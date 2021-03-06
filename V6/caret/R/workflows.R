### In this file, there are a lot of functions form caret that are
### references using the explicit namespace operator (:::). For some
### reason, with some parallel processing technologies and foreach,
### functions inside of caret cannot be found despite using the
### ".packages" argument and calling the caret package via library().

getOper <- function(x) if(x)  `%dopar%` else  `%do%`
getTrainOper <- function(x) if(x)  `%dopar%` else  `%do%`


progress <- function(x, names, iter, start = TRUE)
{
  text <- paste(ifelse(start, "+ ", "- "),
                names[iter], ": ",
                paste(colnames(x), x, sep = "=", collapse = ", "),
                sep = "")
  cat(text, "\n")
}

MeanSD <- function(x, exclude = NULL)
{
  if(!is.null(exclude)) x <- x[, !(colnames(x) %in% exclude), drop = FALSE]
  out <- c(colMeans(x, na.rm = TRUE), sapply(x, sd, na.rm = TRUE))
  names(out)[-(1:ncol(x))] <- paste(names(out)[-(1:ncol(x))], "SD", sep = "")
  out
}

expandParameters <- function(fixed, seq)
{
  if(is.null(seq)) return(fixed)
  
  isSeq <- names(fixed) %in% names(seq)
  out <- fixed
  for(i in 1:nrow(seq))
  {
    tmp <- fixed
    tmp[,isSeq] <- seq[i,]
    out <- rbind(out, tmp)
  }
  out
}

nominalTrainWorkflow <- function(x, y, wts, info, method, ppOpts, ctrl, lev, testing = FALSE, ...)
{
  library(caret)
  loadNamespace("caret")
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  printed <- format(info$loop, digits = 4)
  colnames(printed) <- gsub("^\\.", "", colnames(printed))
  
  ## For 632 estimator, add an element to the index of zeros to trick it into
  ## fitting and predicting the full data set.
  
  resampleIndex <- ctrl$index
  if(ctrl$method %in% c("boot632"))
  {
    resampleIndex <- c(list("AllData" = rep(0, nrow(dat))), resampleIndex)
    ctrl$indexOut <- c(list("AllData" = rep(0, nrow(dat))),  ctrl$indexOut)
  }
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  
  pkgs <- c("methods", "caret")
  if(!is.null(method$library)) pkgs <- c(pkgs, method$library)
  
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = pkgs, .errorhandling = "stop") %:%
    foreach(parm = 1:nrow(info$loop), .combine = "c", .verbose = FALSE, .packages = pkgs, .errorhandling = "stop")  %op%
{
  if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) set.seed(ctrl$seeds[[iter]][parm])
  
  library(caret)
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                        names(resampleIndex), iter)
  
  if(names(resampleIndex)[iter] != "AllData")
  {
    modelIndex <- resampleIndex[[iter]]
    holdoutIndex <- ctrl$indexOut[[iter]]
  } else {
    modelIndex <- 1:nrow(dat)
    holdoutIndex <- modelIndex
  }
  
  if(testing) cat("pre-model\n")
  
  mod <- try(
    caret:::createModel(x = x[modelIndex,,drop = FALSE ],
                        y = y[modelIndex],
                        wts = wts[modelIndex],
                        method = method,
                        tuneValue = info$loop[parm,,drop = FALSE],
                        obsLevels = lev,
                        pp = ppp,
                        classProbs = ctrl$classProbs,
                        ...),
    silent = TRUE)
  
  if(class(mod)[1] != "try-error")
  {
    predicted <- try(
      caret:::predictionFunction(method = method,
                                 modelFit = mod$fit,
                                 newdata = x[holdoutIndex,, drop = FALSE],
                                 preProc = mod$preProc,
                                 param = info$submodels[[parm]]),
      silent = TRUE)
    
    if(class(predicted)[1] == "try-error")
    {
      wrn <- paste(colnames(printed[parm,,drop = FALSE]),
                   printed[parm,,drop = FALSE],
                   sep = "=",
                   collapse = ", ")
      wrn <- paste("predictions failed for ", names(resampleIndex)[iter],
                   ": ", wrn, " ", as.character(predicted), sep = "")
      if(ctrl$verboseIter) cat(wrn, "\n")
      warning(wrn)
      rm(wrn)
      
      ## setup a dummy results with NA values for all predictions
      nPred <- length(holdoutIndex)
      if(!is.null(lev))
      {
        predicted <- rep("", nPred)
        predicted[seq(along = predicted)] <- NA
      } else {
        predicted <- rep(NA, nPred)
      }
      if(!is.null(info$submodels[[parm]]))
      {
        tmp <- predicted
        predicted <- vector(mode = "list", length = nrow(info$submodels[[parm]]) + 1)
        for(i in seq(along = predicted)) predicted[[i]] <- tmp
        rm(tmp)
      }
    }
  } else {
    wrn <- paste(colnames(printed[parm,,drop = FALSE]),
                 printed[parm,,drop = FALSE],
                 sep = "=",
                 collapse = ", ")
    wrn <- paste("model fit failed for ", names(resampleIndex)[iter],
                 ": ", wrn, " ", as.character(mod), sep = "")
    if(ctrl$verboseIter) cat(wrn, "\n")
    warning(wrn)
    rm(wrn)
    
    ## setup a dummy results with NA values for all predictions
    nPred <- length(holdoutIndex)
    if(!is.null(lev))
    {
      predicted <- rep("", nPred)
      predicted[seq(along = predicted)] <- NA
    } else {
      predicted <- rep(NA, nPred)
    }
    if(!is.null(info$submodels[[parm]]))
    {
      tmp <- predicted
      predicted <- vector(mode = "list", length = nrow(info$submodels[[parm]]) + 1)
      for(i in seq(along = predicted)) predicted[[i]] <- tmp
      rm(tmp)
    }
  }
  
  if(testing) print(head(predicted))
  if(ctrl$classProbs)
  {
    if(class(mod)[1] != "try-error")
    {
      probValues <- caret:::probFunction(method = method,
                                         modelFit = mod$fit,
                                         newdata = x[holdoutIndex,, drop = FALSE],
                                         preProc = mod$preProc,
                                         param = info$submodels[[parm]])
    } else {
      probValues <- as.data.frame(matrix(NA, nrow = nPred, ncol = length(lev)))
      colnames(probValues) <- lev
      if(!is.null(info$submodels[[parm]]))
      {
        tmp <- probValues
        probValues <- vector(mode = "list", length = nrow(info$submodels[[parm]]) + 1)
        for(i in seq(along = probValues)) probValues[[i]] <- tmp
        rm(tmp)
      }
    }
    if(testing) print(head(probValues))
  }
  
  ##################################
  
  if(!is.null(info$submodels))
  {
    ## merge the fixed and seq parameter values together
    allParam <- caret:::expandParameters(info$loop[parm,,drop = FALSE], info$submodels[[parm]])
    allParam <- allParam[complete.cases(allParam),, drop = FALSE]
    
    #     ## For ctree, we had to repeat the first value
    #     if(method == "ctree") allParam <- allParam[!duplicated(allParam),, drop = FALSE]
    #     
    #     ## For glmnet, we fit all the lambdas but x$fixed has an NA
    #     if(method == "glmnet") allParam <- allParam[complete.cases(allParam),, drop = FALSE]
    
    ## collate the predicitons across all the sub-models
    predicted <- lapply(predicted,
                        function(x, y, lv)
                        {
                          if(!is.factor(x) & is.character(x)) x <- factor(as.character(x), levels = lv)
                          data.frame(pred = x, obs = y, stringsAsFactors = FALSE)
                        },
                        y = y[holdoutIndex],
                        lv = lev)
    if(testing) print(head(predicted))
    
    ## same for the class probabilities
    if(ctrl$classProbs)
    {
      for(k in seq(along = predicted)) predicted[[k]] <- cbind(predicted[[k]], probValues[[k]])
    }
    
    if(ctrl$savePredictions)
    {
      tmpPred <- predicted
      for(modIndex in seq(along = tmpPred))
      {
        tmpPred[[modIndex]]$rowIndex <- holdoutIndex
        tmpPred[[modIndex]] <- cbind(tmpPred[[modIndex]], allParam[modIndex,,drop = FALSE])
      }
      tmpPred <- rbind.fill(tmpPred)
      tmpPred$Resample <- names(resampleIndex)[iter]
    } else tmpPred <- NULL
    
    ## get the performance for this resample for each sub-model
    thisResample <- lapply(predicted,
                           ctrl$summaryFunction,
                           lev = lev,
                           model = method)
    if(testing) print(head(thisResample))
    ## for classification, add the cell counts
    if(length(lev) > 1)
    {
      cells <- lapply(predicted,
                      function(x) caret:::flatTable(x$pred, x$obs))
      for(ind in seq(along = cells)) thisResample[[ind]] <- c(thisResample[[ind]], cells[[ind]])
    }
    thisResample <- do.call("rbind", thisResample)          
    thisResample <- cbind(allParam, thisResample)
    
  } else {       
    if(is.factor(y)) predicted <- factor(as.character(predicted), levels = lev)
    tmp <-  data.frame(pred = predicted,
                       obs = y[holdoutIndex],
                       stringsAsFactors = FALSE)
    ## Sometimes the code above does not coerce the first
    ## columnn to be named "pred" so force it
    names(tmp)[1] <- "pred"
    if(ctrl$classProbs) tmp <- cbind(tmp, probValues)
    
    if(ctrl$savePredictions)
    {
      tmpPred <- tmp
      tmpPred$rowIndex <- holdoutIndex
      tmpPred <- cbind(tmpPred, info$loop[parm,,drop = FALSE])
      tmpPred$Resample <- names(resampleIndex)[iter]
    } else tmpPred <- NULL
    
    ##################################
    thisResample <- ctrl$summaryFunction(tmp,
                                         lev = lev,
                                         model = method)
    
    ## if classification, get the confusion matrix
    if(length(lev) > 1) thisResample <- c(thisResample, caret:::flatTable(tmp$pred, tmp$obs))
    thisResample <- as.data.frame(t(thisResample))
    thisResample <- cbind(thisResample, info$loop[parm,,drop = FALSE])
    
  }
  thisResample$Resample <- names(resampleIndex)[iter]
  
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                        names(resampleIndex), iter, FALSE)
  list(resamples = thisResample, pred = tmpPred)
}
  
  resamples <- rbind.fill(result[names(result) == "resamples"])
  pred <- if(ctrl$savePredictions)  rbind.fill(result[names(result) == "pred"]) else NULL
  if(ctrl$method %in% c("boot632"))
  {
    perfNames <- names(ctrl$summaryFunction(data.frame(obs = dat$.outcome, pred = sample(dat$.outcome)),
                                            lev = lev,
                                            model = method))
    apparent <- subset(resamples, Resample == "AllData")
    apparent <- apparent[,!grepl("^\\.cell|Resample", colnames(apparent)),drop = FALSE]
    names(apparent)[which(names(apparent) %in% perfNames)] <- paste(names(apparent)[which(names(apparent) %in% perfNames)],
                                                                    "Apparent", sep = "")
    names(apparent) <- gsub("^\\.", "", names(apparent))
    if(any(!complete.cases(apparent[,!grepl("^cell|Resample", colnames(apparent)),drop = FALSE])))
    {
      warning("There were missing values in the apparent performance measures.")
    }        
    resamples <- subset(resamples, Resample != "AllData")
  }
  names(resamples) <- gsub("^\\.", "", names(resamples))
  
  if(any(!complete.cases(resamples[,!grepl("^cell|Resample", colnames(resamples)),drop = FALSE])))
  {
    warning("There were missing values in resampled performance measures.")
  }
  
  out <- ddply(resamples[,!grepl("^cell|Resample", colnames(resamples)),drop = FALSE],
               ## TODO check this for seq models
               gsub("^\\.", "", colnames(info$loop)),
               caret:::MeanSD, 
               exclude = gsub("^\\.", "", colnames(info$loop)))
  
  if(ctrl$method %in% c("boot632"))
  {
    out <- merge(out, apparent)
    for(p in seq(along = perfNames))
    {
      const <- 1-exp(-1)
      out[, perfNames[p]] <- (const * out[, perfNames[p]]) +  ((1-const) * out[, paste(perfNames[p],"Apparent", sep = "")])
    }
  }
  
  list(performance = out, resamples = resamples, predictions = if(ctrl$savePredictions) pred else NULL)
}



looTrainWorkflow <- function(x, y, wts, info, method, ppOpts, ctrl, lev, testing = FALSE, ...)
{
  library(caret)
  loadNamespace("caret")
  
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  printed <- format(info$loop)
  colnames(printed) <- gsub("^\\.", "", colnames(printed))
  
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  
  pkgs <- c("methods", "caret")
  if(!is.null(method$library)) pkgs <- c(pkgs, method$library)
  
  result <- foreach(iter = seq(along = ctrl$index), .combine = "rbind", .verbose = FALSE, .packages = pkgs, .errorhandling = "stop") %:%
    foreach(parm = 1:nrow(info$loop), .combine = "rbind", .verbose = FALSE, .packages = pkgs, .errorhandling = "stop") %op%
{
  
  if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) set.seed(ctrl$seeds[[iter]][parm])
  if(testing) cat("after loops\n")
  library(caret)
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                        names(ctrl$index), iter, TRUE)
  
  mod <- caret:::createModel(x = x[ctrl$index[[iter]],,drop = FALSE ],
                             y = y[ctrl$index[[iter]] ],
                             wts = wts[ctrl$index[[iter]] ],
                             method = method,
                             tuneValue = info$loop[parm,,drop = FALSE],
                             obsLevels = lev,
                             pp = ppp,
                             classProbs = ctrl$classProbs,
                             ...)
  
  holdoutIndex <- -unique(ctrl$index[[iter]])
  
  predicted <- caret:::predictionFunction(method = method,
                                          modelFit = mod$fit,
                                          newdata = x[-ctrl$index[[iter]],, drop = FALSE],
                                          preProc = mod$preProc,
                                          param = info$submodels[[parm]])
  
  if(testing) print(head(predicted))
  if(ctrl$classProbs)
  {
    probValues <- caret:::probFunction(method = method,
                                       modelFit = mod$fit,
                                       newdata = x[holdoutIndex,, drop = FALSE],
                                       preProc = mod$preProc,
                                       param = info$submodels[[parm]])
    if(testing) print(head(probValues))
  }
  
  ##################################
  
  if(!is.null(info$submodels))
  {
    ## collate the predictions across all the sub-models
    predicted <- lapply(predicted,
                        function(x, y, lv)
                        {
                          if(!is.factor(x) & is.character(x)) x <- factor(as.character(x), levels = lv)
                          data.frame(pred = x, obs = y, stringsAsFactors = FALSE)
                        },
                        y = y[holdoutIndex],
                        lv = lev)
    if(testing) print(head(predicted))
    
    ## same for the class probabilities
    if(ctrl$classProbs)
    {
      for(k in seq(along = predicted)) predicted[[k]] <- cbind(predicted[[k]], probValues[[k]])
    }
    predicted <- do.call("rbind", predicted)
    allParam <- caret:::expandParameters(info$loop[parm,,drop = FALSE], info$submodels[[parm]])
    rownames(predicted) <- NULL
    predicted <- cbind(predicted, allParam)
    ## if saveDetails then save and export 'predicted'
  } else {
    
    if(is.factor(y)) predicted <- factor(as.character(predicted),
                                         levels = lev)
    predicted <-  data.frame(pred = predicted,
                             obs = y[holdoutIndex],
                             stringsAsFactors = FALSE)
    if(ctrl$classProbs) predicted <- cbind(predicted, probValues)
    predicted <- cbind(predicted, info$loop[parm,,drop = FALSE])
  }
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                        names(ctrl$index), iter, FALSE)
  predicted
}
  
  names(result) <- gsub("^\\.", "", names(result))
  out <- ddply(result,
               as.character(method$parameter$parameter),
               ctrl$summaryFunction,
               lev = lev,
               model = method)
  list(performance = out, predictions = result)
}

oobTrainWorkflow <- function(x, y, wts, info, method, ppOpts, ctrl, lev, testing = FALSE, ...)
{
  library(caret)
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  printed <- format(info$loop)
  colnames(printed) <- gsub("^\\.", "", colnames(printed))
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  result <- foreach(parm = 1:nrow(info$loop), .packages = c("methods", "caret"), .combine = "rbind") %op%
{
  library(caret)
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE], "", 1, TRUE)
  
  mod <- caret:::createModel(x = x,
                             y = y,
                             wts = wts,
                             method = method,
                             tuneValue = info$loop[parm,,drop = FALSE],
                             obsLevels = lev,
                             pp = ppp,
                             classProbs = ctrl$classProbs,
                             ...)
  
  out <- switch(class(mod$fit)[1],
                randomForest = caret:::rfStats(mod$fit),
                RandomForest = caret:::cforestStats(mod$fit),
                bagEarth =, bagFDA = caret:::bagEarthStats(mod$fit),
                regbagg =, classbagg = caret:::ipredStats(mod$fit))
  if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE], "", 1, FALSE)
  
  cbind(as.data.frame(t(out)), info$loop[parm,,drop = FALSE])
}
  names(result) <- gsub("^\\.", "", names(result))
  result
}

################################################################################################

nominalSbfWorkflow <- function(x, y, ppOpts, ctrl, lev, ...)
{
  library(caret)
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  resampleIndex <- ctrl$index
  if(ctrl$method %in% c("boot632")) resampleIndex <- c(list("AllData" = rep(0, nrow(dat))), resampleIndex)
  
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop") %op%
{
  if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) set.seed(ctrl$seeds[iter])
  
  library(caret)
  
  if(names(resampleIndex)[iter] != "AllData")
  {
    modelIndex <- resampleIndex[[iter]]
    holdoutIndex <- -unique(resampleIndex[[iter]])
  } else {
    modelIndex <- 1:nrow(dat)
    holdoutIndex <- modelIndex
  }
  
  sbfResults <- caret:::sbfIter(x[modelIndex,,drop = FALSE],
                                y[modelIndex],
                                x[holdoutIndex,,drop = FALSE],
                                y[holdoutIndex],
                                ctrl,
                                ...)
  if(ctrl$saveDetails)
  {
    tmpPred <- sbfResults$pred
    tmpPred$Resample <- names(resampleIndex)[iter]
    tmpPred$rowIndex <- seq(along = y)[unique(holdoutIndex)]
  } else tmpPred <- NULL
  resamples <- ctrl$functions$summary(sbfResults$pred, lev = lev)
  if(is.factor(y)) resamples <- c(resamples, caret:::flatTable(sbfResults$pred$pred, sbfResults$pred$obs))
  resamples <- data.frame(t(resamples))
  resamples$Resample <- names(resampleIndex)[iter]
  
  list(resamples = resamples, selectedVars = sbfResults$variables, pred = tmpPred)
}
  
  resamples <- rbind.fill(result[names(result) == "resamples"])
  pred <- if(ctrl$saveDetails) rbind.fill(result[names(result) == "pred"]) else NULL
  performance <- caret:::MeanSD(resamples[,!grepl("Resample", colnames(resamples)),drop = FALSE])
  
  if(ctrl$method %in% c("boot632"))
  {
    modelIndex <- 1:nrow(x)
    holdoutIndex <- modelIndex
    appResults <- caret:::sbfIter(x[modelIndex,,drop = FALSE],
                                  y[modelIndex],
                                  x[holdoutIndex,,drop = FALSE],
                                  y[holdoutIndex],
                                  ctrl,
                                  ...)
    apparent <- ctrl$functions$summary(appResults$pred, lev = lev)
    perfNames <- names(apparent)
    
    const <- 1-exp(-1)
    
    for(p in seq(along = perfNames))
      performance[perfNames[p]] <- (const * performance[perfNames[p]]) +  ((1-const) * apparent[perfNames[p]])
    
  }
  
  list(performance = performance, everything = result, predictions = if(ctrl$saveDetails) pred else NULL)
}


looSbfWorkflow <- function(x, y, ppOpts, ctrl, lev, ...)
{
  library(caret)
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  resampleIndex <- ctrl$index
  
  vars <- vector(mode = "list", length = length(y))
  
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop") %op%
{
  if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) set.seed(ctrl$seeds[iter])
  
  library(caret)
  
  modelIndex <- resampleIndex[[iter]]
  holdoutIndex <- -unique(resampleIndex[[iter]])
  
  sbfResults <- caret:::sbfIter(x[modelIndex,,drop = FALSE],
                                y[modelIndex],
                                x[holdoutIndex,,drop = FALSE],
                                y[holdoutIndex],
                                ctrl,
                                ...)
  
  sbfResults
}
  resamples <- do.call("rbind", result[names(result) == "pred"])
  performance <- ctrl$functions$summary(resamples, lev = lev)
  
  list(performance = performance, everything = result, predictions = if(ctrl$saveDetails) resamples else NULL)
}


################################################################################################

nominalRfeWorkflow <- function(x, y, sizes, ppOpts, ctrl, lev, ...)
{
  library(caret)
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  resampleIndex <- ctrl$index
  if(ctrl$method %in% c("boot632")) resampleIndex <- c(list("AllData" = rep(0, nrow(x))), resampleIndex)
  
  `%op%` <- getOper(ctrl$allowParallel && getDoParWorkers() > 1)
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop") %op%
{
  library(caret)
  
  if(names(resampleIndex)[iter] != "AllData")
  {
    modelIndex <- resampleIndex[[iter]]
    holdoutIndex <- -unique(resampleIndex[[iter]])
  } else {
    modelIndex <- 1:nrow(x)
    holdoutIndex <- modelIndex
  }
  
  seeds <- if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) ctrl$seeds[[iter]] else NA
  rfeResults <- caret:::rfeIter(x[modelIndex,,drop = FALSE],
                                y[modelIndex],
                                x[holdoutIndex,,drop = FALSE],
                                y[holdoutIndex],
                                sizes,
                                ctrl,
                                label = names(resampleIndex)[iter],
                                seeds = seeds,
                                ...)
  resamples <- ddply(rfeResults$pred, .(Variables), ctrl$functions$summary, lev = lev)
  
  if(ctrl$saveDetails)
  {
    rfeResults$pred$Resample <- names(resampleIndex)[iter]
    ## If the user did not have nrow(x) in 'sizes', rfeIter added it.
    ## So, we need to find out how many set of predictions there are:
    nReps <- length(table(rfeResults$pred$Variables))
    rfeResults$pred$rowIndex <- rep(seq(along = y)[unique(holdoutIndex)], nReps)
  }
  
  if(is.factor(y))
  {
    cells <- ddply(rfeResults$pred, .(Variables), function(x) caret:::flatTable(x$pred, x$obs))
    resamples <- merge(resamples, cells)
  }
  
  resamples$Resample <- names(resampleIndex)[iter]
  vars <- do.call("rbind", rfeResults$finalVariables)
  vars$Resample <- names(resampleIndex)[iter]
  list(resamples = resamples, selectedVars = vars, predictions = if(ctrl$saveDetails) rfeResults$pred else NULL)
}
  resamples <- do.call("rbind", result[names(result) == "resamples"])
  rownames(resamples) <- NULL
  
  if(ctrl$method %in% c("boot632"))
  {
    perfNames <- names(ctrl$functions$summary(data.frame(obs =y, pred = sample(y)),
                                              lev = lev,
                                              model = method))
    apparent <- subset(resamples, Resample == "AllData")
    apparent <- apparent[,!grepl("^\\.cell|Resample", colnames(apparent)),drop = FALSE]
    names(apparent)[which(names(apparent) %in% perfNames)] <- paste(names(apparent)[which(names(apparent) %in% perfNames)],
                                                                    "Apparent", sep = "")
    names(apparent) <- gsub("^\\.", "", names(apparent))
    resamples <- subset(resamples, Resample != "AllData")
  }
  
  externPerf <- ddply(resamples[,!grepl("\\.cell|Resample", colnames(resamples)),drop = FALSE],
                      .(Variables),
                      caret:::MeanSD,
                      exclude = "Variables")
  if(ctrl$method %in% c("boot632"))
  {
    externPerf <- merge(externPerf, apparent)
    for(p in seq(along = perfNames))
    {
      const <- 1-exp(-1)
      externPerf[, perfNames[p]] <- (const * externPerf[, perfNames[p]]) +  ((1-const) * externPerf[, paste(perfNames[p],"Apparent", sep = "")])
    }
    externPerf <- externPerf[, !(names(externPerf) %in% paste(perfNames,"Apparent", sep = ""))]
  }
  list(performance = externPerf, everything = result)
}


looRfeWorkflow <- function(x, y, sizes, ppOpts, ctrl, lev, ...)
{
  library(caret)
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  resampleIndex <- ctrl$index
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop") %dopar%
{
  library(caret)
  
  modelIndex <- resampleIndex[[iter]]
  holdoutIndex <- -unique(resampleIndex[[iter]])
  
  seeds <- if(!(length(ctrl$seeds) == 1 && is.na(ctrl$seeds))) ctrl$seeds[[iter]] else NA
  rfeResults <- caret:::rfeIter(x[modelIndex,,drop = FALSE],
                                y[modelIndex],
                                x[holdoutIndex,,drop = FALSE],
                                y[holdoutIndex],
                                sizes,
                                ctrl,
                                seeds = seeds,
                                ...)
  rfeResults
}
  preds <- do.call("rbind", result[names(result) == "pred"])
  resamples <- ddply(preds, .(Variables), ctrl$functions$summary, lev = lev)   
  list(performance = resamples, everything = result)
}



adaptiveTrainWorkflow <- function(dat, info, method, ppOpts, ctrl, lev, testing = FALSE, ...)
{
  library(caret)
  loadNamespace("caret")
  ppp <- list(options = ppOpts)
  ppp <- c(ppp, ctrl$preProcOptions)
  
  printed <- format(info$loop, digits = 4)
  colnames(printed) <- gsub("^\\.", "", colnames(printed))
  
  burnIn <- 5
  diffThreshold <- .25
  
  ## For 632 estimator, add an element to the index of zeros to trick it into
  ## fitting and predicting the full data set.
  
  resampleIndex <- ctrl$index
  if(ctrl$method %in% c("boot632"))
  {
    resampleIndex <- c(list("AllData" = rep(0, nrow(dat))), resampleIndex)
    ctrl$indexOut <- c(list("AllData" = rep(0, nrow(dat))),  ctrl$indexOut)
  }
  
  `%op%` <- `%do%`
  
  ## use regular for loop here as to easily adjust the loop data
  result <- foreach(iter = seq(along = resampleIndex), .combine = "c", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop") %do% {
    library(caret)
    if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                          names(resampleIndex), iter)
    
    if(names(resampleIndex)[iter] != "AllData")
    {
      modelIndex <- resampleIndex[[iter]]
      holdoutIndex <- ctrl$indexOut[[iter]]
    } else {
      modelIndex <- 1:nrow(dat)
      holdoutIndex <- modelIndex
    }
    
    subResult <- foreach(parm = 1:nrow(info$loop), .combine = "rbind", .verbose = FALSE, .packages = c("methods", "caret"), .errorhandling = "stop")  %op% {
      mod <- try(
        caret:::createModel(data = dat[modelIndex,,drop = FALSE ],
                            method = method,
                            tuneValue = info$loop[parm,,drop = FALSE],
                            obsLevels = lev,
                            pp = ppp,
                            custom = ctrl$custom$model,
                            classProbs = ctrl$classProbs,
                            ...),
        silent = TRUE)
      
      predicted <- try(
        caret:::predictionFunction(method = method,
                                   modelFit = mod$fit,
                                   newdata = dat[holdoutIndex, !(names(dat) %in% c(".outcome", ".modelWeights")), drop = FALSE],
                                   preProc = mod$preProc,
                                   param = info$seqParam[[parm]],
                                   custom = ctrl$custom$prediction),
        silent = TRUE)
      
      if(is.factor(dat$.outcome)) predicted <- factor(as.character(predicted), levels = lev)
      tmp <-  data.frame(pred = predicted,
                         obs = dat$.outcome[holdoutIndex],
                         stringsAsFactors = FALSE)
      ## Sometimes the code above does not coerce the first
      ## columnn to be named "pred" so force it
      names(tmp)[1] <- "pred"
      if(ctrl$classProbs) tmp <- cbind(tmp, probValues)
      
      ##################################
      thisResample <- ctrl$summaryFunction(tmp,
                                           lev = lev,
                                           model = method)
      
      ## if classification, get the confusion matrix
      if(length(lev) > 1) thisResample <- c(thisResample, caret:::flatTable(tmp$pred, tmp$obs))
      thisResample <- as.data.frame(t(thisResample))
      thisResample <- cbind(thisResample, info$loop[parm,,drop = FALSE])
    } ## end loop over parameters
    
    subResult$Resample <- names(resampleIndex)[iter]
    if(iter <= burnIn)
    {
      currentResults <- if(iter == 1) subResult else rbind(currentResults, subResult)
    } else {
      paramResults <- paramTest(currentResults, metric = "RMSE", ".C", maximize = FALSE)
      print(paramResults)
      selectedParam <- subset(paramResults, min_prob >= diffThreshold)
      if(nrow(selectedParam) == 0) selectedParam <- paramResults[which.max(paramResults$min_prob),,drop = FALSE]
      selectedParam <- selectedParam[, names(selectedParam) %in% names(info$loop),drop = FALSE]
      print(selectedParam)
      
      info$loop <- merge(selectedParam, info$loop)
      if(ctrl$verboseIter) cat("Number of tuning parameters reduced to", nrow(info$loop), "\n")
    }
    
    if(ctrl$verboseIter) caret:::progress(printed[parm,,drop = FALSE],
                                          names(resampleIndex), iter, FALSE)
    list(resamples = subResult)
  } ## end loop over resamples
  
  resamples <- rbind.fill(result[names(result) == "resamples"])
  pred <- if(ctrl$savePredictions)  rbind.fill(result[names(result) == "pred"]) else NULL
  if(ctrl$method %in% c("boot632"))
  {
    perfNames <- names(ctrl$summaryFunction(data.frame(obs = dat$.outcome, pred = sample(dat$.outcome)),
                                            lev = lev,
                                            model = method))
    apparent <- subset(resamples, Resample == "AllData")
    apparent <- apparent[,!grepl("^\\.cell|Resample", colnames(apparent)),drop = FALSE]
    names(apparent)[which(names(apparent) %in% perfNames)] <- paste(names(apparent)[which(names(apparent) %in% perfNames)],
                                                                    "Apparent", sep = "")
    names(apparent) <- gsub("^\\.", "", names(apparent))
    if(any(!complete.cases(apparent[,!grepl("^cell|Resample", colnames(apparent)),drop = FALSE])))
    {
      warning("There were missing values in the apparent performance measures.")
    }        
    resamples <- subset(resamples, Resample != "AllData")
  }
  names(resamples) <- gsub("^\\.", "", names(resamples))
  
  if(any(!complete.cases(resamples[,!grepl("^cell|Resample", colnames(resamples)),drop = FALSE])))
  {
    warning("There were missing values in resampled performance measures.")
  }
  out <- ddply(resamples[,!grepl("^cell|Resample", colnames(resamples)),drop = FALSE],
               info$model$parameter,
               caret:::MeanSD, exclude = info$model$parameter)
  
  if(ctrl$method %in% c("boot632"))
  {
    out <- merge(out, apparent)
    for(p in seq(along = perfNames))
    {
      const <- 1-exp(-1)
      out[, perfNames[p]] <- (const * out[, perfNames[p]]) +  ((1-const) * out[, paste(perfNames[p],"Apparent", sep = "")])
    }
  }
  
  list(performance = out, resamples = resamples, predictions = if(ctrl$savePredictions) pred else NULL)
}


paramTest <- function(x, metric = names(x)[1], param, maximize = TRUE)
{
  paramValues <- x[, param, drop = FALSE]
  paramValues <- paramValues[!duplicated(paramValues),,drop = FALSE]
  paramValues$.setting <- paste("param", gsub(" ", "0", format(1:nrow(paramValues))), sep = "")
  x <- merge(x, paramValues, all.x = TRUE)
  horz <- reshape(x[, c("Resample", metric, ".setting")], 
                  direction = "wide", 
                  v.names = metric, 
                  timevar = ".setting", 
                  idvar = "Resample") 
  horz <- horz[order(horz$Resample),
               c("Resample", sort(grep(metric, colnames(horz), value = TRUE)))]
  colnames(horz) <- gsub(paste(metric, ".", sep = ""), "", colnames(horz))
  min_probs <- getBestP(horz[, -1], maximize = maximize)
  merge(paramValues, min_probs)
}

getBestP <- function(dat, maximize = TRUE)
{
  pvals <- diffs <- matrix(NA, nrow = ncol(dat), ncol = ncol(dat))
  colnames(pvals) <- colnames(dat)
  alt <- if(maximize) "greater" else "less"
  for(Row in 1:ncol(dat))
  {
    for(Col in Row:ncol(dat))
    {
      if(Row != Col)
      {
        
        tmp <- t.test(dat[,Row] - dat[,Col], alternative = alt)
        pvals[Row,Col] <- tmp$p.value
        pvals[Col,Row] <- 1- pvals[Row,Col]
        diffs[Row,Col] <- tmp$estimate
        diffs[Col,Row] <- -diffs[Row,Col]        
      }
    }
  }  
  data.frame(.setting = colnames(dat),
             min_prob = apply(pvals, 2, min, na.rm = TRUE))
}
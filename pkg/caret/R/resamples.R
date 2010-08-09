"resamples" <- function(x, ...) UseMethod("resamples")

resamples.default <- function(x, modelNames = names(x), ...)
  {

    ## Do a lot of checkin of the object types and make sure
    ## that they actually used the samples samples in the resamples
    if(length(x) < 2) stop("at least two train objects are needed")
    classes <- unlist(lapply(x, function(x) class(x)[1]))
    if(!all(classes %in% c("sbf", "rfe", "train"))) stop("all objects in x must of class train, sbf or rfe")

 
    numResamp <- unlist(lapply(x, function(x) length(x$control$index)))
    if(length(unique(numResamp)) > 1) stop("There are different numbers of resamples in each model")
    
    
    for(i in 1:numResamp[1])
      {
        indices <- lapply(x, function(x, i) sort(x$control$index[[1]]), i = i)
        uniqueIndex <- length(table(table(unlist(indices))))
        if(length(uniqueIndex) > 1) stop("The samples indices are not equal across resamples")
      }

    getNames <- function(x)
      {
        switch(class(x)[1],
               sbf = x$metrics,
               train =, rfe = x$perfNames)               
      }
    
    perfs <- lapply(x, getNames)
    if(length(unique(unlist(lapply(perfs, length)))) != 1) stop("all objects must has the same performance metrics")
    perfs <- do.call("rbind", perfs)
    uniques <- apply(perfs, 2, function(x) length(unique(x)))
    if(!all(uniques == 1)) stop("all objects must has the same performance metrics")
    pNames <- unique(as.vector(perfs))

    
    if(is.null(modelNames)) modelNames <- paste("Model", seq(along = x))
    for(i in seq(along = x))
      {

        ## TODO check for returnResamp in control object and select appropriate
        ## data for train
        if(class(x[[i]])[1] == "rfe" && x[[i]]$control$returnResamp == "all")
          {
            x[[i]]$resample <- subset(x[[i]]$resample, Variables == x[[i]]$bestSubset)
          }
        tmp <- x[[i]]$resample[, c(pNames, "Resample"), drop = FALSE]
        names(tmp)[names(tmp) %in% pNames] <- paste(modelNames[i], names(tmp)[names(tmp) %in% pNames], sep = "~")
        out <- if(i == 1) tmp else merge(out, tmp)
      }

    out <- structure(
                     list(
                          call = match.call(),
                          values = out,
                          models = modelNames,
                          metrics = pNames,
                          methods = unlist(lapply(x, function(x) x$method))),
                     class = "resamples")
    
    
    out
  }


prcomp.resamples <- function(x, metric = x$metrics[1],  ...)
  {
    
    if(length(metric) != 1) stop("exactly one metric must be given")

    tmpData <- x$values[, grep(paste("~", metric, sep = ""),
                               names(x$value),
                               fixed = TRUE),
                        drop = FALSE]
    names(tmpData) <- gsub(paste("~", metric, sep = ""),
                           "",
                           names(tmpData),
                           fixed = TRUE)

    tmpData <- t(tmpData)
    out <- prcomp(tmpData)
    out$metric <- metric
    out$call <- match.call()
    class(out) <- c("prcomp.resamples", "prcomp")
    out
  }

plot.prcomp.resamples <- function(x, what = "scree", dims = max(2, ncol(x$rotation)), ...)
{
  if(length(what) > 1) stop("one plot at a time please")
  switch(what,
         scree =
         {
           barchart(x$sdev ~ paste("PC", seq(along = x$sdev)),
                    ylab = "Standard Deviation", ...)
         },
         cumulative =
         {
           barchart(cumsum(x$sdev^2)/sum(x$sdev^2) ~ paste("PC", seq(along = x$sdev)),
                    ylab = "Culmulative Percent of Variance", ...)
         },
         loadings =
         {

           panelRange <- extendrange(x$rotation[, 1:dims,drop = FALSE])
           if(dims > 2)
             {
               
               splom(~x$rotation[, 1:dims,drop = FALSE],
                     main = caret:::useMathSymbols(x$metric),
                     prepanel.limits = function(x) panelRange,
                     type = c("p", "g"),
                     ...)
             } else {
               xyplot(PC2~PC1, data = as.data.frame(x$rotation),
                     main = caret:::useMathSymbols(x$metric),
                     xlim = panelRange,
                     ylim = panelRange,
                     type = c("p", "g"),
                     ...)
             }

         },
         components =
         {

           panelRange <- extendrange(x$x[, 1:dims,drop = FALSE])
           if(dims > 2)
             {
               
               splom(~x$x[, 1:dims,drop = FALSE],
                     main = caret:::useMathSymbols(x$metric),
                     prepanel.limits = function(x) panelRange,
                     groups = rownames(x$x),
                     type = c("p", "g"),
                     ...)
             } else {
               xyplot(PC2~PC1, data = as.data.frame(x$x),
                     main = caret:::useMathSymbols(x$metric),
                     xlim = panelRange,
                     ylim = panelRange,
                     
                     groups = rownames(x$x),
                     type = c("p", "g"),
                     ...)
             }

         })
} 


print.prcomp.resamples <- function (x, digits = max(3, getOption("digits") - 3), print.x = FALSE, ...) 
{
  cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")
  cat("Metric:", x$metric, "\n")


  sds <- rbind(x$sdev, cumsum(x$sdev^2)/sum(x$sdev^2))
  rownames(sds) <- c("Std. Dev. ", "Cum. Percent Var. ")
  colnames(sds) <- rep("", ncol(sds))
                     
  print(sds, digits = digits, ...)
  cat("\nRotation:\n")
  print(x$rotation, digits = digits, ...)
  if (print.x && length(x$x)) {
    cat("\nRotated variables:\n")
    print(x$x, digits = digits, ...)
  }
  invisible(x)
}

print.resamples <- function(x, ...)
  {
    cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")
    cat("Models:", paste(x$models, collapse = ", "), "\n")
    cat("Number of resamples:", nrow(x$values), "\n")
    cat("Performance metrics:",  paste(x$metrics, collapse = ", "), "\n")
    invisible(x)
  }

summary.resamples <- function(object, ...)
{

  vals <- object$values[, names(object$values) != "Resample", drop = FALSE]

  out <- vector(mode = "list", length = length(object$metrics))
  for(i in seq(along = object$metrics))
    {
      tmpData <- vals[, grep(paste("~", object$metrics[i], sep = ""), names(vals), fixed = TRUE), drop = FALSE]
      
      out[[i]] <- do.call("rbind", lapply(tmpData, summary))
      rownames(out[[i]]) <- gsub(paste("~", object$metrics[i], sep = ""),
                                 "",
                                 rownames(out[[i]]),
                                 fixed = TRUE)
    }
  
  names(out) <- object$metrics
  out <- structure(
                   list(values = vals,
                        call = match.call(),
                        statistics = out,
                        models = object$models,
                        metrics = object$metrics,
                        methods = object$methods),
                   class = "summary.resamples")
  out
}


print.summary.resamples <- function(x, ...)
  {
    cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")
    cat("Models:", paste(x$models, collapse = ", "), "\n")
    cat("Number of resamples:", nrow(x$values), "\n")

    cat("\n")
    
    for(i in seq(along = x$statistics))
      {
        cat(names(x$statistics)[i], "\n")
        print(x$statistics[[i]])
        cat("\n")
      }
    invisible(x)
  }



xyplot.resamples <- function (x, data = NULL, models = x$models[1:2], metric = x$metric[1], ...) 
{
  if(length(metric) != 1) stop("exactly one metric must be given")
  if(length(models) != 2) stop("exactly two model names must be given")
  tmpData <- x$values[, paste(models, metric, sep ="~")]
  tmpData$Difference <- tmpData[,1] - tmpData[,2]
  tmpData$Average <- (tmpData[,1] + tmpData[,2])/2
  ylm <- extendrange(c(tmpData$Difference, 0))
  xyplot(Difference ~ Average,
         data = tmpData,
         ylab = paste(models, collapse = " - "),
         ylim = ylm,
         main = useMathSymbols(metric),
         panel = function(x, y, ...)
         {
           panel.abline(h = 0, col = "darkgrey", lty = 2)
           panel.xyplot(x, y, ...)
         })
  
}

parallel.resamples <- function (x, data = NULL, models = x$models, metric = x$metric[1], ...) 
{
  if(length(metric) != 1) stop("exactly one metric must be given")

  tmpData <- x$values[, grep(paste("~", metric, sep = ""),
                             names(x$value),
                             fixed = TRUE),
                      drop = FALSE]
  names(tmpData) <- gsub(paste("~", metric, sep = ""),
                         "",
                         names(tmpData),
                         fixed = TRUE)
  rng <- range(unlist(lapply(lapply(tmpData, as.numeric), range)))
  prng <- pretty(rng)

  reord <- order(apply(tmpData, 2, median))
  tmpData <- tmpData[, reord]

  parallel(~tmpData,
           common.scale = TRUE,
           scales = list(x = list(at = (prng-min(rng))/diff(rng), labels = prng)),
           xlab = useMathSymbols(metric),
           ...)
    
}

splom.resamples <- function (x, data = NULL, models = x$models, metric = x$metric[1], panelRange = NULL, ...) 
{
  if(length(metric) != 1) stop("exactly one metric must be given")

  tmpData <- x$values[, grep(paste("~", metric, sep = ""),
                             names(x$value),
                             fixed = TRUE),
                      drop = FALSE]
  names(tmpData) <- gsub(paste("~", metric, sep = ""),
                         "",
                         names(tmpData),
                         fixed = TRUE)
  if(is.null(panelRange)) panelRange <- extendrange(tmpData)
  splom(~tmpData,
        panel = function(x, y)
        {
          panel.splom(x, y, ...)
          panel.abline(0, 1, lty = 2, col = "darkgrey")

          },
        main = useMathSymbols(metric),
        prepanel.limits = function(x) panelRange,
        ...)
                         
}


densityplot.resamples <- function (x, data = NULL, models = x$models, metric = x$metric, ...) 
{
  plotData <- melt(x$values, id.vars = "Resample")
  tmp <- strsplit(as.character(plotData$variable), "~", fixed = TRUE)
  plotData$Model <- unlist(lapply(tmp, function(x) x[1]))
  plotData$Metric <- unlist(lapply(tmp, function(x) x[2]))
  plotData <- subset(plotData, Model %in% models & Metric  %in% metric)


  densityplot(~value|Metric, data = plotData, groups = Model, xlab = "", ...)
                         
}



bwplot.resamples <- function (x, data = NULL, models = x$models, metric = x$metric, ...) 
{
  plotData <- melt(x$values, id.vars = "Resample")
  tmp <- strsplit(as.character(plotData$variable), "~", fixed = TRUE)
  plotData$Model <- unlist(lapply(tmp, function(x) x[1]))
  plotData$Metric <- unlist(lapply(tmp, function(x) x[2]))
  plotData <- subset(plotData, Model %in% models & Metric  %in% metric)

  bwplot(Model~value|Metric, data = plotData,
         xlab = "", ...)
                         
}



dotplot.resamples <- function (x, data = NULL, models = x$models, metric = x$metric, conf.level = 0.95, ...) 
{
  plotData <- melt(x$values, id.vars = "Resample")
  tmp <- strsplit(as.character(plotData$variable), "~", fixed = TRUE)
  plotData$Model <- unlist(lapply(tmp, function(x) x[1]))
  plotData$Metric <- unlist(lapply(tmp, function(x) x[2]))
  plotData <- subset(plotData, Model %in% models & Metric  %in% metric)
  plotData$variable <- factor(as.character(plotData$variable))

  plotData <- split(plotData, plotData$variable)
  results <- lapply(plotData,
                    function(x, cl)
                    {
                      ttest <- t.test(x$value, conf.level = cl)
                      out <- c(ttest$conf.int, ttest$estimate)
                      names(out) <- c("LowerLimit", "UpperLimit", "Estimate")
                      out
                    },
                    cl = conf.level)
  results <- do.call("rbind", results)
  results <- melt(results)
  tmp <- strsplit(as.character(results$X1), "~", fixed = TRUE)
  results$Model <- unlist(lapply(tmp, function(x) x[1]))
  results$Metric <- unlist(lapply(tmp, function(x) x[2]))
  dotplot(Model ~ value|Metric,
         data = results,
         xlab = "",
         panel = function(x, y)
         {
           plotTheme <- trellis.par.get()
           y <- as.numeric(y)
           
           vals <- aggregate(x, list(group = y), function(x) c(min = min(x), mid = median(x), max = max(x)))
         
           panel.dotplot(vals$x[,"mid"], vals$group,
                        pch = plotTheme$plot.symbol$pch,
                        col = plotTheme$plot.symbol$col)
           panel.segments(vals$x[,"min"], vals$group, 
                          vals$x[,"max"], vals$group, 
                          lty = plotTheme$plot.line$lty,
                        col = plotTheme$plot.line$col,
                          lwd = plotTheme$plot.line$lwd)
          
         },
          sub = paste("Confidence Level:", conf.level),
         ...)
  
}


diff.resamples <- function(x,
                           models = x$models,
                           metric = x$metrics,
                           test = t.test,
                           ...)
  {

    allDif <- vector(mode = "list", length = length(metric))
    names(allDif) <- metric

    allStats <- allDif
    
    for(h in seq(along = metric))
      {
        index <- 0
        dif <- matrix(NA,
                      nrow = nrow(x$values),
                      ncol = choose(length(models), 2))
        stat <- vector(mode = "list", length = choose(length(models), 2))
        
        colnames(dif) <- paste("tmp", 1:ncol(dif), sep = "")
        for(i in seq(along = models))
          {
            for(j in seq(along = models))
              {
                if(i < j)
                  {
                    index <- index + 1
                    
                    left <- paste(models[i], metric[h], sep = "~")
                    right <- paste(models[j], metric[h], sep = "~")
                    
                                        # cat(right, left, "\n")
                    dif[,index] <- x$values[,left] - x$values[,right]
                    colnames(dif)[index] <- paste(models[i], models[j], sep = ".diff.")
                  }
              }
          }

        stats <- apply(dif, 2, function(x, tst, ...) tst(x, ...), tst = test, ...)
        
        allDif[[h]] <- dif
        allStats[[h]] <- stats
      }
    out <- structure(
                     list(
                          call = match.call(),
                          difs = allDif,
                          statistics = allStats,
                          models = models,
                          metric = metric),
                     class = "diff.resamples")
    out
  }


densityplot.diff.resamples <- function(x, data, metric = x$metric, ...)
  {
    plotData <- lapply(x$difs,
                       function(x) stack(as.data.frame(x)))
    plotData <- do.call("rbind", plotData)
    plotData$Metric <- rep(x$metric, each = length(x$difs[[1]]))
    plotData$ind <- gsub(".diff.", " - ", plotData$ind, fixed = TRUE)
    plotData <- subset(plotData, Metric %in% metric)
         densityplot(~ values|Metric, data = plotData, groups = ind,
                     xlab = "", ...)

  }


bwplot.diff.resamples <- function(x, data, metric = x$metric, ...)
  {
    plotData <- lapply(x$difs,
                       function(x) stack(as.data.frame(x)))
    plotData <- do.call("rbind", plotData)
    plotData$Metric <- rep(x$metric, each = length(x$difs[[1]]))
    plotData$ind <- gsub(".diff.", " - ", plotData$ind, fixed = TRUE)
    plotData <- subset(plotData, Metric %in% metric)
    bwplot(ind ~ values|Metric,
           data = plotData,
           xlab = "",
           ...)

  }

print.diff.resamples <- function(x, ...)
  {
    cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")
    cat("Models:", paste(x$models, collapse = ", "), "\n")
    cat("Metrics:", paste(x$metric, collapse = ", "), "\n")
    cat("Number of differences:",  ncol(x$difs[[1]]), "\n")
    invisible(x)
  }


summary.diff.resamples <- function(object, digits = max(3, getOption("digits") - 3), ...)
{
  comps <- ncol(object$difs[[1]])

  
  all <- vector(mode = "list", length = length(object$metric))
  names(all) <- object$metric

  for(h in seq(along = object$metric))
    {
      pvals <- matrix(NA, nrow = length(object$models), ncol = length( object$models))
      meanDiff <- pvals
      index <- 0
      for(i in seq(along = object$models))
        {
          for(j in seq(along = object$models))
            {
              
              if(i < j)
                {
                  index <- index + 1
                  meanDiff[i, j] <- object$statistics[[h]][index][[1]]$estimate
                }
            }
        }
      
      index <- 0
      for(i in seq(along = object$models))
        {
          for(j in seq(along = object$models))
            {
              
              if(i < j)
                {
                  index <- index + 1
                  pvals[j, i] <- object$statistics[[h]][index][[1]]$p.value

                }
            }
        }
      asText <- matrix("", nrow = length(object$models), ncol = length( object$models))
      meanDiff2 <- format(meanDiff, digits = digits)
      pvals2 <- matrix(format.pval(pvals, digits = digits), nrow = length( object$models))
      asText[upper.tri(asText)] <- meanDiff2[upper.tri(meanDiff2)]
      asText[lower.tri(asText)] <- pvals2[lower.tri(pvals2)]
      diag(asText) <- ""
      colnames(asText) <- object$models
      rownames(asText) <- object$models
      all[[h]] <- asText
    }  
  
  out <- structure(
                   list(
                        call = match.call(),
                        table = all),
                   class = "summary.diff.resamples")
  out
}


levelplot.diff.resamples <- function(x, data = NULL, metric = x$metric[1], what = "pvalues", ...)
{
  comps <- ncol(x$difs[[1]])
  if(length(metric) != 1) stop("exactly one metric must be given")
  
  all <- vector(mode = "list", length = length(x$metric))
  names(all) <- x$metric

  for(h in seq(along = x$metric))
    {
      temp <- matrix(NA, nrow = length(x$models), ncol = length( x$models))
      index <- 0
      for(i in seq(along = x$models))
        {
          for(j in seq(along = x$models))
            {
              
              if(i < j)
                {
                  index <- index + 1
                   temp[i, j] <-  if(what == "pvalues")
                     {
                       x$statistics[[h]][index][[1]]$p.value
                     } else x$statistics[[h]][index][[1]]$estimate
                 temp[j, i] <- temp[i, j] 
                }
            }
        }
      colnames(temp) <- x$models
      temp  <- as.data.frame(temp)
      temp$A <- x$models
      temp$Metric <- x$metric[h]
      all[[h]] <- temp
    }
  all <- do.call("rbind", all)
  all <- melt(all, measure.vars = x$models)
  names(all)[names(all) == "variable"] <- "B"
  all$A <- factor(all$A, levels = x$models)
  all$B <- factor(as.character(all$B), levels = x$models)
  
  all <- all[complete.cases(all),]
  levelplot(value ~ A + B|Metric,
            data = all,
            subset = Metric %in% metric,
            xlab = "",
            ylab = "",
            sub = ifelse(what == "pvalues", "p-values", "difference = (x axis - y axis)"),
            ...)
}




print.summary.diff.resamples <- function(x, ...)
  {
    cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")

    cat("Upper diagonal: estimates of the difference\n",
        "Lower diagonal: p-value for H0: difference = 0\n\n",
        sep = "")
        
    for(i in seq(along = x$table))
      {
        cat(names(x$table)[i], "\n")
        print(x$table[[i]], quote = FALSE)
        cat("\n")
      }
    invisible(x)
  }


dotplot.diff.resamples <- function(x, data = NULL, metric = x$metric[1], ...)
  {
    if(length(metric) > 1)
      {
        metric <- metric[1]
        warning("Sorry Dave, only one value of metric is allowed right now. I'll use the first value")

      }
    h <- which(x$metric == metric)
    plotData <- as.data.frame(matrix(NA, ncol = 3, nrow = ncol(x$difs[[metric]])))
    ## Get point and interval estimates on the differences
    index <- 0
    for(i in seq(along = x$models))
      {
        for(j in seq(along = x$models))
          {
            
            if(i < j)
              {
                index <- index + 1
                plotData[index, 1] <- x$statistics[[h]][index][[1]]$estimate
                plotData[index, 2:3] <- x$statistics[[h]][index][[1]]$conf.int

              }
          }
      }
    names(plotData)[1:3] <- c("Estimate", "LowerLimit", "UpperLimit")
    plotData$Difference <- gsub(".diff.", " - ", colnames(x$difs[[metric]]), fixed = TRUE)
    plotData <- melt(plotData, id.vars = "Difference")
    plotData
    dotplot(Difference ~ value,
            data = plotData,
            xlab = paste("Difference in", useMathSymbols(metric)),
            panel = function(x, y)
            {
              plotTheme <- trellis.par.get()
              panel.dotplot(x, y, type = "n")
              panel.abline(v = 0,
                           col = plotTheme$reference.line$col[1],
                           lty = plotTheme$reference.line$lty[1],
                           lwd = plotTheme$reference.line$lwd[1])

              middle <- aggregate(x, list(mod = y), median)
              upper <- aggregate(x, list(mod = as.numeric(y)), max)
              lower <- aggregate(x, list(mod = as.numeric(y)), min)
              for(i in seq(along = upper$mod)) panel.segments(upper$x[i], upper$mod[i], lower$x[i], lower$mod[i],
                             col = plotTheme$plot.line$col[1],
                             lwd = plotTheme$plot.line$lwd[1],
                             lty = plotTheme$plot.line$lty[1])
                

              panel.dotplot(middle$x, middle$mod)
            },
            ...)
  }


if(FALSE)
  {

    library(caret)
    data(BloodBrain)



    set.seed(1)
    tmp <- createDataPartition(logBBB,
                               p = .8,
                               times = 5)
    bbbDescr2 <- scale(bbbDescr[, apply(bbbDescr, 2, function(x) length(unique(x)) > 1)])

    rpartFit <- train(bbbDescr, logBBB,
                      "rpart", 
                      tuneLength = 16,
                      trControl = trainControl(method = "LGOCV", index = tmp))


    ctreeFit <- train(bbbDescr, logBBB,
                      "ctree2",
                      tuneLength = 5,
                      trControl = trainControl(method = "LGOCV", index = tmp))

    m5Fit <- train(bbbDescr, logBBB,
                   "M5Rules",
                   trControl = trainControl(method = "LGOCV", index = tmp))    


    earthFit <- train(bbbDescr, logBBB,
                      "earth",
                      tuneLength = 10,
                      trControl = trainControl(method = "LGOCV", index = tmp))



    bagEarthFit <- train(bbbDescr, logBBB,
                         "bagEarth",
                         tuneLength = 10,
                         trControl = trainControl(method = "LGOCV", index = tmp))

    rfFit <- train(bbbDescr, logBBB,
                   "rf",
                   tuneLength = 5,
                   trControl = trainControl(method = "LGOCV", index = tmp))

    crfFit <- train(bbbDescr, logBBB,
                    "cforest",
                    tuneLength = 5,
                    trControl = trainControl(method = "LGOCV", index = tmp))

    gbmFit <- train(bbbDescr, logBBB,
                    "gbm",
                    tuneGrid = expand.grid(
                      .interaction.depth = -1 + (1:5) * 2,
                      .n.trees = 20 * (1:20),
                      .shrinkage = .1),
                    verbose = FALSE,
                    trControl = trainControl(method = "LGOCV", index = tmp))

    svmRFit <- train(bbbDescr2, logBBB,
                    "svmRadial",
                    tuneLength = 5,
                    trControl = trainControl(method = "LGOCV", index = tmp))

    svmLFit <- train(bbbDescr2, logBBB,
                    "svmLinear",
                    tuneLength = 5,
                    trControl = trainControl(method = "LGOCV", index = tmp))    

    plsFit <- train(bbbDescr2, logBBB,
                    "pls",
                    tuneLength = 15,
                    trControl = trainControl(method = "LGOCV", index = tmp))


    lmFit <- train(bbbDescr2, logBBB,
                    "lm",
                    trControl = trainControl(method = "LGOCV", index = tmp))       
    

    resamps <- resamples(list(CART = rpartFit,
                              CondInfTree = ctreeFit,
                              MARS = earthFit,
                              M5 = m5Fit,
                              rf = rfFit,
                              crf = crfFit,
                              pls = plsFit,
                              svmL = svmLFit,
                              svmR = svmRFit,
                              bagMARS = bagEarthFit,
                              gbm = gbmFit))
    

    resamps
    bwplot(resamps, metric = "RMSE")
    densityplot(resamps,
                auto.key = list(columns = 3),
                pch = "|")
    splom(resamps, metric = "RMSE")

    summary(resamps)
    
    difValues <- diff(resamps)

    summary(difValues)

    dotplot(difValues)
    densityplot(difValues,
                metric = "RMSE",
                auto.key = TRUE,
                pch = "|")

    save(rpartFit, earthFit, ctreeFit, m5Fit, file = "~/tmp/exampleModels.RData")

    ## add to caret web page and provide link

  }

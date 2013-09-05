"plot.train" <-  function(x,
                    plotType = "scatter",
                    metric = x$perfNames[1],
                    digits = getOption("digits") - 3,
                    xTrans = NULL,
                    ...)
  {
    

    ## Error trap
    if(!(plotType %in% c("level", "scatter", "line"))) stop("plotType must be either level, scatter or line")
    
    cutpoints <- c(0, 1.9, 2.9, 3.9, Inf)
    
    ## define some functions
    prettyVal <- function(u, dig, Name = NULL)
      { 
        if(is.numeric(u))
          {
            if(!is.null(Name)) u <- paste(gsub(".", " ", Name, fixed = TRUE),
                                          ": ", 
                                          format(u, digits = dig), sep = "")
            return(factor(u))
          } else return(if(!is.factor(u)) as.factor(u) else u)
      }

    ## Get tuning parameter info

    if(x$method == "custom")
      {
        pNames <- gsub("^\\.", "", names(x$bestTune))
        modelInfo <- data.frame(model = "custom",
                                parameter = pNames,
                                label = pNames,
                                stringsAsFactors = FALSE)
      } else modelInfo <- modelLookup(x$method)
    params <- modelInfo$parameter


    
    plotIt <- "yes"
    if(all(params == "parameter"))
      {
        plotIt <- "There are no tuning parameters for this model."
      } else {
        dat <- x$results

        ## Some exceptions for pretty printing
        if(x$method == "nb") dat$usekernel <- factor(ifelse(dat$usekernel, "Nonparametric", "Gaussian"))
        if(x$method == "gam") dat$select <- factor(ifelse(dat$select, "Feature Selection", "No Feature Selection"))
        if(x$method == "qrnn") dat$bag <- factor(ifelse(dat$bag, "Bagging", "No Bagging"))
        if(x$method == "C5.0") dat$winnow <- factor(ifelse(dat$winnow, "Winnowing", "No Winnowing"))
##        if(x$method %in% c("M5Rules", "M5", "PART")) dat$pruned <- factor(ifelse(dat$pruned == "Yes", "Pruned", "Unpruned"))
##        if(x$method %in% c("M5Rules", "M5")) dat$smoothed <- factor(ifelse(dat$smoothed == "Yes", "Smoothed", "Unsmoothed"))
        if(x$method == "M5") dat$rules <- factor(ifelse(dat$rules == "Yes", "Rules", "Trees"))
##        if(x$method == "vbmpRadial") dat$estimateTheta <- factor(ifelse(dat$estimateTheta == "Yes", "Estimate Theta", "Do Not Estimate Theta"))


        ## Check to see which tuning parameters were varied        
        
        paramValues <- apply(dat[,params,drop = FALSE],
                             2,
                             function(x) length(unique(x)))
        ##paramValues <- paramValues[order(paramValues)]
        if(any(paramValues > 1))
          {
            params <- names(paramValues)[paramValues > 1]
          } else plotIt <- "There are no tuning parameters with more than 1 value."         
      }

    if(plotIt == "yes")
      {
        p <- length(params)
        dat <- dat[, c(metric, params)]
        
        ## The conveintion is that the first parameter (in
        ## position #2 of dat) is plotted on the x-axis,
        ## the second parameter is the grouping variable
        ## and the rest are conditioning variables
        if(!is.null(xTrans) & plotType == "scatter") dat[,2] <- xTrans(dat[,2])

        ## We need to pretty-up some of the values of grouping
        ## or conditioning variables


        resampName <- switch(tolower(x$control$method),
                             boot = "(Bootstrap)",
                             boot632 = "(Bootstrap 632 Rule)",
                             cv = "(Cross-Validation)",
                             repeatedcv = "(Repeated Cross-Validation)",
                             lgocv = "(Repeated Train/Test Splits)")
        
        if(plotType %in% c("line", "scatter"))
          {

            if(plotType == "scatter")
              {
                if(p >= 2) for(i in 3:ncol(dat))
                  dat[,i] <- prettyVal(dat[,i], dig = digits, Name = if(i > 3) params[i-1] else  NULL)
              } else {
                for(i in 2:ncol(dat))
                  dat[,i] <- prettyVal(dat[,i], dig = digits, Name = if(i > 3) params[i-1] else  NULL)
              }
            for(i in 2:ncol(dat)) if(is.logical(dat[,i])) dat[,i] <- factor(dat[,i])
            
            ## make formula
            form <- if(p <= 2)
              {          
                as.formula(
                           paste(metric, "~", params[1], sep = ""))
              } else as.formula(paste(metric, "~", params[1], "|",
                                      paste(params[-(1:2)], collapse = "*"),
                                      sep = ""))
            defaultArgs <- list(x = form,
                                data = dat,
                                groups = if(p > 1) dat[,params[2]] else NULL)
            if(length(list(...)) > 0) defaultArgs <- c(defaultArgs, list(...))
            lNames <- names(defaultArgs)
            if(!("ylab" %in% lNames))  defaultArgs$ylab <- paste(metric, resampName)
            
            if(!("type" %in% lNames) & plotType == "scatter") defaultArgs$type <- c("g", "o")
            if(!("type" %in% lNames) & plotType == "line") defaultArgs$type <- c("g", "o")
            paramLabs <- subset(modelInfo, parameter %in% params)$label    
            if(p > 1)
              {
                ## I apologize in advance for the following 3 line kludge. 
                groupCols <- 4
                if(length(unique(dat[,3])) < 4) groupCols <- length(unique(dat[,3]))
                if(length(unique(dat[,3])) %in% 5:6) groupCols <- 3
                
                groupCols <- as.numeric(
                                        cut(length(unique(dat[,3])),
                                            cutpoints,
                                            include.lowest = TRUE))
                
                if(!(any(c("key", "auto.key") %in% lNames)))
                  defaultArgs$auto.key <- list(columns = groupCols, lines = TRUE, title = paramLabs[2], cex.title = 1)
              }
            if(!("xlab" %in% lNames)) defaultArgs$xlab <- paramLabs[1]
            
            if(plotType == "scatter")
              {
                out <- do.call("xyplot", defaultArgs)
              } else {
                ## line plot #########################
                out <- do.call("stripplot", defaultArgs)
              }
            
          }

        if(plotType == "level")
          {
            if(p == 1) stop("There must be at least 2 tuning parameters with multiple values")

            for(i in 2:ncol(dat))
              dat[,i] <- prettyVal(dat[,i], dig = digits, Name = if(i > 3) params[i-1] else  NULL)
            
            ## make formula
            form <- if(p <= 2)
              {          
                as.formula(paste(metric, "~", params[1], "*", params[2], sep = ""))
              } else as.formula(paste(metric, "~", params[1], "*", params[2], "|",
                                      paste(params[-(1:2)], collapse = "*"),
                                      sep = ""))
            defaultArgs <- list(x = form, data = dat)
            if(length(list(...)) > 0) defaultArgs <- c(defaultArgs, list(...))
            lNames <- names(defaultArgs)
            if(!("sub" %in% lNames)) defaultArgs$sub <- paste(metric, resampName)

            paramLabs <- subset(modelInfo, parameter %in% params)$label    
            if(!("xlab" %in% lNames)) defaultArgs$xlab <- paramLabs[1]
            if(!("ylab" %in% lNames)) defaultArgs$ylab <- paramLabs[2]

            
            
            out <- do.call("levelplot", defaultArgs)
          }        
        
      } else stop(plotIt)
 
    out
    

  }


modelInfo <- list(label = "Neural Networks with Feature Extraction",
                  library = "nnet",
                  loop = NULL,
                  type = c("Classification", "Regression"),
                  parameters = data.frame(parameter = c('size', 'decay'),
                                          class = rep("numeric", 2),
                                          label = c('#Hidden Units', 'Weight Decay')),
                  grid = function(x, y, len = NULL) expand.grid(size = ((1:len) * 2) - 1, 
                                                                decay = c(0, 10 ^ seq(-1, -4, length = len - 1))),
                  fit = function(x, y, wts, param, lev, last, classProbs, ...) {
                    library(nnet)
                    dat <- x
                    dat$.outcome <- y
                    if(!is.null(wts))
                    {
                      out <- pcaNNet(.outcome ~ .,
                                     data = dat,
                                     weights = wts,                                       
                                     size = param$size,
                                     decay = param$decay,
                                     ...)
                    } else out <- pcaNNet(.outcome ~ .,
                                          data = dat,
                                          size = param$size,
                                          decay = param$decay,
                                          ...)
                    out
                  },
                  predict = function(modelFit, newdata, submodels = NULL)
                  {
                    if(modelFit$problemType == "Classification")
                    {
                      out <- predict(modelFit, newdata, type="class")
                    } else {
                      out  <- predict(modelFit, newdata, type="raw")
                    }
                    out
                  },
                  prob = function(modelFit, newdata, submodels = NULL){
                    out <- predict(modelFit, newdata)
                    if(ncol(as.data.frame(out)) == 1)
                    {
                      out <- cbind(out, 1-out)
                      dimnames(out)[[2]] <-  rev(modelFit$obsLevels)
                    }
                    out
                  },
                  predictors = function(x, ...) rownames(x$pc$rotation),
                  levels = function(x) x$model$lev,
                  tags = c("Neural Network", "Feature Extraction", "L2 Regularization"),
                  sort = function(x) x[order(x$size, -x$decay),])

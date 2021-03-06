\name{plotClassProbs}
\alias{plotClassProbs}
\title{Plot Predicted Probabilities in Classification Models}
\description{
  This function takes an object (preferably from the function \code{\link{extractProb}})
  and creates a lattice plot.  
  
  If the call to \code{\link{extractProb}} included test data, these data are shown, but
  if unknowns were also included, these are not plotted
  
}
\usage{
plotClassProbs(object,
               plotType = "histogram",
               useObjects = FALSE,
               ...)
}
\arguments{
  \item{object}{an object (preferably from the function \code{\link{extractProb}}. There 
  should be columns for each level of the class factor and columns named \code{obs}, \code{pred}, \code{model} (e.g. "rpart", "nnet" etc), 
  \code{dataType} (e.g. "Training", "Test" etc) and optionally \code{objects} (for giving names to objects with the same model type).}
  \item{plotType}{either "histogram" or "densityplot"}
  \item{useObjects}{a logical; should the object name (if any) be used as a conditioning variable?}
  \item{\dots}{parameters to pass to   \code{\link[lattice]{histogram}} or \code{\link[lattice]{densityplot}}}
}

\value{
   A lattice object. Note that the plot has to be printed to be displayed (especially in a loop).
}
\author{Max Kuhn}

\examples{
\dontrun{
data(mdrr)
set.seed(90)
inTrain <- createDataPartition(mdrrClass, p = .5)[[1]]

trainData <- mdrrDescr[inTrain,1:20]
testData <- mdrrDescr[-inTrain,1:20]

trainY <- mdrrClass[inTrain]
testY <- mdrrClass[-inTrain]

ctrl <- trainControl(method = "cv")

nbFit1 <- train(trainData, trainY, "nb",
                trControl = ctrl,
                tuneGrid = data.frame(.usekernel = TRUE, .fL = 0))

nbFit2 <- train(trainData, trainY, "nb",
                trControl = ctrl,
                tuneGrid = data.frame(.usekernel = FALSE, .fL = 0))


models <- list(para = nbFit2,
               nonpara = nbFit1)

predProbs <- extractProb(models,
                         testX = testData, 
                         testY = testY)

plotClassProbs(predProbs,
               useObjects = TRUE)
plotClassProbs(predProbs,
               subset = object == "para" & dataType == "Test")
plotClassProbs(predProbs,
               useObjects = TRUE,
               plotType = "densityplot",
               auto.key = list(columns = 2))
}


}

\keyword{hplot}

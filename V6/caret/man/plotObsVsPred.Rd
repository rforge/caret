\name{plotObsVsPred}
\alias{plotObsVsPred}
\title{Plot Observed versus Predicted Results in Regression
   and Classification Models}
\description{
  This function takes an object (preferably from the function \code{\link{extractPrediction}})
  and creates a lattice plot. For numeric outcomes, the observed and predicted data are plotted
  with a 45 degree reference line and a smoothed fit. For factor outcomes, a dotplot plot is 
  produced with the accuracies for the different models. 
  
  If the call to \code{\link{extractPrediction}} included test data, these data are shown, but
  if unknowns were also included, they are not plotted
  
}
\usage{
plotObsVsPred(object, equalRanges = TRUE, ...)
}
\arguments{
  \item{object}{an object (preferably from the function \code{\link{extractPrediction}}. There 
  should be columns named \code{obs}, \code{pred}, \code{model} (e.g. "rpart", "nnet" etc)
  and \code{dataType} (e.g. "Training", "Test" etc) }
  \item{equalRanges}{a logical; should teh x- and y-axis ranges be the same?}
  \item{\dots}{parameters to pass to   \code{\link[lattice]{xyplot}} or \code{\link[lattice:xyplot]{dotplot}}, such as  \code{auto.key}}
}

\value{
   A lattice object. Note that the plot has to be printed to be displayed (especially in a loop).
}
\author{Max Kuhn}

\examples{
\dontrun{
# regression example
data(BostonHousing)
rpartFit <- train(BostonHousing[1:100, -c(4, 14)], 
                  BostonHousing$medv[1:100], 
                  "rpart", tuneLength = 9)
plsFit <- train(BostonHousing[1:100, -c(4, 14)], 
                BostonHousing$medv[1:100], 
                "pls")

predVals <- extractPrediction(list(rpartFit, plsFit), 
                              testX = BostonHousing[101:200, -c(4, 14)], 
                              testY = BostonHousing$medv[101:200], 
                              unkX = BostonHousing[201:300, -c(4, 14)])

plotObsVsPred(predVals)


#classification example
data(Satellite)
numSamples <- dim(Satellite)[1]
set.seed(716)

varIndex <- 1:numSamples

trainSamples <- sample(varIndex, 150)

varIndex <- (1:numSamples)[-trainSamples]
testSamples <- sample(varIndex, 100)

varIndex <- (1:numSamples)[-c(testSamples, trainSamples)]
unkSamples <- sample(varIndex, 50)

trainX <- Satellite[trainSamples, -37]
trainY <- Satellite[trainSamples, 37]

testX <- Satellite[testSamples, -37]
testY <- Satellite[testSamples, 37]

unkX <- Satellite[unkSamples, -37]

knnFit  <- train(trainX, trainY, "knn")
rpartFit <- train(trainX, trainY, "rpart")

predTargets <- extractPrediction(list(knnFit, rpartFit), 
                                 testX = testX, 
                                 testY = testY, 
                                 unkX = unkX)

plotObsVsPred(predTargets)
}
}
\keyword{hplot}

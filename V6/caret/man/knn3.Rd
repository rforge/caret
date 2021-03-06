\name{knn3}
\alias{knn3}
\alias{knn3.formula}
\alias{knn3.matrix}
\alias{knn3.data.frame}
\alias{knn3Train}
\title{ k-Nearest Neighbour Classification }
\description{
  $k$-nearest neighbour classification that can return class votes for all classes.
}
\usage{
\method{knn3}{formula}(formula, data, subset, na.action, k = 5, ...) 

\method{knn3}{matrix}(x, y, k = 5, ...)

\method{knn3}{data.frame}(x, y, k = 5, ...)

knn3Train(train, test, cl, k=1, l=0, prob = TRUE, use.all=TRUE)

}
\arguments{
  \item{formula}{a formula of the form \code{lhs ~ rhs} where \code{lhs} 
                 is the response variable and \code{rhs} a set of
                 predictors.}
  \item{data}{optional data frame containing the variables in the
              model formula.} 
  \item{subset}{optional vector specifying a subset of observations
                to be used.}
  \item{na.action}{function which indicates what should happen when
                   the data contain \code{NA}s.}
  \item{k}{number of neighbours considered.}
  
  \item{x}{a matrix of training set predictors}

  \item{y}{a factor vector of training set classes}

  \item{...}{additional parameters to pass to \code{knn3Train}. However, passing
  \code{prob = FALSE} will be over--ridden.}
  
  \item{train}{matrix or data frame of training set cases.}
  
  \item{test}{matrix or data frame of test set cases. A vector will be interpreted
  as a row vector for a single case.}
  
  \item{cl}{factor of true classifications of training set}

  \item{l}{minimum vote for definite decision, otherwise \code{doubt}. (More
  precisely, less than \code{k-l} dissenting votes are allowed, even if \code{k}
  is increased by ties.)}

  \item{prob}{
  If this is true, the proportion of the votes for each class
  are returned as attribute \code{prob}.}
  
  \item{use.all}{controls handling of ties. If true, all distances equal to the \code{k}th
  largest are included. If false, a random selection of distances
  equal to the \code{k}th is chosen to use exactly \code{k} neighbours.}  
}

\details{
  \code{knn3} is essentially the same code as \code{\link[ipred]{ipredknn}}
  and \code{knn3Train} is a copy of \code{\link[class]{knn}}. The underlying 
  C code from the \code{class} pacakge has been modifed to return the vote
  percentages for each class (previously the percentage for the winning 
  class was returned).
  
}

\value{
  An object of class \code{knn3}. See \code{\link{predict.knn3}}.
}

\author{\code{\link[class]{knn}} by  W. N. Venables and B. D. Ripley and 
\code{\link[ipred]{ipredknn}} by 
Torsten.Hothorn <Torsten.Hothorn@rzmail.uni-erlangen.de>,
modifications by Max Kuhn and Andre Williams }

\examples{
irisFit1 <- knn3(Species ~ ., iris)

irisFit2 <- knn3(as.matrix(iris[, -5]), iris[,5])

data(iris3)
train <- rbind(iris3[1:25,,1], iris3[1:25,,2], iris3[1:25,,3])
test <- rbind(iris3[26:50,,1], iris3[26:50,,2], iris3[26:50,,3])
cl <- factor(c(rep("s",25), rep("c",25), rep("v",25)))
knn3Train(train, test, cl, k = 5, prob = TRUE) 
}
\keyword{multivariate}

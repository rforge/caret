\name{lift}
\alias{lift}
\alias{lift.formula}
\alias{lift.default}
\alias{xyplot.lift}
\title{
Lift Plot
}
\description{
For classification models, this function creates a 'lift plot' that describes how well a model ranks samples for one class
}
\usage{

lift(x, ...)

\method{lift}{formula}(x, data = NULL, class = NULL,
     subset = TRUE, lattice.options = NULL, labels = NULL, 
     ...)

\method{xyplot}{lift}(x, data, plot = "gain", values = NULL, ...)

}
\arguments{
  \item{x}{
a \code{lattice} formula (see \code{\link[lattice:xyplot]{xyplot}} for syntax) where the left-hand side of the formula is a factor class variable of the observed outcome and the right-hand side specifies one or model columns corresponding to a numeric ranking variable for a model (e.g. class probabilities). The classification variable should have two levels. 
}
  \item{data}{
For \code{lift.formula}, a data frame (or more precisely, anything that is a valid \code{envir} argument in \code{eval}, e.g., a list or an environment) containing values for any variables in the formula, as well as \code{groups} and \code{subset} if applicable. If not found in \code{data}, or if \code{data} is unspecified, the variables are looked for in the environment of the formula. This argument is not used for \code{xyplot.lift}.
}
  \item{class}{
a character string for the class of interest
}
  \item{subset}{
An expression that evaluates to a logical or integer indexing vector. It is evaluated in \code{data}. Only the resulting rows of \code{data} are used for the plot. 
}
  \item{lattice.options}{
A list that could be supplied to \code{\link[lattice:lattice.options]{lattice.options}} 
}
  \item{labels}{
A named list of labels for keys. The list should have an element for each term on the right-hand side of the formula and the names should match the names of the models.
}
  \item{plot}{
Either "gain" (the default) or "lift". The former plots the number of samples called events versus the event rate while the latter shows the event cut-off versus the lift statistic.}
 \item{values}{
A vector of numbers between 0 and 100 specifying reference values for the percentage of samples found (i.e. the y-axis). Corresponding points on the x-axis are found via interpolation and line segments are shown to indicate how many samples must be tested before these percentages are found. The lines use either the \code{plot.line} or \code{superpose.line} component of the current lattice theme to draw the lines (depending on whether groups were used. These values are only used when \code{type = "gain"}.}
  \item{\dots}{
options to pass through to \code{\link[lattice:xyplot]{xyplot}} or the panel function (not used in \code{lift.formula}).
}
}
\details{
\code{lift.formula} is used to process the data and \code{xyplot.lift} is used to create the plot.

To construct data for the the lift and gain plots, the following steps are used for each model:

\enumerate{
   \item The data are ordered by the numeric model prediction used on the right-hand side of the model formula
   \item Each unque value of the score is treated as a cut point
   \item The number of samples with true results equal to \code{class} are determined
   \item The lift is calculated as the ratio of the percentage of samples in each split corresponding to \code{class} over the same percentage in the entire data set}
\code{lift} with \code{plot = "gain"} produces a plot of the cumulative lift values by the percentage of samples evaluated while \code{plot = "lift"} shows the cut point value versus the lift statistic. 

This implementation uses the \pkg{lattice} function \code{\link[lattice:xyplot]{xyplot}}, so plot elements can be changed via panel functions, \code{\link[lattice:trellis.par.get]{trellis.par.set}} or other means. \code{lift} uses the panel function \code{\link{panel.lift2}} by default, but it can be changes using \code{\link[lattice:update.trellis]{update.trellis}} (see the examples in \code{\link{panel.lift2}}).

The following elements are set by default in the plot but can be changed by passing new values into \code{xyplot.lift}: \code{xlab = "\% Samples Tested"}, \code{ylab = "\% Samples Found"}, \code{type = "S"}, \code{ylim = extendrange(c(0, 100))} and \code{xlim = extendrange(c(0, 100))}.

}
\value{
\code{lift.formula} returns a list with elements:
  \item{data}{the data used for plotting}
  \item{cuts}{the number of cuts}
  \item{class}{the event class}
  \item{probNames}{the names of the model probabilities}
  \item{pct}{the baseline event rate}

\code{xyplot.lift} returns a \pkg{lattice} object
}

\author{
Max Kuhn, some \pkg{lattice} code and documentation by Deepayan Sarkar
}

\seealso{
\code{\link[lattice:xyplot]{xyplot}}, \code{\link[lattice:trellis.par.get]{trellis.par.set}}} 

\examples{
set.seed(1)
simulated <- data.frame(obs = factor(rep(letters[1:2], each = 100)),
                        perfect = sort(runif(200), decreasing = TRUE),
                        random = runif(200))

lift1 <- lift(obs ~ random, data = simulated)
lift1
xyplot(lift1)

lift2 <- lift(obs ~ random + perfect, data = simulated)
lift2
xyplot(lift2, auto.key = list(columns = 2))

xyplot(lift2, auto.key = list(columns = 2), value = c(10, 30))

xyplot(lift2, plot = "lift", auto.key = list(columns = 2))
}
\keyword{hplot}
library(caret)
timestamp <- format(Sys.time(), "%Y_%m_%d_%H_%M")

model <- "krlsPoly"

#########################################################################

data(BloodBrain)
bbbDescr <-bbbDescr[, -nearZeroVar(bbbDescr)]
bbbDescr <-bbbDescr[, -findCorrelation(cor(bbbDescr), .5)]

set.seed(2)

inTrain <- createDataPartition(logBBB, p = .90)
trainX <-bbbDescr[inTrain[[1]], ]
trainY <- logBBB[inTrain[[1]]]
testX <- bbbDescr[-inTrain[[1]], ]
testY <- logBBB[-inTrain[[1]]]

rctrl1 <- trainControl(method = "cv", number = 3, returnResamp = "all")
rctrl2 <- trainControl(method = "LOOCV")
rctrl3 <- trainControl(method = "none")

set.seed(849)
test_reg_cv_model <- train(trainX, trainY, method = "krlsPoly", trControl = rctrl1,
                           preProc = c("center", "scale"), print.level = 0,
                           tuneGrid = data.frame(.lambda = NA, .degree = 1:2))
test_reg_pred <- predict(test_reg_cv_model, testX)

set.seed(849)
test_reg_loo_model <- train(trainX, trainY, method = "krlsPoly", trControl = rctrl2,
                            preProc = c("center", "scale"), print.level = 0,
                            tuneGrid = data.frame(.lambda = NA, .degree = 1:2))

set.seed(849)
test_reg_none_model <- train(trainX, trainY, 
                             method = "krlsPoly", 
                             trControl = rctrl3, 
                             print.level = 0,
                             tuneGrid = data.frame(.lambda = NA, .degree = 2),
                             preProc = c("center", "scale"))
test_reg_none_pred <- predict(test_reg_none_model, testX)

#########################################################################

tests <- grep("test_", ls(), fixed = TRUE, value = TRUE)

sInfo <- sessionInfo()

save(list = c(tests, "sInfo", "timestamp"),
     file = file.path(getwd(), paste(model, ".RData", sep = "")))

q("no")



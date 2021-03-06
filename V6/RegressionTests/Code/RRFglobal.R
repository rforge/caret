library(caret)
timestamp <- format(Sys.time(), "%Y_%m_%d_%H_%M")

model <- "RRFglobal"

#########################################################################

set.seed(2)
training <- twoClassSim(100)
testing <- twoClassSim(500)
trainX <- training[, -ncol(training)]
trainY <- training$Class

cctrl1 <- trainControl(method = "cv", number = 3, returnResamp = "all")
cctrl2 <- trainControl(method = "LOOCV")

set.seed(849)
test_class_cv_model <- train(trainX, trainY, 
                             method = "RRFglobal", 
                             trControl = cctrl1,
                             preProc = c("center", "scale"),
                             tuneGrid = expand.grid(.mtry = 2:4,
                                                    .coefReg = c(0.1, .5, 1)),
                             ntree = 50,
                             importance = TRUE)

test_class_pred <- predict(test_class_cv_model, testing[, -ncol(testing)])

set.seed(849)
test_class_loo_model <- train(trainX, trainY, 
                              method = "RRFglobal", 
                              trControl = cctrl2,
                              preProc = c("center", "scale"),
                              tuneGrid = expand.grid(.mtry = 2:4,
                                                     .coefReg = c(0.1, .5, 1)),
                              ntree = 50)
test_levels <- levels(test_class_cv_model)
if(!all(levels(trainY) %in% test_levels))
  cat("wrong levels")

#########################################################################

data(BloodBrain)
bbbDescr <-bbbDescr[, -nearZeroVar(bbbDescr)]
bbbDescr <-bbbDescr[, -findCorrelation(cor(bbbDescr), .5)]

set.seed(2)

inTrain <- createDataPartition(logBBB, p = .5)
trainX <-bbbDescr[inTrain[[1]], ]
trainY <- logBBB[inTrain[[1]]]
testX <- bbbDescr[-inTrain[[1]], ]
testY <- logBBB[-inTrain[[1]]]

rctrl1 <- trainControl(method = "cv", number = 3, returnResamp = "all")
rctrl2 <- trainControl(method = "LOOCV")

set.seed(849)
test_reg_cv_model <- train(trainX, trainY, 
                           method = "RRFglobal", 
                           trControl = rctrl1,
                           preProc = c("center", "scale"),
                           tuneGrid = expand.grid(.mtry = 2:4,
                                                  .coefReg = c(0.1, .5, 1)),
                           ntree = 50,
                           importance = TRUE)
test_reg_pred <- predict(test_reg_cv_model, testX)

set.seed(849)
test_reg_loo_model <- train(trainX, trainY, 
                            method = "RRFglobal",
                            trControl = rctrl2,
                            tuneGrid = expand.grid(.mtry = 2:4,
                                                   .coefReg = c(0.1, .5, 1)),
                            preProc = c("center", "scale"),
                            ntree = 50)

#########################################################################

test_class_imp <- varImp(test_class_cv_model)
test_reg_imp <- varImp(test_reg_cv_model)

#########################################################################

tests <- grep("test_", ls(), fixed = TRUE, value = TRUE)

sInfo <- sessionInfo()

save(list = c(tests, "sInfo", "timestamp"),
     file = file.path(getwd(), paste(model, ".RData", sep = "")))

q("no")



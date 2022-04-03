library(tidyverse) #includes ggplot2, dplyr, and tidyr
library(plm)
library(pglm)
library(xtable)
library(sjPlot)

# Read the data
data <- read.csv("data/vehicles/ev_counts.csv", 
                 #na.strings=c("", "NA"), 
                 header=TRUE)
data$time <- as.Date(data$time)
data$time
data[is.na(data)] <- 0

head(data)
str(data)

pop_by_zip <- read.csv("data/pop_by_zip.csv", header=TRUE)
summary(pop_by_zip$Total)

data$r_ev <- NA
data$r_bev <- NA
data$r_phev <- NA
for (zip_code in pop_by_zip$zip) {
  n_ev <- data[data$zip == zip_code, "n_ev"]
  pop <- pop_by_zip[pop_by_zip$zip == zip_code, "Total"]
  data[which(data$zip == zip_code), "r_ev"] <- n_ev/pop
  
  n_bev <- data[data$zip == zip_code, "n_bev"]
  data[which(data$zip == zip_code), "r_bev"] <- n_bev/pop
  
  n_phev <- data[data$zip == zip_code, "n_phev"]
  data[which(data$zip == zip_code), "r_phev"] <- n_phev/pop
}
head(data)

data$zip <- as.factor(data$zip)

summary(data)
summary(data$r_bev)
str(data)

##########################
# Linear model

model <- glm(n_bev ~ time+gas_price+n_evse, data=data)

summary(model)
coef(model)
vcov(model)
# xtable(model)

BIC(model)
AIC(model)

par(mfrow=c(2,2)) #create a 2x2 plot
plot(model)


##########################
# Fixed effects binomial logit model

model <- plm(r_bev ~ n_evse+gas_price+log(m_bev), data=data, index=c("time","zip"), 
              model="within")
model <- pglm(r_bev ~ 1, data=data, index=c("time","zip"), 
              model="within", family="binomial")



# model_random <- plm(n_bev ~ gas_price+n_evse, data=data, index=c("zip","time"), model="random")
model_random <- plm(n_bev ~ 1, data=data, index=c("zip","time"), model="random")

# model_fixed <- plm(n_bev ~ gas_price+n_evse+time, data=data, index=c("zip"), model="within")

model <- model_fixed
model <- model_random

summary(model)
coef(model)
vcov(model)
# xtable(model)

BIC(model)
AIC(model)

par(mfrow=c(2,2)) #create a 2x2 plot
plot(model)

fixef(model)
plmtest(model)

#Haussmann test
phtest(model_fixed, model_random)

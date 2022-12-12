library(tidyverse) #includes ggplot2, dplyr, and tidyr
library(plm)
library(pglm)
library(xtable)
library(sjPlot)
library(lvmisc)
library(texreg)

logit2prob <- function(logit){
  odds <- exp(logit)
  prob <- odds / (1 + odds)
  return(prob)
}

# Read the data
# data <- read.csv("data/data.csv", 
# data <- read.csv("data/data_no_census.csv", 
# data <- read.csv("data/data_2011_to_2022.csv", 
data <- read.csv("data/data__2018_to_2022.csv", 
                 #na.strings=c("", "NA"), 
                 header=TRUE)
data$time <- as.Date(data$time)
# data$time

head(data)
str(data)

data$zip_code <- as.factor(data$zip_code)
data$county <- as.factor(data$county)

#exclude census tracts that meet exclusion criteria
# data <- data %>% filter(n_veh > 10)
census_tracts_2010_0n_veh = c(53009990100, 53027990000, 53031990000, 53033990100, 53035990100, 53049990100, 53055990100, 53061990100, 53067990100)
length(census_tracts_2010_0n_veh)
census_tracts_2010_less_than_100n_veh = c(53029992201, 53061990002, 53005012000, 53057990100, 53071920400, 53021980100, 53059950100)
length(census_tracts_2010_less_than_100n_veh)
census_tracts_2010_missing_ACS_data = c(53071920400, 53033005302, 53037975401, 53053072906, 53035081400)
length(census_tracts_2010_missing_ACS_data)
# census_tracts_2010_ = c(53009000200) #not in data anyway
dim(data)
data <- data %>% filter(!census_tract_2010 %in% census_tracts_2010_0n_veh)
data <- data %>% filter(!census_tract_2010 %in% census_tracts_2010_less_than_100n_veh)
data <- data %>% filter(!census_tract_2010 %in% census_tracts_2010_missing_ACS_data)

MIN <- 0.01
data$n_ev[data$n_ev == 0] <- MIN
data$n_bev[data$n_bev == 0] <- MIN
data$n_phev[data$n_phev == 0] <- MIN
data$n_ev_new_sales[data$n_ev_new_sales == 0] <- MIN
data$n_bev_new_sales[data$n_bev_new_sales == 0] <- MIN
data$n_phev_new_sales[data$n_phev_new_sales == 0] <- MIN
# data$n_veh_new_sales[data$n_veh_new_sales == 0] <- MIN

#calculate EV shares
data$p_ev = data$n_ev/data$n_veh
data$p_bev = data$n_bev/data$n_veh
data$p_phev = data$n_phev/data$n_veh
data$p_ev_new_sales = data$n_ev_new_sales/data$n_veh_new_sales
data$p_bev_new_sales = data$n_bev_new_sales/data$n_veh_new_sales
data$p_phev_new_sales = data$n_phev_new_sales/data$n_veh_new_sales

#treat cases where n_veh_new_sales was 0 or where n_ev_new_sales >= n_veh_new_sales
MINN <- 0.0001
# data["p_ev_new_sales"][is.nan(data["p_ev_new_sales"])] <- MINN
data$p_ev_new_sales[is.nan(data$p_ev_new_sales)] <- MINN
data$p_bev_new_sales[is.nan(data$p_bev_new_sales)] <- MINN
data$p_phev_new_sales[is.nan(data$p_phev_new_sales)] <- MINN
data$p_ev_new_sales[data$n_ev_new_sales >= data$n_veh_new_sales] <- 1-MINN
data$p_bev_new_sales[data$n_ev_new_sales >= data$n_veh_new_sales] <- 1-MINN
data$p_phev_new_sales[data$n_ev_new_sales >= data$n_veh_new_sales] <- 1-MINN

# sum(is.na(data$p_ev_new_sales))
# data$p_ev_new_sales[is.nan(data$p_ev_new_sales)]
# data$p_ev_new_sales

data$p_ev_log_odds = log(data$p_ev/(1-data$p_ev))
data$p_bev_log_odds = log(data$p_bev/(1-data$p_bev))
data$p_phev_log_odds = log(data$p_phev/(1-data$p_phev))
data$p_ev_new_sales_log_odds = log(data$p_ev_new_sales/(1-data$p_ev_new_sales))
data$p_bev_new_sales_log_odds = log(data$p_bev_new_sales/(1-data$p_bev_new_sales))
data$p_phev_new_sales_log_odds = log(data$p_phev_new_sales/(1-data$p_phev_new_sales))

# data$p_ev_new_sales
# data$p_ev_new_sales_log_odds
# data$p_ev_new_sales[is.nan(data$p_ev_new_sales)]

n_digits = 7
data$p_ev = round(data$p_ev, digit=n_digits)
data$p_bev = round(data$p_bev, digit=n_digits)
data$p_phev = round(data$p_phev, digit=n_digits)
data$p_ev_new_sales = round(data$p_ev_new_sales, digit=n_digits)
data$p_bev_new_sales = round(data$p_bev_new_sales, digit=n_digits)
data$p_phev_new_sales = round(data$p_phev_new_sales, digit=n_digits)
data$p_ev_log_odds = round(data$p_ev_log_odds, digit=n_digits)
data$p_bev_log_odds = round(data$p_bev_log_odds, digit=n_digits)
data$p_phev_log_odds = round(data$p_phev_log_odds, digit=n_digits)
data$p_ev_new_sales_log_odds = round(data$p_ev_new_sales_log_odds, digit=n_digits)
data$p_bev_new_sales_log_odds = round(data$p_bev_new_sales_log_odds, digit=n_digits)
data$p_phev_new_sales_log_odds = round(data$p_phev_new_sales_log_odds, digit=n_digits)

data$p_white = data$n_white/data$n_total_pop
data$p_bachelor = data$n_bachelor/data$n_workers_16plus
data$p_single_family_unit = (data$n_units_1detached+data$n_units_1attached)/data$n_units_tot

data$date = data$time

data$tract_date = paste(data$census_tract_2010, data$date, sep="-")
data$index <- 1:nrow(data)

data_p = pdata.frame(data, index=c("census_tract_2010", "date"))
data_p$index_p <- 1:nrow(data_p)
is.pbalanced(data_p, index=c("census_tract_2010", "date"))
pdim(data_p)

data_p$ones = 1
# data_p$ones = runif(nrow(data_p), 0, 1000)

head(data)
summary(data)
summary(data$p_bev)
str(data)

write.csv(data, "data/data_no_census_R.csv")
write.csv(data, "data/data_2011_to_2022_R.csv")
write.csv(data_p, "data/data_2011_to_2022_R.csv")
write.csv(data_p, "data/data__2018_to_2022_R.csv")

##########################
# Data exploration

hist(data$n_veh)

library(gplots)
scatterplot(p_ev~year|census_tract_2010, data=data)

#histogram of p_ev
date_to_show <- "2013-04-30"
date_to_show <- "2022-09-30"
hist_plot_p_ev <- ggplot(subset(data, date==date_to_show))
# hist_plot_p_ev <- ggplot(subset(data_p, date==date_to_show))
hist_plot_p_ev <- hist_plot_p_ev + geom_histogram(mapping = aes(x=p_ev), binwidth=0.001) #0.001, 0.0001
hist_plot_p_ev <- hist_plot_p_ev + labs(title=paste("histogram of p_ev (EV fleet share) for date=", date_to_show, sep=""))
hist_plot_p_ev <- hist_plot_p_ev + geom_vline(aes(xintercept = mean(p_ev)), col='red', size=1) + geom_text(aes(label=round(mean(p_ev),4),y=0,x=mean(p_ev)+0.005),
                                                                                                           vjust=-1,col='red',size=5)
# hist_plot_p_ev <- hist_plot_p_ev + labs(x="time | census_tract", y="p_ev_res (fitted-observed)")
ggsave(path="results/", filename=paste("hist_plot_p_ev_", "date=", date_to_show, ".png", sep=""), dpi=200)
hist_plot_p_ev

#histogram of p_ev_new_sales
date_to_show <- "2013-04-30"
date_to_show <- "2022-09-30"
hist_plot_p_ev_new_sales <- ggplot(subset(data, date==date_to_show))
# hist_plot_p_ev_new_sales <- ggplot(subset(data_p, date==date_to_show))
hist_plot_p_ev_new_sales <- hist_plot_p_ev_new_sales + geom_histogram(mapping = aes(x=p_ev_new_sales), binwidth=0.001) #0.001, 0.0001
hist_plot_p_ev_new_sales <- hist_plot_p_ev_new_sales + labs(title=paste("histogram of p_ev_new_sales (EV new sales share) for date=", date_to_show, sep=""))
# hist_plot_p_ev_new_sales <- hist_plot_p_ev_new_sales + geom_vline(aes(xintercept = mean(p_ev)), col='red', size=1) + geom_text(aes(label=round(mean(p_ev),4),y=0,x=mean(p_ev)+0.005),
                                                                                                           # vjust=-1,col='red',size=5)
# hist_plot_p_ev <- hist_plot_p_ev + labs(x="time | census_tract", y="p_ev_res (fitted-observed)")
ggsave(path="results/", filename=paste("hist_plot_p_ev_new_sales_", "date=", date_to_show, ".png", sep=""), dpi=200)
hist_plot_p_ev_new_sales

hist(data_p$p_ev_new_sales)

106947/5974507

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

# model_fixed <- lm(p_ev_log_odds ~ 1,
model_fixed_lm <- lm(p_ev_log_odds ~ as.factor(census_tract_2010)+as.factor(date),
# model_fixed_lmm <- lm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev)+p_white+p_bachelor+p_single_family_unit+median_hh_inc, 
# model_fixed <- lm(p_ev_log_odds ~ as.factor(census_tract_2010)+as.factor(date)+n_evse+gas_price+log(m_ev)+p_white+p_bachelor+p_single_family_unit+median_hh_inc,
                  data=data)

# model <- plm(p_ev ~ n_evse+gas_price+log(m_ev), data=data, index=c("date","census_tract_2010"),
# model <- plm(p_ev ~ n_evse+gas_price+log(m_ev), data=data, index=c("census_tract_2010","date"),
# model_fixed <- plm(p_ev_log_odds ~ 1,
# model_fixed <- plm(p_ev_log_odds ~ ones, 
# model_fixed <- plm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev),
# model_fixed <- plm(p_ev_log_odds ~ n_evse,
# model_fixed <- plm(p_ev_log_odds ~ n_evse+median_hh_inc,
model_fixed <- plm(p_ev_new_sales_log_odds ~ n_evse+gas_price+log(m_ev)+p_white+p_bachelor+p_single_family_unit+median_hh_inc,
# model_fixed <- plm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev)+p_white+p_bachelor+p_single_family_unit+median_hh_inc,
# model_fixed <- plm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev)+p_single_family_unit+median_hh_inc,
# model_fixed <- plm(p_ev_log_odds ~ n_evse,
                   data=data_p, index=c("census_tract_2010","date"), model="within", effect="twoways")
                   # data=data_p, index=c("census_tract_2010","date"), model="within", effect="twoways", method="ht")
# model <- pglm(p_ev_log_odds ~ 1, 
                # data=data, index=c("time","census_tract_2010"),

model_random <- plm(p_ev_log_odds ~ 1, data=data_p, index=c("census_tract_2010","date"),
# model_random <- plm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev), data=data_p, index=c("census_tract_2010","date"),
# model_random <- plm(p_ev_log_odds ~ n_evse+gas_price+log(m_ev)+p_white+p_bachelor+p_single_family_unit+median_hh_inc, data=data_p, index=c("census_tract_2010","date"),
                    model="random", effect="twoways")

# model_fixed <- plm(n_bev ~ gas_price+n_evse+time, data=data, index=c("census_tract_2010"), model="within")

model <- model_fixed
model <- model_fixed_lm
model <- model_fixed_lmm
model <- model_random

s <- summary(model)
s
coef(model)
head(coef(model))
write.csv(coef(model), "results/coef_model.csv")
vcov(model)
# xtable(model)

#residuals, predictions
# data_p$p_ev_log_odds_res = residuals(model) #observed-fitted
data_p$p_ev_log_odds_res = -residuals(model) #fitted-observed
# data_p$p_ev_log_odds_res
# head(data_p$p_ev_log_odds_res)
# data_p$p_ev_log_odds_predict = predict(model, data_p)
# data_p$p_ev_log_odds_predict = fitted(model, data_p)
# data_p$p_ev_log_odds_predict = data_p$p_ev_log_odds - data_p$p_ev_log_odds_res
data_p$p_ev_log_odds_predict = data_p$p_ev_log_odds + data_p$p_ev_log_odds_res
# head(data_p)
data_p$p_ev_predict = 1 / ( 1 + exp(-data_p$p_ev_log_odds_predict) )
# data_p$p_ev_res = data_p$p_ev - data_p$p_ev_predict
data_p$p_ev_res = data_p$p_ev_predict - data_p$p_ev

data_p$p_ev_new_sales_log_odds_res = -residuals(model) #fitted-observed
data_p$p_ev_new_sales_log_odds_predict = data_p$p_ev_new_sales_log_odds + data_p$p_ev_new_sales_log_odds_res
data_p$p_ev_new_sales_predict = 1 / ( 1 + exp(-data_p$p_ev_new_sales_log_odds_predict) )
data_p$p_ev_new_sales_res = data_p$p_ev_new_sales_predict - data_p$p_ev_new_sales


head(data_p)
head(data_p$index)
str(data_p)

#sort by either index (ti) or index_p (it)
data_pp = data_p[order(data_p$index),]
head(data_pp)

#plot residuals
head(res)
length(res)
sample(res, 1000)
# plot(sample(res, 1000))
# hist(sample(res, 1000))
# hist(sample(data_p$p_ev_res, 1000))
res_plot_ti <- ggplot(data_p)
date_to_show <- "2013-04-30"
date_to_show <- "2020-04-30"
date_to_show <- "2022-09-30"
res_plot_ti <- ggplot(subset(data_p, date==date_to_show))
res_plot_ti <- res_plot_ti + geom_point(mapping = aes(x=index, y=p_ev_res), pch=".") #x=index
res_plot_ti <- res_plot_ti + labs(x="census_tract (running index)", y="p_ev_res (fitted-observed)", title=paste("residuals for date=", date_to_show, sep=""))
res_plot_ti <- res_plot_ti + labs(x="time | census_tract", y="p_ev_res (fitted-observed)")
ggsave(path="results/", filename="res_plot_ti.png", dpi=200)
ggsave(path="results/", filename=paste("res_plot_ti_", "date=", date_to_show, ".png", sep=""), dpi=200)
res_plot_ti
# res_plot_hist <- ggplot(data_p)
# res_plot_hist <- res_plot_hist + geom_histogram(mapping = aes(x=p_ev_res), binwidth=0.01)
# res_plot_hist
res_plot_it <- ggplot(data_p)
census_tract_2010_to_show = 53001950100
census_tract_2010_to_show = 53027000600
census_tract_2010_to_show = 53033005900 #high adopting (in zip=98119)
res_plot_it <- ggplot(subset(data_p, census_tract_2010==census_tract_2010_to_show))
res_plot_it <- res_plot_it + geom_point(mapping = aes(x=time, y=p_ev_res), pch="o") #x=index_p // x=time
res_plot_it <- res_plot_it + scale_x_date()
res_plot_it <- res_plot_it + labs(x="time", y="p_ev_res (fitted-observed)", title=paste("residuals for census_tract=", census_tract_2010_to_show, sep=""))
res_plot_it <- res_plot_it + labs(x="census_tract | time", y="p_ev_res (fitted-observed)")
ggsave(path="results/", filename="res_plot_it.png", dpi=200)
ggsave(path="results/", filename=paste("res_plot_it_", "census_tract=", census_tract_2010_to_show, ".png", sep=""), dpi=200)
res_plot_it

#fitted vs. observed plot
# plot(preds, data_p$p_ev, asp = 1)
# plot(as.vector(data_p$p_ev_predict), as.vector(data_p$p_ev), asp = 1, pch=".")
# abline(0, 1, col = 'red', lty = 'dashed', lwd = 2)
fit_vs_obs_plot <- ggplot(data_p)
date_to_show <- "2013-04-30"
date_to_show <- "2020-04-30"
date_to_show <- "2022-09-30"
fit_vs_obs_plot <- ggplot(subset(data_p, date==date_to_show))
fit_vs_obs_plot <- fit_vs_obs_plot + geom_point(mapping = aes(x=log(p_ev), y=log(p_ev_predict)), pch=".")
fit_vs_obs_plot <- fit_vs_obs_plot + coord_fixed()
fit_vs_obs_plot <- fit_vs_obs_plot + geom_abline(aes(intercept=0, slope=1), col = 'red', lty = 'dashed', lwd = 1)
fit_vs_obs_plot <- fit_vs_obs_plot + labs(x="p_ev", y="p_ev_predict", title=paste("fitted vs. observed p_ev", ", date=", date_to_show, sep=""))
fit_vs_obs_plot <- fit_vs_obs_plot + labs(x="p_ev", y="p_ev_predict", title="fitted vs. observed p_ev")
ggsave(path="results/", filename="fit_vs_obs_plot.png", dpi=200)
ggsave(path="results/", filename=paste("fit_vs_obs_plot_", "date=", date_to_show, ".png", sep=""), dpi=200)
fit_vs_obs_plot
# res_plot_hist <- ggplot(data_p)
# res_plot_hist <- res_plot_hist + geom_histogram(mapping = aes(x=p_ev_res), binwidth=0.01)
# res_plot_hist
census_tract_2010_to_show = 53001950100
census_tract_2010_to_show = 53027000600
census_tract_2010_to_show = 53033005900 #high adopting (in zip=98119)
fit_vs_obs_plot <- ggplot(subset(data_p, census_tract_2010==census_tract_2010_to_show))
fit_vs_obs_plot <- fit_vs_obs_plot + geom_point(mapping = aes(x=p_ev, y=p_ev_predict), pch="o")
fit_vs_obs_plot <- fit_vs_obs_plot + coord_fixed()
fit_vs_obs_plot <- fit_vs_obs_plot + geom_abline(aes(intercept=0, slope=1), col = 'red', lty = 'dashed', lwd = 1)
fit_vs_obs_plot <- fit_vs_obs_plot + labs(x="p_ev", y="p_ev_predict", title=paste("fitted vs. observed p_ev", ", census_tract=", census_tract_2010_to_show, sep=""))
# fit_vs_obs_plot <- fit_vs_obs_plot + labs(x="p_ev", y="p_ev_predict", title="fitted vs. observed p_ev")
# ggsave(path="results/", filename="fit_vs_obs_plot.png", dpi=200)
ggsave(path="results/", filename=paste("fit_vs_obs_plot_", "census_tract=", census_tract_2010_to_show, ".png", sep=""), dpi=200)
fit_vs_obs_plot

#qq plot
png(file="results/qqplot.png", width=1000, height=1000)
qqnorm(data_p$p_ev_res, ylab="Residuals")
qqline(data_p$p_ev_res, col="red", lwd=2, lty=2)
dev.off()

#quality of fit
epsilon <- 0.001
n <- sum(data_p$p_ev_res < epsilon & data_p$p_ev_res > -epsilon)
N <- length(data_p$p_ev_res)
n/N


# library(ggfortify)
# autoplot(model)
# fortify(model)

BIC(model)
AIC(model)

# screenreg(list(fixed=model_fixed))

methods(class= "plm")

length(residuals(model))
head(data_p$p_ev_predict)
preds = as.vector(data_p$p_ev_predict)
head(preds)
length(preds)
str(preds)
is.pseries(preds)

# head(data.frame(data_p$p_ev_log_odds))
# head(data.frame(residuals(model)))
punbalancedness(data_p)
join = data.frame(data_p$p_ev_log_odds) %>% left_join(data.frame(residuals(model)), by=c("data_p.p_ev_log_odds"= "residuals.model."))
write.csv(data_p$p_ev_log_odds_predict, "results/log_odds_predict.csv")
write.csv(preds, "results/preds.csv")
write.csv(residuals(model), "results/res.csv")



par(mfrow=c(2,2)) #create a 2x2 plot
plot(model, N=10)

plot_model(model, type="est")
plot_model(model, type="diag")
plot_model_qq(model)

#R^2
sst <- with(data_p, sum((p_ev_log_odds - mean(p_ev_log_odds))^2))
sst
model_sse <- t(data_p$p_ev_log_odds_res) %*% data_p$p_ev_log_odds_res
R = (sst - model_sse) / sst
R_squared = R*R
R_squared

sst <- with(data_p, sum((p_ev - mean(p_ev))^2))
model_sse <- t(data_p$p_ev_res) %*% data_p$p_ev_res
R = (sst - model_sse) / sst
R_squared = R*R
R_squared

RSS = sum((data_p$p_ev_log_odds-data_p$p_ev_log_odds_predict)^2)
TSS = sum((data_p$p_ev_log_odds-mean(data_p$p_ev_log_odds))^2)
RSS = sum((data_p$p_ev_new_sales_log_odds-data_p$p_ev_new_sales_log_odds_predict)^2)
TSS = sum((data_p$p_ev_new_sales_log_odds-mean(data_p$p_ev_new_sales_log_odds))^2)
R_squared = 1- RSS/TSS
R_squared

r.squared(model)

RSQUARE = function(y_actual,y_predict){
  cor(y_actual,y_predict)^2
}

RSQUARE(data_p$p_ev_log_odds, data_p$p_ev_log_odds_predict)
RSQUARE(data_p$p_ev, data_p$p_ev_predict)

# fixef(model)
# write.csv(fixef(model), "results/model_fixef.csv")
fix_i = fixef(model, effect="individual")
fix_i
write.csv(fix_i, "results/model_fixef_twoways_i.csv")
fix_t = fixef(model, effect="time")
fix_t
write.csv(fix_t, "results/model_fixef_twoways_t.csv")
fix_t = read.csv("results/model_fixef_twoways_t.csv")
fix_t = read.csv("results/model~1/model_fixef_t.csv")
names(fix_t) <- c("date", "fixeff_t")
fix_t$date <- as.Date(fix_t$date)
plmtest(model)

#fit to time fixed effects
# fit_function <- function(x, A, B, C, D) {
#   A+B*log(C+D*x)
# }
fit_function <- function(x, A, B, C) {
  A+B*log(C+x)
}
head(fix_t)
n_time_steps <- nrow(fix_t)
fix_t$t_dummy <- seq(1, n_time_steps)
# m <- nls(fixeff_t ~ fit_function(t_dummy, A, B, C), data=fix_t, start=list(A=-10,B=3.5, C=0.1))
m <- nls(fixeff_t ~ fit_function(t_dummy, A, B, C), data=fix_t, start=list(A=0,B=3.5, C=0.0002))
# m <- nls(fixeff_t ~ A+B*log(C+D*t_dummy), data=fix_t, start=list(A=-10,B=3.5,C=0.1,D=0.15))
# m <- nls(fixeff_t ~ A+B*log(C+D*t_dummy), data=fix_t, start=list(A=1,B=1,C=1,D=1))
# m <- nls(fixeff_t ~ A+B*t_dummy, data=fix_t, start=list(A=1,B=1))
m
coef(m)
# fix_t %>%
#   add_row()
# date_predict <- seq(as.Date("2011-01-31"), as.Date("2035-12-31"), "months")
date_predict <- seq(as.Date("2011-02-01"), length=25*12, by="1 month") - 1
t_dummy_predict <- seq(1, length(date_predict))
fixeff_t_predict <- fit_function(t_dummy_predict, coef(m)[1], coef(m)[2], coef(m)[3])
fix_t_predict <- data.frame(date_predict, t_dummy_predict, fixeff_t_predict)#, predict(m, newdata=t_dummy_predict))
head(fix_t_predict)
tail(fix_t_predict)
write.csv(fix_t_predict, "results/model_fixeff_t_predict.csv")


#plot of time fixed effects and fit (and projection into the future)
time_fixeff_plot <- ggplot(fix_t)
# time_fixeff_plot <- ggplot(subset(data_p, date>=date))
time_fixeff_plot <- time_fixeff_plot + geom_point(mapping = aes(x=date, y=fixeff_t), pch="o")
# time_fixeff_plot <- time_fixeff_plot + geom_line(mapping = aes(x=date, y=fixeff_t_fit), col="red")
time_fixeff_plot <- time_fixeff_plot + geom_line(data=fix_t_predict, mapping = aes(x=date_predict, y=fixeff_t_predict), col="red")
time_fixeff_plot <- time_fixeff_plot + scale_x_date()
time_fixeff_plot <- time_fixeff_plot + labs(x="date", y="Time fixed effect", title="Time fixed effects")
# time_fixeff_plot <- time_fixeff_plot + labs(x="p_ev", y="p_ev_predict", title="fitted vs. observed p_ev")
ggsave(path="results/", filename="time_fixeff_plot.png", dpi=200)
# ggsave(path="results/", filename=paste("time_fixeff_plot_", "census_tract=", census_tract_2010_to_show, ".png", sep=""), dpi=200)
time_fixeff_plot


#predictions into the future
data_future <- read.csv("data/data_future.csv")
data_future$date <- as.Date(data_future$date)
head(data_future)
data_future$p_ev_log_odds_forecast <- -14.0649 + data_future$fixeff_i + data_future$fixeff_t_predict
data_future$diff = data_future$p_ev_log_odds_predict - data_future$p_ev_log_odds_forecast
hist(data_future$diff)
data_future$p_ev_forecast <- logit2prob(data_future$p_ev_log_odds_forecast)
data_future$n_ev_forecast <- data_future$p_ev_forecast * data_future$n_veh
head(data_future)
tail(data_future)
write.csv(data_future, "results/model~1/predictions.csv")
# predictions <- predict(model_fixed_lm)
# predictions_future <- predict(model_fixed_lm, newdata=data_future)
# head(predictions)
# head(data$p_ev_log_odds)


#Haussmann test
phtest(model_fixed, model_random)

ggplot(sample(model$residuals, 1000)) + 
  geom_scatter(mapping = aes(y = ..density..), fill ='#CBC3E3', binwidth = 20) + 
  geom_density(colour = '#AA98A9') +
  ggtitle("EV registration by zipcode") + 
  ylab("count") +
  geom_vline(xintercept = avg, lwd = 0.5, colour = '#702963',linetype = 2) +
  geom_text(x = 8, y = 0.1, label = "Mean = 182.1294, \n Variance = 82940.39")

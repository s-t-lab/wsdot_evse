library(tidyverse) #includes ggplot2, dplyr, and tidyr
# library(plm)
# library(pglm)
# library(xtable)
# library(sjPlot)

# Read the data
data <- read.csv("data/df.csv", 
                 #na.strings=c("", "NA"), 
                 header=TRUE)
head(data)
tail(data)
str(data)

data_sub <- data %>% filter(time == "2021-12-31")
head(data_sub)

quantile(data$n_evse, seq(0, 1, by=0.1))
quantile(data_sub$n_evse, seq(0, 1, by=0.1))

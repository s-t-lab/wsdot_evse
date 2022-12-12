library(ggplot2)
library(readxl)
library(stringr)
library(tidyverse)

# Read in all loop data from WSDOT
i=1
data_names = c("HWY2_EB_SULTAN",
               "HWY2_WB_SULTAN",
               "I5_NB_CENTRALIA",
               "I5_SB_CENTRALIA",
               "I90_EB_NORTHBEND",
               "I90_WB_NORTHBEND",
               "I90_EB_SPOKANE",
               "I90_WB_SPOKANE",
               "I182_EB_KENNEWICK",
               "I182_WB_KENNEWICK")
all_data = data.frame()
data_files = list.files('./data/aadt')
for (file in data_files) {
    data = read_excel(paste0("./data/aadt/", file),
                      col_types=c("date", rep("guess",2)),
                      range="A1:C289")
    data = data %>%
        mutate(
            Time=seq(0,(60*24-5),5),
            volume=`Mean Volume`,
            proportion=volume / sum(volume)
        ) %>%
        select(
            time='Time',
            volume,
            proportion
        )
    data$location = data_names[i]
    all_data = rbind(all_data, data)
    rm(data,file)
    i=i+1
}

# Average by 5min
avg_proportion = all_data %>%
    group_by(
        time
    ) %>%
    summarise(
        proportion=mean(proportion)
    )

# Plot loop curves
ggplot(data=all_data, aes(x=time, y=volume, col=location)) +
    geom_line()
ggplot(data=all_data, aes(x=time, y=proportion, col=location)) +
    geom_line() +
    geom_line(data=avg_proportion, col='black', linetype='dashed', size=.75, aes(x=time, y=proportion)) +
    ggtitle('AADT K-Factor Estimation') +
    xlab('Minute of Day') +
    ylab('5-Minute Proportion of 2021 AADT')

write.csv(avg_proportion, './data/avg_kfactor.csv')

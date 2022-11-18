library(ggplot2)
library(stringr)
library(tidyverse)

# Read in all loop data from WSDOT
batch_directory = './models/batch_results_05/'
files = list.files(batch_directory)
all_data = data.frame()
for (file in files) {
    components = str_split(file, "_")[[1]]
    var_name = components[1]
    run_num = substr(components[3],1,1)
    data = read.csv(paste0(batch_directory, file), col.names=c("value"))
    data$metric = var_name
    data$run = run_num
    data$step = seq(1,nrow(data),1)
    all_data = rbind(all_data, data)
}
rm(data,file,files,run_num,var_name,components)

# Calculate metrics across runs
all_data = all_data %>%
    group_by(
        metric,
        step,
    ) %>%
    summarise(
        mean_val=mean(value),
        sd_val=sd(value)
    ) %>%
    mutate(
        metric_named = recode(metric,
                              "ar"="Arrival Rate (veh/min)",
                              "pd"="Power Draw (kW)",
                              "qd"="Queue Delay (veh-min)")
    )

# Plot loop curves
ggplot(data=all_data, aes(x=step, y=mean_val)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    geom_line() +
    ggtitle("DCFC Station Performance Metrics (Average of 10 Simulation Runs)") +
    xlab("Minute of Day") +
    ylab("Batch Simulation Mean")
# 
# ggplot(data=all_data, aes(x=time, y=proportion, col=location)) +
#     geom_line() +
#     geom_line(data=avg_proportion, col='black', linetype='dashed', size=.75, aes(x=time, y=proportion)) +
#     ggtitle('AADT K-Factor Estimation') +
#     xlab('Minute of Day') +
#     ylab('5-Minute Proportion of 2021 AADT')
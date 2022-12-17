library(ggplot2)
library(stringr)
library(tidyverse)


#### Compile simulation results ####
batch_directory = './ev_charging_station/models/batch_results_350/'
run_folders = list.files(batch_directory)
time_data = data.frame()
veh_data = data.frame()
for (folder in run_folders) {
    # # For updating plug counts
    # folder="batch_results_3000_100"
    # file="./ev_charging_station/models/batch_results/batch_results_3000_100"
    print(folder)
    ld_aadt = as.numeric(str_split(folder, fixed("_"))[[1]][3])
    bev_pct = as.numeric(str_split(folder, fixed("_"))[[1]][4])
    run_files = list.files(paste0(batch_directory, folder))
    for (file in run_files) {
        var_type = str_split(file, fixed("_"))[[1]][1]
        var_name = str_split(file, fixed("_"))[[1]][2]
        run_num = str_split(str_split(file, fixed("_"))[[1]][3], fixed("."))[[1]][1]
        data = read.csv(paste0(batch_directory, folder, "/", file), col.names=c("value"))
        # If there is data, read it in and clean
        if (nrow(data) > 0) {
            data$ld_aadt = ld_aadt
            data$bev_pct = bev_pct
            data$metric = var_name
            data$run = run_num
            data$step = seq(1,nrow(data),1)
            data = data %>%
                mutate(
                    metric_named = recode(
                        metric,
                        "ar"="Arrival Rate (veh/min)",
                        "pd"="Power Draw (kW)",
                        "ql"="Queue Length (veh)",
                        "qd"="Queue Delay (veh-min)",
                        "ct"="Charging Time (veh-min)")
                )
            if (var_type=="veh") {
                veh_data = rbind(veh_data, data)
            } else {
                time_data = rbind(time_data, data)
            }
        }
    }
}
rm(data,folder,run_folders,file,run_files,run_num,var_name,bev_pct,ld_aadt,var_type)

saveRDS(veh_data, "./veh_data.rds")
saveRDS(time_data, "./time_data.rds")


#### After compiling results ####
veh_data = readRDS("./veh_data.rds")
time_data = readRDS("./time_data.rds")
plug_data = read.csv("./ev_charging_station/data/plug_counts.csv")

# Table
# Average number of charging sessions per day
veh_table_data = veh_data %>%
    filter(
        metric_named=="Queue Delay (veh-min)"
    ) %>%
    group_by(
        ld_aadt=as.factor(ld_aadt),
        bev_pct=as.factor(bev_pct)
    ) %>%
    summarise(
        n=round(n() / 30, 0),
        pct_wait=quantile(value, .95)
    )
# Max power across all runs
time_table_data_max = time_data %>%
    filter(
        metric_named=="Power Draw (kW)"
    ) %>%
    group_by(
        ld_aadt=as.factor(ld_aadt),
        bev_pct=as.factor(bev_pct)
    ) %>%
    summarise(
        max=round(max(value), 0),
    )
# Total energy based on average draw per timestep across all runs
time_table_data_total = time_data %>%
    filter(
        metric_named=="Power Draw (kW)"
    ) %>%
    group_by(
        step,
        ld_aadt=as.factor(ld_aadt),
        bev_pct=as.factor(bev_pct)
    ) %>%
    summarise(
        mean=mean(value),
    ) %>%
    group_by(
        ld_aadt,
        bev_pct
    ) %>%
    summarise(
        total_e=round(sum(mean)/60, 0)
    )
table_data = merge(veh_table_data, time_table_data_max, on=c('ld_aadt','bev_pct'))
table_data = merge(table_data, time_table_data_total, on=c('ld_aadt','bev_pct'))

# Plots
# Time metrics
time_data$`BEV Long Distance AADT` = as.factor(time_data$ld_aadt * time_data$bev_pct / 100)
plot_data = time_data %>%
    group_by(
        `BEV Long Distance AADT`,
        metric_named,
        step
    ) %>%
    summarise(
        mean_val = mean(value),
        sd_val = sd(value)
    )
ggplot(data=plot_data, aes(x=step, y=mean_val, col=`BEV Long Distance AADT`)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    geom_line() +
    ggtitle("DCFC Station Performance Metrics (Average of 30 Simulation Runs)") +
    xlab("Minute of Day") +
    ylab("Batch Simulation Mean")

# Vehicle metrics
veh_data$ev_ld_aadt = as.factor(veh_data$ld_aadt * veh_data$bev_pct / 100)
ggplot(data=veh_data, aes(x=value, col=ev_ld_aadt)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    stat_ecdf(geom="step") +
    ggtitle("DCFC Vehicle Performance Metrics (Average of 30 Simulation Runs)") +
    xlab("Minutes") +
    ylab("Vehicle Cumulative Distribution Function %")


#### Configuration Comparisons ####
# First, re-run compilation with new batch location
# Vehicle delays ecdf
plot_data = veh_data
ggplot(data=plot_data, aes(x=value)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    stat_ecdf(geom="step") +
    ggtitle("Distribution of Vehicle Delays") +
    xlab("Minutes") +
    ylab("Vehicle Cumulative Distribution Function %")
quantile(plot_data[plot_data$metric=="qd",]$value, .95)
quantile(plot_data[plot_data$metric=="ct",]$value, .50)

# Generic Plots Time
plot_data = time_data %>%
    group_by(
        metric_named,
        step
    ) %>%
    summarise(
        mean=mean(value),
        max=max(value)
    )
ggplot(data=plot_data, aes(x=step, y=mean)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    geom_line() +
    ggtitle("DCFC Station Performance Metrics (Average of 30 Simulation Runs)") +
    xlab("Minute of Day") +
    ylab("Batch Simulation Mean")

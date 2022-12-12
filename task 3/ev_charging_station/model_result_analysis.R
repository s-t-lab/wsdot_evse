library(ggplot2)
library(stringr)
library(tidyverse)

# Read in all simulation scenario data
batch_directory = './models/batch_results_3000_100/'
files = list.files(batch_directory)
time_data = data.frame()
veh_data = data.frame()
for (file in files) {
    components = str_split(file, "_")[[1]]
    var_name = components[2]
    run_num = substr(components[3],1,1)
    data = read.csv(paste0(batch_directory, file), col.names=c("value"))
    if (nrow(data) > 0) {
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
        if (components[[1]]=="veh") {
            veh_data = rbind(veh_data, data)
        } else {
            time_data = rbind(time_data, data)
        }
    }
}
rm(data,file,files,run_num,var_name,components)

# Calculate metrics across runs
time_data_summ = time_data %>%
    group_by(
        metric_named,
        step,
    ) %>%
    summarise(
        mean_val=mean(value),
        sd_val=sd(value)
    )

# Plot time metrics
ggplot(data=time_data_summ, aes(x=step, y=mean_val)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    geom_line() +
    ggtitle("DCFC Station Performance Metrics (Average of 10 Simulation Runs)") +
    xlab("Minute of Day") +
    ylab("Batch Simulation Mean")
# Plot vehicle metrics
ggplot(data=veh_data, aes(x=value)) +
    facet_grid(rows=vars(metric_named), scales="free") +
    stat_ecdf(geom="step") +
    ggtitle("DCFC Vehicle Performance Metrics (Average of 10 Simulation Runs)") +
    xlab("Minutes") +
    ylab("Vehicle Cumulative Distribution Function %")

# % vehicles waiting 5 mins or more
no_delay_vehs = veh_data %>%
    filter(
        metric=="qd",
        value <=5
    )
all_delay_vehs = veh_data %>%
    filter(
        metric=="qd"
    )
# Daily charging sessions
charge_sessions = veh_data %>%
    group_by(
        run
    ) %>%
    summarise(
        n=n()
    )
# Peak power
peak_power = time_data_summ %>%
    filter(
        metric_named=="Power Draw (kW)"
    )
# Total energy
total_energy = time_data_summ %>%
    filter(
        metric_named=="Power Draw (kW)"
    )

print(paste0("% > 5 Minute Wait: ", (1.00 - round(nrow(no_delay_vehs) / nrow(all_delay_vehs), 2))))
print(paste0("Mean Daily Charging Sessions: ", round(mean(charge_sessions$n), 0)))
print(paste0("Peak Power Demand: ", round(max(peak_power$mean_val), 0)))
print(paste0("Total Energy Consumed: ", round(sum(peak_power$mean_val) / 60.0, 0)))

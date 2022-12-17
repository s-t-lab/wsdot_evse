library(ggplot2)
library(tidyverse)

# Read in simulation scenario data
data = read.csv(
    './sim_queueing_results_data.csv',
    col.names=c("ev_pct","aadt","metric","value")
)
data$`EV Fleet Share (%)` = as.factor(data$ev_pct)

# Plot data
ggplot(data=data, aes(x=aadt, y=value, col=`EV Fleet Share (%)`)) +
    facet_grid(rows=vars(metric), scales="free") +
    geom_line() +
    ggtitle("Aggregated Simulation Results") +
    xlab("Long Distance AADT (veh/day)") +
    ylab("Simulation Mean")

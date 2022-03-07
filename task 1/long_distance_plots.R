library(ggplot2)
library(reshape)


setwd('/Users/zack/Desktop/stl/wsdot_evse/Task 1')
ld_data = read.csv('long_distance_counts.csv')

ld_data = ld_data[ld_data$trips<5000,]
# ld_data = melt(ld_data)

# Gathered as sum after running shortest path and station analysis, bevs can count towards multiple stations
ggplot(ld_data, aes(x=trips)) +
  geom_density(color='darkblue', fill='lightblue', bw=300)

# Roughly 5000-10000 in prior analysis with 12% EVs
pctiles = seq(0,1.0,.25)
quantile(ld_data$trips, pctiles)

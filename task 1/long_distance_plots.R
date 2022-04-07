library(ggplot2)
library(reshape)


setwd('/Users/zack/Desktop/stl/wsdot_evse/Task 1')
ld_data = read.csv('long_distance_counts.csv')

# Remove outliers
ld_data = ld_data[ld_data$trips<5000,]

# Separate Upgrade and Candidate sites
ld_data$station_type = substr(ld_data$pid, 1,1)
ld_candidate_data = ld_data[ld_data$station_type=='c',]
ld_upgrade_data = ld_data[ld_data$station_type=='u',]

# Gathered as sum after running shortest path and station analysis, bevs can count towards multiple stations
ggplot(ld_candidate_data, aes(x=trips)) +
  geom_density(color='darkblue', fill='lightblue', bw=300)
ggplot(ld_upgrade_data, aes(x=trips)) +
  geom_density(color='darkblue', fill='lightblue', bw=300)

# Roughly 5000-10000 in prior analysis with 12% EVs
pctiles = seq(0,1.0,.10)
quantile(ld_candidate_data$trips, pctiles)
quantile(ld_upgrade_data$trips, pctiles)

library(ggplot2)

# Read in all soc-charge data from InsideEVs
all_data = data.frame()
data_files = c('mache.csv','id.csv','bolt.csv','leaf.csv','lightning.csv','models.csv')
ranges = c(303.0, 275.0, 259.0, 212.0, 320.0, 396.0)
efficiencies = c(90.0/33.7, 98.0/33.7, 109.0/33.7, 98.0/33.7, 63.0/33.7, 112.0/33.7)
capacities = (1/efficiencies) * ranges
i = 1
for (file in data_files) {
    data = read.csv(paste0("./data/charge_curves/", file))
    data$model = file
    colnames(data) = c('soc','power','model')
    data$c_rate = data$power / capacities[i]
    all_data = rbind(all_data, data)
    i = i+1
}

# Fit regression to data
linmodel_c_rate = lm(c_rate ~ soc, all_data)
all_data$fit_line = predict.lm(linmodel_c_rate, all_data)
summ = summary(linmodel_c_rate)
se_int = summ$coefficients[[3]]
se_slope = summ$coefficients[[4]]

# Model + 2*standard error
max_model = linmodel_c_rate
max_model$coefficients[[1]] = max_model$coefficients[[1]] + 2*se_int
max_model$coefficients[[2]] = max_model$coefficients[[2]] + 2*se_slope
all_data$max_fit_line = predict.lm(max_model, all_data)

# Model - 2*standard error
min_model = linmodel_c_rate
min_model$coefficients[[1]] = min_model$coefficients[[1]] - 2*se_int
min_model$coefficients[[2]] = min_model$coefficients[[2]] - 2*se_slope
all_data$min_fit_line = predict.lm(min_model, all_data)

# Custom model
linefit = function(point1, point2, xvals) {
    slope = (point2[2]-point1[2]) / (point2[1]-point1[1])
    yint = point1[2] - (slope*point1[1])
    print(slope)
    print(yint)
    return (slope*xvals + yint)
}

# Custom Model - Upper bound of goes through 100%=0.0
point1 = c(0.00, 2.50)
point2 = c(1.00, 0.00)
all_data$max_cust_line = linefit(point1, point2, all_data$soc)

# Custom Model - Lower bound of goes through 100%=0.0
point1 = c(0.00, 0.75)
point2 = c(1.00, 0.00)
all_data$min_cust_line = linefit(point1, point2, all_data$soc)

# Plot charge and power curves
ggplot(data=all_data, aes(x=soc, y=power, col=model)) +
    geom_line()
ggplot(data=all_data, aes(x=soc, y=c_rate, col=model)) +
    geom_line() +
    ggtitle('C-Rate Curve Fitting (Charging Ends at 80%)') +
    xlab('State of Charge (SOC)') +
    ylab('C-Rate') +
    # geom_line(data=all_data, col='black', linetype='dashed', size=.75, aes(x=soc, y=fit_line)) +
    # geom_line(data=all_data, col='red', linetype='dotted', size=.75, aes(x=soc, y=max_fit_line)) +
    # geom_line(data=all_data, col='red', linetype='dotted', size=.75, aes(x=soc, y=min_fit_line)) +
    geom_line(data=all_data, col='darkred', linetype='dashed', size=.75, aes(x=soc, y=max_cust_line)) +
    geom_line(data=all_data, col='darkred', linetype='dashed', size=.75, aes(x=soc, y=min_cust_line)) +
    geom_vline(xintercept=0.80, size=.75)

print(summ)


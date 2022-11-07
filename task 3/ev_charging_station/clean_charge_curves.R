library(ggplot2)

# Read in all soc-charge data from InsideEVs
all_data = data.frame()
data_files = c('bolt.csv','id.csv','leaf.csv','lightning.csv','mache.csv','models.csv')
capacities = c(65,82,62,145,99,100)
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

# Plot charge and power curves
ggplot(data=all_data, aes(x=soc, y=power, col=model)) +
    geom_line()
ggplot(data=all_data, aes(x=soc, y=c_rate, col=model)) +
    geom_line() +
    ggtitle('C-Rate Curve Fitting (Charging Ends at 80%)') +
    xlab('State of Charge (SOC)') +
    ylab('C-Rate') +
    geom_line(data=all_data, col='black', linetype='dashed', size=.75, aes(x=soc, y=fit_line)) +
    geom_line(data=all_data, col='red', linetype='dashed', size=.75, aes(x=soc, y=max_fit_line)) +
    geom_line(data=all_data, col='red', linetype='dashed', size=.75, aes(x=soc, y=min_fit_line)) +
    geom_vline(xintercept=0.80, size=.75)
print(summ)

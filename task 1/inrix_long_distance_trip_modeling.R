library(dplyr)
library(sqldf)
library(data.table)

# Reading Inrix data
setwd('./Desktop/stl/wsdot_evse')
tripheaders = read.csv(file='./inrix_data/TripRecordsReportTripsHeaders.csv')

# Look at trips that Parastoo re-joined
corrected_trips = read.csv('./inrix_data/sequenced trips (corrected).csv', header=FALSE)

# Get long distance trips and process stats from chunks of full trip file
con = file('./inrix_data/TripRecordsReportTrips.csv', "r")
ld_data = list()
total_trips = 0
for (i in seq(0,9,1)) {
  print(i)
  data = read.csv(con, nrows=1000000, header=FALSE)
  colnames(data) = colnames(tripheaders)
  data = data[data$VehicleWeightClass == 1,]
  total_trips = total_trips + nrow(data)
  ld_trips = data[data$TripDistanceMeters*.000621371 >= 150,]
  ld_data[[i+1]] = ld_trips
  rm(data, ld_trips, i)
}
close(con)
ld_data = rbindlist(ld_data)
write.csv(ld_data, './inrix_data/ld_trips.csv')

proportion_ld = nrow(ld_data) / total_trips

library(Hmisc)
library(ggplot2)
library(ggtext)
library(reshape)
library(dplyr)
library(spatstat)
library(pracma)


# veh_data = read.csv('/Volumes/GoogleDrive-100069302124626889369/My Drive/STL/Datasets/NHTS/vehpub.csv')
trip_data = read.csv('/Volumes/GoogleDrive-100069302124626889369/My Drive/STL/Datasets/NHTS/trippub.csv')

# Look at NHTS distribution of daily miles
trip_data = trip_data[trip_data$VEHID != 97,]
trip_data = trip_data[trip_data$VEHID != -1,]
trip_data = trip_data[trip_data$TRPMILES > 0,]
trip_data = trip_data[trip_data$TRPTRANS %in% c(3,4,5,6,8,9,18),]
trip_data = trip_data[trip_data$DRVR_FLG == 1,]
triplens = trip_data %>%
  group_by(HOUSEID, VEHID) %>%
  summarise(
  triplen = sum(TRPMILES),
  weight = sum(WTTRDFIN)
)

# triplens = triplens[triplens$triplen < 1000,]
hist(triplens$triplen)

# Assume DCFC only needed on days over X miles
DCFC_threshold = 150
triplens$dcfc_miles = triplens$triplen - DCFC_threshold
triplens_dcfc = triplens[triplens$dcfc_miles > 0,]
triplens_dcfc$wtd_dcfc_miles = triplens_dcfc$triplen*triplens_dcfc$weight
total_dcfc_miles = sum(triplens_dcfc$wtd_dcfc_miles)

# Work out percentage of daily VMT that requires DCFC
triplens$wtd_triplen = triplens$triplen*triplens$weight
total_miles = sum(triplens$wtd_triplen)

proportion_dcfc_miles = total_dcfc_miles / total_miles

# Work out percentage of daily trips that require DCFC
proportion_dcfc_trips = sum(triplens_dcfc$weight) / sum(triplens$weight)

# Weighted ecdf of daily trip lengths
ewcdf_fun = ewcdf(triplens$triplen, triplens$weight)
x = linspace(0, 500, n=1000)
y = ewcdf_fun(x)
plot(x,y,
     type="l",
     main="Weighted ECDF of Daily Tour Mileage in NHTS Vehicles",
     xlab="Daily Vehicle Mileage (veh-mi)",
     ylab="Proportion of NHTS Vehicle Fleet",
     )
abline(v=.80*c(150,225,260,520,400),col="blue")
veh_pcts = ewcdf_fun(.80*c(150,225,260,520,400))
veh_pcts = (1-veh_pcts)*100
veh_pcts

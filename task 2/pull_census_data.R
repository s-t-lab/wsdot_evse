library(tidyverse) #includes ggplot2, dplyr, and tidyr
library(tidycensus)
library(hash) #for dictionaries
library(data.table) #for setnames()

readRenviron("keys.py")
census_api_key(Sys.getenv("CENSUS_DATA_KEY"))

vars_acs5_2019 <- load_variables(2019, "acs5", cache = TRUE)
view(vars_acs5_2019)
write.csv(vars_acs5_2019, "data/census/vars_acs5_2019.csv")

vars_acs5_2020 <- load_variables(2020, "acs5", cache = TRUE)
view(vars_acs5_2020)
write.csv(vars_acs5_2020, "data/census/vars_acs5_2020.csv")

vars_acs1_2021 <- load_variables(2021, "acs1", cache = TRUE)
view(vars_acs1_2021)
write.csv(vars_acs1_2021, "data/census/vars_acs1_2021.csv")

# age10 <- get_decennial(state="WA", 
#                        geography = "zcta", 
#                        variables = "B08008", 
#                        year = 2019)

#variables to be pulled
variables <- read.csv("data/census/variables.csv", 
                      na.strings=c("", "NA"), 
                      header=TRUE, fileEncoding="UTF-8-BOM")
variables <- variables %>% filter(download==1)
head(variables)

#query data
year <- 2011
data <- get_acs(
  state = "WA", 
  # geography = "zcta",
  geography = "tract",
  variables = variables$census_name, 
  # summary_var = "B01001_001",
  year = year, #2020
  # survey = "acs1" ##
)
head(data, 10)

#pivot data into respective columns in a dataframe
y = data %>% dplyr::select(-moe) %>% pivot_wider(names_from = variable, values_from = estimate)
setnames(y, old=variables$census_name, new=variables$short_name)
head(y)

write.csv(y, sprintf('data/census/all_acs_by_tract_%d.csv', year))


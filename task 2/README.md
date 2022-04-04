# ZIP Code-Level EV Adoption Forecasting in Washington State

## About

A Python-based framework to compile historic EV registration in Washington state by ZIP code and month. Preliminary model implementations to forecast ZIP code-level EV adoption in Washington are written in R.

## Workflow

+ `scrape_veh_registration_data.ipynb`: download EV and other vehicle registration data from [Data.WA.gov](https://data.wa.gov/)
+ `scrape_charging_stations.ipynb`: download EV charging stations data from [NREL's Alternative Fuel Data Center](https://developer.nrel.gov/docs/transportation/alt-fuel-stations-v1/)
+ `process_EV_registration_activity.ipynb`: deduce number of currently registered EVs (BEVs and PHEVs) by ZIP code for each month since January 2017
+ `combine_data_sources.ipynb`: combine the different data sources into one dataframe

In addition, the file `explore_EV_title_and_registration_activity.ipynb` contains code to gain first insights into the EV registration activity data from Data.WA.gov, e.g. counts by vehicle type or transaction type, and the ability to create plots of different variables.

## Contact

The work is conducted in the University of Washington's Sustainable Transportation Lab.

+ Principal Investigator: Prof. Don MacKenzie (dwhm [at] uw.edu)
+ Senior Research Scientist: Daniel Malarkey (djmalark [at] uw.edu)
+ Graduate Research Assistant: Steffen Coenen (scoenen [at] uw.com)
+ Graduate Research Assistant: Zack Aemmer (zae5op [at] uw.com)

## Documentation

Further documentation can be found in the code. Each file contains a header, describing in detail what it does. Defined functions contains their own documentation with description of all function parameters.

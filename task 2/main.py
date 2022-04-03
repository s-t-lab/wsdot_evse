# -*- coding: utf-8 -*-
"""
Created on Mon Jan 31 17:34:38 2022

@author: steff
"""

import classes

# import init
# init.run()

ev_pop_data = classes.EVPopulationData("data/vehicles/Electric_Vehicle_Population_Data.csv", "config/Electric_Vehicle_Population_Data_key.csv")

print(ev_pop_data.data.dtypes)
print(ev_pop_data.data["location"].value_counts())
print(ev_pop_data.data["zip_code"].value_counts())

ev_pop_data.plot_counts_by("county", save=0)
ev_pop_data.plot_counts_by("city", save=0)
# ev_pop_data.plot_counts_by("zip_code", save=0)
# ev_pop_data.plot_counts_by("make", save=0)




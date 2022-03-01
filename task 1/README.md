## WSDOT Electric Vehicle Supply Equipment (EVSE) Project Task 1
Task 1 of this Project builds from prior work on the ChargEVal electric vehicle (EV) charging analysis tool to screen for candidate and upgrade Direct Current Fast Charging (DCFC) sites in Washington state. The main output of this analysis is a set of recommended candidate (new) and upgraded DCFC sites to meet currently infeasible charging demand. Expected traffic volumes and a station-based queueing analysis are performed separately to inform individual station sizing.

### Analysis Structure:
1. Update EV registration, candidate sites, and existing site data.
2. Calculate network-wide trip infeasibility.
3. Place and cluster candidate stations.
4. Repeat steps 2 and 3 for upgrade stations.
5. Spot-check and add/remove stations where needed.
6. Calculate long distance shares.
7. Update queueing analysis in spreadsheets.

### Key File Descriptions:
* update_bevs.R: Step 1 above for EV registrations.
* clean_afdc_evse.ipynb: Step 1 above for existing stations.
* gas_station: Step 1 above for candidate upgrade sites.
* infeasible_station_analysis.R: Steps 2-4 above.
* get_long_dist.R: Step 6 above.
* WA Roadway Coverage Analysis: Step 7 above.

### Database:
The data itself is stored in an RDS instance running Postgresql with PostGIS. It requires an access key that is not uploaded here. Duplicate tables with the qualifier "_wsdot" have been created in some cases to avoid overwriting previous ChargEVal work, and should be used. The "_combo" qualifier on all tables indicates that the entire analysis has been performed for Combo plugs only. The key tables created during the analysis are:

* WA_roads:
Geometry of the highway network.

* added_sites_wsdot:
Potential new DCFC sites added manually using QGIS during Step 5.

* added_upgrades_wsdot:
Potential upgraded DCFC sites added manually using QGIS during Step 5.

* all_gas_stations:
Locations of all gas stations collected from the Google API, and used as potential candidates.

* all_trips_count_full:
Count of long distance trips modeled between all zip code OD pairs in Washington.

* built_evse:
Locations of existing DCFC infrastructure.

* combo_candidates_automatic:
Potential new DCFC sites identified during Steps 2-4.

* combo_upgrades_automatic:
Potential upgraded DCFC sites identified during Steps 2-4.

* od_sp_geom_wsdot:
Geometry of all shortest paths between zip code OD pairs and corresponding trip counts.

* trip_infeasibility_combo:
Set of tables with geometry for currently infeasible paths identified during Steps 2-5. The "_after" qualifier indicates after automatic candidates/upgrades have been added. The "_after_add" qualifier indicates after both automatic and manual candidates/upgrades have been added.

* wa_bevs:
Registration data by zip code for EVs in Washington state.

### Project Data and Resources Used
* [ChargEVal](https://github.com/s-t-lab/ChargEval)
* [NREL Alternative Fuel Stations Data](https://developer.nrel.gov/docs/transportation/alt-fuel-stations-v1/all/#csv-output-format)
* [Washington EV Registration Data](https://data.wa.gov/Transportation/Electric-Vehicle-Population-Data/f6w7-q2d2)
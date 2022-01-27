library(foreach)
library(DBI)
library(RPostgres)

main_con = dbConnect(
  Postgres(),
  host = Sys.getenv("MAIN_HOST"),
  dbname = Sys.getenv("MAIN_DB"),
  user = Sys.getenv("MAIN_USER"),
  password = Sys.getenv("MAIN_PWD"),
  port = Sys.getenv("MAIN_PORT")
)

# Bins for spacing; 50 mile increment, last is minimum length considered
all_vals = c(500,450,400,350,300,250,200,150,100,0)

# Upload ideal candidate sites for each spacing
for (i in 1:(length(all_vals)-1)) {
  num_stations = as.integer(all_vals[i] /50)-1
  station_spacing = 1/(num_stations+1)
  current_spacing = 0
  for (j in 1:num_stations) {
    current_spacing = current_spacing + station_spacing
    insert_query =
      paste0(
        'INSERT INTO combo_candidates_wsdot (gid,trip_count,bev_count,cid,type,geom,length,dist_bin,dist_to_desired,rank)
          SELECT *
          FROM
          (SELECT segments.gid,
            segments.trip_count,
            segments.bev_count,
            candidates.id,
            candidates.type,
            candidates.geom,
            segments.length,
            ',all_vals[i],' AS dist_bin,
            ABS(candidates.ratio - ',current_spacing,') AS dist_to_desired,
            ROW_NUMBER() OVER (PARTITION BY segments.gid ORDER BY ABS(candidates.ratio - ',current_spacing,') ASC) AS rank
            FROM trip_infeasibility_combo_wsdot AS segments
            CROSS JOIN LATERAL
            (SELECT id,
              geom,
              \'GAS\' AS "type",
              ST_LineLocatePoint(segments.geom, geom) AS ratio
              FROM all_gas_stations
              -- Limit to infrastructure within 10 miles
              WHERE ST_DWithin(segments.geom, geom, .24)) AS candidates) AS ranked_locations
        WHERE rank = 1 AND length <= ',all_vals[i],' AND length > ',all_vals[i+1],' 
        ORDER BY trip_count DESC'
      )
    print(paste0(i,' ',j,'/',num_stations))
    rs = dbSendQuery(main_con, insert_query)
    dbClearResult(rs)
  }
}
dbDisconnect(main_con)

# Upload ideal upgrade sites for each spacing
for (i in 1:(length(all_vals)-1)) {
  num_stations = as.integer(all_vals[i] /50)-1
  station_spacing = 1/(num_stations+1)
  current_spacing = 0
  for (j in 1:num_stations) {
    current_spacing = current_spacing + station_spacing
    insert_query =
      paste0(
        'INSERT INTO combo_upgrades_wsdot (gid,trip_count,bev_count,cid,type,geom,length,dist_bin,dist_to_desired,rank)
          SELECT *
          FROM
          (SELECT segments.gid,
            segments.trip_count,
            segments.bev_count,
            candidates.id,
            candidates.type,
            candidates.geom,
            segments.length,
            ',all_vals[i],' AS dist_bin,
            ABS(candidates.ratio - ',current_spacing,') AS dist_to_desired,
            ROW_NUMBER() OVER (PARTITION BY segments.gid ORDER BY ABS(candidates.ratio - ',current_spacing,') ASC) AS rank
            FROM trip_infeasibility_combo_existing_wsdot AS segments
            CROSS JOIN LATERAL
            (SELECT bevse_id AS id,
              ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS geom,
              \'EXISTING\' AS "type",
              ST_LineLocatePoint(segments.geom, ST_Setsrid(st_makepoint(longitude, latitude), 4326)) AS ratio
              FROM built_evse
              -- Limit to infrastructure within 10 miles
              WHERE ST_DWithin(segments.geom, geom, .24) AND dcfc_count > 0 AND (connector_code = 2 OR connector_code = 3)) AS candidates) AS ranked_locations
        WHERE rank = 1 AND length <= ',all_vals[i],' AND length > ',all_vals[i+1],' 
        ORDER BY trip_count DESC'
      )
    print(paste0(i,' ',j,'/',num_stations))
    rs = dbSendQuery(main_con, insert_query)
    dbClearResult(rs)
  }
}
dbDisconnect(main_con)
# Function to set up all the required tables in the RDS database
setup_tables = function(table_qualifier) {

  main_con = dbConnect(
    Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )

  insert_query =
    paste0('CREATE TABLE trip_infeasibility_combo_wsdot_candidates',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text,
        length double precision,
        gid serial primary key,
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE trip_infeasibility_combo_wsdot_upgrades',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text,
        length double precision,
        gid serial primary key,
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_candidates',table_qualifier,' on trip_infeasibility_combo_wsdot_candidates',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_upgrades',table_qualifier,' on trip_infeasibility_combo_wsdot_upgrades',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE INDEX trip_infeasibility_combo_wsdot_geom_idx_candidates',table_qualifier,'
      ON trip_infeasibility_combo_wsdot_candidates',table_qualifier,'
      USING GIST (geom);')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE INDEX trip_infeasibility_combo_wsdot_geom_idx_upgrades',table_qualifier,'
      ON trip_infeasibility_combo_wsdot_upgrades',table_qualifier,'
      USING GIST (geom);')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CLUSTER trip_infeasibility_combo_wsdot_candidates',table_qualifier,' USING trip_infeasibility_combo_wsdot_geom_idx_candidates',table_qualifier,';')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CLUSTER trip_infeasibility_combo_wsdot_upgrades',table_qualifier,' USING trip_infeasibility_combo_wsdot_geom_idx_upgrades',table_qualifier,';')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE combo_wsdot_candidates',table_qualifier,' (
        id serial primary key,
        gid integer,
        trip_count integer,
        bev_count integer,
        cid integer,
        type varchar,
        geom geometry,
        length double precision,
        dist_bin integer,
        dist_to_desired double precision,
        rank integer
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE combo_wsdot_upgrades',table_qualifier,' (
        id serial primary key,
        gid integer,
        trip_count integer,
        bev_count integer,
        cid integer,
        type varchar,
        geom geometry,
        length double precision,
        dist_bin integer,
        dist_to_desired double precision,
        rank integer
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE trip_infeasibility_combo_wsdot_candidates_after',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text, 
        length double precision, 
        gid serial primary key, 
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE trip_infeasibility_combo_wsdot_upgrades_after',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text, 
        length double precision, 
        gid serial primary key, 
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_candidates_after',table_qualifier,' on trip_infeasibility_combo_wsdot_candidates_after',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_upgrades_after',table_qualifier,' on trip_infeasibility_combo_wsdot_upgrades_after',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('-- Create tables to hold updated infeasibility after manual sites
      CREATE TABLE trip_infeasibility_combo_wsdot_candidates_after_add',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text, 
        length double precision, 
        gid serial primary key, 
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE trip_infeasibility_combo_wsdot_upgrades_after_add',table_qualifier,' (
        trip_count integer,
        bev_count integer,
        od_pairs text, 
        length double precision, 
        gid serial primary key, 
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_candidates_after_add',table_qualifier,' on trip_infeasibility_combo_wsdot_candidates_after_add',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('create unique index unique_geom_index_combo_wsdot_upgrades_after_add',table_qualifier,' on trip_infeasibility_combo_wsdot_upgrades_after_add',table_qualifier,' (md5(geom::TEXT));')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('--Create tables for manually added sites; not fully implemented
      CREATE TABLE added_wsdot_candidates',table_qualifier,' (
        gid serial primary key,
        geom geometry
      );')
  dbExecute(main_con, insert_query)
  insert_query = 
    paste0('CREATE TABLE added_wsdot_upgrades',table_qualifier,' (
        gid serial primary key,
        geom geometry
      );')
  dbExecute(main_con, insert_query)

  # Close db connection
  dbDisconnect(main_con)
}


# Function that drops tables for a particular analysis run
drop_analysis_tables = function(table_qualifier) {
  main_con = dbConnect(
    Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )
  insert_query =
    paste0('DROP TABLE IF EXISTS ',
           ' trip_infeasibility_combo_wsdot_candidates',table_qualifier,
           ',trip_infeasibility_combo_wsdot_upgrades',table_qualifier,
           ',combo_wsdot_candidates',table_qualifier,
           ',combo_wsdot_upgrades',table_qualifier,
           ',trip_infeasibility_combo_wsdot_candidates_after',table_qualifier,
           ',trip_infeasibility_combo_wsdot_upgrades_after',table_qualifier,
           ',trip_infeasibility_combo_wsdot_candidates_after_add',table_qualifier,
           ',trip_infeasibility_combo_wsdot_upgrades_after_add',table_qualifier,
           ',added_wsdot_candidates',table_qualifier,
           ',added_wsdot_upgrades',table_qualifier,
           ',combo_wsdot_clustered_candidates',table_qualifier,
           ',combo_wsdot_clustered_upgrades',table_qualifier,
           ',combo_wsdot_automatic_candidates',table_qualifier,
           ',combo_wsdot_automatic_upgrades',table_qualifier
           )
  dbExecute(main_con, insert_query)
  dbDisconnect(main_con)
}


# Function that looks at stations, roads in the database and finds the infeasible segments
find_infeasible_segments = function(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step) {

  # Run in parallel to speed up
  cl = makeCluster(10)
  registerDoSNOW(cl)
  clusterEvalQ(cl, {
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
    NULL
  })

  # Show progress bar
  pb = txtProgressBar(max=nrow(all_trips), style=3)
  progress <- function(n) setTxtProgressBar(pb, n)
  opts <- list(progress = progress)

  # Get infeasible segments
  foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
    insert_query <-
      paste0(
        'INSERT INTO trip_infeasibility_combo_wsdot',full_qualifier,' (trip_count, bev_count, od_pairs, length, geom)
        (SELECT ',all_trips$trip_counts[row],' AS trip_count,
                ',all_trips$bev_counts[row],' AS bev_count,
                ',all_trips$origin[row],all_trips$destination[row],' AS od_pairs,
                sq3.spacings AS length,
                -- Select portion of the line that was infeasible
                ST_Linesubstring(sq3.line, sq3.ratio - sq3.ratio_lag, sq3.ratio) AS geom
        FROM
        -- Ratio of each infrastructure point (0-1), Lagged distance between prior point (0-1), Actual distance (mi), shortest OD line
        (SELECT sq2.ratio,
                (sq2.ratio - COALESCE((LAG(sq2.ratio) OVER (ORDER BY sq2.ratio)), 0)) AS ratio_lag,
                ((sq2.ratio - COALESCE((LAG(sq2.ratio) OVER (ORDER BY sq2.ratio)), 0)) * st_length(line) / 0.024) AS spacings,
                line
        -- Get shortest OD line, ratio of each infrastructure within X miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of existing evse infrastructure
                  (',
                  switch(analysis_step, # This is the selection for what infrastructure is considered available
                         paste0('SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                          FROM built_evse_wsdot
                          WHERE connector_code = 2 OR connector_code = 3'),
                         paste0('SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                          FROM built_evse_wsdot
                          WHERE connector_code = 2 OR connector_code = 3
                          UNION ALL
                          SELECT geom AS points
                          FROM combo_wsdot_automatic_candidates',table_qualifier),
                         paste0('SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                          FROM built_evse_wsdot
                          WHERE connector_code = 2 OR connector_code = 3
                          UNION ALL
                          SELECT geom AS points
                          FROM combo_wsdot_automatic_candidates',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM added_wsdot_candidates',table_qualifier),
                         paste0('SELECT geom AS points
                          FROM combo_wsdot_automatic_candidates',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM added_wsdot_candidates',table_qualifier),
                         paste0('SELECT geom AS points
                          FROM combo_wsdot_automatic_upgrades',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM combo_wsdot_automatic_candidates',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM added_wsdot_candidates',table_qualifier),
                         paste0('SELECT geom AS points
                          FROM combo_wsdot_automatic_upgrades',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM added_wsdot_upgrades',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM combo_wsdot_automatic_candidates',table_qualifier,'
                          UNION ALL
                          SELECT geom AS points
                          FROM added_wsdot_candidates',table_qualifier)
                         ),
                  ') AS sq
            -- Limit existing infrastructure within 10 miles from the line
             WHERE st_dwithin(line, sq.points, .24)
             UNION
             -- Concatenate with list of all shortest lines with ratio of 1.0
             SELECT 1.0,
                   line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line
             ORDER BY ratio ASC
             ) AS sq2
        ) AS sq3
        -- Limit to spacings over X miles
        WHERE (spacings > ',station_spacing,'))
        ON CONFLICT (md5(geom::TEXT))
        DO UPDATE
        SET trip_count = trip_infeasibility_combo_wsdot',full_qualifier,'.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_wsdot',full_qualifier,'.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_wsdot',full_qualifier,'.od_pairs || \', \' || EXCLUDED.od_pairs;'
      )
    rs = dbSendQuery(main_con, insert_query)
    dbClearResult(rs)
  }
  close(pb)
  stopCluster(cl)
  dbDisconnect(main_con)
}


# Function to search along infeasible segments, and select candidates to make feasible
locate_candidates = function(station_spacing, full_qualifier, analysis_step) {
  main_con = dbConnect(
    Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )
  
  # Bins for spacing; X mile increment, last is minimum length considered
  all_vals = seq(0,500,station_spacing)
  all_vals = all_vals[3:length(all_vals)]
  all_vals = c(0,all_vals)
  all_vals = rev(all_vals)

  # Upload ideal candidate sites for each spacing
  for (i in 1:(length(all_vals)-1)) {
    num_stations = as.integer(all_vals[i] / station_spacing)-1
    station_line_spacing = 1/(num_stations+1)
    current_line_spacing = 0
    for (j in 1:num_stations) {
      current_spacing = current_line_spacing + station_line_spacing
      insert_query =
        paste0(
          'INSERT INTO combo_wsdot',full_qualifier,' (gid,trip_count,bev_count,cid,type,geom,length,dist_bin,dist_to_desired,rank)
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
            ABS(candidates.ratio - ',current_line_spacing,') AS dist_to_desired,
            ROW_NUMBER() OVER (PARTITION BY segments.gid ORDER BY ABS(candidates.ratio - ',current_line_spacing,') ASC) AS rank
            FROM trip_infeasibility_combo_wsdot',full_qualifier,' AS segments 
            CROSS JOIN LATERAL',
            ifelse(
              analysis_step %in% c(1,2,3),
              '(SELECT id,
                geom,
                \'GAS\' AS "type",
                ST_LineLocatePoint(segments.geom, geom) AS ratio
                FROM all_gas_stations
                -- Limit to infrastructure within 10 miles
                WHERE ST_DWithin(segments.geom, geom, .24)) AS candidates) AS ranked_locations ',
                '(SELECT bevse_id AS id,
                ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS geom,
                \'EXISTING\' AS "type",
                ST_LineLocatePoint(segments.geom, ST_Setsrid(st_makepoint(longitude, latitude), 4326)) AS ratio
                FROM built_evse_wsdot
                -- Limit to infrastructure within 10 miles
                WHERE ST_DWithin(segments.geom, geom, .24) AND dcfc_count > 0 AND (connector_code = 2 OR connector_code = 3)) AS candidates) AS ranked_locations '
            ),
          'WHERE rank = 1 AND length <= ',all_vals[i],' AND length > ',all_vals[i+1],' 
          ORDER BY trip_count DESC'
        )
      print(paste0(i,' ',j,'/',num_stations))
      rs = dbSendQuery(main_con, insert_query)
      dbClearResult(rs)
    }
  }
  dbDisconnect(main_con)
}


# Function to group candidate sites by clusters and insert into new table
cluster_candidates = function(full_qualifier, analysis_step) {
  main_con = dbConnect(
    Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )
  
  # First cluster the sites
  if (analysis_step %in% c(1,2,3)) {
    insert_query =
      paste0(
        '--Use single clustering
        SELECT *,
        ST_ClusterDBSCAN(geom, eps:=.24, minpoints:=1) OVER () AS cluster_id
        INTO combo_wsdot_clustered',full_qualifier,'
        FROM combo_wsdot',full_qualifier,';'
      )
  } else {
    insert_query = 
      paste0('-- Use two clusterings - one small then one wider
            SELECT *, ST_ClusterDBSCAN(geom, eps:=.20, minpoints:=1) OVER () AS cluster_id
            INTO combo_wsdot_clustered',full_qualifier,'
            FROM
            	(SELECT cid_counts.cid,
            	cid_counts.cid_count,
            	clusters_1.trip_count,
            	clusters_1.bev_count,
            	clusters_1.dist_bin,
            	clusters_1.dist_to_desired,
            	clusters_1.geom,
            	ROW_NUMBER() OVER (PARTITION BY cluster_1_id ORDER BY cid_count DESC) AS rank
            	FROM
            		(SELECT *,
            		ST_ClusterDBSCAN(geom, eps:=.08, minpoints:=1) OVER () AS cluster_1_id
            		FROM combo_wsdot',full_qualifier,') AS clusters_1
            	JOIN
            		(SELECT COUNT(*) AS cid_count, cid
            		FROM
            			(SELECT *,
            			ST_ClusterDBSCAN(geom, eps:=.08, minpoints:=1) OVER () AS cluster_1_id
            			FROM combo_wsdot',full_qualifier,') AS clusters_2
            		GROUP BY cid) AS cid_counts
            	ON clusters_1.cid = cid_counts.cid) AS ranked_cids
            WHERE ranked_cids.rank = 1
            ORDER BY cid DESC;'
      )
  }
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)

  # Then pick the best site from each cluster
  insert_query = 
    paste0(
      '-- Select the best candidate site from each spatial cluster
      SELECT *
      INTO combo_wsdot_automatic',full_qualifier,'
      FROM
      (SELECT cid_counts.cid,
       		cid_counts.cid_count,
       		combo_wsdot_clustered',full_qualifier,'.cluster_id,
       		combo_wsdot_clustered',full_qualifier,'.trip_count,
       		combo_wsdot_clustered',full_qualifier,'.bev_count,
       		combo_wsdot_clustered',full_qualifier,'.dist_bin,
       		combo_wsdot_clustered',full_qualifier,'.dist_to_desired,
       		combo_wsdot_clustered',full_qualifier,'.geom,
      		ROW_NUMBER() OVER (PARTITION BY cluster_id ORDER BY cid_counts.cid_count DESC) AS rank
      FROM combo_wsdot_clustered',full_qualifier,'
      JOIN
      (SELECT COUNT(*) AS cid_count, cid
      FROM combo_wsdot_clustered',full_qualifier,'
      GROUP BY cid) AS cid_counts
      ON combo_wsdot_clustered',full_qualifier,'.cid = cid_counts.cid) AS ranked_cids
      WHERE ranked_cids.rank = 1
      ORDER BY cid DESC;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
  dbDisconnect(main_con)
}


# Function to run full analysis of candidates and upgrades
main = function(station_spacing, max_dist_to_inf, table_qualifier, add_manual_stations) {

  ## Drop tables for scenario if they exist
  drop_analysis_tables(table_qualifier)
  
  ## Create all tables
  setup_tables(table_qualifier)
  
  ## Get all existing trips
  main_con = dbConnect(
    Postgres(),
    host = Sys.getenv("MAIN_HOST"),
    dbname = Sys.getenv("MAIN_DB"),
    user = Sys.getenv("MAIN_USER"),
    password = Sys.getenv("MAIN_PWD"),
    port = Sys.getenv("MAIN_PORT")
  )
  
  # Query the set of ODs between all zip codes in the database
  all_trips <- DBI::dbGetQuery(main_con,
                               "SELECT *
                               FROM (SELECT origin,
                                            destination,
                                            SUM(ccounts) AS trip_counts,
                                            -- Left join leaves zip codes as null if not in wa_bevs
                                            COALESCE(SUM(evcounts),0) AS bev_counts
                                    FROM (SELECT
                                          CASE WHEN origin <= destination THEN origin ELSE destination END AS origin,
                                          CASE WHEN origin <= destination THEN destination ELSE origin END AS destination,
                                          ccounts,
                                          evcounts
                                          FROM all_trips_count_full
                                          LEFT JOIN
                                          (SELECT COUNT(*) AS evcounts,
                                                  zip_code
                                          FROM wa_bevs
                                          WHERE connector_code = 2 OR connector_code = 3
                                          GROUP BY zip_code) AS wa_bevs
                                          ON all_trips_count_full.origin = wa_bevs.zip_code) AS ordered
                                    GROUP BY origin, destination) AS unique_ods;")
  dbDisconnect(main_con)

  ## Set currently infeasible segments
  print("Step 1")
  analysis_step = 1
  full_qualifier = paste0("_candidates", table_qualifier)
  find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)

  ## Select a round of candidates that make all segments feasible (so long as it is possible)
  locate_candidates(station_spacing, full_qualifier, analysis_step)
  
  ## Cluster candidates to consolidate into best ones
  cluster_candidates(full_qualifier, analysis_step)

  ## Get new infeasible segments
  print("Step 2")
  analysis_step = 2
  full_qualifier = paste0("_candidates_after", table_qualifier)
  find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)
  
  ## Manually add more candidates using QGIS
  if (add_manual_stations) {
    # Pause not implemented
    print("Step 3")
    analysis_step = 3
    ## Get final infeasible segments
    full_qualifier = paste0("_candidates_after_add", table_qualifier)
    find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)
  }
  
  ## Drop out new proposed sites, get infeasible segments for upgrades
  print("Step 4")
  analysis_step = 4
  full_qualifier = paste0("_upgrades", table_qualifier)
  find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)
  
  ## Select a round of upgrades that make all segments feasible (so long as it is possible)
  locate_candidates(station_spacing, full_qualifier, analysis_step)

  ## Cluster candidates to consolidate into best ones
  cluster_candidates(full_qualifier, analysis_step)

  ## Get new infeasible segments
  print("Step 5")
  analysis_step = 5
  full_qualifier = paste0("_upgrades_after", table_qualifier)
  find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)
  
  ## Manually add more upgrades using QGIS
  if (add_manual_stations) {
    # Pause not implemented
    print("Step 6")
    analysis_step = 6
    ## Get final infeasible segments
    full_qualifier = paste0("_upgrades_after_add", table_qualifier)
    find_infeasible_segments(all_trips, station_spacing, full_qualifier, table_qualifier, analysis_step)
  }

  print("Analysis Completed")
}



library(foreach)
library(doSNOW)
library(DBI)
library(RPostgres)

# This script creates tables and runs infeasibility analysis on the evi-dss database
# Results are saved to the added tables on the database
# First run secret.R to save database credentials in environment
# Also Make sure that ip inbound rule exists on the RDS instance

# Analysis settings:
station_spacing = 75 # Maximum number of miles between candidate/existing sites
max_dist_to_inf = 10 # Miles away from roadway segments to look for candidate sites; not implemented
table_qualifier = "_75" # String to identify the tables from this particular analysis run
add_manual_stations = FALSE # Set to True if planning to pause in middle and use QGIS to add stations

# Run analysis:
main(station_spacing, max_dist_to_inf, table_qualifier, add_manual_stations)

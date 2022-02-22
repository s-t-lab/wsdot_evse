# Upload infeasibility in parallel
library(foreach)
library(doSNOW)
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

# Maximum miles between stations
station_spacing = 75

# Get only unique OD/DO combos
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

pb = txtProgressBar(max=nrow(all_trips), style=3)
progress <- function(n) setTxtProgressBar(pb, n)
opts <- list(progress = progress)


# INITIAL Candidates
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of existing evse infrastructure
                  (SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                  FROM built_evse_wsdot
                  WHERE connector_code = 2 OR connector_code = 3) AS sq
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
        SET trip_count = trip_infeasibility_combo_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)
# Now go to locate candidates R script to select candidates



# UPDATE Candidates
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_after_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of existing evse infrastructure, and additional candidate sites
                  (SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                  FROM built_evse_wsdot
                  WHERE connector_code = 2 OR connector_code = 3
                  UNION ALL
                  SELECT geom AS points
                  FROM combo_candidates_automatic_wsdot) AS sq
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
        SET trip_count = trip_infeasibility_combo_after_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_after_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_after_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)



# UPDATE W/Added Sites Candidates
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_after_add_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of existing evse infrastructure, and additional candidate sites
                  (SELECT ST_Setsrid(st_makepoint(longitude, latitude), 4326) AS points
                  FROM built_evse_wsdot
                  WHERE connector_code = 2 OR connector_code = 3
                  UNION ALL
                  SELECT geom AS points
                  FROM combo_candidates_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM added_sites_wsdot) AS sq
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
        SET trip_count = trip_infeasibility_combo_after_add_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_after_add_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_after_add_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)



# INITIAL Upgrades
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_existing_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of candidate sites
                  (SELECT geom AS points
                  FROM combo_candidates_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM added_sites_wsdot) AS sq
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
        SET trip_count = trip_infeasibility_combo_existing_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_existing_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_existing_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)
# Now go to locate candidates R script to select upgrades



# UPDATE Upgrades
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_existing_after_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of candidate sites
                  (SELECT geom AS points
                  FROM combo_upgrades_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM combo_candidates_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM added_sites_wsdot) AS sq
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
        SET trip_count = trip_infeasibility_combo_existing_after_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_existing_after_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_existing_after_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)



# UPDATE W/Added Sites Upgrades
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO trip_infeasibility_combo_existing_after_add_wsdot (trip_count, bev_count, od_pairs, length, geom)
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
        -- Get shortest OD line, ratio of each infrastructure within 10 miles, concat to shortest OD line, 1.0
        -- Ratio is 0-1 from origin, to the orthogonal point on shortest OD line where infrastructure lies
        FROM (SELECT ST_LineLocatePoint(line, sq.points) AS ratio,
                     line
             FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS line,
                  -- Get the points of candidate sites
                  (SELECT geom AS points
                  FROM combo_upgrades_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM added_upgrades_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM combo_candidates_automatic_wsdot
                  UNION ALL
                  SELECT geom AS points
                  FROM added_sites_wsdot) AS sq
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
        SET trip_count = trip_infeasibility_combo_existing_after_add_wsdot.trip_count + EXCLUDED.trip_count,
            bev_count = trip_infeasibility_combo_existing_after_add_wsdot.bev_count + EXCLUDED.bev_count,
            od_pairs = trip_infeasibility_combo_existing_after_add_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)
dbDisconnect(main_con)
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

# Calculate shortest path geometry for each OD and save
foreach(row=1:nrow(all_trips), .options.snow=opts, .noexport="main_con", .packages=c("DBI","RPostgres")) %dopar% {
  insert_query <-
    paste0(
      'INSERT INTO od_sp_geom_wsdot (trip_count, bev_count, od_pairs, geom)
      (SELECT ',all_trips$trip_counts[row],' AS trip_count,
              ',all_trips$bev_counts[row],' AS bev_count,
              ',all_trips$origin[row],all_trips$destination[row],' AS od_pairs,
              sq.shortest_path AS geom
      FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS sq)
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

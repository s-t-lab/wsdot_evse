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

insert_query <-
  paste0(
    '-- Create table
    CREATE TABLE od_sp_geom_wsdot (
      trip_count integer,
      bev_count integer,
      od_pairs text, 
      gid serial primary key, 
      geom geometry
    );'
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)

insert_query <-
  paste0(
    'create unique index unique_geom_index_od_sp_geom_wsdot on od_sp_geom_wsdot (md5(geom::TEXT));'
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)

# Get only unique OD/DO combos
insert_query = paste0(
  'WITH query1 AS (
  SELECT origin, destination,
  SUM(ret) + SUM(dep) AS trips,
  SUM(oevs)/SUM(ocars) AS o_ratio
  FROM wa_evtrips
  GROUP BY origin, destination)
  SELECT *, o_ratio*trips AS ev_trips
  FROM query1
  ORDER BY ev_trips DESC'
)
all_trips = dbGetQuery(main_con, insert_query)

cl = makeCluster(10)
registerDoSNOW(cl)

clusterEvalQ(cl, {
  library(DBI)
  library(RPostgres)
  main_con = dbConnect(
        Postgres(),
        host="cp84-chargeval.coavcn49hnn6.us-west-2.rds.amazonaws.com",
        dbname="chargeval_prod",
        user="tundrafire",
        password="!-RJhpyp522R5u",
        port="5432"
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
      (SELECT ',all_trips$trips[row],' AS trip_count,
              ',all_trips$ev_trips[row],' AS bev_count,
              ',all_trips$origin[row],all_trips$destination[row],' AS od_pairs,
              sq.shortest_path AS geom
      FROM sp_od2(',all_trips$origin[row],', ',all_trips$destination[row],') AS sq)
      ON CONFLICT (md5(geom::TEXT))
      DO UPDATE
      SET trip_count = od_sp_geom_wsdot.trip_count + EXCLUDED.trip_count,
          bev_count = od_sp_geom_wsdot.bev_count + EXCLUDED.bev_count,
          od_pairs = od_sp_geom_wsdot.od_pairs || \', \' || EXCLUDED.od_pairs;'
    )
  rs = dbSendQuery(main_con, insert_query)
  dbClearResult(rs)
}
close(pb)
stopCluster(cl)

insert_query <-
  paste0(
    "WITH all_sites AS (
    SELECT ","'","c_","'"," || ROW_NUMBER() OVER(ORDER BY cid)::text AS pid, geom AS points
    FROM combo_candidates_automatic_wsdot
    UNION ALL
    SELECT ","'","u_","'"," || ROW_NUMBER() OVER(ORDER BY cid)::text AS pid, geom AS points
    FROM combo_upgrades_automatic_wsdot
    UNION ALL
    SELECT ","'","c_add_","'"," || ROW_NUMBER() OVER(ORDER BY id)::text AS pid, geom AS points
    FROM added_sites_wsdot
    UNION ALL
    SELECT ","'","u_add_","'"," || ROW_NUMBER() OVER(ORDER BY id)::text AS pid, geom AS points
    FROM added_upgrades_wsdot
    )
    SELECT *
      INTO all_sites_wsdot
    FROM all_sites"
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)

insert_query <-
  paste0(
    'CREATE INDEX all_sites_wsdot_geom_idx
    ON all_sites_wsdot
    USING GIST (points);'
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)

insert_query <-
  paste0(
    'CREATE INDEX od_sp_wsdot_geom_idx
    ON od_sp_geom_wsdot
    USING GIST (geom);'
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)

insert_query <-
  paste0(
    'SELECT query1.pid AS pid, trips, bevs, num_segments, points
    INTO long_distance_counts_wsdot
    FROM
    (SELECT pid, SUM(trip_count) AS trips, SUM(bev_count) AS bevs, COUNT(*) AS num_segments
      FROM all_sites_wsdot
      CROSS JOIN od_sp_geom_wsdot AS lines
      WHERE ST_DWithin(points, lines.geom, .024)
      GROUP BY pid
    ) AS query1
    JOIN
    (SELECT pid, points
      FROM all_sites_wsdot
    ) AS query2
    ON query1.pid = query2.pid'
  )
rs = dbSendQuery(main_con, insert_query)
dbClearResult(rs)
dbDisconnect(main_con)
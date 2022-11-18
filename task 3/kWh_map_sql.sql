SELECT *, ST_BUFFER(geom, .001) buffered_geom
INTO "WA_roads_buffered_wsdot"
FROM "WA_roads";

CREATE INDEX geom_index_wa_roads_buffered
  ON "WA_roads_buffered_wsdot"
  USING GIST (buffered_geom);

SELECT id, SUM(bev_count) bev_ld_aadt, SUM(trip_count) ld_aadt
INTO "WA_roads_trip_counts_wsdot"
FROM "WA_roads_buffered_wsdot"
JOIN od_sp_geom_wsdot
ON ST_INTERSECTS(buffered_geom, od_sp_geom_wsdot.geom)
GROUP BY id;

SELECT "WA_roads".id id,
"WA_roads_trip_counts_wsdot".ld_aadt ld_aadt,
"WA_roads_trip_counts_wsdot".bev_ld_aadt bev_ld_aadt,
"WA_roads".geom geom
INTO "WA_roads_trip_counts_geom_wsdot"
FROM "WA_roads"
JOIN "WA_roads_trip_counts_wsdot"
ON "WA_roads".id = "WA_roads_trip_counts_wsdot".id;

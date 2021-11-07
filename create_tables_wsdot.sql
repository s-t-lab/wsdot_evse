-- Create trip_infeasibility tables
CREATE TABLE trip_infeasibility_combo_wsdot (
    trip_count integer, 
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_wsdot on trip_infeasibility_combo_wsdot (md5(geom::TEXT));


-- Fix geometry SRID if necessary from uploaded data
SELECT UpdateGeometrySRID('trip_infeasibility_combo_wsdot','geom',4326);


-- Add spatial indexes to infeasible segments
CREATE INDEX trip_infeasibility_combo_wsdot_geom_idx
ON trip_infeasibility_combo_wsdot
USING GIST (geom);

CLUSTER trip_infeasibility_combo_wsdot USING trip_infeasibility_combo_wsdot_geom_idx;


-- Probably run these after everything is loaded
VACUUM ANALYZE trip_infeasibility_combo_wsdot;
VACUUM ANALYZE all_gas_stations;
VACUUM ANALYZE city_limits_centroids;


-- Create candidate site tables
CREATE TABLE combo_candidates_wsdot (
    id serial primary key,
    gid integer,
    trip_count integer,
    cid integer,
    type varchar,
    geom geometry,
    length double precision,
    dist_bin integer,
    dist_to_desired double precision,
    rank integer
);


-- Create secondary tables to hold updated infeasibility after adding candidate sites
CREATE TABLE trip_infeasibility_combo_after_wsdot (
    trip_count integer, 
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_after_wsdot on trip_infeasibility_combo_after_wsdot (md5(geom::TEXT));


--BEV Code (Join to main insert query to weight trips by EV registration)
LEFT JOIN
Get count of EVs registered in origin zip code, 0 if none registered
(SELECT COALESCE(COUNT(*), 0) AS evcount,
       zip_code
FROM wa_bevs
WHERE connector_code = 2 OR connector_code = 3
GROUP BY zip_code) AS wa_bevs
ON at1.origin = wa_bevs.zip_code


-- WSDOT cities are in different SRID (run after adding centroids from QGIS)
-- Also need to transform the geometry
SELECT UpdateGeometrySRID('city_limits_centroids','geom',3857);
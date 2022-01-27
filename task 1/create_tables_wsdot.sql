-- Create trip_infeasibility table
CREATE TABLE trip_infeasibility_combo_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_wsdot on trip_infeasibility_combo_wsdot (md5(geom::TEXT));


-- Add spatial indexes to infeasible segments
CREATE INDEX trip_infeasibility_combo_wsdot_geom_idx
ON trip_infeasibility_combo_wsdot
USING GIST (geom);

CLUSTER trip_infeasibility_combo_wsdot USING trip_infeasibility_combo_wsdot_geom_idx;
VACUUM ANALYZE trip_infeasibility_combo_wsdot;
VACUUM ANALYZE all_gas_stations;


-- Create candidate site table
CREATE TABLE combo_candidates_wsdot (
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
);

-- Create upgrades site table
CREATE TABLE combo_upgrades_wsdot (
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
);


-- Create tables to hold updated infeasibility after automatic candidate sites, then after manual candidate sites
CREATE TABLE trip_infeasibility_combo_after_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_after_wsdot on trip_infeasibility_combo_after_wsdot (md5(geom::TEXT));

CREATE TABLE trip_infeasibility_combo_after_add_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_after_add_wsdot on trip_infeasibility_combo_after_add_wsdot (md5(geom::TEXT));

-- Create table to hold updated infeasibility after dropping out existing stations
CREATE TABLE trip_infeasibility_combo_existing_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_existing_wsdot on trip_infeasibility_combo_existing_wsdot (md5(geom::TEXT));

-- Create tables to hold updated infeasibility after after automatic upgrade sites, then after manual candidate sites
CREATE TABLE trip_infeasibility_combo_existing_after_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_existing_after_wsdot on trip_infeasibility_combo_existing_after_wsdot (md5(geom::TEXT));

CREATE TABLE trip_infeasibility_combo_existing_after_add_wsdot (
    trip_count integer,
    bev_count integer,
    od_pairs text, 
    length double precision, 
    gid serial primary key, 
    geom geometry
);
create unique index unique_geom_index_combo_existing_after_add_wsdot on trip_infeasibility_combo_existing_after_add_wsdot (md5(geom::TEXT));
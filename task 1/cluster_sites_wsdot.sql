-- Cluster candidate sites based on DBSCAN algorithm w/10mi radius
SELECT *,
		ST_ClusterDBSCAN(geom, eps:=.24, minpoints:=1) OVER () AS cluster_id
INTO combo_candidates_clustered_wsdot
FROM combo_candidates_wsdot;

-- Cluster upgrade sites based on DBSCAN algorithm
-- Uses two clusterings - one small then one wider
SELECT *, ST_ClusterDBSCAN(geom, eps:=.20, minpoints:=1) OVER () AS cluster_id
INTO combo_upgrades_clustered_wsdot
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
		FROM combo_upgrades_wsdot) AS clusters_1
	JOIN
		(SELECT COUNT(*) AS cid_count, cid
		FROM
			(SELECT *, ST_ClusterDBSCAN(geom, eps:=.08, minpoints:=1) OVER () AS cluster_1_id
			FROM combo_upgrades_wsdot) AS clusters_2
		GROUP BY cid) AS cid_counts
	ON clusters_1.cid = cid_counts.cid) AS ranked_cids
WHERE ranked_cids.rank = 1
ORDER BY cid DESC;


-- Select the best candidate site from each spatial cluster
SELECT *
INTO combo_candidates_automatic_wsdot
FROM
(SELECT cid_counts.cid,
 		cid_counts.cid_count,
 		combo_candidates_clustered_wsdot.cluster_id,
 		combo_candidates_clustered_wsdot.trip_count,
 		combo_candidates_clustered_wsdot.bev_count,
 		combo_candidates_clustered_wsdot.dist_bin,
 		combo_candidates_clustered_wsdot.dist_to_desired,
 		combo_candidates_clustered_wsdot.geom,
		ROW_NUMBER() OVER (PARTITION BY cluster_id ORDER BY cid_count DESC) AS rank
FROM combo_candidates_clustered_wsdot
JOIN
(SELECT COUNT(*) AS cid_count, cid
FROM combo_candidates_clustered_wsdot
GROUP BY cid) AS cid_counts
ON combo_candidates_clustered_wsdot.cid = cid_counts.cid) AS ranked_cids
WHERE ranked_cids.rank = 1
ORDER BY cid DESC;

-- Select the best upgrade site from each spatial cluster
SELECT *
INTO combo_upgrades_automatic_wsdot
FROM
(SELECT cid_counts.cid,
 		cid_counts.cid_count,
 		combo_upgrades_clustered_wsdot.cluster_id,
 		combo_upgrades_clustered_wsdot.trip_count,
 		combo_upgrades_clustered_wsdot.bev_count,
 		combo_upgrades_clustered_wsdot.dist_bin,
 		combo_upgrades_clustered_wsdot.dist_to_desired,
 		combo_upgrades_clustered_wsdot.geom,
		ROW_NUMBER() OVER (PARTITION BY cluster_id ORDER BY cid_count DESC) AS rank
FROM combo_upgrades_clustered_wsdot
JOIN
(SELECT COUNT(*) AS cid_count, cid
FROM combo_upgrades_clustered_wsdot
GROUP BY cid) AS cid_counts
ON combo_upgrades_clustered_wsdot.cid = cid_counts.cid) AS ranked_cids
WHERE ranked_cids.rank = 1
ORDER BY cid DESC;
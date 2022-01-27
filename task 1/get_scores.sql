SELECT query1.pid AS pid, trips, bevs, num_segments, points
INTO combo_candidates_final_scored_wsdot
FROM
(SELECT pid, SUM(trip_count) AS trips, SUM(bev_count) AS bevs, COUNT(*) AS num_segments
FROM
	(SELECT 'candidate_' || ROW_NUMBER() OVER(ORDER BY cid)::text AS pid, geom AS points
	FROM combo_candidates_final_wsdot
	UNION ALL
	SELECT 'added_' || ROW_NUMBER() OVER(ORDER BY id)::text AS pid, geom AS points
	FROM added_sites) AS points
CROSS JOIN trip_infeasibility_combo_wsdot AS lines
WHERE ST_DWithin(points, lines.geom, .24)
GROUP BY pid) AS query1
JOIN
(SELECT pid, points
FROM
	(SELECT 'candidate_' || ROW_NUMBER() OVER(ORDER BY cid)::text AS pid, geom AS points
	FROM combo_candidates_final_wsdot
	UNION ALL
	SELECT 'added_' || ROW_NUMBER() OVER(ORDER BY id)::text AS pid, geom AS points
	FROM added_sites) AS points
) AS query2
ON query1.pid = query2.pid

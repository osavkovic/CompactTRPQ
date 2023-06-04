----------------------------------------------------------------------------
-- (positive = true)/T[-???, 0]/F/meets/
----------------------------------------------------------------------------
-- NOTE: Some additional DISTINCT have been introduced as the data contains duplicates !
----------------------------------------------------------------------------
-- No fancy join algorithms for temporal data as hash joins perform fine for this dataset
-- for datasets with less selective node identifiers in edges you may consider an index based join
-- pointers for index based joins are in the paper
----------------------------------------------------------------------------

DROP TABLE IF EXISTS pos_contact_v1, pos_contact_v2, pos_contact_points, pos_contact_points_v2, pos_contact_v1_coalesced, pos_contact_v2_coalesced;

----------------------------------------------------------------------------
-- V1 (o1, o2, d, [alpha])
----------------------------------------------------------------------------
CREATE TABLE pos_contact_v1 AS
WITH 
nodes_pos AS ( -- (positive = true)
  SELECT id AS o1, id AS o2, 0 AS d, ts, te FROM node WHERE type = 'person' AND prop1 = 'pos' 
),
prev AS ( -- (positive = true)/T[-???, 0]
  SELECT DISTINCT o1, o2, d+generate_series(-???, 0) AS d, ts, te FROM nodes_pos 
),
edges_meets AS ( -- meets
  SELECT DISTINCT src AS o1, dst AS o2, 0 AS d, ts, te FROM edge WHERE label = 'meets' 
),
join1 AS ( -- (positive = true)/T[-???, 0]/F/meets/
  SELECT a.o1, b.o2, a.d+b.d as d,
  Greatest(a.ts+a.d, b.ts)-a.d as ts,
  Least(a.te+a.d, b.te)-a.d as te
  FROM prev a JOIN edges_meets b ON a.o2 = b.o1 AND a.ts+a.d <= b.te AND b.ts <= a.te+a.d
)
SELECT * FROM join1;
----------------------------------------------------------------------------
-- V2 (o1, o2, t, [delta])
----------------------------------------------------------------------------
CREATE TABLE pos_contact_v2 AS
WITH 
nodes_pos AS ( -- (positive = true)
  SELECT id AS o1, id AS o2, t, 0 AS ds, 0 AS de FROM node, generate_series(ts, te) t WHERE type = 'person' AND prop1 = 'pos' 
),
prev AS ( -- (positive = true)/T[-???, 0]
  SELECT DISTINCT o1, o2, t, ds-??? AS ds, de+0 AS de FROM nodes_pos 
),
edges_meets AS ( -- meets
  SELECT DISTINCT src AS o1, dst AS o2, t, 0 AS ds, 0 AS de FROM edge, generate_series(ts, te) t WHERE label = 'meets' 
),
join1 AS ( -- (positive = true)/T[-???, 0]/F/meets/
  SELECT a.o1, b.o2, 
  a.t,
  b.ds + b.t - a.t AS ds,
  b.de + b.t - a.t AS de
  FROM prev a JOIN edges_meets b ON a.o2 = b.o1 AND b.t BETWEEN a.t + a.ds AND a.t + a.de 
)
SELECT * FROM join1;

----------------------------------------------------------------------------
-- points
----------------------------------------------------------------------------
CREATE TABLE pos_contact_points AS
SELECT DISTINCT o1, o2, generate_series(ts, te) AS t1, generate_series(ts, te)+d AS t2 -- Note: this is not a cartesian product!!
FROM pos_contact_v1;

-- CREATE TABLE pos_contact_points_v2 AS
-- SELECT DISTINCT o1, o2, t AS t1, t+generate_series(ds, de) AS t2
-- FROM pos_contact_v2;

----------------------------------------------------------------------------
-- V1 (o1, o2, d, [alpha]) COALESCED
----------------------------------------------------------------------------

CREATE TABLE pos_contact_v1_coalesced AS 
WITH RECURSIVE T0 AS 
(
  SELECT o1, o2, d, ts, te+1 AS te FROM pos_contact_v1 -- switch [ts, te] -> [ts, te)
),
T1 AS (
  SELECT 1 AS S, 0 AS E, ts AS T, o1, o2, d FROM T0
  UNION ALL
  SELECT 0, 1, te AS T, o1, o2, d FROM T0
),
T2 AS (
  SELECT
  SUM(S) OVER w AS cS,
  SUM(E) OVER w AS cE,
  SUM(S) OVER w - S AS pS,
  SUM(E) OVER w - E As pE,
  T,
  o1, o2, d
  FROM T1
  WINDOW w AS (PARTITION BY o1, o2, d ORDER BY T, E ROWS UNBOUNDED PRECEDING)
),
T3 AS (
  SELECT cS, cE, o1, o2, d, LAG(T, 1) OVER (PARTITION BY o1, o2, d ORDER BY T) AS S, T AS E 
  FROM T2 
  WHERE cS = cE -- number of starts and ends up to and including this time point is equal, thus this time point closes an open interval, so this will be an end time point
  OR pS = pE -- number of starts and ends up to and excluding this time point is equal, thus no open intervals from before, so this will be a start time point
)
SELECT o1, o2, d, S as ts, E-1 as te -- switch [ts, te) -> [ts, te]
FROM T3 
WHERE cS = cE; -- we fetched the start time points using LAG, so now we only keep the ends

----------------------------------------------------------------------------
-- V2 (o1, o2, t, [delta]) COALESCED
----------------------------------------------------------------------------

CREATE TABLE pos_contact_v2_coalesced AS 
WITH RECURSIVE T0 AS 
(
  SELECT o1, o2, t AS d, ds AS ts, de+1 AS te FROM pos_contact_v2 -- switch (t, [ds, de]) -> (d, [ts, te]) and switch [ts, te] -> [ts, te)
),
T1 AS (
  SELECT 1 AS S, 0 AS E, ts AS T, o1, o2, d FROM T0
  UNION ALL
  SELECT 0, 1, te AS T, o1, o2, d FROM T0
),
T2 AS (
  SELECT
  SUM(S) OVER w AS cS,
  SUM(E) OVER w AS cE,
  SUM(S) OVER w - S AS pS,
  SUM(E) OVER w - E As pE,
  T,
  o1, o2, d
  FROM T1
  WINDOW w AS (PARTITION BY o1, o2, d ORDER BY T, E ROWS UNBOUNDED PRECEDING)
),
T3 AS (
  SELECT cS, cE, o1, o2, d, LAG(T, 1) OVER (PARTITION BY o1, o2, d ORDER BY T) AS S, T AS E 
  FROM T2 
  WHERE cS = cE -- number of starts and ends up to and including this time point is equal, thus this time point closes an open interval, so this will be an end time point
  OR pS = pE -- number of starts and ends up to and excluding this time point is equal, thus no open intervals from before, so this will be a start time point
)
SELECT o1, o2, d AS t, S as ds, E-1 as de -- switch [ts, te) -> [ts, te] and (d, [ts, te]) -> (t, [ds, de])
FROM T3 
WHERE cS = cE; -- we fetched the start time points using LAG, so now we only keep the ends

----------------------------------------------------------------------------
-- MEASURES
----------------------------------------------------------------------------

SELECT count(*) FROM pos_contact_points;
SELECT count(*) FROM pos_contact_v1_coalesced;
SELECT count(*) FROM pos_contact_v2_coalesced;

INSERT INTO exp_sizes SELECT now(), '(positive = true)/T[-???, 0]/F/meets/', (SELECT count(*) FROM pos_contact_points), (SELECT count(*) FROM pos_contact_v1), (SELECT count(*) FROM pos_contact_v1_coalesced), (SELECT count(*) FROM pos_contact_v2), (SELECT count(*) FROM pos_contact_v2_coalesced), ?!?, ???;

DROP TABLE IF EXISTS pos_contact_v1, pos_contact_v2, pos_contact_points, pos_contact_points_v2, pos_contact_v1_coalesced, pos_contact_v2_coalesced;

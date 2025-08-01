-- FULL QUERY FOR x = 300 IN U^d

EXPLAIN (ANALYZE, TIMING OFF)
WITH RECURSIVE
nodes_pos AS ( -- (positive = true)
  SELECT id AS o1, id AS o2, t, 0 AS ds, 0 AS de FROM node, generate_series(ts, te) t WHERE type = 'person' AND prop1 = 'pos' 
),
prev AS ( -- (positive = true)/T[-300, 0]
  SELECT DISTINCT o1, o2, t, ds-300 AS ds, de+0 AS de FROM nodes_pos 
),
edges_meets AS ( -- meets
  SELECT DISTINCT src AS o1, dst AS o2, t, 0 AS ds, 0 AS de FROM edge, generate_series(ts, te) t WHERE label = 'meets' 
),
join1 AS ( -- (positive = true)/T[-300, 0]/F/meets/
  SELECT a.o1, b.o2, 
  a.t,
  b.ds + b.t - a.t AS ds,
  b.de + b.t - a.t AS de
  FROM prev a JOIN edges_meets b ON a.o2 = b.o1 AND b.t BETWEEN a.t + a.ds AND a.t + a.de 
),
T0 AS 
(
  SELECT o1, o2, t AS d, ds AS ts, de+1 AS te FROM join1 -- switch (t, [ds, de]) -> (d, [ts, te]) and switch [ts, te] -> [ts, te)
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
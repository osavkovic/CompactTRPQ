-- k = 5
DROP VIEW IF EXISTS edge, node;
CREATE view edge AS SELECT id, src, dst, label, prop1, ts*5 AS ts, ts*5+(te-ts+1)*5-1 AS te FROM edge_big;
CREATE view node AS SELECT id, type, prop1, prop2, prop3, prop4, ts*5 AS ts, ts*5+(te-ts+1)*5-1 AS te FROM node_big;
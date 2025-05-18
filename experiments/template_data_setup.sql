DROP VIEW IF EXISTS edge, node;
CREATE view edge AS SELECT id, src, dst, label, prop1, ts*??? AS ts, ts*???+(te-ts+1)*???-1 AS te FROM edge_big;
CREATE view node AS SELECT id, type, prop1, prop2, prop3, prop4, ts*??? AS ts, ts*???+(te-ts+1)*???-1 AS te FROM node_big;
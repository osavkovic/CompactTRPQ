# Compact Answers to Temporal Regular Path Queries

This folder contains the supplementary material for our ICDT 2024 paper submission. 

In particular, it contains SQL queries used in the experiments and instructions on how to run the queries.


# Code for the experiments in the paper

## Data and required tables

The code assumes two tables ```node_big``` and ```edge_big``` as input (see create table statements below; for the data see https://github.com/amirpouya/tpath/tree/main/data/contact) and a table ```exp_sizes``` where the results of the experiments are store (see create table statement below).

```sql
CREATE TABLE node_big (id INT, type VARCHAR, prop1 VARCHAR, prop2 VARCHAR, prop3 VARCHAR, prop4 VARCHAR, ts INT, te INT);
CREATE TABLE edge_big (id INT, src INT, dst INT, label VARCHAR, prop1 VARCHAR, ts INT, te INT);
CREATE TABLE exp_sizes (t TIMESTAMP, query VARCHAR, points bigInt, v1 bigInt, v1_coalesced bigInt, v2 bigInt, v2_coalesced bigInt, k INT, x INT);
```

The bash script ```run.sh``` is the main entry point and can be used to run the experiments, with different durations x and domain scaling factors k

The result is a ```out.txt``` file for logging purposes and the output size of the queries is stored in table ```exp_sizes```, where ```points``` is the result size for using time points, ```v1``` and ```v1_coalesced``` is the result size of U^{[t]} before and after coalescing respectively, and ```v2``` and ```v2_coalesced``` is the result size of U^{[d]} before and after coalescing respectively.


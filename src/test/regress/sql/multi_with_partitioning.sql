SET citus.shard_replication_factor TO 1;

CREATE TABLE local_users_2 (user_id int, event_type int);
INSERT INTO local_users_2 VALUES (0, 0), (1, 4), (1, 7), (2, 1), (3, 3), (5, 4), (6, 2), (10, 7);

CREATE TABLE partitioning_test(id int, time date) PARTITION BY RANGE (time);
 
-- create its partitions
CREATE TABLE partitioning_test_2017 PARTITION OF partitioning_test FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE partitioning_test_2010 PARTITION OF partitioning_test FOR VALUES FROM ('2010-01-01') TO ('2011-01-01');

-- load some data and distribute tables
INSERT INTO partitioning_test VALUES (1, '2017-11-23');
INSERT INTO partitioning_test VALUES (2, '2010-07-07');

INSERT INTO partitioning_test_2017 VALUES (3, '2017-11-22');
INSERT INTO partitioning_test_2010 VALUES (4, '2010-03-03');

-- distribute partitioned table
SELECT create_distributed_table('partitioning_test', 'id');


-- Join of a CTE on distributed table and then join with a partitioned table
WITH cte AS (
	SELECT * FROM users_table
)
SELECT DISTINCT ON (id) id, cte.time FROM cte join partitioning_test on cte.time::date=partitioning_test.time ORDER BY 1, 2 LIMIT 3;


-- Join of a CTE on distributed table and then join with a partitioned table hitting on only one partition
WITH cte AS (
	SELECT * FROM users_table
)
SELECT DISTINCT ON (id) id, cte.time FROM cte join partitioning_test on cte.time::date=partitioning_test.time WHERE partitioning_test.time >'2017-11-20' ORDER BY 1, 2 LIMIT 3;


-- Join with a distributed table and then join of two CTEs
WITH cte AS (
	SELECT id, time FROM partitioning_test
),
cte_2 AS (
	SELECT * FROM partitioning_test WHERE id > 2
),
cte_joined AS (
	SELECT user_id, cte_2.time FROM users_table join cte_2 on (users_table.time::date = cte_2.time)
),
cte_joined_2 AS (
	SELECT user_id, cte_joined.time FROM cte_joined join cte on (cte_joined.time = cte.time)
)
SELECT DISTINCT ON (event_type) event_type, cte_joined_2.user_id FROM events_table join cte_joined_2 on (cte_joined_2.time=events_table.time::date) ORDER BY 1, 2 LIMIT 10 OFFSET 2;


-- Join a partitioned table with a local table (both in CTEs)
-- and then with a distributed table. After all join with a 
-- partitioned table again
WITH cte AS (
	SELECT id, time FROM partitioning_test
),
cte_2 AS (
	SELECT * FROM local_users_2
),
cte_joined AS (
	SELECT user_id, cte.time FROM cte join cte_2 on (cte.id = cte_2.user_id)
),
cte_joined_2 AS (
	SELECT users_table.user_id, cte_joined.time FROM cte_joined join users_table on (cte_joined.time = users_table.time::date)
)
SELECT DISTINCT ON (id) id, cte_joined_2.time FROM cte_joined_2 join partitioning_test on (cte_joined_2.time=partitioning_test.time) ORDER BY 1, 2;

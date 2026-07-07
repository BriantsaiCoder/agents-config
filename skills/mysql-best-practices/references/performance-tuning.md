# Performance Tuning

Reference for rules 5, 6 in SKILL.md. Read this when optimizing slow queries, planning bulk operations, or tuning MySQL server settings.

## Table of contents
- [Slow query log](#slow-query-log)
- [Index optimization](#index-optimization)
- [Covering indexes](#covering-indexes)
- [Query cache (deprecated)](#query-cache)
- [Bulk insert strategies](#bulk-insert-strategies)
- [Optimizer hints (8.0+)](#optimizer-hints)
- [InnoDB buffer pool monitoring](#innodb-buffer-pool-monitoring)
- [Connection pool sizing](#connection-pool-sizing)

---

## Slow query log

The slow query log is the single most valuable tool for identifying performance problems in production.

### Configuration

```ini
# my.cnf / mysqld.cnf
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1          # Log queries taking > 1 second (default 10; too high for most apps)
log_queries_not_using_indexes = ON   # Also log queries that do full table scans
log_slow_extra = ON          # 5.7.2+: adds Rows_examined, Rows_sent, bytes sent to log entries
min_examined_row_limit = 100 # Only log if >100 rows examined (reduces noise)
```

### Dynamic enable (no restart)

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;  -- 500ms threshold
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

### Analyzing with pt-query-digest

```bash
# Install percona-toolkit, then:
pt-query-digest /var/log/mysql/slow.log > slow_report.txt

# Top queries by total time:
pt-query-digest --order-by Query_time:sum /var/log/mysql/slow.log

# Filter to a specific time range:
pt-query-digest --since '2024-01-15 00:00:00' --until '2024-01-16 00:00:00' /var/log/mysql/slow.log
```

pt-query-digest groups similar queries (normalizes parameters), ranks them by total time, and shows execution statistics (count, min/max/avg time, rows examined). Focus on the top 5-10 queries by total time, not just the slowest individual execution.

---

## Index optimization

### Redundant index detection

Redundant indexes waste disk space, slow down writes, and confuse the optimizer.

```sql
-- Find redundant indexes using sys schema (8.0) or information_schema
-- 8.0 sys schema:
SELECT * FROM sys.schema_redundant_indexes WHERE table_schema = 'myapp';

-- Manual check with SHOW INDEX:
SHOW INDEX FROM orders;
-- If you have INDEX(a, b) and INDEX(a), the second is redundant (leftmost prefix rule).
```

**Percona toolkit:**
```bash
pt-duplicate-key-checker --databases=myapp h=localhost,u=root
```

### Composite index vs multiple single-column indexes

MySQL can use **index merge** (combining multiple single-column indexes), but it is generally less efficient than a proper composite index:

```sql
-- Query: WHERE status = 'active' AND region = 'US'

-- Suboptimal: two single-column indexes, MySQL may index-merge
CREATE INDEX idx_status ON users (status);
CREATE INDEX idx_region ON users (region);

-- Optimal: one composite index
CREATE INDEX idx_status_region ON users (status, region);
-- Drop the redundant single-column indexes after adding the composite.
```

### Index merge behavior

The optimizer can combine multiple indexes using intersection (AND) or union (OR):
```sql
-- EXPLAIN may show: Using intersect(idx_status, idx_region)
-- This is a sign that a composite index would be better.
```

Control via optimizer switch (rarely needed):
```sql
SET optimizer_switch = 'index_merge=off';  -- Force the optimizer to pick one index
```

### Index cardinality and selectivity

- **High selectivity** = many distinct values / total rows (e.g., email: ~1.0). Put these columns first in composite indexes.
- **Low selectivity** = few distinct values (e.g., status with 3 values: ~0.003). These benefit less from indexing alone but work well as the first column when combined with high-selectivity columns.

```sql
-- Check cardinality:
SELECT
    INDEX_NAME, COLUMN_NAME, CARDINALITY,
    (SELECT TABLE_ROWS FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = t.TABLE_SCHEMA AND TABLE_NAME = t.TABLE_NAME) AS table_rows
FROM information_schema.STATISTICS t
WHERE TABLE_SCHEMA = 'myapp' AND TABLE_NAME = 'orders'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;
```

---

## Covering indexes

A covering index includes all columns referenced in the query (WHERE, ORDER BY, GROUP BY, and SELECT). When MySQL can satisfy the query entirely from the index, it avoids the expensive random I/O to the clustered index (primary key).

### How to identify covering index opportunities

EXPLAIN shows `Using index` in the Extra column when a covering index is used.

```sql
-- Query:
SELECT status, COUNT(*) FROM orders WHERE tenant_id = 42 GROUP BY status;

-- Without covering index: index lookup on tenant_id, then fetch status from clustered index
CREATE INDEX idx_tenant ON orders (tenant_id);
-- EXPLAIN Extra: Using where

-- With covering index: all needed columns in the index
CREATE INDEX idx_tenant_status ON orders (tenant_id, status);
-- EXPLAIN Extra: Using where; Using index
```

### InnoDB secondary index structure

Every InnoDB secondary index implicitly includes the primary key columns. So if your PK is `id`, an index on `(tenant_id, status)` effectively contains `(tenant_id, status, id)`. This means `SELECT id, tenant_id, status` is automatically covered.

### When covering indexes are worth it

- High-frequency queries where the covering index eliminates random I/O.
- Queries returning few columns from wide tables.
- **Not worth it** when the index becomes very wide (many columns), as it increases write overhead and memory usage.

---

## Query cache

### MySQL 5.7

The query cache existed but was often harmful:
- Any write to a table invalidated all cached queries for that table.
- High concurrency caused mutex contention on the query cache lock.
- Default: `query_cache_type = OFF` in many distributions.

**Recommendation:** Leave it disabled. If you need caching, use application-level caching (Redis, Memcached).

### MySQL 8.0

The query cache was **completely removed** in MySQL 8.0. The `query_cache_size` and `query_cache_type` variables no longer exist.

Do not attempt to configure it. Use application-level caching.

---

## Bulk insert strategies

### Multi-row INSERT VALUES (simplest, good performance)

Batch 500-1000 rows per statement. More rows per statement reduces round trips but must stay within `max_allowed_packet`.

**C# with Dapper:**
```csharp
// Build multi-row INSERT with parameterized values
var sql = new StringBuilder("INSERT INTO sensors (sensor_id, reading, recorded_at) VALUES ");
var parameters = new DynamicParameters();
for (int i = 0; i < batch.Count; i++)
{
    if (i > 0) sql.Append(", ");
    sql.Append($"(@SensorId{i}, @Reading{i}, @RecordedAt{i})");
    parameters.Add($"@SensorId{i}", batch[i].SensorId);
    parameters.Add($"@Reading{i}", batch[i].Reading);
    parameters.Add($"@RecordedAt{i}", batch[i].RecordedAt);
}
await conn.ExecuteAsync(sql.ToString(), parameters);
```

**Node.js with mysql2:**
```javascript
const values = rows.map(r => [r.sensorId, r.reading, r.recordedAt]);
const [result] = await pool.query(
  'INSERT INTO sensors (sensor_id, reading, recorded_at) VALUES ?',
  [values]
);
```

### LOAD DATA INFILE (fastest)

10-20x faster than INSERT statements for large datasets. Reads from a file on the server or client.

```sql
LOAD DATA LOCAL INFILE '/tmp/sensors.csv'
INTO TABLE sensors
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(sensor_id, reading, @recorded_at)
SET recorded_at = STR_TO_DATE(@recorded_at, '%Y-%m-%d %H:%i:%s');
```

**Requirements:**
- `local_infile = ON` on both server and client.
- `secure_file_priv` controls allowed directories for server-side LOAD DATA.
- The FILE privilege is required for server-side files (not LOCAL).
- MySqlConnector: set `AllowLoadLocalInfile=true` in connection string.
- mysql2 Node.js: not directly supported; use server-side LOAD DATA or shell out.

### MySqlConnector MySqlBulkCopy

```csharp
await using var conn = _db.Create();
await conn.OpenAsync(ct);

var bulkCopy = new MySqlBulkCopy(conn)
{
    DestinationTableName = "sensors",
    BulkCopyTimeout = 60,
};

// Map columns (0-based ordinal to column name)
bulkCopy.ColumnMappings.Add(new MySqlBulkCopyColumnMapping(0, "sensor_id"));
bulkCopy.ColumnMappings.Add(new MySqlBulkCopyColumnMapping(1, "reading"));
bulkCopy.ColumnMappings.Add(new MySqlBulkCopyColumnMapping(2, "recorded_at"));

// Convert to DataTable or use MySqlBulkCopyColumnMapping
var dataTable = new DataTable();
dataTable.Columns.Add("sensor_id", typeof(int));
dataTable.Columns.Add("reading", typeof(decimal));
dataTable.Columns.Add("recorded_at", typeof(DateTime));

foreach (var row in sensorReadings)
    dataTable.Rows.Add(row.SensorId, row.Reading, row.RecordedAt);

var result = await bulkCopy.WriteToServerAsync(dataTable, ct);
// result.RowsInserted contains the count
```

MySqlBulkCopy uses the MySQL binary protocol for fast bulk inserts without generating SQL text. It is the .NET equivalent of LOAD DATA INFILE.

### mysql2 batch insert pattern

```javascript
// For large batches, chunk into groups of 1000
const BATCH_SIZE = 1000;
for (let i = 0; i < rows.length; i += BATCH_SIZE) {
  const batch = rows.slice(i, i + BATCH_SIZE);
  const values = batch.map(r => [r.sensorId, r.reading, r.recordedAt]);
  await pool.query(
    'INSERT INTO sensors (sensor_id, reading, recorded_at) VALUES ?',
    [values]
  );
}
```

### INSERT ON DUPLICATE KEY UPDATE for upserts

See the [query-writing.md#insert-on-duplicate-key-update](query-writing.md#insert-on-duplicate-key-update) section for syntax and gotchas.

### Performance comparison (approximate)

| Method | Rows/sec (typical) | Notes |
|---|---|---|
| Individual INSERT in a loop | 500-2,000 | Never do this for bulk data |
| Multi-row INSERT (1000 per batch) | 20,000-50,000 | Good default choice |
| MySqlBulkCopy / LOAD DATA | 100,000-500,000+ | Best for large imports |
| Disable indexes, bulk load, re-enable | Even faster | Only for initial loads on empty tables |

### Tips for maximum bulk insert speed

1. **Disable autocommit:** Wrap batches in explicit transactions (1000-5000 rows per transaction).
2. **Disable unique checks temporarily** (only if you guarantee no duplicates):
   ```sql
   SET unique_checks = 0;
   -- ... bulk insert ...
   SET unique_checks = 1;
   ```
3. **Disable foreign key checks** (only if you guarantee referential integrity):
   ```sql
   SET foreign_key_checks = 0;
   -- ... bulk insert ...
   SET foreign_key_checks = 1;
   ```
4. **Increase `bulk_insert_buffer_size`** for MyISAM (not relevant for InnoDB).
5. **Ensure `max_allowed_packet`** is large enough for your batch statements (default 64MB in 8.0; increase if needed).
6. **Use `innodb_autoinc_lock_mode = 2`** (interleaved) for maximum concurrent insert performance. This is the default in 8.0.

---

## Optimizer hints

MySQL 8.0 introduced optimizer hints that are embedded in SQL comments and influence query execution without changing the query structure.

### Common hints

```sql
-- Force a specific index
SELECT /*+ INDEX(orders idx_customer_created) */ *
FROM orders WHERE customer_id = 42 ORDER BY created_at;

-- Prevent use of an index
SELECT /*+ NO_INDEX(orders idx_status) */ *
FROM orders WHERE status = 'pending';

-- Control join order
SELECT /*+ JOIN_ORDER(customers, orders) */ c.name, o.total
FROM customers c INNER JOIN orders o ON o.customer_id = c.id;

-- Set a variable for this query only
SELECT /*+ SET_VAR(sort_buffer_size = 16777216) */ *
FROM large_table ORDER BY unindexed_column LIMIT 100;

-- Limit execution time (milliseconds)
SELECT /*+ MAX_EXECUTION_TIME(5000) */ * FROM slow_view;

-- Control join algorithm (8.0.18+)
SELECT /*+ HASH_JOIN(t1, t2) */ * FROM t1 JOIN t2 ON t1.id = t2.t1_id;
SELECT /*+ NO_HASH_JOIN(t1, t2) */ * FROM t1 JOIN t2 ON t1.id = t2.t1_id;
```

### Hint vs FORCE INDEX

Optimizer hints are preferred over `FORCE INDEX` / `USE INDEX`:
- Hints are forward-compatible: if the hint is invalid, MySQL ignores it (no error).
- `FORCE INDEX` causes an error if the index is dropped.
- Hints can control more than just index selection (join order, variables, timeouts).

---

## InnoDB buffer pool monitoring

The buffer pool is InnoDB's in-memory cache for data and index pages. Its hit ratio is the single most important metric for InnoDB performance.

### Key metrics

```sql
-- Buffer pool hit ratio (should be > 99% for OLTP)
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';  -- Logical reads (from pool)
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';           -- Physical reads (from disk)
-- Hit ratio = 1 - (reads / read_requests) * 100

-- Convenience query:
SELECT
    (1 - (
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
        /
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')
    )) * 100 AS buffer_pool_hit_ratio_pct;
```

### SHOW ENGINE INNODB STATUS

```sql
SHOW ENGINE INNODB STATUS\G
```

Key sections:
- **BUFFER POOL AND MEMORY:** Pages total, free, dirty. If free pages is consistently 0, increase `innodb_buffer_pool_size`.
- **LOG:** Pending log writes, checkpoint info.
- **ROW OPERATIONS:** Reads, inserts, updates, deletes per second.
- **SEMAPHORES:** Mutex waits; high numbers indicate contention.
- **LATEST DETECTED DEADLOCK:** Shows the two transactions, their locks, and which was rolled back.

### Tuning buffer pool size

```ini
# my.cnf - dedicated database server
innodb_buffer_pool_size = 12G  # 70-80% of total RAM for a dedicated DB server
innodb_buffer_pool_instances = 8  # Multiple instances reduce contention; use 8 for > 1GB pool
innodb_buffer_pool_dump_at_shutdown = ON   # Save buffer pool state on shutdown
innodb_buffer_pool_load_at_startup = ON    # Restore on startup (warm cache faster)
```

### Performance Schema queries (8.0)

```sql
-- Top tables by buffer pool usage
SELECT
    OBJECT_SCHEMA, OBJECT_NAME,
    ALLOCATED AS pages_allocated,
    DATA AS data_pages,
    DIRTY AS dirty_pages
FROM sys.innodb_buffer_stats_by_table
ORDER BY ALLOCATED DESC
LIMIT 20;

-- Tables with most I/O waits
SELECT * FROM sys.schema_table_statistics_with_buffer
WHERE table_schema = 'myapp'
ORDER BY io_read_latency DESC
LIMIT 10;
```

---

## Connection pool sizing

### The formula

A widely-used guideline from the PostgreSQL community (applicable to MySQL):

```
pool_size = (core_count * 2) + effective_spindle_count
```

- **core_count:** Physical CPU cores available to the database server.
- **effective_spindle_count:** Number of independent disk spindles. For SSD, use 1. For RAID arrays, use the number of drives.

Example: 4-core server with SSD = (4 * 2) + 1 = 9 connections.

### Why fewer connections is better

- Each MySQL connection consumes ~1-10 MB of memory (depending on buffers).
- Too many connections cause context switching, lock contention, and memory pressure.
- MySQL's `max_connections` default is 151. With 10 application instances each running 50 connections, you need 500 connections -- far too many.
- Monitor `Threads_connected` (current) vs `Threads_running` (actively executing). If `Threads_running` is consistently low while `Threads_connected` is high, your pool is oversized.

### Sizing guidelines

| Workload | Pool size per app instance | Notes |
|---|---|---|
| Low-traffic API | 5-10 | |
| Medium-traffic API | 10-20 | |
| High-traffic API | 20-50 | Scale app instances, not pool size |
| Background worker | 2-5 | Workers usually have sequential access patterns |

### Monitoring connection usage

```sql
-- Current connections
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Threads_running';
SHOW GLOBAL STATUS LIKE 'Max_used_connections';

-- Connection errors (pool exhaustion signal)
SHOW GLOBAL STATUS LIKE 'Connection_errors%';
SHOW GLOBAL STATUS LIKE 'Aborted_connects';
```

**Application-side monitoring (C#):**
MySqlConnector does not expose pool statistics directly. Monitor connection wait times via APM tools (OpenTelemetry, Application Insights) or by timing `conn.OpenAsync()`.

**Application-side monitoring (Node.js):**
```javascript
// mysql2 pool events
pool.on('connection', (conn) => console.log('New connection created'));
pool.on('acquire', (conn) => console.log('Connection acquired from pool'));
pool.on('release', (conn) => console.log('Connection released to pool'));
pool.on('enqueue', () => console.log('Waiting for available connection'));
```

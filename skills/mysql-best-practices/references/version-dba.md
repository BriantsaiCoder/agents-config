# Version Differences & DBA Essentials

Reference for rule 10 in SKILL.md. Read this when you need to check feature availability by version, tune server settings, or set up monitoring.

## Table of contents
- [5.7 vs 8.0 feature matrix](#57-vs-80-feature-matrix)
- [MySQL 5.7 end of life](#mysql-57-end-of-life)
- [my.cnf key settings](#mycnf-key-settings)
- [Monitoring essentials](#monitoring-essentials)
- [Replication overview](#replication-overview)

---

## 5.7 vs 8.0 feature matrix

| Feature | 5.7 | 8.0 | Notes |
|---|---|---|---|
| **Common Table Expressions (CTEs)** | No | Yes (8.0.1) | Recursive CTEs supported |
| **Window functions** | No | Yes (8.0.2) | ROW_NUMBER, RANK, LAG, LEAD, etc. |
| **JSON_TABLE** | No | Yes (8.0.4) | Convert JSON to relational rows |
| **LATERAL derived tables** | No | Yes (8.0.14) | Correlated subqueries in FROM |
| **Roles** | No | Yes (8.0.0) | `CREATE ROLE`, `GRANT role TO user` |
| **Invisible indexes** | No | Yes (8.0.0) | `ALTER TABLE t ALTER INDEX idx INVISIBLE` |
| **Descending indexes** | No | Yes (8.0.0) | `CREATE INDEX idx ON t (col DESC)` |
| **Histogram statistics** | No | Yes (8.0.0) | `ANALYZE TABLE t UPDATE HISTOGRAM ON col` |
| **CHECK constraints (enforced)** | Parsed, ignored | Enforced (8.0.16) | Pre-8.0.16: CHECK is silently dropped |
| **DEFAULT expressions** | Literals only | Expressions OK (8.0.13) | `DEFAULT (UUID())`, `DEFAULT (NOW())` |
| **Atomic DDL** | No | Yes (8.0.0) | DDL operations are crash-safe |
| **Instant ADD COLUMN** | No | Yes (8.0.12) | `ALGORITHM=INSTANT` for adding columns at the end |
| **Hash join** | No | Yes (8.0.18) | Equi-joins without index; replaces BNL |
| **EXPLAIN ANALYZE** | No | Yes (8.0.18) | Actual execution metrics |
| **Functional indexes** | No | Yes (8.0.13) | `CREATE INDEX idx ON t ((LOWER(col)))` |
| **Multi-valued indexes** | No | Yes (8.0.17) | Index JSON arrays: `CAST(j->'$.tags' AS UNSIGNED ARRAY)` |
| **caching_sha2_password** | Available | **Default** auth plugin | Requires SSL or RSA key exchange |
| **mysql_native_password** | Default | Available (deprecated 8.0.34) | Being phased out |
| **Query cache** | Available (disabled default) | **Removed** | Use application-level caching |
| **utf8mb4_0900_ai_ci** | Not available | Default collation | UCA 9.0, faster than unicode_ci |
| **Undo tablespace management** | Limited | Automatic (8.0.14) | Auto-truncation of undo logs |
| **Resource groups** | No | Yes (8.0.0) | CPU affinity for threads |
| **Data dictionary** | File-based (.frm) | Transactional (InnoDB) | Crash-safe metadata; no .frm files |
| **Clone plugin** | No | Yes (8.0.17) | Full instance clone for replica provisioning |
| **Group Replication** | Plugin (5.7.17) | Built-in, improved | Multi-primary and single-primary modes |

---

## MySQL 5.7 end of life

- **Premier Support ended:** October 2023.
- **Extended Support ended:** October 2023 (Oracle changed the support policy).
- **Security patches:** No longer provided. Running 5.7 in production is a security risk.

**Migration path:** Upgrade to MySQL 8.0 (or 8.4 LTS). Key breaking changes to watch:
1. Default authentication changed to `caching_sha2_password`. Update connection strings or create users with `mysql_native_password` temporarily.
2. `utf8mb4` is the default charset; `utf8mb4_0900_ai_ci` is the default collation.
3. Reserved words added: `RANK`, `ROW_NUMBER`, `GROUPS`, `LATERAL`, etc. Escape with backticks if used as column/table names.
4. `GROUP BY` no longer implicitly sorts. Add explicit `ORDER BY` if you relied on sorted GROUP BY results.
5. Query cache removed. Remove `query_cache_*` settings from my.cnf.

---

## my.cnf key settings

### InnoDB core settings

```ini
[mysqld]
# Buffer pool: 70-80% of RAM on a dedicated DB server
innodb_buffer_pool_size = 12G

# Multiple pool instances reduce mutex contention (use 8 for pools > 1GB)
innodb_buffer_pool_instances = 8

# Redo log file size: larger = better write throughput, slower crash recovery
# 5.7: innodb_log_file_size = 1G (applies to each of innodb_log_files_in_group files)
# 8.0.30+: innodb_redo_log_capacity = 4G (replaces log_file_size and log_files_in_group)
innodb_log_file_size = 1G

# Flush behavior:
# 1 = Full ACID (flush log to disk on every commit) — safest, required for production
# 2 = Flush to OS cache on commit, sync to disk once per second — up to 1 second of data loss on crash
# 0 = Write to log buffer, flush once per second — up to 1 second of data loss on MySQL crash
innodb_flush_log_at_trx_commit = 1

# One file per table (default ON since 5.6.6)
innodb_file_per_table = ON

# I/O capacity: set based on disk throughput
# HDD: 200-400, SSD: 2000-10000, NVMe: 10000-40000
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000

# Thread concurrency: 0 = let InnoDB decide (recommended for most workloads)
innodb_thread_concurrency = 0

# Print all deadlocks to error log (8.0; useful for debugging)
innodb_print_all_deadlocks = ON

# Lock wait timeout: seconds before a lock wait times out (default 50; too long for OLTP)
innodb_lock_wait_timeout = 10
```

### Connection and thread settings

```ini
# Maximum connections: size based on workload, not "as many as possible"
# Formula: app_instances * pool_size_per_instance + admin_overhead
max_connections = 200

# Thread cache: reuse threads instead of creating new ones per connection
thread_cache_size = 16

# Wait timeout: seconds before idle connections are closed
wait_timeout = 600
interactive_timeout = 600

# Max packet size: must accommodate your largest single query/result
max_allowed_packet = 64M
```

### Replication and binary log

```ini
# Binary log format: ROW is safest for replication
binlog_format = ROW

# Row image: FULL for safety, MINIMAL for bandwidth (if you understand the trade-offs)
binlog_row_image = FULL

# GTID: enables automatic failover and simpler replication management
gtid_mode = ON
enforce_gtid_consistency = ON

# Expire binary logs:
# 5.7: expire_logs_days = 7
# 8.0: binlog_expire_logs_seconds = 604800  (7 days in seconds)
binlog_expire_logs_seconds = 604800

# Sync binary log to disk on every commit (required for crash-safe replication)
sync_binlog = 1
```

### Character set

```ini
# Server-wide defaults
character_set_server = utf8mb4
# 8.0:
collation_server = utf8mb4_0900_ai_ci
# 5.7:
# collation_server = utf8mb4_unicode_ci
```

### Temporary tables and sort buffers

```ini
# In-memory temp table size (for GROUP BY, DISTINCT, etc.)
tmp_table_size = 64M
max_heap_table_size = 64M

# Sort buffer per connection (not global pool)
sort_buffer_size = 4M

# Join buffer per join per connection
join_buffer_size = 4M

# Read buffer for sequential scans
read_buffer_size = 1M
```

---

## Monitoring essentials

### SHOW GLOBAL STATUS (key variables)

```sql
-- Connections
SHOW GLOBAL STATUS LIKE 'Threads_connected';     -- Current connections
SHOW GLOBAL STATUS LIKE 'Threads_running';        -- Actively executing (should be low)
SHOW GLOBAL STATUS LIKE 'Max_used_connections';   -- Peak since startup
SHOW GLOBAL STATUS LIKE 'Aborted_connects';       -- Failed connection attempts

-- Query throughput
SHOW GLOBAL STATUS LIKE 'Questions';              -- Total queries since startup
SHOW GLOBAL STATUS LIKE 'Com_select';             -- SELECT count
SHOW GLOBAL STATUS LIKE 'Com_insert';             -- INSERT count
SHOW GLOBAL STATUS LIKE 'Com_update';             -- UPDATE count
SHOW GLOBAL STATUS LIKE 'Com_delete';             -- DELETE count

-- InnoDB
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';  -- Logical reads
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';          -- Disk reads (should be << requests)
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_waits';             -- Row lock contention
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_time_avg';          -- Avg lock wait (ms)
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';                  -- Total deadlocks since startup

-- Temporary tables
SHOW GLOBAL STATUS LIKE 'Created_tmp_disk_tables';  -- Temp tables on disk (should be low)
SHOW GLOBAL STATUS LIKE 'Created_tmp_tables';       -- Total temp tables
```

### SHOW ENGINE INNODB STATUS

Run `SHOW ENGINE INNODB STATUS\G` and check:
1. **SEMAPHORES:** High OS waits indicate contention.
2. **LATEST DETECTED DEADLOCK:** Full details of the last deadlock.
3. **TRANSACTIONS:** Long-running transactions with large undo log entries.
4. **BUFFER POOL AND MEMORY:** Free pages, dirty pages, hit ratio.
5. **LOG:** Pending log writes and checkpoint lag.

### Performance Schema (8.0)

```sql
-- Top 10 queries by total latency
SELECT
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    ROUND(SUM_TIMER_WAIT / 1e12, 2) AS total_latency_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 4) AS avg_latency_sec,
    SUM_ROWS_EXAMINED,
    SUM_ROWS_SENT
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Tables with most I/O
SELECT * FROM sys.schema_table_statistics
WHERE table_schema = 'myapp'
ORDER BY io_read_latency DESC
LIMIT 10;

-- Unused indexes (candidates for removal)
SELECT * FROM sys.schema_unused_indexes
WHERE object_schema = 'myapp';
```

### sys schema views (8.0)

The sys schema provides human-readable views on top of Performance Schema:

| View | Purpose |
|---|---|
| `sys.schema_unused_indexes` | Indexes never used since last restart |
| `sys.schema_redundant_indexes` | Duplicate/redundant indexes |
| `sys.schema_table_statistics` | Table I/O and lock statistics |
| `sys.statements_with_full_table_scans` | Queries doing full scans |
| `sys.statements_with_temp_tables` | Queries creating temp tables |
| `sys.innodb_buffer_stats_by_table` | Buffer pool usage per table |
| `sys.user_summary` | Per-user connection and query stats |
| `sys.host_summary` | Per-host connection stats |

---

## Replication overview

### Asynchronous replication (default)

The source writes to binary log, the replica reads and applies. There is a lag between source commit and replica apply.

- **Pros:** Simple, low overhead on source.
- **Cons:** Data loss if source crashes before replica catches up.
- **Use case:** Read replicas for scaling reads.

### Semi-synchronous replication

The source waits for at least one replica to acknowledge receipt of the binary log event before committing.

```sql
-- On source:
INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';
SET GLOBAL rpl_semi_sync_master_enabled = 1;
SET GLOBAL rpl_semi_sync_master_timeout = 5000;  -- ms; fall back to async if replica is slow

-- On replica:
INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
```

- **Pros:** Zero data loss (at least one replica has the data).
- **Cons:** Higher commit latency; degrades to async if replica is unreachable.

### GTID-based replication

Global Transaction Identifiers (GTIDs) give each transaction a unique ID (`source_uuid:sequence_number`). This simplifies failover because replicas know exactly which transactions they have applied.

```ini
# my.cnf (both source and replica)
gtid_mode = ON
enforce_gtid_consistency = ON
```

**Advantages over file-position replication:**
- Automatic failover: replica can find its position on any source.
- Simpler replica provisioning with `CHANGE MASTER TO MASTER_AUTO_POSITION = 1`.
- Easy to verify consistency.

### Group Replication (8.0)

MySQL Group Replication provides built-in high availability with automatic failover:

- **Single-primary mode:** One read-write node, others are read-only. Automatic primary election on failure.
- **Multi-primary mode:** All nodes accept writes. Conflict detection and resolution via certification.
- Built on Paxos consensus protocol.
- Requires `gtid_mode = ON` and InnoDB only.

**Use Group Replication when:** You need automatic failover without external tools (like MHA or Orchestrator).

### InnoDB Cluster (8.0)

InnoDB Cluster bundles Group Replication + MySQL Shell + MySQL Router:
- **Group Replication:** Provides the replication and consensus layer.
- **MySQL Shell:** Administrative tool for cluster setup and management.
- **MySQL Router:** Application-transparent routing (reads to replicas, writes to primary).

This is MySQL's recommended high-availability solution for 8.0+.

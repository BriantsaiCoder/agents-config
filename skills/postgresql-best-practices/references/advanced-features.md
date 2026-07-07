# PostgreSQL Advanced Features

## Row-Level Security (RLS)

RLS allows you to define policies that control which rows a user can see or modify, enforced transparently by the database engine.

### Enabling RLS

```sql
-- Enable RLS on the table (no policies = deny all for non-owner roles)
ALTER TABLE tenant_data ENABLE ROW LEVEL SECURITY;

-- Force RLS even for the table owner (important for testing and safety)
ALTER TABLE tenant_data FORCE ROW LEVEL SECURITY;
```

### Creating Policies

```sql
-- USING clause: controls which rows are visible (SELECT, UPDATE, DELETE)
-- WITH CHECK clause: controls which rows can be written (INSERT, UPDATE)

-- Multi-tenant isolation using a session variable
CREATE POLICY tenant_isolation ON tenant_data
    USING (tenant_id = current_setting('app.tenant_id')::bigint)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::bigint);

-- Role-based access
CREATE POLICY admin_full_access ON tenant_data
    TO admin_role
    USING (true)
    WITH CHECK (true);

-- Read-only policy for a reporting role
CREATE POLICY reporting_read ON tenant_data
    FOR SELECT
    TO reporting_role
    USING (true);

-- Users can only update their own rows
CREATE POLICY own_rows_only ON user_profiles
    FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());
```

### Setting Session Variables for RLS

In your application, set the tenant context at the start of each request:

```csharp
// C# / Npgsql
await using var conn = new NpgsqlConnection(connectionString);
await conn.OpenAsync(ct);
await conn.ExecuteAsync("SET app.tenant_id = @TenantId", new { TenantId = tenantId });

// All subsequent queries on this connection are now filtered by tenant_id
var data = await conn.QueryAsync<TenantData>("SELECT * FROM tenant_data");
```

```javascript
// Node.js / pg
const client = await pool.connect();
try {
  await client.query('SET app.tenant_id = $1', [tenantId]);
  const { rows } = await client.query('SELECT * FROM tenant_data');
  // rows are automatically filtered by RLS policy
} finally {
  // IMPORTANT: reset the setting before releasing back to pool
  await client.query('RESET app.tenant_id');
  client.release();
}
```

### Testing RLS

```sql
-- Test as a specific role
SET ROLE app_user;
SET app.tenant_id = '42';

SELECT * FROM tenant_data;  -- should only show tenant 42's data
INSERT INTO tenant_data (tenant_id, value) VALUES (99, 'hack');  -- should fail

RESET ROLE;
RESET app.tenant_id;
```

### Performance Considerations

RLS policies are appended as additional `WHERE` conditions. If the policy references an indexed column (like `tenant_id`), the optimizer can use that index. Ensure `tenant_id` is part of your primary key or has an index.

```sql
-- Composite index that supports both RLS filtering and common queries
CREATE INDEX idx_tenant_data_tenant_created ON tenant_data (tenant_id, created_at);
```

## Materialized Views

A materialized view stores the result of a query physically, trading freshness for query speed.

### Creating and Refreshing

```sql
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    date_trunc('day', created_at) AS sale_date,
    product_id,
    count(*) AS order_count,
    sum(total) AS revenue
FROM orders
WHERE status = 'completed'
GROUP BY 1, 2;

-- Create a unique index (required for CONCURRENTLY refresh)
CREATE UNIQUE INDEX uq_mv_daily_sales ON mv_daily_sales (sale_date, product_id);

-- Regular refresh (exclusive lock, blocks reads)
REFRESH MATERIALIZED VIEW mv_daily_sales;

-- Concurrent refresh (no lock on reads, requires unique index)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
```

### When to Use

- **Expensive aggregations:** Dashboard queries that summarize millions of rows.
- **Search results:** Pre-computed search indexes with complex joins.
- **Reporting:** Denormalized views for BI tools.

### Index on Materialized Views

```sql
-- Index the materialized view for fast lookups
CREATE INDEX idx_mv_daily_sales_product ON mv_daily_sales (product_id);
CREATE INDEX idx_mv_daily_sales_date ON mv_daily_sales (sale_date);
```

### Refresh Strategies

| Strategy | Freshness | Complexity |
|----------|-----------|------------|
| **Cron job** (`pg_cron` or OS cron) | Minutes to hours | Low |
| **Application-triggered** (after batch operations) | Event-driven | Medium |
| **Trigger-based** (refresh on source table changes) | Near real-time | High (careful: avoid refresh storms) |

```sql
-- Example: pg_cron refresh every 15 minutes
SELECT cron.schedule('refresh_daily_sales', '*/15 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales');
```

## Extensions

### pg_trgm (Trigram Similarity)

Enables substring and fuzzy text search using trigram decomposition.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Similarity search
SELECT name, similarity(name, 'Johnn') AS sim
FROM users
WHERE similarity(name, 'Johnn') > 0.3
ORDER BY sim DESC;

-- word_similarity: best trigram match of query within the string
SELECT name, word_similarity('john', name) AS wsim
FROM users
WHERE 'john' <% name  -- word_similarity threshold
ORDER BY wsim DESC;

-- GIN index for LIKE '%substring%' (normally not indexable)
CREATE INDEX idx_users_name_trgm ON users USING gin (name gin_trgm_ops);

-- Now these queries use the index:
SELECT * FROM users WHERE name ILIKE '%john%';
SELECT * FROM users WHERE name % 'Johnn';  -- similarity threshold

-- Tune the similarity threshold
SET pg_trgm.similarity_threshold = 0.3;  -- default
```

### PostGIS

Spatial data types and functions for geographic queries.

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE locations (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    geom geometry(Point, 4326),      -- geometry: projected, faster math
    geog geography(Point, 4326)      -- geography: spherical, accurate distances
);

-- Spatial index
CREATE INDEX idx_locations_geom ON locations USING gist (geom);
CREATE INDEX idx_locations_geog ON locations USING gist (geog);

-- Find locations within 1km of a point
SELECT id, name, ST_Distance(geog, ST_MakePoint(-122.4194, 37.7749)::geography) AS distance_m
FROM locations
WHERE ST_DWithin(geog, ST_MakePoint(-122.4194, 37.7749)::geography, 1000)
ORDER BY distance_m;
```

**geometry vs geography:**
- `geometry`: Cartesian math, faster, good for local regions with a suitable projection.
- `geography`: Spherical math, accurate across the globe, slightly slower. Use for lat/lon data.

### uuid-ossp vs gen_random_uuid()

Since PostgreSQL 13, `gen_random_uuid()` is built-in (no extension needed) and generates UUIDv4. The `uuid-ossp` extension is only needed for UUIDv1 or UUIDv5, which are rarely required.

```sql
-- PG 13+: no extension needed
SELECT gen_random_uuid();

-- Only if you need UUIDv1 or UUIDv5
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT uuid_generate_v1();
```

### pg_stat_statements

Covered in detail in `performance-tuning.md`. Essential for identifying slow queries. Must be in `shared_preload_libraries` (requires restart).

### pgcrypto

Encryption and hashing functions:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Hash a password (use in stored procedures, not typically in application SQL)
SELECT crypt('user_password', gen_salt('bf', 12));

-- Verify a password
SELECT (password_hash = crypt('user_input', password_hash)) AS is_valid
FROM users WHERE id = 1;

-- Generate random bytes
SELECT gen_random_bytes(32);  -- 32 random bytes

-- Encrypt/decrypt with PGP symmetric encryption
SELECT pgp_sym_encrypt('sensitive data', 'encryption_key');
SELECT pgp_sym_decrypt(encrypted_col, 'encryption_key') FROM secrets;
```

**Note:** Prefer application-level encryption for sensitive data. Database-level encryption with pgcrypto means the database server has access to keys and plaintext.

## Table Inheritance vs Declarative Partitioning

| Feature | Table Inheritance | Declarative Partitioning |
|---------|------------------|------------------------|
| Purpose | Polymorphic schemas (rare) | Data lifecycle management |
| Query routing | Manual CHECK constraints | Automatic partition pruning |
| Unique constraints | Cannot span children | Can span all partitions (PG 11+) |
| Foreign keys | Cannot reference parent | Supported (PG 12+) |
| Maintenance | Manual, error-prone | `ATTACH`/`DETACH PARTITION` |

**Rule:** Use declarative partitioning for data management (time-series, multi-tenant). Avoid table inheritance for new designs.

## postgresql.conf Key Settings

### Memory

| Setting | Default | Recommended | Notes |
|---------|---------|-------------|-------|
| `shared_buffers` | 128 MB | 25% of RAM (max ~8 GB) | PostgreSQL's own page cache |
| `effective_cache_size` | 4 GB | 50-75% of RAM | Planner hint: total cache available (shared_buffers + OS cache) |
| `work_mem` | 4 MB | 4-16 MB | Per-operation (sort, hash). `connections * sorts_per_query * work_mem` = total usage |
| `maintenance_work_mem` | 64 MB | 256 MB - 1 GB | For VACUUM, CREATE INDEX. Higher = faster maintenance |
| `huge_pages` | try | try | Reduces TLB misses with large shared_buffers. Requires OS config |

### Planner / I/O

| Setting | Default | Recommended | Notes |
|---------|---------|-------------|-------|
| `random_page_cost` | 4.0 | 1.1 (SSD) / 4.0 (HDD) | Ratio of random I/O cost to sequential. SSD makes random ~same as sequential |
| `effective_io_concurrency` | 1 | 200 (SSD) | Number of concurrent I/O operations. Higher for NVMe/SSD |
| `seq_page_cost` | 1.0 | 1.0 | Baseline cost unit |

### Connections

| Setting | Default | Recommended | Notes |
|---------|---------|-------------|-------|
| `max_connections` | 100 | Keep low (100-200) | Each connection is an OS process (~10 MB). Use connection pooling |
| `superuser_reserved_connections` | 3 | 3-5 | Reserved for superuser maintenance access |

### WAL / Replication

| Setting | Default | Recommended | Notes |
|---------|---------|-------------|-------|
| `wal_level` | replica | `replica` (standby) or `logical` (logical replication) | `logical` for CDC/Debezium |
| `max_wal_senders` | 10 | 10 | Max concurrent streaming replication connections |
| `max_replication_slots` | 10 | 10 | Slots prevent WAL cleanup until consumer catches up |
| `checkpoint_completion_target` | 0.9 | 0.9 | Spread checkpoint writes over this fraction of the checkpoint interval |

### Applying Changes

```sql
-- Most settings can be changed with reload (no restart)
ALTER SYSTEM SET work_mem = '16MB';
SELECT pg_reload_conf();

-- Some require restart (shared_buffers, max_connections, shared_preload_libraries, wal_level)
ALTER SYSTEM SET shared_buffers = '4GB';
-- Then: pg_ctl restart or systemctl restart postgresql
```

## Monitoring Queries

### Active Queries and Locks

```sql
-- Currently running queries
SELECT
    pid,
    now() - query_start AS duration,
    state,
    wait_event_type,
    wait_event,
    left(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY duration DESC;

-- Lock contention
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid
JOIN pg_locks kl ON kl.locktype = bl.locktype
    AND kl.database IS NOT DISTINCT FROM bl.database
    AND kl.relation IS NOT DISTINCT FROM bl.relation
    AND kl.page IS NOT DISTINCT FROM bl.page
    AND kl.tuple IS NOT DISTINCT FROM bl.tuple
    AND kl.transactionid IS NOT DISTINCT FROM bl.transactionid
    AND kl.classid IS NOT DISTINCT FROM bl.classid
    AND kl.objid IS NOT DISTINCT FROM bl.objid
    AND kl.objsubid IS NOT DISTINCT FROM bl.objsubid
    AND kl.pid != bl.pid
JOIN pg_stat_activity blocking ON kl.pid = blocking.pid
WHERE NOT bl.granted;
```

### Table and Index Health

```sql
-- Table statistics: size, dead tuples, sequential vs index scan ratio
SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    seq_scan,
    idx_scan,
    round(100.0 * idx_scan / greatest(seq_scan + idx_scan, 1), 1) AS idx_scan_pct,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;

-- Unused indexes (candidates for removal)
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE idx_scan < 10  -- barely used
  AND indexrelname NOT LIKE 'uq_%'  -- keep unique constraints
  AND indexrelname NOT LIKE 'pk_%'  -- keep primary keys
ORDER BY pg_relation_size(indexrelid) DESC;
```

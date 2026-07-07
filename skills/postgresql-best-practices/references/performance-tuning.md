# PostgreSQL Performance Tuning

## EXPLAIN ANALYZE BUFFERS Reading Guide

Always run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` on complex queries before shipping them. This executes the query and shows actual vs estimated costs.

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, o.total, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.created_at > '2025-01-01'
  AND o.status = 'completed';
```

### Node Types

| Node | What It Does | When You See It |
|------|-------------|-----------------|
| **Seq Scan** | Reads every row in the table | No useful index, or query returns a large fraction of rows |
| **Index Scan** | Traverses B-tree, fetches heap rows | Selective query with a matching index |
| **Index Only Scan** | Reads from index alone, no heap access | All selected columns are in the index (covering index) |
| **Bitmap Index Scan** | Scans index, builds a bitmap of matching pages | Multiple index conditions OR'd, or moderate selectivity |
| **Bitmap Heap Scan** | Fetches heap pages from bitmap | Always paired with Bitmap Index Scan |
| **Hash Join** | Builds hash table from smaller side, probes with larger | Equality joins, larger datasets |
| **Merge Join** | Merges two sorted inputs | Both sides already sorted (by index or explicit Sort) |
| **Nested Loop** | For each outer row, scans inner | Small outer set, indexed inner; or no better strategy |
| **Sort** | In-memory or disk sort | ORDER BY, merge join input, DISTINCT |
| **Aggregate** | GROUP BY, COUNT, SUM, etc. | Aggregation queries |

### Key Metrics to Read

**actual time (startup..total):** Time in milliseconds. Startup is time before first row is produced. Total is time for all rows. Multiply by `loops` for true cost.

**actual rows vs planned rows (rows):** If `actual rows` is dramatically different from the estimate (e.g., estimated 1 row, actual 50,000), statistics are stale. Run `ANALYZE` on the table.

**Buffers:** 
- `shared hit` = pages found in PostgreSQL's buffer cache (fast).
- `shared read` = pages read from OS cache or disk (slower).
- High `shared read` relative to `shared hit` = cold cache or table too large for `shared_buffers`.

**loops:** The node was executed this many times (common in Nested Loop). Multiply `actual time` and `actual rows` by `loops` for true totals.

### Common Problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| Seq Scan on large table with selective WHERE | Missing index | Create appropriate index |
| Bitmap Heap Scan with many "Recheck Cond" rows | Index has low selectivity | More specific index, partial index, or accept Seq Scan |
| Nested Loop with high loop count | Large outer set | Check if Hash Join would be better; add index on inner table |
| Sort with "Sort Method: external merge Disk" | `work_mem` too low for the sort | Increase `work_mem` (carefully) or add an index for the ORDER BY |
| Estimated rows = 1, actual = 100,000 | Stale statistics | `ANALYZE tablename;` or tune `default_statistics_target` |

## Index Types Deep Dive

### B-tree (Default)

The workhorse index. Supports: `=`, `<`, `>`, `<=`, `>=`, `BETWEEN`, `IN`, `IS NULL`, `IS NOT NULL`, pattern matching with `LIKE 'prefix%'` (not `%suffix`), and `ORDER BY`.

```sql
CREATE INDEX idx_orders_created_at ON orders (created_at);
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status);  -- composite
CREATE UNIQUE INDEX uq_users_email ON users (email);
```

**Column order matters in composite indexes.** The index is useful for queries that filter on a leading prefix of the columns. `(customer_id, status)` helps `WHERE customer_id = 1` and `WHERE customer_id = 1 AND status = 'active'` but NOT `WHERE status = 'active'` alone.

### GIN (Generalized Inverted Index)

For multi-valued data: arrays, JSONB, full-text search (tsvector), trigram similarity.

```sql
-- Array containment
CREATE INDEX idx_products_tags ON products USING gin (tags);
-- Query: WHERE tags @> ARRAY['electronics']

-- JSONB
CREATE INDEX idx_events_payload ON events USING gin (payload);
-- Query: WHERE payload @> '{"type": "purchase"}'

-- JSONB with jsonb_path_ops (smaller, only supports @> containment)
CREATE INDEX idx_events_payload_path ON events USING gin (payload jsonb_path_ops);

-- Full-text search
CREATE INDEX idx_articles_search ON articles USING gin (search_vector);
-- Query: WHERE search_vector @@ to_tsquery('english', 'postgresql & tuning')

-- Trigram (requires pg_trgm extension)
CREATE INDEX idx_users_name_trgm ON users USING gin (name gin_trgm_ops);
-- Query: WHERE name ILIKE '%john%'   (substring search!)
```

**GIN trade-offs:** Slower to build and update than B-tree (especially bulk inserts). Faster for containment/membership queries on multi-valued columns. Use `gin_pending_list_limit` to tune write performance.

### GiST (Generalized Search Tree)

For spatial data, range types, nearest-neighbor search, and full-text (alternative to GIN).

```sql
-- Range type non-overlap (used with EXCLUDE constraints)
CREATE INDEX idx_reservations_during ON reservations USING gist (during);

-- PostGIS spatial index
CREATE INDEX idx_locations_geom ON locations USING gist (geom);
-- Query: WHERE ST_DWithin(geom, ST_MakePoint(-122.4, 37.7)::geography, 1000)

-- KNN (K-nearest neighbors) with ORDER BY <-> operator
SELECT id, name, geom <-> ST_MakePoint(-122.4, 37.7)::geometry AS distance
FROM locations
ORDER BY geom <-> ST_MakePoint(-122.4, 37.7)::geometry
LIMIT 10;

-- Full-text search (smaller than GIN but slower queries)
CREATE INDEX idx_articles_search_gist ON articles USING gist (search_vector);
```

### BRIN (Block Range Index)

Extremely compact index for large, naturally ordered tables (append-only data with correlated columns):

```sql
-- Time-series data: timestamps naturally correlate with physical row order
CREATE INDEX idx_logs_created_at ON logs USING brin (created_at);

-- Perfect for: log tables, IoT sensor data, event streams
-- Terrible for: randomly inserted data, frequently updated tables
```

**BRIN trade-offs:** Tiny index size (often <1% of table size). Works by storing min/max per block range. Only useful when the column values correlate with physical row order. Not for random access patterns.

### Hash Index

Supports only equality (`=`). No range, no sort, no UNIQUE. Rarely useful since B-tree handles equality efficiently and also supports range queries. WAL-logged and crash-safe since PG 10.

```sql
CREATE INDEX idx_sessions_token ON sessions USING hash (token);
-- Only faster than B-tree for very long keys where B-tree nodes become large
```

## Partial Indexes

Index only the rows that matter:

```sql
-- Only index active users (skip millions of inactive rows)
CREATE INDEX idx_users_email_active ON users (email) WHERE is_active = true;
-- Query must include: WHERE is_active = true AND email = '...'

-- Only index non-null values
CREATE INDEX idx_orders_shipped_at ON orders (shipped_at) WHERE shipped_at IS NOT NULL;

-- Index only pending orders (small subset of a large table)
CREATE INDEX idx_orders_pending ON orders (created_at) WHERE status = 'pending';
```

**Benefits:** Smaller index, faster to build, faster to scan, less write overhead for rows that do not match the condition.

## Expression Indexes

Index on a computed expression:

```sql
-- Case-insensitive email lookup
CREATE INDEX idx_users_email_lower ON users (lower(email));
-- Query MUST use: WHERE lower(email) = lower($1)

-- JSONB field extraction
CREATE INDEX idx_events_type ON events ((payload->>'type'));
-- Query: WHERE payload->>'type' = 'purchase'

-- Date truncation for time-based grouping
CREATE INDEX idx_orders_created_month ON orders (date_trunc('month', created_at));
-- Query: WHERE date_trunc('month', created_at) = '2025-01-01'
```

**Important:** The query must use the exact same expression as the index definition for the planner to use it.

## Covering Indexes (INCLUDE, PG 11+)

Add non-key columns to an index to enable Index Only Scans without making the B-tree key wider:

```sql
-- The index key is (customer_id, status); total and created_at are just "included" payload
CREATE INDEX idx_orders_cust_status ON orders (customer_id, status) INCLUDE (total, created_at);

-- This query can now be an Index Only Scan (no heap access):
SELECT customer_id, status, total, created_at
FROM orders
WHERE customer_id = 1 AND status = 'completed';
```

**INCLUDE columns** are not part of the B-tree ordering, so they do not help with filtering or sorting, but they allow the index to satisfy the SELECT list without visiting the heap.

## VACUUM / ANALYZE / Autovacuum

### Why VACUUM and ANALYZE Exist

PostgreSQL uses MVCC (Multi-Version Concurrency Control). When a row is updated or deleted, the old version remains as a "dead tuple" until VACUUM reclaims the space. Dead tuples cause table bloat and slow scans. ANALYZE updates table statistics that the query planner depends on for choosing good execution plans.

### Autovacuum Configuration

| Parameter | Default | Recommendation |
|-----------|---------|----------------|
| `autovacuum_vacuum_scale_factor` | 0.2 (20% dead tuples) | Lower to 0.01-0.05 for large tables |
| `autovacuum_analyze_scale_factor` | 0.1 (10% changed rows) | Lower to 0.02-0.05 for large tables |
| `autovacuum_vacuum_threshold` | 50 | Minimum dead tuples before vacuum triggers |
| `autovacuum_analyze_threshold` | 50 | Minimum changed rows before analyze triggers |
| `autovacuum_vacuum_cost_delay` | 2ms | Increase if autovacuum causes I/O pressure |
| `autovacuum_max_workers` | 3 | Increase for many tables (5-8 is common) |

### Per-Table Overrides

For large, high-churn tables, override autovacuum settings:

```sql
ALTER TABLE events SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_vacuum_threshold = 1000
);
```

### Monitoring Autovacuum

```sql
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    round(n_dead_tup::numeric / greatest(n_live_tup, 1) * 100, 2) AS dead_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### VACUUM FULL vs Regular VACUUM

| | Regular VACUUM | VACUUM FULL |
|-|---------------|-------------|
| Locks | No exclusive lock (runs concurrently) | **Exclusive lock on table** |
| Space | Marks dead tuples as reusable, does NOT shrink file | Rewrites entire table, reclaims disk space |
| When | Routine (autovacuum handles this) | Rarely; only after massive deletes when you must reclaim disk |
| Duration | Fast, incremental | Slow, blocks all access |

**Rule:** Rely on regular VACUUM (via autovacuum) for daily operations. Use `VACUUM FULL` only in maintenance windows after you understand the impact.

## Bulk Operations

### COPY Protocol via Npgsql (C#)

The fastest way to bulk-load data into PostgreSQL from .NET:

```csharp
await using var conn = new NpgsqlConnection(connectionString);
await conn.OpenAsync(ct);

await using var writer = await conn.BeginBinaryImportAsync(
    "COPY products (name, price, category, created_at) FROM STDIN (FORMAT BINARY)", ct);

foreach (var product in products)
{
    await writer.StartRowAsync(ct);
    await writer.WriteAsync(product.Name, NpgsqlDbType.Text, ct);
    await writer.WriteAsync(product.Price, NpgsqlDbType.Numeric, ct);
    await writer.WriteAsync(product.Category, NpgsqlDbType.Text, ct);
    await writer.WriteAsync(product.CreatedAt, NpgsqlDbType.TimestampTz, ct);
}

await writer.CompleteAsync(ct);  // CRITICAL: must call Complete or data is discarded
```

### COPY in Node.js (pg-copy-streams)

```javascript
const { from: copyFrom } = require('pg-copy-streams');
const { pipeline } = require('stream/promises');
const { Readable } = require('stream');

const client = await pool.connect();
try {
  const ingestStream = client.query(copyFrom(
    "COPY products (name, price, category) FROM STDIN WITH (FORMAT csv)"
  ));

  const source = Readable.from(
    products.map(p => `${p.name},${p.price},${p.category}\n`)
  );

  await pipeline(source, ingestStream);
} finally {
  client.release();
}
```

### Multi-Value INSERT

For moderate batch sizes (10-1000 rows), multi-value INSERT is simpler than COPY:

```sql
INSERT INTO products (name, price, category)
VALUES
    ('Widget A', 9.99, 'gadgets'),
    ('Widget B', 19.99, 'gadgets'),
    ('Widget C', 29.99, 'gadgets');
```

With Dapper, batch parameter objects:

```csharp
var products = new[]
{
    new { Name = "Widget A", Price = 9.99m, Category = "gadgets" },
    new { Name = "Widget B", Price = 19.99m, Category = "gadgets" },
};

await conn.ExecuteAsync(
    "INSERT INTO products (name, price, category) VALUES (@Name, @Price, @Category)",
    products);  // Dapper iterates and executes once per row
```

**Note:** Dapper's `Execute` with a collection still executes one INSERT per row. For true multi-value INSERT, build the SQL manually or use COPY.

### Performance Comparison

| Method | 1,000 rows | 100,000 rows | 1M rows |
|--------|-----------|-------------|---------|
| Individual INSERT (loop) | ~500ms | ~50s | ~500s |
| Multi-value INSERT (batched) | ~50ms | ~5s | ~50s |
| COPY (binary) | ~20ms | ~1s | ~5s |

COPY is approximately 10x faster than multi-value INSERT for large datasets.

## Statistics Targets

For columns with non-uniform distribution (skewed data), increase the statistics target so the planner builds a more accurate histogram:

```sql
-- Default statistics target is 100 (100 histogram buckets)
-- Increase for high-cardinality skewed columns
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ALTER TABLE events ALTER COLUMN event_type SET STATISTICS 1000;

-- Then re-analyze
ANALYZE orders;
ANALYZE events;
```

Higher statistics = more accurate plans but slightly slower ANALYZE. For most columns, the default of 100 is fine.

## pg_stat_statements

Essential extension for identifying slow and frequent queries.

### Enabling

```sql
-- postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
-- Restart required

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### Top Queries by Total Execution Time

```sql
SELECT
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct,
    left(query, 100) AS query_preview
FROM pg_stat_statements
WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user)
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Top Queries by Mean Execution Time

```sql
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows,
    left(query, 100) AS query_preview
FROM pg_stat_statements
WHERE calls > 100  -- filter out rare queries
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Reset Statistics

```sql
SELECT pg_stat_statements_reset();  -- reset all
```

**Workflow:** Enable `pg_stat_statements`, let it collect for a representative period, then sort by `total_exec_time` to find the queries consuming the most database time. Optimize those first for the biggest impact.

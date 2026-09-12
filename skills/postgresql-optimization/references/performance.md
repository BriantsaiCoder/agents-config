# Query Performance, Indexes, and Monitoring

## EXPLAIN Workflow

Apply the [Default Workflow](../SKILL.md#default-workflow) authorization and rollback conditions to all query, index, statistics, extension/config, and data-load operations below. Examples are candidates, not permission to execute them.

1. Reuse an existing representative plan; run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>` only when the query, environment, and effects are authorized.
2. Look for: `Seq Scan` on large tables, `Sort` spilling to disk (`external merge`), high `Buffers: shared read=` (cold cache hits), row estimate vs actual mismatch (planner has bad stats), and — PG 18+ — `Index Searches` far above 1 on a B-tree scan (skip scan fired, but the leading column's cardinality is too high for it to pay off; fix the column order or add an index).
3. Investigate estimates off by >10×; consider `ANALYZE <table>` or per-column stats changes only within authorized maintenance scope.

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT TEXT)
SELECT u.name, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2026-01-01'::date
GROUP BY u.id, u.name;

ALTER TABLE orders ALTER COLUMN user_id SET STATISTICS 1000;  -- default 100
ANALYZE orders;
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

**actual rows vs planned rows (rows):** If `actual rows` is dramatically different from the estimate (e.g., estimated 1 row, actual 50,000), investigate statistics; run `ANALYZE` only within the authorized maintenance scope.

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

## Index Types — Decision

| Type | Use for |
|---|---|
| `btree` (default) | Equality, range, ORDER BY |
| `gin` | JSONB, arrays, full-text, trigram |
| `gist` | Range types, geometric, exclusion constraints |
| `brin` | Append-only, naturally clustered (time-series) — tiny, no random reads |
| `hash` | Equality only; rarely worth it over btree (PG 10+ is WAL-logged so safe, just no range support) |

```sql
-- Composite: column order matches WHERE clause from most-selective to least
-- PG 18+: skip scan lets a composite index serve queries that omit the leading column,
-- but only when that column has few distinct values. Order by access pattern, not by skip scan.
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Partial: skip rows that never qualify
CREATE INDEX idx_active_users ON users(created_at) WHERE status = 'active';

-- Expression: compute once, reuse
CREATE INDEX idx_users_lower_email ON users(lower(email));

-- Covering (PG 11+): satisfy query without heap fetch
CREATE INDEX idx_orders_covering ON orders(user_id, status) INCLUDE (total, created_at);

-- BRIN for huge time-series with naturally ordered inserts
CREATE INDEX idx_events_brin ON events USING brin(occurred_at) WITH (pages_per_range = 64);
```

Use `CREATE INDEX CONCURRENTLY` in production — it doesn't lock writes (slower, allowed to fail; check `\d` output for `INVALID` index and rebuild).

## Query Patterns

### Pagination

```sql
-- ❌ OFFSET grows linearly: page 1000 reads rows 1..20020
SELECT * FROM products ORDER BY id OFFSET 10000 LIMIT 20;

-- ✅ Keyset (cursor) pagination — O(log n) regardless of page
SELECT * FROM products WHERE id > $last_id ORDER BY id LIMIT 20;
```

For UI that needs random page jumps, fall back to OFFSET but cap maximum offset.

### Bulk Insert

```sql
-- COPY is 5–10× faster than INSERT for large loads
COPY events (occurred_at, payload) FROM STDIN WITH (FORMAT csv);

-- Batched INSERT with multi-row VALUES is the next best
INSERT INTO events (occurred_at, payload) VALUES
    ($1, $2), ($3, $4), ($5, $6), ...;
```

Wrap authorized bulk loads in a transaction. Retain indexes unless a measured need and existing authorization cover their removal/recreation, with an applicable rollback plan.

### UPSERT

```sql
INSERT INTO counters (key, value) VALUES ('hits', 1)
ON CONFLICT (key) DO UPDATE SET value = counters.value + EXCLUDED.value;
```

## Monitoring

```sql
-- Slowest by total time (needs pg_stat_statements extension)
SELECT query, calls, total_exec_time, mean_exec_time, rows,
       100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;

-- Unused indexes (zero scans since last stats reset)
SELECT schemaname, relname, indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS idx_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Bloat snapshot (rough)
SELECT schemaname, relname,
       n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 20;

-- Connection breakdown
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
```

Compare retained snapshots over time. Use `pg_stat_statements_reset()` only for a necessary, authorized reset; archive snapshots first to preserve evidence, without claiming that this undoes the reset.

## Useful Extensions

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- query stats (load via shared_preload_libraries)
CREATE EXTENSION IF NOT EXISTS pg_trgm;              -- fuzzy / trigram match
CREATE EXTENSION IF NOT EXISTS btree_gin;            -- GIN over scalar types (composite GIN indexes)
CREATE EXTENSION IF NOT EXISTS pgcrypto;             -- crypt(), gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS unaccent;             -- diacritic-insensitive search
```

UUIDv7 (PG 18+) is monotonic — prefer it over random `gen_random_uuid()` for index locality.

## Maintenance Knobs

- **`autovacuum`** — leave on; tune per-table thresholds for hot tables (`autovacuum_vacuum_scale_factor`).
- **`work_mem`** — per-sort/hash; raise for analytical queries, but a single query can use this × number of operations × parallel workers.
- **`shared_buffers`** — typically 25% of RAM on a dedicated server.
- **`max_connections`** — keep low (~100–200), front with PgBouncer for high-concurrency workloads.

## Anti-Patterns

- **Adding indexes without measuring** — every index slows writes and consumes maintenance work. Verify usage in `pg_stat_user_indexes`.
- **`SELECT *` in hot paths** — defeats covering indexes, wastes network.
- **Long-running transactions** — block autovacuum, accumulate bloat. Keep transactions short; never `BEGIN` and wait on user input.
- **Function calls on indexed columns in WHERE** — `WHERE lower(email) = ...` requires an expression index on `lower(email)`, or the index is bypassed.

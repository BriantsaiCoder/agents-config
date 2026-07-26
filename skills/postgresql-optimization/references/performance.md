# Query Performance, Indexes, and Monitoring

## EXPLAIN Workflow

1. Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>` on a representative dataset.
2. Look for: `Seq Scan` on large tables, `Sort` spilling to disk (`external merge`), high `Buffers: shared read=` (cold cache hits), row estimate vs actual mismatch (planner has bad stats), and — PG 18+ — `Index Searches` far above 1 on a B-tree scan (skip scan fired, but the leading column's cardinality is too high for it to pay off; fix the column order or add an index).
3. If estimate is off by >10× → run `ANALYZE <table>`; if persistently off → bump per-column stats target.

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

Wrap in a transaction; drop non-essential indexes before big loads, recreate after.

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

Track over time: `pg_stat_statements_reset()` periodically to get rolling windows; archive snapshots before reset.

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

---
name: postgresql-best-practices
description: 'Use when writing or reviewing PostgreSQL SQL, schema, migrations, RLS policies, or DAL code — Npgsql, node-postgres/pg, DDL, jsonb, timestamptz, uuid, arrays, general query hygiene, PgBouncer pooling, COPY bulk-load, or partitioning basics. Apply even when user just says "design this PG schema", "review this PG migration", or "set up RLS". For deep PostgreSQL performance tuning with EXPLAIN, index/operator selection, JSONB, FTS, or partition strategy, use postgresql-optimization.'
---

# PostgreSQL Best Practices

PostgreSQL 15+ across .NET (Npgsql/Dapper) and Node.js (pg). MySQL / SQL Server / SQLite → skill does **not** apply.

Performance tuning (EXPLAIN, index/operator, JSONB pattern, FTS, partition) → `postgresql-optimization`. This skill: correctness, schema, migration, RLS, DAL, baseline hygiene.

## Mode

1. **Writing** — apply rules proactively. Don't ask before parameterization / `timestamptz` / `RETURNING`.
2. **Reviewing** — checklist. Priority: security (SQLi) → correctness (type / tz / tx) → perf (indexes, N+1, pagination).

## Golden Rules

Why + patterns → `references/rules-expanded.md`.

1. **`timestamptz`, never `timestamp`** for wall-clock. Timezone-less silently shifts meaning.
2. **Richest type** — UUID, arrays, JSONB, enums, ranges, `inet`. DB-side validation + indexing.
3. **JSONB > JSON; never structured data as TEXT.** GIN / `@>` / `?` / path only on JSONB.
4. **Parameterize all queries** (`@param` / `$1`). Dynamic identifiers → `pg-format`. SQLi defense + plan cache.
5. **Right index type** — B-tree / GIN / GiST / BRIN. Wrong = no win or pure overhead.
6. **Partial + expression indexes aggressively.** Smaller, faster, lower write cost.
7. **Tune autovacuum.** High-churn → `autovacuum_vacuum_scale_factor 0.01–0.05`. Watch `n_dead_tup`. Bloat + stale stats wreck plans.
8. **`EXPLAIN (ANALYZE, BUFFERS)` for complex queries.** Only ground truth.
9. **Pool connections** — Npgsql built-in / multiplexing; PgBouncer transaction mode for Node / multi-service. ~10 MB per conn.
10. **Retry SQLSTATE 40001** on SERIALIZABLE / RR. SSI aborts conflicts; no retry = random fails.
11. **`RETURNING`** vs separate SELECT after INSERT/UPDATE. Atomic, race-free.
12. **`INSERT ON CONFLICT`** for upserts. Atomic via unique index.

## Reference Map

- `references/rules-expanded.md` — rule whys + patterns
- `references/schema-design.md` — types, UUID, generated columns, partitioning, constraints, domains
- `references/query-writing.md` — params, CTE, window, RETURNING, FTS, JSONB/array ops, ON CONFLICT, LATERAL, keyset pagination
- `references/connections-transactions.md` — Npgsql conn string, multiplexing, Dapper, PgBouncer, pg Pool, isolation, 40001 retry, advisory locks, Npgsql 6+ DateTime breaking
- `references/performance-tuning.md` — EXPLAIN reading, index deep dive, partial/expression/covering, autovacuum, COPY, stats, pg_stat_statements
- `references/advanced-features.md` — RLS multi-tenant, MVs, extensions (pg_trgm, PostGIS, pgcrypto), partitioning vs inheritance, postgresql.conf
- `references/backup-restore.md` — pg_dump / pg_basebackup, parallel dumps, WAL, PITR, retention, restore validation

Open one at a time.

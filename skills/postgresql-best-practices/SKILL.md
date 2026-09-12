---
name: postgresql-best-practices
description: "Write or review PostgreSQL SQL, schema, migrations, RLS, and data-access correctness. Evidence-driven performance tuning uses postgresql-optimization."
---

# PostgreSQL Best Practices

PostgreSQL 15+ across .NET (Npgsql/Dapper) and Node.js (pg). MySQL / SQL Server / SQLite → skill does **not** apply.

Performance tuning (EXPLAIN, index/operator, JSONB pattern, FTS, partition) → `postgresql-optimization`. This skill: correctness, schema, migration, RLS, DAL, baseline hygiene.

## Mode

1. **Writing** — make minimal authorized query changes while preserving result/data semantics. Schema, time semantics, or transaction-boundary changes require matching S2/migration authorization. Review-only work produces findings.
2. **Reviewing** — checklist. Priority: security (SQLi) → correctness (type / tz / tx) → perf (indexes, N+1, pagination).

## Golden Rules

Why + patterns → `references/rules-expanded.md`.

1. **`timestamptz`, never `timestamp`** for wall-clock. Timezone-less silently shifts meaning.
2. **Richest type** — UUID, arrays, JSONB, enums, ranges, `inet`. DB-side validation + indexing.
3. **JSONB > JSON; never structured data as TEXT.** GIN / `@>` / `?` / path only on JSONB.
4. **Parameterize all queries** (`@param` / `$1`). Dynamic identifiers → `pg-format`. SQLi defense + plan cache.
5. **Index suitability** — record workload evidence for B-tree/GIN/GiST/BRIN choices; route tuning to `postgresql-optimization`.
6. **Partial/expression indexes** — evaluate query match and write overhead with that tuning owner.
7. **Autovacuum** — inspect existing bloat/stats evidence; configuration changes need matching authorization.
8. **Plan evidence** — prefer existing plans. `EXPLAIN ANALYZE` executes the query; check actual effects and environment before running it.
9. **Pool connections** — Npgsql built-in / multiplexing; PgBouncer transaction mode for Node / multi-service. ~10 MB per conn.
10. **Retry SQLSTATE 40001** on SERIALIZABLE / RR. SSI aborts conflicts; no retry = random fails.
11. **`RETURNING`** vs separate SELECT after INSERT/UPDATE. Atomic, race-free.
12. **`INSERT ON CONFLICT`** for upserts. Atomic via unique index.

## Reference Map

- `references/rules-expanded.md` — rule whys + patterns
- `references/schema-design.md` — types, UUID, generated columns, partitioning, constraints, domains
- `references/query-writing.md` — params, CTE, window, RETURNING, FTS, JSONB/array ops, ON CONFLICT, LATERAL, keyset pagination
- `references/connections-transactions.md` — Npgsql conn string, multiplexing, Dapper, PgBouncer, pg Pool, isolation, 40001 retry, advisory locks, Npgsql 6+ DateTime breaking
- `references/performance-tuning.md` — index deep dive, partial/expression/covering, autovacuum, COPY, stats, pg_stat_statements; plan reading → [EXPLAIN workflow](../postgresql-optimization/references/performance.md#explain-workflow)
- `references/advanced-features.md` — RLS multi-tenant, MVs, extensions (pg_trgm, PostGIS, pgcrypto), partitioning vs inheritance, postgresql.conf
- `references/backup-restore.md` — pg_dump / pg_basebackup, parallel dumps, WAL, PITR, retention, restore validation

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.

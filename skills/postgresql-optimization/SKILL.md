---
name: postgresql-optimization
description: "Tune PostgreSQL query plans, indexes, partitioning, and search with workload evidence; general schema and DAL correctness use postgresql-best-practices."
---

# PostgreSQL Optimization

Pick the PostgreSQL feature that matches the access pattern. Most "PG is slow" cases come from using a feature designed for one workload (e.g., JSONB for everything, OFFSET pagination on big tables) where a better-fitting feature exists.

This skill is the deep tuning companion to `postgresql-best-practices`. Use `postgresql-best-practices` for schema/migration/RLS/DAL correctness and baseline performance hygiene; use this skill when the answer depends on PostgreSQL planner behavior, access patterns, or specialized index/feature choices.

## Default Workflow

1. Prefer existing plans/workload evidence and authorized statistics reads. Before query execution (including `EXPLAIN (ANALYZE, BUFFERS)`) or maintenance, check the exact database, target, and effects against existing authorization. Reuse covered scope; prepare concrete commands and applicable rollback for index removal, statistics resets, extension/config changes, and data loads. Pause only uncovered operations and continue static analysis.
2. Identify the feature category (data shape, query pattern, scale).
3. Pick using the table below; read the matching reference for indexing/anti-pattern detail.
4. Compare representative latency, throughput, resource use, and correctness against the task goal; use plans to explain results, without requiring a changed plan shape.

## Feature Decision Table

| Symptom / Need | Pick | Read |
|---|---|---|
| Schemaless or sparse fields you query by containment | JSONB + `jsonb_path_ops` GIN | `references/jsonb.md` |
| Running totals, rankings, lag/lead, hierarchical data | Window functions / recursive CTE | `references/window-functions.md` |
| Free-text search with stemming, ranking, snippets | `tsvector` + GIN; trigram (`pg_trgm`) for fuzzy | `references/fts.md` |
| Time-series / multi-tenant table beyond ~50–100M rows | Declarative partitioning (`PARTITION BY RANGE/LIST`) | `references/partitioning.md` |
| Booking / scheduling overlap, time ranges | Range types + GiST exclusion constraint | `references/partitioning.md` |
| Pagination, bulk insert, UPSERT, missing indexes, monitoring | Indexes + query patterns + `pg_stat_*` | `references/performance.md` |
| Composite index but queries often omit the leading column | Check leading-column cardinality; PG 18+ B-tree skip scan | `references/performance.md` |

## Always-True Anti-Patterns

- **`SELECT * FROM t OFFSET <large> LIMIT N`** → use keyset pagination.
- **`column LIKE '%foo%'`** for search → trigram or FTS.
- **`data::text LIKE '%role%'`** on JSONB → `data @> '{"role": "..."}'` with GIN.
- **Function on indexed column in `WHERE`** (`WHERE lower(email) = ...`) → expression index, or the planner ignores the index.
- **Adding indexes without measuring** → every index slows writes; verify usage before keeping.
- **Long-running transactions** → block autovacuum, accumulate bloat.

## Validation Checklist

- Representative workload meets the agreed performance goal without correctness regression. A sequential scan can be appropriate; investigate actual bottlenecks and spills.
- Investigate row estimates differing from actual by more than ~10×; run `ANALYZE` or change stats targets only within the authorized maintenance scope.
- New indexes show non-zero `idx_scan` after a representative workload.
- For migration / index changes on hot tables: `CREATE INDEX CONCURRENTLY`, `DETACH PARTITION ... CONCURRENTLY` (PG 14+). `ATTACH PARTITION` has no `CONCURRENTLY` form — it already takes only SHARE UPDATE EXCLUSIVE on the parent.

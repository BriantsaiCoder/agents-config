---
name: postgresql-optimization
description: "Tune PostgreSQL query plans, indexes, partitioning, and search with workload evidence; general schema and DAL correctness use postgresql-best-practices."
---

# PostgreSQL Optimization

Pick the PostgreSQL feature that matches the access pattern. Most "PG is slow" cases come from using a feature designed for one workload (e.g., JSONB for everything, OFFSET pagination on big tables) where a better-fitting feature exists.

This skill is the deep tuning companion to `postgresql-best-practices`. Use `postgresql-best-practices` for schema/migration/RLS/DAL correctness and baseline performance hygiene; use this skill when the answer depends on PostgreSQL planner behavior, access patterns, or specialized index/feature choices.

## Default Workflow

1. Get evidence: `EXPLAIN (ANALYZE, BUFFERS)` on a representative dataset; check `pg_stat_statements` for offending queries; check `pg_stat_user_indexes` for unused / missing indexes.
2. Identify the feature category (data shape, query pattern, scale).
3. Pick using the table below; read the matching reference for indexing/anti-pattern detail.
4. Verify with `EXPLAIN` again — confirm the plan changed and the cost dropped on real data.

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

- `EXPLAIN ANALYZE` plan changed (no more `Seq Scan` on the hot path / sort no longer spills).
- Row estimate vs actual within ~10×; if not, `ANALYZE` and consider raising stats target.
- New indexes show non-zero `idx_scan` after a representative workload.
- For migration / index changes on hot tables: `CREATE INDEX CONCURRENTLY`, `DETACH PARTITION ... CONCURRENTLY` (PG 14+). `ATTACH PARTITION` has no `CONCURRENTLY` form — it already takes only SHARE UPDATE EXCLUSIVE on the parent.

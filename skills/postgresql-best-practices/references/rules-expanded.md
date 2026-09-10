# PostgreSQL Golden Rules — Expanded

The Why behind each rule.

## 1. Always `timestamptz`, never `timestamp`

**Why**: `timestamp` (without time zone) stores a raw value with no timezone context. When server / session timezone changes, the stored value's meaning changes silently. `timestamptz` stores UTC internally and converts on display.

## 2. Use the richest appropriate type

UUID, arrays, JSONB, enums, range types, `inet`, etc.

**Why**: PostgreSQL's type system gives built-in validation, indexing, and operators. `text` for everything = reimplementing those guarantees in app code, poorly.

## 3. JSONB > JSON; never structured data as TEXT

**Why**: `jsonb` decomposed binary supports GIN indexing, `@>`, `?`, path queries. `json` preserves whitespace but no indexing. `text` JSON loses query + validation.

## 4. Parameterize all queries

`@param` (Npgsql/Dapper) / `$1`/`$2` (pg). Dynamic identifiers → `pg-format`.

**Why**: Only reliable defense against SQL injection. Enables plan cache.

## 5. Right index type for access pattern

- B-tree → equality, range, ORDER BY
- GIN → arrays, JSONB, full-text, trigram
- GiST → spatial, range types, KNN
- BRIN → large append-only with naturally correlated columns

**Why**: B-tree on JSONB does nothing useful. GIN on a high-write column is overhead. Match index to query → fast vs full scan.

## 6. Evaluate partial/expression indexes with the tuning owner

`CREATE INDEX … WHERE is_active = true` / `CREATE INDEX ON t(lower(email))`.

**Why**: Smaller, faster build, faster scan, lower write overhead. Expression indexes make planner use them on computed predicates.

## 7. VACUUM / ANALYZE — understand autovacuum

Inspect existing `n_dead_tup` and workload evidence; autovacuum tuning belongs to `postgresql-optimization`. Changing settings needs matching configuration authorization.

**Why**: MVCC leaves dead tuples after UPDATE/DELETE. No timely VACUUM = bloat + slow scans. No ANALYZE = stale stats = bad plans.

## 8. `EXPLAIN (ANALYZE, BUFFERS)` for complex queries

Prefer existing plans and route planner decisions to `postgresql-optimization`. Before a fresh ANALYZE probe, check query side effects and authorized environment; then compare actual/estimated rows and buffers against workload goals.

**Why**: Cost-based planner. Wrong estimates → catastrophic plans. EXPLAIN ANALYZE is the only ground truth.

## 9. Pool connections — Npgsql / PgBouncer

PostgreSQL forks ~10 MB per connection. Keep `max_connections` low. .NET → Npgsql built-in pool / multiplexing. Node.js / multi-service → PgBouncer transaction mode.

**Why**: Connection overhead is PostgreSQL's Achilles heel.

## 10. Retry SQLSTATE 40001 (`serialization_failure`)

Expected under SERIALIZABLE / REPEATABLE READ. Catch, back off, retry.

**Why**: SSI (Serializable Snapshot Isolation) achieves true serializability by aborting conflicting transactions. No retry → random failures under concurrency.

## 11. `RETURNING` over separate `SELECT` after write

**Why**: Atomic with the write, no second round trip, no race between write and follow-up read.

## 12. `INSERT ON CONFLICT` for upserts

`DO NOTHING` for skip; `DO UPDATE` with `EXCLUDED` for merge.

**Why**: App-level "check-then-insert" is a race. `ON CONFLICT` is atomic via the unique index — no full-table lock.

## Working Pattern — Writing

1. Confirm PG version (15+ for the most modern features).
2. Schema first: types intentional (`timestamptz`, `uuid`, `jsonb`, arrays, enums/domains, ranges).
3. Constraints: `CHECK`, `UNIQUE`, exclusion, generated columns — let DB enforce invariants.
4. Parameterize. `RETURNING` for write-then-read. `ON CONFLICT` for upsert.
5. Index after the query is written — pick type by access pattern; partial / expression where it pays.
6. Validate with `EXPLAIN (ANALYZE, BUFFERS)`.

## Working Pattern — Reviewing

Walk top-to-bottom in this order:

1. **Security** — parameterization, least-privilege grants, RLS correctness, no app-user `GRANT ALL`.
2. **Schema fit** — `timestamp` vs `timestamptz`, `text` instead of `jsonb` / array / enum / domain / range.
3. **JSONB / arrays** — indexable operators (`@>`, `?`, array containment) over `data::text LIKE …` or unindexed `ANY(...)`.
4. **Constraints** — `CHECK`, `UNIQUE`, exclusion, generated columns where the DB can enforce.
5. **Performance evidence** — `EXPLAIN (ANALYZE, BUFFERS)` for non-trivial queries; index type / partial / expression fit; row-estimate quality.
6. **Operational safety** — concurrent index creation on hot tables; lock-impact note; rollback or forward-fix for risky migrations.

# MySQL Golden Rules — Expanded

The Why behind each rule. Read this when you need to judge an edge case, justify a deviation, or explain a violation in review.

## 1. utf8mb4 with the correct collation

Use `utf8mb4` for charset and `utf8mb4_0900_ai_ci` (8.0) or `utf8mb4_unicode_ci` (5.7) for collation — on the server, every table, and the connection string. **Never** use MySQL's `utf8`.

**Why**: MySQL's `utf8` is a 3-byte alias for `utf8mb3` and silently truncates emoji and many CJK characters. Every other system's "utf8" is 4-byte; MySQL's is the exception.

## 2. Smallest sufficient data type

`TINYINT` for booleans / small enums, `INT` for general integers, `BIGINT` for PKs and large counters. `DECIMAL` for money — never `FLOAT` / `DOUBLE`. `VARCHAR(N)` over `TEXT` when max length is known.

**Why**: Smaller types use less disk, fit more rows in the buffer pool, and make indexes smaller and faster.

## 3. Explicit primary key — auto-increment BIGINT or UUID v7

Auto-increment `BIGINT UNSIGNED` is optimal for InnoDB's clustered index (sequential, append-only). UUID v7 / ULID acceptable for distributed systems. Avoid UUID v4 as PK.

**Why**: InnoDB clusters data by the primary key. Random PKs scatter writes across the B+Tree, causing page splits and severe write amplification.

## 4. Parameterize all queries

.NET → Dapper `@param` with anonymous objects or `DynamicParameters`. Node.js → mysql2 `?` placeholders or named placeholders with `execute()`. **Never** concatenate user input into SQL.

**Why**: Only reliable defense against SQL injection. Also enables server-side prepared statement caching.

## 5. EXPLAIN before shipping queries touching > 1 table or > 1K expected rows

Check `type` (avoid `ALL`), `key` (should not be NULL), `Extra` (watch for `Using filesort` / `Using temporary`). Use `EXPLAIN ANALYZE` (8.0.18+) for actual vs estimated.

**Why**: A missing index on a JOIN column or a full table scan is invisible without EXPLAIN and only surfaces in production under load.

## 6. Index for WHERE → ORDER BY → SELECT (covering)

Equality columns first, single range column next, sort columns after, remaining selected columns last. Leftmost prefix rule: `(a, b, c)` serves `(a)`, `(a, b)`, `(a, b, c)` but not `(b)` or `(c)` alone.

**Why**: A well-ordered composite index can satisfy filter + sort + projection in a single index scan, avoiding both clustered index lookup and filesort.

## 7. Default to InnoDB. Never MyISAM for new tables

InnoDB: transactions, row-level locking, crash recovery, foreign keys.

**Why**: MyISAM uses table-level locking (one write blocks all reads), has no crash recovery, no transactions. There is no valid reason to use it for new application tables.

## 8. MySqlConnector in .NET; mysql2 in Node.js

MySqlConnector → true async I/O (not sync-over-async like MySql.Data), full `CancellationToken`, robust pooling. mysql2 → prepared statements, streaming, proper BIGINT / DECIMAL handling.

**Why**: MySql.Data's fake async causes thread pool starvation under load. mysql2 is the maintained successor to the original `mysql` package.

## 9. Understand GAP locks in REPEATABLE READ

InnoDB's default isolation uses next-key locks (record + gap) to prevent phantom reads. Range scans in UPDATE/DELETE lock the gaps between index entries, blocking concurrent INSERTs.

**Why**: Most common cause of unexpected deadlocks. Mitigations: narrow WHERE clauses, use unique index lookups, switch to READ COMMITTED, keep transactions short.

## 10. Know your version's feature set

CTEs, window functions, `JSON_TABLE`, hash joins, `EXPLAIN ANALYZE`, enforced CHECK constraints, functional indexes, histograms → all 8.0+. On 5.7 they cause syntax errors.

**Why**: 5.7 and 8.0 have significantly different feature sets. Code written for 8.0 will silently fail or error on 5.7.

## 11. Online DDL for schema changes on live tables

Prefer `ALGORITHM=INPLACE` (or `INSTANT` in 8.0.12+) over default `COPY`. For huge tables, use `pt-online-schema-change` or `gh-ost`.

**Why**: `COPY` creates a full table copy and holds a metadata lock for the entire duration, blocking all DML. On a 10GB table = minutes of downtime. `INPLACE` allows concurrent reads/writes; `INSTANT` completes in constant time for supported changes.

## 12. Enable and monitor the slow query log

Set `long_query_time` to 1s (or lower, e.g. 0.5s). Use `pt-query-digest` to aggregate by *total time*, not just per-execution time.

**Why**: A 200ms query running 10K times/hour costs more than one 5-second query. Without the log, performance problems are invisible until they become outages.

---
name: mysql-best-practices
description: 'Use when writing or reviewing MySQL 8.x / 8.4 LTS / 9.x (plus 5.7 legacy) SQL, schema, or DAL code — MySqlConnector, mysql2, DDL/migrations, stored procedures, my.cnf tuning, utf8mb4, InnoDB choices, keyset pagination, transactions, deadlock diagnosis, or slow queries.'
---

# MySQL Best Practices

MySQL 8.0 / 8.4 LTS / 9.x innovation across .NET (MySqlConnector + Dapper) and Node.js (mysql2). 5.7 is EOL — still covered, but only when taking over legacy; see `references/version-dba.md`. PostgreSQL / SQL Server / SQLite → skill does **not** apply.

## Mode

1. **Writing** — apply rules proactively. Don't ask before utf8mb4 / parameterized.
2. **Reviewing** — checklist. Priority: security (SQLi) → correctness (charset, types, tx) → perf (indexes, plans).

## Golden Rules

Why → `references/rules-expanded.md`.

1. **utf8mb4 + collation** (`utf8mb4_0900_ai_ci` 8.0 / `utf8mb4_unicode_ci` 5.7). Plain `utf8` truncates emoji / CJK.
2. **Smallest sufficient type.** `DECIMAL` for money; `VARCHAR(N)` over `TEXT`. Buffer pool + index size.
3. **Explicit PK — `BIGINT UNSIGNED` or UUID v7.** No UUID v4 PK; clustered index write amplification.
4. **Parameterize all queries.** Dapper `@param` / mysql2 `?`. SQLi + prepared-statement cache.
5. **`EXPLAIN` before shipping** > 1 table / > 1K rows. Watch `type` / `key` / `Extra`. Scans hide until load.
6. **Index for WHERE → ORDER BY → SELECT (covering).** Leftmost prefix.
7. **InnoDB only.** MyISAM = table lock, no recovery, no tx.
8. **MySqlConnector (.NET); mysql2 (Node).** MySql.Data fake async starves thread pool.
9. **Gap locks in RR.** Range UPDATE/DELETE → deadlocks. Next-key locks block INSERTs.
10. **Match version.** CTE, window, `JSON_TABLE`, `EXPLAIN ANALYZE`, enforced CHECK → 8.0+ only.
11. **Online DDL.** `ALGORITHM=INPLACE`/`INSTANT` (8.0.12+); huge → `pt-online-schema-change` / `gh-ost`. Default `COPY` = minutes downtime.
12. **Slow log on, `long_query_time=1`.** `pt-query-digest` by total time. 200ms × 10K/hr > one 5s.

## Reference Map

- `references/rules-expanded.md` — rule whys + edge cases
- `references/working-patterns.md` — writing / reviewing patterns
- `references/schema-design.md` — tables, types, PK, composite indexes, partitioning
- `references/query-writing.md` — params, JOIN, CTE, window, JSON, EXPLAIN, pagination
- `references/connections-transactions.md` — MySqlConnector vs MySql.Data, pool, isolation, deadlock retry, outbox
- `references/performance-tuning.md` — slow log, pt-query-digest, covering indexes, bulk insert, hints, buffer pool
- `references/version-dba.md` — 5.7 vs 8.0 matrix + where 8.4 LTS / 9.x sit, my.cnf, monitoring, replication
- `references/backup-restore.md` — mysqldump / XtraBackup, binlog PITR, retention

Open one at a time.

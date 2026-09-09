---
name: mysql-best-practices
description: "Write, review, or tune MySQL SQL, schema, transactions, and data access for the installed version; legacy 5.7 guidance is included."
---

# MySQL Best Practices

MySQL 8.0 / 8.4 LTS / 9.x innovation across .NET (MySqlConnector + Dapper) and Node.js (mysql2). 5.7 is EOL — still covered, but only when taking over legacy; see `references/version-dba.md`. PostgreSQL / SQL Server / SQLite → skill does **not** apply.

## Mode

1. **Writing** — parameterize authorized query changes. New columns follow repo/version charset policy; converting existing charset/collation/schema requires explicit migration scope, compatibility analysis, and rollback under S2. Review-only work produces findings.
2. **Reviewing** — checklist. Priority: security (SQLi) → correctness (charset, types, tx) → perf (indexes, plans).

## Golden Rules

Why → `references/rules-expanded.md`.

1. **Match charset/collation to schema semantics and installed version.** Prefer compatible utf8mb4 for new text columns; do not silently convert existing comparison or uniqueness semantics.
2. **Smallest sufficient type.** `DECIMAL` for money; `VARCHAR(N)` over `TEXT`. Buffer pool + index size.
3. **Explicit PK — `BIGINT UNSIGNED` or UUID v7.** No UUID v4 PK; clustered index write amplification.
4. **Parameterize all queries.** Dapper `@param` / mysql2 `?`. SQLi + prepared-statement cache.
5. **Inspect existing plans and workload evidence.** Run non-writing plan probes only for the authorized query/environment; inspect `type` / `key` / `Extra` when performance is in scope.
6. **Index for WHERE → ORDER BY → SELECT (covering).** Leftmost prefix.
7. **InnoDB only.** MyISAM = table lock, no recovery, no tx.
8. **MySqlConnector (.NET); mysql2 (Node).** MySql.Data fake async starves thread pool.
9. **Gap locks in RR.** Range UPDATE/DELETE → deadlocks. Next-key locks block INSERTs.
10. **Match version.** CTE, window, `JSON_TABLE`, `EXPLAIN ANALYZE`, enforced CHECK → 8.0+ only.
11. **Authorize DDL effects explicitly.** Check installed-version algorithm support, locks, consumers, and rollback before an online migration; a query review does not authorize schema execution.
12. **Use existing slow-log evidence**, ranked by total cost. Enabling logs or changing thresholds is a configuration effect requiring matching authorization.

## Reference Map

- `references/rules-expanded.md` — rule whys + edge cases
- `references/working-patterns.md` — writing / reviewing patterns
- `references/schema-design.md` — tables, types, PK, composite indexes, partitioning
- `references/query-writing.md` — params, JOIN, CTE, window, JSON, EXPLAIN, pagination
- `references/connections-transactions.md` — MySqlConnector vs MySql.Data, pool, isolation, deadlock retry, outbox
- `references/performance-tuning.md` — slow log, pt-query-digest, covering indexes, bulk insert, hints, buffer pool
- `references/version-dba.md` — 5.7 vs 8.0 matrix + where 8.4 LTS / 9.x sit, my.cnf, monitoring, replication
- `references/backup-restore.md` — mysqldump / XtraBackup, binlog PITR, retention

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.

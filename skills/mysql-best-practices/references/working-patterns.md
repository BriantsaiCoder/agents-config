# MySQL Working Patterns

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Working pattern for *writing* MySQL code

1. Confirm the MySQL version (5.7 or 8.0+). This determines available features (CTEs, window functions, JSON_TABLE, hash joins).
2. Choose charset `utf8mb4` and the version-appropriate collation.
3. Design tables with explicit PKs (auto-increment BIGINT or UUID v7), smallest sufficient data types, and NOT NULL where appropriate.
4. Write SQL with parameterized placeholders (`@param` for .NET, `?` for Node.js). Choose the right Dapper method by arity.
5. Design indexes following the equality-range-sort-select order. Check for redundant indexes.
6. Run EXPLAIN on any query touching multiple tables or expected to handle significant row counts. Fix `ALL` access types and missing keys.
7. For transactions, keep them short, pass the transaction object to every Dapper call, and implement deadlock retry with exponential backoff.

## Working pattern for *reviewing* MySQL code

Walk the file top-to-bottom and check, in this order:

1. **SQL injection:** Any string concatenation or interpolation in SQL with variables? Flag as severity HIGH. Fix is always parameterization.
2. **Charset:** Tables or connections using `utf8` instead of `utf8mb4`? Flag as correctness issue.
3. **Data types:** FLOAT/DOUBLE for money? VARCHAR without length limit where TEXT is not needed? UUID v4 as clustered PK? DATETIME where TIMESTAMP semantics are intended (or vice versa)?
4. **Primary keys:** Tables without an explicit PK? Composite PKs that could be replaced with a surrogate?
5. **Index design:** Missing indexes on JOIN columns or WHERE predicates? Redundant indexes? Wrong column order in composite indexes?
6. **Query efficiency:** Correlated subqueries that should be JOINs? OFFSET-based pagination at depth? SELECT * when only specific columns are needed? Missing EXPLAIN evidence?
7. **Transaction safety:** Long-running transactions? Missing deadlock retry? Gap-lock-prone patterns in REPEATABLE READ? DDL mixed with DML in a transaction?
8. **Connection management:** Missing connection pool configuration? Hardcoded credentials? Missing SSL/TLS in production? MySql.Data used instead of MySqlConnector?
9. **Schema change safety:** ALTER TABLE on a large table without `ALGORITHM=INPLACE` or an online DDL tool? DDL during peak traffic without migration tooling?
10. **Observability:** Slow query log disabled or `long_query_time` still at default 10s? No monitoring of query performance in production?

Report findings grouped by severity (security, correctness, performance, style), each with a short code-level fix, not just a principle.

# PostgreSQL Working Patterns

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Working pattern for *writing* PostgreSQL code

1. Confirm the PostgreSQL version (15+ assumed) and the client library (`NpgsqlConnection` for .NET, `pg.Pool` for Node.js). Check for Npgsql version and any timestamp behavior settings.
2. For schema changes: use `timestamptz` for times, the richest appropriate type for each column, `GENERATED ALWAYS AS IDENTITY` instead of `serial`, snake_case naming, and explicit constraints (CHECK, UNIQUE, FK with appropriate ON DELETE).
3. Write SQL with parameterized placeholders (`@param` for .NET, `$1` for Node.js). Pick the right Dapper method by arity if using .NET.
4. For reads: add `RETURNING` to writes, use keyset pagination instead of OFFSET for large result sets, use CTEs for readability, prefer `= ANY(@ids)` over `IN @ids` for array parameters in PostgreSQL.
5. For indexes: match the index type to the query operators. Add partial/expression indexes when queries filter on conditions or computed values.
6. For transactions: set isolation level explicitly when needed, pass `transaction:` in Dapper calls, handle serialization failures with retry.
7. Run `EXPLAIN (ANALYZE, BUFFERS)` on the query in a development environment with representative data.

## Working pattern for *reviewing* PostgreSQL code

Walk the file top-to-bottom and check, in this order:

1. **SQL injection**: Any string concatenation, interpolation, template literals, or `string.Format` touching SQL with user-controlled variables? Flag as severity HIGH. Fix: parameterize.
2. **Timestamp correctness**: Any use of `timestamp` (without tz) for wall-clock times? Any `DateTime.Now` or `DateTime.Kind = Local` with Npgsql 6+? Flag and suggest `timestamptz` + `DateTimeOffset`.
3. **Type misuse**: Structured data stored as `text` instead of `jsonb`? UUIDs stored as `varchar`? IP addresses as `text`? Booleans as `smallint`? Flag and suggest the native PostgreSQL type.
4. **Connection/transaction lifecycle**: Connection leaks (no `using`/`await using` in .NET, no `client.release()` in Node.js)? Transactions without proper commit/rollback/finally? Dapper calls missing `transaction:` parameter inside a transaction block?
5. **Missing indexes**: Foreign key columns without indexes? Columns used in WHERE/JOIN/ORDER BY without supporting indexes? Wrong index type for the operator (e.g., B-tree for JSONB containment)?
6. **N+1 queries**: Database calls inside loops? Suggest batching with `= ANY(@ids)`, CTEs, or `QueryMultipleAsync`.
7. **Pagination**: OFFSET-based pagination on large tables? Suggest keyset pagination.
8. **Missing RETURNING**: INSERT/UPDATE followed by a separate SELECT for the same row? Suggest `RETURNING`.
9. **Error handling**: Silent catch of `PostgresException`? Missing serialization failure retry for SERIALIZABLE transactions? Swallowed exceptions that hide database errors?

Report findings grouped by severity (security > correctness > performance > style), each with a short code-level fix.

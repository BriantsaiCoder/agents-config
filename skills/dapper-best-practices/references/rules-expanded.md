# Dapper Golden Rules — Expanded

The Why behind each rule + working patterns for writing and reviewing.

## 1. Always parameterize

`@name` placeholders + anonymous object / POCO / `DynamicParameters`. Never interpolate user input.

**Why**: Only reliable defense against SQL injection. Also lets the DB cache execution plans.

## 2. Own connection lifetime with `await using`

`await using var conn = new SqlConnection(connStr);` (or factory).

**Why**: Returns the connection to the pool deterministically, even on exceptions. A long-lived `IDbConnection` field is a leak waiting to happen.

## 3. `*Async` + `CancellationToken`

Default to `QueryAsync`, `ExecuteAsync`, `QueryFirstOrDefaultAsync`, `QueryMultipleAsync`. Pass token via `new CommandDefinition(sql, param, cancellationToken: ct)`.

**Why**: Sync Dapper on a hot ASP.NET path blocks threadpool threads, starves the server, and cannot be cancelled.

## 4. No `IEnumerable<T>` return from inside `using` (when `buffered: false`)

Either buffer (default → `List<T>`), materialize inside the block, or return `IAsyncEnumerable<T>` and keep the connection alive for the caller.

**Why**: Unbuffered `IEnumerable` defers iteration; by the time the caller iterates, the `using` has closed the connection → `ObjectDisposedException`.

## 5. Right read method for arity

- `QueryAsync<T>` — 0..N rows
- `QueryFirstOrDefaultAsync<T>` — 0 or 1 row, no exception
- `QuerySingleAsync<T>` — exactly 1, throws otherwise (must-exist invariant)
- `ExecuteScalarAsync<T>` — single value (count, id, aggregate)

**Why**: `QueryFirstOrDefaultAsync` tells the DB to stop after one row and communicates intent.

## 6. Kill N+1

If you're calling Dapper inside `foreach`, stop. Options:

- Batch: `WHERE id IN @ids` (Dapper expands lists automatically)
- `QueryMultipleAsync` for parent + children
- Multi-mapping: `QueryAsync<Order, Customer, Order>(sql, (o, c) => …, splitOn: "CustomerId")`

**Why**: Each round trip ≈ 1ms+ latency; 100 calls = 100ms wall time for nothing.

## 7. Transactions: open, pass, commit, dispose

```csharp
await using var tx = await conn.BeginTransactionAsync(ct);
// pass `transaction: tx` to *every* Dapper call inside the block
await tx.CommitAsync(ct);
```

**Why**: Dapper does not auto-enlist; `IDbCommand.Transaction` must be set explicitly via the `transaction:` parameter. Forget it → statements run outside the transaction and silently break atomicity.

## 8. DI owns the connection factory, not the constructor

Register `IDbConnectionFactory` (scoped/transient); repositories ask the factory for a fresh connection per operation.

**Why**: A connection opened in a ctor has the lifetime of the class. Singleton repository = forever leak. Even scoped is worse than letting the pool work.

## 9. POCOs, not `dynamic`

Class properties match column names (or `DefaultTypeMap.MatchNamesWithUnderscores = true` for snake_case). Use SQL aliases when needed.

**Why**: `dynamic` defers all type errors to runtime, breaks refactoring, hides schema drift. POCOs give compile-time checks and IntelliSense.

## 10. Bulk inserts don't belong in a Dapper loop

> few hundred rows → `SqlBulkCopy` (+ `FastMember.ObjectReader`), `Dapper.Plus`, TVP, `MERGE`, staging table.

**Why**: Dapper = one INSERT per call. `SqlBulkCopy` streams all rows in a single protocol operation — 10–100× faster.

## 11. Stored procedures: be explicit

`commandType: CommandType.StoredProcedure`, build inputs with `DynamicParameters`, read output/return via `parameters.Get<T>("@name")` *after* the call.

**Why**: Default is `CommandType.Text` → without the flag the proc name becomes malformed SQL.

## 12. Don't swallow `SqlException`

Propagate or wrap with context (which query, which parameters — but never log raw parameter values if they contain PII / secrets).

**Why**: Silent catch-and-return-null turns a data-layer bug into a mysterious upstream NRE hours later.

## Working Pattern — Writing

1. Confirm provider (`Sql` / `Npgsql` / `Sqlite` / `MySql` / `Oracle` Connection). `LIMIT`/`TOP`, parameter prefix, bulk insert all differ.
2. Start from a POCO matching the result shape. Snake_case mapping if needed.
3. Write SQL with `@param` placeholders. Pick Dapper method by arity (rule 5).
4. Get connection from injected factory; wrap in `await using`.
5. `*Async` + `CancellationToken`. Pass `transaction:` if inside a transaction block.
6. Multiple result sets / parent-child → `QueryMultipleAsync` / multi-mapping before any loop.
7. INSERT/UPDATE/DELETE → return `rowsAffected` so caller can assert expected count.

## Working Pattern — Reviewing

Walk top-to-bottom in this order:

1. **Security** — `$"..."` / `+` / `string.Format` / `StringBuilder` with a variable in SQL? → SQL injection, severity HIGH. Fix: `@param` + parameter object.
2. **Connection lifetime** — every `new SqlConnection` inside `await using`? Stored `IDbConnection` field? `IEnumerable<T>` returning from a `using` with `buffered: false`?
3. **Async hygiene** — sync `Query`/`Execute` on an async method? `.Result` / `.Wait()` / `.GetAwaiter().GetResult()`? Missing `CancellationToken`?
4. **Transactions** — `BeginTransaction` without matching `Commit`/`Rollback`? Calls inside the block missing `transaction: tx`?
5. **N+1** — Dapper call inside `foreach` / `Select` / `for`? Suggest batching, multi-mapping, `QueryMultiple`.
6. **Mapping** — `dynamic` return that could be POCO? Column alias / casing mismatch silently dropping data?
7. **Bulk** — large list with `await ExecuteAsync` per row? Suggest `SqlBulkCopy` or TVP.
8. **Error handling** — empty `catch`? Swallowed `SqlException`? Logging leaking parameter values?

Group findings by severity (security → correctness → performance → style); each with a code-level fix, not just a principle.

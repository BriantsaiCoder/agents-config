# Performance: Buffering, Async, Multi-result, Multi-mapping

Reference for rules 3, 4, 5, 6 in SKILL.md. Read this when a Dapper query is slow, touches large result sets, or joins multiple tables.

## Table of contents
- [`buffered: true` vs `false`](#buffered-true-vs-false)
- [Streaming with `IAsyncEnumerable`](#streaming-with-iasyncenumerable)
- [`QueryMultipleAsync` for parent/child](#querymultipleasync-for-parentchild)
- [Multi-mapping and `splitOn`](#multi-mapping-and-spliton)
- [Async pitfalls](#async-pitfalls)
- [`CommandDefinition` and `CancellationToken`](#commanddefinition-and-cancellationtoken)
- [Plan caching and parameter sizing](#plan-caching-and-parameter-sizing)
- [Benchmarking tips](#benchmarking-tips)

## `buffered: true` vs `false`

Dapper's default is `buffered: true`, which means `QueryAsync<T>` internally materializes all rows into a `List<T>` before returning. This is the right choice 95% of the time because:
- The connection is released back to the pool immediately after the call returns.
- You can iterate the result multiple times.
- LINQ operators over the result don't re-query.

`buffered: false` keeps the reader open and yields rows lazily:
```csharp
// WARNING: connection MUST stay open while the caller iterates
var rows = await conn.QueryAsync<Row>(
    new CommandDefinition(sql, param, flags: CommandFlags.None, cancellationToken: ct));
// With buffered:false you typically do it this way:
foreach (var row in conn.Query<Row>(sql, param, buffered: false))
{
    await ProcessAsync(row);
}
```
Rules for `buffered: false`:
1. **Iterate inside the `using` block** that owns the connection. Never `return` the `IEnumerable<T>` — by the time the caller touches it, the connection has been disposed and you get `ObjectDisposedException` or `InvalidOperationException`.
2. Prefer this path only when the row count is large enough that buffering would blow memory, *and* you can process rows in a streaming fashion.
3. If you need async + streaming, prefer `IAsyncEnumerable<T>` (next section).

## Streaming with `IAsyncEnumerable`

For truly large result sets in an async codebase, wrap a raw reader:
```csharp
public async IAsyncEnumerable<Row> StreamRowsAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    await using var conn = _factory.Create();
    await conn.OpenAsync(ct);
    await using var reader = await conn.ExecuteReaderAsync(
        new CommandDefinition(sql, param, cancellationToken: ct));

    var parser = reader.GetRowParser<Row>();
    while (await reader.ReadAsync(ct))
    {
        yield return parser(reader);
    }
}
```
The connection lives as long as the enumerator. `GetRowParser<T>` is Dapper's compiled mapper — fast, no reflection per row.

## `QueryMultipleAsync` for parent/child

Instead of N+1:
```csharp
// BAD
var orders = await conn.QueryAsync<Order>("SELECT * FROM Orders WHERE CustomerId = @id", new { id });
foreach (var o in orders)
    o.Lines = (await conn.QueryAsync<OrderLine>(
        "SELECT * FROM OrderLines WHERE OrderId = @oid", new { oid = o.Id })).ToList();
```
Do one round trip:
```csharp
const string sql = @"
SELECT * FROM Orders      WHERE CustomerId = @id;
SELECT * FROM OrderLines  WHERE OrderId IN (SELECT Id FROM Orders WHERE CustomerId = @id);";

await using var multi = await conn.QueryMultipleAsync(sql, new { id });
var orders = (await multi.ReadAsync<Order>()).ToList();
var lines  = (await multi.ReadAsync<OrderLine>()).ToLookup(l => l.OrderId);

foreach (var o in orders)
    o.Lines = lines[o.Id].ToList();
```
Two result sets, one round trip, zero N+1. The order of `ReadAsync<T>()` calls must match the order of `SELECT`s.

## Multi-mapping and `splitOn`

For a single-row-per-result join (e.g. `Order` + `Customer`):
```csharp
const string sql = @"
SELECT o.Id, o.Total, o.CustomerId,
       c.Id, c.Name, c.Email
FROM Orders o
JOIN Customers c ON c.Id = o.CustomerId
WHERE o.Id = @id";

var order = (await conn.QueryAsync<Order, Customer, Order>(
    sql,
    (o, c) => { o.Customer = c; return o; },
    new { id },
    splitOn: "Id")) // <-- Dapper splits when it sees this column NAME
    .FirstOrDefault();
```
`splitOn` **gotchas**:
- Default is `"Id"`. If both tables have `Id`, that works. If the right side's key column is named `CustomerId` or `CustId`, set `splitOn: "CustomerId"`.
- The *column order in the SELECT* matters. The left entity's columns must come first, then the split column starts the right entity.
- For 3+ entities, use a comma-separated list: `splitOn: "Id,Id"`.
- If `splitOn` is wrong, you silently get wrong mappings — the right entity ends up with null/default fields. Always test with a row that has distinguishable values.

For 1-to-many through multi-mapping (one query), deduplicate the parent in the callback:
```csharp
var lookup = new Dictionary<int, Order>();
await conn.QueryAsync<Order, OrderLine, Order>(sql, (o, l) =>
{
    if (!lookup.TryGetValue(o.Id, out var order))
        lookup.Add(o.Id, order = o);
    if (l is not null) order.Lines.Add(l);
    return order;
}, param, splitOn: "OrderLineId");
var orders = lookup.Values.ToList();
```
This works but is clunkier than `QueryMultipleAsync` for most cases — pick whichever is clearer for the shape.

## Async pitfalls

- **Never** call `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` on a Dapper task in server code. Deadlocks in sync-context frameworks (classic ASP.NET), threadpool starvation everywhere else.
- In **library** code (anything that might be called from a UI sync context), append `.ConfigureAwait(false)` to every awaited Dapper call. In application code (ASP.NET Core), it's not needed because there is no sync context.
- Do not mix sync `Query` and `ExecuteAsync` in the same method — pick one lane.
- `async void` is banned except for event handlers; a Dapper call inside `async void` will crash the process on exception.

## `CommandDefinition` and `CancellationToken`

The overloads that take simple strings do **not** accept a `CancellationToken`. Use `CommandDefinition`:
```csharp
var cmd = new CommandDefinition(
    commandText: sql,
    parameters: param,
    transaction: tx,
    commandTimeout: 30,
    commandType: CommandType.Text,
    flags: CommandFlags.Buffered,
    cancellationToken: ct);

var rows = await conn.QueryAsync<Row>(cmd);
```
Cancellation matters for long-running reports, search boxes, and any endpoint behind a client that can hang up. Without `ct`, the query runs to completion on the DB even after the HTTP request is gone.

## Plan caching and parameter sizing

SQL Server caches execution plans keyed by the exact SQL text + parameter shapes. Two traps:
1. **`varchar` size inference.** Dapper sends `string` parameters as `nvarchar(4000)` or `nvarchar(max)` by default. If your column is `varchar(50)`, you get an implicit conversion that prevents index seeks. Fix: use `DynamicParameters.Add("@email", email, DbType.AnsiString, size: 200)` or annotate via `DbString`:
   ```csharp
   new { email = new DbString { Value = email, IsAnsi = true, Length = 200 } }
   ```
2. **Parameter size churn.** `DynamicParameters.Add("@email", email, size: email.Length)` creates a new plan per length. Use a stable size (the column's declared size).

## Benchmarking tips

- Measure with BenchmarkDotNet against a real database, not mocks. Micro-ORM perf wins evaporate if the DB is the bottleneck anyway.
- For read-heavy paths, the biggest wins are usually: reducing round trips, fixing implicit conversions (column type mismatch), and returning less data (projection to a DTO instead of `SELECT *`).
- Dapper itself is rarely the bottleneck. If a profiler points at `SqlMapper`, look at row count, column count, and how many times you're calling it per request.

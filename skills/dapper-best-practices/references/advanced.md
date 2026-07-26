<!-- last-verified: 2026-07-26 -->
# Advanced: Contrib, Bulk, Stored Procedures, TVP, JSON, Providers

Reference for rules 9, 10 in SKILL.md. Read this when the task goes beyond plain CRUD — bulk inserts, stored procedures with output parameters, table-valued parameters, JSON columns, or non-SQL Server providers.

## Table of contents
- [Dapper.Contrib: when and when not](#dappercontrib-when-and-when-not)
- [Bulk insert strategies](#bulk-insert-strategies)
- [Stored procedures](#stored-procedures)
- [Table-Valued Parameters (TVP)](#table-valued-parameters-tvp)
- [JSON columns](#json-columns)
- [Custom type handlers](#custom-type-handlers)
- [Dapper.AOT: when to reach for it](#dapperaot-when-to-reach-for-it)
- [Provider-specific notes](#provider-specific-notes)

## Dapper.Contrib: when and when not

`Dapper.Contrib` adds `Insert<T>`, `Update<T>`, `Delete<T>`, `Get<T>`, `GetAll<T>` extension methods on `IDbConnection` based on attribute conventions:

It is a separately versioned package and repository, not part of Dapper core's
API surface. Before introducing it, check its current NuGet release, repository
activity, target frameworks, and provider issues. Existing use can remain when
the mapping fits; do not expand adoption solely to shorten straightforward
parameterized SQL.

Source: https://github.com/DapperLib/Dapper.Contrib

```csharp
[Table("Users")]
public class User
{
    [Key] public int Id { get; set; }
    public string Email { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    [Computed] public string? FullName { get; set; } // read-only column
}

var id = await conn.InsertAsync(user);
await conn.UpdateAsync(user);
await conn.DeleteAsync(user);
var u = await conn.GetAsync<User>(id);
```

Use Contrib when:
- The table is simple CRUD, one-row-at-a-time.
- You already have a POCO that maps 1:1 to the table.
- You value brevity over a custom query.

Do **not** use Contrib when:
- You need to update only some columns (Contrib updates all).
- You need `WHERE` conditions beyond primary key.
- You need joins, aggregates, or any non-trivial SQL.
- Performance is critical — Contrib does more reflection than hand-written SQL.

Contrib doesn't cover queries. For `SELECT ... WHERE Email = @email`, write plain Dapper. Mixing Contrib and plain Dapper in the same repository is normal and expected.

## Bulk insert strategies

Rank ordered from fastest to slowest for SQL Server:

### 1. `SqlBulkCopy` + `FastMember` (SQL Server, best)
```csharp
using Dapper;
using FastMember;
using Microsoft.Data.SqlClient;

public async Task BulkInsertOrdersAsync(IReadOnlyList<Order> orders, CancellationToken ct)
{
    await using var conn = (SqlConnection)_factory.Create();
    await conn.OpenAsync(ct);

    using var bulk = new SqlBulkCopy(conn)
    {
        DestinationTableName = "dbo.Orders",
        BatchSize = 5_000,
        BulkCopyTimeout = 60,
    };
    bulk.ColumnMappings.Add(nameof(Order.Id),         "Id");
    bulk.ColumnMappings.Add(nameof(Order.CustomerId), "CustomerId");
    bulk.ColumnMappings.Add(nameof(Order.Total),      "Total");
    bulk.ColumnMappings.Add(nameof(Order.CreatedAt),  "CreatedAt");

    using var reader = ObjectReader.Create(orders,
        nameof(Order.Id), nameof(Order.CustomerId), nameof(Order.Total), nameof(Order.CreatedAt));

    await bulk.WriteToServerAsync(reader, ct);
}
```
Typical: 10–100× faster than looped `ExecuteAsync` for 1k+ rows.

### 2. Table-Valued Parameter + stored procedure
See [TVP section](#table-valued-parameters-tvp). One round trip, set-based insert. Good when you want the logic on the server side or need to combine insert with other set operations.

### 3. Single `INSERT` with multiple `VALUES` rows
```csharp
INSERT INTO Orders (Id, CustomerId, Total) VALUES (@Id0, @Cust0, @Tot0), (@Id1, @Cust1, @Tot1), ...
```
Build the SQL and parameter bag dynamically. Practical up to ~1000 rows per batch (watch SQL Server's 2100-parameter limit). Simpler than TVP if you don't have a type on the server.

### 4. `Dapper.Plus` (commercial)
Third-party library with `BulkInsert`, `BulkUpdate`, `BulkMerge`. Convenient but not free — evaluate license before adopting.

### What NOT to do
```csharp
// BAD: one round trip per row — 5000 rows = 5000 round trips
foreach (var o in orders)
    await conn.ExecuteAsync("INSERT INTO Orders ... VALUES (@Id, @CustomerId, ...)", o);
```
This is the single most common Dapper perf bug. Flag it on review and suggest `SqlBulkCopy`.

## Stored procedures

```csharp
var p = new DynamicParameters();
p.Add("@email", email, DbType.String, size: 200);
p.Add("@newUserId", dbType: DbType.Int64, direction: ParameterDirection.Output);
p.Add("@returnValue", dbType: DbType.Int32, direction: ParameterDirection.ReturnValue);

await conn.ExecuteAsync(new CommandDefinition(
    "dbo.CreateUser",
    p,
    commandType: CommandType.StoredProcedure,
    cancellationToken: ct));

var newUserId = p.Get<long>("@newUserId");
var rc = p.Get<int>("@returnValue");
```

Gotchas:
- **Always** pass `commandType: CommandType.StoredProcedure`. Without it, Dapper sends `dbo.CreateUser` as literal SQL text and the server errors (or worse, runs something unintended).
- Read output/return values **after** the call, not before — they are only populated once the reader is closed.
- A proc that returns a result set: use `QueryAsync<T>` with `commandType: CommandType.StoredProcedure`. Output parameters still work alongside result sets as long as you fully read the result before calling `p.Get<T>()`.
- Procs that return multiple result sets: `QueryMultipleAsync` with `CommandType.StoredProcedure`.

## Table-Valued Parameters (TVP)

SQL Server only. Create a user-defined type first:
```sql
CREATE TYPE dbo.IdList AS TABLE (Id BIGINT NOT NULL PRIMARY KEY);
```
Then pass a `DataTable` via `DynamicParameters`:
```csharp
var table = new DataTable();
table.Columns.Add("Id", typeof(long));
foreach (var id in ids) table.Rows.Add(id);

var p = new DynamicParameters();
p.Add("@ids", table.AsTableValuedParameter("dbo.IdList"));

var users = await conn.QueryAsync<User>(
    "SELECT u.* FROM Users u JOIN @ids i ON i.Id = u.Id",
    p);
```
TVPs are the right answer for:
- Large `IN` lists (beyond Dapper's list expansion / parameter-limit comfort zone).
- Passing structured batches into a stored procedure.
- Bulk upserts via `MERGE @tvp`.

## JSON columns

### SQL Server (JSON stored as `nvarchar(max)`)
```csharp
// Write
await conn.ExecuteAsync(
    "UPDATE Documents SET Payload = @json WHERE Id = @id",
    new { id, json = JsonSerializer.Serialize(dto) });

// Read
var raw = await conn.QueryFirstOrDefaultAsync<string>(
    "SELECT Payload FROM Documents WHERE Id = @id", new { id });
var dto = raw is null ? null : JsonSerializer.Deserialize<Dto>(raw);
```
For queries over JSON properties, use server-side functions:
```sql
SELECT * FROM Documents
WHERE JSON_VALUE(Payload, '$.status') = @status
```

### PostgreSQL (`jsonb`)
Npgsql maps `jsonb` to `string` or to any type via `JsonSerializer`. Register a custom type handler (next section) if you want Dapper to materialize directly into a POCO.

## Custom type handlers

For types Dapper doesn't know about (value objects, enums stored as strings, domain IDs):
```csharp
public sealed class UserIdHandler : SqlMapper.TypeHandler<UserId>
{
    public override UserId Parse(object value) => new((long)value);
    public override void SetValue(IDbDataParameter parameter, UserId value)
    {
        parameter.DbType = DbType.Int64;
        parameter.Value = value.Value;
    }
}

// Once, at startup:
SqlMapper.AddTypeHandler(new UserIdHandler());
```
Register handlers in a single bootstrap path (e.g. a `DapperConfiguration` class called from `Program.cs`), not scattered across repositories. Registering twice is a silent no-op for the same type but a code-smell signal that the bootstrap isn't centralized.

## Dapper.AOT: when to reach for it

Plain Dapper materializes rows by emitting IL at runtime (`GetDeserializer`). That breaks under NativeAOT and trimming, and costs a first-call warmup per query shape.

`Dapper.AOT` is a separate build-time package that uses C# interceptors to replace your Dapper call sites with generated, ahead-of-time compiled code — same source, no runtime reflection. It also surfaces analyzer diagnostics for incorrect Dapper usage.

Use it when:
- Publishing NativeAOT or trimmed.
- Per-query-shape warmup cost is visible in the profile.
- You want compile-time diagnostics on your Dapper calls.

Skip it when: a normally JIT-hosted service where reflection warmup never shows up in a profile — it is an extra package and an extra build step, not a default.

## Provider-specific notes

### PostgreSQL (Npgsql)
- Parameter prefix `@name` works.
- Case sensitivity: unquoted identifiers are lowercased. `SELECT "Id"` vs `SELECT id` matters — match what your migrations created.
- `DateTime` handling changed in Npgsql 6+: `DateTime.Kind == Unspecified` no longer binds to `timestamptz` automatically. Use `DateTimeOffset` or set `Npgsql.EnableLegacyTimestampBehavior`.
- Bulk insert: use Npgsql's `BeginBinaryImport` (COPY) — much faster than row-by-row.

### SQLite
- No `SqlBulkCopy`. Wrap bulk inserts in a single transaction to avoid per-row fsync; that alone is 100× faster.
- `WAL` journal mode improves concurrent read/write.

### MySQL / MariaDB
- `MySqlConnector` is the maintained driver (not `MySql.Data`). Supports `BulkCopyAsync`.
- Backtick identifiers: `` `Users` ``. Dapper just passes SQL through — you write the dialect.

### Oracle
- Parameter prefix `:name`.
- Use `Oracle.ManagedDataAccess.Core` — bind by name (`BindByName = true`) or positional binding will bite you when the same parameter appears twice.

### Dapper does not insulate you from dialect
Dapper is not an ORM — it will not rewrite `TOP` to `LIMIT` or `GETDATE()` to `NOW()`. Write SQL for the provider you're targeting, and if you support multiple providers, keep SQL in dialect-specific files or use a query builder on top.

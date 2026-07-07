# Core CRUD & Parameterization Safety

Reference for rules 1, 5, 9, 11 in SKILL.md. Read this when writing a new query or when you need to explain how Dapper binds parameters.

## Table of contents
- [Method cheat sheet](#method-cheat-sheet)
- [Parameterization: the three forms](#parameterization-the-three-forms)
- [SQL injection: what NOT to do](#sql-injection-what-not-to-do)
- [`IN (@ids)` list expansion](#in-ids-list-expansion)
- [`LIKE` and wildcard escaping](#like-and-wildcard-escaping)
- [`DynamicParameters` deep dive](#dynamicparameters-deep-dive)
- [Nullable parameters and `DBNull`](#nullable-parameters-and-dbnull)
- [Provider-specific parameter prefixes](#provider-specific-parameter-prefixes)

## Method cheat sheet

| Need | Method | Returns | Notes |
|---|---|---|---|
| 0..N rows → collection | `QueryAsync<T>` | `IEnumerable<T>` (buffered `List<T>` by default) | Default choice for reads. |
| 0 or 1 row | `QueryFirstOrDefaultAsync<T>` | `T?` | No exception on empty. Prefer when result is optional. |
| Exactly 1 row | `QuerySingleAsync<T>` | `T` | Throws on 0 or >1. Use for invariants ("user must exist"). |
| 1 row expected, might be 0 | `QuerySingleOrDefaultAsync<T>` | `T?` | Throws on >1, returns null on 0. |
| Single scalar | `ExecuteScalarAsync<T>` | `T` | `COUNT(*)`, `SELECT @@IDENTITY`, aggregates. |
| INSERT/UPDATE/DELETE | `ExecuteAsync` | `int` (rows affected) | Always capture and assert if caller cares. |
| Multiple result sets | `QueryMultipleAsync` | `GridReader` | Call `ReadAsync<T>()` per set, in order. |
| Multi-mapping (joins) | `QueryAsync<T1, T2, TResult>` | `IEnumerable<TResult>` | Requires `splitOn:`. |

`Query`, `Execute`, `QueryFirstOrDefault` etc. (non-async) exist — **do not use them in async code paths**. They block threads.

## Parameterization: the three forms

### 1. Anonymous object (simplest, most common)
```csharp
var user = await conn.QueryFirstOrDefaultAsync<User>(
    "SELECT Id, Email, CreatedAt FROM Users WHERE Email = @email",
    new { email });
```
Dapper maps each property of the anonymous object to a parameter of the same name. Property order does not matter. Extra properties are ignored; missing ones throw at execution.

### 2. POCO / existing model
```csharp
await conn.ExecuteAsync(
    "INSERT INTO Users (Id, Email, CreatedAt) VALUES (@Id, @Email, @CreatedAt)",
    user); // user is a User with matching property names
```
Useful when you already have the object. Be careful: if the POCO has extra properties Dapper doesn't care, but if SQL references a name that's missing, you get a runtime error.

### 3. `DynamicParameters` (when you need more control)
```csharp
var p = new DynamicParameters();
p.Add("@email", email, DbType.String, size: 200);
p.Add("@isActive", true, DbType.Boolean);
p.Add("@newId", dbType: DbType.Int64, direction: ParameterDirection.Output);

await conn.ExecuteAsync(
    "INSERT INTO Users (Email, IsActive) OUTPUT INSERTED.Id INTO @newId VALUES (@email, @isActive)",
    p);

var newId = p.Get<long>("@newId");
```
Use when you need: explicit `DbType`, output/return direction, size hints (avoid varchar(8000) for short strings), or when building parameters conditionally.

## SQL injection: what NOT to do

Every one of these is a security bug. Flag with HIGH severity on review.

```csharp
// BAD: string concatenation
conn.Query<User>("SELECT * FROM Users WHERE Email = '" + email + "'");

// BAD: string interpolation — same thing, prettier syntax, identical risk
conn.Query<User>($"SELECT * FROM Users WHERE Email = '{email}'");

// BAD: string.Format
conn.Query<User>(string.Format("SELECT * FROM Users WHERE Id = {0}", id));

// BAD: StringBuilder
var sb = new StringBuilder("SELECT * FROM Users WHERE 1=1");
if (!string.IsNullOrEmpty(email)) sb.Append($" AND Email = '{email}'");
conn.Query<User>(sb.ToString());
```

Even `int` parameters interpolated into SQL are bad practice — they bypass plan caching and normalize to the same parameterized habit anyway.

The **dynamic WHERE** case is where people cheat most often. Do it correctly:
```csharp
var sql = new StringBuilder("SELECT * FROM Users WHERE 1=1");
var p = new DynamicParameters();
if (!string.IsNullOrEmpty(email)) { sql.Append(" AND Email = @email"); p.Add("@email", email); }
if (minAge is not null)          { sql.Append(" AND Age >= @minAge"); p.Add("@minAge", minAge); }

var users = await conn.QueryAsync<User>(sql.ToString(), p);
```
Identifiers (table/column names) **cannot** be parameterized by any DB. If you must inject an identifier, validate against an allow-list *before* concatenating:
```csharp
static readonly HashSet<string> AllowedSortColumns = new(StringComparer.OrdinalIgnoreCase)
    { "Email", "CreatedAt", "LastLogin" };

if (!AllowedSortColumns.Contains(sortBy))
    throw new ArgumentException($"Invalid sort column: {sortBy}");

var sql = $"SELECT * FROM Users ORDER BY {sortBy}"; // safe because allow-listed
```

## `IN (@ids)` list expansion

Dapper automatically expands a collection parameter into a parameter list:
```csharp
var ids = new[] { 1, 2, 3 };
var users = await conn.QueryAsync<User>(
    "SELECT * FROM Users WHERE Id IN @ids",
    new { ids });
// Sent as: SELECT * FROM Users WHERE Id IN (@ids1, @ids2, @ids3)
```
Notes:
- Do **not** write `IN (@ids)` with parentheses — Dapper adds them.
- An empty collection expands to `IN (SELECT NULL WHERE 1=0)` — safe, returns no rows.
- Large lists (thousands) hit parameter limits (SQL Server ~2100). For huge batches, use a TVP or a temp table instead (`references/advanced.md`).

## `LIKE` and wildcard escaping

```csharp
// GOOD: build the pattern in C#, pass as parameter
var pattern = $"%{EscapeLike(search)}%";
var users = await conn.QueryAsync<User>(
    "SELECT * FROM Users WHERE Email LIKE @pattern ESCAPE '\\'",
    new { pattern });

static string EscapeLike(string input) =>
    input.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_").Replace("[", "\\[");
```
Without escaping, a user typing `%` or `_` turns your exact filter into a wildcard search — annoying, and in some schemas it's a data-leak vector.

## `DynamicParameters` deep dive

- `Add(name, value, dbType?, direction?, size?, precision?, scale?)` — full control.
- `AddDynamicParams(object)` — merges another anonymous object or POCO into the bag. Handy for mixing a base set of params with conditional extras.
- `Get<T>(name)` — must be called **after** the Dapper call has executed. Reading before the call (or using `Query` which defers) gives you the default value, not the output.
- Output parameters + `buffered: false` do not mix — the output is only set after the reader is consumed.

## Nullable parameters and `DBNull`

Dapper converts C# `null` to `DBNull.Value` automatically — you do **not** need to write `value ?? (object)DBNull.Value`. That pattern you see in old ADO.NET code is obsolete here.

One exception: when using `DynamicParameters.Add` with an explicit `DbType` and a null value, be sure the column is nullable in the DB — Dapper will happily send `NULL` and let the server throw.

## Provider-specific parameter prefixes

Dapper accepts any of `@name`, `:name`, or `?` in your SQL and picks the right prefix at execution time based on the provider — but **be consistent within a file**. Practical guidance:

| Provider | Convention |
|---|---|
| SQL Server (`SqlConnection`) | `@name` |
| PostgreSQL (`NpgsqlConnection`) | `@name` (Npgsql accepts `@`) |
| Oracle (`OracleConnection`) | `:name` |
| SQLite (`SqliteConnection`) | `@name` or `$name` |
| MySQL (`MySqlConnection`) | `@name` |

Parameter *names* in Dapper are matched case-insensitively against the property names on your parameter object.

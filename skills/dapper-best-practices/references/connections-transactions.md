# Connections & Transactions

Reference for rules 2, 4, 7, 8 in SKILL.md. Read this when designing a repository/DAL layer, debugging a connection leak, or laying out a unit-of-work.

## Table of contents
- [The connection pool and why it matters](#the-connection-pool-and-why-it-matters)
- [`IDbConnectionFactory` pattern](#idbconnectionfactory-pattern)
- [DI lifetimes: what to register as what](#di-lifetimes-what-to-register-as-what)
- [The `return IEnumerable` from `using` trap](#the-return-ienumerable-from-using-trap)
- [`IDbTransaction` usage](#idbtransaction-usage)
- [`TransactionScope` vs `IDbTransaction`](#transactionscope-vs-idbtransaction)
- [Unit of work sketch](#unit-of-work-sketch)
- [Debugging connection leaks](#debugging-connection-leaks)

## The connection pool and why it matters

`SqlConnection` (and peers) are cheap to instantiate because ADO.NET maintains a pool keyed by connection string. `conn.Open()` pulls an idle connection from the pool; `conn.Dispose()` returns it. The actual TCP/TLS handshake only happens when the pool is empty and has to grow.

This is why the correct pattern is **open a connection, use it, dispose it**, for every logical operation. Holding a connection open across the lifetime of a class defeats the pool and creates leaks: if the class lives as a singleton, you've just bottlenecked your entire service on one socket.

## `IDbConnectionFactory` pattern

```csharp
public interface IDbConnectionFactory
{
    DbConnection Create();            // closed connection — caller opens + disposes
}

public sealed class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;
    public SqlConnectionFactory(IOptions<DbOptions> opt) => _connectionString = opt.Value.ConnectionString;
    public DbConnection Create() => new SqlConnection(_connectionString);
}
```

Repository usage:
```csharp
public sealed class UserRepository
{
    private readonly IDbConnectionFactory _factory;
    public UserRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<User?> GetByEmailAsync(string email, CancellationToken ct)
    {
        await using var conn = _factory.Create();
        await conn.OpenAsync(ct);
        return await conn.QueryFirstOrDefaultAsync<User>(
            new CommandDefinition(
                "SELECT Id, Email, CreatedAt FROM Users WHERE Email = @email",
                new { email },
                cancellationToken: ct));
    }
}
```
Key points:
- One connection per public method call.
- `await using` disposes on every exit path.
- `OpenAsync(ct)` — open is I/O too.
- No fields of type `IDbConnection` on the repository.

## DI lifetimes: what to register as what

| Thing | Lifetime | Why |
|---|---|---|
| `IDbConnectionFactory` | Singleton | It's just a connection-string holder — stateless. |
| `IDbConnection` directly | **Do not register** | Forces a lifetime decision that should live in the caller. |
| Repositories (`UserRepository`, etc.) | Scoped | Matches the request scope; safe to take request-scoped things as dependencies. |
| Unit of work / `IDbTransaction` holder | Scoped | One transaction per request at most. |

Red flag on review: `services.AddScoped<IDbConnection>(sp => new SqlConnection(cs));` — this forces every repository in the request to share one connection and encourages storing it as a field.

## The `return IEnumerable` from `using` trap

```csharp
// BAD
public IEnumerable<User> GetAll()
{
    using var conn = _factory.Create();
    conn.Open();
    return conn.Query<User>("SELECT * FROM Users", buffered: false);
    // conn is disposed here — the returned IEnumerable is already toxic
}
```
When the caller iterates, Dapper tries to read from a disposed connection. Three correct fixes:

1. **Buffer (simplest).** Remove `buffered: false` — `Query<User>` returns `List<User>` materialized before the method exits.
2. **Materialize explicitly.**
   ```csharp
   return conn.Query<User>(sql).ToList();
   ```
3. **Return `IAsyncEnumerable` and own the connection in the enumerator** (see `performance.md`).

Same trap shows up with `yield return` inside a `using`: that works (the compiler keeps the connection alive for the enumerator), but only for the sync `Query` path and only if the caller iterates to completion. Usually not worth the subtlety.

## `IDbTransaction` usage

```csharp
public async Task TransferAsync(int fromId, int toId, decimal amount, CancellationToken ct)
{
    await using var conn = _factory.Create();
    await conn.OpenAsync(ct);
    await using var tx = await conn.BeginTransactionAsync(ct);

    try
    {
        var debited = await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE Accounts SET Balance = Balance - @amount WHERE Id = @id AND Balance >= @amount",
            new { amount, id = fromId },
            transaction: tx, cancellationToken: ct));

        if (debited != 1)
            throw new InvalidOperationException("Insufficient funds");

        await conn.ExecuteAsync(new CommandDefinition(
            "UPDATE Accounts SET Balance = Balance + @amount WHERE Id = @id",
            new { amount, id = toId },
            transaction: tx, cancellationToken: ct));

        await tx.CommitAsync(ct);
    }
    catch
    {
        await tx.RollbackAsync(ct);
        throw;
    }
}
```
Points to check on review:
- Every Dapper call inside the `try` passes `transaction: tx`. Forget one and it runs on the connection's default transaction (i.e. auto-committed), silently breaking atomicity.
- On .NET 6+, use `BeginTransactionAsync` / `CommitAsync` / `RollbackAsync` — the sync versions block.
- The `await using` on `tx` handles rollback on uncaught exceptions automatically — the explicit `catch { rollback; throw; }` is for readability; you can rely on the `using` alone if you prefer.
- Use an **isolation level** explicitly when you need to: `BeginTransactionAsync(IsolationLevel.Serializable, ct)`. Default is usually `ReadCommitted`.

## `TransactionScope` vs `IDbTransaction`

- `IDbTransaction` (what we did above): one connection, one DB, no distributed transaction. Simple, fast, works everywhere. **Preferred default.**
- `TransactionScope`: ambient transaction, enlists any connection opened inside the scope. Can escalate to MSDTC if two different connection strings are opened. In .NET Core/5+, MSDTC support is limited; escalation is a common footgun.
  - Use only when you genuinely need to coordinate across multiple `DbConnection`s in one atomic unit and you know MSDTC is available.
  - With `TransactionScope`, remember `TransactionScopeAsyncFlowOption.Enabled` or it won't flow across `await`:
    ```csharp
    using var scope = new TransactionScope(
        TransactionScopeOption.Required,
        new TransactionOptions { IsolationLevel = IsolationLevel.ReadCommitted },
        TransactionScopeAsyncFlowOption.Enabled);
    // ... Dapper calls ...
    scope.Complete();
    ```

## Unit of work sketch

A lightweight UoW shares one connection + transaction across multiple repositories within a single business operation:
```csharp
public sealed class DbSession : IAsyncDisposable
{
    public DbConnection Connection { get; }
    public DbTransaction? Transaction { get; private set; }

    public DbSession(IDbConnectionFactory factory) => Connection = factory.Create();

    public async Task OpenAsync(CancellationToken ct) => await Connection.OpenAsync(ct);

    public async Task BeginAsync(CancellationToken ct) =>
        Transaction = await Connection.BeginTransactionAsync(ct);

    public Task CommitAsync(CancellationToken ct) => Transaction!.CommitAsync(ct).AsTask();
    public Task RollbackAsync(CancellationToken ct) => Transaction!.RollbackAsync(ct).AsTask();

    public async ValueTask DisposeAsync()
    {
        if (Transaction is not null) await Transaction.DisposeAsync();
        await Connection.DisposeAsync();
    }
}
```
Repositories take `DbSession` (scoped in DI), use `session.Connection` and `session.Transaction`. The service layer decides when to `BeginAsync` / `CommitAsync`.

This is optional — for most CRUD services, one transaction per repository method is fine. Reach for a UoW only when you actually need cross-repo atomicity.

## Debugging connection leaks

Symptoms: `InvalidOperationException: Timeout expired. The timeout period elapsed prior to obtaining a connection from the pool` under load.

Checklist:
1. Search for `new SqlConnection` not immediately inside `using` / `await using`.
2. Search for `IDbConnection` / `DbConnection` fields on classes — especially singletons.
3. Search for methods returning `IEnumerable<T>` from within a `using` block (the trap above).
4. Search for `Query<T>(..., buffered: false)` outside a `using`.
5. Check for exception paths that skip `Dispose` — `await using` handles this; manual `try/finally` might not.
6. Enable ADO.NET connection pool statistics or SQL Server `sys.dm_exec_sessions` to count active sessions under a reproduction run.

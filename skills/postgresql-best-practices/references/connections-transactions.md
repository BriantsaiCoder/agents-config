<!-- last-verified: 2026-07-26 -->
# PostgreSQL Connections and Transactions

## Npgsql Connection String Settings

Key connection string parameters for `NpgsqlConnection`:

| Parameter | Default | Notes |
|-----------|---------|-------|
| `Host` | (required) | Server hostname or IP. Multiple hosts for failover: `host1,host2` |
| `Port` | 5432 | PostgreSQL port |
| `Database` | (required) | Database name |
| `Username` | (required) | Login role |
| `Password` | (required) | Password |
| `Minimum Pool Size` | 0 | Connections kept open when idle |
| `Maximum Pool Size` | 100 | Hard cap on connections from this pool |
| `Connection Idle Lifetime` | 300 (sec) | Close idle connections after this time |
| `Connection Pruning Interval` | 10 (sec) | How often to check for idle connections to prune |
| `Keepalive` | 0 (disabled) | TCP keepalive interval in seconds; set to 60 for long-lived connections behind firewalls |
| `Timeout` | 15 (sec) | Time to wait for a connection from the pool |
| `Command Timeout` | 30 (sec) | Default timeout for commands (0 = infinite) |
| `SSL Mode` | Prefer | Options: `Disable`, `Allow`, `Prefer`, `Require`, `VerifyCA`, `VerifyFull` |
| `Trust Server Certificate` | false | Set to true for self-signed certs in dev only |
| `Multiplexing` | false | Npgsql 6+; see below |
| `No Reset On Close` | false | Required when using PgBouncer transaction pooling |

Example connection string:

```
Host=db.example.com;Port=5432;Database=myapp;Username=app_user;Password=secret;Maximum Pool Size=50;Keepalive=60;SSL Mode=Require;
```

## Npgsql Multiplexing Mode

Npgsql 6+ introduces multiplexing, which sends commands from multiple async callers over a single physical connection:

- **What it does:** Multiple concurrent `QueryAsync` calls share fewer physical connections. Npgsql batches commands and pipelines them over the wire.
- **When to use:** High-concurrency web apps with many short queries. Reduces the number of physical connections needed.
- **Connection vs command:** With multiplexing, you are not "holding" a connection while awaiting a query. The physical connection is shared.
- **Limitations:** Not compatible with: prepared statements (by default), cursors, `LISTEN/NOTIFY`, `COPY`, or anything that requires exclusive connection state. Transactions work but hold a connection for the transaction duration.

```
Host=db.example.com;Database=myapp;Username=app;Password=secret;Multiplexing=true;
```

## Dapper Integration Pattern with Npgsql

Npgsql 7+ uses one thread-safe `NpgsqlDataSource` per database/pool. Register it
through `Npgsql.DependencyInjection`, then open and dispose a logical connection
per operation.

```csharp
var connectionString = builder.Configuration.GetConnectionString("PostgreSQL")
    ?? throw new InvalidOperationException("PostgreSQL connection string not configured.");

builder.Services.AddNpgsqlDataSource(connectionString);

// In a repository
public class OrderRepository
{
    private readonly NpgsqlDataSource _dataSource;

    public OrderRepository(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<Order?> GetByIdAsync(long id, CancellationToken ct)
    {
        await using var conn = await _dataSource.OpenConnectionAsync(ct);
        var cmd = new CommandDefinition(
            "SELECT id, customer_id, total, created_at FROM orders WHERE id = @Id",
            new { Id = id },
            cancellationToken: ct);
        return await conn.QueryFirstOrDefaultAsync<Order>(cmd);
    }
}
```

`NpgsqlDataSource` owns the pool; disposing a connection returns its physical
connection to that pool. Do not hold a scoped connection for the lifetime of an
HTTP request.

References:

- https://www.npgsql.org/doc/basic-usage.html
- https://www.npgsql.org/doc/diagnostics/logging.html

## PgBouncer

### Why PgBouncer?

PostgreSQL forks a new OS process per connection (~10 MB RSS each). With 200+ connections, this becomes a significant memory and context-switching cost. PgBouncer sits between the app and PostgreSQL, multiplexing many client connections onto fewer server connections.

### Pooling Modes

| Mode | Description | Npgsql Compatibility |
|------|-------------|---------------------|
| **Transaction** | Connection returned to pool after each transaction | Best for web apps; add `No Reset On Close=true` to Npgsql |
| **Session** | Connection held for the entire client session | Full compatibility, less pooling benefit |
| **Statement** | Connection returned after each statement | Most restrictive; multi-statement transactions break |

### Npgsql Configuration for PgBouncer

```
Host=pgbouncer.example.com;Port=6432;Database=myapp;Username=app;Password=secret;No Reset On Close=true;Enlist=false;
```

**Key settings:**
- `No Reset On Close=true`: Prevents Npgsql from sending `RESET ALL` / `DISCARD ALL` when returning a connection to the pool, which confuses PgBouncer.
- `Enlist=false`: Disables automatic `TransactionScope` enlistment which does not work with PgBouncer transaction pooling.
- Prepared statements: Npgsql's automatic preparation is incompatible with PgBouncer transaction mode (prepared statements are per-server-connection). Disable with `Max Auto Prepare=0` or use PgBouncer 1.21+ with prepared statement support.

### When to Use PgBouncer vs Npgsql Internal Pool

- **Npgsql pool only:** Single .NET application, moderate concurrency (<100 connections). Simpler topology.
- **PgBouncer:** Multiple applications (different languages/services) sharing one PostgreSQL instance, very high concurrency, or when PostgreSQL `max_connections` is the bottleneck.

## Node.js pg Pool Configuration

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.example.com',
  port: 5432,
  database: 'myapp',
  user: 'app_user',
  password: process.env.DB_PASSWORD,
  max: 20,                    // Maximum connections in pool
  min: 2,                     // Minimum idle connections
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 5000, // Fail if no connection in 5s
  allowExitOnIdle: true,      // Allow process to exit when pool is idle
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/ca.pem'),
  },
});

// Handle pool errors (idle client errors)
pool.on('error', (err) => {
  console.error('Unexpected pool error', err);
  // Do NOT crash; the pool will remove the broken client
});
```

### pool.query() vs Client Checkout

```javascript
// Simple queries: use pool.query() (auto-checkout and return)
const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);

// Transactions or multi-statement: checkout a client
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromId]);
  await client.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toId]);
  await client.query('COMMIT');
} catch (e) {
  await client.query('ROLLBACK');
  throw e;
} finally {
  client.release();  // ALWAYS release back to pool
}
```

**Critical:** Always call `client.release()` in a `finally` block. A leaked client exhausts the pool.

## Isolation Levels

| Level | Behavior | Use Case |
|-------|----------|----------|
| `READ COMMITTED` | Each statement sees committed data as of statement start | Default; suitable for most OLTP |
| `REPEATABLE READ` | Transaction sees snapshot as of first query | Reports, consistent reads across multiple queries |
| `SERIALIZABLE` | True serializability via SSI (Serializable Snapshot Isolation) | Financial transactions, inventory where correctness > throughput |

**Note:** PostgreSQL's `READ COMMITTED` is different from MySQL's. In PostgreSQL, each *statement* in a READ COMMITTED transaction sees the latest committed data, which means concurrent updates can cause non-repeatable reads within a transaction.

```sql
-- Set isolation level (must be first statement in transaction)
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- or
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

## Serialization Failure Retry Pattern

When using `REPEATABLE READ` or `SERIALIZABLE`, PostgreSQL may abort a transaction with SQLSTATE `40001` (serialization_failure). **This is expected behavior, not a bug.** The application must retry.

### C# Retry Pattern

```csharp
public async Task<T> ExecuteWithRetryAsync<T>(
    Func<NpgsqlConnection, Task<T>> operation,
    int maxRetries = 3,
    CancellationToken ct = default)
{
    var delay = TimeSpan.FromMilliseconds(50);

    for (int attempt = 0; ; attempt++)
    {
        await using var conn = _factory.Create();
        await conn.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(IsolationLevel.Serializable, ct);

        try
        {
            var result = await operation(conn);
            await tx.CommitAsync(ct);
            return result;
        }
        catch (PostgresException ex) when (ex.SqlState == "40001" && attempt < maxRetries)
        {
            // Serialization failure — retry with backoff
            await Task.Delay(delay, ct);
            delay *= 2; // exponential backoff
        }
    }
}
```

### Node.js Retry Pattern

```javascript
async function executeWithRetry(pool, operation, maxRetries = 3) {
  let delay = 50;

  for (let attempt = 0; ; attempt++) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN ISOLATION LEVEL SERIALIZABLE');
      const result = await operation(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      if (err.code === '40001' && attempt < maxRetries) {
        await new Promise(r => setTimeout(r, delay));
        delay *= 2;
        continue;
      }
      throw err;
    } finally {
      client.release();
    }
  }
}
```

## Advisory Locks

PostgreSQL advisory locks are application-level cooperative locks that do not lock any table or row:

```sql
-- Session-level: held until explicitly released or session ends
SELECT pg_advisory_lock(12345);         -- blocks until acquired
SELECT pg_try_advisory_lock(12345);     -- non-blocking, returns true/false
SELECT pg_advisory_unlock(12345);       -- release

-- Transaction-level: released at end of transaction
SELECT pg_advisory_xact_lock(12345);    -- blocks until acquired
SELECT pg_try_advisory_xact_lock(12345); -- non-blocking
-- No explicit unlock needed; released on COMMIT/ROLLBACK
```

**Use cases:**
- Job queue deduplication: lock on job ID before processing.
- Distributed coordination: ensure only one worker runs a migration or cron task.
- Custom resource locking: lock on a hash of a resource identifier.

```csharp
// C# example: advisory lock for job dedup
await using var conn = _factory.Create();
await conn.OpenAsync(ct);
var acquired = await conn.ExecuteScalarAsync<bool>(
    "SELECT pg_try_advisory_lock(@LockId)",
    new { LockId = jobId.GetHashCode() });

if (!acquired) return; // another worker has this job

try
{
    // Process the job
}
finally
{
    await conn.ExecuteAsync("SELECT pg_advisory_unlock(@LockId)",
        new { LockId = jobId.GetHashCode() });
}
```

## Npgsql 6+ DateTime Breaking Changes

Npgsql 6 introduced strict `timestamp` vs `timestamptz` mapping based on `DateTime.Kind`:

| DateTime.Kind | Maps to | Notes |
|---------------|---------|-------|
| `Utc` | `timestamptz` | Correct for wall-clock times |
| `Unspecified` | `timestamp` (without tz) | For abstract/local times only |
| `Local` | **Rejected** | Throws; ambiguous |

### Migration Strategies

**Option 1: Switch to `DateTimeOffset` (Recommended)**

`DateTimeOffset` always maps to `timestamptz` cleanly. No ambiguity.

```csharp
public class AuditLog
{
    public long Id { get; set; }
    public DateTimeOffset CreatedAt { get; set; }  // maps to timestamptz
}
```

**Option 2: Use Npgsql NodaTime Plugin**

The NodaTime types (`Instant`, `LocalDateTime`, `ZonedDateTime`) are unambiguous and map correctly.

```csharp
// In connection string or data source builder
var dataSource = new NpgsqlDataSourceBuilder(connectionString)
    .UseNodaTime()
    .Build();
```

**Option 3: Legacy Escape Hatch**

For existing codebases that cannot migrate immediately:

```csharp
// In Program.cs or startup, before any Npgsql usage
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
```

This restores pre-6.0 behavior where `DateTime` of any `Kind` can be sent to `timestamptz`. **Use only as a temporary migration aid.**

## Node.js pg Date Handling

By default, `pg` parses `timestamptz` to JavaScript `Date` objects and `timestamp` (without tz) as if it were local time, which can cause timezone bugs.

### Custom Type Parsers

```javascript
const types = require('pg').types;

// Parse TIMESTAMPTZ as raw string (avoid JS Date timezone issues)
types.setTypeParser(types.builtins.TIMESTAMPTZ, (val) => val);

// Parse NUMERIC as float (default is string to preserve precision)
types.setTypeParser(types.builtins.NUMERIC, parseFloat);

// Parse BIGINT as BigInt instead of string
types.setTypeParser(types.builtins.INT8, (val) => BigInt(val));

// Parse DATE without timezone shift
types.setTypeParser(types.builtins.DATE, (val) => val); // keep as 'YYYY-MM-DD' string
```

**Recommendation:** For dates, consider keeping the raw string and parsing with a date library (dayjs, date-fns, Temporal) rather than relying on JavaScript's `Date` constructor, which applies local timezone offsets.

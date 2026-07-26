# Connections & Transactions

Reference for rules 8, 9 in SKILL.md. Read this when configuring connection pooling, managing transactions, or debugging deadlocks.

## Table of contents
- [MySqlConnector vs MySql.Data comparison](#mysqlconnector-vs-mysqldata-comparison)
- [MySqlConnector connection string settings](#mysqlconnector-connection-string-settings)
- [Dapper integration pattern](#dapper-integration-pattern)
- [Node.js mysql2 connection pool](#nodejs-mysql2-connection-pool)
- [Isolation levels](#isolation-levels)
- [REPEATABLE READ and GAP locks](#repeatable-read-and-gap-locks)
- [Deadlock retry pattern](#deadlock-retry-pattern)
- [Transaction best practices](#transaction-best-practices)
- [Distributed transactions](#distributed-transactions)

---

## MySqlConnector vs MySql.Data comparison

| Feature | MySqlConnector | MySql.Data (Oracle) |
|---|---|---|
| **True async I/O** | Yes (fully async from the ground up) | No (sync-over-async wrapper) |
| **Connection pooling** | Built-in, robust, configurable | Built-in, but less reliable under load |
| **Prepared statements** | Full support, server-side caching | Supported |
| **Bulk copy** | `MySqlBulkCopy` class | `MySqlBulkLoader` (LOAD DATA LOCAL) |
| **Cancellation support** | Full `CancellationToken` support | Limited |
| **.NET version support** | .NET Framework 4.8+, .NET 8/9/10 (2.3.0 dropped net461 + netcoreapp3.1; 2.5.0 added .NET 10) | .NET Framework 4.5.2+, .NET 6/7/8 |
| **License** | MIT | GPLv2 (commercial license available) |
| **NuGet package** | `MySqlConnector` | `MySql.Data` |
| **Actively maintained** | Yes (community + corporate sponsors) | Yes (Oracle) |
| **Dapper compatibility** | Excellent | Works, but async issues under load |
| **Default parameter prefix** | `@` | `@` |

**Recommendation:** Use **MySqlConnector** for all new projects. Its true async implementation prevents thread pool starvation under load, which is critical for ASP.NET Core applications. MySql.Data's sync-over-async can cause deadlocks and throughput degradation.

---

## MySqlConnector connection string settings

```
Server=localhost;Port=3306;Database=myapp;UserID=appuser;Password=secret;
Pooling=true;MinimumPoolSize=5;MaximumPoolSize=50;ConnectionLifeTime=300;
ConnectionTimeout=15;SslMode=Required;CharacterSet=utf8mb4;
AllowPublicKeyRetrieval=true;UseAffectedRows=true;
```

### Key settings explained

| Setting | Default | Recommended | Why |
|---|---|---|---|
| `Pooling` | `true` | `true` | Connection reuse is essential for performance |
| `MinimumPoolSize` | `0` | `5` | Keeps warm connections ready; avoids cold-start latency |
| `MaximumPoolSize` | `100` | `20-50` | Match to your DB's max_connections / app instance count |
| `ConnectionLifeTime` | `0` (infinite) | `300` (5 min) | Recycle connections to handle server-side timeouts, DNS changes, failover |
| `ConnectionTimeout` | `15` | `15` | Seconds to wait for a pool connection before throwing |
| `SslMode` | `Preferred` | `Required` | Enforce TLS in production; use `VerifyFull` for strongest security |
| `CharacterSet` | `utf8mb4` | `utf8mb4` | Must match server charset; prevents encoding issues |
| `UseAffectedRows` | `false` | `true` | Returns actual changed rows (not matched rows) from UPDATE; Dapper expects this |
| `AllowPublicKeyRetrieval` | `false` | `true` (dev only) | Needed for `caching_sha2_password` in MySQL 8.0; prefer RSA key file in production |
| `DefaultCommandTimeout` | `30` | `30` | Seconds before a query times out; adjust per-command for long reports |
| `GuidFormat` | `Default` | `Binary16` or `Char36` | Controls how `Guid` is stored/read; `Binary16` for BINARY(16) columns |
| `TreatTinyAsBoolean` | `true` | `true` | Maps TINYINT(1) to `bool` in C# |

---

## Dapper integration pattern

### Connection factory (recommended)

```csharp
// Registration in DI container
services.AddTransient<IDbConnectionFactory, MySqlConnectionFactory>();

// Factory implementation
public interface IDbConnectionFactory
{
    MySqlConnection Create();
}

public sealed class MySqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public MySqlConnectionFactory(IOptions<DatabaseOptions> options)
    {
        _connectionString = options.Value.ConnectionString;
    }

    public MySqlConnection Create() => new MySqlConnection(_connectionString);
}
```

### Repository pattern with Dapper

```csharp
public sealed class OrderRepository
{
    private readonly IDbConnectionFactory _db;

    public OrderRepository(IDbConnectionFactory db) => _db = db;

    public async Task<Order?> GetByIdAsync(long id, CancellationToken ct)
    {
        await using var conn = _db.Create();
        await conn.OpenAsync(ct);

        return await conn.QueryFirstOrDefaultAsync<Order>(
            new CommandDefinition(
                "SELECT id, customer_id, total, status, created_at FROM orders WHERE id = @Id",
                new { Id = id },
                cancellationToken: ct));
    }

    public async Task<int> UpdateStatusAsync(long id, string status, CancellationToken ct)
    {
        await using var conn = _db.Create();
        await conn.OpenAsync(ct);

        return await conn.ExecuteAsync(
            new CommandDefinition(
                "UPDATE orders SET status = @Status, updated_at = NOW() WHERE id = @Id",
                new { Id = id, Status = status },
                cancellationToken: ct));
    }
}
```

### Transaction pattern with Dapper

```csharp
public async Task TransferFundsAsync(long fromAccount, long toAccount, decimal amount, CancellationToken ct)
{
    await using var conn = _db.Create();
    await conn.OpenAsync(ct);
    await using var tx = await conn.BeginTransactionAsync(ct);

    try
    {
        var deducted = await conn.ExecuteAsync(
            new CommandDefinition(
                "UPDATE accounts SET balance = balance - @Amount WHERE id = @Id AND balance >= @Amount",
                new { Id = fromAccount, Amount = amount },
                transaction: tx,
                cancellationToken: ct));

        if (deducted == 0)
            throw new InvalidOperationException("Insufficient balance.");

        await conn.ExecuteAsync(
            new CommandDefinition(
                "UPDATE accounts SET balance = balance + @Amount WHERE id = @Id",
                new { Id = toAccount, Amount = amount },
                transaction: tx,
                cancellationToken: ct));

        await tx.CommitAsync(ct);
    }
    catch
    {
        await tx.RollbackAsync(ct);
        throw;
    }
}
```

---

## Node.js mysql2 connection pool

### Pool configuration

```javascript
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  charset: 'utf8mb4',

  // Pool settings
  waitForConnections: true,   // Queue requests when pool is full (vs reject immediately)
  connectionLimit: 20,        // Max connections in pool; match to DB capacity / app instance count
  queueLimit: 0,              // 0 = unlimited queue; set a limit to fail fast under extreme load
  idleTimeout: 60000,         // Close idle connections after 60s (mysql2 3.x+)
  maxIdle: 10,                // Keep at most 10 idle connections (mysql2 3.x+)
  enableKeepAlive: true,      // TCP keepalive to detect dead connections
  keepAliveInitialDelay: 30000,

  // Type handling
  supportBigNumbers: true,    // Required for BIGINT safety
  bigNumberStrings: true,     // Return BIGINT as string (avoid JS number precision loss)
  dateStrings: false,         // false = Date objects; true = date strings
  decimalNumbers: false,      // false = strings for DECIMAL (safe); true = numbers (lossy)

  // SSL
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: true } : undefined,
});

export default pool;
```

### Using connections from the pool

```javascript
// Simple query (connection auto-released)
const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [userId]);

// Manual connection for transactions
const conn = await pool.getConnection();
try {
  await conn.beginTransaction();
  await conn.execute('UPDATE accounts SET balance = balance - ? WHERE id = ?', [amount, fromId]);
  await conn.execute('UPDATE accounts SET balance = balance + ? WHERE id = ?', [amount, toId]);
  await conn.commit();
} catch (err) {
  await conn.rollback();
  throw err;
} finally {
  conn.release();  // CRITICAL: always release back to pool, even on error
}
```

**Common mistake:** Forgetting `conn.release()` in error paths. Always use try/finally.

---

## Isolation levels

| Level | Dirty reads | Non-repeatable reads | Phantom reads | Lock behavior |
|---|---|---|---|---|
| `READ UNCOMMITTED` | Yes | Yes | Yes | Minimal locking; sees uncommitted data |
| `READ COMMITTED` | No | Yes | Yes | Each SELECT sees latest committed snapshot |
| `REPEATABLE READ` | No | No | No (InnoDB) | **MySQL default**; consistent snapshot for the transaction |
| `SERIALIZABLE` | No | No | No | All SELECTs become `SELECT ... LOCK IN SHARE MODE` |

### Setting isolation level

```sql
-- Session level
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Transaction level (8.0+)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
```

**C# (MySqlConnector):**
```csharp
await using var tx = await conn.BeginTransactionAsync(
    System.Data.IsolationLevel.ReadCommitted, ct);
```

**Node.js:**
```javascript
await conn.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED");
await conn.beginTransaction();
```

### When to change from REPEATABLE READ

- **Use READ COMMITTED** for long-running reporting queries that do not need a consistent snapshot and where you want to reduce lock contention and undo log growth.
- **Use SERIALIZABLE** almost never; prefer explicit `SELECT ... FOR UPDATE` on specific rows.
- **Keep REPEATABLE READ** (default) for most OLTP workloads.

---

## REPEATABLE READ and GAP locks

This is the most common source of unexpected deadlocks in MySQL. Understanding it is essential.

### How InnoDB locking works in REPEATABLE READ

InnoDB uses **next-key locks** (record lock + gap lock) to prevent phantom reads:

1. **Record lock:** Locks a specific index record (row).
2. **Gap lock:** Locks the gap *between* index records, preventing inserts into that gap.
3. **Next-key lock:** Combination of record lock + gap lock on the preceding gap.

### Example: how gap locks cause deadlocks

```sql
-- Table: orders (id INT PK, status VARCHAR, customer_id INT, INDEX idx_status(status))
-- Existing rows: status = 'pending' for ids 1, 5, 10

-- Transaction A:
UPDATE orders SET status = 'processing' WHERE status = 'pending' AND customer_id = 100;
-- InnoDB scans idx_status for 'pending', locking gaps between matching rows

-- Transaction B:
INSERT INTO orders (id, status, customer_id) VALUES (3, 'pending', 200);
-- Blocked! The gap between id 1 and id 5 (in the status index) is locked by Transaction A

-- Transaction A:
INSERT INTO orders (id, status, customer_id) VALUES (7, 'pending', 100);
-- Blocked! If Transaction B holds a gap lock on a different range
-- DEADLOCK: MySQL detects the cycle and rolls back one transaction
```

### Mitigations

1. **Use READ COMMITTED** when gap locks are not needed (no phantom read protection required).
2. **Narrow your WHERE clauses:** The fewer index entries scanned, the fewer gaps locked.
3. **Use unique index lookups** when possible: `WHERE id = ?` takes a record lock only, no gap lock.
4. **Keep transactions short:** Reduces the window for lock conflicts.
5. **Access tables in consistent order** across all transactions.
6. **Use `SELECT ... FOR UPDATE` explicitly** instead of relying on implicit locking from UPDATE/DELETE scans.

---

## Deadlock retry pattern

### C# with exponential backoff

```csharp
public static async Task<T> ExecuteWithDeadlockRetryAsync<T>(
    Func<Task<T>> operation,
    int maxRetries = 3,
    CancellationToken ct = default)
{
    for (int attempt = 0; ; attempt++)
    {
        try
        {
            return await operation();
        }
        catch (MySqlException ex) when (ex.Number == 1213 && attempt < maxRetries) // 1213 = ER_LOCK_DEADLOCK
        {
            var delay = TimeSpan.FromMilliseconds(50 * Math.Pow(2, attempt)); // 50ms, 100ms, 200ms
            await Task.Delay(delay, ct);
        }
    }
}

// Usage:
var result = await ExecuteWithDeadlockRetryAsync(async () =>
{
    await using var conn = _db.Create();
    await conn.OpenAsync(ct);
    await using var tx = await conn.BeginTransactionAsync(ct);

    // ... transactional work ...

    await tx.CommitAsync(ct);
    return result;
}, ct: ct);
```

### Node.js with exponential backoff

```javascript
async function executeWithDeadlockRetry(operation, maxRetries = 3) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await operation();
    } catch (err) {
      // MySQL error 1213 = deadlock, 1205 = lock wait timeout
      if ((err.errno === 1213 || err.errno === 1205) && attempt < maxRetries) {
        const delay = 50 * Math.pow(2, attempt); // 50ms, 100ms, 200ms
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw err;
    }
  }
}

// Usage:
const result = await executeWithDeadlockRetry(async () => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    // ... transactional work ...
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
});
```

---

## Transaction best practices

1. **Keep transactions short.** Long transactions hold locks, grow the undo log, and block other sessions. Do all computation before `BEGIN`; only the actual reads and writes belong inside the transaction.

2. **No user interaction mid-transaction.** Never wait for user input, HTTP responses, or external service calls inside a transaction. Fetch everything you need first, then open the transaction, mutate, and commit.

3. **Always explicitly COMMIT or ROLLBACK.** Do not rely on connection close or pool return to auto-rollback. MySqlConnector will roll back uncommitted transactions on `Dispose()`, but relying on this obscures intent.

4. **Set appropriate timeouts.**
   ```sql
   SET innodb_lock_wait_timeout = 5;  -- seconds; default is 50, which is too long for OLTP
   ```

5. **Log deadlock details.**
   ```sql
   SHOW ENGINE INNODB STATUS;  -- "LATEST DETECTED DEADLOCK" section shows the involved queries and locks
   ```
   In MySQL 8.0, enable `innodb_print_all_deadlocks = ON` to log all deadlocks to the error log.

6. **Avoid mixing DDL and DML in transactions.** In MySQL, DDL statements (ALTER TABLE, CREATE INDEX) cause an implicit COMMIT. Your transaction will be committed prematurely.

7. **Batch operations in reasonable sizes.** Processing 100,000 rows in a single transaction creates massive undo log entries. Break into batches of 1,000-5,000 rows, each in its own transaction.

---

## Distributed transactions

### XA transactions

MySQL supports XA (eXtended Architecture) two-phase commit for coordinating transactions across multiple MySQL instances or heterogeneous data sources:

```sql
XA START 'xid-001';
INSERT INTO orders (customer_id, total) VALUES (1, 99.99);
XA END 'xid-001';
XA PREPARE 'xid-001';
-- ... coordinate with other participants ...
XA COMMIT 'xid-001';
```

### Limitations and caveats

1. **XA transactions are slow.** The two-phase protocol requires disk flushes and coordination rounds.
2. **Not fully crash-safe before 8.0.** In MySQL 5.7, a crash between PREPARE and COMMIT could leave orphaned prepared transactions.
3. **Replication complications.** XA transactions and binary log replication have known edge cases.
4. **Prefer application-level patterns.** For most distributed systems, prefer:
   - **Saga pattern:** Compensating transactions for each step.
   - **Outbox pattern:** Write events to a local outbox table in the same transaction, then publish asynchronously.
   - **Idempotent operations:** Design operations to be safely retried.

### Outbox pattern example (preferred over XA)

```sql
-- In one local transaction:
BEGIN;
INSERT INTO orders (customer_id, total) VALUES (1, 99.99);
INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload, created_at)
VALUES ('Order', LAST_INSERT_ID(), 'OrderCreated', '{"customerId":1,"total":99.99}', NOW());
COMMIT;

-- A separate poller/CDC process reads the outbox and publishes to the message broker.
```

This guarantees the domain event and the state change are committed atomically without distributed coordination.

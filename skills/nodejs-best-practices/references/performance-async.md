# Performance & Async Patterns

Covers **Rule 7** (never block the event loop) and **Rule 8** (connection pooling and parameterized queries).

---

## Table of Contents

- [Event Loop Fundamentals](#event-loop-fundamentals)
- [Identifying and Fixing Blocking Code](#identifying-and-fixing-blocking-code)
- [Streams for Large Data](#streams-for-large-data)
- [Worker Threads for CPU Work](#worker-threads-for-cpu-work)
- [Database Connection Pooling](#database-connection-pooling)
- [Parameterized Queries](#parameterized-queries)
- [Common Performance Anti-Patterns](#common-performance-anti-patterns)

---

## Event Loop Fundamentals

Node.js runs JavaScript on a single thread. The event loop processes I/O callbacks, timers, and microtasks
in a deterministic order. Any synchronous operation that takes more than a few milliseconds blocks *all*
concurrent requests.

### What blocks the event loop

| Blocking operation | Async alternative |
|-------------------|-------------------|
| `fs.readFileSync()` | `fs.promises.readFile()` |
| `fs.writeFileSync()` | `fs.promises.writeFile()` |
| `crypto.pbkdf2Sync()` | `crypto.pbkdf2()` (callback) or promisified |
| `crypto.scryptSync()` | `crypto.scrypt()` (callback) or promisified |
| `JSON.parse()` on huge strings | Stream-based JSON parsing (`stream-json`) |
| CPU-heavy loop (e.g., image resize) | `worker_threads` |
| Synchronous child process calls | Async `execFile()` with callback/promise |

### Monitoring event loop lag

```typescript
// Simple event loop lag monitor
let lastCheck = Date.now();
setInterval(() => {
  const now = Date.now();
  const lag = now - lastCheck - 1000; // expected 1000ms interval
  if (lag > 100) {
    logger.warn({ lagMs: lag }, 'Event loop lag detected');
  }
  lastCheck = now;
}, 1000).unref(); // unref so it doesn't keep the process alive
```

For production, use `prom-client` or `clinic.js` for proper event loop monitoring.

---

## Identifying and Fixing Blocking Code

### Before (blocking)

```typescript
// BAD: blocks event loop for every request
router.get('/report', asyncHandler(async (req, res) => {
  const data = fs.readFileSync('/data/large-report.csv', 'utf-8'); // Blocking!
  const parsed = Papa.parse(data); // CPU-heavy on large files!
  res.json(parsed.data);
}));
```

### After (non-blocking)

```typescript
// GOOD: async file read + streaming for large files
router.get('/report', asyncHandler(async (req, res) => {
  const data = await fs.promises.readFile('/data/large-report.csv', 'utf-8');
  const parsed = Papa.parse(data);
  res.json(parsed.data);
}));

// BETTER: stream large files instead of loading entirely into memory
router.get('/report/stream', asyncHandler(async (req, res) => {
  const stream = fs.createReadStream('/data/large-report.csv');
  res.setHeader('Content-Type', 'text/csv');
  stream.pipe(res);
}));
```

---

## Streams for Large Data

Streams process data in chunks, keeping memory usage constant regardless of data size.

### Reading large files

```typescript
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

async function processLargeFile(filePath: string): Promise<number> {
  const rl = createInterface({
    input: createReadStream(filePath),
    crlfDelay: Infinity,
  });

  let lineCount = 0;
  for await (const line of rl) {
    // Process line by line — constant memory
    lineCount++;
  }
  return lineCount;
}
```

### Streaming JSON responses

```typescript
// For large result sets, stream JSON instead of buffering
router.get('/export', asyncHandler(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.write('[');

  let first = true;
  const cursor = db.query('SELECT * FROM orders').stream();

  for await (const row of cursor) {
    if (!first) res.write(',');
    res.write(JSON.stringify(row));
    first = false;
  }

  res.write(']');
  res.end();
}));
```

### Pipeline for transform streams

```typescript
import { pipeline } from 'node:stream/promises';
import { createReadStream, createWriteStream } from 'node:fs';
import { createGzip } from 'node:zlib';

// Compress a file using streams — memory efficient
await pipeline(
  createReadStream('input.json'),
  createGzip(),
  createWriteStream('input.json.gz'),
);
```

---

## Worker Threads for CPU Work

For CPU-intensive operations (image processing, PDF generation, complex calculations), use `worker_threads`
to avoid blocking the main thread.

```typescript
// src/common/worker-pool.ts
import { Worker } from 'node:worker_threads';

export function runInWorker<T>(workerPath: string, data: unknown): Promise<T> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(workerPath, { workerData: data });
    worker.on('message', resolve);
    worker.on('error', reject);
    worker.on('exit', (code) => {
      if (code !== 0) reject(new Error(`Worker exited with code ${code}`));
    });
  });
}
```

```typescript
// src/workers/image-resize.worker.ts
import { parentPort, workerData } from 'node:worker_threads';
import sharp from 'sharp';

const { inputPath, outputPath, width, height } = workerData;

const result = await sharp(inputPath)
  .resize(width, height)
  .toFile(outputPath);

parentPort?.postMessage(result);
```

```typescript
// Usage in route handler
router.post('/resize', asyncHandler(async (req, res) => {
  const result = await runInWorker('./src/workers/image-resize.worker.js', {
    inputPath: req.file.path,
    outputPath: `/tmp/resized-${Date.now()}.jpg`,
    width: 800,
    height: 600,
  });
  res.json(result);
}));
```

---

## Database Connection Pooling

### PostgreSQL with pg

```typescript
// src/config/database.ts
import { Pool } from 'pg';
import { config } from './env';

// Create ONE pool, shared across the application
export const pool = new Pool({
  connectionString: config.DATABASE_URL,
  min: config.DB_POOL_MIN,   // minimum idle connections (default: 2)
  max: config.DB_POOL_MAX,   // maximum connections (default: 10)
  idleTimeoutMillis: 30_000, // close idle connections after 30s
  connectionTimeoutMillis: 5_000, // fail fast if can't connect in 5s
});

// Log pool errors (don't let them crash the process)
pool.on('error', (err) => {
  logger.error({ err }, 'Unexpected database pool error');
});

// Health check
export async function checkDatabaseHealth(): Promise<boolean> {
  try {
    await pool.query('SELECT 1');
    return true;
  } catch {
    return false;
  }
}
```

### Common mistakes

```typescript
// BAD: new Client per request — no pooling, connection overhead on every query
router.get('/users', asyncHandler(async (req, res) => {
  const client = new Client(config.DATABASE_URL); // Wrong!
  await client.connect();
  const result = await client.query('SELECT * FROM users');
  await client.end();
  res.json(result.rows);
}));

// GOOD: use pool.query — automatically acquires and releases a connection
router.get('/users', asyncHandler(async (req, res) => {
  const result = await pool.query('SELECT * FROM users');
  res.json(result.rows);
}));
```

### Transactions with pool

```typescript
// For transactions, acquire a client from the pool and release it after
async function transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromId]);
    await client.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toId]);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release(); // ALWAYS release back to pool
  }
}
```

---

## Parameterized Queries

### Why parameterized queries are non-negotiable

```typescript
// DANGEROUS: SQL injection via string concatenation
const result = await pool.query(
  `SELECT * FROM users WHERE email = '${req.body.email}'` // NEVER do this
);
// Input: ' OR '1'='1  → returns all users

// SAFE: parameterized query
const result = await pool.query(
  'SELECT * FROM users WHERE email = $1',
  [req.body.email]
);
```

### Parameterized query patterns by database

```typescript
// PostgreSQL (pg): $1, $2, $3...
await pool.query('SELECT * FROM users WHERE id = $1 AND status = $2', [id, 'active']);

// MySQL (mysql2): ? placeholders
await pool.query('SELECT * FROM users WHERE id = ? AND status = ?', [id, 'active']);

// Named parameters with knex
await knex('users').where({ id, status: 'active' }).select('*');

// Prisma (always parameterized)
await prisma.user.findMany({ where: { id, status: 'active' } });
```

### Dynamic WHERE clauses (safe pattern)

```typescript
// Building dynamic queries safely — never concatenate conditions
function buildUserQuery(filters: ListUsersQuery) {
  const conditions: string[] = [];
  const params: unknown[] = [];
  let paramIndex = 1;

  if (filters.search) {
    conditions.push(`(name ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`);
    params.push(`%${filters.search}%`);
    paramIndex++;
  }

  if (filters.role) {
    conditions.push(`role = $${paramIndex}`);
    params.push(filters.role);
    paramIndex++;
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const offset = (filters.page - 1) * filters.limit;

  return {
    query: `SELECT * FROM users ${where} ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    params: [...params, filters.limit, offset],
  };
}
```

---

## Common Performance Anti-Patterns

### N+1 queries

```typescript
// BAD: N+1 — one query per order to get its items
const orders = await pool.query('SELECT * FROM orders');
for (const order of orders.rows) {
  const items = await pool.query('SELECT * FROM order_items WHERE order_id = $1', [order.id]);
  order.items = items.rows; // N extra queries!
}

// GOOD: single query with JOIN or batch
const result = await pool.query(`
  SELECT o.*, json_agg(oi.*) as items
  FROM orders o
  LEFT JOIN order_items oi ON oi.order_id = o.id
  GROUP BY o.id
`);
```

### Missing indices

```typescript
// If you filter or sort by a column, ensure it has an index
// Check with: EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

### Unbounded queries

```typescript
// BAD: no limit — can return millions of rows
const result = await pool.query('SELECT * FROM logs');

// GOOD: always limit
const result = await pool.query('SELECT * FROM logs ORDER BY created_at DESC LIMIT $1', [100]);
```

### Fire-and-forget without intent

```typescript
// BAD: promise rejection is silently swallowed
sendEmail(user.email, 'Welcome!'); // missing await!

// GOOD: await or explicitly handle
await sendEmail(user.email, 'Welcome!');

// OK: intentional fire-and-forget with error logging
sendEmail(user.email, 'Welcome!').catch((err) => {
  logger.error({ err, email: user.email }, 'Failed to send welcome email');
});
```

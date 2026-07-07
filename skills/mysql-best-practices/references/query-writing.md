# Query Writing

Reference for rules 4, 5, 6, 10 in SKILL.md. Read this when writing queries, optimizing SQL, or reading EXPLAIN output.

## Table of contents
- [Parameterization in .NET (MySqlConnector + Dapper)](#parameterization-in-net)
- [Parameterization in Node.js (mysql2)](#parameterization-in-nodejs)
- [JOIN optimization](#join-optimization)
- [Subquery anti-patterns](#subquery-anti-patterns)
- [CTEs (8.0+)](#ctes)
- [Window functions (8.0+)](#window-functions)
- [JSON operations](#json-operations)
- [Reading EXPLAIN output](#reading-explain-output)
- [EXPLAIN ANALYZE (8.0.18+)](#explain-analyze)
- [INSERT ON DUPLICATE KEY UPDATE](#insert-on-duplicate-key-update)
- [Pagination strategies](#pagination-strategies)

---

## Parameterization in .NET

### MySqlConnector + Dapper: @param style

```csharp
// Anonymous object (most common)
var user = await conn.QueryFirstOrDefaultAsync<User>(
    "SELECT id, email, created_at FROM users WHERE email = @Email AND is_active = @IsActive",
    new { Email = email, IsActive = true });

// POCO as parameter source
await conn.ExecuteAsync(
    "INSERT INTO users (email, name, created_at) VALUES (@Email, @Name, @CreatedAt)",
    user);
```

### DynamicParameters for complex scenarios

```csharp
var p = new DynamicParameters();
p.Add("@TenantId", tenantId, DbType.Int64);
p.Add("@Status", status.ToString(), DbType.String, size: 50);
p.Add("@MinDate", minDate, DbType.DateTime);

var orders = await conn.QueryAsync<Order>(
    @"SELECT id, total, created_at FROM orders
      WHERE tenant_id = @TenantId AND status = @Status AND created_at >= @MinDate",
    p);
```

### IN clause expansion

Dapper automatically expands list parameters into individual parameters:

```csharp
var ids = new[] { 1L, 2L, 3L, 4L };
var users = await conn.QueryAsync<User>(
    "SELECT id, email FROM users WHERE id IN @Ids",
    new { Ids = ids });
// Dapper generates: WHERE id IN (@Ids0, @Ids1, @Ids2, @Ids3)
```

**Warning:** MySQL has a practical limit of ~65,535 parameters per query. For very large lists (1000+), use a temporary table or a subquery instead.

### LIKE with parameterization

```csharp
// Correct: parameter contains the wildcards
var users = await conn.QueryAsync<User>(
    "SELECT id, email FROM users WHERE email LIKE @Pattern",
    new { Pattern = $"%{searchTerm}%" });

// WRONG: concatenation in SQL — SQL injection risk
// "SELECT id, email FROM users WHERE email LIKE '%" + searchTerm + "%'"
```

Escape user input that might contain `%` or `_`:
```csharp
var escaped = searchTerm.Replace("%", "\\%").Replace("_", "\\_");
var users = await conn.QueryAsync<User>(
    "SELECT id, email FROM users WHERE email LIKE @Pattern ESCAPE '\\'",
    new { Pattern = $"%{escaped}%" });
```

### Stored procedure calls

```csharp
var p = new DynamicParameters();
p.Add("@UserId", userId, DbType.Int64);
p.Add("@NewBalance", dbType: DbType.Decimal, direction: ParameterDirection.Output, precision: 19, scale: 4);

await conn.ExecuteAsync("sp_update_balance", p, commandType: CommandType.StoredProcedure);

var newBalance = p.Get<decimal>("@NewBalance");
```

---

## Parameterization in Node.js

### mysql2: positional placeholders (?)

```javascript
// Single query with positional parameters
const [rows] = await pool.execute(
  'SELECT id, email FROM users WHERE email = ? AND is_active = ?',
  [email, true]
);

// INSERT
const [result] = await pool.execute(
  'INSERT INTO users (email, name, created_at) VALUES (?, ?, NOW())',
  [user.email, user.name]
);
console.log(result.insertId); // auto-increment ID
```

### Named placeholders

```javascript
// Enable named placeholders on the pool/connection
const pool = mysql.createPool({ ...config, namedPlaceholders: true });

const [rows] = await pool.execute(
  'SELECT id, email FROM users WHERE tenant_id = :tenantId AND status = :status',
  { tenantId: 42, status: 'active' }
);
```

### Prepared statements

mysql2 uses `execute()` for prepared statements (server-side) and `query()` for text protocol:

```javascript
// execute() — prepared statement, parameters sent separately (safe from injection)
const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [userId]);

// query() — text protocol, parameters are escaped client-side
const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [userId]);

// Both are safe from SQL injection. Prefer execute() for repeated queries (plan caching).
```

### IN clause in mysql2

mysql2 does not auto-expand arrays. Use the `?` placeholder with an array-of-arrays trick:

```javascript
const ids = [1, 2, 3, 4];
const [rows] = await pool.query(
  'SELECT id, email FROM users WHERE id IN (?)',
  [ids]  // mysql2 expands the array: IN (1, 2, 3, 4)
);
// Note: this works with query() but NOT with execute() (prepared statements).
// For execute(), build the placeholders dynamically:
const placeholders = ids.map(() => '?').join(', ');
const [rows2] = await pool.execute(
  `SELECT id, email FROM users WHERE id IN (${placeholders})`,
  ids
);
```

### Batch insert

```javascript
const users = [
  ['alice@example.com', 'Alice'],
  ['bob@example.com', 'Bob'],
  ['charlie@example.com', 'Charlie'],
];
const [result] = await pool.query(
  'INSERT INTO users (email, name) VALUES ?',
  [users]  // mysql2 expands to multi-row VALUES
);
console.log(result.affectedRows); // 3
```

---

## JOIN optimization

MySQL 8.0 supports three join algorithms. Understanding them helps you write queries the optimizer can handle efficiently.

### Index nested loop join (default, most common)

For each row in the outer (driving) table, MySQL looks up matching rows in the inner table using an index.

- **Optimal when:** the inner table has an index on the join column and the outer table is small or well-filtered.
- **EXPLAIN shows:** `type: ref` or `type: eq_ref` for the inner table.
- **Ensure:** indexes exist on both sides of the join condition.

```sql
-- Good: orders.customer_id is indexed
SELECT o.id, o.total, c.name
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.created_at >= '2024-01-01';
```

### Hash join (8.0.18+)

MySQL 8.0.18+ uses a hash join when no index is available on the join column. It builds a hash table from the smaller table and probes it with the larger table.

- **EXPLAIN shows:** `Using join buffer (hash join)` in Extra.
- **Useful for:** analytical queries joining large tables on non-indexed columns.
- **Tuning:** `join_buffer_size` controls the in-memory hash table size. If it exceeds memory, MySQL spills to disk.

### Block nested loop (BNL)

Before 8.0.18, MySQL used BNL when no index was available: buffer rows from the outer table, scan the inner table, match. This is **slow for large tables**.

- **EXPLAIN shows:** `Using join buffer (Block Nested Loop)`.
- **Fix:** Add an index on the join column, or upgrade to 8.0.18+ for hash join.

### JOIN best practices

1. **Always index join columns** on both tables.
2. **Filter early:** Put the most restrictive WHERE conditions on the driving table.
3. **Avoid implicit joins** (`FROM a, b WHERE a.id = b.a_id`); use explicit `JOIN` syntax for clarity.
4. **Be careful with LEFT JOIN:** Conditions on the right table in WHERE (not ON) convert it to an INNER JOIN.
5. **Limit the number of joins:** Beyond 5-6 tables, consider denormalization or breaking the query.

---

## Subquery anti-patterns

### Correlated subquery (often slow)

```sql
-- BAD: correlated subquery executes once per row in the outer query
SELECT o.id, o.total,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
FROM orders o
WHERE o.created_at >= '2024-01-01';

-- BETTER: use a JOIN with aggregation
SELECT o.id, o.total, COALESCE(oi.item_count, 0) AS item_count
FROM orders o
LEFT JOIN (
    SELECT order_id, COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
) oi ON oi.order_id = o.id
WHERE o.created_at >= '2024-01-01';
```

### Derived table materialization

MySQL materializes derived tables (subqueries in FROM) into temporary tables by default. In 8.0, the optimizer can sometimes merge them into the outer query.

```sql
-- 5.7: this derived table is materialized (temporary table created)
-- 8.0: optimizer may merge it into the outer query
SELECT d.customer_id, d.total_orders
FROM (
    SELECT customer_id, COUNT(*) AS total_orders
    FROM orders
    GROUP BY customer_id
) d
WHERE d.total_orders > 10;
```

### EXISTS vs IN

```sql
-- Prefer EXISTS for correlated checks (stops at first match)
SELECT c.id, c.name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id AND o.total > 1000);

-- IN is fine for small, static lists or non-correlated subqueries
SELECT * FROM orders WHERE status IN ('pending', 'processing');
```

---

## CTEs

Common Table Expressions require MySQL 8.0+. They improve readability and enable recursive queries.

### Basic CTE

```sql
WITH active_customers AS (
    SELECT id, name, email
    FROM customers
    WHERE is_active = 1 AND last_login >= DATE_SUB(NOW(), INTERVAL 30 DAY)
)
SELECT ac.name, COUNT(o.id) AS order_count
FROM active_customers ac
INNER JOIN orders o ON o.customer_id = ac.id
GROUP BY ac.id, ac.name
ORDER BY order_count DESC;
```

### Recursive CTE (hierarchical data)

```sql
-- Organization tree: find all descendants of a manager
WITH RECURSIVE org_tree AS (
    -- Anchor: start with the root manager
    SELECT id, name, manager_id, 0 AS depth
    FROM employees
    WHERE id = 1

    UNION ALL

    -- Recursive: find direct reports of current level
    SELECT e.id, e.name, e.manager_id, ot.depth + 1
    FROM employees e
    INNER JOIN org_tree ot ON e.manager_id = ot.id
    WHERE ot.depth < 10  -- safety limit to prevent infinite recursion
)
SELECT * FROM org_tree ORDER BY depth, name;
```

### CTE limitations
- CTEs are **not writable** in MySQL; you cannot UPDATE/DELETE inside a CTE.
- MySQL does **not** automatically cache CTE results if referenced multiple times; it may re-evaluate the CTE for each reference (8.0 optimizer decides).
- Recursive CTEs need a termination condition (UNION ALL with a depth limit or a WHERE that eventually returns no rows).

---

## Window functions

Window functions require MySQL 8.0+. They compute values across a set of rows related to the current row without collapsing the result set.

### ROW_NUMBER, RANK, DENSE_RANK

```sql
-- Assign a row number within each partition
SELECT
    id, customer_id, total, created_at,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
FROM orders;

-- Get the most recent order per customer
SELECT * FROM (
    SELECT
        id, customer_id, total, created_at,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
    FROM orders
) ranked
WHERE rn = 1;
```

| Function | Ties behavior | Example (values: 10, 20, 20, 30) |
|---|---|---|
| `ROW_NUMBER()` | No ties, arbitrary order for equal values | 1, 2, 3, 4 |
| `RANK()` | Ties get same rank, gap after | 1, 2, 2, 4 |
| `DENSE_RANK()` | Ties get same rank, no gap | 1, 2, 2, 3 |

### LAG / LEAD

```sql
-- Compare each order's total with the previous order's total
SELECT
    id, customer_id, total, created_at,
    LAG(total, 1) OVER (PARTITION BY customer_id ORDER BY created_at) AS prev_total,
    total - LAG(total, 1) OVER (PARTITION BY customer_id ORDER BY created_at) AS diff
FROM orders;
```

### Running totals with SUM OVER

```sql
-- Running total of order amounts per customer
SELECT
    id, customer_id, total, created_at,
    SUM(total) OVER (
        PARTITION BY customer_id
        ORDER BY created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM orders;
```

### Frame specifications

```sql
-- Moving average over last 7 days
SELECT
    report_date, revenue,
    AVG(revenue) OVER (
        ORDER BY report_date
        RANGE BETWEEN INTERVAL 6 DAY PRECEDING AND CURRENT ROW
    ) AS avg_7day
FROM daily_revenue;
```

---

## JSON operations

### Basic extraction

```sql
-- -> returns JSON value (quoted strings)
SELECT metadata->'$.customer.name' FROM orders;  -- returns: "Alice"

-- ->> returns unquoted text (equivalent to JSON_UNQUOTE(JSON_EXTRACT(...)))
SELECT metadata->>'$.customer.name' FROM orders;  -- returns: Alice

-- Nested access
SELECT metadata->>'$.items[0].sku' FROM orders;
```

### Modification

```sql
-- JSON_SET: set or replace a value
UPDATE orders SET metadata = JSON_SET(metadata, '$.status', 'shipped') WHERE id = 1;

-- JSON_INSERT: insert only if path does not exist
UPDATE orders SET metadata = JSON_INSERT(metadata, '$.tracking_number', 'ABC123') WHERE id = 1;

-- JSON_REPLACE: replace only if path exists
UPDATE orders SET metadata = JSON_REPLACE(metadata, '$.status', 'delivered') WHERE id = 1;

-- JSON_REMOVE: delete a key
UPDATE orders SET metadata = JSON_REMOVE(metadata, '$.internal_notes') WHERE id = 1;
```

### JSON construction

```sql
-- JSON_OBJECT: build a JSON object
SELECT JSON_OBJECT('id', id, 'email', email, 'name', name) AS user_json FROM users;

-- JSON_ARRAY: build a JSON array
SELECT JSON_ARRAY(1, 'two', 3.0, NULL);  -- [1, "two", 3.0, null]

-- JSON_ARRAYAGG / JSON_OBJECTAGG: aggregate into JSON (8.0+)
SELECT customer_id, JSON_ARRAYAGG(JSON_OBJECT('id', id, 'total', total)) AS orders_json
FROM orders
GROUP BY customer_id;
```

### JSON_TABLE (8.0+)

Converts JSON data into a relational result set:

```sql
SELECT jt.*
FROM orders o,
JSON_TABLE(o.metadata, '$.items[*]' COLUMNS (
    item_index FOR ORDINALITY,
    sku VARCHAR(50) PATH '$.sku',
    qty INT PATH '$.quantity',
    price DECIMAL(10,2) PATH '$.price'
)) AS jt
WHERE o.id = 1;
```

### Indexing JSON with generated columns

JSON columns cannot be indexed directly. Use generated columns:

```sql
ALTER TABLE orders
ADD COLUMN customer_email VARCHAR(255) GENERATED ALWAYS AS (metadata->>'$.customer.email') STORED,
ADD INDEX idx_json_email (customer_email);

-- Now this query uses the index:
SELECT * FROM orders WHERE customer_email = 'alice@example.com';
-- Instead of the slow full scan:
-- SELECT * FROM orders WHERE metadata->>'$.customer.email' = 'alice@example.com';
```

In MySQL 8.0+, you can also create a functional index directly (no generated column needed):

```sql
CREATE INDEX idx_func_email ON orders ((CAST(metadata->>'$.customer.email' AS CHAR(255))));
```

---

## Reading EXPLAIN output

Always run EXPLAIN before shipping queries that touch more than one table or are expected to handle significant row counts.

### The `type` column (access method, best to worst)

| Type | Meaning | Performance |
|---|---|---|
| `system` | Table has exactly 1 row | Best |
| `const` | At most 1 row (PK or unique index = constant) | Excellent |
| `eq_ref` | One row per row from previous table (PK/unique JOIN) | Excellent |
| `ref` | Multiple rows via non-unique index | Good |
| `fulltext` | FULLTEXT index lookup | Good (for text search) |
| `ref_or_null` | Like ref, plus NULL lookup | Good |
| `index_merge` | Multiple indexes combined | Moderate |
| `range` | Index range scan (BETWEEN, >, <, IN) | Moderate |
| `index` | Full index scan (reads entire index) | Poor |
| `ALL` | Full table scan | Worst — add an index |

### The `key` column

Shows which index MySQL chose. If NULL, no index is being used. Check `possible_keys` for what was available but not chosen.

### The `rows` column

Estimated number of rows MySQL expects to examine. A large number here relative to the result set indicates an inefficient scan.

### The `Extra` column (key values)

| Extra | Meaning | Action |
|---|---|---|
| `Using index` | Covering index; no table lookup | Optimal |
| `Using where` | Row filter applied after index lookup | Normal, but check if index could be better |
| `Using temporary` | Temporary table created (often for GROUP BY) | Consider adding an index that covers the GROUP BY |
| `Using filesort` | Extra sort pass required | Add an index that matches the ORDER BY |
| `Using index condition` | Index Condition Pushdown (ICP); filter pushed to storage engine | Good optimization (5.6+) |
| `Using join buffer` | No index on join column | Add an index on the join column |

### EXPLAIN FORMAT=JSON (more detail)

```sql
EXPLAIN FORMAT=JSON SELECT ...;
```

Returns a JSON document with cost estimates, used/filtered rows, and detailed access paths. Useful for complex queries.

---

## EXPLAIN ANALYZE

Available in MySQL 8.0.18+. Runs the query and shows **actual** execution metrics alongside estimates.

```sql
EXPLAIN ANALYZE SELECT o.id, c.name
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.created_at >= '2024-01-01' AND o.status = 'pending';
```

Output includes:
- **actual time**: real milliseconds for first row and all rows.
- **rows**: actual rows produced vs estimated.
- **loops**: number of times the operation was executed.

**Key insight:** Compare `estimated rows` vs `actual rows`. A large mismatch means stale statistics. Run `ANALYZE TABLE` to update them.

```sql
-- Update table statistics
ANALYZE TABLE orders;
ANALYZE TABLE customers;
```

---

## INSERT ON DUPLICATE KEY UPDATE

### Basic syntax

```sql
INSERT INTO inventory (sku, warehouse_id, quantity, updated_at)
VALUES ('ABC-123', 1, 50, NOW())
ON DUPLICATE KEY UPDATE
    quantity = quantity + VALUES(quantity),
    updated_at = NOW();
```

Requires a UNIQUE index or PRIMARY KEY on the conflict columns. If a duplicate is found, the UPDATE clause runs instead.

### Multi-row upsert

```sql
INSERT INTO inventory (sku, warehouse_id, quantity, updated_at)
VALUES
    ('ABC-123', 1, 50, NOW()),
    ('DEF-456', 1, 30, NOW()),
    ('GHI-789', 1, 20, NOW())
ON DUPLICATE KEY UPDATE
    quantity = quantity + VALUES(quantity),
    updated_at = NOW();
```

### Gotchas

1. **Auto-increment gap:** Each attempted INSERT consumes an auto-increment value, even if the row already exists and triggers the UPDATE path. This creates gaps in auto-increment sequences.
2. **`VALUES()` deprecation:** In MySQL 8.0.20+, `VALUES(col)` in the UPDATE clause is deprecated. Use alias syntax instead:
   ```sql
   INSERT INTO inventory (sku, warehouse_id, quantity) VALUES ('ABC-123', 1, 50) AS new_row
   ON DUPLICATE KEY UPDATE quantity = quantity + new_row.quantity;
   ```
3. **Row count:** Returns 1 for insert, 2 for update, 0 for no change.

### REPLACE INTO comparison

`REPLACE INTO` deletes the existing row and inserts a new one. This is almost always wrong:
- It triggers DELETE + INSERT triggers, not UPDATE.
- It resets auto-increment if the PK is auto-increment.
- Foreign key cascades may fire on the DELETE.
- **Prefer INSERT ON DUPLICATE KEY UPDATE** in virtually all cases.

---

## Pagination strategies

### LIMIT OFFSET (simple but problematic)

```sql
-- Page 1
SELECT id, title, created_at FROM articles ORDER BY created_at DESC LIMIT 20 OFFSET 0;
-- Page 100
SELECT id, title, created_at FROM articles ORDER BY created_at DESC LIMIT 20 OFFSET 1980;
```

**Problems at depth:**
- MySQL must read and discard `OFFSET` rows before returning results.
- `OFFSET 1000000` means scanning 1 million + 20 rows, even with an index.
- Performance degrades linearly with page depth.

### Keyset pagination (cursor-based, scalable)

Instead of OFFSET, remember the last seen value and filter from there:

```sql
-- First page
SELECT id, title, created_at FROM articles
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Next page: use the last row's values as cursor
SELECT id, title, created_at FROM articles
WHERE (created_at, id) < (@last_created_at, @last_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

**C# example with Dapper:**
```csharp
var articles = await conn.QueryAsync<Article>(
    @"SELECT id, title, created_at FROM articles
      WHERE (created_at, id) < (@LastCreatedAt, @LastId)
      ORDER BY created_at DESC, id DESC
      LIMIT @PageSize",
    new { LastCreatedAt = cursor.CreatedAt, LastId = cursor.Id, PageSize = 20 });
```

**Node.js example with mysql2:**
```javascript
const [rows] = await pool.execute(
  `SELECT id, title, created_at FROM articles
   WHERE (created_at, id) < (?, ?)
   ORDER BY created_at DESC, id DESC
   LIMIT ?`,
  [lastCreatedAt, lastId, 20]
);
```

**Advantages:**
- Constant performance regardless of page depth (uses index range scan).
- Consistent results even if new rows are inserted.

**Trade-off:** Cannot jump to arbitrary page numbers; only forward/backward navigation.

### Deferred join (for OFFSET when keyset is not feasible)

```sql
-- Instead of selecting all columns with a large OFFSET:
SELECT a.id, a.title, a.body, a.created_at
FROM articles a
INNER JOIN (
    SELECT id FROM articles ORDER BY created_at DESC LIMIT 20 OFFSET 1980
) AS page ON page.id = a.id
ORDER BY a.created_at DESC;
```

The inner query only reads the index (covering), making the OFFSET scan much faster. The outer query fetches full rows only for the 20 matching IDs.

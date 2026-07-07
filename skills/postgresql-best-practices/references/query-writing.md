# PostgreSQL Query Writing

## Parameterization

### .NET (Npgsql + Dapper)

Npgsql uses `@param` syntax for named parameters:

```csharp
// Dapper with Npgsql — anonymous object parameters
await using var conn = new NpgsqlConnection(connectionString);
var users = await conn.QueryAsync<User>(
    "SELECT id, name, email FROM users WHERE status = @Status AND created_at > @Since",
    new { Status = "active", Since = DateTimeOffset.UtcNow.AddDays(-30) });

// Explicit NpgsqlParameter for type control
await using var cmd = new NpgsqlCommand(
    "SELECT * FROM products WHERE tags @> @Tags", conn);
cmd.Parameters.Add(new NpgsqlParameter("Tags", NpgsqlDbType.Array | NpgsqlDbType.Text)
{
    Value = new[] { "electronics", "sale" }
});

// IN list expansion with Dapper
var ids = new[] { 1, 2, 3, 4, 5 };
var orders = await conn.QueryAsync<Order>(
    "SELECT * FROM orders WHERE id = ANY(@Ids)",
    new { Ids = ids });

// Alternative: Dapper expands IN @list automatically for small lists
var orders2 = await conn.QueryAsync<Order>(
    "SELECT * FROM orders WHERE id IN @Ids",
    new { Ids = ids });
```

**Important:** For PostgreSQL, prefer `= ANY(@Ids)` over `IN @Ids` for array parameters. Dapper's `IN` expansion generates individual parameters (`@Ids1, @Ids2, ...`) which prevents plan caching. `ANY` with a single array parameter allows plan reuse.

### Node.js (pg / node-postgres)

pg uses positional `$1`, `$2`, ... parameters:

```javascript
// Basic parameterized query
const { rows } = await pool.query(
  'SELECT id, name, email FROM users WHERE status = $1 AND created_at > $2',
  ['active', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)]
);

// IN clause with ANY and array parameter
const ids = [1, 2, 3, 4, 5];
const { rows: orders } = await pool.query(
  'SELECT * FROM orders WHERE id = ANY($1::int[])',
  [ids]
);

// JSONB containment query
const { rows: events } = await pool.query(
  'SELECT * FROM events WHERE payload @> $1',
  [JSON.stringify({ type: 'purchase' })]
);
```

**Dynamic identifiers** (table/column names) cannot be parameterized. Use `pg-format` for safe identifier quoting:

```javascript
const format = require('pg-format');

// Safe dynamic table name
const tableName = 'user_accounts';
const sql = format('SELECT * FROM %I WHERE id = $1', tableName);
const { rows } = await pool.query(sql, [userId]);

// Safe dynamic column + value
const sql2 = format('SELECT * FROM users WHERE %I = %L', 'email', userEmail);
```

**Never** concatenate or template-literal user input into SQL strings. Always use parameters.

## CTEs (Common Table Expressions)

### Non-Recursive CTEs

Use CTEs for readability and DRY within a single query:

```sql
WITH active_customers AS (
    SELECT id, name, email
    FROM customers
    WHERE status = 'active'
      AND last_login > now() - interval '90 days'
),
recent_orders AS (
    SELECT customer_id, count(*) AS order_count, sum(total) AS total_spent
    FROM orders
    WHERE created_at > now() - interval '30 days'
    GROUP BY customer_id
)
SELECT
    ac.name,
    ac.email,
    coalesce(ro.order_count, 0) AS recent_orders,
    coalesce(ro.total_spent, 0) AS recent_total
FROM active_customers ac
LEFT JOIN recent_orders ro ON ro.customer_id = ac.id
ORDER BY ro.total_spent DESC NULLS LAST;
```

### Materialization Hints (PG 12+)

```sql
-- Force materialization (useful when CTE is referenced multiple times)
WITH expensive_calc AS MATERIALIZED (
    SELECT product_id, avg(price) AS avg_price FROM price_history GROUP BY product_id
)
SELECT * FROM expensive_calc WHERE avg_price > 100;

-- Prevent materialization (allow the planner to inline the CTE)
WITH simple_filter AS NOT MATERIALIZED (
    SELECT * FROM orders WHERE status = 'pending'
)
SELECT * FROM simple_filter WHERE total > 1000;
```

Since PG 12, non-recursive CTEs are inlined by default (treated as sub-selects) unless they have side effects or are referenced multiple times. Use `MATERIALIZED` to force a single evaluation when the CTE is expensive and referenced multiple times.

### Recursive CTEs

```sql
-- Hierarchical data: org chart
WITH RECURSIVE org_tree AS (
    -- Base case: top-level managers
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive case
    SELECT e.id, e.name, e.manager_id, ot.depth + 1
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
    WHERE ot.depth < 10  -- safety limit to prevent infinite recursion
)
SELECT * FROM org_tree ORDER BY depth, name;
```

### Writable CTEs

```sql
-- Archive old orders: delete and insert into archive in one statement
WITH deleted_orders AS (
    DELETE FROM orders
    WHERE status = 'completed' AND completed_at < now() - interval '2 years'
    RETURNING *
)
INSERT INTO orders_archive
SELECT * FROM deleted_orders;

-- Upsert and return the result
WITH upserted AS (
    INSERT INTO inventory (product_id, warehouse_id, quantity)
    VALUES (101, 1, 50)
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET quantity = inventory.quantity + EXCLUDED.quantity
    RETURNING *
)
SELECT * FROM upserted;
```

## Window Functions

### Cheat Sheet

```sql
-- ROW_NUMBER: unique sequential number per partition
SELECT
    department,
    name,
    salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees;

-- RANK / DENSE_RANK: handle ties differently
-- RANK: 1, 2, 2, 4 (skips)    DENSE_RANK: 1, 2, 2, 3 (no skip)
SELECT name, salary,
    RANK() OVER (ORDER BY salary DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank
FROM employees;

-- LAG / LEAD: access previous/next row
SELECT
    date,
    revenue,
    LAG(revenue, 1) OVER (ORDER BY date) AS prev_day_revenue,
    LEAD(revenue, 1) OVER (ORDER BY date) AS next_day_revenue,
    revenue - LAG(revenue, 1) OVER (ORDER BY date) AS daily_change
FROM daily_sales;

-- FIRST_VALUE / LAST_VALUE / NTH_VALUE
SELECT
    name,
    salary,
    FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC) AS highest_paid,
    NTH_VALUE(name, 2) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS second_highest
FROM employees;

-- Running totals and averages
SELECT
    date,
    amount,
    SUM(amount) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
    AVG(amount) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM transactions;

-- FILTER clause (aggregate filter, not window-specific but often combined)
SELECT
    department,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE salary > 100000) AS high_earners
FROM employees
GROUP BY department;
```

### Named Window Definitions

```sql
SELECT
    name,
    department,
    salary,
    ROW_NUMBER() OVER w AS row_num,
    SUM(salary) OVER w AS running_salary
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC);
```

## RETURNING Clause

Works with `INSERT`, `UPDATE`, and `DELETE`:

```sql
-- INSERT ... RETURNING
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')
RETURNING id, created_at;

-- UPDATE ... RETURNING (get the old and new values)
UPDATE products SET price = price * 1.1 WHERE category = 'electronics'
RETURNING id, name, price AS new_price;

-- DELETE ... RETURNING
DELETE FROM sessions WHERE expired_at < now()
RETURNING id, user_id;
```

**Rule:** Use `RETURNING` instead of a separate `SELECT` after `INSERT`/`UPDATE`. It is atomic and avoids a round trip.

## Full-Text Search

### Basic Setup

```sql
-- Add a generated tsvector column for efficient searching
ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    ) STORED;

-- Create a GIN index on the tsvector column
CREATE INDEX idx_articles_search ON articles USING gin (search_vector);

-- Query with ranking
SELECT
    id,
    title,
    ts_rank(search_vector, query) AS rank,
    ts_headline('english', body, query, 'StartSel=<b>, StopSel=</b>, MaxWords=50') AS snippet
FROM articles,
     websearch_to_tsquery('english', 'postgresql performance tuning') AS query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
```

### Query Functions

| Function | Input | Use Case |
|----------|-------|----------|
| `to_tsquery('english', 'cat & dog')` | Boolean syntax (`&`, `|`, `!`, `<->`) | Programmatic queries |
| `plainto_tsquery('english', 'cat dog')` | Plain text, ANDs all words | Simple search |
| `phraseto_tsquery('english', 'cat dog')` | Phrase (proximity) | Exact phrase match |
| `websearch_to_tsquery('english', '"cat dog" -fish')` | Google-like syntax | User-facing search (PG 11+) |

### Ranking

- `ts_rank(vector, query)`: Frequency-based ranking.
- `ts_rank_cd(vector, query)`: Cover density ranking (considers proximity of matching terms).

## Array Operations

```sql
-- ANY / ALL
SELECT * FROM products WHERE 'electronics' = ANY(tags);
SELECT * FROM products WHERE tags @> ARRAY['electronics', 'sale'];  -- contains all
SELECT * FROM products WHERE tags && ARRAY['electronics', 'sale'];  -- overlaps (any match)

-- Unnest: expand array to rows
SELECT id, unnest(tags) AS tag FROM products;

-- Aggregate back to array
SELECT customer_id, array_agg(DISTINCT tag ORDER BY tag) AS all_tags
FROM orders, unnest(tags) AS tag
GROUP BY customer_id;

-- Array modification
UPDATE products SET tags = array_append(tags, 'featured') WHERE id = 1;
UPDATE products SET tags = array_remove(tags, 'sale') WHERE id = 1;

-- Index for array containment queries
CREATE INDEX idx_products_tags ON products USING gin (tags);
```

## JSONB Operations

### Operators

```sql
-- Access operators
SELECT payload->'user' AS user_json FROM events;          -- returns jsonb
SELECT payload->>'user' AS user_text FROM events;          -- returns text
SELECT payload#>'{user,address}' AS address FROM events;   -- path access, returns jsonb
SELECT payload#>>'{user,address,city}' AS city FROM events; -- path access, returns text

-- Containment (very fast with GIN index)
SELECT * FROM events WHERE payload @> '{"type": "purchase"}'::jsonb;

-- Key existence
SELECT * FROM events WHERE payload ? 'error';              -- has key
SELECT * FROM events WHERE payload ?| array['error','warning']; -- has any key
SELECT * FROM events WHERE payload ?& array['user','type'];     -- has all keys

-- Modification
UPDATE events SET payload = jsonb_set(payload, '{status}', '"processed"') WHERE id = 1;
UPDATE events SET payload = payload || '{"processed": true}'::jsonb WHERE id = 1;
UPDATE events SET payload = payload - 'temporary_field' WHERE id = 1;  -- remove key
```

### JSONPath (PG 12+)

```sql
-- JSONPath queries
SELECT * FROM events
WHERE payload @? '$.items[*] ? (@.price > 100)';

-- Extract with JSONPath
SELECT jsonb_path_query_array(payload, '$.items[*].name') FROM events WHERE id = 1;
```

### JSONB Indexing Strategies

```sql
-- Default GIN: supports @>, ?, ?|, ?&
CREATE INDEX idx_events_payload ON events USING gin (payload);

-- jsonb_path_ops: smaller index, supports only @> containment
CREATE INDEX idx_events_payload_path ON events USING gin (payload jsonb_path_ops);

-- Expression index on a specific key (B-tree, for equality/range on one field)
CREATE INDEX idx_events_type ON events ((payload->>'type'));
```

## INSERT ON CONFLICT (Upsert)

```sql
-- DO NOTHING: skip on conflict
INSERT INTO user_settings (user_id, key, value)
VALUES (1, 'theme', 'dark')
ON CONFLICT (user_id, key) DO NOTHING;

-- DO UPDATE with EXCLUDED pseudo-table
INSERT INTO inventory (product_id, warehouse_id, quantity)
VALUES (101, 1, 50)
ON CONFLICT (product_id, warehouse_id)
DO UPDATE SET
    quantity = inventory.quantity + EXCLUDED.quantity,
    updated_at = now()
RETURNING *;

-- With partial unique index
CREATE UNIQUE INDEX uq_active_subscription ON subscriptions (user_id) WHERE (status = 'active');

INSERT INTO subscriptions (user_id, plan, status)
VALUES (1, 'premium', 'active')
ON CONFLICT (user_id) WHERE (status = 'active')
DO UPDATE SET plan = EXCLUDED.plan, updated_at = now();
```

## LATERAL Joins

`LATERAL` allows a subquery in `FROM` to reference columns from preceding tables, like a correlated subquery but usable as a join target:

```sql
-- Top-N per group: get the 3 most recent orders per customer
SELECT c.id, c.name, recent.order_id, recent.total, recent.created_at
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.id AS order_id, o.total, o.created_at
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.created_at DESC
    LIMIT 3
) recent
WHERE c.status = 'active';

-- Replace correlated subquery for better performance
-- Instead of: SELECT *, (SELECT max(total) FROM orders WHERE customer_id = c.id) ...
SELECT c.*, best.max_total
FROM customers c
LEFT JOIN LATERAL (
    SELECT max(total) AS max_total
    FROM orders
    WHERE customer_id = c.id
) best ON true;
```

`LATERAL` often outperforms equivalent correlated subqueries because the planner can choose better join strategies.

## Pagination

### LIMIT/OFFSET Problems

```sql
-- Simple but problematic at scale
SELECT * FROM products ORDER BY created_at DESC LIMIT 20 OFFSET 10000;
-- PostgreSQL must scan and discard 10000 rows. Gets slower with deeper pages.
```

### Keyset Pagination (Cursor-Based)

```sql
-- First page
SELECT id, name, created_at
FROM products
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Next page: use the last row's values as cursor
SELECT id, name, created_at
FROM products
WHERE (created_at, id) < (@LastCreatedAt, @LastId)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

**Benefits of keyset pagination:**
- Constant performance regardless of page depth.
- Stable results even when new rows are inserted.
- Works well with B-tree indexes on the sort columns.

**Limitation:** Cannot jump to an arbitrary page number. Use OFFSET only when you need random page access on small result sets.

### Keyset Pagination in Dapper (.NET)

```csharp
var nextPage = await conn.QueryAsync<Product>(
    @"SELECT id, name, created_at
      FROM products
      WHERE (created_at, id) < (@LastCreatedAt, @LastId)
      ORDER BY created_at DESC, id DESC
      LIMIT @PageSize",
    new { LastCreatedAt = cursor.CreatedAt, LastId = cursor.Id, PageSize = 20 });
```

### Keyset Pagination in Node.js

```javascript
const { rows } = await pool.query(
  `SELECT id, name, created_at
   FROM products
   WHERE (created_at, id) < ($1, $2)
   ORDER BY created_at DESC, id DESC
   LIMIT $3`,
  [cursor.createdAt, cursor.id, 20]
);
```

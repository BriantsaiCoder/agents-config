# Window Functions and CTEs

Use window functions for analytics that need a row-level value derived from a group (running totals, rankings, lag/lead). They avoid self-joins and subqueries that don't scale.

## Common Patterns

```sql
SELECT
    product_id,
    sale_date,
    amount,
    SUM(amount) OVER (PARTITION BY product_id ORDER BY sale_date) AS running_total,
    AVG(amount) OVER (
        PARTITION BY product_id ORDER BY sale_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3,
    DENSE_RANK() OVER (
        PARTITION BY EXTRACT(month FROM sale_date) ORDER BY amount DESC
    ) AS monthly_rank,
    LAG(amount, 1) OVER (PARTITION BY product_id ORDER BY sale_date) AS prev_amount,
    LEAD(amount, 1) OVER (PARTITION BY product_id ORDER BY sale_date) AS next_amount
FROM sales;
```

## Frame Clauses

| Frame | Meaning |
|---|---|
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | Running aggregate up to current row |
| `ROWS BETWEEN N PRECEDING AND CURRENT ROW` | Trailing N-row window (moving average) |
| `RANGE BETWEEN INTERVAL '7 day' PRECEDING AND CURRENT ROW` | Time-based window (PG 11+) |

`ROWS` is positional; `RANGE` is value-based and slower but correct for ties / time gaps.

## Recursive CTE for Hierarchies

```sql
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS level
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree ORDER BY level, name;
```

Add a depth guard (`WHERE ct.level < 50`) on user-controlled trees to prevent runaway recursion.

## CTE Materialization (PG 12+)

CTEs were always materialized (an optimization fence) before PG 12. From PG 12 they inline by default — usually faster. Force the old behavior only when you need fence semantics:

```sql
WITH expensive AS MATERIALIZED ( ... )    -- force fence (compute once)
WITH cheap     AS NOT MATERIALIZED ( ... ) -- force inline (default in PG 12+)
```

## Anti-Patterns

- **Using a self-join where a window function would do** — `ROW_NUMBER()` and `LAG()` are O(n log n); self-joins are O(n²).
- **`ORDER BY` inside the window without a `PARTITION`** — you almost always want partitioning, otherwise the running aggregate is global.
- **Recursive CTE without a termination clause / depth limit** — looped data (`A→B→A`) hangs the query.

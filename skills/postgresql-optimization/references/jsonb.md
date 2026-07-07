# JSONB Operations and Indexing

JSONB stores parsed JSON as a binary structure. Use it when the schema is genuinely heterogeneous; use regular columns when it isn't. JSONB is slower to write than `jsonb`-free schemas and harder to constrain.

## Containment vs Path Queries

```sql
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Containment (uses GIN index): "data has these key/value pairs"
SELECT * FROM events WHERE data @> '{"type": "login"}';

-- Existence: "data has this top-level key"
SELECT * FROM events WHERE data ? 'user_id';

-- Path extraction (does NOT use GIN by default)
SELECT * FROM events WHERE data #>> '{user,role}' = 'admin';

-- Aggregation
SELECT jsonb_agg(data) FROM events WHERE data ? 'user_id';
```

## GIN Index Variants

| Operator class | Supports | Size | Build speed |
|---|---|---|---|
| `gin_jsonb_ops` (default) | `?`, `?&`, `?|`, `@>`, `@?`, `@@` | Larger | Slower |
| `jsonb_path_ops` | `@>`, `@?`, `@@` only | ~3× smaller | ~3× faster |

```sql
-- Default — supports more operators
CREATE INDEX idx_events_data_gin ON events USING gin(data);

-- jsonb_path_ops — pick when you only need containment (most common)
CREATE INDEX idx_events_data_path ON events USING gin(data jsonb_path_ops);

-- Functional index on a single key — smallest, fastest for one access pattern
CREATE INDEX idx_events_type ON events ((data->>'type'));
```

Pick `jsonb_path_ops` unless you actually use `?`/`?&`/`?|`. For one hot key, prefer a functional index on the extracted column.

## Anti-Patterns

- **JSONB for fields you always query** — promote to a regular column. JSONB compares are 3–10× slower.
- **`data::text LIKE '%foo%'`** — bypasses every index. Use `@>` or `jsonb_path_ops`.
- **Updating JSONB in place at high frequency** — every update rewrites the entire JSONB value (no in-place patching). Split hot fields out.
- **Indexing JSONB without analyzing query shape** — default `gin_jsonb_ops` is huge; most workloads only need `jsonb_path_ops`.

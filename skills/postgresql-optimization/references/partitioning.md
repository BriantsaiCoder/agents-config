# Partitioning, Range Types, and Spatial Constraints

## Declarative Partitioning (PG 10+)

Partition when a single table exceeds ~50–100M rows AND queries usually filter on the partition key. Don't partition prematurely — partition pruning adds planning overhead.

```sql
CREATE TABLE events (
    id BIGSERIAL,
    occurred_at TIMESTAMPTZ NOT NULL,
    payload JSONB,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE events_2026q1 PARTITION OF events
    FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE events_2026q2 PARTITION OF events
    FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');

-- Default catches everything outside defined ranges (avoid in prod — silent surprise)
CREATE TABLE events_default PARTITION OF events DEFAULT;
```

| Strategy | Use for |
|---|---|
| `RANGE` | Time-series, numeric ranges (most common) |
| `LIST`  | Discrete categories (region, tenant) |
| `HASH`  | Even distribution when no natural key (rare) |

Indexes / constraints on the parent table apply to each partition automatically (PG 11+).

### Operations

```sql
-- Detach without rewriting data (PG 14+: CONCURRENTLY)
ALTER TABLE events DETACH PARTITION events_2024q1 CONCURRENTLY;

-- Attach existing table as partition (must satisfy bounds)
ALTER TABLE events ATTACH PARTITION events_2027q1
    FOR VALUES FROM ('2027-01-01') TO ('2027-04-01');
```

Drop old partitions with `DROP TABLE events_2024q1` — instant, no `DELETE` overhead.

## Range Types

```sql
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    room_id INTEGER NOT NULL,
    period TSTZRANGE NOT NULL,
    price_range NUMRANGE
);

-- Overlap query
SELECT * FROM reservations
WHERE period && tstzrange('2026-07-20', '2026-07-25', '[)');

-- Exclusion constraint: no two reservations on the same room overlap
ALTER TABLE reservations ADD CONSTRAINT no_overlap
    EXCLUDE USING gist (room_id WITH =, period WITH &&);
```

Bracket notation: `[` / `]` inclusive, `(` / `)` exclusive. Default for `tstzrange` is `[)`.

## Geometric Types and GiST

```sql
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    coords POINT NOT NULL,
    service_area POLYGON
);

CREATE INDEX idx_locations_coords ON locations USING gist(coords);

-- Nearest-N (KNN) query
SELECT name, coords <-> point(40.7128, -74.0060) AS dist
FROM locations
ORDER BY coords <-> point(40.7128, -74.0060)
LIMIT 5;
```

For real GIS work, use **PostGIS** — `geometry`/`geography` types, SRIDs, spatial joins, raster. The built-in `point`/`polygon` types are unprojected and sufficient only for toy cases.

## Anti-Patterns

- **Partitioning small tables "in case they grow"** — partition planning cost outweighs the benefit until you actually have the rows.
- **Cross-partition unique indexes** — not supported. Either include the partition key in the unique constraint, or enforce uniqueness in app code.
- **`DEFAULT` partition in production without monitoring** — rows that don't match any range silently land there and never benefit from pruning.
- **Built-in geometric types where PostGIS belongs** — no projection support; distance is in arbitrary units.

# PostgreSQL Schema Design

## Data Type Cheat Sheet

### Integer Types

| Type | Size | Range | Notes |
|------|------|-------|-------|
| `smallint` | 2 bytes | -32,768 to 32,767 | Use for enums, small counters |
| `integer` | 4 bytes | -2.1B to 2.1B | Default choice for most IDs and counts |
| `bigint` | 8 bytes | -9.2E18 to 9.2E18 | Large sequences, distributed systems |
| `serial` | 4 bytes | Auto-incrementing `integer` | Legacy; prefer `GENERATED ALWAYS AS IDENTITY` |
| `bigserial` | 8 bytes | Auto-incrementing `bigint` | Legacy; prefer `GENERATED ALWAYS AS IDENTITY` |

Prefer `GENERATED ALWAYS AS IDENTITY` (SQL standard) over `serial`/`bigserial`:

```sql
CREATE TABLE orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ...
);
```

### Numeric / Decimal Types

| Type | Storage | Precision | Use Case |
|------|---------|-----------|----------|
| `numeric(p,s)` / `decimal(p,s)` | Variable | Exact | Money, financial calculations |
| `real` | 4 bytes | 6 decimal digits | Scientific data, non-critical approximation |
| `double precision` | 8 bytes | 15 decimal digits | Scientific data, geospatial calculations |

**Rule:** Never use `real` or `double precision` for money. Use `numeric(19,4)` or similar.

### Text Types

| Type | Notes |
|------|-------|
| `text` | Unlimited length, preferred for most string columns |
| `varchar(n)` | Use only when you need a hard length constraint enforced at the DB level |
| `char(n)` | Fixed-width, padded with spaces; almost never useful |

PostgreSQL stores `text` and `varchar` identically internally. Prefer `text` with a `CHECK` constraint when you need length validation:

```sql
ALTER TABLE users ADD CONSTRAINT chk_email_length CHECK (length(email) <= 320);
```

### Boolean

`boolean` stores `TRUE`, `FALSE`, or `NULL`. Use it; do not use `smallint` with 0/1 conventions.

### UUID

Native 16-byte type. Highly efficient for storage and comparison.

```sql
-- PG 13+: no extension needed
CREATE TABLE events (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY
);
```

For sequential (time-sortable) UUIDs, use UUIDv7. PG 18+ generates it natively with `uuidv7()`; on PG 17 and earlier, generate it outside core:
- Generate in the application layer (C#: `Guid.CreateVersion7()` in .NET 9+, or `UUIDNext` package; Node.js: `uuid` package v10+)
- Use a PL/pgSQL function or the `pg_uuidv7` extension

**UUID vs BIGSERIAL trade-offs:**

| Factor | UUID | BIGSERIAL |
|--------|------|-----------|
| Size | 16 bytes | 8 bytes |
| Index size | Larger (~1.5x) | Smaller |
| Merge-friendly | Yes (no conflicts) | Requires sequences coordination |
| Guessable | No | Yes (sequential) |
| Sort by creation | Only with UUIDv7 | Natural ordering |

### Timestamp Types

| Type | Stores | Use When |
|------|--------|----------|
| `timestamptz` | UTC internally, displays in session timezone | **Always for wall-clock times** |
| `timestamp` (without tz) | Raw value, no timezone context | Theoretical/abstract times only (rare) |
| `date` | Date only | Birth dates, calendar dates |
| `time` | Time of day | Scheduling (opening hours) |
| `interval` | Duration | Time differences, durations |

**Rule:** Always use `timestamptz` for any real-world event time. The `timestamp` (without time zone) type loses timezone context and causes bugs when servers or sessions change timezone settings.

```sql
CREATE TABLE audit_log (
    created_at timestamptz NOT NULL DEFAULT now(),
    -- NOT: created_at timestamp
);
```

### Array Types

PostgreSQL supports arrays of any built-in type:

```sql
CREATE TABLE products (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tags text[] NOT NULL DEFAULT '{}',
    scores integer[]
);

-- Insert
INSERT INTO products (tags) VALUES (ARRAY['electronics', 'sale']);
INSERT INTO products (tags) VALUES ('{"electronics","sale"}');  -- alternative syntax
```

Use arrays for small, fixed-purpose lists. For large or queryable collections, use a separate table.

### JSONB vs JSON

| Type | Storage | Indexable | Operators | Use Case |
|------|---------|-----------|-----------|----------|
| `jsonb` | Binary, decomposed | Yes (GIN) | Full operator set | **Default choice** |
| `json` | Raw text, preserved | No | Limited | Exact formatting preservation only |

**Rule:** Always use `jsonb`. Never store structured data as `text`.

```sql
CREATE TABLE api_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payload jsonb NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_api_events_payload ON api_events USING gin (payload);
```

### Enum Types

```sql
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled');

CREATE TABLE orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status order_status NOT NULL DEFAULT 'pending'
);
```

Enums are 4 bytes internally, provide type safety, and prevent invalid values. Adding new values is easy (`ALTER TYPE ... ADD VALUE`), but removing or renaming values requires migration care.

### Range Types

| Type | Element Type | Use Case |
|------|-------------|----------|
| `int4range` | `integer` | Integer intervals |
| `int8range` | `bigint` | Large integer intervals |
| `numrange` | `numeric` | Decimal intervals |
| `tstzrange` | `timestamptz` | Time periods (bookings, schedules) |
| `daterange` | `date` | Date periods (reservations) |

```sql
CREATE TABLE reservations (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id integer NOT NULL,
    during tstzrange NOT NULL,
    EXCLUDE USING gist (room_id WITH =, during WITH &&)  -- no overlapping bookings
);

INSERT INTO reservations (room_id, during)
VALUES (1, tstzrange('2025-01-01 14:00+00', '2025-01-01 16:00+00'));
```

### Network Types

| Type | Stores | Notes |
|------|--------|-------|
| `inet` | IP address with optional subnet | IPv4 or IPv6, supports operators |
| `cidr` | Network address | Enforces valid network addresses |
| `macaddr` | MAC address | 6-byte hardware address |

```sql
CREATE TABLE access_log (
    client_ip inet NOT NULL,
    network cidr
);

-- Query: find all entries in a subnet
SELECT * FROM access_log WHERE client_ip << '192.168.1.0/24';
```

### Composite Types

```sql
CREATE TYPE address AS (
    street text,
    city text,
    postal_code text,
    country text
);

CREATE TABLE warehouses (
    id integer PRIMARY KEY,
    location address
);
```

Use sparingly. Separate tables are usually cleaner for complex nested data.

### bytea

Stores raw binary data (up to 1 GB). Use for small binary blobs (hashes, tokens, small files). For large files, consider Large Objects or external storage.

## C# Type Mapping (Npgsql)

| PostgreSQL | C# | Notes |
|------------|-----|-------|
| `smallint` | `short` | |
| `integer` | `int` | |
| `bigint` | `long` | |
| `boolean` | `bool` | |
| `real` | `float` | |
| `double precision` | `double` | |
| `numeric` | `decimal` | |
| `text` / `varchar` | `string` | |
| `uuid` | `Guid` | |
| `timestamptz` | `DateTimeOffset` or `DateTime` (UTC) | Npgsql 6+ enforces Kind |
| `timestamp` | `DateTime` (Unspecified Kind) | |
| `date` | `DateOnly` (.NET 6+) or `DateTime` | |
| `time` | `TimeOnly` (.NET 6+) or `TimeSpan` | |
| `interval` | `TimeSpan` or `NpgsqlInterval` | |
| `jsonb` / `json` | `string` or `JsonDocument` or POCO | Npgsql 8+ supports POCO mapping |
| `integer[]` | `int[]` | |
| `text[]` | `string[]` | |
| `bytea` | `byte[]` | |
| `inet` | `IPAddress` or `NpgsqlInet` | |

## Node.js Type Mapping (pg / node-postgres)

| PostgreSQL | JavaScript | Notes |
|------------|-----------|-------|
| `smallint` / `integer` | `number` | Parsed as integer |
| `bigint` | `string` (default) | Use `parseInt` or `BigInt`; override with custom parser |
| `boolean` | `boolean` | |
| `real` / `double precision` | `number` | |
| `numeric` | `string` (default) | Precision loss if parsed to `number`; use libraries for exact math |
| `text` / `varchar` | `string` | |
| `uuid` | `string` | |
| `timestamptz` | `Date` | pg parses to JS Date by default |
| `timestamp` | `Date` | **Caution:** pg assumes local timezone; use custom parser for UTC |
| `date` | `Date` | Override parser to avoid timezone shift |
| `jsonb` / `json` | `object` | Automatically parsed |
| `integer[]` / `text[]` | `Array` | Automatically parsed |
| `bytea` | `Buffer` | |
| `inet` | `string` | |

## Generated Columns

PostgreSQL supports `STORED` generated columns only (no `VIRTUAL`):

```sql
CREATE TABLE products (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    price_cents integer NOT NULL,
    quantity integer NOT NULL,
    total_cents integer GENERATED ALWAYS AS (price_cents * quantity) STORED
);
```

The value is computed on write and physically stored. Useful for indexed expressions and denormalization.

## Declarative Partitioning

### RANGE Partitioning (Most Common)

```sql
CREATE TABLE measurements (
    id bigint GENERATED ALWAYS AS IDENTITY,
    recorded_at timestamptz NOT NULL,
    device_id integer NOT NULL,
    value double precision
) PARTITION BY RANGE (recorded_at);

CREATE TABLE measurements_2025_q1 PARTITION OF measurements
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
CREATE TABLE measurements_2025_q2 PARTITION OF measurements
    FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');

-- Default partition catches anything that does not match
CREATE TABLE measurements_default PARTITION OF measurements DEFAULT;
```

### LIST Partitioning

```sql
CREATE TABLE orders (
    id bigint GENERATED ALWAYS AS IDENTITY,
    region text NOT NULL,
    total numeric
) PARTITION BY LIST (region);

CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('EU', 'UK');
```

### HASH Partitioning

```sql
CREATE TABLE sessions (
    id uuid DEFAULT gen_random_uuid(),
    user_id bigint NOT NULL,
    data jsonb
) PARTITION BY HASH (user_id);

CREATE TABLE sessions_p0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_p1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_p2 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_p3 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

### Partition Management

- **Partition pruning** is automatic when the partition key appears in `WHERE` clauses.
- **Detach/Attach** for maintenance: `ALTER TABLE measurements DETACH PARTITION measurements_2024_q1;` (can be `CONCURRENTLY` in PG 14+).
- **Partition-wise JOIN/aggregation:** Enable with `SET enable_partitionwise_join = on;` and `SET enable_partitionwise_aggregate = on;` for queries that join or aggregate across partitions on the partition key.

## Naming Conventions

- **snake_case** for everything: tables, columns, indexes, constraints, functions.
- **Singular** table names: `order`, `user_account` (not `orders`, `user_accounts`). Alternatively, pick one convention and be consistent.
- **_id suffix** for foreign keys: `customer_id`, `order_id`.
- **idx_** prefix for indexes: `idx_order_customer_id`.
- **chk_** prefix for check constraints: `chk_order_total_positive`.
- **uq_** prefix for unique constraints: `uq_user_email`.
- **fk_** prefix for foreign keys: `fk_order_customer`.

## Constraint Design

### PRIMARY KEY

```sql
CREATE TABLE users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
```

### UNIQUE (including Partial Unique)

```sql
-- Full unique
ALTER TABLE users ADD CONSTRAINT uq_user_email UNIQUE (email);

-- Partial unique: only one active email per user
CREATE UNIQUE INDEX uq_user_active_email ON users (email) WHERE (is_active = true);
```

### CHECK

```sql
ALTER TABLE orders ADD CONSTRAINT chk_order_total_positive CHECK (total >= 0);
ALTER TABLE users ADD CONSTRAINT chk_user_age CHECK (age BETWEEN 0 AND 150);
```

### EXCLUDE (Range Non-Overlap)

```sql
-- Requires btree_gist extension for combining equality with range overlap
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE reservations ADD CONSTRAINT excl_room_overlap
    EXCLUDE USING gist (room_id WITH =, during WITH &&);
```

### FOREIGN KEY

```sql
ALTER TABLE orders ADD CONSTRAINT fk_order_customer
    FOREIGN KEY (customer_id) REFERENCES customers (id)
    ON DELETE CASCADE;    -- or SET NULL, RESTRICT, NO ACTION (default)
```

- `CASCADE`: Deleting a customer deletes all their orders.
- `SET NULL`: Deleting a customer sets `customer_id` to NULL on their orders.
- `RESTRICT`: Prevents deleting a customer who has orders.

## Domain Types

Reusable constraints packaged as types:

```sql
CREATE DOMAIN email_address AS text
    CHECK (VALUE ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$');

CREATE DOMAIN positive_integer AS integer
    CHECK (VALUE > 0);

CREATE TABLE contacts (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email email_address NOT NULL,
    priority positive_integer NOT NULL DEFAULT 1
);
```

Domains are especially useful when the same constraint applies to many columns across multiple tables.

## Data Types to Avoid

Each has a better replacement:

- `timestamp` (without time zone) → use `timestamptz` for wall-clock times.
- `char(n)` / `varchar(n)` → use `text` + `CHECK (length(col) <= n)` if you need a limit. Storage is identical; `text` avoids silent padding/truncation surprises.
- `money` → use `numeric(p, s)`. `money` is locale-dependent and lossy across currencies.
- `timetz` → use `timestamptz`. Timezone information on a bare time value is ambiguous without a date.
- `timestamptz(0)` or any fractional-second precision → use plain `timestamptz` (microsecond precision is free).
- `serial` / `bigserial` → use `bigint GENERATED ALWAYS AS IDENTITY` (SQL standard, better ownership semantics, no implicit sequence grants).

## UNIQUE and NULLs

`UNIQUE` treats `NULL` as distinct by default, so multiple `NULL`s are allowed. Use `NULLS NOT DISTINCT` (PG 15+) when you want at most one NULL in the column:

```sql
ALTER TABLE users ADD CONSTRAINT uq_external_id
    UNIQUE NULLS NOT DISTINCT (external_id);
```

## DEFERRABLE Foreign Keys

For circular FK dependencies or bulk loads where rows reference each other in an unpredictable order, declare the constraint `DEFERRABLE INITIALLY DEFERRED` — it is checked at transaction commit instead of per statement:

```sql
ALTER TABLE orders ADD CONSTRAINT fk_order_customer
    FOREIGN KEY (customer_id) REFERENCES customers (id)
    DEFERRABLE INITIALLY DEFERRED;
```

Keep DEFERRABLE off for hot paths — immediate checks let the planner use the FK for joins and catch bad data earlier.

## Table Types: Regular vs UNLOGGED vs TEMPORARY

- **Regular** — default; WAL-logged, replicated, crash-safe.
- **UNLOGGED** — persistent but not WAL-logged; 2–5× faster writes. Contents are **truncated on crash** and not replicated. Use for caches, staging, derivable data only.
- **TEMPORARY** — session-scoped, auto-dropped on disconnect, not visible to other sessions. Use for scratch computation in stored procedures / ETL.

```sql
CREATE UNLOGGED TABLE import_staging (...);   -- fast bulk load target
CREATE TEMP TABLE tmp_batch (...) ON COMMIT DROP;  -- scratchpad
```

## Update-Heavy Tables: HOT Updates and fillfactor

PostgreSQL's MVCC creates a new row version on every UPDATE. **HOT (Heap-Only Tuple) updates** avoid rewriting indexes when the update (a) does not touch any indexed column and (b) the new row version fits on the same page. Enable them with a lower `fillfactor`:

```sql
ALTER TABLE sessions SET (fillfactor = 80);   -- leave 20% free per page
```

- Prefer fillfactor 80–90 for update-heavy OLTP tables. Keep 100 (default) for append-only.
- Avoid indexing columns that are frequently updated — every index on a mutated column breaks HOT.
- Separate hot (frequently updated) and cold columns into two tables joined by PK when row width and update frequency are both high.

## TOAST (Large Value Storage)

Values > ~2 KB are automatically compressed and/or moved out-of-line into a TOAST table. Default `EXTENDED` (compress + out-of-line) is almost always right; use `EXTERNAL` (no compression) when you substring/slice large text often. Tune per column with `ALTER TABLE t ALTER COLUMN c SET STORAGE EXTERNAL;`.

## Safe Schema Evolution

- **CREATE INDEX CONCURRENTLY** — non-blocking; cannot run in a transaction and leaves `INVALID` indexes on failure (drop and retry).
- **Volatile defaults rewrite the table** — `ADD COLUMN ... DEFAULT now()` / `gen_random_uuid()` rewrites every row. Non-volatile constants are metadata-only (PG 11+).
- **DROP CONSTRAINT before DROP COLUMN** to avoid dependency errors. Most DDL is transactional — smoke-test with `BEGIN; ... ROLLBACK;`.
- Set a short `lock_timeout` for online schema changes so long waiters bail instead of queueing.

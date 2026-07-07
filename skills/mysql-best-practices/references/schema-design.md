# Schema Design

Reference for rules 1, 2, 3, 7 in SKILL.md. Read this when designing tables, choosing data types, or planning indexes.

## Table of contents
- [Data type cheat sheet](#data-type-cheat-sheet)
- [C# type mapping (MySqlConnector / Dapper)](#c-type-mapping)
- [Node.js type mapping (mysql2)](#nodejs-type-mapping)
- [Character set: always utf8mb4](#character-set-always-utf8mb4)
- [Primary key strategies](#primary-key-strategies)
- [Composite index design](#composite-index-design)
- [Index types](#index-types)
- [Partitioning](#partitioning)
- [Generated columns](#generated-columns)

---

## Data type cheat sheet

### Integer types

| Type | Bytes | Signed range | Unsigned range | Use when |
|---|---|---|---|---|
| `TINYINT` | 1 | -128 to 127 | 0 to 255 | Status codes, boolean flags, small enums |
| `SMALLINT` | 2 | -32768 to 32767 | 0 to 65535 | Port numbers, small counters |
| `MEDIUMINT` | 3 | -8M to 8M | 0 to 16M | Rarely used; prefer INT |
| `INT` | 4 | -2.1B to 2.1B | 0 to 4.2B | General-purpose integer |
| `BIGINT` | 8 | -9.2E18 to 9.2E18 | 0 to 18.4E18 | Primary keys, large counters, timestamps-as-epoch |

**Rule of thumb:** Use `BIGINT UNSIGNED` for auto-increment PKs on any table that could exceed 2 billion rows or where you want headroom. Use `INT` for foreign keys to small lookup tables. Use `TINYINT` for booleans (`BOOLEAN` is an alias for `TINYINT(1)`).

### Decimal / floating-point

| Type | Bytes | Precision | Use when |
|---|---|---|---|
| `DECIMAL(M,D)` | Variable | Exact to M digits, D after decimal | Money, financial calculations, anything requiring exact arithmetic |
| `FLOAT` | 4 | ~7 significant digits | Scientific data where approximate is OK |
| `DOUBLE` | 8 | ~15 significant digits | Scientific data, GPS coordinates where approximate is OK |

**Never use FLOAT or DOUBLE for money.** Rounding errors accumulate. Use `DECIMAL(19,4)` for currency.

### String types

| Type | Max length | Storage | Use when |
|---|---|---|---|
| `VARCHAR(N)` | 65,535 bytes (minus row overhead) | Length prefix + data | Most strings: names, emails, URLs, short descriptions |
| `CHAR(N)` | 255 bytes | Fixed N bytes | Fixed-length codes (ISO country codes, UUIDs stored as CHAR(36)) |
| `TINYTEXT` | 255 bytes | Length prefix + data | Rarely useful; prefer VARCHAR |
| `TEXT` | 64 KB | Stored off-page (usually) | Medium-length user content |
| `MEDIUMTEXT` | 16 MB | Off-page | Articles, large documents |
| `LONGTEXT` | 4 GB | Off-page | Extremely large text (audit logs, serialized payloads) |

**VARCHAR vs TEXT:** Prefer `VARCHAR(N)` when you know the max length. TEXT columns cannot have a default value (before 8.0.13), cannot be fully indexed (only prefix indexes), and are stored off-page in InnoDB if they exceed ~768 bytes.

### Date / time types

| Type | Range | Storage | Timezone behavior | Use when |
|---|---|---|---|---|
| `DATETIME` | 1000-01-01 to 9999-12-31 | 5 bytes (+ 3 for fractional seconds) | Stored as-is, no conversion | Calendar dates that should not shift with server timezone changes |
| `TIMESTAMP` | 1970-01-01 to 2038-01-19 | 4 bytes (+ 3 for fractional seconds) | Stored as UTC, converted to session timezone on read | Event timestamps, audit trails; beware 2038 limit |
| `DATE` | 1000-01-01 to 9999-12-31 | 3 bytes | None | Birth dates, calendar dates without time |
| `TIME` | -838:59:59 to 838:59:59 | 3 bytes (+ 3 for fractional) | None | Duration, time-of-day |
| `YEAR` | 1901 to 2155 | 1 byte | None | Rarely used |

**DATETIME vs TIMESTAMP:** Use `DATETIME(6)` (with microsecond precision) as default choice for most applications. TIMESTAMP auto-converts to UTC which can be useful for distributed systems, but has the 2038 limit and surprising behavior when the server timezone changes. If you use TIMESTAMP, always set `explicit_defaults_for_timestamp=ON`.

### JSON type (5.7+)

```sql
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    metadata JSON NOT NULL,
    -- Index a specific JSON path via generated column
    customer_email VARCHAR(255) GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.email'))) STORED,
    INDEX idx_customer_email (customer_email)
) ENGINE=InnoDB;
```

- Validated on write (invalid JSON is rejected).
- Stored in binary format for faster access than TEXT.
- Cannot be indexed directly; use generated columns + BTREE index for query paths.
- Maximum size limited by `max_allowed_packet` (default 64 MB).

### ENUM type

```sql
CREATE TABLE tickets (
    status ENUM('open', 'in_progress', 'resolved', 'closed') NOT NULL DEFAULT 'open'
);
```

- Stored as 1-2 bytes internally (index into the enum list).
- Adding values to the **end** of the list is an online DDL operation (ALGORITHM=INSTANT in 8.0).
- Inserting/removing values from the **middle** requires a table rebuild.
- **Prefer a lookup table** for values that change frequently.

### BINARY / BLOB types

| Type | Max length | Use when |
|---|---|---|
| `BINARY(N)` | 255 bytes | Fixed-length binary (UUID as 16 bytes, hashes) |
| `VARBINARY(N)` | 65,535 bytes | Variable-length binary |
| `TINYBLOB` | 255 bytes | Small binary data |
| `BLOB` | 64 KB | Medium binary |
| `MEDIUMBLOB` | 16 MB | Images, files (but prefer object storage) |
| `LONGBLOB` | 4 GB | Large files (but really, use S3/GCS) |

**Tip:** Store UUIDs as `BINARY(16)` with `UUID_TO_BIN(uuid, 1)` (8.0+) for the most compact and index-friendly representation.

---

## C# type mapping

MySqlConnector / Dapper mapping for common MySQL types:

| MySQL type | C# type | Notes |
|---|---|---|
| `TINYINT` | `sbyte` / `byte` (unsigned) | `TINYINT(1)` maps to `bool` by default (`TreatTinyAsBoolean=true`) |
| `SMALLINT` | `short` / `ushort` | |
| `INT` | `int` / `uint` | |
| `BIGINT` | `long` / `ulong` | |
| `DECIMAL` | `decimal` | Exact mapping |
| `FLOAT` | `float` | |
| `DOUBLE` | `double` | |
| `BOOLEAN` | `bool` | Alias for TINYINT(1) |
| `VARCHAR` / `TEXT` | `string` | |
| `CHAR` | `string` | |
| `BINARY` / `VARBINARY` / `BLOB` | `byte[]` | |
| `DATETIME` | `DateTime` | |
| `TIMESTAMP` | `DateTime` | Returned as local time by default |
| `DATE` | `DateTime` | Time portion is midnight |
| `TIME` | `TimeSpan` | |
| `JSON` | `string` | Returned as string; deserialize manually |
| `ENUM` | `string` | Use `Enum.Parse<T>()` to convert |
| `GUID` (CHAR(36) or BINARY(16)) | `Guid` | Set `OldGuids=false` in connection string |

---

## Node.js type mapping

mysql2 mapping for common MySQL types:

| MySQL type | Node.js type | Notes |
|---|---|---|
| `TINYINT` / `SMALLINT` / `INT` | `number` | |
| `BIGINT` | `string` (default) or `BigInt` | Set `supportBigNumbers: true`, `bigNumberStrings: true` for safety |
| `DECIMAL` | `string` | To avoid floating-point loss; parse with a decimal library |
| `FLOAT` / `DOUBLE` | `number` | |
| `VARCHAR` / `TEXT` / `CHAR` | `string` | |
| `BINARY` / `VARBINARY` / `BLOB` | `Buffer` | |
| `DATETIME` / `TIMESTAMP` | `Date` | Set `dateStrings: true` to get string instead |
| `DATE` | `Date` | Set `dateStrings: ['DATE']` to get `YYYY-MM-DD` string |
| `TIME` | `string` | Returned as `HH:MM:SS` |
| `JSON` | `object` | mysql2 auto-parses JSON columns |
| `ENUM` | `string` | |
| `BIT(1)` | `Buffer` | Convert: `result.flag[0] === 1` |

---

## Character set: always utf8mb4

### Why utf8 is broken

MySQL's `utf8` charset is actually `utf8mb3`: it encodes only the Basic Multilingual Plane (3 bytes max). This means:
- Emoji (U+1F600 range) cannot be stored, causing silent truncation or errors.
- Some CJK unified ideographs extension B+ are lost.
- This is a MySQL-specific quirk; in every other system `utf8` means full Unicode.

### utf8mb4 is the correct choice

```sql
-- Server-level default (my.cnf)
[mysqld]
character_set_server = utf8mb4
collation_server = utf8mb4_0900_ai_ci  -- 8.0; use utf8mb4_unicode_ci for 5.7

-- Table-level
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Connection-level (MySqlConnector)
-- Add CharacterSet=utf8mb4 to connection string
```

### Collation choices

| Collation | Version | Behavior | Use when |
|---|---|---|---|
| `utf8mb4_general_ci` | 5.5+ | Fast but inaccurate for some languages | Legacy; avoid for new projects |
| `utf8mb4_unicode_ci` | 5.5+ | Unicode Collation Algorithm v4.0, case-insensitive | Default for MySQL 5.7 projects |
| `utf8mb4_0900_ai_ci` | 8.0+ | UCA v9.0, accent-insensitive, case-insensitive, faster | Default for MySQL 8.0 projects |
| `utf8mb4_0900_as_cs` | 8.0+ | Accent-sensitive, case-sensitive | When exact matching matters (passwords, codes) |
| `utf8mb4_bin` | 5.5+ | Binary comparison (byte-for-byte) | Hash values, base64 strings, case-sensitive exact match |

### Migrating from utf8 to utf8mb4

```sql
-- 1. Check current charset per table
SELECT TABLE_NAME, TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mydb' AND TABLE_COLLATION LIKE 'utf8_%' AND TABLE_COLLATION NOT LIKE 'utf8mb4%';

-- 2. Convert tables (this rebuilds the table -- schedule during maintenance)
ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- 3. Watch for index length issues:
--    utf8 VARCHAR(255) = 765 bytes index; utf8mb4 VARCHAR(255) = 1020 bytes
--    InnoDB max key length is 3072 bytes (innodb_large_prefix=ON, which is default in 5.7.7+)
--    Reduce VARCHAR length if you hit the limit.
```

---

## Primary key strategies

### Auto-increment BIGINT (preferred for most cases)

```sql
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- ...
    PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1;
```

**Pros:** Sequential inserts are optimal for InnoDB's clustered index (append-only, no page splits), 8 bytes, simple JOINs, human-readable.
**Cons:** Predictable (information disclosure risk in URLs), requires DB round-trip to get ID, replication conflicts in multi-master.

### UUID v7 / ULID (sequential, distributed-safe)

UUID v7 (RFC 9562) and ULID both embed a millisecond timestamp prefix, making them **monotonically increasing** within a node:

```sql
-- Store as BINARY(16) for space efficiency
CREATE TABLE events (
    id BINARY(16) NOT NULL,
    -- ...
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- MySQL 8.0: use UUID_TO_BIN with swap flag for index-friendliness
INSERT INTO events (id) VALUES (UUID_TO_BIN(UUID(), 1));
```

**Pros:** Generated client-side (no DB round-trip), globally unique, sequential (minimal page splits), works in distributed systems.
**Cons:** 16 bytes (vs 8 for BIGINT), less human-readable, requires `BIN_TO_UUID()` for display.

### UUID v4 (avoid for PKs)

Random UUIDs cause **severe InnoDB performance problems**:
- Random insertion into the clustered index causes page splits on every insert.
- Buffer pool efficiency drops because hot pages are scattered.
- Write amplification increases as pages are split and merged.

**If you must use UUID v4:** Store as `BINARY(16)`, consider a secondary auto-increment column for the clustered index, or use UUID v7 instead.

---

## Composite index design

### Leftmost prefix rule

A composite index `(a, b, c)` can satisfy queries on:
- `WHERE a = ?` (uses 1 column)
- `WHERE a = ? AND b = ?` (uses 2 columns)
- `WHERE a = ? AND b = ? AND c = ?` (uses all 3)
- `WHERE a = ? AND b > ?` (uses 2 columns; c is not used after a range scan on b)
- `WHERE a = ? ORDER BY b` (uses index for both filter and sort)

It **cannot** satisfy:
- `WHERE b = ?` (skips the leftmost column)
- `WHERE b = ? AND c = ?` (skips a)
- `ORDER BY b, c` without filtering on a

### Column ordering strategy

1. **Equality columns first** (highest selectivity): columns in `WHERE col = ?`.
2. **Range column next** (at most one): the column in `WHERE col > ?` or `WHERE col BETWEEN ? AND ?`.
3. **ORDER BY columns after**: if the sort matches the index order, MySQL avoids filesort.
4. **SELECT columns last** (covering): include remaining selected columns to avoid the clustered index lookup.

```sql
-- Query: WHERE tenant_id = ? AND status = ? AND created_at > ? ORDER BY created_at
-- Optimal index:
CREATE INDEX idx_tenant_status_created ON orders (tenant_id, status, created_at);
-- tenant_id (equality) -> status (equality) -> created_at (range + sort)
```

### Covering indexes

A covering index contains **all columns** referenced in the query (WHERE, ORDER BY, and SELECT). When MySQL can answer the query entirely from the index, EXPLAIN shows `Using index` in the Extra column. No clustered index lookup needed.

```sql
-- Query: SELECT id, status, created_at FROM orders WHERE tenant_id = ? AND status = ?
-- Covering index (id is in PK, which is appended to every secondary index in InnoDB):
CREATE INDEX idx_covering ON orders (tenant_id, status, created_at);
-- All needed columns (tenant_id, status, created_at, id) are in the index
```

---

## Index types

| Type | Engine | Use when | Notes |
|---|---|---|---|
| `BTREE` | InnoDB, MyISAM | Default. Range queries (`>`, `<`, `BETWEEN`), equality, `ORDER BY`, `GROUP BY` | B+Tree in InnoDB; supports prefix compression |
| `HASH` | MEMORY, NDB | Exact equality lookups only | Not available in InnoDB; Memory engine only |
| `FULLTEXT` | InnoDB (5.6+), MyISAM | Natural language text search | Use `MATCH(col) AGAINST('search terms')` syntax |
| `SPATIAL` | InnoDB (5.7+), MyISAM | Geographic data (GEOMETRY, POINT types) | Requires `NOT NULL` column; uses R-tree |

### FULLTEXT example

```sql
ALTER TABLE articles ADD FULLTEXT INDEX ft_title_body (title, body);

-- Natural language mode (default)
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('database optimization' IN NATURAL LANGUAGE MODE);

-- Boolean mode (AND, OR, NOT operators)
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('+database +optimization -mongodb' IN BOOLEAN MODE);
```

---

## Partitioning

### When to partition
- Tables with **hundreds of millions of rows** where queries always filter by the partition key.
- Time-series data where old partitions can be dropped (`ALTER TABLE t DROP PARTITION p2023`) instead of running expensive `DELETE` operations.
- **Do not partition** for tables under ~10M rows; the overhead outweighs benefits.

### RANGE partitioning (most common)

```sql
CREATE TABLE sensor_data (
    id BIGINT UNSIGNED AUTO_INCREMENT,
    sensor_id INT UNSIGNED NOT NULL,
    reading DECIMAL(10,4) NOT NULL,
    recorded_at DATETIME NOT NULL,
    PRIMARY KEY (id, recorded_at)  -- partition key must be in PK
) ENGINE=InnoDB
PARTITION BY RANGE (YEAR(recorded_at)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION pmax VALUES LESS THAN MAXVALUE
);
```

**Partition pruning:** Queries that include the partition key in WHERE will only scan relevant partitions. Verify with `EXPLAIN PARTITIONS`.

### Other strategies

| Strategy | Use when | Example |
|---|---|---|
| `RANGE` | Date-based archival, time-series | `PARTITION BY RANGE (YEAR(created_at))` |
| `LIST` | Known discrete values (region, tenant) | `PARTITION BY LIST (region_id)` |
| `HASH` | Even distribution when no natural range | `PARTITION BY HASH (user_id) PARTITIONS 8` |
| `KEY` | Like HASH but MySQL chooses the hash function | `PARTITION BY KEY (id) PARTITIONS 8` |

### Partition gotchas
- The partition key **must** be part of every unique index (including the primary key).
- Foreign keys are **not supported** on partitioned tables.
- Queries that do not filter on the partition key scan **all** partitions.

---

## Generated columns

### VIRTUAL vs STORED

| Property | VIRTUAL | STORED |
|---|---|---|
| Storage | Not stored; computed on read | Physically stored on disk |
| Index support | 5.7: no secondary index; 8.0: secondary index OK | Both 5.7 and 8.0: full index support |
| Write overhead | None | Recomputed on INSERT/UPDATE |
| Read overhead | Computed every read | None (read from disk) |

### Common patterns

```sql
-- Extract and index a JSON field
ALTER TABLE orders
ADD COLUMN customer_email VARCHAR(255) GENERATED ALWAYS AS (JSON_UNQUOTE(metadata->>'$.email')) STORED,
ADD INDEX idx_customer_email (customer_email);

-- Computed full name for search
ALTER TABLE users
ADD COLUMN full_name VARCHAR(201) GENERATED ALWAYS AS (CONCAT(first_name, ' ', last_name)) STORED,
ADD FULLTEXT INDEX ft_full_name (full_name);

-- 8.0+ virtual column with index (no extra storage)
ALTER TABLE products
ADD COLUMN price_cents INT GENERATED ALWAYS AS (CAST(price * 100 AS SIGNED)) VIRTUAL,
ADD INDEX idx_price_cents (price_cents);
```

### Version differences
- **5.7:** Generated columns cannot reference other generated columns. Virtual columns cannot be indexed (use STORED).
- **8.0:** Virtual columns can be indexed. Generated columns can use most built-in functions. DEFAULT expressions can use expressions (not just literals).

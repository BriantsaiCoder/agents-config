# Migrations and Data Modeling

Reference for safe migration practices, Fluent API configuration, index design, raw SQL, compiled models, value conversions, and inheritance strategies. Read this when designing the data model, reviewing generated migrations, or adding schema changes to an existing production database.

## Table of contents
- [Migration safety](#migration-safety)
- [Fluent API configuration](#fluent-api-configuration)
- [Index design](#index-design)
- [Raw SQL](#raw-sql)
- [Compiled models](#compiled-models)
- [Value conversions](#value-conversions)
- [Table splitting and owned types](#table-splitting-and-owned-types)

---

## Migration safety

### Review generated SQL before applying

Every migration generates a `.Designer.cs` snapshot and a `.cs` file with `Up` and `Down` methods. Before applying to any non-local environment, generate and inspect the SQL:

```bash
# Generate SQL script — safe to inspect without touching the database.
dotnet ef migrations script --from <previousMigration> --to <targetMigration> --output migration.sql

# Or: idempotent script (safe to run multiple times; checks __EFMigrationsHistory).
dotnet ef migrations script --idempotent --output migration.sql
```

What to look for:
- Unexpected `DROP TABLE` or `DROP COLUMN` (EF may generate these for renames it cannot infer).
- Large table scans implied by adding a non-nullable column without a default to an existing table.
- Missing `BEGIN TRANSACTION` / `COMMIT` wrappers (SQL Server wraps DDL in transactions by default; PostgreSQL does too; MySQL does not).

### Never use Database.Migrate() at startup in production

`Database.Migrate()` is convenient in development but dangerous in production:
- Multiple instances starting simultaneously will race to apply migrations, potentially corrupting `__EFMigrationsHistory` or applying a migration twice.
- A failed migration during startup leaves the database partially migrated and the app unable to start.

```csharp
// Development only — acceptable because a single local instance runs.
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}
// Production: apply via CLI or CI/CD pipeline before deploying app code.
```

In production, apply migrations from CI/CD as a pre-deploy step:

```bash
dotnet ef database update --connection "$(PROD_CONNECTION_STRING)"
# Or use the idempotent SQL script approach for more control.
```

### Handling concurrent migration attempts

Use a distributed lock or deploy migrations as a separate step from the application deployment. For SQL Server, the idempotent script approach is safest because `__EFMigrationsHistory` prevents double-application.

### Data migrations: separate from schema migrations

Schema migrations (DDL) and data migrations (DML to backfill/transform existing data) should be kept in separate migration files where possible:
1. Add new nullable column (schema migration).
2. Backfill the column from existing data (data migration — can be a standalone script or a migration with `migrationBuilder.Sql(...)`).
3. Add the NOT NULL constraint (schema migration).

This staged approach prevents locking issues on large tables and makes rollback safer.

```csharp
// Data migration example inside a migration's Up method.
migrationBuilder.Sql(@"
    UPDATE Products
    SET NormalizedName = LOWER(Name)
    WHERE NormalizedName IS NULL
");
```

### Never edit published migrations

Once a migration has been applied to any environment (staging, production), treat it as immutable. If you need to undo a change, add a new migration. Editing a published migration breaks the snapshot and causes `dotnet ef migrations list` to report pending migrations that have already been applied.

### Rollback commands

EF Core rolls back by applying `Down` of migrations between the current state and the target:

```bash
# Revert database to a specific prior migration (runs Down of everything after it).
dotnet ef database update PreviousMigrationName

# Revert all migrations (empty schema).
dotnet ef database update 0

# Generate a rollback SQL script for review before applying.
dotnet ef migrations script CurrentMigration PreviousMigration --output rollback.sql
```

Rollback only works if every affected migration has a correct `Down` method. Migrations that ran `migrationBuilder.Sql(...)` with destructive statements (e.g. `DROP TABLE`, data transforms) usually cannot be auto-reversed — write the inverse SQL explicitly in `Down`, or treat the migration as forward-only and plan a forward-fix migration instead of a rollback.

### Migration conflict resolution (multiple developers)

When two branches each add a migration on top of the same parent, the model snapshot (`*.Designer.cs` / `ModelSnapshot.cs`) conflicts:

```bash
# 1. Pull latest main; let their migration stay.
git pull origin main

# 2. Remove your local unapplied migration (drops the .cs + updates snapshot).
dotnet ef migrations remove

# 3. Re-add your migration on top of the updated snapshot.
dotnet ef migrations add YourFeature

# 4. Re-test against a fresh DB.
dotnet ef database update
```

Never resolve the snapshot conflict by hand-merging JSON — always regenerate via `remove` + `add`.

### Migration bundles (EF Core 6+) for production deployment

A migration bundle is a self-contained executable that applies pending migrations without requiring the EF CLI, SDK, or project source on the target machine:

```bash
# Build a bundle for the deployment target.
dotnet ef migrations bundle --self-contained -r linux-x64 --output ./efbundle

# Apply on the deploy host (CI/CD step before rolling out app pods).
./efbundle --connection "$PROD_CONNECTION_STRING"
```

Bundles are preferable to `Database.Migrate()` at startup because they run once as a deployment step, not per-instance at boot. They also pin the exact migration set to the app version being deployed.

### Custom SQL in migrations (procs, views, indexes with predicates)

Use `migrationBuilder.Sql(...)` for provider-specific DDL that EF cannot model directly. Always write the inverse in `Down`:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.Sql(@"
        CREATE VIEW vw_ActiveOrders AS
        SELECT o.*, c.Name AS CustomerName
        FROM Orders o
        INNER JOIN Customers c ON o.CustomerId = c.Id
        WHERE o.IsDeleted = 0");
}

protected override void Down(MigrationBuilder migrationBuilder)
{
    migrationBuilder.Sql("DROP VIEW IF EXISTS vw_ActiveOrders");
}
```

For filtered indexes, prefer the Fluent API (`HasIndex(...).HasFilter(...)`) so the index is part of the model and survives `dotnet ef dbcontext optimize`. Reserve `migrationBuilder.Sql` for procs, views, triggers, and provider-specific DDL that has no Fluent API equivalent.

### Data seeding: HasData vs migrationBuilder.InsertData

`HasData` in `OnModelCreating` emits `InsertData` calls into the next generated migration, so seed rows participate in migration history and can be changed / removed via further migrations:

```csharp
modelBuilder.Entity<OrderStatus>().HasData(
    new OrderStatus { Id = 1, Name = "Pending" },
    new OrderStatus { Id = 2, Name = "Processing" });
```

Use `HasData` only for static reference data with stable primary keys. For user-generated or environment-specific data, seed via a separate data script outside the migration pipeline — mixing them forces every environment to share identical seed rows.

---

## Zero-downtime schema changes (expand-contract)

Breaking schema changes applied in a single migration while the old app version is still serving traffic cause failed requests. Split every breaking change into **expand → migrate → contract** phases, each deployed separately so the database and at least one app version are always compatible.

### Renaming a column

```text
Phase 1 (expand):  Migration adds NewName column (nullable). Old code still reads/writes OldName.
Phase 2 (dual-write): Deploy app v2 — writes to BOTH OldName and NewName, reads from OldName.
Phase 3 (backfill): Migration runs UPDATE to copy OldName → NewName for existing rows.
Phase 4 (switch-read): Deploy app v3 — reads from NewName, still writes both.
Phase 5 (contract): Deploy app v4 — writes only NewName. Migration drops OldName.
```

Every phase is independently deployable and rollback-safe. Never skip the dual-write phase — without it, a rollback of the app version after Phase 4 would lose data written to NewName only.

### Changing a column type (e.g. string → int)

Never use `AlterColumn` to change type on a populated table — it rewrites every row, locks the table, and fails on unconvertible data.

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    // 1. Add new column alongside the old one.
    migrationBuilder.AddColumn<int>("Age_New", "Users", nullable: true);

    // 2. Copy and transform in batches (for large tables, issue multiple smaller UPDATEs).
    migrationBuilder.Sql(@"
        UPDATE Users
        SET Age_New = CAST(Age AS INT)
        WHERE Age IS NOT NULL AND ISNUMERIC(Age) = 1");

    // 3. Separate later migration (after app switches reads): drop old, rename new.
    // migrationBuilder.DropColumn("Age", "Users");
    // migrationBuilder.RenameColumn("Age_New", "Users", "Age");
}
```

Ship steps 1-2 and step 3 as **separate migrations in separate deployments** so the app has time to switch between columns.

### Adding a NOT NULL column to an existing table

Never add `NOT NULL` without a default on a populated table — the migration will fail on existing rows.

```csharp
// Phase 1: add nullable column.
migrationBuilder.AddColumn<string>("Email", "Customers", nullable: true);

// Phase 2 (data migration): backfill.
migrationBuilder.Sql("UPDATE Customers SET Email = 'unknown@example.com' WHERE Email IS NULL");

// Phase 3 (after app writes Email for all new rows): tighten to NOT NULL.
migrationBuilder.AlterColumn<string>("Email", "Customers", nullable: false);
```

### Verification checkpoints for large data migrations

Long-running data migrations should verify correctness before the next phase proceeds:

```csharp
migrationBuilder.Sql(@"
    IF EXISTS (SELECT 1 FROM Customers WHERE Email IS NULL)
        THROW 50001, 'Backfill incomplete — aborting migration.', 1;");
```

Run this at the end of the data-migration phase; if the invariant fails, the migration transaction rolls back and the deployment halts before the contract phase drops the old column.

---

## Fluent API configuration

### Why Fluent API over Data Annotations

Data Annotations pollute domain models with infrastructure concerns and have a smaller feature set. Fluent API:
- Supports all EF Core features (filtered indexes, owned types, table splitting, shadow properties).
- Keeps entity classes free of EF attributes.
- Is easier to review in one place per entity.

Use Data Annotations only for simple scalar constraints where the project convention already accepts them.

### IEntityTypeConfiguration pattern

Define one configuration class per entity, implement `IEntityTypeConfiguration<T>`, and register them all at once:

```csharp
// Infrastructure/Persistence/Configurations/OrderConfiguration.cs
internal sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("Orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.Status)
            .HasConversion<string>()          // store as string, not int
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(o => o.Total)
            .HasPrecision(18, 2)             // avoids decimal(18,2) default surprise
            .IsRequired();

        builder.Property(o => o.Notes)
            .HasMaxLength(2000);             // avoids nvarchar(max) for a notes field

        builder.HasOne(o => o.Customer)
            .WithMany(c => c.Orders)
            .HasForeignKey(o => o.CustomerId)
            .OnDelete(DeleteBehavior.Restrict); // avoid accidental cascade deletes
    }
}

// In DbContext:
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
```

### Common EF Core default traps to fix explicitly

| Default EF behavior | Problem | Fix |
|---------------------|---------|-----|
| `string` maps to `nvarchar(max)` | Index cannot be created on `max` columns in SQL Server | `HasMaxLength(N)` |
| `decimal` maps to `decimal(18,2)` | May be too imprecise or too wide for your domain | `HasPrecision(precision, scale)` |
| `enum` maps to `int` | Readable SQL, easier debugging | `HasConversion<string>()` |
| Cascade delete on required FK | Accidental mass delete | `OnDelete(DeleteBehavior.Restrict)` |
| No table name convention | Plural vs singular inconsistency | `ToTable("OrderLines")` explicitly |

---

## Index design

### HasIndex for frequently queried columns

Any column that appears frequently in `WHERE`, `JOIN ON`, or `ORDER BY` clauses should have an index:

```csharp
builder.HasIndex(o => o.CustomerId);             // single column
builder.HasIndex(o => o.PlacedAt);               // for date-range queries
```

### Composite indexes and column order

Column order in a composite index matters. Place the most selective column (highest cardinality) first, and ensure that the leading column matches the most common query predicate:

```csharp
// Supports: WHERE TenantId = @t AND Status = @s
// Does NOT efficiently support: WHERE Status = @s (without TenantId)
builder.HasIndex(o => new { o.TenantId, o.Status });
```

### Unique indexes

```csharp
builder.HasIndex(o => o.EmailAddress)
    .IsUnique();

// Unique composite — enforce uniqueness across multiple columns.
builder.HasIndex(o => new { o.TenantId, o.OrderNumber })
    .IsUnique();
```

### Filtered indexes

Index only a subset of rows — dramatically more efficient for sparse predicates like `IsDeleted = 0`:

```csharp
// SQL Server / PostgreSQL partial index — indexes only non-deleted rows.
builder.HasIndex(o => o.CustomerId)
    .HasFilter("IsDeleted = 0");         // SQL Server syntax
    // PostgreSQL: .HasFilter("\"IsDeleted\" = false")
```

### Include columns (covering indexes for SQL Server)

Add non-key columns to the index leaf level to satisfy a query entirely from the index (no key lookup):

```csharp
// Covers: SELECT Id, Total, PlacedAt FROM Orders WHERE CustomerId = @id ORDER BY PlacedAt
builder.HasIndex(o => new { o.CustomerId, o.PlacedAt })
    .IncludeProperties(o => new { o.Id, o.Total });
```

`IncludeProperties` is SQL Server-specific. On PostgreSQL, use `INCLUDE` via a raw annotation or rely on covering index behavior from composite columns.

---

## Raw SQL

### FromSqlInterpolated (safe, recommended)

EF Core extracts interpolated values as parameters:

```csharp
var region = "North";
var minTotal = 100m;

// Generated SQL: SELECT ... FROM Orders WHERE Region = @p0 AND Total >= @p1
var orders = await db.Orders
    .FromSqlInterpolated($"SELECT * FROM Orders WHERE Region = {region} AND Total >= {minTotal}")
    .AsNoTracking()
    .Where(o => o.Status == OrderStatus.Active) // LINQ can compose over FromSql
    .ToListAsync(ct);
```

### FromSqlRaw with explicit parameters

Use when you need to pass a raw `SqlParameter` (e.g., for TVP or output parameters):

```csharp
var param = new SqlParameter("@region", SqlDbType.NVarChar, 50) { Value = region };
var orders = await db.Orders
    .FromSqlRaw("SELECT * FROM Orders WHERE Region = @region", param)
    .AsNoTracking()
    .ToListAsync(ct);
```

### SqlQuery for non-entity results (EF8+)

EF Core 8 added `SqlQuery<T>` for arbitrary scalar or DTO results without needing a `DbSet`:

```csharp
var summaries = await db.Database
    .SqlQuery<SalesSummaryDto>($@"
        SELECT Region, SUM(Total) AS TotalSales, COUNT(*) AS OrderCount
        FROM Orders
        WHERE PlacedAt >= {fromDate}
        GROUP BY Region")
    .ToListAsync(ct);
```

`SalesSummaryDto` must be a type with properties matching the column names (case-insensitive). It does not need to be registered as an entity.

### ExecuteSqlInterpolatedAsync for commands

```csharp
await db.Database.ExecuteSqlInterpolatedAsync(
    $"UPDATE Products SET Stock = Stock - {quantity} WHERE Id = {productId}",
    ct);
```

### Security: never concatenate user input

```csharp
// WRONG — SQL injection.
var userInput = request.Region;
await db.Database.ExecuteSqlRawAsync(
    $"DELETE FROM Orders WHERE Region = '{userInput}'"); // never do this

// CORRECT
await db.Database.ExecuteSqlInterpolatedAsync(
    $"DELETE FROM Orders WHERE Region = {userInput}", ct);
```

---

## Compiled models

### When needed

The model-building phase (parsing `IEntityTypeConfiguration` classes, validating relationships, building internal metadata) adds startup latency proportional to model size. For models with 100+ entities, this can be 500ms or more at cold start, which matters in containerized environments with frequent instance recycling.

Compiled models pre-build this metadata at design time:

```bash
dotnet ef dbcontext optimize \
    --output-dir Infrastructure/Persistence/CompiledModel \
    --namespace MyApp.Infrastructure.Persistence.CompiledModel
```

Register in `Program.cs`:
```csharp
options.UseSqlServer(connStr)
    .UseModel(AppDbContextModel.Instance); // generated class
```

### Limitations

- Must be regenerated every time the model changes (run `dotnet ef dbcontext optimize` again).
- CI/CD pipelines should regenerate and commit the compiled model alongside migrations.
- Some advanced model features (certain interceptors, complex ownership configurations) may not serialize to the compiled model; EF will warn at build time.

---

## Value conversions

### HasConversion for enum-to-string

Storing enums as strings makes the database human-readable and avoids broken queries when enum values are reordered:

```csharp
builder.Property(o => o.Status)
    .HasConversion<string>()
    .HasMaxLength(50);
```

### Custom HasConversion for complex types

```csharp
// Store a Money value object as two columns: Amount and Currency.
builder.OwnsOne(o => o.Price, priceBuilder =>
{
    priceBuilder.Property(p => p.Amount).HasPrecision(18, 4).HasColumnName("PriceAmount");
    priceBuilder.Property(p => p.Currency).HasMaxLength(3).HasColumnName("PriceCurrency");
});

// Or — store as a single JSON column (EF8+):
builder.Property(o => o.Metadata)
    .HasConversion(
        v => JsonSerializer.Serialize(v, JsonSerializerOptions.Default),
        v => JsonSerializer.Deserialize<OrderMetadata>(v, JsonSerializerOptions.Default)!);
```

EF Core 8+ has first-class JSON column support via `OwnsOne` / `OwnsMany` + `ToJson()`:

```csharp
builder.OwnsOne(o => o.ShippingAddress, addr =>
{
    addr.ToJson(); // stored as a single JSON column called ShippingAddress
});
```

### ValueComparer for complex types

When EF Core cannot determine whether a complex property changed (e.g., a `List<string>` or custom class), it may either always mark it modified or never detect changes. Provide a `ValueComparer` to fix this:

```csharp
var listComparer = new ValueComparer<List<string>>(
    (a, b) => a != null && b != null && a.SequenceEqual(b),
    list => list.Aggregate(0, (h, s) => HashCode.Combine(h, s.GetHashCode())),
    list => list.ToList()); // snapshot — create a copy, not a reference

builder.Property(e => e.Tags)
    .HasConversion(
        v => string.Join(',', v),
        v => v.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList())
    .Metadata.SetValueComparer(listComparer);
```

### Performance implications of conversions

- Conversions run in-memory after data is fetched; they do not affect query translation for `WHERE` clauses unless EF can inline them.
- Filtering on a converted column may cause client-side evaluation — verify by checking `EnableSensitiveDataLogging` output or a query logger.
- For JSON columns, filtering inside the JSON document works on SQL Server (via `JSON_VALUE`) and PostgreSQL (via `jsonb` operators) when EF Core's JSON query support is used.

---

## Table splitting and owned types

### Owned entities for value objects

Owned types map a value object to columns in the owner's table. Use them for address, money, geolocation, and similar concepts that have no independent identity:

```csharp
public sealed class Order
{
    public int Id { get; set; }
    public Address ShippingAddress { get; set; } = null!;
}

public sealed class Address
{
    public string Street { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string PostalCode { get; set; } = string.Empty;
}

// Configuration:
builder.OwnsOne(o => o.ShippingAddress, addr =>
{
    addr.Property(a => a.Street).HasMaxLength(200).HasColumnName("ShippingStreet");
    addr.Property(a => a.City).HasMaxLength(100).HasColumnName("ShippingCity");
    addr.Property(a => a.PostalCode).HasMaxLength(20).HasColumnName("ShippingPostalCode");
});
```

### Table splitting for wide tables

Table splitting maps multiple entity types to the same table. Useful when some columns are rarely accessed and you want to avoid loading them in normal queries:

```csharp
// Two entities, one table — load OrderSummary cheaply; load OrderDetail only when needed.
builder.Entity<Order>().ToTable("Orders");
builder.Entity<OrderDetail>().ToTable("Orders"); // same table

builder.Entity<Order>()
    .HasOne(o => o.Detail)
    .WithOne(d => d.Order)
    .HasForeignKey<OrderDetail>(d => d.Id);
```

### Inheritance strategies

EF Core supports three inheritance mapping strategies. Choose based on query patterns and schema preferences:

| Strategy | Description | Pro | Con |
|----------|-------------|-----|-----|
| **TPH** (Table Per Hierarchy) | All types in one table with a discriminator column | Fewest tables; best query performance; simplest schema | Table grows wide; nullable columns for derived-type properties |
| **TPT** (Table Per Type) | One table per type; base + derived joined | Normalized schema; no nulls | JOIN per query; slower reads |
| **TPC** (Table Per Concrete type, EF7+) | One table per concrete type; no base table | No JOINs; clean tables | No shared base table; UNION for polymorphic queries; identity column management is complex |

TPH is the default and the recommended starting point:

```csharp
// TPH — default; no extra configuration needed.
modelBuilder.Entity<Payment>()
    .HasDiscriminator<string>("PaymentType")
    .HasValue<CreditCardPayment>("CreditCard")
    .HasValue<BankTransferPayment>("BankTransfer");

// TPT:
modelBuilder.Entity<CreditCardPayment>().ToTable("CreditCardPayments");
modelBuilder.Entity<BankTransferPayment>().ToTable("BankTransferPayments");

// TPC (EF7+):
modelBuilder.Entity<Payment>().UseTpcMappingStrategy();
```

TPT is rarely the right choice: it adds a JOIN for every query against any type in the hierarchy. Prefer TPH unless schema normalization is a hard requirement.

TPC is useful when each concrete type has many unique columns and polymorphic queries are rare. It requires careful management of sequence-based keys (since there is no shared table to generate identity values from).

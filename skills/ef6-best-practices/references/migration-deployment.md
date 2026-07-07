# EF6 — Migrations and Deployment

## Automatic vs Code-Based Migrations

### Automatic Migrations

EF6 supports `AutomaticMigrationsEnabled = true`. Automatic migrations apply schema changes without
generating explicit migration files.

**When acceptable:** Solo developer; rapid prototyping; no production database.

**When to avoid (most cases):**
- Team environments — no audit trail; conflicts are invisible.
- Production — you cannot review the SQL before it runs.
- Any table containing real user data.

**Recommendation: disable automatic migrations in any project that will reach production.**

```csharp
internal sealed class OrderContextMigrations : DbMigrationsConfiguration<OrderContext>
{
    public OrderContextMigrations()
    {
        AutomaticMigrationsEnabled = false;
        AutomaticMigrationDataLossAllowed = false;
    }
}
```

---

## Code-Based Migration Workflow

### Step 1 — Create the Migration

```
PM> Add-Migration AddOrderShippedAt
```

### Step 2 — Review the Generated File

```csharp
public partial class AddOrderShippedAt : DbMigration
{
    public override void Up()
    {
        AddColumn("dbo.Orders", "ShippedAt", c => c.DateTimeOffset(nullable: true));
    }

    public override void Down()
    {
        DropColumn("dbo.Orders", "ShippedAt");
    }
}
```

Verify:
- `Up()` does what you expect (correct table, column name, type, nullability).
- `Down()` correctly reverses the change.
- No accidental drop/create pairs where a rename was intended.

### Step 3 — Generate and Review the SQL Script

```
PM> Update-Database -Script -SourceMigration:<last applied> -TargetMigration:<new migration>
```

### Step 4 — Apply to Development

```
PM> Update-Database
```

---

## Deployment Strategies

### Option A — SQL Script (Recommended for Production)

Generate the script in CI, apply via DBA or migration pipeline. Full visibility and review gate.

### Option B — `MigrateDatabaseToLatestVersion` Initializer

```csharp
Database.SetInitializer(
    new MigrateDatabaseToLatestVersion<OrderContext, OrderContextMigrations>());
```

Risks for production:
- Multiple instances can race on migration application.
- No review gate before SQL runs.
- Startup time increases.

### Option C — `Migrate.exe` (EF6 command-line tool)

```
migrate.exe MyApp.dll /startupConfigurationFile="Web.config" /targetMigration="latest"
```

---

## Seeding Data

```csharp
protected override void Seed(OrderContext context)
{
    context.Customers.AddOrUpdate(
        c => c.Email,
        new Customer { Name = "Internal Test", Email = "test@internal.example" }
    );
    context.SaveChanges();
}
```

`AddOrUpdate` matches on the key expression and updates if found, inserts if not. Do not use for
large datasets — it issues one SELECT per row.

**Seed runs after every `Update-Database` call.** Keep seed data idempotent and non-destructive.

---

## Handling Migration Conflicts in Teams

### Prevention

- Coordinate: only one developer creates migrations on a feature branch at a time.
- Merge the migration-creating branch to main before creating the next one.

### Resolution

If two migrations have the same source:

1. Decide on the correct ordering.
2. Rebase: delete one migration's files, re-apply on top of the other, then re-run `Add-Migration`.
3. Or use `Add-Migration <name> -IgnoreChanges` to create an empty migration that advances the
   snapshot, then manually write the `Up()`/`Down()` DDL.

---

## Downgrade / Rollback Strategies

### Rolling Back to a Specific Migration

```
PM> Update-Database -TargetMigration:<migration name>
```

This runs `Down()` of each migration in reverse order.

### If `Down()` Is Not Safe

For destructive migrations, `Down()` cannot recover data. Strategies:

1. **Backup before applying.** Always backup before running destructive migrations.
2. **Phased approach:** Deploy 1: mark column unused. Deploy 2: drop column.
3. **Compensating migration:** Write a new forward migration that restores the schema.

### Rollback Checklist

- [ ] Database backup taken before migration.
- [ ] `Down()` method reviewed and tested on staging.
- [ ] Application version rolled back simultaneously with database rollback.
- [ ] `__MigrationHistory` table reflects expected state after rollback.

---

## Migration Quality Checklist

Before committing any migration file:

- [ ] `Up()` produces correct DDL (column types, nullability, defaults).
- [ ] `Down()` correctly reverses `Up()`.
- [ ] No accidental drop/create where `RenameColumn`/`RenameTable` was intended.
- [ ] SQL Script reviewed (via `Update-Database -Script`).
- [ ] Migration applied to staging database with production schema.
- [ ] `Seed()` method (if changed) is idempotent.
- [ ] Migration name is descriptive.
- [ ] No automatic migrations enabled in the configuration class.

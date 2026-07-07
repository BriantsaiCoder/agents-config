# EF6 — EDMX, Code First, and Model Management

## The Three Workflow Styles

| Style | Entry Point | Who owns the schema | When to choose |
|-------|-------------|----------------------|----------------|
| **Database First** | EDMX generated from existing DB | DBA / database team | Legacy databases; schema pre-dates the application |
| **Code First** | C# model classes | Application team | Greenfield projects; team owns schema |
| **Model First** | EDMX designed in VS designer | Application team | Rarely used; Code First is preferred for new work |

---

## EDMX Maintenance Best Practices

The EDMX file is an XML artifact with three embedded sections: CSDL (Conceptual), SSDL (Store), MSL (Mapping).

### After Any Database Schema Change

1. Right-click the EDMX surface → **Update Model from Database**.
2. Review the diff in source control before committing.
3. Rebuild the project — the T4 template regenerates entity classes from the updated EDMX.
4. Run all unit and integration tests before merging.

### Source Control Hygiene

- Commit the `.edmx` file and its generated `.tt` / `.cs` files together.
- Do not commit the `.edmx` with unreviewed auto-generated changes.
- In team environments, coordinate schema changes and update the EDMX on a single branch, then merge.

### Naming Conventions

The EDMX designer uses table/column names as-is by default. Rename entities and properties in the
designer to match C# conventions (PascalCase). These renames live in the CSDL layer and do not affect
the SSDL (database names).

---

## Problems with Large EDMX Files

An EDMX with 100+ entities becomes unwieldy:

- **VS designer performance** degrades; opening the diagram is slow.
- **Cold-start view generation** time increases.
- **Merge conflicts** become frequent in team environments.
- **Compile times** increase because the T4 template generates a large file.

### Splitting Large EDMX Files

EF6 supports multiple `DbContext` classes, each with its own EDMX or Code First model, pointing to the
same database. Split by bounded context:

```csharp
// Ordering context — only order-related tables
public class OrderContext : DbContext
{
    public OrderContext() : base("name=OrderDb") { }
    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderLine> OrderLines { get; set; }
}

// Inventory context — only stock tables
public class InventoryContext : DbContext
{
    public InventoryContext() : base("name=OrderDb") { }
    public DbSet<Product> Products { get; set; }
    public DbSet<StockLevel> StockLevels { get; set; }
}
```

---

## Code First Workflow

### Entity Class

```csharp
public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public OrderStatus Status { get; set; }

    public virtual Customer Customer { get; set; }
    public virtual ICollection<OrderLine> Lines { get; set; } = new HashSet<OrderLine>();
}
```

Remove `virtual` keywords when `ProxyCreationEnabled = false`.

### DbContext with OnModelCreating

```csharp
public class OrderContext : DbContext
{
    public OrderContext() : base("name=OrderDb")
    {
        Configuration.LazyLoadingEnabled = false;
        Configuration.ProxyCreationEnabled = false;
    }

    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderLine> OrderLines { get; set; }
    public DbSet<Customer> Customers { get; set; }

    protected override void OnModelCreating(DbModelBuilder modelBuilder)
    {
        modelBuilder.Configurations.Add(new OrderConfiguration());
        modelBuilder.Configurations.Add(new OrderLineConfiguration());
    }
}
```

---

## Data Annotations vs Fluent API in EF6

Prefer **Fluent API** for all but the simplest constraints.

### Data Annotations (acceptable for simple cases)

```csharp
[Table("Orders")]
public class Order
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(200)]
    public string Reference { get; set; }
}
```

### Fluent API (preferred)

```csharp
internal class OrderConfiguration : EntityTypeConfiguration<Order>
{
    public OrderConfiguration()
    {
        ToTable("Orders");
        HasKey(o => o.Id);

        Property(o => o.Reference)
            .IsRequired()
            .HasMaxLength(200);

        Property(o => o.CreatedAt)
            .IsRequired();

        HasRequired(o => o.Customer)
            .WithMany(c => c.Orders)
            .HasForeignKey(o => o.CustomerId)
            .WillCascadeOnDelete(false);
    }
}
```

Register all configurations: `modelBuilder.Configurations.AddFromAssembly(typeof(OrderContext).Assembly)`.

---

## Handling Schema Changes in Code First

1. Add or modify entity properties.
2. Run `Add-Migration <DescriptiveName>` in Package Manager Console.
3. Open the generated migration and **review the `Up()` and `Down()` methods**.
4. If EF inferred wrong (e.g., rename detected as drop + add), fix it manually using `RenameColumn`.
5. Run `Update-Database -Script` to generate the SQL; review before applying.
6. Apply with `Update-Database` to the development database.
7. Commit both the migration file and the updated model snapshot.

---

## Stored Procedure Mapping

### Mapping Insert/Update/Delete to Stored Procedures

```csharp
// In EntityTypeConfiguration<Order>
this.MapToStoredProcedures(s =>
{
    s.Insert(i => i.HasName("dbo.Order_Insert")
        .Parameter(o => o.Reference, "Reference")
        .Result(o => o.Id, "NewId"));
    s.Update(u => u.HasName("dbo.Order_Update"));
    s.Delete(d => d.HasName("dbo.Order_Delete"));
});
```

### Calling Stored Procedures Directly

```csharp
// Returns a list of entities
var orders = ctx.Database.SqlQuery<Order>(
    "EXEC dbo.GetPendingOrders @cutoff",
    new SqlParameter("@cutoff", cutoff))
    .ToList();

// Non-query (no result set)
ctx.Database.ExecuteSqlCommand(
    "EXEC dbo.ArchiveOldOrders @before",
    new SqlParameter("@before", DateTimeOffset.UtcNow.AddYears(-2)));
```

Always use named `SqlParameter` objects for stored procedure calls.

---

## Large EDMX → Bounded Context Migration Playbook

When a single EDMX grows beyond 80–100 entities, VS designer becomes slow, merge conflicts are frequent, and compile times increase due to view generation. The following step-by-step playbook provides an actionable migration path.

### Prerequisites

- Source control (Git or TFVC) in good state — commit before starting.
- Identify 2–4 bounded contexts by domain area (e.g., `Ordering`, `Inventory`, `Customers`, `Reporting`).
- Pick the **smallest, most isolated** context to migrate first (fewest cross-context FKs).

### Step 1 — Create a New Small DbContext (Code First with Existing Database)

```bash
# 1. Create a new folder for the bounded context
mkdir Data/Ordering

# 2. Create the entity POCOs (copy from EDMX-generated .cs, remove EF6 attributes)
# OrderingContext.cs, Order.cs, OrderLine.cs
```

```csharp
// Data/Ordering/OrderingContext.cs
public class OrderingContext : DbContext
{
    public OrderingContext()
        : base("name=MainConnectionString")  // same connection string
    {
        // CRITICAL: disable initializer — the DB already exists
        Database.SetInitializer<OrderingContext>(null);

        Configuration.LazyLoadingEnabled = false;
        Configuration.ProxyCreationEnabled = false;
    }

    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderLine> OrderLines { get; set; }

    protected override void OnModelCreating(DbModelBuilder modelBuilder)
    {
        // Map to existing table names — must match the current schema exactly
        modelBuilder.Entity<Order>().ToTable("Orders", "dbo");
        modelBuilder.Entity<Order>().HasKey(o => o.Id);
        modelBuilder.Entity<Order>().Property(o => o.Total)
            .HasPrecision(18, 2);

        modelBuilder.Entity<OrderLine>().ToTable("OrderLines", "dbo");
        // ... configure all columns to match existing schema
    }
}
```

**Git checkpoint**: `git add Data/Ordering/ && git commit -m "feat: add OrderingContext (Code First with existing DB)"`

### Step 2 — Write Integration Tests to Verify Schema Match

```csharp
[TestMethod]
public void OrderingContext_Can_Read_Existing_Orders()
{
    using (var ctx = new OrderingContext())
    {
        // If schema doesn't match, this throws at runtime
        var order = ctx.Orders
            .AsNoTracking()
            .FirstOrDefault();
        // No assert on data — just verifying the mapping compiles and runs
    }
}
```

Run tests against a copy of production data (or a recent backup). If the test fails, the Fluent API mapping doesn't match the actual table schema — fix column names, types, or precision.

**Git checkpoint**: `git commit -m "test: verify OrderingContext schema mapping"`

### Step 3 — Migrate Consumers to Use the New Context

```csharp
// BEFORE: using the monolithic EDMX context
using (var ctx = new MainEntities())
{
    var orders = ctx.Orders.Include(o => o.Lines).ToList();
}

// AFTER: using the new bounded context
using (var ctx = new OrderingContext())
{
    var orders = ctx.Orders
        .Include(o => o.OrderLines)
        .AsNoTracking()
        .ToListAsync();
}
```

Migrate one repository or service class at a time. Run all tests after each file change.

**Git checkpoint per file**: `git commit -m "refactor: OrderRepository now uses OrderingContext"`

### Step 4 — Remove Migrated Entities from the Large EDMX

1. Open the EDMX in **XML editor** (not the designer — it's too slow).
2. Search for `<EntityType Name="Order">` and remove the `EntityType`, `EntitySet`, `AssociationSet`, and related `NavigationProperty` entries.
3. Delete the corresponding `.cs` files from the EDMX's T4-generated output.
4. Build — fix any remaining references.

**Git checkpoint**: `git commit -m "refactor: remove Order/OrderLine from MainEntities EDMX"`

### Step 5 — Repeat for Next Bounded Context

Pick the next domain area and repeat Steps 1–4. Typical cadence: one context per sprint.

### Step 6 — Pre-generate Views for Remaining EDMX

While the EDMX is still large during transition, pre-generate views to reduce startup time:

```bash
# Using EF Power Tools or command line
# Package Manager Console:
Install-Package EntityFramework.CodeTemplates.CSharp

# Or use the EF6 Power Tools VS extension:
# Right-click EDMX → Entity Framework → Generate Views
```

This creates a `MainEntities.Views.cs` file that eliminates runtime view compilation.

### Step 7 — Handle Cross-Context References

When Entity A (in OrderingContext) has a FK to Entity B (in InventoryContext):

```csharp
// DON'T: navigation property across contexts (EF6 can't resolve it)
// DO: use the FK value directly
public class Order
{
    public int ProductId { get; set; }  // FK only, no navigation property
    // Product lives in InventoryContext — load it separately if needed
}
```

For cross-context reads, use a service layer that queries both contexts:

```csharp
public async Task<OrderWithProductDto> GetOrderWithProductAsync(int orderId)
{
    using (var orderCtx = new OrderingContext())
    using (var invCtx = new InventoryContext())
    {
        var order = await orderCtx.Orders.FindAsync(orderId);
        var product = await invCtx.Products.FindAsync(order.ProductId);
        return new OrderWithProductDto(order, product);
    }
}
```

### Merge Conflict Prevention Tips

| Strategy | How |
|----------|-----|
| Edit EDMX as XML, not designer | Avoid designer-generated UUID churn |
| `.gitattributes` merge driver | `*.edmx merge=union` for CSDL sections |
| Lock before designer edits | Team convention: announce EDMX changes in advance |
| Split early, split often | Smaller EDMX = fewer conflicts |

### Rollback Strategy

If a bounded context migration causes issues:
1. Revert the consumer code to use `MainEntities` (the commits are atomic per file).
2. The database schema is unchanged — no migration rollback needed.
3. The new `OrderingContext` can be deleted without any data impact.

This is a **read-path-only migration** — no schema changes, no data migration, no risk of data loss.

# Query Performance

Reference for tracking behavior, N+1 prevention, projection, parameterization, compiled queries, pagination, and global filters. Read this when a query is slow, loads more data than needed, or generates unexpected SQL.

## Table of contents
- [Tracking vs no-tracking](#tracking-vs-no-tracking)
- [N+1 query prevention](#n1-query-prevention)
- [Projection](#projection)
- [Query parameterization](#query-parameterization)
- [Compiled queries](#compiled-queries)
- [Pagination](#pagination)
- [Global query filters](#global-query-filters)

---

## Tracking vs no-tracking

### Default tracking

By default, EF Core tracks every entity returned by a query. Tracking does two things:

1. **Snapshot** — EF takes a deep copy of each entity's property values so it can detect changes at `SaveChanges` time.
2. **Identity resolution** — if the same row appears twice (e.g., the same `Customer` referenced by two `Order`s), EF returns the same object reference rather than two separate instances.

Both are useful for update workflows but have real overhead: snapshot allocation is proportional to the number of entities and their property count.

### AsNoTracking for read-only queries

For any query that is purely for display — API responses, reports, exports — use `AsNoTracking()`. EF skips the snapshot and the identity map lookup, resulting in roughly 20–35% less allocations on typical entity shapes.

```csharp
// Read-only list endpoint — no tracking needed.
var orders = await db.Orders
    .AsNoTracking()
    .Where(o => o.CustomerId == customerId)
    .OrderByDescending(o => o.PlacedAt)
    .ToListAsync(ct);
```

Benchmark reference (EF Core team blog, EF 8):
- Tracking: ~310 ns/op, ~3.2 KB allocated per entity
- NoTracking: ~210 ns/op, ~1.8 KB allocated per entity (approximately 32% faster, 44% less allocation)

Actual numbers depend on entity shape; always measure your own model.

### AsNoTrackingWithIdentityResolution

Use this when you want the memory savings of no-tracking but still need deduplication of related objects across the graph. The classic case is a JOIN that produces duplicate parent rows:

```csharp
// Each Order appears once in the result even though it joins to multiple OrderLines.
var orders = await db.Orders
    .AsNoTrackingWithIdentityResolution()
    .Include(o => o.Lines)
    .Where(o => o.CustomerId == customerId)
    .ToListAsync(ct);
```

Without identity resolution, `o.Lines` on different `Order` references that map to the same DB row would be distinct in-memory objects with potentially different state. `AsNoTrackingWithIdentityResolution` gives you the correct graph without the change-tracker overhead.

### Default tracking behavior at context level

If most queries in a context are read-only, set the default once rather than calling `AsNoTracking()` everywhere:

```csharp
public sealed class ReadOnlyAppDbContext : DbContext
{
    public ReadOnlyAppDbContext(DbContextOptions<ReadOnlyAppDbContext> options) : base(options)
    {
        // All queries on this context are no-tracking by default.
        ChangeTracker.QueryTrackingBehavior = QueryTrackingBehavior.NoTracking;
    }
}
```

Or in `OnConfiguring`:
```csharp
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
{
    optionsBuilder.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);
}
```

When you do need tracking for a specific query on a no-tracking context, opt back in explicitly:
```csharp
var product = await db.Products.AsTracking().FirstAsync(p => p.Id == id, ct);
```

---

## N+1 query prevention

An N+1 problem occurs when code loops over a collection and issues one additional query per element. EF Core does not warn about this by default.

### What N+1 looks like

```csharp
// N+1 — one query for orders, then one query per order for its customer.
var orders = await db.Orders.ToListAsync(ct);           // 1 query
foreach (var order in orders)
{
    // Lazy loading (if enabled) or explicit access triggers a new query each time.
    Console.WriteLine(order.Customer.Name);             // N queries
}
```

### Fix with Include / ThenInclude

```csharp
// Single query with a JOIN — no N+1.
var orders = await db.Orders
    .Include(o => o.Customer)
    .Include(o => o.Lines)
        .ThenInclude(l => l.Product)
    .AsNoTracking()
    .ToListAsync(ct);
```

EF Core translates this into either a single query with JOINs or (with `AsSplitQuery`) multiple targeted queries.

### AsSplitQuery for wide Include trees

Deep `Include` chains produce a JOIN that multiplies rows (cartesian explosion). For example, an order with 10 lines multiplies every row by 10 in a single-query JOIN. Use `AsSplitQuery` to break this into multiple round trips, each returning a smaller, non-multiplied result:

```csharp
var orders = await db.Orders
    .Include(o => o.Lines)
        .ThenInclude(l => l.Product)
    .Include(o => o.Customer)
        .ThenInclude(c => c.Address)
    .AsSplitQuery()     // EF issues separate SELECT statements and stitches in memory.
    .AsNoTracking()
    .ToListAsync(ct);
```

When to use `AsSplitQuery`:
- Multiple collection navigations at the same level (causes cartesian explosion).
- The single-query plan is significantly larger than the sum of individual queries.

Tradeoff: split queries are not atomic. If data changes between the split selects, you may see inconsistent snapshots. For consistency-critical reads, use a transaction or accept the single-query cartesian product.

### Explicit loading as an alternative

When you do not always need the related data, load it on demand with explicit loading rather than always eager-loading:

```csharp
var order = await db.Orders.FindAsync([orderId], ct);

// Only load lines when the caller actually needs them.
if (includeLines)
{
    await db.Entry(order!).Collection(o => o.Lines).LoadAsync(ct);
}
```

Use this pattern when the related collection is large or conditionally needed. It still issues N queries if called in a loop — avoid that.

---

## Projection

Loading a full entity and then mapping it to a DTO in-memory transfers more data over the network than needed. Use `Select` to project in the query itself:

```csharp
// AVOID — loads all columns, then maps in C#.
var entities = await db.Orders.AsNoTracking().ToListAsync(ct);
var dtos = entities.Select(o => new OrderSummaryDto(o.Id, o.Total, o.PlacedAt)).ToList();

// PREFER — SQL transfers only three columns.
var dtos = await db.Orders
    .AsNoTracking()
    .Select(o => new OrderSummaryDto(o.Id, o.Total, o.PlacedAt))
    .ToListAsync(ct);
```

Projection rules:
- `Select` can project to anonymous types, records, or classes. EF generates SQL that selects only the referenced columns.
- You do not need `AsNoTracking()` when projecting to a non-entity type — EF does not track scalars or DTOs.
- Avoid calling unmapped methods inside `Select`; they cannot be translated and cause client-side evaluation.

Projection to a DTO record:
```csharp
public sealed record OrderSummaryDto(int Id, decimal Total, DateTimeOffset PlacedAt);

var summaries = await db.Orders
    .Where(o => o.Status == OrderStatus.Completed)
    .OrderByDescending(o => o.PlacedAt)
    .Select(o => new OrderSummaryDto(o.Id, o.Total, o.PlacedAt))
    .ToListAsync(ct);
```

---

## Query parameterization

### Automatic parameterization

EF Core automatically parameterizes captured variables. This is safe and allows the database to reuse cached execution plans:

```csharp
int customerId = 42;

// EF generates: SELECT ... WHERE CustomerId = @p0
// @p0 = 42 — plan is reused for any customer id.
var orders = await db.Orders
    .Where(o => o.CustomerId == customerId)
    .ToListAsync(ct);
```

### Collection parameters (default changed in EF Core 10)

A captured *collection* used in `Contains` is translated differently depending on version:

```csharp
int[] ids = [1, 2, 3];
// EF Core 10 default: WHERE [b].[Id] IN (@ids1, @ids2, @ids3) — one scalar parameter per element
// EF Core 8–9 default: a single collection parameter (OPENJSON on SQL Server)
var blogs = await db.Blogs.Where(b => ids.Contains(b.Id)).ToListAsync(ct);
```

EF Core 10 expands the collection so the planner gets cardinality information, which usually yields better plans — but each distinct collection *length* now produces a distinct plan. For hot paths with highly variable list sizes, measure. EF Core 10 also simplified generated SQL parameter names, so any code or test asserting on `@p0`-style names needs review.

### Inline constants vs captured variables

Constants embedded directly in a LINQ expression are inlined as literal SQL values. Each unique value produces a distinct query plan:

```csharp
// Generates: WHERE CustomerId = 42  (literal, not a parameter)
// Different plan than WHERE CustomerId = 99 — plan cache pollution.
var orders = await db.Orders.Where(o => o.CustomerId == 42).ToListAsync(ct);
```

Prefer captured variables or `EF.Constant` (EF Core 8+) for values you want inlined intentionally:
```csharp
// EF Core 8 — explicit constant, skip parameterization for a known-fixed value.
var orders = await db.Orders
    .Where(o => o.Status == EF.Constant(OrderStatus.Active))
    .ToListAsync(ct);
```

### Raw SQL — safe patterns

Use `FromSqlInterpolated` for raw SQL with user-supplied values. EF Core extracts the interpolated values as parameters automatically:

```csharp
// Safe — values become @p0, @p1 parameters. No SQL injection.
var region = "North";
var minTotal = 100m;
var orders = await db.Orders
    .FromSqlInterpolated($"SELECT * FROM Orders WHERE Region = {region} AND Total >= {minTotal}")
    .AsNoTracking()
    .ToListAsync(ct);
```

`FromSqlRaw` with explicit parameters:
```csharp
// Safe — explicit SqlParameter, no interpolation.
var orders = await db.Orders
    .FromSqlRaw(
        "SELECT * FROM Orders WHERE Region = {0} AND Total >= {1}",
        region, minTotal)
    .AsNoTracking()
    .ToListAsync(ct);
```

Never concatenate user input into `FromSqlRaw`:
```csharp
// WRONG — SQL injection. Never do this.
var orders = await db.Orders
    .FromSqlRaw($"SELECT * FROM Orders WHERE Region = '{userInput}'")
    .ToListAsync(ct);
```

---

## Compiled queries

EF Core translates LINQ to SQL on each call: it parses the expression tree, maps it to the model, and generates SQL. For hot paths called thousands of times per second, this translation overhead adds up.

`EF.CompileAsyncQuery` pre-translates the query once at startup and stores the result:

```csharp
// Define once — typically as a static field on a repository or a static class.
private static readonly Func<AppDbContext, int, CancellationToken, Task<Order?>> FindOrderById =
    EF.CompileAsyncQuery((AppDbContext db, int id, CancellationToken ct) =>
        db.Orders.FirstOrDefault(o => o.Id == id));

// Call many times — no re-translation on each invocation.
var order = await FindOrderById(_db, orderId, ct);
```

Multi-result compiled query:
```csharp
private static readonly Func<AppDbContext, int, CancellationToken, IAsyncEnumerable<Order>> OrdersByCustomer =
    EF.CompileAsyncQuery((AppDbContext db, int customerId, CancellationToken ct) =>
        db.Orders.Where(o => o.CustomerId == customerId).OrderByDescending(o => o.PlacedAt));

// Caller awaits the enumerable.
await foreach (var order in OrdersByCustomer(_db, customerId, ct))
{
    // process
}
```

Limitations:
- No `Include` in some EF versions — verify with your target EF Core version.
- Parameters must be scalar; you cannot pass a collection as a parameter.
- The compiled query is tied to a specific `DbContext` type.
- Use only for queries that appear in profiling as translation hot spots — not as a blanket optimization.

### Precompiled queries (EF Core 9+, stabilizing in EF Core 10)

Hand-written `EF.CompileAsyncQuery` is not the only option. EF Core 9 added query precompilation: the CLI statically finds your LINQ queries and generates C# interceptors holding pre-compiled SQL and materialization code, so translation cost leaves startup entirely — no delegates to maintain, no scalar-only parameter restriction at the call site.

```bash
# Precompile queries only — removes translation overhead from startup.
dotnet ef dbcontext optimize --precompile-queries

# Also generates the compiled model; required for NativeAOT publishing.
dotnet ef dbcontext optimize
```

This was explicitly experimental in EF Core 9 ("not recommended for production use"), with stabilization targeted at EF Core 10. Confirm the status for your exact EF Core version before adopting; on versions where it applies, prefer it over hand-written `EF.CompileAsyncQuery`.

---

## Pagination

### Offset pagination (Skip/Take)

Standard for most UI paging scenarios:

```csharp
int page = 3;        // 1-based
int pageSize = 25;

var orders = await db.Orders
    .AsNoTracking()
    .OrderByDescending(o => o.PlacedAt)
    .Skip((page - 1) * pageSize)
    .Take(pageSize)
    .ToListAsync(ct);
```

`OrderBy` is required when using `Skip`; without it, results are non-deterministic across pages.

Offset pagination degrades at large offsets (e.g., `SKIP 100000`) because the database must scan and discard rows. For datasets with millions of rows or infinite-scroll UIs, prefer keyset pagination.

### Keyset pagination (cursor-based)

Instead of skipping rows, filter using the last-seen key from the previous page. This scales to arbitrarily large datasets:

```csharp
// First page — no cursor.
var firstPage = await db.Orders
    .AsNoTracking()
    .OrderBy(o => o.PlacedAt)
    .ThenBy(o => o.Id)   // tiebreaker ensures stable ordering
    .Take(pageSize)
    .ToListAsync(ct);

// Subsequent pages — pass the cursor values from the last row of the previous page.
DateTimeOffset lastPlacedAt = firstPage.Last().PlacedAt;
int lastId = firstPage.Last().Id;

var nextPage = await db.Orders
    .AsNoTracking()
    .Where(o => o.PlacedAt > lastPlacedAt
             || (o.PlacedAt == lastPlacedAt && o.Id > lastId))
    .OrderBy(o => o.PlacedAt)
    .ThenBy(o => o.Id)
    .Take(pageSize)
    .ToListAsync(ct);
```

Keyset pagination requirements:
- The sort columns must be unique or combined to be unique (use a tiebreaker like `Id`).
- You cannot jump to an arbitrary page number — only forward (or backward with reversed sort).
- Requires a composite index on the sort columns for performance.

---

## Global query filters

Global query filters are predicates applied automatically to all queries for an entity type. The two most common uses are soft delete and multi-tenancy.

### Soft delete

```csharp
// In OnModelCreating or IEntityTypeConfiguration.
modelBuilder.Entity<Order>()
    .HasQueryFilter(o => !o.IsDeleted);

// All queries automatically exclude soft-deleted rows.
var activeOrders = await db.Orders.ToListAsync(ct); // IsDeleted = false implied
```

### Multi-tenant

```csharp
public sealed class AppDbContext : DbContext
{
    private readonly ICurrentTenant _tenant;

    public AppDbContext(DbContextOptions<AppDbContext> options, ICurrentTenant tenant)
        : base(options)
    {
        _tenant = tenant;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Filter is evaluated per query — _tenant.Id is resolved at query time, not at startup.
        modelBuilder.Entity<Order>()
            .HasQueryFilter(o => o.TenantId == _tenant.Id);
    }
}
```

### Bypassing filters

When you genuinely need to query across tenants (admin reports, data migrations) or include soft-deleted records:

```csharp
// Ignore all global filters for this query.
var allOrders = await db.Orders
    .IgnoreQueryFilters()
    .Where(o => o.IsDeleted)
    .ToListAsync(ct);
```

### Performance implications

Global filters add a predicate to every query on the entity. Ensure that the filtered column(s) are indexed:

```csharp
modelBuilder.Entity<Order>()
    .HasIndex(o => o.TenantId);

modelBuilder.Entity<Order>()
    .HasIndex(o => o.IsDeleted)
    .HasFilter("IsDeleted = 0"); // Partial/filtered index — only indexes live rows (SQL Server/PostgreSQL).
```

A missing index on the filter column causes a full table scan on every query — a silent performance killer that appears only at scale.

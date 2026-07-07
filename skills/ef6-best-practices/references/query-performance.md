# EF6 — Query Performance

## Lazy Loading: The Default N+1 Trap

EF6 enables `LazyLoadingEnabled = true` by default. When a navigation property is accessed on a
tracked entity and the property has not been loaded, EF issues a new SQL `SELECT` automatically.

**Turn both off in the context constructor:**

```csharp
public class OrderContext : DbContext
{
    public OrderContext() : base("name=OrderDb")
    {
        Configuration.LazyLoadingEnabled = false;
        Configuration.ProxyCreationEnabled = false;
    }
}
```

Disabling proxy creation also reduces startup overhead and eliminates surprises when serializing
entities (serializers often trigger lazy loads).

---

## Eager Loading with `.Include()`

Always import `System.Data.Entity` to get the lambda overload.

```csharp
using System.Data.Entity;

// One level deep
var orders = ctx.Orders
    .Include(o => o.Customer)
    .ToList();

// Two levels deep — EF6 syntax uses Select() inside Include()
var orders = ctx.Orders
    .Include(o => o.Lines.Select(l => l.Product))
    .ToList();

// Multiple paths
var orders = ctx.Orders
    .Include(o => o.Customer)
    .Include(o => o.Lines.Select(l => l.Product))
    .Include(o => o.ShippingAddress)
    .ToList();
```

**EF6 does NOT have `.ThenInclude()`.** That API exists only in EF Core.

---

## Explicit Loading

When you need to load a navigation property conditionally:

```csharp
var order = ctx.Orders.Find(id); // loads Order only

if (needsLines)
{
    ctx.Entry(order).Collection(o => o.Lines).Load();
    // or async:
    await ctx.Entry(order).Collection(o => o.Lines).LoadAsync(ct);
}

if (needsCustomer)
{
    ctx.Entry(order).Reference(o => o.Customer).Load();
}
```

---

## `AsNoTracking()` — Read-Only Queries

For any query where you will not call `SaveChanges` on the results, add `AsNoTracking()`.

```csharp
var summaries = ctx.Orders
    .AsNoTracking()
    .Include(o => o.Customer)
    .Where(o => o.CreatedAt >= cutoff)
    .Select(o => new OrderSummaryDto
    {
        Id = o.Id,
        CustomerName = o.Customer.Name,
        Total = o.Lines.Sum(l => l.Quantity * l.UnitPrice)
    })
    .ToListAsync(ct);
```

**`MergeOption.NoTracking` on `ObjectContext`:** If working at the `ObjectContext` level, the
equivalent is `ObjectQuery<T>.MergeOption = MergeOption.NoTracking`.

---

## N+1 Detection and Prevention

### Detecting N+1

Enable query logging:

```csharp
ctx.Database.Log = sql => System.Diagnostics.Debug.WriteLine(sql);
```

If you see dozens of identical parameterized `SELECT` statements differing only by a foreign key value,
you have an N+1 problem.

### Prevention Checklist

1. Lazy loading disabled (Rule 2).
2. Every navigation access in a loop is covered by an `.Include()` before the loop.
3. DTO projections with `.Select()` avoid loading navigation properties as entities at all.

### DTO Projection — Fastest Read Pattern

```csharp
var dtos = ctx.Orders
    .Where(o => o.Status == OrderStatus.Pending)
    .Select(o => new OrderDto
    {
        Id = o.Id,
        CustomerName = o.Customer.Name,
        LineCount = o.Lines.Count()
    })
    .ToListAsync(ct);
```

No entity is materialized; no change tracking snapshot is taken.

---

## Compiled Queries

For high-frequency queries with fixed shapes:

```csharp
private static readonly Func<OrderContext, int, Order> GetOrderById =
    CompiledQuery.Compile<OrderContext, int, Order>(
        (ctx, id) => ctx.Orders.FirstOrDefault(o => o.Id == id));

using (var ctx = new OrderContext())
{
    var order = GetOrderById(ctx, id);
}
```

Limitations:
- Cannot be further composed (no additional `.Where()`, `.Include()`).
- `Include` is not composable with `CompiledQuery` in EF6.
- Normal LINQ queries cache the plan after first execution anyway.

---

## Query Plan Caching

EF6 caches parameterized query plans keyed on query structure. Build the query once, then filter:

```csharp
IQueryable<Order> query = ctx.Orders.AsNoTracking();

if (customerId.HasValue)
    query = query.Where(o => o.CustomerId == customerId.Value);

if (status.HasValue)
    query = query.Where(o => o.Status == status.Value);

var results = await query.ToListAsync(ct);
```

---

## Pagination

EF6 requires `.OrderBy()` before `.Skip()` and `.Take()`:

```csharp
var page = await ctx.Orders
    .AsNoTracking()
    .OrderByDescending(o => o.CreatedAt)
    .Skip((pageNumber - 1) * pageSize)
    .Take(pageSize)
    .ToListAsync(ct);
```

For very large tables, keyset pagination avoids the `OFFSET` performance cliff:

```csharp
var page = await ctx.Orders
    .AsNoTracking()
    .Where(o => o.CreatedAt < lastSeenCreatedAt)
    .OrderByDescending(o => o.CreatedAt)
    .Take(pageSize)
    .ToListAsync(ct);
```

---

## View Generation and Pre-Compiled Views

On first use of a `DbContext`, EF6 generates query views and validates the model. This causes a
cold-start delay for large models. Pre-generate views using EF Power Tools or T4 template to
eliminate the cold-start cost.

For large models (50+ entities), pre-compiled views are worth the setup cost.

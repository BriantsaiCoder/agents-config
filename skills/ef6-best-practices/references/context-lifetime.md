# EF6 — DbContext Lifetime Management

## Why Lifetime Matters

`System.Data.Entity.DbContext` is a thin wrapper over `ObjectContext`. Both maintain:

- An open (or pooled) database **connection**.
- An **identity map**: one instance per primary key per type.
- A **change tracker** (`ObjectStateManager`): snapshot of every tracked entity's original values.

The `ObjectStateManager` grows monotonically during the context's life. `SaveChanges` walks every
tracked entry to detect changes. A context kept alive for minutes (or the application lifetime) becomes
a memory leak and a performance sink.

---

## Correct Pattern: `using` Block Per Operation

```csharp
// One context per unit of work — dispose when done
public Order GetOrder(int id)
{
    using (var ctx = new OrderContext())
    {
        return ctx.Orders
            .Include(o => o.Lines)
            .AsNoTracking()
            .FirstOrDefault(o => o.Id == id);
    }
}

public void ShipOrder(int id)
{
    using (var ctx = new OrderContext())
    {
        var order = ctx.Orders.Find(id);
        if (order == null)
            throw new InvalidOperationException($"Order {id} not found.");

        order.Status = OrderStatus.Shipped;
        order.ShippedAt = DateTimeOffset.UtcNow;
        ctx.SaveChanges();
    }
}
```

Each method opens, uses, and disposes its own context. Connections return to the ADO.NET connection pool
immediately on dispose, keeping pool utilization low.

---

## Repository Pattern for EF6

EF6 is commonly used with Repository + Unit of Work without dependency injection (especially in
WebForms or WinForms apps). The pattern below keeps context creation centralized.

```csharp
// Unit of Work — owns the context for one logical operation
public sealed class UnitOfWork : IDisposable
{
    private readonly OrderContext _ctx;
    private bool _disposed;

    public UnitOfWork()
    {
        _ctx = new OrderContext();
    }

    private OrderRepository _orders;
    public OrderRepository Orders =>
        _orders ?? (_orders = new OrderRepository(_ctx));

    public int Complete() => _ctx.SaveChanges();

    public Task<int> CompleteAsync(CancellationToken ct = default) =>
        _ctx.SaveChangesAsync(ct);

    public void Dispose()
    {
        if (!_disposed)
        {
            _ctx.Dispose();
            _disposed = true;
        }
    }
}

// Repository — query logic lives here, not scattered in service classes
public class OrderRepository
{
    private readonly OrderContext _ctx;

    internal OrderRepository(OrderContext ctx)
    {
        _ctx = ctx;
    }

    public Task<List<Order>> GetPendingAsync(CancellationToken ct) =>
        _ctx.Orders
            .Include(o => o.Customer)
            .Include(o => o.Lines.Select(l => l.Product))
            .Where(o => o.Status == OrderStatus.Pending)
            .AsNoTracking()
            .ToListAsync(ct);

    public Task<Order> FindAsync(int id, CancellationToken ct) =>
        _ctx.Orders.FindAsync(ct, id);
}
```

Usage:

```csharp
using (var uow = new UnitOfWork())
{
    var order = await uow.Orders.FindAsync(id, ct);
    order.Status = OrderStatus.Shipped;
    await uow.CompleteAsync(ct);
}
```

---

## Why Short-Lived Contexts Are Critical

| Risk | Cause | Effect |
|------|-------|--------|
| Memory growth | Identity map accumulates entities | GC pressure; eventual `OutOfMemoryException` on servers |
| Stale data | Long-lived context caches entities from its first load | Reads outdated rows; update conflicts |
| Thread safety | `DbContext` is not thread-safe | Concurrent access causes `InvalidOperationException` |
| Connection exhaustion | Context holds connection open (in some configurations) | Pool starvation under load |
| `SaveChanges` slowdown | `ObjectStateManager` walks all tracked entities | Quadratic degradation as entity count grows |

---

## ObjectContext vs DbContext

`DbContext` is the public surface introduced in EF 4.1. `ObjectContext` is the lower-level API it
wraps. You interact with `DbContext` in virtually all EF6 code. Direct `ObjectContext` access is only
needed for operations not exposed through `DbContext`.

```csharp
// Access the underlying ObjectContext when needed
var objectContext = ((IObjectContextAdapter)ctx).ObjectContext;
objectContext.CommandTimeout = 120; // set query timeout in seconds

// ObjectStateManager (for diagnostics / manual state control)
var stateManager = objectContext.ObjectStateManager;
var entries = stateManager.GetObjectStateEntries(EntityState.Modified);
```

Key differences:

| Aspect | `DbContext` (EF6) | `ObjectContext` |
|--------|------------------|-----------------|
| Namespace | `System.Data.Entity` | `System.Data.Objects` |
| Introduced | EF 4.1 | EF 1.0 |
| API style | Fluent, LINQ-friendly | Verbose, query-string ESQL |
| Lazy loading | Controlled via `Configuration` property | Controlled via `ContextOptions` |
| Change tracking | `DbChangeTracker` wrapping `ObjectStateManager` | `ObjectStateManager` directly |

Prefer `DbContext` exclusively. Drop to `ObjectContext` only for timeout configuration or advanced
state manager manipulation.

---

## Connection Management and Pooling

EF6 uses ADO.NET connection pooling by default. Each `new DbContext()` does not necessarily open a new
physical connection — it borrows one from the pool and returns it on `Dispose()`. To benefit from pooling:

- Always dispose `DbContext` (via `using`).
- Do not set `ctx.Database.Connection.Open()` manually unless you have a specific reason.
- Keep the connection string consistent; ADO.NET pools per unique connection string.

---

## Anti-Patterns

### Static Context

```csharp
// WRONG — shared across all requests; not thread-safe; grows without bound
public static class Db
{
    public static readonly OrderContext Context = new OrderContext();
}
```

### Long-lived Context in WinForms / WPF

```csharp
// WRONG — form-level context lives for the form's lifetime
public partial class OrderForm : Form
{
    private readonly OrderContext _ctx = new OrderContext(); // never disposed until form closes
}
```

Prefer creating a new context for each button-click handler or command. For WPF MVVM, create a
context inside each `ICommand.Execute` implementation, not in the `ViewModel` constructor.

### Passing Context as a Parameter Through Layers

```csharp
// WRONG — context lifetime becomes hard to reason about
public void ProcessOrder(int id, OrderContext ctx) { ... }
```

Use the Repository / Unit of Work pattern so the context stays encapsulated and its lifetime is
controlled by a single `using` block.

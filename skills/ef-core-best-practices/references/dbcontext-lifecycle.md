# DbContext Lifecycle and Dependency Injection

Reference for DbContext registration, scoping, pooling, and thread-safety rules. Read this when designing a data-access layer, debugging a lifetime error, or adding a DbContext to a background service.

## Table of contents
- [DbContext in ASP.NET Core DI](#dbcontext-in-aspnet-core-di)
- [DbContextFactory pattern](#dbcontextfactory-pattern)
- [DbContext pooling](#dbcontext-pooling)
- [Thread safety](#thread-safety)
- [Anti-patterns](#anti-patterns)

---

## DbContext in ASP.NET Core DI

`AddDbContext<T>` registers the context with a **Scoped** lifetime by default — one instance per HTTP request. This is the correct default for web applications because:
- A single request is inherently single-threaded.
- One unit of work per request maps cleanly to one context per request.
- The context is disposed at the end of the request, releasing pooled connections.

```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
```

Inject via constructor:
```csharp
public sealed class OrderRepository
{
    private readonly AppDbContext _db;

    // EF Core registers the context; the DI container handles disposal.
    public OrderRepository(AppDbContext db) => _db = db;

    public async Task<Order?> FindAsync(int id, CancellationToken ct)
        => await _db.Orders.FindAsync([id], ct);
}
```

`AppDbContext` itself should have a single constructor that accepts `DbContextOptions<AppDbContext>`. Do not accept a raw connection string in the constructor — configuration belongs in `AddDbContext`.

```csharp
public sealed class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Order> Orders => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all IEntityTypeConfiguration<T> implementations from this assembly.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

---

## DbContextFactory pattern

Use `IDbContextFactory<T>` — instead of injecting the context directly — in three situations:

| Situation | Why |
|-----------|-----|
| Blazor Server components | Components have a longer lifetime than Scoped; a shared context accumulates change-tracker state across user interactions. |
| `BackgroundService` / hosted services | The service is Singleton; it cannot take a Scoped dependency directly. |
| Parallel work within one request | A single DbContext is not thread-safe; factory lets each parallel branch create its own instance. |

Registration:
```csharp
// AddDbContextFactory registers the factory as Singleton and the context as Transient.
builder.Services.AddDbContextFactory<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
```

Usage — always dispose the context after use:
```csharp
public sealed class ReportService
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    public ReportService(IDbContextFactory<AppDbContext> factory) => _factory = factory;

    public async Task<List<SalesSummary>> GetSummaryAsync(CancellationToken ct)
    {
        // Each call creates a fresh, short-lived context.
        await using var db = await _factory.CreateDbContextAsync(ct);
        return await db.Orders
            .AsNoTracking()
            .GroupBy(o => o.Region)
            .Select(g => new SalesSummary(g.Key, g.Sum(o => o.Total)))
            .ToListAsync(ct);
    }
}
```

In Blazor Server components, create one context per user operation, not one per component:
```csharp
// Blazor component — do NOT store a long-lived DbContext as a field.
@inject IDbContextFactory<AppDbContext> DbFactory

private async Task LoadDataAsync()
{
    await using var db = await DbFactory.CreateDbContextAsync();
    Items = await db.Products.AsNoTracking().ToListAsync();
}
```

In a `BackgroundService`, create a scope for scoped services and use the factory for the context:
```csharp
public sealed class DataSyncService : BackgroundService
{
    private readonly IDbContextFactory<AppDbContext> _factory;
    private readonly ILogger<DataSyncService> _logger;

    public DataSyncService(
        IDbContextFactory<AppDbContext> factory,
        ILogger<DataSyncService> logger)
    {
        _factory = factory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("DataSyncService starting.");
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var db = await _factory.CreateDbContextAsync(stoppingToken);
                await SyncBatchAsync(db, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // Normal shutdown — do not rethrow.
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Sync batch failed.");
            }
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
        _logger.LogInformation("DataSyncService stopped.");
    }
}
```

---

## DbContext pooling

Context pooling reuses `DbContext` instances across requests, similar to connection pooling. This avoids the overhead of re-running `OnModelCreating` and re-configuring options on every request. It is beneficial at high throughput (thousands of requests/second).

```csharp
// AddDbContextPool uses a pool of contexts rather than creating one per scope.
// Default pool size is 1024; tune based on load testing.
builder.Services.AddDbContextPool<AppDbContext>(
    options => options.UseSqlServer(builder.Configuration.GetConnectionString("Default")),
    poolSize: 128);
```

For factory-based access with pooling:
```csharp
builder.Services.AddPooledDbContextFactory<AppDbContext>(
    options => options.UseSqlServer(builder.Configuration.GetConnectionString("Default")),
    poolSize: 128);
```

### Pooling constraints

Pooling resets the change tracker between uses but does **not** re-run `OnConfiguring`. This has two important implications:

1. **Do not use `OnConfiguring` to configure options.** With pooling, `OnConfiguring` runs only once on the first context instance and is not called on returned instances. Put all configuration in the `AddDbContextPool` lambda.

2. **Instance state must be safe to reuse.** If you add custom fields to your `DbContext` subclass (e.g., a current-user property for multi-tenancy), EF Core will call `PoolingDbContextResetter` between uses. Override `OnModelCreating` but do not rely on constructor state that changes per-request.

Multi-tenant pooling with a custom tenant resolver:
```csharp
// This pattern lets each context know which tenant it belongs to
// while still benefiting from pooling.
public sealed class AppDbContext : DbContext
{
    // Set by the DI factory before returning the context to a scope.
    public string TenantId { get; private set; } = string.Empty;

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // Called by the pool when returning the context; reset per-request state here.
    public void SetTenant(string tenantId) => TenantId = tenantId;
}

// Custom factory that sets the tenant after leasing from the pool.
public sealed class TenantDbContextFactory
{
    private readonly IDbContextFactory<AppDbContext> _inner;
    private readonly ICurrentTenant _tenant;

    public TenantDbContextFactory(
        IDbContextFactory<AppDbContext> inner,
        ICurrentTenant tenant)
    {
        _inner = inner;
        _tenant = tenant;
    }

    public async Task<AppDbContext> CreateAsync(CancellationToken ct)
    {
        var db = await _inner.CreateDbContextAsync(ct);
        db.SetTenant(_tenant.Id);
        return db;
    }
}
```

---

## Thread safety

`DbContext` is **not thread-safe**. It maintains internal state (identity map, change tracker) that is not designed for concurrent access. EF Core throws `InvalidOperationException` if it detects a concurrent operation:

> A second operation was started on this context instance before a previous operation completed.

### Common mistakes

**Parallel.ForEach sharing one context:**
```csharp
// WRONG — all iterations share the same context concurrently.
await Parallel.ForEachAsync(customerIds, async (id, ct) =>
{
    var customer = await _db.Customers.FindAsync([id], ct); // race condition
    customer!.LastSeen = DateTimeOffset.UtcNow;
    await _db.SaveChangesAsync(ct);
});
```

**Task.WhenAll with one context:**
```csharp
// WRONG — both awaited queries run concurrently on the same context instance.
var ordersTask = _db.Orders.ToListAsync(ct);
var customersTask = _db.Customers.ToListAsync(ct);
await Task.WhenAll(ordersTask, customersTask);
```

### Solution: one context per parallel branch

```csharp
// CORRECT — each task gets its own context from the factory.
await Parallel.ForEachAsync(customerIds, new ParallelOptions { CancellationToken = ct }, async (id, innerCt) =>
{
    await using var db = await _factory.CreateDbContextAsync(innerCt);
    var customer = await db.Customers.FindAsync([id], innerCt);
    if (customer is null) return;
    customer.LastSeen = DateTimeOffset.UtcNow;
    await db.SaveChangesAsync(innerCt);
});
```

**EnableThreadSafetyChecks** (EF Core 9+):
```csharp
// Only disable after thorough load testing proves your access pattern is actually safe.
// Disabling this hides real bugs; leave it enabled in development and staging.
options.EnableThreadSafetyChecks(false);
```

---

## Anti-patterns

### Singleton DbContext

```csharp
// WRONG — Singleton lifetime means one context for the entire application lifetime.
// The change tracker accumulates entities forever; queries slow down; no isolation between requests.
builder.Services.AddSingleton<AppDbContext>(); // never do this
```

### DbContext in a static field

```csharp
// WRONG — Static fields have application lifetime.
// Thread-unsafe, leaks memory, no connection-pool benefits.
public static class Database
{
    public static readonly AppDbContext Context = new(options); // never do this
}
```

### Resolving a Scoped DbContext from a Singleton service

```csharp
// WRONG — IServiceProvider.GetRequiredService inside a Singleton captures the root scope,
// which means the DbContext is never disposed.
public sealed class MySingletonService
{
    private readonly AppDbContext _db;

    public MySingletonService(IServiceProvider sp)
    {
        _db = sp.GetRequiredService<AppDbContext>(); // root scope, never disposed
    }
}
```

The correct fix is to use `IDbContextFactory<T>` in Singleton services or to create an explicit scope per operation via `IServiceScopeFactory`:

```csharp
// CORRECT — Create and dispose a scope per operation.
public sealed class MySingletonService
{
    private readonly IServiceScopeFactory _scopeFactory;

    public MySingletonService(IServiceScopeFactory scopeFactory)
        => _scopeFactory = scopeFactory;

    public async Task DoWorkAsync(CancellationToken ct)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        // Use db here; it is disposed when the scope is disposed.
    }
}
```

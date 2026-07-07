# Architecture and Dependency Injection

Reference for the built-in DI container, service lifetimes, the Options pattern, project structure, and common DI patterns in .NET 6+/8/10. Read this when registering services, debugging lifetime issues, designing project layout, or implementing cross-cutting patterns like factories, decorators, and strategies.

## Table of contents
- [Built-in DI container](#built-in-di-container)
- [Service lifetimes deep dive](#service-lifetimes-deep-dive)
- [Options pattern](#options-pattern)
- [Project structure](#project-structure)
- [Common DI patterns](#common-di-patterns)

---

## Built-in DI container

### Service registration basics

The built-in container supports three lifetimes via explicit registration methods:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddScoped<IOrderService, OrderService>();       // one per request/scope
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();  // new instance per injection
builder.Services.AddSingleton<ICacheService, MemoryCacheService>(); // one for the app lifetime
```

### Constructor injection

Constructor injection is the default and preferred pattern. The container resolves all constructor parameters automatically. Keep constructors focused — if a class needs more than 4-5 dependencies, it likely violates the single responsibility principle.

```csharp
public sealed class OrderService : IOrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }
}
```

### Multiple implementations of the same interface

When multiple classes implement the same interface, the last registration wins for single-injection. Use `IEnumerable<T>` to get all implementations:

```csharp
builder.Services.AddScoped<INotificationSender, EmailNotificationSender>();
builder.Services.AddScoped<INotificationSender, SmsNotificationSender>();
builder.Services.AddScoped<INotificationSender, PushNotificationSender>();

// Inject all — the container provides all three
public sealed class NotificationDispatcher(IEnumerable<INotificationSender> senders)
{
    public async Task NotifyAllAsync(string message, CancellationToken ct)
    {
        foreach (var sender in senders)
            await sender.SendAsync(message, ct);
    }
}
```

### Keyed services (.NET 8+)

Keyed services let you register and resolve multiple implementations by a key, replacing the need for manual factory patterns:

```csharp
builder.Services.AddKeyedScoped<IPaymentGateway, StripeGateway>("stripe");
builder.Services.AddKeyedScoped<IPaymentGateway, PayPalGateway>("paypal");
builder.Services.AddKeyedSingleton<IPaymentGateway, MockGateway>("mock");

// Resolve by key in constructors
public sealed class CheckoutService(
    [FromKeyedServices("stripe")] IPaymentGateway gateway)
{
    public Task ChargeAsync(decimal amount, CancellationToken ct)
        => gateway.ProcessPaymentAsync(amount, ct);
}

// Resolve by key in Minimal API endpoints
app.MapPost("/pay/{provider}", async (
    string provider,
    [FromKeyedServices("stripe")] IPaymentGateway stripe,
    [FromKeyedServices("paypal")] IPaymentGateway paypal) =>
{
    var gateway = provider == "paypal" ? paypal : stripe;
    await gateway.ProcessPaymentAsync(100m, default);
    return Results.Ok();
});
```

### Open generic registration

Register an open generic to avoid registering every closed type individually:

```csharp
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
builder.Services.AddScoped(typeof(IValidator<>), typeof(DataAnnotationsValidator<>));

// The container closes the generic when resolving
public sealed class OrderService(IRepository<Order> repo) { }
public sealed class CustomerService(IRepository<Customer> repo) { }
```

### TryAdd* methods

Use `TryAdd*` to register only if no implementation is already registered. This is essential for library authors to avoid overriding application-level registrations:

```csharp
using Microsoft.Extensions.DependencyInjection.Extensions;

// Only registers if IOrderService has no existing registration
builder.Services.TryAddScoped<IOrderService, OrderService>();
builder.Services.TryAddSingleton<ICacheService, MemoryCacheService>();

// TryAddEnumerable prevents duplicate implementations in IEnumerable<T>
builder.Services.TryAddEnumerable(
    ServiceDescriptor.Scoped<INotificationSender, EmailNotificationSender>());
```

---

## Service lifetimes deep dive

### Scoped — one per request/scope

A scoped service is created once per DI scope. In ASP.NET Core, each HTTP request automatically creates a scope. Ideal for `DbContext`, unit-of-work, and per-request state like the current user.

```csharp
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();
```

### Transient — new instance per injection

A transient service is created every time it is requested from the container. Ideal for stateless, lightweight services where sharing an instance is unnecessary or undesirable.

```csharp
builder.Services.AddTransient<IDateTimeProvider, UtcDateTimeProvider>();
builder.Services.AddTransient<ISlugGenerator, SlugGenerator>();
```

Avoid transient for services that hold expensive resources (connections, large buffers) — each injection creates a new instance, and disposal depends on the containing scope.

### Singleton — shared across all requests

A singleton is created once and lives for the application lifetime. It must be **thread-safe** because concurrent requests share the same instance.

```csharp
builder.Services.AddSingleton<IExchangeRateCache, ExchangeRateCache>();

// Must be thread-safe — use ConcurrentDictionary, Interlocked, or immutable data
public sealed class ExchangeRateCache : IExchangeRateCache
{
    private readonly ConcurrentDictionary<string, decimal> _rates = new();

    public decimal GetRate(string currency)
        => _rates.GetOrAdd(currency, _ => FetchFromApi(currency));
}
```

### Captive dependency problem

A **captive dependency** occurs when a shorter-lived service is injected into a longer-lived one. The short-lived instance is "captured" and lives beyond its intended lifetime.

```csharp
// WRONG — Scoped service captured by Singleton. The DbContext lives forever,
// leaking connections and serving stale data.
builder.Services.AddSingleton<IReportService, ReportService>(); // lives forever
builder.Services.AddScoped<AppDbContext>();                      // should live per-request

public sealed class ReportService(AppDbContext db) : IReportService
{
    // db was created once at startup and never disposed — stale data, connection leaks
}
```

### ValidateScopes and ValidateOnBuild

Enable both in development to catch lifetime mismatches and missing registrations at startup instead of at runtime:

```csharp
var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    builder.Host.UseDefaultServiceProvider(options =>
    {
        options.ValidateScopes = true;   // catches captive dependencies
        options.ValidateOnBuild = true;  // catches missing registrations
    });
}
```

`ValidateScopes` throws an `InvalidOperationException` when a scoped service is resolved from the root provider (which is what happens when a singleton depends on a scoped service). `ValidateOnBuild` iterates all registrations at startup and tries to resolve them, surfacing any missing dependency chains immediately.

---

## Options pattern

### IOptions&lt;T&gt; — singleton, bound once

Read once at startup. Cheapest option. Use when configuration does not change at runtime.

```csharp
public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    [Required] public string Host { get; set; } = "";
    [Range(1, 65535)] public int Port { get; set; } = 587;
    public bool UseSsl { get; set; } = true;
}

builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration(SmtpOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();  // fail at startup, not on first request

public sealed class EmailSender(IOptions<SmtpOptions> options)
{
    private readonly SmtpOptions _smtp = options.Value;
}
```

### IOptionsSnapshot&lt;T&gt; — scoped, re-read per request

Re-reads configuration on each request. Use when configuration may change without restarting the application (e.g., Azure App Configuration, file reload).

```csharp
// IOptionsSnapshot<T> is scoped — cannot be injected into singletons
public sealed class FeatureFlagService(IOptionsSnapshot<FeatureFlags> options)
{
    public bool IsEnabled(string flag) => options.Value.EnabledFlags.Contains(flag);
}
```

### IOptionsMonitor&lt;T&gt; — singleton with change notifications

Singleton that reacts to configuration changes via a callback. Ideal for long-lived services (singletons, background services) that need to pick up config changes.

```csharp
public sealed class RateLimitService : IDisposable
{
    private RateLimitOptions _current;
    private readonly IDisposable? _onChange;

    public RateLimitService(IOptionsMonitor<RateLimitOptions> monitor)
    {
        _current = monitor.CurrentValue;
        _onChange = monitor.OnChange(updated => _current = updated);
    }

    public bool IsAllowed() => _current.MaxRequestsPerMinute > 0;
    public void Dispose() => _onChange?.Dispose();
}
```

### Named options

Use named options when you need multiple instances of the same configuration type:

```csharp
builder.Services.AddOptions<StorageOptions>("primary")
    .BindConfiguration("Storage:Primary");
builder.Services.AddOptions<StorageOptions>("archive")
    .BindConfiguration("Storage:Archive");

public sealed class StorageService(IOptionsSnapshot<StorageOptions> options)
{
    public string GetPrimaryPath() => options.Get("primary").BasePath;
    public string GetArchivePath() => options.Get("archive").BasePath;
}
```

### Post-configure and validation

`PostConfigure` runs after all `Configure` calls, useful for computing derived values. Custom validation provides richer checks than data annotations alone:

```csharp
builder.Services.AddOptions<DatabaseOptions>()
    .BindConfiguration("Database")
    .PostConfigure(opts =>
    {
        if (string.IsNullOrEmpty(opts.Schema))
            opts.Schema = "dbo";
    })
    .Validate(opts =>
    {
        if (opts.MaxRetries < 0)
            return false;
        if (opts.ConnectionString.Contains("password=", StringComparison.OrdinalIgnoreCase)
            && !opts.ConnectionString.Contains("Encrypt=true", StringComparison.OrdinalIgnoreCase))
            return false;
        return true;
    }, "Database config is invalid: negative retries or unencrypted password connection.")
    .ValidateOnStart();
```

---

## Project structure

### Minimal API — single project

Best for small services, microservices, and APIs with fewer than 10-15 endpoints. All code lives in one project.

```
MyService/
  Program.cs
  Endpoints/
    OrderEndpoints.cs
    CustomerEndpoints.cs
  Services/
    OrderService.cs
  Models/
    Order.cs
  MyService.csproj
```

### Clean Architecture — layered projects

Best for complex domains with rich business logic. Dependencies point inward — outer layers depend on inner layers, never the reverse.

```
src/
  MyApp.Domain/          # Entities, value objects, domain events, interfaces
  MyApp.Application/     # Use cases, DTOs, validation, IRepository<T>
  MyApp.Infrastructure/  # EF Core, external APIs, file system, email
  MyApp.API/             # Controllers or Minimal API, middleware, DI wiring
```

The API project references Application and Infrastructure. Application references only Domain. Infrastructure references Domain and Application (to implement interfaces).

### Vertical slice architecture

Organized by feature instead of layer. Each feature folder contains its endpoint, handler, validator, and DTOs. Reduces cross-feature coupling and keeps related code together.

```
src/
  MyApp/
    Features/
      Orders/
        CreateOrder.cs        # endpoint + handler + DTO + validation
        GetOrderById.cs
        CancelOrder.cs
      Customers/
        RegisterCustomer.cs
        GetCustomerProfile.cs
    Common/
      Middleware/
      Extensions/
```

### When to split vs keep together

| Signal | Action |
|--------|--------|
| Fewer than 15 endpoints, simple CRUD | Single project |
| Shared domain model across multiple APIs | Split to Domain + shared contracts |
| Team ownership boundaries | Separate projects per team boundary |
| Independent deployment needed | Separate projects or separate repositories |
| Complex business rules | Clean Architecture with Domain isolation |

---

## Common DI patterns

### Factory pattern — IServiceScopeFactory

Use `IServiceScopeFactory` when a singleton or background service needs access to scoped services. Create and dispose a scope per operation:

```csharp
public sealed class OrderProcessingJob : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OrderProcessingJob> _logger;

    public OrderProcessingJob(
        IServiceScopeFactory scopeFactory,
        ILogger<OrderProcessingJob> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();
            await orderService.ProcessPendingOrdersAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

### Decorator pattern

Decorators wrap an existing service to add cross-cutting behavior (logging, caching, retry). Register manually or use the Scrutor library:

```csharp
// Manual decorator registration
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.Decorate<IOrderService, LoggingOrderServiceDecorator>();
// Requires the Scrutor NuGet package for the Decorate extension method.

// Manual registration without Scrutor
builder.Services.AddScoped<OrderService>();
builder.Services.AddScoped<IOrderService>(sp =>
    new LoggingOrderServiceDecorator(
        sp.GetRequiredService<OrderService>(),
        sp.GetRequiredService<ILogger<LoggingOrderServiceDecorator>>()));

public sealed class LoggingOrderServiceDecorator : IOrderService
{
    private readonly IOrderService _inner;
    private readonly ILogger _logger;

    public LoggingOrderServiceDecorator(IOrderService inner, ILogger<LoggingOrderServiceDecorator> logger)
    {
        _inner = inner;
        _logger = logger;
    }

    public async Task<Order> CreateAsync(CreateOrderDto dto, CancellationToken ct)
    {
        _logger.LogInformation("Creating order for {CustomerId}", dto.CustomerId);
        var result = await _inner.CreateAsync(dto, ct);
        _logger.LogInformation("Created order {OrderId}", result.Id);
        return result;
    }
}
```

### Strategy pattern with keyed services or IEnumerable&lt;T&gt;

Use keyed services (.NET 8+) when you select a strategy by a known key. Use `IEnumerable<T>` when you need to iterate all strategies:

```csharp
// Keyed services — select by key
builder.Services.AddKeyedScoped<IExportStrategy, CsvExportStrategy>("csv");
builder.Services.AddKeyedScoped<IExportStrategy, PdfExportStrategy>("pdf");
builder.Services.AddKeyedScoped<IExportStrategy, ExcelExportStrategy>("xlsx");

app.MapGet("/export/{format}", async (
    string format,
    [FromKeyedServices("csv")] IExportStrategy csv,
    [FromKeyedServices("pdf")] IExportStrategy pdf,
    [FromKeyedServices("xlsx")] IExportStrategy xlsx,
    CancellationToken ct) =>
{
    var strategy = format switch
    {
        "csv" => csv,
        "pdf" => pdf,
        "xlsx" => xlsx,
        _ => throw new ArgumentException($"Unknown format: {format}")
    };
    return Results.File(await strategy.ExportAsync(ct), strategy.ContentType);
});

// IEnumerable<T> — run all validators
builder.Services.AddScoped<IOrderValidator, StockValidator>();
builder.Services.AddScoped<IOrderValidator, CreditValidator>();
builder.Services.AddScoped<IOrderValidator, FraudValidator>();

public sealed class OrderValidationService(IEnumerable<IOrderValidator> validators)
{
    public async Task<ValidationResult> ValidateAsync(Order order, CancellationToken ct)
    {
        var errors = new List<string>();
        foreach (var validator in validators)
        {
            var result = await validator.ValidateAsync(order, ct);
            if (!result.IsValid)
                errors.AddRange(result.Errors);
        }
        return errors.Count == 0
            ? ValidationResult.Success()
            : ValidationResult.Failure(errors);
    }
}
```

### Lazy&lt;T&gt; and IServiceProvider for deferred resolution

Use `Lazy<T>` to defer construction of expensive services until first use. Use `IServiceProvider` only as a last resort — it hides dependencies and makes code harder to test:

```csharp
// Lazy<T> — deferred construction
builder.Services.AddSingleton<ExpensiveAnalyticsEngine>();
builder.Services.AddSingleton(sp =>
    new Lazy<ExpensiveAnalyticsEngine>(
        () => sp.GetRequiredService<ExpensiveAnalyticsEngine>()));

public sealed class ReportService(Lazy<ExpensiveAnalyticsEngine> engine)
{
    public async Task<Report> GenerateAsync(ReportRequest request, CancellationToken ct)
    {
        if (!request.IncludeAnalytics)
            return await GenerateBasicReportAsync(request, ct);

        // Engine is only constructed on first access
        return await engine.Value.AnalyzeAsync(request, ct);
    }
}

// IServiceProvider — avoid when possible, use only for dynamic resolution
public sealed class PluginHost(IServiceProvider sp)
{
    public IPlugin Resolve(string pluginName)
    {
        // Acceptable when the type is truly dynamic and not known at compile time.
        // Prefer keyed services (.NET 8+) over this pattern when keys are known ahead of time.
        return sp.GetRequiredKeyedService<IPlugin>(pluginName);
    }
}
```

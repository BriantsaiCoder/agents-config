# .NET 6+ Code Patterns per Golden Rule

Complete code examples for each Golden Rule in main `SKILL.md`, plus the 7-step writing pattern, Console app patterns, and .NET version feature matrix. For deeper treatment of DI, hosting, API design, security/performance, see the other reference files in this folder.

## Rule 1 — DI lifetimes + keyed services (.NET 8+)

```csharp
var builder = WebApplication.CreateBuilder(args);

// Correct lifetime choices
builder.Services.AddScoped<IOrderService, OrderService>();     // per-request
builder.Services.AddSingleton<ICacheService, CacheService>();  // shared, thread-safe
builder.Services.AddTransient<IEmailSender, EmailSender>();    // new instance each time

// .NET 8+ keyed services
builder.Services.AddKeyedScoped<IPaymentGateway, StripeGateway>("stripe");
builder.Services.AddKeyedScoped<IPaymentGateway, PayPalGateway>("paypal");

// Catch captive dependencies in development
if (builder.Environment.IsDevelopment())
{
    builder.Host.UseDefaultServiceProvider(options =>
    {
        options.ValidateScopes = true;
        options.ValidateOnBuild = true;
    });
}
```

## Rule 2 — Options pattern

```csharp
// Strongly-typed options class
public class SmtpOptions
{
    public const string SectionName = "Smtp";

    [Required] public string Host { get; set; } = "";
    [Range(1, 65535)] public int Port { get; set; } = 587;
    public string? Username { get; set; }
}

// Register with validation
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration(SmtpOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart(); // fail fast if config is invalid

// Inject
public class EmailSender(IOptions<SmtpOptions> options)
{
    private readonly SmtpOptions _smtp = options.Value;
}
```

**When to use which:**
- `IOptions<T>` — singleton, read once at startup, cheapest
- `IOptionsSnapshot<T>` — scoped, re-reads per request, good for config that changes
- `IOptionsMonitor<T>` — singleton, reacts to changes via callback, good for long-lived services

## Rule 3 — IHttpClientFactory + resilience

```csharp
// Registration
builder.Services.AddHttpClient("github", client =>
{
    client.BaseAddress = new Uri("https://api.github.com/");
    client.DefaultRequestHeaders.Add("User-Agent", "MyApp");
})
.AddStandardResilienceHandler(); // .NET 8+ built-in Polly integration

// Usage via typed client
public class GitHubService(HttpClient httpClient)
{
    public async Task<string> GetRepoAsync(string owner, string repo, CancellationToken ct)
        => await httpClient.GetStringAsync($"repos/{owner}/{repo}", ct);
}
```

**Resilience exception handling**: Callers must handle `BrokenCircuitException` (circuit breaker open) and `TimeoutRejectedException` explicitly. Return appropriate HTTP status codes (503, 504) instead of letting them bubble up as 500.

**Idempotency with retries**: For non-idempotent operations (POST creating records, payment charges), include an `Idempotency-Key` header so downstream services can deduplicate. Without this, retries cause duplicate records or double charges.

## Rule 4 — Middleware order

```csharp
var app = builder.Build();

// Canonical middleware order
app.UseExceptionHandler("/error");
app.UseHsts();
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();        // .NET 7+
app.UseOutputCache();         // .NET 7+
app.MapControllers();
```

## Rule 5 — Minimal API with route groups

```csharp
// Minimal API — good for simple, focused endpoints
var group = app.MapGroup("/api/orders").RequireAuthorization();

group.MapGet("/", async (IOrderService svc, CancellationToken ct) =>
    Results.Ok(await svc.GetAllAsync(ct)));

group.MapGet("/{id:int}", async (int id, IOrderService svc, CancellationToken ct) =>
    await svc.GetByIdAsync(id, ct) is { } order
        ? Results.Ok(order)
        : Results.NotFound());

group.MapPost("/", async (CreateOrderDto dto, IOrderService svc, CancellationToken ct) =>
{
    var result = await svc.CreateAsync(dto, ct);
    return Results.Created($"/api/orders/{result.Id}", result);
});
```

## Rule 6 — Structured logging

```csharp
// ❌ Wrong — string interpolation defeats structured logging
_logger.LogInformation($"Order {order.Id} created for {order.CustomerId}");

// ✅ Correct — named placeholders enable structured queries
_logger.LogInformation("Order {OrderId} created for {CustomerId}",
    order.Id, order.CustomerId);
```

## Rule 7 — CancellationToken propagation

```csharp
app.MapGet("/api/reports/{id}", async (
    int id,
    IReportService svc,
    CancellationToken ct) =>    // auto-bound by ASP.NET Core
{
    return await svc.GenerateAsync(id, ct);
});
```

## Rule 8 — Health checks

```csharp
builder.Services.AddHealthChecks()
    .AddSqlServer(connectionString, name: "database")
    .AddRedis(redisConnectionString, name: "cache");

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false // liveness = app process is running
});
```

## Rule 9 — Secrets management

```csharp
// Development — User Secrets (stored outside repo)
// dotnet user-secrets set "Jwt:SigningKey" "my-secret-key"

// Production — environment variables or vault
builder.Configuration.AddAzureKeyVault(
    new Uri("https://myvault.vault.azure.net/"),
    new DefaultAzureCredential());
```

## Rule 10 — ProblemDetails global error handling

```csharp
// .NET 8+ ProblemDetails integration
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
    };
});

app.UseExceptionHandler();  // uses ProblemDetails automatically in .NET 8+
app.UseStatusCodePages();
```

## Rule 11 — Authorization policies

```csharp
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"))
    .AddPolicy("CanManageOrders", policy =>
        policy.RequireClaim("permission", "orders.manage"));

// Apply to Minimal API
app.MapDelete("/api/orders/{id}", ...).RequireAuthorization("CanManageOrders");

// Apply to Controller
[Authorize(Policy = "CanManageOrders")]
public IActionResult Delete(int id) { /* ... */ }
```

## .NET Version Feature Matrix

| Version | Key Features |
|---------|-------------|
| .NET 6 | Minimal API, global usings, file-scoped namespaces, `DateOnly`/`TimeOnly` |
| .NET 7 | Rate limiting middleware, output caching, `IResult` improvements, `StringSyntaxAttribute` |
| .NET 8 | Keyed DI services, Identity API endpoints, native AOT, `TimeProvider`, `FrozenDictionary`, `IExceptionHandler` |
| .NET 9 | `HybridCache`, built-in OpenAPI, `SearchValues<T>`, `Task.WhenEach`, LINQ `CountBy`/`AggregateBy` |
| .NET 10 | Extended `Minimal API`, improved AOT, enhanced `System.Text.Json` source gen |

## 7-Step Writing Pattern for New .NET 6+ Code

1. **Choose the hosting model.** `WebApplication.CreateBuilder()` for web APIs. `Host.CreateDefaultBuilder()` for Worker Services. Minimal API for simple endpoints, Controllers for complex APIs with filters and versioning.

2. **Register services with correct lifetimes.** Scoped for per-request services and DbContext. Singleton for thread-safe shared state and `IHttpClientFactory` configurations. Transient for stateless utilities. Enable `ValidateScopes` and `ValidateOnBuild` in development.

3. **Configure with the Options pattern.** Bind configuration sections to strongly-typed classes. Add `ValidateDataAnnotations()` and `ValidateOnStart()` for fail-fast behavior.

4. **Set up middleware in the correct order.** Exception handling → HTTPS → Static files → Routing → CORS → Authentication → Authorization → Rate limiting → Output cache → Endpoints.

5. **Use async with CancellationToken throughout.** Every async method accepts and forwards `CancellationToken`. Use `ILogger<T>` with message templates for structured logging.

6. **Configure health checks.** Add checks for database, cache, and external dependencies. Expose `/health/ready` and `/health/live` endpoints.

7. **Secure the application.** Use authorization policies (not inline role checks), store secrets in User Secrets / vault, enable CORS only for known origins, use `ProblemDetails` for error responses.

## Console Application Patterns (.NET 6+)

### Generic Host for Console Apps

```csharp
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddHostedService<DataImportWorker>();
builder.Services.AddScoped<IOrderProcessor, OrderProcessor>();

var host = builder.Build();
await host.RunAsync();
```

### One-Shot Console App (Run and Exit)

```csharp
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddScoped<IDataMigrator, DataMigrator>();

using var host = builder.Build();
using var scope = host.Services.CreateScope();
var migrator = scope.ServiceProvider.GetRequiredService<IDataMigrator>();
await migrator.ExecuteAsync(CancellationToken.None);
```

## Logging Integration Quick Examples

For comprehensive logging guidance, see the **dotnet-logging-best-practices** skill.

### High-Performance Logging with Source Generators

```csharp
public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information,
        Message = "Order {OrderId} created for customer {CustomerId}")]
    public static partial void OrderCreated(ILogger logger, int orderId, string customerId);
}

// Zero-allocation when level is disabled
LogMessages.OrderCreated(_logger, order.Id, order.CustomerId);
```

### Serilog Integration

```csharp
builder.Host.UseSerilog((context, config) => config
    .ReadFrom.Configuration(context.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/app-.log", rollingInterval: RollingInterval.Day));

app.UseSerilogRequestLogging(); // structured HTTP request logs
```

## C# 12 / .NET 8+ Syntax Preferences

Modern C# syntax that the 7-step pattern assumes. Use these consistently in new code.

```csharp
// Primary constructors — replaces field + ctor boilerplate
public sealed class OrderService(IOrderRepository repo, ILogger<OrderService> logger) : IOrderService
{
    public Task<Order?> GetAsync(int id, CancellationToken ct) => repo.GetByIdAsync(id, ct);
}

// Collection expressions
int[] statuses = [200, 201, 204];
List<string> tags = ["new", "featured"];

// required + init for immutable DTOs / domain objects
public sealed class CreateOrderDto
{
    public required string CustomerId { get; init; }
    public required IReadOnlyList<OrderLine> Lines { get; init; }
}

// Records for DTOs (value equality, terse syntax)
public record OrderResponse(int Id, string CustomerId, decimal Total);

// File-scoped namespace (one per file)
namespace MyApp.Orders;

// Pattern-matching null checks (prefer over == null)
if (order is null) return Results.NotFound();
if (order is { Status: OrderStatus.Paid } paid) { /* use paid */ }
```

Naming: PascalCase for types/methods, camelCase for locals/params, `I` prefix for interfaces, `Async` suffix for async methods. Prefer descriptive names (`cancellationToken`) over short ones (`ct`) in public APIs; `ct` is acceptable in private helpers and samples.

## Advanced Async Patterns

Extensions beyond Rule 7. See also `references/security-performance.md#async-best-practices` for ValueTask / Channel / async void.

### Bounded concurrency

```csharp
// .NET 6+ Parallel.ForEachAsync — preferred
await Parallel.ForEachAsync(
    ids,
    new ParallelOptions { MaxDegreeOfParallelism = 10, CancellationToken = ct },
    async (id, token) => await ProcessAsync(id, token));

// Pre-.NET 6 or finer control — SemaphoreSlim
using var gate = new SemaphoreSlim(10);
var tasks = ids.Select(async id =>
{
    await gate.WaitAsync(ct);
    try { await ProcessAsync(id, ct); }
    finally { gate.Release(); }
});
await Task.WhenAll(tasks);
```

### Linked cancellation tokens

Combine request cancellation with a timeout (or any secondary token):

```csharp
using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
var result = await upstream.FetchAsync(linked.Token);
```

### IAsyncEnumerable with cancellation

`[EnumeratorCancellation]` is required for the consumer's `WithCancellation(ct)` to propagate into the iterator body.

```csharp
public async IAsyncEnumerable<Order> StreamAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    await foreach (var row in _repo.ReadAllAsync(ct))
        yield return row;
}
```

### Collecting all exceptions from Task.WhenAll

`await Task.WhenAll(...)` rethrows only the first exception. To inspect all failures:

```csharp
var tasks = items.Select(i => ProcessAsync(i, ct)).ToList();
try { await Task.WhenAll(tasks); }
catch
{
    var failures = tasks.Where(t => t.IsFaulted)
                        .SelectMany(t => t.Exception!.InnerExceptions)
                        .ToList();
    throw new AggregateException(failures);
}
```

## Result Pattern for Expected Failures

Global CLAUDE.md preference: use Result for predictable business failures (validation, not-found, domain rule violation); reserve exceptions for system errors and invariant breaks. Pairs with Rule 10 (`ProblemDetails` converts unhandled exceptions at the edge).

```csharp
public readonly record struct Result<T>(bool IsSuccess, T? Value, string? Error, string? Code)
{
    public static Result<T> Ok(T value) => new(true, value, null, null);
    public static Result<T> Fail(string code, string error) => new(false, default, error, code);
}

public async Task<Result<Order>> CreateAsync(CreateOrderDto dto, CancellationToken ct)
{
    if (dto.Lines.Count == 0)
        return Result<Order>.Fail("orders.empty", "Order must have at least one line.");
    // ...
    return Result<Order>.Ok(order);
}

// Endpoint converts Result → HTTP
app.MapPost("/api/orders", async (CreateOrderDto dto, IOrderService svc, CancellationToken ct) =>
{
    var r = await svc.CreateAsync(dto, ct);
    return r.IsSuccess
        ? Results.Created($"/api/orders/{r.Value!.Id}", r.Value)
        : Results.Problem(title: r.Error, statusCode: 400, extensions: new Dictionary<string, object?> { ["code"] = r.Code });
});
```

Keep the shape compatible with the standard error envelope `{ error, code, details? }`.

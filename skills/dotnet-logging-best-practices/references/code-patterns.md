<!-- last-verified: 2026-07-26 -->
# .NET Logging — Code Patterns per Golden Rule

Complete code examples for each Golden Rule in the main `SKILL.md`, plus the .NET 6+ / .NET Framework platform quick reference. For Serilog-specific patterns see `serilog-deep-dive.md`; for NLog/log4net see `nlog-log4net-guide.md`.

## Rule 1 — Structured logging (message templates, not interpolation)

```csharp
// ❌ Wrong — string interpolation defeats structured logging
_logger.LogInformation($"Order {order.Id} created for {customer.Name}");

// ❌ Wrong — string concatenation, same problem plus allocates even when disabled
_logger.LogDebug("Processing item " + item.Id + " weight " + item.Weight);

// ✅ Correct — message template with named placeholders
_logger.LogInformation("Order {OrderId} created for {CustomerName}",
    order.Id, customer.Name);
```

**Template naming convention**: Use PascalCase for placeholder names (`{OrderId}`, not `{orderId}`). This creates consistent field names across your log storage.

## Rule 2 — Log level matrix

| Level | Use For | Production Default |
|-------|---------|-------------------|
| **Critical** | Application crash, data corruption, unrecoverable state | Always on |
| **Error** | Operation failed, needs attention (exception caught, retry exhausted) | Always on |
| **Warning** | Unexpected but recoverable (deprecated API, slow query, approaching limit) | Always on |
| **Information** | Business events (order created, user login, job completed) | On |
| **Debug** | Developer diagnostics (method flow, intermediate state) | Off |
| **Trace** | Verbose internals (raw payloads, SQL parameters, wire data) | Off |

## Rule 3 — `[LoggerMessage]` source generator (zero allocation when disabled)

```csharp
// .NET 6+ source generator — compile-time generated, zero-allocation
public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information,
        Message = "Order {OrderId} processed in {ElapsedMs}ms")]
    public static partial void OrderProcessed(ILogger logger, int orderId, long elapsedMs);

    [LoggerMessage(Level = LogLevel.Warning,
        Message = "Retry {Attempt} for order {OrderId}")]
    public static partial void RetryAttempt(ILogger logger, int attempt, int orderId);
}

// Usage — no boxing, no allocation when level is disabled
LogMessages.OrderProcessed(_logger, order.Id, stopwatch.ElapsedMilliseconds);
```

**.NET Framework alternative** — `LoggerMessage.Define`:
```csharp
private static readonly Action<ILogger, int, long, Exception?> _orderProcessed =
    LoggerMessage.Define<int, long>(LogLevel.Information,
        new EventId(1001, "OrderProcessed"),
        "Order {OrderId} processed in {ElapsedMs}ms");

_orderProcessed(_logger, order.Id, elapsed, null);
```

## Rule 4 — Guard expensive log parameters with `IsEnabled`

```csharp
// ❌ Wrong — ComputeHash runs even if Debug is disabled
_logger.LogDebug("Payload hash: {Hash}", ComputeHash(largePayload));

// ✅ Correct — guard with IsEnabled
if (_logger.IsEnabled(LogLevel.Debug))
{
    _logger.LogDebug("Payload hash: {Hash}", ComputeHash(largePayload));
}

// ✅ Best for hot paths — use LoggerMessage source generator (Rule 3)
// The generated code already includes the IsEnabled check
```

## Rule 5 — Never log sensitive data

```csharp
// ❌ Wrong — token in logs
_logger.LogInformation("User authenticated with token {Token}", jwt);

// ❌ Wrong — full request body may contain sensitive fields
_logger.LogDebug("Request body: {Body}", JsonSerializer.Serialize(request));

// ✅ Correct — log only identifiers
_logger.LogInformation("User {UserId} authenticated via {AuthMethod}",
    userId, "JWT");

// ✅ Correct — redact sensitive fields, log metadata only
_logger.LogDebug("Request for {Endpoint} with {PayloadSize} bytes",
    request.Path, request.ContentLength);
```

**Serilog destructure policy** for automatic redaction:
```csharp
.Destructure.ByTransforming<LoginRequest>(r => new
{
    r.Username,
    Password = "***REDACTED***"
})
```

## Rule 6 — Per-namespace log levels

```json
// appsettings.json (.NET 6+)
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Warning",
      "System.Net.Http.HttpClient": "Warning",
      "MyApp.Services": "Debug",
      "MyApp.DataAccess": "Information"
    }
  }
}
```

```xml
<!-- NLog.config (.NET Framework) -->
<rules>
  <logger name="*" minlevel="Info" writeTo="file" />
  <logger name="System.Net.Http.*" maxlevel="Info" final="true" />
  <logger name="MyApp.DataAccess.*" minlevel="Debug" writeTo="file" />
</rules>
```

## Rule 7 — Correlation IDs

```csharp
// ASP.NET Core — middleware approach
app.Use(async (context, next) =>
{
    var correlationId = context.Request.Headers["X-Correlation-Id"].FirstOrDefault()
        ?? Activity.Current?.Id
        ?? Guid.NewGuid().ToString();

    using (_logger.BeginScope(new Dictionary<string, object>
    {
        ["CorrelationId"] = correlationId
    }))
    {
        context.Response.Headers["X-Correlation-Id"] = correlationId;
        await next();
    }
});

// Serilog — automatic enrichment
.Enrich.WithCorrelationId()       // Serilog.Enrichers.CorrelationId package
.Enrich.WithProperty("ServiceName", "OrderApi")
```

## Rule 10 — Log at boundaries

```csharp
// ✅ Good — log at boundaries
public async Task<Order> ProcessOrderAsync(int orderId, CancellationToken ct)
{
    _logger.LogInformation("Processing order {OrderId}", orderId);

    var order = await _repository.GetByIdAsync(orderId, ct);
    if (order is null)
    {
        _logger.LogWarning("Order {OrderId} not found", orderId);
        throw new OrderNotFoundException(orderId);
    }

    // ... business logic (no logging for each step)

    _logger.LogInformation("Order {OrderId} processed, status={Status}",
        orderId, order.Status);
    return order;
}

// ❌ Bad — logging every line creates noise
public async Task<Order> ProcessOrderAsync(int orderId, CancellationToken ct)
{
    _logger.LogDebug("Entering ProcessOrderAsync");           // noise
    _logger.LogDebug("Calling repository");                    // noise
    var order = await _repository.GetByIdAsync(orderId, ct);
    _logger.LogDebug("Repository returned");                   // noise
    _logger.LogDebug("Checking if order is null");            // noise
    // ...
}
```

## Rule 11 — Include context in error logs

```csharp
// ❌ Wrong — no context
_logger.LogError("Error processing order");

// ❌ Wrong — exception swallowed
try { /* ... */ }
catch (Exception ex)
{
    _logger.LogError("Failed"); // where? what? which order?
}

// ✅ Correct — exception + context
try
{
    await ProcessPaymentAsync(order, ct);
}
catch (PaymentGatewayException ex)
{
    _logger.LogError(ex,
        "Payment failed for order {OrderId}, amount {Amount}, gateway {Gateway}",
        order.Id, order.Amount, _gateway.Name);
    throw;  // or handle appropriately
}
```

## Rule 12 — Centralized logging solutions

| Solution | Best For | Setup |
|----------|---------|-------|
| **Seq** | .NET-native, development + small teams | `Serilog.Sinks.Seq` |
| **Elastic Stack** | Elasticsearch 8+, self-hosted or cloud | `Elastic.Serilog.Sinks` or NLog Elasticsearch target |
| **Azure App Insights** | Azure-hosted applications | `Serilog.Sinks.ApplicationInsights` or `Microsoft.Extensions.Logging.ApplicationInsights` |
| **Grafana Loki** | Kubernetes, cost-efficient | `Serilog.Sinks.Grafana.Loki` |

```csharp
// Serilog with multiple sinks
.WriteTo.Console()
.WriteTo.File("logs/app-.log", rollingInterval: RollingInterval.Day)
.WriteTo.Seq("http://localhost:5341")
```

## Platform-Specific Quick Reference

### .NET 6+ (Microsoft.Extensions.Logging)

```csharp
// Registration (automatic with WebApplication.CreateBuilder)
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Inject and use (primary constructor in .NET 8+)
public class OrderService(ILogger<OrderService> logger)
{
    public void Process() => logger.LogInformation("Processing...");
}
```

### .NET Framework (NLog)

```csharp
// Get logger
private static readonly NLog.Logger Logger = NLog.LogManager.GetCurrentClassLogger();

// Use — NLog supports message templates
Logger.Info("Processing order {OrderId}", orderId);
Logger.Error(ex, "Failed to process order {OrderId}", orderId);
```

### .NET Framework (log4net)

```csharp
// Get logger
private static readonly ILog Log = LogManager.GetLogger(typeof(OrderService));

// Use — log4net does not support message templates natively
Log.Info($"Processing order {orderId}");
Log.Error($"Failed to process order {orderId}", ex);
```

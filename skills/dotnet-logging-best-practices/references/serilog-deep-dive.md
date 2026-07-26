<!-- last-verified: 2026-07-26 -->
# Serilog Deep Dive

## Architecture Overview

Serilog is a structured logging library for .NET built around four core concepts:

1. **Logger** -- The `ILogger` interface that receives log events. Created via `LoggerConfiguration`.
2. **Sink** -- A destination for log events (Console, File, Seq, Elasticsearch, etc.).
3. **Enricher** -- Attaches additional properties to every log event passing through the pipeline.
4. **Destructuring** -- Controls how complex .NET objects are converted into structured log data.

The pipeline flow:

```
Code -> Logger -> MinimumLevel filter -> Enrichers -> Sink(s)
```

Each log event is a `LogEvent` containing a `MessageTemplate`, properties, timestamp, level, and optional exception.

---

## Sink Configuration

### Console Sink

```csharp
// Package: Serilog.Sinks.Console
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(
        outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}",
        theme: Serilog.Sinks.SystemConsole.Themes.AnsiConsoleTheme.Code,
        restrictedToMinimumLevel: LogEventLevel.Debug)
    .CreateLogger();
```

Common output template tokens: `{Timestamp}`, `{Level}`, `{Message}`, `{Exception}`, `{NewLine}`, `{Properties}`.

Level format specifiers: `{Level:u3}` = uppercase 3-char (`INF`), `{Level:w3}` = lowercase 3-char (`inf`).

Themes: `AnsiConsoleTheme.Code`, `AnsiConsoleTheme.Literate`, `AnsiConsoleTheme.Sixteen`, `SystemConsoleTheme.Grayscale`.

### File Sink

```csharp
// Package: Serilog.Sinks.File
Log.Logger = new LoggerConfiguration()
    .WriteTo.File(
        path: "logs/app-.log",
        rollingInterval: RollingInterval.Day,      // Appends date to filename
        rollOnFileSizeLimit: true,
        fileSizeLimitBytes: 50_000_000,            // 50 MB per file
        retainedFileCountLimit: 31,                // Keep 31 files
        shared: true,                               // Allow multiple processes
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}",
        buffered: false)                            // true = buffered writes (faster, risk of loss)
    .CreateLogger();
```

Key options:
- `rollingInterval`: `Infinite`, `Year`, `Month`, `Day`, `Hour`, `Minute`.
- `shared: true`: Uses mutex-based file locking; slight performance cost but safe for multi-process.
- `retainedFileTimeLimit`: Alternative to count-based retention using `TimeSpan`.
- `hooks`: `FileLifecycleHooks` for gzip compression on roll.

### Seq Sink

```csharp
// Package: Serilog.Sinks.Seq
Log.Logger = new LoggerConfiguration()
    .WriteTo.Seq(
        serverUrl: "http://localhost:5341",
        apiKey: "your-api-key",                    // Optional
        batchPostingLimit: 1000,                   // Events per batch
        period: TimeSpan.FromSeconds(2),           // Batch interval
        queueSizeLimit: 100_000,                   // In-memory buffer
        compact: true)                              // Compact JSON format (smaller payloads)
    .CreateLogger();
```

Seq sink uses durable batching: events are written to a local buffer file, then shipped to the server. This survives transient network failures.

### Elasticsearch Sink

```csharp
// Package: Elastic.Serilog.Sinks (Elasticsearch 8+)
Log.Logger = new LoggerConfiguration()
    .WriteTo.Elasticsearch(
        [new Uri("https://elastic.example.com")],
        options =>
        {
            options.DataStream = new DataStreamName("logs", "myapp", "production");
            options.BootstrapMethod = BootstrapMethod.Failure;
        })
    .CreateLogger();
```

The former community sink is archived. For durable delivery, emit ECS JSON to
a file or stdout and ship it with Elastic Agent/Filebeat; the official direct
sink does not provide durable mode.

Reference: https://www.elastic.co/docs/reference/ecs/logging/dotnet/serilog-data-shipper

### Application Insights Sink

```csharp
// Package: Serilog.Sinks.ApplicationInsights
builder.Services.AddSerilog((services, config) => config
    .WriteTo.ApplicationInsights(
        services.GetRequiredService<TelemetryConfiguration>(),
        TelemetryConverter.Traces));
```

---

## Enricher Patterns

### Built-in Enrichers

```csharp
// Packages: Serilog.Enrichers.Environment, Serilog.Enrichers.Thread, Serilog.Enrichers.Process
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()                     // Captures ambient LogContext properties
    .Enrich.WithMachineName()                    // {MachineName}
    .Enrich.WithEnvironmentName()                // {EnvironmentName}
    .Enrich.WithThreadId()                       // {ThreadId}
    .Enrich.WithThreadName()                     // {ThreadName}
    .Enrich.WithProcessId()                      // {ProcessId}
    .Enrich.WithProcessName()                    // {ProcessName}
    .Enrich.WithProperty("Application", "MyApp") // Static property on all events
    .CreateLogger();
```

### Using LogContext (Scoped Properties)

```csharp
// Push a property onto the ambient context for the duration of the scope
using (LogContext.PushProperty("OrderId", orderId))
using (LogContext.PushProperty("CustomerId", customerId))
{
    _logger.Information("Processing order");
    // OrderId and CustomerId are attached to all log events within this scope
    await ProcessOrderAsync(orderId);
}
```

### Custom Enricher Implementation

```csharp
public class CorrelationIdEnricher : ILogEventEnricher
{
    private const string PropertyName = "CorrelationId";

    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        var httpContext = new HttpContextAccessor().HttpContext;
        if (httpContext == null) return;

        var correlationId = httpContext.Request.Headers["X-Correlation-ID"].FirstOrDefault()
            ?? httpContext.TraceIdentifier;

        var property = propertyFactory.CreateProperty(PropertyName, correlationId);
        logEvent.AddPropertyIfAbsent(property);
    }
}

// Registration
Log.Logger = new LoggerConfiguration()
    .Enrich.With<CorrelationIdEnricher>()
    .CreateLogger();
```

### ASP.NET Core Request Logging Enrichment

```csharp
// Package: Serilog.AspNetCore
app.UseSerilogRequestLogging(options =>
{
    options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
    {
        diagnosticContext.Set("RequestHost", httpContext.Request.Host.Value);
        diagnosticContext.Set("UserAgent", httpContext.Request.Headers["User-Agent"].ToString());
        diagnosticContext.Set("UserId", httpContext.User?.FindFirst("sub")?.Value);
    };
});
```

---

## Destructuring

### @ Operator (Structured Object Capture)

```csharp
var order = new { OrderId = 123, Total = 99.50m, Items = new[] { "Widget", "Gadget" } };
_logger.Information("Order placed: {@Order}", order);
// Captures as structured data: { OrderId: 123, Total: 99.50, Items: ["Widget", "Gadget"] }
```

### $ Operator (ToString Stringification)

```csharp
_logger.Information("Order placed: {$Order}", order);
// Captures as string: "{ OrderId = 123, Total = 99.50, Items = System.String[] }"
```

### Destructure.ByTransforming (Redaction / Projection)

```csharp
Log.Logger = new LoggerConfiguration()
    .Destructure.ByTransforming<UserProfile>(u => new
    {
        u.UserId,
        u.DisplayName,
        Email = MaskEmail(u.Email),       // Redact sensitive data
        // Password is omitted entirely
    })
    .CreateLogger();
```

### Custom Destructuring Policy

```csharp
public class SensitiveDataPolicy : IDestructuringPolicy
{
    public bool TryDestructure(
        object value,
        ILogEventPropertyValueFactory propertyValueFactory,
        out LogEventPropertyValue result)
    {
        if (value is CreditCard card)
        {
            result = new StructureValue(new[]
            {
                new LogEventProperty("Last4", new ScalarValue(card.Number[^4..])),
                new LogEventProperty("Expiry", new ScalarValue(card.Expiry)),
                // Full number is never logged
            });
            return true;
        }
        result = null;
        return false;
    }
}

// Registration
.Destructure.With<SensitiveDataPolicy>()
```

### Other Destructure Options

```csharp
.Destructure.ToMaximumDepth(4)                   // Limit nesting depth
.Destructure.ToMaximumStringLength(1024)          // Truncate long strings
.Destructure.ToMaximumCollectionCount(10)         // Limit array/collection length
```

---

## Two-Stage Initialization

Bootstrap logging captures startup errors before the full configuration (e.g., appsettings.json, DI) is available.

```csharp
// Program.cs (.NET 6+)
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();          // <-- Bootstrap logger

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Services.AddSerilog((services, config) => config
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .WriteTo.Console()
        .WriteTo.Seq("http://localhost:5341"));

    var app = builder.Build();
    // ... configure middleware
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();               // Always flush on shutdown
}
```

Reference: https://github.com/serilog/serilog-aspnetcore

---

## Audit Logging (AuditTo vs WriteTo)

`WriteTo` -- best-effort delivery. If a sink fails, the event is lost silently.

`AuditTo` -- guaranteed delivery. If a sink throws, the exception propagates to the caller.

```csharp
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()                              // Best-effort
    .AuditTo.File("logs/audit-.log",                // Guaranteed delivery
        rollingInterval: RollingInterval.Day)
    .AuditTo.Sink(new DatabaseAuditSink())          // Custom audit sink
    .CreateLogger();
```

Use `AuditTo` for compliance-critical events (financial transactions, access control changes, data deletions). Be aware that `AuditTo` sinks block the calling thread and propagate exceptions -- they are not suitable for high-throughput general logging.

---

## Sub-loggers and ForContext

### ForContext (Scoped Logger)

```csharp
public class OrderService
{
    private readonly ILogger _logger;

    public OrderService(ILogger<OrderService> logger)
    {
        _logger = logger;  // Automatically tagged with SourceContext = "OrderService"
    }

    public void Process(int orderId)
    {
        var log = _logger.ForContext("OrderId", orderId);
        log.Information("Starting order processing");
        log.Warning("Inventory low for order");
    }
}
```

### Conditional Sub-loggers

```csharp
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.Logger(subLogger => subLogger
        .Filter.ByIncludingOnly(e => e.Properties.ContainsKey("AuditEvent"))
        .WriteTo.File("logs/audit.log"))
    .WriteTo.Logger(subLogger => subLogger
        .Filter.ByIncludingOnly(Matching.FromSource("Microsoft.EntityFrameworkCore"))
        .MinimumLevel.Is(LogEventLevel.Warning)
        .WriteTo.File("logs/ef-warnings.log"))
    .CreateLogger();
```

---

## Performance Considerations

### MessageTemplate Caching

Serilog caches parsed message templates. Always use structured templates, never string interpolation:

```csharp
// GOOD -- template is cached, structured properties are captured
_logger.Information("Order {OrderId} processed in {Elapsed}ms", orderId, elapsed);

// BAD -- new string every call, no structured data, defeats caching
_logger.Information($"Order {orderId} processed in {elapsed}ms");
```

### Check IsEnabled Before Expensive Serialization

```csharp
if (_logger.IsEnabled(LogEventLevel.Debug))
{
    _logger.Debug("Full payload: {@Payload}", expensiveObject.Serialize());
}
```

### Async Wrapper for Slow Sinks

```csharp
// Package: Serilog.Sinks.Async
Log.Logger = new LoggerConfiguration()
    .WriteTo.Async(a => a.File("logs/app.log"),
        bufferSize: 10_000,                  // In-memory ring buffer
        blockWhenFull: false)                // Drop events when full (vs block caller)
    .CreateLogger();
```

### Batching Sink Performance

Most network sinks (Seq, Elasticsearch, Application Insights) use `PeriodicBatchingSink` internally. Tune `batchPostingLimit` and `period` based on throughput needs:
- High throughput: larger batches, longer intervals.
- Low latency: smaller batches, shorter intervals.

---

## Serilog.Expressions and Serilog.Filters

### Serilog.Expressions (Recommended over Serilog.Filters.Expressions)

```csharp
// Package: Serilog.Expressions
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly("RequestPath like '/api/orders%'")
        .WriteTo.File("logs/orders.log"))
    .WriteTo.Logger(lc => lc
        .Filter.ByExcluding("SourceContext = 'Microsoft.AspNetCore.Hosting.Diagnostics'")
        .WriteTo.Seq("http://localhost:5341"))
    .CreateLogger();
```

### Expression-Based Output Templates

```csharp
// Use expressions in output templates for conditional formatting
.WriteTo.Console(new ExpressionTemplate(
    "[{@t:HH:mm:ss} {@l:u3}]{#if CorrelationId is not null} [{CorrelationId}]{#end} {@m}\n{@x}"))
```

### appsettings.json Configuration with Filters

```json
{
  "Serilog": {
    "Using": ["Serilog.Sinks.Console", "Serilog.Sinks.File", "Serilog.Expressions"],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.Hosting.Lifetime": "Information",
        "System": "Warning"
      }
    },
    "WriteTo": [
      { "Name": "Console" },
      {
        "Name": "File",
        "Args": {
          "path": "logs/app-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 14
        }
      }
    ],
    "Filter": [
      {
        "Name": "ByExcluding",
        "Args": {
          "expression": "RequestPath like '/health%'"
        }
      }
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"]
  }
}
```

### Common Filter Expressions

```
@l = 'Error'                                    -- Level equals Error
@l in ['Error', 'Fatal']                        -- Level is Error or Fatal
SourceContext like 'MyApp.%'                     -- Source starts with MyApp.
RequestPath like '/api/%'                        -- Request path pattern
Elapsed > 500                                   -- Slow request filter
@m like '%timeout%'                             -- Message contains timeout
IsDefined(OrderId)                              -- Property exists
coalesce(UserId, 'anonymous') = 'anonymous'     -- Missing or null check
```

---

## .NET Framework vs .NET 6+ Differences

### .NET Framework Setup

```csharp
// Global.asax.cs or Startup
Log.Logger = new LoggerConfiguration()
    .ReadFrom.AppSettings()    // Reads from web.config / app.config
    .CreateLogger();
```

### .NET 6+ Setup

```csharp
// Program.cs
builder.Services.AddSerilog((services, config) => config
    .ReadFrom.Configuration(builder.Configuration)   // Reads from appsettings.json
    .ReadFrom.Services(services));                    // Resolves sinks/enrichers from DI
```

Key difference: `.ReadFrom.AppSettings()` in .NET Framework reads from XML config; `.ReadFrom.Configuration()` in .NET 6+ reads from `IConfiguration` (JSON, env vars, etc.).

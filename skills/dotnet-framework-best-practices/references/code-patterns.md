# .NET Framework 4.x Code Patterns per Golden Rule

Complete code examples for each Golden Rule in main `SKILL.md`, plus 7-step writing pattern, console app patterns, and logging anti-patterns. For deeper treatment see the other reference files.

## Rule 1 — Composition Root with DI

```csharp
// ❌ Wrong — hidden dependency, untestable
public class OrderController : ApiController
{
    public IHttpActionResult Get(int id)
    {
        var svc = new OrderService(); // tight coupling
        return Ok(svc.GetOrder(id));
    }
}

// ✅ Correct — constructor injection
public class OrderController : ApiController
{
    private readonly IOrderService _orderService;

    public OrderController(IOrderService orderService)
    {
        _orderService = orderService;
    }

    public IHttpActionResult Get(int id) => Ok(_orderService.GetOrder(id));
}
```

## Rule 3 — Async all the way

```csharp
// ❌ Wrong — deadlock under ASP.NET
public ActionResult Index()
{
    var data = _service.GetDataAsync().Result; // deadlock
    return View(data);
}

// ✅ Correct — async all the way
public async Task<ActionResult> Index()
{
    var data = await _service.GetDataAsync();
    return View(data);
}
```

## Rule 4 — ConfigureAwait(false) in library code

```csharp
// In a service/library class
public async Task<Order> GetOrderAsync(int id, CancellationToken ct)
{
    var data = await _repository.FindAsync(id, ct).ConfigureAwait(false);
    return MapToOrder(data);
}
```

## Rule 5 — Input validation

```csharp
public IHttpActionResult Post(CreateOrderDto dto)
{
    if (!ModelState.IsValid)
        return BadRequest(ModelState);

    var result = _orderService.Create(dto);
    return Created($"api/orders/{result.Id}", result);
}
```

## Rule 6 — Global error handlers

```csharp
// Web API 2 — register in WebApiConfig
config.Services.Replace(typeof(IExceptionHandler), new GlobalExceptionHandler());
config.Services.Add(typeof(IExceptionLogger), new GlobalExceptionLogger());
```

## Rule 8 — Encrypted config sections

```xml
<!-- ❌ Wrong — plain text password -->
<connectionStrings>
  <add name="OrderDb" connectionString="Server=prod;Database=Orders;User=sa;Password=P@ss123!" />
</connectionStrings>

<!-- ✅ Better — use integrated security or encrypted section -->
<connectionStrings configProtectionProvider="RsaProtectedConfigurationProvider">
  <EncryptedData>...</EncryptedData>
</connectionStrings>
```

## Rule 9 — CSRF protection

```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public ActionResult Create(OrderViewModel model)
{
    // CSRF-protected action
}
```

## Rule 10 — HttpClient lifecycle

```csharp
// ❌ Wrong — socket exhaustion under load
public async Task<string> CallApi()
{
    using (var client = new HttpClient())
    {
        return await client.GetStringAsync("https://api.example.com/data");
    }
}

// ✅ Correct — shared static instance
private static readonly HttpClient _httpClient = new HttpClient();

public async Task<string> CallApi()
{
    return await _httpClient.GetStringAsync("https://api.example.com/data");
}
```

## Writing New .NET Framework Code — 7-Step Pattern

1. **Set up the Composition Root.** Choose a DI container (Autofac, Unity, Ninject). Register services with appropriate lifetimes (per-request for controllers and DbContext, singleton for HttpClient wrappers, transient for stateless utilities). Wire the container to MVC's `DependencyResolver` and/or Web API's `IDependencyResolver`.

2. **Define clear layer boundaries.** Controllers → Services → Repositories → Data Access. Each layer depends only on abstractions from the layer below. No circular references.

3. **Configure validation at the boundary.** Data Annotations on DTOs/ViewModels. Check `ModelState.IsValid` in every action accepting input.

4. **Use async throughout.** `async Task<ActionResult>` controllers, `ConfigureAwait(false)` in service/repo layers.

5. **Set up global error handling.** Register `IExceptionHandler` and `IExceptionLogger` (Web API 2) or `HandleErrorAttribute` (MVC). Log to structured logging (Serilog, NLog).

6. **Secure the application.** Enable CSRF protection, validate input, encrypt config sections, use HTTPS, configure CORS properly for Web API.

7. **Configure caching and bundling.** `[OutputCache]` for read-heavy actions. `BundleConfig.cs` for CSS/JS optimization.

## Console Application Patterns

### Structured Entry Point with DI

```csharp
class Program
{
    static async Task<int> Main(string[] args)
    {
        var container = new UnityContainer();
        container.RegisterType<IOrderProcessor, OrderProcessor>();
        container.RegisterType<ILogger, NLogLogger>();

        var processor = container.Resolve<IOrderProcessor>();
        try
        {
            await processor.RunAsync(args, CancellationToken.None);
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Fatal: {ex.Message}");
            return 1;
        }
        finally
        {
            container.Dispose();
        }
    }
}
```

### Graceful Shutdown

```csharp
static async Task<int> Main(string[] args)
{
    using var cts = new CancellationTokenSource();
    Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };
    AppDomain.CurrentDomain.ProcessExit += (_, _) => cts.Cancel();

    await RunWorkloadAsync(cts.Token);
    return 0;
}
```

### App.config for Console Apps

Use `App.config` (compiles to `MyApp.exe.config`) with `ConfigurationManager`. For environment-specific transforms, install the **SlowCheetah** NuGet package.

## Logging Patterns (.NET Framework)

For comprehensive logging guidance, see the **dotnet-logging-best-practices** skill. Key patterns specific to .NET Framework:

### NLog Quick Setup

```xml
<!-- NLog.config — set Copy Always -->
<nlog>
  <targets>
    <target name="file" xsi:type="File"
            fileName="${basedir}/logs/${shortdate}.log"
            layout="${longdate}|${level:uppercase=true}|${logger}|${message}${onexception:${newline}${exception:format=tostring}}" />
  </targets>
  <rules>
    <logger name="*" minlevel="Info" writeTo="file" />
    <logger name="System.Net.Http.*" maxlevel="Info" final="true" />
  </rules>
</nlog>
```

### Structured Logging with Serilog

```csharp
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("System.Net.Http", LogEventLevel.Warning)
    .WriteTo.Console()
    .WriteTo.File("logs/app-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

// Message template, NOT string interpolation
Log.Information("Processing order {OrderId} for {CustomerId}", order.Id, order.CustomerId);
```

### Anti-patterns

```csharp
// ❌ Wrong — string concatenation allocates even when level is disabled
logger.Debug("Processing order " + orderId + " at " + DateTime.Now);

// ❌ Wrong — string interpolation bypasses structured logging
logger.Information($"Order {orderId} completed");

// ✅ Correct — message template with named placeholders
logger.Information("Order {OrderId} completed", orderId);
```

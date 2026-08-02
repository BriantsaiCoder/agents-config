# .NET Framework 4.x — Configuration and Hosting Patterns

## Web.config / App.config Structure

The XML configuration file is the central configuration mechanism for .NET Framework applications.
Web applications use `Web.config`; console apps and services use `App.config`.

### Core Sections

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="Environment" value="Production" />
    <add key="MaxRetries" value="3" />
    <add key="FeatureFlag:NewCheckout" value="false" />
  </appSettings>

  <connectionStrings>
    <add name="DefaultConnection"
         connectionString="Server=.;Database=MyApp;Integrated Security=true"
         providerName="System.Data.SqlClient" />
  </connectionStrings>

  <system.web>
    <compilation debug="false" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" maxRequestLength="10240" />
    <customErrors mode="RemoteOnly" defaultRedirect="~/Error" />
    <authentication mode="Forms">
      <forms loginUrl="~/Account/Login" timeout="30" />
    </authentication>
  </system.web>

  <system.webServer>
    <modules runAllManagedModulesForAllRequests="false" />
    <handlers>
      <remove name="ExtensionlessUrlHandler-Integrated-4.0" />
      <add name="ExtensionlessUrlHandler-Integrated-4.0"
           path="*." verb="*"
           type="System.Web.Handlers.TransferRequestHandler"
           preCondition="integratedMode,runtimeVersionv4.0" />
    </handlers>
  </system.webServer>
</configuration>
```

`4.8` is the safe value here, not the newest one: 4.8.1 is the last release of the 4.x line (in-box on Windows 11 22H2+ and Windows Server 2022; targeting it needs VS 2022 17.3+ plus the 4.8.1 Developer Pack). Bump `compilation`/`httpRuntime targetFramework` to `4.8.1` only when every target server has 4.8.1 installed — a `targetFramework` later than the installed framework is a startup configuration error. The quirks contract keyed on `httpRuntime targetFramework` is satisfied at 4.8 or higher either way.

### Reading Configuration Values

```csharp
using System.Configuration;

// appSettings — always returns string; null if key missing
string env = ConfigurationManager.AppSettings["Environment"];
int maxRetries = int.Parse(ConfigurationManager.AppSettings["MaxRetries"] ?? "1");

// connectionStrings — returns ConnectionStringSettings object
var connStr = ConfigurationManager.ConnectionStrings["DefaultConnection"];
string connectionString = connStr.ConnectionString;
string provider = connStr.ProviderName;
```

**Never hardcode connection strings or secrets in source code.** Always read from config.

### Custom Configuration Sections

```csharp
// Define the section
public class CacheSettings : ConfigurationSection
{
    [ConfigurationProperty("enabled", DefaultValue = true)]
    public bool Enabled => (bool)this["enabled"];

    [ConfigurationProperty("durationSeconds", DefaultValue = 300)]
    public int DurationSeconds => (int)this["durationSeconds"];
}
```

```xml
<!-- Register and use in Web.config -->
<configSections>
  <section name="cacheSettings"
           type="MyApp.CacheSettings, MyApp" />
</configSections>

<cacheSettings enabled="true" durationSeconds="600" />
```

```csharp
var cache = (CacheSettings)ConfigurationManager.GetSection("cacheSettings");
int duration = cache.DurationSeconds;
```

### Config Transforms

Config transforms apply XDT (XML Document Transform) syntax to produce environment-specific configs
at build time. Visual Studio creates `Web.Debug.config` and `Web.Release.config` by default.

```xml
<!-- Web.Release.config -->
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
  <appSettings>
    <add key="Environment" value="Production"
         xdt:Transform="SetAttributes" xdt:Locator="Match(key)" />
  </appSettings>
  <connectionStrings>
    <add name="DefaultConnection"
         connectionString="Server=prod-sql;Database=MyApp;Integrated Security=true"
         xdt:Transform="SetAttributes" xdt:Locator="Match(name)" />
  </connectionStrings>
  <system.web>
    <compilation xdt:Transform="RemoveAttributes(debug)" />
  </system.web>
</configuration>
```

For `App.config` transforms (console apps, services), install the **SlowCheetah** NuGet package.
SlowCheetah adds the same XDT transform support that `Web.config` has natively.

---

## Global.asax Lifecycle

`Global.asax` (the `HttpApplication` subclass) defines event handlers for the ASP.NET application
lifecycle. The most commonly used events:

```csharp
public class MvcApplication : System.Web.HttpApplication
{
    protected void Application_Start()
    {
        // Runs once when the application pool starts.
        // Register routes, filters, bundles, areas, and DI containers here.
        AreaRegistration.RegisterAllAreas();
        FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        RouteConfig.RegisterRoutes(RouteTable.Routes);
        BundleConfig.RegisterBundles(BundleTable.Bundles);

        // DI container setup (e.g., Unity, Autofac, Ninject)
        var container = new UnityContainer();
        container.RegisterType<IOrderService, OrderService>();
        DependencyResolver.SetResolver(new UnityDependencyResolver(container));
    }

    protected void Application_End()
    {
        // Runs when the app pool shuts down. Dispose singletons, flush logs.
    }

    protected void Application_Error()
    {
        // Global unhandled exception handler.
        var exception = Server.GetLastError();
        // Log the exception — do not swallow silently.
        Logger.Error("Unhandled exception", exception);
        Server.ClearError();
        Response.Redirect("~/Error");
    }

    protected void Session_Start()
    {
        // Fires when a new session is created. Avoid heavy work here.
    }

    protected void Session_End()
    {
        // Fires when a session expires (InProc mode only).
    }

    protected void Application_BeginRequest()
    {
        // Fires at the start of every HTTP request.
        // Use for cross-cutting concerns: logging, security headers.
    }

    protected void Application_EndRequest()
    {
        // Fires at the end of every HTTP request.
        // Use for response-level cleanup or header injection.
    }
}
```

### ASP.NET Request Pipeline Order

1. `BeginRequest`
2. `AuthenticateRequest`
3. `AuthorizeRequest`
4. `ResolveRequestCache`
5. `MapRequestHandler` (handler selected)
6. `AcquireRequestState` (session loaded)
7. `PreRequestHandlerExecute`
8. **Handler executes** (MVC controller action, Web API action, etc.)
9. `PostRequestHandlerExecute`
10. `ReleaseRequestState`
11. `UpdateRequestCache`
12. `EndRequest`

`Application_Error` fires whenever an unhandled exception occurs at any stage.

---

## OWIN / Katana

### What Is OWIN

OWIN (Open Web Interface for .NET) defines a standard interface between .NET web servers and
applications. Katana is Microsoft's implementation. OWIN decouples your application from
`System.Web` and IIS, making it portable and easier to migrate to .NET Core later.

The core abstraction is a function: `Func<IDictionary<string, object>, Task>`. Middleware
components compose into a pipeline, each calling the next.

### Startup Class

```csharp
// Mark the assembly so Katana finds the startup class
[assembly: OwinStartup(typeof(MyApp.Startup))]

namespace MyApp
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            // Middleware executes in registration order
            app.UseCors(CorsOptions.AllowAll);

            // Token-based authentication
            app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());

            // Web API
            var config = new HttpConfiguration();
            config.MapHttpAttributeRoutes();
            config.Routes.MapHttpRoute("DefaultApi", "api/{controller}/{id}",
                new { id = RouteParameter.Optional });

            app.UseWebApi(config);
        }
    }
}
```

### OWIN Middleware vs HttpModules

| Aspect | OWIN Middleware | HttpModule |
|--------|---------------|------------|
| Dependency | `Microsoft.Owin` | `System.Web` |
| Registration | Code in `Startup.Configuration` | XML in `Web.config` |
| Portability | Runs self-hosted or in IIS | IIS only |
| Composability | Simple function pipeline | Event-based, harder to order |
| Migration path | Maps directly to ASP.NET Core middleware | Requires rewrite |

### Self-Hosting (No IIS)

```csharp
// Install: Microsoft.Owin.Hosting, Microsoft.Owin.Host.HttpListener
using Microsoft.Owin.Hosting;

class Program
{
    static void Main()
    {
        string baseAddress = "http://localhost:9000/";
        using (WebApp.Start<Startup>(baseAddress))
        {
            Console.WriteLine($"Listening on {baseAddress}");
            Console.ReadLine();
        }
    }
}
```

Self-hosting is useful for Windows Services, integration tests, and scenarios where IIS is
unavailable or undesirable.

### Bridging OWIN into IIS

Install `Microsoft.Owin.Host.SystemWeb` to run OWIN middleware inside IIS. This package hooks
into the ASP.NET pipeline so the `Startup` class is invoked automatically. No code changes
needed beyond adding the NuGet package and the `[assembly: OwinStartup]` attribute.

---

## IIS Deployment

### Application Pool Configuration

| Setting | Recommendation | Reason |
|---------|---------------|--------|
| Pipeline mode | **Integrated** | Classic mode is legacy; Integrated enables `system.webServer` handlers |
| .NET CLR version | **v4.0** | Covers .NET 4.0 through 4.8.x (they share the same CLR) |
| Identity | **ApplicationPoolIdentity** or dedicated service account | Least privilege |
| 32-bit apps | **False** unless required by a dependency | 64-bit allows more memory |

### Recycling Settings

- **Regular time interval:** Default is 1740 minutes (29 hours). Keep it or extend; avoid very
  short intervals that cause cold-start latency.
- **Overlapped recycling:** Enabled by default. A new worker process starts before the old one
  shuts down, minimizing downtime.
- **Private memory limit:** Set a ceiling if the app has known memory leaks. Prefer fixing the
  leak over relying on recycling.

Application pool recycling terminates all in-flight requests. `Application_End` fires on recycle.
In-memory session state (`InProc`) is lost. Use SQL Server or Redis session state for resilience.

### Web Deploy (MSDeploy)

```
msdeploy.exe -verb:sync
  -source:package="MyApp.zip"
  -dest:auto,computerName="https://server:8172/msdeploy.axd",
        userName="deploy",password="***",authType="basic"
  -enableRule:AppOffline
```

The `-enableRule:AppOffline` flag drops an `app_offline.htm` file during deployment, returning a
friendly maintenance page and stopping the app cleanly.

### IIS URL Rewrite

```xml
<!-- Web.config — force HTTPS -->
<system.webServer>
  <rewrite>
    <rules>
      <rule name="HTTPS Redirect" stopProcessing="true">
        <match url="(.*)" />
        <conditions>
          <add input="{HTTPS}" pattern="^OFF$" />
        </conditions>
        <action type="Redirect" url="https://{HTTP_HOST}/{R:1}"
                redirectType="Permanent" />
      </rule>
    </rules>
  </rewrite>
</system.webServer>
```

---

## Windows Services

### When to Use a Windows Service

- Long-running background processing (queue consumers, schedulers, polling).
- No HTTP listener needed (otherwise prefer IIS or OWIN self-host).
- Must start automatically on boot without user login.

### Topshelf (Recommended)

Topshelf removes the ceremony of `ServiceBase`, `Installer`, and `InstallUtil`. The service is a
normal console app during development and installs as a Windows Service for production.

```csharp
// Install: Topshelf NuGet package
using Topshelf;

class Program
{
    static int Main()
    {
        return (int)HostFactory.Run(cfg =>
        {
            cfg.Service<OrderProcessor>(s =>
            {
                s.ConstructUsing(() => new OrderProcessor());
                s.WhenStarted(svc => svc.Start());
                s.WhenStopped(svc => svc.Stop());
            });

            cfg.RunAsLocalService();
            cfg.SetServiceName("OrderProcessor");
            cfg.SetDisplayName("Order Processor Service");
            cfg.SetDescription("Processes pending orders from the queue.");

            cfg.EnableServiceRecovery(r =>
            {
                r.RestartService(1); // restart after 1 minute on first failure
                r.RestartService(5); // restart after 5 minutes on second failure
                r.SetResetPeriod(1); // reset failure count after 1 day
            });
        });
    }
}

// Install:   MyService.exe install
// Start:     MyService.exe start
// Uninstall: MyService.exe uninstall
```

### ServiceBase (Manual Implementation)

```csharp
public class OrderProcessorService : ServiceBase
{
    private CancellationTokenSource _cts;
    private Task _workerTask;

    protected override void OnStart(string[] args)
    {
        _cts = new CancellationTokenSource();
        _workerTask = Task.Run(() => ProcessLoop(_cts.Token));
    }

    protected override void OnStop()
    {
        _cts.Cancel();
        _workerTask?.Wait(TimeSpan.FromSeconds(30));
        _cts.Dispose();
    }

    private async Task ProcessLoop(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                // Do work
                await ProcessNextBatchAsync(ct);
                await Task.Delay(TimeSpan.FromSeconds(10), ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                EventLog.WriteEntry($"Processing error: {ex}", EventLogEntryType.Error);
            }
        }
    }
}
```

### Logging and Error Handling in Services

- Use structured logging (NLog, log4net, Serilog) — write to files and/or the Windows Event Log.
- Never let exceptions escape `OnStart` or `OnStop` — the SCM will mark the service as failed.
- Use `CancellationToken` for graceful shutdown; avoid `Thread.Abort`.
- Log service start, stop, and configuration values at startup for diagnostics.
- Set up service recovery options (restart on failure) via Topshelf or `sc.exe failurereset`.

---

## Legacy NuGet (`packages.config`)

For non-SDK .NET Framework projects, do not apply the SDK-style CPM workflow.
Use the repository's existing NuGet tooling (`nuget.exe`, Visual Studio Package
Manager, or the solution's wrapper) and keep `packages.config`, project
references, and any checked-in `packages/` convention consistent. Verify the
exact package/version on the configured source, restore the solution, then
build its legacy target. On failure, revert only this task's package edit and
preserve pre-existing dirty changes. Convert to `PackageReference` only as a
separately authorized migration.

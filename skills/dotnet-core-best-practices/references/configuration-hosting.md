# Configuration and Hosting Patterns

Reference for .NET 8/10 configuration providers, environment handling, Kestrel tuning, health checks, background services, and hosting models. Read this when setting up a new project, debugging configuration override order, or adding production-readiness features.

## Table of contents
- [Configuration system](#configuration-system)
- [Environment-based configuration](#environment-based-configuration)
- [Kestrel configuration](#kestrel-configuration)
- [Health checks](#health-checks)
- [Worker services and hosted services](#worker-services-and-hosted-services)
- [Hosting models](#hosting-models)

---

## Configuration system

### Provider priority (last wins)

`WebApplication.CreateBuilder` registers providers in this order. Later providers override earlier ones:

1. `appsettings.json`
2. `appsettings.{Environment}.json`
3. User Secrets (Development only)
4. Environment variables
5. Command-line arguments

This means a command-line argument always beats an environment variable, which beats a JSON file. This ordering is intentional — ephemeral overrides (CLI, env vars) take precedence over static files.

### appsettings.json

```json
{
  "ConnectionStrings": {
    "Default": "Server=localhost;Database=AppDb;Trusted_Connection=true"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "App": {
    "PageSize": 25,
    "EnableFeatureX": false
  }
}
```

### Strongly typed options (preferred over raw IConfiguration)

```csharp
public sealed class AppOptions
{
    public const string SectionName = "App";
    public int PageSize { get; set; } = 25;
    public bool EnableFeatureX { get; set; }
}

// Program.cs
builder.Services.Configure<AppOptions>(
    builder.Configuration.GetSection(AppOptions.SectionName));

// Usage via IOptions<T> (singleton-like, read once at startup)
// Usage via IOptionsSnapshot<T> (scoped, re-reads per request)
// Usage via IOptionsMonitor<T> (singleton, reacts to changes)
```

Prefer `IOptionsMonitor<T>` in long-lived services and `IOptionsSnapshot<T>` in request-scoped code. Use `IOptions<T>` only when you do not need reloading.

### Environment variables

Environment variables map to configuration keys by replacing `__` (double underscore) with `:` as the section separator:

```bash
# Sets ConnectionStrings:Default
export ConnectionStrings__Default="Server=prod;Database=AppDb"

# DOTNET_ prefix for host-level settings
export DOTNET_ENVIRONMENT=Production

# ASPNETCORE_ prefix for web-host settings
export ASPNETCORE_URLS="https://+:443;http://+:80"
```

### Command-line arguments

```bash
dotnet run --App:PageSize=50 --App:EnableFeatureX=true
```

### User Secrets (development only)

User Secrets store sensitive values outside the project tree, avoiding accidental commits:

```bash
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:Default" "Server=dev;Database=AppDb;User=sa;Password=secret"
dotnet user-secrets set "ExternalApi:ApiKey" "dev-key-12345"
```

Secrets are stored in `~/.microsoft/usersecrets/<UserSecretsId>/secrets.json` and are only loaded when `IHostEnvironment.IsDevelopment()` is true.

### Azure Key Vault integration

```csharp
var builder = WebApplication.CreateBuilder(args);

if (!builder.Environment.IsDevelopment())
{
    var keyVaultUri = builder.Configuration["KeyVault:Uri"]
        ?? throw new InvalidOperationException("KeyVault:Uri is required in non-dev environments.");
    builder.Configuration.AddAzureKeyVault(
        new Uri(keyVaultUri),
        new DefaultAzureCredential());
}
```

Key Vault secret names use `--` as the section separator (e.g., `ConnectionStrings--Default` maps to `ConnectionStrings:Default`).

### Custom configuration provider

Implement `IConfigurationSource` and `IConfigurationProvider` for database-backed or remote configuration:

```csharp
public sealed class DbConfigSource : IConfigurationSource
{
    private readonly string _connectionString;
    public DbConfigSource(string connectionString) => _connectionString = connectionString;

    public IConfigurationProvider Build(IConfigurationBuilder builder)
        => new DbConfigProvider(_connectionString);
}

public sealed class DbConfigProvider : ConfigurationProvider
{
    private readonly string _connectionString;
    public DbConfigProvider(string connectionString) => _connectionString = connectionString;

    public override void Load()
    {
        // Query the database and populate Data dictionary.
        using var conn = new SqlConnection(_connectionString);
        conn.Open();
        // ... populate this.Data with key-value pairs.
    }
}

// Registration
builder.Configuration.Add(new DbConfigSource(connectionString));
```

---

## Environment-based configuration

### Setting the environment

The host reads `ASPNETCORE_ENVIRONMENT` (web) or `DOTNET_ENVIRONMENT` (generic host). If neither is set, the default is `Production` — a safe default that avoids accidentally exposing developer diagnostics.

```bash
export ASPNETCORE_ENVIRONMENT=Development   # web apps
export DOTNET_ENVIRONMENT=Staging           # worker services / console apps
```

### Checking the environment in code

```csharp
var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddDatabaseDeveloperPageExceptionFilter();
}

var app = builder.Build();

if (app.Environment.IsProduction())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}
```

`IsDevelopment()`, `IsStaging()`, and `IsProduction()` are convenience methods. For custom environments use `IsEnvironment("QA")`.

### launchSettings.json (local development only)

```json
{
  "profiles": {
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:5001;http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
```

This file is only used by `dotnet run` and IDEs. It is never deployed. Do not put secrets in it.

### Environment-specific service registration

```csharp
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton<IEmailSender, ConsoleEmailSender>();
}
else
{
    builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();
}
```

---

## Kestrel configuration

### Default configuration via appsettings.json

```json
{
  "Kestrel": {
    "Limits": {
      "MaxConcurrentConnections": 100,
      "MaxRequestBodySize": 52428800,
      "KeepAliveTimeout": "00:02:10",
      "RequestHeadersTimeout": "00:00:30"
    },
    "Endpoints": {
      "Https": {
        "Url": "https://*:5001",
        "Certificate": {
          "Path": "/certs/server.pfx",
          "Password": "cert-password"
        }
      },
      "Http": {
        "Url": "http://*:5000"
      }
    }
  }
}
```

### Programmatic configuration

```csharp
builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.Limits.MaxRequestBodySize = 50 * 1024 * 1024; // 50 MB
    kestrel.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
    kestrel.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);

    kestrel.ListenAnyIP(5000); // HTTP
    kestrel.ListenAnyIP(5001, listenOptions =>
    {
        listenOptions.UseHttps("/certs/server.pfx", "cert-password");
    });
});
```

### Reverse proxy configuration (Nginx, Apache, YARP)

When Kestrel sits behind a reverse proxy, the original client IP and scheme are lost. Use `ForwardedHeaders` middleware to restore them:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // Clear defaults and trust the proxy network.
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();
app.UseForwardedHeaders(); // Must be called before UseAuthentication / UseAuthorization.
```

Clearing `KnownNetworks` / `KnownProxies` trusts all proxies — only acceptable when you control the network boundary. In production, add your specific proxy IPs.

---

## Health checks

### Basic setup

```csharp
builder.Services.AddHealthChecks()
    .AddSqlServer(
        builder.Configuration.GetConnectionString("Default")!,
        name: "sqlserver",
        tags: ["ready"])
    .AddRedis(
        builder.Configuration.GetConnectionString("Redis")!,
        name: "redis",
        tags: ["ready"]);

var app = builder.Build();

// Liveness: is the process running?
app.MapHealthChecks("/healthz/live", new HealthCheckOptions
{
    Predicate = _ => false // No dependency checks — just confirms the app responds.
});

// Readiness: can the app serve traffic?
app.MapHealthChecks("/healthz/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

### Custom health check

```csharp
public sealed class ExternalApiHealthCheck : IHealthCheck
{
    private readonly HttpClient _http;

    public ExternalApiHealthCheck(HttpClient http) => _http = http;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken ct = default)
    {
        try
        {
            var response = await _http.GetAsync("/ping", ct);
            return response.IsSuccessStatusCode
                ? HealthCheckResult.Healthy("API reachable.")
                : HealthCheckResult.Degraded($"API returned {response.StatusCode}.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("API unreachable.", ex);
        }
    }
}

// Registration
builder.Services.AddHttpClient<ExternalApiHealthCheck>(c => c.BaseAddress = new Uri("https://api.example.com"));
builder.Services.AddHealthChecks()
    .AddCheck<ExternalApiHealthCheck>("external-api", tags: ["ready"]);
```

### Readiness vs liveness in Kubernetes

```yaml
livenessProbe:
  httpGet:
    path: /healthz/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
```

Liveness checks should be cheap and fast. If a liveness check depends on an external service and that service goes down, Kubernetes will restart your pod unnecessarily.

---

## Worker services and hosted services

### BackgroundService (preferred base class)

```csharp
public sealed class OrderProcessingWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OrderProcessingWorker> _logger;

    public OrderProcessingWorker(IServiceScopeFactory scopeFactory, ILogger<OrderProcessingWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Order processing worker started.");

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(30));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var processor = scope.ServiceProvider.GetRequiredService<IOrderProcessor>();
                await processor.ProcessPendingOrdersAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Error processing orders.");
                // Continue running; do not let a transient error kill the worker.
            }
        }
    }
}

// Registration
builder.Services.AddHostedService<OrderProcessingWorker>();
```

### Scoped service consumption

`BackgroundService` is registered as a singleton. You cannot inject scoped services (e.g., `DbContext`) directly. Always create a scope via `IServiceScopeFactory`:

```csharp
await using var scope = _scopeFactory.CreateAsyncScope();
var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
```

### Queue-based processing pattern

```csharp
public sealed class QueuedWorker : BackgroundService
{
    private readonly Channel<WorkItem> _channel;
    private readonly IServiceScopeFactory _scopeFactory;

    public QueuedWorker(Channel<WorkItem> channel, IServiceScopeFactory scopeFactory)
    {
        _channel = channel;
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var item in _channel.Reader.ReadAllAsync(stoppingToken))
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var handler = scope.ServiceProvider.GetRequiredService<IWorkItemHandler>();
            await handler.HandleAsync(item, stoppingToken);
        }
    }
}

// Registration
builder.Services.AddSingleton(Channel.CreateBounded<WorkItem>(new BoundedChannelOptions(100)
{
    FullMode = BoundedChannelFullMode.Wait
}));
builder.Services.AddHostedService<QueuedWorker>();
```

### Graceful shutdown

The `CancellationToken` passed to `ExecuteAsync` is triggered when the host shuts down. Respect it in all loops and long-running operations. The host waits for `HostOptions.ShutdownTimeout` (default 30 seconds in .NET 8+) before forcefully terminating.

```csharp
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(60);
});
```

---

## Hosting models

### Web application (default)

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.MapControllers();
app.Run();
```

### Generic host (non-web: worker services, console apps)

```csharp
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddHostedService<MyWorker>();
var host = builder.Build();
host.Run();
```

### Slim builder (AOT-friendly, .NET 8+)

`CreateSlimBuilder` omits features that are not AOT-compatible (e.g., Razor, MVC model binding via reflection). Use it for minimal APIs deployed as native AOT binaries:

```csharp
var builder = WebApplication.CreateSlimBuilder(args);
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonContext.Default);
});
var app = builder.Build();
app.MapGet("/", () => "Hello, AOT!");
app.Run();

[JsonSerializable(typeof(string))]
internal partial class AppJsonContext : JsonSerializerContext { }
```

### Docker container hosting

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

Key considerations for containers:
- Bind to `0.0.0.0` (not `localhost`) so the container port is reachable.
- Use non-root user (`USER app` is the default in .NET 8+ images).
- Set `DOTNET_EnableDiagnostics=0` to disable debugging features in production containers.

### systemd integration on Linux

```csharp
builder.Host.UseSystemd(); // Requires Microsoft.Extensions.Hosting.Systemd
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My .NET App
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/dotnet /opt/myapp/MyApp.dll
Restart=on-failure
RestartSec=10
Environment=DOTNET_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
```

`Type=notify` combined with `UseSystemd()` enables the app to signal readiness to systemd, so the service is only marked as "active" once the host is fully started.

---

## NuGet package management

Use the `dotnet` CLI for add/remove/list operations. Only edit `.csproj` / `Directory.Packages.props` by hand to change **versions** of already-referenced packages — never to add or remove references (you will forget to update the lock file, the tool does it for you).

```bash
# Add / remove / update
dotnet add <project> package <Name> [--version X.Y.Z]
dotnet remove <project> package <Name>

# List
dotnet list package                        # direct only
dotnet list package --include-transitive   # transitive too
dotnet list package --outdated             # newer versions available
dotnet list package --vulnerable --include-transitive  # known CVEs (SDK 9.0.300+)
dotnet list package --deprecated

# Explain why a transitive package is present
dotnet nuget why <Name>

# Verify a version exists on NuGet before editing manually
dotnet package search <Name> --exact-match --format json
```

After any version change, run `dotnet restore` (or `dotnet build`) and commit the updated lock file (`packages.lock.json` if `RestorePackagesWithLockFile=true`).

### Central Package Management (CPM)

For solutions with many projects, centralise versions in `Directory.Packages.props` at the repo root so every project pulls the same version.

```xml
<!-- Directory.Packages.props -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Serilog.AspNetCore" Version="8.0.2" />
    <PackageVersion Include="FluentValidation.AspNetCore" Version="11.3.0" />
  </ItemGroup>
</Project>

<!-- Project .csproj references without Version -->
<ItemGroup>
  <PackageReference Include="Serilog.AspNetCore" />
</ItemGroup>
```

### Supply-chain hygiene

Run `--vulnerable` and `--deprecated` in CI and fail the pipeline on findings. For a first-class tool, install `dotnet-outdated-tool` (`dotnet tool install -g dotnet-outdated-tool`) — useful for interactive upgrades but not required in CI. Ensure `nuget.config` declares an `<auditSources>` entry so vulnerability data is fetched from nuget.org.

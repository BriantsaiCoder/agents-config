# .NET Integration Testing Reference

**xUnit version stance:** fixtures below target xUnit v3 (package `xunit.v3` 3.x), where `IAsyncLifetime : IAsyncDisposable` and both `InitializeAsync()` and `DisposeAsync()` return `ValueTask`. On xUnit v2 (package `xunit` 2.x) both members return `Task` — change the signatures back or you get CS0535. v3 also adds `[assembly: AssemblyFixture(typeof(TFixture))]` for a container shared by the whole test assembly, above `ICollectionFixture<T>`.

## WebApplicationFactory<T> Deep Dive

`WebApplicationFactory<TEntryPoint>` from `Microsoft.AspNetCore.Mvc.Testing` creates an in-memory test server for ASP.NET Core applications.

### Basic Usage

```csharp
// Package: Microsoft.AspNetCore.Mvc.Testing
public class OrderApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrderApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetOrder_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/orders/1");
        response.EnsureSuccessStatusCode();

        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        Assert.NotNull(order);
    }
}
```

**Note**: `Program` must be accessible. Add `[assembly: InternalsVisibleTo("YourTestProject")]` to the web project, or use a `public partial class Program { }` in `Program.cs`.

### WithWebHostBuilder and ConfigureTestServices

```csharp
[Fact]
public async Task GetOrder_WhenNotFound_Returns404()
{
    var client = _factory.WithWebHostBuilder(builder =>
    {
        builder.ConfigureTestServices(services =>
        {
            var mockRepo = new Mock<IOrderRepository>();
            mockRepo.Setup(r => r.GetByIdAsync(It.IsAny<int>()))
                .ReturnsAsync((Order?)null);
            services.AddSingleton(mockRepo.Object);
        });
    }).CreateClient();

    var response = await client.GetAsync("/api/orders/999");

    Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
}
```

### ConfigureServices vs ConfigureTestServices

- `ConfigureServices` runs **before** the app's `Startup.ConfigureServices` -- your registrations may be overwritten by the app.
- `ConfigureTestServices` runs **after** the app's service registration -- your registrations win. Always prefer this for overrides.

### Custom Factory (Extending WebApplicationFactory)

```csharp
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureAppConfiguration((context, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = "Server=localhost;Database=TestDb;...",
                ["Features:EnableCaching"] = "false"
            });
        });

        builder.ConfigureTestServices(services =>
        {
            // Remove the real DbContext registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            // Add test database
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("TestDb"));

            // Replace external service with fake
            services.AddSingleton<IEmailService, FakeEmailService>();
        });
    }
}

// Usage
public class OrderApiTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;
    public OrderApiTests(CustomWebApplicationFactory factory)
        => _client = factory.CreateClient();
}
```

### Fake Authentication Handler

```csharp
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "test-user-id"),
            new Claim(ClaimTypes.Name, "Test User"),
            new Claim(ClaimTypes.Role, "Admin")
        };
        var identity = new ClaimsIdentity(claims, "TestScheme");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "TestScheme");

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

// Register in custom factory
builder.ConfigureTestServices(services =>
{
    services.AddAuthentication("TestScheme")
        .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("TestScheme", null);

    services.AddAuthorization(options =>
    {
        options.DefaultPolicy = new AuthorizationPolicyBuilder("TestScheme")
            .RequireAuthenticatedUser()
            .Build();
    });
});
```

### Per-Test Claims (Different Users/Roles)

```csharp
public class TestClaimsProvider
{
    public List<Claim> Claims { get; set; } = new();
}

// Inject into TestAuthHandler, read Claims from the singleton
// Register as singleton in ConfigureTestServices

[Fact]
public async Task AdminEndpoint_WithUserRole_Returns403()
{
    var claimsProvider = _factory.Services.GetRequiredService<TestClaimsProvider>();
    claimsProvider.Claims = new List<Claim>
    {
        new Claim(ClaimTypes.Role, "User") // Not Admin
    };

    var response = await _client.GetAsync("/api/admin/dashboard");
    Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
}
```

### Testing Middleware Pipeline

```csharp
[Fact]
public async Task CorrelationIdMiddleware_AddsHeaderToResponse()
{
    var client = _factory.CreateClient();

    var response = await client.GetAsync("/api/orders");

    Assert.True(response.Headers.Contains("X-Correlation-Id"));
    var correlationId = response.Headers.GetValues("X-Correlation-Id").Single();
    Assert.False(string.IsNullOrWhiteSpace(correlationId));
}

[Fact]
public async Task RateLimitMiddleware_Returns429WhenExceeded()
{
    var client = _factory.CreateClient();

    // Exhaust the rate limit
    for (int i = 0; i < 100; i++)
    {
        await client.GetAsync("/api/orders");
    }

    var response = await client.GetAsync("/api/orders");
    Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
}

[Fact]
public async Task ExceptionMiddleware_ReturnsProblemDetails()
{
    var client = _factory.WithWebHostBuilder(builder =>
    {
        builder.ConfigureTestServices(services =>
        {
            // Force an exception
            var mock = new Mock<IOrderRepository>();
            mock.Setup(r => r.GetByIdAsync(It.IsAny<int>()))
                .ThrowsAsync(new InvalidOperationException("DB unavailable"));
            services.AddSingleton(mock.Object);
        });
    }).CreateClient();

    var response = await client.GetAsync("/api/orders/1");

    Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
    var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
    Assert.NotNull(problem);
    Assert.Equal(500, problem.Status);
}
```

---

## Testcontainers for .NET

Testcontainers spins up real Docker containers for integration tests. More realistic than in-memory fakes.

### SQL Server Container

```csharp
// Package: Testcontainers.MsSql
public class SqlServerFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("Strong_P@ssw0rd!")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        using var context = CreateDbContext();
        await context.Database.MigrateAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();

    public AppDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString)
            .Options;
        return new AppDbContext(options);
    }
}
```

### PostgreSQL Container

```csharp
// Package: Testcontainers.PostgreSql
public class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .WithDatabase("testdb")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        using var context = CreateDbContext();
        await context.Database.MigrateAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();

    public AppDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;
        return new AppDbContext(options);
    }
}
```

### Shared Container with IAsyncLifetime + ICollectionFixture

```csharp
// 1. Define the fixture
public class SharedDatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();
    public string ConnectionString => _container.GetConnectionString();

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        // Run migrations once
        using var context = CreateDbContext();
        await context.Database.MigrateAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();

    public AppDbContext CreateDbContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(ConnectionString).Options);
}

// 2. Define the collection
[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<SharedDatabaseFixture> { }

// 3. Use in test classes -- all classes in this collection share one container
[Collection("Database")]
public class OrderQueryTests
{
    private readonly SharedDatabaseFixture _db;
    public OrderQueryTests(SharedDatabaseFixture db) => _db = db;

    [Fact]
    public async Task GetOrders_ReturnsAll()
    {
        using var context = _db.CreateDbContext();
        // ... test logic
    }
}

[Collection("Database")]
public class OrderCommandTests
{
    private readonly SharedDatabaseFixture _db;
    public OrderCommandTests(SharedDatabaseFixture db) => _db = db;
}
```

### Custom Container Configuration

```csharp
// Custom image, volumes, environment variables, wait strategies
private readonly MsSqlContainer _container = new MsSqlBuilder()
    .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
    .WithPassword("Strong_P@ssw0rd!")
    .WithEnvironment("MSSQL_COLLATION", "SQL_Latin1_General_CP1_CI_AS")
    .WithPortBinding(11433, 1433)                  // Host:Container port mapping
    .WithWaitStrategy(Wait.ForUnixContainer()
        .UntilPortIsAvailable(1433))
    .WithStartupCallback((container, ct) =>        // Run after container starts
    {
        // Execute initialization scripts
        return container.ExecScriptAsync("CREATE DATABASE AppDb;", ct);
    })
    .Build();

// Generic container for unsupported images
var customContainer = new ContainerBuilder()
    .WithImage("my-custom-image:latest")
    .WithPortBinding(8080, true)                   // Random host port
    .WithEnvironment("APP_MODE", "test")
    .WithResourceMapping("init.sql", "/docker-entrypoint-initdb.d/")
    .WithWaitStrategy(Wait.ForUnixContainer()
        .UntilHttpRequestIsSucceeded(r => r.ForPort(8080).ForPath("/health")))
    .Build();
```

### Using Testcontainers with WebApplicationFactory

```csharp
public class IntegrationTestFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _dbContainer = new MsSqlBuilder().Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(_dbContainer.GetConnectionString()));
        });
    }

    public async ValueTask InitializeAsync() => await _dbContainer.StartAsync();

    // xUnit v3: IAsyncLifetime.DisposeAsync and WebApplicationFactory's own
    // `public virtual ValueTask DisposeAsync()` are the same member -- override it
    // and chain to base so the TestServer/host is disposed too.
    // On xUnit v2 this was `public new async Task DisposeAsync()`, which shadowed
    // the base method instead of overriding it.
    public override async ValueTask DisposeAsync()
    {
        await _dbContainer.DisposeAsync();
        await base.DisposeAsync();
    }
}
```

---

## Respawn for Database Reset

Respawn efficiently resets a database to a clean state by intelligently deleting data in dependency order.

```csharp
// Package: Respawn
public class DatabaseFixture : IAsyncLifetime
{
    private Respawner _respawner = null!;
    private string _connectionString = null!;
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();

    public string ConnectionString => _connectionString;

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        _connectionString = _container.GetConnectionString();

        // Run migrations...

        _respawner = await Respawner.CreateAsync(_connectionString, new RespawnerOptions
        {
            TablesToIgnore = new Table[] { "__EFMigrationsHistory", "Countries" },
            SchemasToInclude = new[] { "dbo" },
            DbAdapter = DbAdapter.SqlServer // or DbAdapter.Postgres
        });
    }

    public async Task ResetAsync() => await _respawner.ResetAsync(_connectionString);

    public ValueTask DisposeAsync() => _container.DisposeAsync();
}

// Use in tests: reset before each test
public class OrderTests : IClassFixture<DatabaseFixture>, IAsyncLifetime
{
    private readonly DatabaseFixture _db;
    public OrderTests(DatabaseFixture db) => _db = db;

    public ValueTask InitializeAsync() => new(_db.ResetAsync()); // Clean before each test
    public ValueTask DisposeAsync() => ValueTask.CompletedTask;

    [Fact]
    public async Task CreateOrder_Persists()
    {
        // Start with a clean database every time
    }
}
```

---

## Test Database Strategies

### Transaction Rollback Per Test

Fast isolation. Each test wraps work in a transaction that is rolled back.

```csharp
public class OrderTests : IClassFixture<IntegrationTestFactory>
{
    [Fact]
    public async Task CreateOrder_PersistsToDatabase()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        await using var transaction = await context.Database.BeginTransactionAsync();

        context.Orders.Add(new Order { Total = 99.99m });
        await context.SaveChangesAsync();

        Assert.Single(await context.Orders.ToListAsync());

        await transaction.RollbackAsync(); // Clean slate for next test
    }
}
```

**Caveat**: Breaks if the SUT creates its own DbContext or uses `TransactionScope`. All participants must share the same transaction.

### Database-Per-Test-Class

Each test class gets its own isolated database. Higher overhead, maximum isolation.

```csharp
public class IsolatedDatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();
    private string _connectionString = null!;

    public string ConnectionString => _connectionString;

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        var baseConn = _container.GetConnectionString();
        var dbName = $"TestDb_{Guid.NewGuid():N}";

        // Create a unique database for this test class
        using var conn = new SqlConnection(baseConn);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"CREATE DATABASE [{dbName}]";
        await cmd.ExecuteNonQueryAsync();

        var builder = new SqlConnectionStringBuilder(baseConn) { InitialCatalog = dbName };
        _connectionString = builder.ConnectionString;

        // Run migrations on the new database
        using var context = CreateDbContext();
        await context.Database.MigrateAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();

    public AppDbContext CreateDbContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(_connectionString).Options);
}
```

### Snapshot/Restore

Take a database snapshot after seeding, restore it before each test. Fast reset with full fidelity.

```csharp
public class SnapshotDatabaseFixture : IAsyncLifetime
{
    private string _connectionString = null!;
    private readonly MsSqlContainer _container = new MsSqlBuilder().Build();

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        _connectionString = _container.GetConnectionString();

        // Run migrations and seed reference data
        using var context = CreateDbContext();
        await context.Database.MigrateAsync();
        await SeedReferenceData(context);

        // Create snapshot
        using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            CREATE DATABASE TestDb_Snapshot ON
            (NAME = N'master', FILENAME = N'/var/opt/mssql/data/TestDb_Snapshot.ss')
            AS SNAPSHOT OF [master]";
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task RestoreSnapshotAsync()
    {
        using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            ALTER DATABASE [master] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            RESTORE DATABASE [master] FROM DATABASE_SNAPSHOT = 'TestDb_Snapshot';
            ALTER DATABASE [master] SET MULTI_USER;";
        await cmd.ExecuteNonQueryAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();

    public AppDbContext CreateDbContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(_connectionString).Options);

    private async Task SeedReferenceData(AppDbContext context) { /* ... */ }
}
```

### Choosing a Strategy

| Strategy | Speed | Isolation | Complexity | Fidelity |
|----------|-------|-----------|------------|----------|
| Transaction rollback | Fastest | High | Medium | Lower (triggers may not fire) |
| Respawn | Medium | Highest | Low | High |
| Database-per-class | Slow | Highest | Medium | Highest |
| Snapshot/restore | Fast | Highest | High | Highest |

---

## CI/CD Integration

### GitHub Actions with Testcontainers

Testcontainers requires Docker access. Docker is available by default on `ubuntu-latest`.

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      # Testcontainers pulls and starts containers automatically
      - name: Run integration tests
        run: dotnet test --filter Category=Integration --logger trx --results-directory TestResults

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: TestResults/*.trx
```

### GitHub Actions with Service Containers (no Testcontainers)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    services:
      sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
        env:
          ACCEPT_EULA: Y
          SA_PASSWORD: Strong_P@ssw0rd!
        ports:
          - 1433:1433
        options: >-
          --health-cmd "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P Strong_P@ssw0rd! -C -Q 'SELECT 1'"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - run: dotnet test --filter Category=Integration
        env:
          ConnectionStrings__Default: "Server=localhost;Database=TestDb;User Id=sa;Password=Strong_P@ssw0rd!;TrustServerCertificate=True"
```

### Docker-in-Docker for Testcontainers

When running in environments without native Docker (e.g., Kubernetes-based CI), use Docker-in-Docker (DinD):

```yaml
# GitLab CI example
integration-tests:
  image: mcr.microsoft.com/dotnet/sdk:8.0
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    TESTCONTAINERS_HOST_OVERRIDE: docker
  script:
    - dotnet test --filter Category=Integration
```

### Test Filtering and Parallelism

```csharp
// Categorize tests with traits
[Trait("Category", "Integration")]
public class OrderApiTests : IClassFixture<IntegrationTestFactory> { }

[Trait("Category", "Unit")]
public class OrderServiceTests { }
```

```bash
# Run only integration tests
dotnet test --filter Category=Integration

# Run only unit tests
dotnet test --filter Category!=Integration

# Run specific test class
dotnet test --filter FullyQualifiedName~OrderApiTests

# Parallel execution (xUnit default: parallel per collection)
# Disable parallelism if tests share state:
# [assembly: CollectionBehavior(DisableTestParallelization = true)]

# Limit parallelism in CI
dotnet test -- xunit.maxParallelThreads=4
```

### Code Coverage Collection (Coverlet)

```bash
# Package: coverlet.collector (included in default test template)

# Collect coverage during test run
dotnet test --collect:"XPlat Code Coverage"

# With specific output format
dotnet test --collect:"XPlat Code Coverage" \
  -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura

# Generate HTML report (requires dotnet-reportgenerator-globaltool)
dotnet tool install -g dotnet-reportgenerator-globaltool
reportgenerator \
  -reports:"**/coverage.cobertura.xml" \
  -targetdir:"coveragereport" \
  -reporttypes:Html
```

```xml
<!-- runsettings file for fine-grained control: coverage.runsettings -->
<?xml version="1.0" encoding="utf-8" ?>
<RunSettings>
  <DataCollectionRunSettings>
    <DataCollectors>
      <DataCollector friendlyName="XPlat Code Coverage">
        <Configuration>
          <Format>cobertura</Format>
          <Exclude>[*.Tests]*,[*]*.Migrations.*</Exclude>
          <ExcludeByAttribute>GeneratedCodeAttribute,ObsoleteAttribute</ExcludeByAttribute>
          <SingleHit>false</SingleHit>
          <UseSourceLink>true</UseSourceLink>
        </Configuration>
      </DataCollector>
    </DataCollectors>
  </DataCollectionRunSettings>
</RunSettings>
```

```bash
# Use the runsettings file
dotnet test --settings coverage.runsettings
```

GitHub Actions with coverage reporting:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-dotnet@v4
    with:
      dotnet-version: '8.0.x'

  - name: Run tests with coverage
    run: dotnet test --collect:"XPlat Code Coverage" --results-directory TestResults

  - name: Generate coverage report
    run: |
      dotnet tool install -g dotnet-reportgenerator-globaltool
      reportgenerator \
        -reports:"TestResults/**/coverage.cobertura.xml" \
        -targetdir:"coveragereport" \
        -reporttypes:"Html;Cobertura"

  - name: Upload coverage
    uses: actions/upload-artifact@v4
    with:
      name: coverage-report
      path: coveragereport/
```

### Performance Tips for CI

- Use container image caching (pull images in a separate step or use a registry cache).
- Run unit tests and integration tests in **parallel jobs**.
- Use `per-collection` database strategy to reduce container spin-up count.
- Set reasonable timeouts on container startup (Testcontainers default is 60s).
- Use `WithReuse(true)` during **local development only** (not CI).
- Filter tests by category to avoid running slow integration tests on every push.

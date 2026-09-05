# .NET Testing Code Patterns

Optional examples; match the existing project tools and framework. Numbered sections retain stable reference anchors; they are not mandatory defaults. For Moq/NSubstitute deep dive see `mocking-frameworks.md`; for WebApplicationFactory/Testcontainers see `integration-testing.md`.

**xUnit version stance:** examples target xUnit v3 (package `xunit.v3` 3.x), where `IAsyncLifetime : IAsyncDisposable` and both members return `ValueTask`. On xUnit v2 (package `xunit` 2.x) change them back to `Task InitializeAsync()` / `Task DisposeAsync()`. v3 also adds an assembly-wide fixture level — `[assembly: AssemblyFixture(typeof(TFixture))]` — for resources too expensive even per collection.

## Rule 1 — AAA Pattern

```csharp
[Fact]
public async Task CreateOrder_WithValidInput_ReturnsCreatedOrder()
{
    // Arrange
    var service = new OrderService(_mockRepo.Object, _mockLogger.Object);
    var dto = new CreateOrderDto { CustomerId = 1, Amount = 99.99m };

    // Act
    var result = await service.CreateAsync(dto, CancellationToken.None);

    // Assert
    Assert.NotNull(result);
    Assert.Equal(dto.CustomerId, result.CustomerId);
    Assert.Equal(dto.Amount, result.Amount);
}
```

## Rule 2 — Test naming

```csharp
// ✅ Clear — immediately understand what's tested
[Fact]
public async Task GetById_WhenOrderNotFound_ReturnsNull() { /* ... */ }

[Fact]
public void Validate_WithNegativeAmount_ThrowsArgumentException() { /* ... */ }

[Fact]
public async Task Process_WhenCancelled_StopsGracefully() { /* ... */ }

// ❌ Unclear — what scenario? what's expected?
[Fact]
public void TestOrder() { /* ... */ }

[Fact]
public void OrderServiceTest3() { /* ... */ }
```

## Rule 3 — Parameterized tests with Theory

```csharp
[Theory]
[InlineData("", false)]           // empty
[InlineData("abc", false)]        // no @
[InlineData("a@b.c", true)]       // valid
[InlineData("user@domain.com", true)]
public void IsValidEmail_WithVariousInputs_ReturnsExpected(string email, bool expected)
{
    var result = EmailValidator.IsValid(email);
    Assert.Equal(expected, result);
}

// For complex objects, use MemberData or ClassData
[Theory]
[MemberData(nameof(GetOrderTestCases))]
public async Task ProcessOrder_WithVariousOrders_BehavesCorrectly(
    Order order, bool expectedSuccess)
{
    var result = await _service.ProcessAsync(order);
    Assert.Equal(expectedSuccess, result.IsSuccess);
}

public static IEnumerable<object[]> GetOrderTestCases()
{
    yield return new object[] { new Order { Amount = 100m }, true };
    yield return new object[] { new Order { Amount = -1m }, false };
}
```

## Rule 4 — Mock only external boundaries

```csharp
// ✅ Good — mock external boundary
var mockHttpHandler = new Mock<HttpMessageHandler>();
mockHttpHandler.Protected()
    .Setup<Task<HttpResponseMessage>>("SendAsync",
        ItExpr.IsAny<HttpRequestMessage>(),
        ItExpr.IsAny<CancellationToken>())
    .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK));

// ✅ Good — use real implementation for your own code
var repository = new InMemoryOrderRepository();  // simple fake
var service = new OrderService(repository, NullLogger<OrderService>.Instance);

// ❌ Avoid — mocking your own interface with strict verification
var mockRepo = new Mock<IOrderRepository>(MockBehavior.Strict);
mockRepo.Setup(r => r.GetByIdAsync(42, It.IsAny<CancellationToken>()))
    .ReturnsAsync(testOrder);
// This test breaks if the service changes which repo method it calls,
// even if the behavior is still correct.
```

## Rule 5 — Moq vs NSubstitute (pick one)

```csharp
// Moq style
var mock = new Mock<IOrderService>();
mock.Setup(s => s.GetByIdAsync(42, It.IsAny<CancellationToken>()))
    .ReturnsAsync(expectedOrder);
var service = mock.Object;

// NSubstitute style
var sub = Substitute.For<IOrderService>();
sub.GetByIdAsync(42, Arg.Any<CancellationToken>())
    .Returns(expectedOrder);
```

## Rule 6 — AutoFixture / Bogus

```csharp
// Explicit data: prefer a small existing builder if repeated setup becomes noise.
var order = new Order
{
    Id = 1, CustomerId = 42, CustomerName = "Test",
    Amount = 99.99m, Currency = "USD", Status = OrderStatus.Pending,
    CreatedAt = DateTime.UtcNow, Items = new List<OrderItem>()
};

// If AutoFixture is already appropriate for the project: specify what matters.
var fixture = new Fixture();
var order = fixture.Build<Order>()
    .With(o => o.Status, OrderStatus.Pending)  // only this matters for the test
    .Create();

// ✅ With AutoFixture + xUnit integration
[Theory, AutoData]
public void Process_WithAnyValidOrder_Succeeds(Order order)
{
    order.Status = OrderStatus.Pending; // override only relevant field
    var result = _processor.Process(order);
    Assert.True(result.IsSuccess);
}

// Bogus — realistic-looking fake data (names, addresses, emails)
var faker = new Faker<Customer>()
    .RuleFor(c => c.Name, f => f.Person.FullName)
    .RuleFor(c => c.Email, f => f.Internet.Email())
    .RuleFor(c => c.Phone, f => f.Phone.PhoneNumber());

var customers = faker.Generate(10);
```

## Rule 7 — WebApplicationFactory

```csharp
public class OrdersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace real database with test database
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(opts =>
                    opts.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetOrders_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/orders");
        response.EnsureSuccessStatusCode();
    }
}
```

## Rule 8 — Testcontainers for DB tests

```csharp
public class DatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public ValueTask InitializeAsync() => new(_container.StartAsync());
    public ValueTask DisposeAsync() => _container.DisposeAsync();
}

[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture> { }

[Collection("Database")]
public class OrderRepositoryTests
{
    private readonly DatabaseFixture _db;

    public OrderRepositoryTests(DatabaseFixture db) => _db = db;

    [Fact]
    public async Task Insert_WithValidOrder_Persists()
    {
        await using var context = CreateContext(_db.ConnectionString);
        var repo = new OrderRepository(context);

        await repo.AddAsync(new Order { Amount = 100m });
        await context.SaveChangesAsync();

        var orders = await repo.GetAllAsync();
        Assert.Single(orders);
    }
}
```

## Rule 9 — Test isolation

```csharp
// ❌ Wrong — shared static state
private static List<Order> _orders = new(); // shared across tests, not thread-safe

// ✅ Correct — each test gets its own state
[Fact]
public async Task Test1()
{
    var orders = new List<Order>(); // local to this test
    // ...
}

// Use IAsyncLifetime for setup/teardown
public class OrderTests : IAsyncLifetime
{
    private AppDbContext _context;

    public async ValueTask InitializeAsync()
    {
        _context = CreateFreshContext(); // clean database per test
        await SeedTestData(_context);
    }

    public ValueTask DisposeAsync() => _context.DisposeAsync();
}
```

## Rule 10 — Test behavior, not implementation

```csharp
// ❌ Wrong — testing implementation details
mock.Verify(r => r.ValidateInternalState(), Times.Once);  // internal method
mock.Verify(r => r.GetByIdAsync(42, It.IsAny<CancellationToken>()), Times.Exactly(1));

// ✅ Correct — testing observable behavior
var result = await service.GetOrderAsync(42);
Assert.NotNull(result);
Assert.Equal(42, result.Id);
Assert.Equal("Shipped", result.Status);
```

## Rule 11 — Speed targets

Measure the affected suite on the actual runner and compare with its baseline. Set finite bounds for hung tests and record performance regressions with the same workload; there is no universal unit/integration/E2E duration cutoff. Share expensive context through existing fixtures only with isolation and reset guarantees. Prefer a completion signal (`TaskCompletionSource`) or bounded condition polling over `Thread.Sleep`.

## Rule 12 — Coverage strategy

**What to cover:**
- Business rules and calculations
- Input validation and boundary conditions
- Error handling paths (what happens when X fails?)
- Complex conditional logic
- Concurrency-sensitive code

**What NOT to cover (diminishing returns):**
- Auto-generated code (Designer.cs, migrations)
- Simple DTOs/POCOs with no logic
- Framework configuration (Startup.cs, Program.cs)
- One-liner property accessors

## Test Project Structure

```
tests/
├── MyApp.UnitTests/               # Fast, isolated, no external deps
│   ├── Services/
│   │   ├── OrderServiceTests.cs
│   │   └── PaymentServiceTests.cs
│   └── Validators/
│       └── OrderValidatorTests.cs
├── MyApp.IntegrationTests/        # Real pipeline, real DB (Testcontainers)
│   ├── Fixtures/
│   │   └── DatabaseFixture.cs
│   ├── Api/
│   │   └── OrdersEndpointTests.cs
│   └── Repositories/
│       └── OrderRepositoryTests.cs
└── MyApp.TestUtilities/           # Shared test helpers (builders, fakers)
    ├── Builders/
    │   └── OrderBuilder.cs
    └── Fakers/
        └── CustomerFaker.cs
```

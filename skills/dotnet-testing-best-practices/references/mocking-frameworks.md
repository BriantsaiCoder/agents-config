# .NET Mocking Frameworks Reference

## Moq Deep Dive

### Setup, Returns, ReturnsAsync

```csharp
var mock = new Mock<IOrderRepository>();

// Simple return
mock.Setup(r => r.GetById(42)).Returns(new Order { Id = 42, Total = 100m });

// Return based on input
mock.Setup(r => r.GetById(It.IsAny<int>()))
    .Returns((int id) => new Order { Id = id });

// Async returns
mock.Setup(r => r.GetByIdAsync(42)).ReturnsAsync(new Order { Id = 42 });

// Sequential returns
mock.SetupSequence(r => r.GetNextOrder())
    .Returns(new Order { Id = 1 })
    .Returns(new Order { Id = 2 })
    .Throws<InvalidOperationException>(); // Third call throws
```

### Callback

Execute code when the mocked method is called. Useful for capturing arguments or side effects.

```csharp
var capturedOrders = new List<Order>();

mock.Setup(r => r.Save(It.IsAny<Order>()))
    .Callback<Order>(order => capturedOrders.Add(order))
    .Returns(true);

// Callback before and after Returns
mock.Setup(r => r.Save(It.IsAny<Order>()))
    .Callback<Order>(o => Debug.WriteLine($"Saving {o.Id}"))
    .Returns(true)
    .Callback<Order>(o => Debug.WriteLine($"Saved {o.Id}"));
```

### Throws

```csharp
mock.Setup(r => r.Delete(It.Is<int>(id => id < 0)))
    .Throws<ArgumentException>();

mock.Setup(r => r.DeleteAsync(It.Is<int>(id => id < 0)))
    .ThrowsAsync(new ArgumentException("Invalid ID"));
```

### Argument Matchers (It class)

```csharp
It.IsAny<int>()                           // Any value
It.Is<int>(x => x > 0)                    // Predicate match
It.IsIn(1, 2, 3)                          // In set
It.IsNotIn(4, 5)                          // Not in set
It.IsInRange(1, 100, Moq.Range.Inclusive) // Range
It.IsRegex(@"^\d{3}$")                    // Regex for strings
It.IsNotNull<string>()                    // Non-null
```

### Verify, VerifyAll, Times

Assert that methods were called with expected arguments and frequency.

```csharp
mock.Verify(r => r.Save(It.IsAny<Order>()), Times.Once);
mock.Verify(r => r.Delete(It.IsAny<int>()), Times.Never);
mock.Verify(r => r.GetById(42), Times.Exactly(2));
mock.Verify(r => r.Search(It.Is<string>(s => s.Length > 3)), Times.AtLeastOnce);
mock.Verify(r => r.Ping(), Times.AtLeast(3));
mock.Verify(r => r.Ping(), Times.AtMost(5));
mock.Verify(r => r.Ping(), Times.Between(2, 5, Moq.Range.Inclusive));

// VerifyAll: asserts that ALL Setups were invoked at least once
mock.Setup(r => r.GetById(42)).Returns(new Order());
mock.Setup(r => r.Save(It.IsAny<Order>())).Returns(true);
// ... run SUT ...
mock.VerifyAll(); // Fails if either Setup was never called

// Verify no other calls were made beyond what was verified
mock.VerifyNoOtherCalls();
```

### MockBehavior.Strict vs Loose

```csharp
// Strict: throws MockException on any call without a matching Setup.
var strict = new Mock<IOrderRepository>(MockBehavior.Strict);
strict.Setup(r => r.GetById(42)).Returns(new Order());
// strict.Object.GetById(99); // throws MockException -- no matching Setup

// Loose (default): returns default values for unconfigured members.
var loose = new Mock<IOrderRepository>(MockBehavior.Loose);
// loose.Object.GetById(99) returns null (default for reference type)
// Unconfigured int returns 0; string returns null; Task returns completed task.
```

**Recommendation**: Use `Loose` by default. Use `Strict` only when verifying that no unexpected calls are made (e.g., testing that a cache prevents a database call).

### Mocking Properties

```csharp
// Setup property getter
mock.Setup(r => r.ConnectionString).Returns("Server=test");
mock.SetupGet(r => r.IsConnected).Returns(true);

// Setup property setter
mock.SetupSet(r => r.ConnectionString = "Server=prod");
mock.SetupSet(r => r.ConnectionString = It.IsAny<string>())
    .Callback<string>(val => Debug.WriteLine($"Set to: {val}"));

// Verify property access
mock.VerifyGet(r => r.IsConnected, Times.Once);
mock.VerifySet(r => r.ConnectionString = "Server=prod", Times.Once);

// Stub all properties (auto-tracks get/set)
mock.SetupAllProperties();
mock.Object.ConnectionString = "Server=prod";
Assert.Equal("Server=prod", mock.Object.ConnectionString);
```

### Mocking Events

```csharp
var mock = new Mock<IOrderRepository>();

// Raise event when method is called
mock.Setup(r => r.Save(It.IsAny<Order>()))
    .Returns(true)
    .Raises(r => r.OrderSaved += null, new OrderSavedEventArgs(42));

// Raise event manually
mock.Raise(r => r.OrderSaved += null, new OrderSavedEventArgs(42));

// Verify event subscription
mock.VerifyAdd(r => r.OrderSaved += It.IsAny<EventHandler<OrderSavedEventArgs>>());
mock.VerifyRemove(r => r.OrderSaved -= It.IsAny<EventHandler<OrderSavedEventArgs>>());
```

### Mocking Protected Members

```csharp
// For abstract/virtual protected methods (common with HttpMessageHandler)
var mock = new Mock<MyBaseClass>();

mock.Protected()
    .Setup<int>("CalculateDiscount", ItExpr.IsAny<Order>())
    .Returns(10);

mock.Protected()
    .Setup<Task<HttpResponseMessage>>(
        "SendAsync",
        ItExpr.IsAny<HttpRequestMessage>(),
        ItExpr.IsAny<CancellationToken>())
    .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK));

// Verify protected member
mock.Protected()
    .Verify("CalculateDiscount", Times.Once(), ItExpr.IsAny<Order>());
```

### Multi-Interface Mocking with As<T>()

```csharp
var mock = new Mock<IOrderRepository>();

// Add additional interface implementations to the same mock
mock.As<IDisposable>()
    .Setup(d => d.Dispose());

mock.As<IOrderValidator>()
    .Setup(v => v.Validate(It.IsAny<Order>()))
    .Returns(true);

// The mock object now implements both interfaces
IOrderRepository repo = mock.Object;
IOrderValidator validator = (IOrderValidator)mock.Object;
IDisposable disposable = (IDisposable)mock.Object;

// Verify across interfaces
mock.As<IOrderValidator>()
    .Verify(v => v.Validate(It.IsAny<Order>()), Times.Once);
```

### Mock.Of<T> (Functional Syntax)

Creates an already-configured mock object in one expression. Best for simple scenarios.

```csharp
var repo = Mock.Of<IOrderRepository>(r =>
    r.GetById(42) == new Order { Id = 42, Total = 100m } &&
    r.IsConnected == true);

// Get the Mock<T> wrapper if you need Verify later
var mock = Mock.Get(repo);
mock.Verify(r => r.GetById(42), Times.Once);
```

---

## NSubstitute Deep Dive

### Substitute.For<T> and Returns

```csharp
var repo = Substitute.For<IOrderRepository>();

// Simple return
repo.GetById(42).Returns(new Order { Id = 42 });

// Return based on input
repo.GetById(Arg.Any<int>()).Returns(callInfo =>
    new Order { Id = callInfo.ArgAt<int>(0) });

// Async returns -- wraps in Task automatically
repo.GetByIdAsync(42).Returns(new Order { Id = 42 });

// Sequential returns
repo.GetNextOrder().Returns(
    new Order { Id = 1 },
    new Order { Id = 2 }); // Returns in sequence

// Throwing
repo.Delete(Arg.Is<int>(id => id < 0))
    .Returns(x => throw new ArgumentException());
```

### ReturnsForAnyArgs

```csharp
// Returns a value regardless of what arguments are passed
repo.GetById(default).ReturnsForAnyArgs(new Order { Id = 99 });

// Now any call matches:
var order1 = repo.GetById(1);   // Returns Order { Id = 99 }
var order2 = repo.GetById(999); // Returns Order { Id = 99 }

// Useful when you don't care about the specific arguments
repo.Search(default, default).ReturnsForAnyArgs(new List<Order>());
```

### Argument Matchers (Arg class)

```csharp
Arg.Any<int>()                          // Any value
Arg.Is<int>(x => x > 0)                // Predicate
Arg.Is(42)                              // Exact value
Arg.Do<Order>(o => captured.Add(o))     // Capture argument
Arg.Compat.Is<int>(x => x > 0)         // For non-virtual/interface scenarios
```

### Received, DidNotReceive (Verification)

```csharp
repo.Received().Save(Arg.Any<Order>());             // At least once
repo.Received(2).GetById(Arg.Any<int>());           // Exactly 2 times
repo.DidNotReceive().Delete(Arg.Any<int>());        // Never called
repo.ReceivedWithAnyArgs().Save(default);            // Called with any args
repo.DidNotReceiveWithAnyArgs().Delete(default);     // Never called (any args)

// Clear received calls (useful in Arrange-Act-Assert when setup triggers calls)
repo.ClearReceivedCalls();

// Check call order
Received.InOrder(() =>
{
    repo.GetById(1);
    repo.Save(Arg.Any<Order>());
});
```

### When...Do (Callbacks)

```csharp
var captured = new List<Order>();

repo.When(r => r.Save(Arg.Any<Order>()))
    .Do(callInfo => captured.Add(callInfo.ArgAt<Order>(0)));

// For void methods that should throw
repo.When(r => r.Delete(-1)).Throw<InvalidOperationException>();

// WhenForAnyArgs
repo.WhenForAnyArgs(r => r.Delete(default))
    .Do(ci => Debug.WriteLine($"Delete called with {ci.ArgAt<int>(0)}"));
```

### Properties

```csharp
repo.ConnectionString.Returns("Server=test");
repo.IsConnected.Returns(true);

// Auto-property behavior: NSubstitute tracks property sets by default
repo.ConnectionString = "Server=prod";
Assert.Equal("Server=prod", repo.ConnectionString); // Works without setup
```

### Partial Substitutes

```csharp
// ForPartsOf calls real implementation by default, allows overriding virtual members
var sub = Substitute.ForPartsOf<OrderService>(realRepo);

// Override a virtual method
sub.Configure().SendNotification(Arg.Any<Order>()).Returns(true);

// Real method is called for non-overridden virtual members
var result = sub.ProcessOrder(order); // Calls real ProcessOrder

// Prevent real call on a specific setup
sub.When(s => s.SendNotification(Arg.Any<Order>())).DoNotCallBase();
sub.SendNotification(Arg.Any<Order>()).Returns(true);
```

**Warning**: ForPartsOf requires methods to be `virtual`. Non-virtual methods always call the real implementation.

---

## Moq vs NSubstitute Comparison

| Feature | Moq | NSubstitute |
|---------|-----|-------------|
| Syntax style | `mock.Setup(x => x.Method())` | `sub.Method().Returns(value)` |
| Create mock | `new Mock<T>()` / `Mock.Of<T>()` | `Substitute.For<T>()` |
| Return value | `.Returns(val)` / `.ReturnsAsync(val)` | `.Returns(val)` (auto-wraps Task) |
| Any args return | N/A (use It.IsAny in Setup) | `.ReturnsForAnyArgs(val)` |
| Argument match | `It.IsAny<T>()`, `It.Is<T>(pred)` | `Arg.Any<T>()`, `Arg.Is<T>(pred)` |
| Verify call | `mock.Verify(x => x.M(), Times.Once)` | `sub.Received().M()` |
| Verify not called | `mock.Verify(x => x.M(), Times.Never)` | `sub.DidNotReceive().M()` |
| Capture args | `.Callback<T>(val => ...)` | `Arg.Do<T>(val => ...)` |
| Strict mode | `MockBehavior.Strict` | No built-in equivalent |
| Partial mock | `new Mock<T> { CallBase = true }` | `Substitute.ForPartsOf<T>()` |
| Multi-interface | `mock.As<IOther>()` | `Substitute.For<IA, IB>()` |
| License | MIT | BSD |

**Recommendation**: Both are excellent. Pick one per project and be consistent. NSubstitute has slightly less ceremony; Moq has stricter verification options.

---

## Mocking HttpClient

Never mock `HttpClient` directly (its methods are not virtual). Mock `HttpMessageHandler` instead.

### Moq approach (Protected mock)

```csharp
public static HttpClient CreateMockHttpClient(
    HttpStatusCode statusCode,
    string content)
{
    var handler = new Mock<HttpMessageHandler>();

    handler.Protected()
        .Setup<Task<HttpResponseMessage>>(
            "SendAsync",
            ItExpr.IsAny<HttpRequestMessage>(),
            ItExpr.IsAny<CancellationToken>())
        .ReturnsAsync(new HttpResponseMessage
        {
            StatusCode = statusCode,
            Content = new StringContent(content, Encoding.UTF8, "application/json")
        });

    return new HttpClient(handler.Object)
    {
        BaseAddress = new Uri("https://api.test.com/")
    };
}

// Verify the request was made with correct URL and method
handler.Protected().Verify(
    "SendAsync",
    Times.Once(),
    ItExpr.Is<HttpRequestMessage>(req =>
        req.Method == HttpMethod.Post &&
        req.RequestUri!.PathAndQuery == "/api/orders"),
    ItExpr.IsAny<CancellationToken>());
```

### NSubstitute approach (custom DelegatingHandler)

```csharp
public class FakeHandler : DelegatingHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _handlerFunc;

    public FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> handlerFunc)
        => _handlerFunc = handlerFunc;

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromResult(_handlerFunc(request));
}

// Usage
var client = new HttpClient(new FakeHandler(req =>
    new HttpResponseMessage(HttpStatusCode.OK)
    {
        Content = new StringContent("{\"id\":1}", Encoding.UTF8, "application/json")
    }))
{
    BaseAddress = new Uri("https://api.test.com/")
};
```

**Better alternative**: Use `IHttpClientFactory` in production. In tests, replace the handler via DI or use a library like `RichardSzalay.MockHttp`.

---

## Mocking ILogger<T>

`ILogger<T>` logging methods are extension methods, which cannot be mocked directly. Mock the underlying `ILogger.Log` method.

### Moq: Verify log calls

```csharp
var mockLogger = new Mock<ILogger<OrderService>>();

var service = new OrderService(mockLogger.Object);
service.ProcessOrder(invalidOrder);

// Verify a specific log level and message substring
mockLogger.Verify(
    x => x.Log(
        LogLevel.Error,
        It.IsAny<EventId>(),
        It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("failed")),
        It.IsAny<Exception>(),
        It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
    Times.Once);
```

### NullLogger (when you don't need to verify)

```csharp
var service = new OrderService(NullLogger<OrderService>.Instance);
```

### FakeLogger (.NET 8+)

```csharp
// Package: Microsoft.Extensions.Diagnostics.Testing
var fakeLogger = new FakeLogger<OrderService>();
var service = new OrderService(fakeLogger);

service.ProcessOrder(order);

// Assert on captured log entries
var logs = fakeLogger.Collector.GetSnapshot();
Assert.Single(logs, entry =>
    entry.Level == LogLevel.Information &&
    entry.Message.Contains("Order processed"));
```

---

## Auto-Mocking with AutoFixture

AutoFixture generates test data and auto-creates mocks for constructor dependencies.

### AutoFixture.AutoMoq

```csharp
// Package: AutoFixture.AutoMoq
[Fact]
public void ProcessOrder_WithValidOrder_ReturnsSuccess()
{
    var fixture = new Fixture().Customize(new AutoMoqCustomization());

    // All constructor dependencies of OrderService are auto-mocked
    var sut = fixture.Create<OrderService>();

    // Configure specific mock behavior
    var repoMock = fixture.Freeze<Mock<IOrderRepository>>();
    repoMock.Setup(r => r.Save(It.IsAny<Order>())).Returns(true);

    var order = fixture.Create<Order>();

    var result = sut.ProcessOrder(order);

    Assert.True(result);
}
```

### AutoFixture.AutoNSubstitute

```csharp
// Package: AutoFixture.AutoNSubstitute
[Fact]
public void ProcessOrder_WithValidOrder_ReturnsSuccess()
{
    var fixture = new Fixture().Customize(new AutoNSubstituteCustomization());

    var repo = fixture.Freeze<IOrderRepository>();
    repo.Save(Arg.Any<Order>()).Returns(true);

    var sut = fixture.Create<OrderService>();
    var order = fixture.Create<Order>();

    var result = sut.ProcessOrder(order);

    Assert.True(result);
    repo.Received().Save(Arg.Any<Order>());
}
```

### Freeze vs Create

- `fixture.Create<T>()` -- generates a new instance each time.
- `fixture.Freeze<T>()` -- generates once, returns the same instance for all subsequent requests. Use `Freeze` for dependencies you want to configure or verify.

### xUnit Integration with AutoData

```csharp
// Package: AutoFixture.Xunit2
[Theory, AutoMoqData]
public void GetOrder_ReturnsOrder(
    [Frozen] Mock<IOrderRepository> repoMock,
    OrderService sut,
    Order expected)
{
    repoMock.Setup(r => r.GetById(expected.Id)).Returns(expected);

    var result = sut.GetOrder(expected.Id);

    Assert.Equal(expected, result);
}

// Custom attribute combining AutoData + AutoMoq:
public class AutoMoqDataAttribute : AutoDataAttribute
{
    public AutoMoqDataAttribute()
        : base(() => new Fixture().Customize(new AutoMoqCustomization())) { }
}

// NSubstitute variant:
public class AutoNSubstituteDataAttribute : AutoDataAttribute
{
    public AutoNSubstituteDataAttribute()
        : base(() => new Fixture().Customize(new AutoNSubstituteCustomization())) { }
}
```

---

## When NOT to Mock

Mocking is a tool for isolating collaborators. Overuse leads to brittle, hard-to-maintain tests.

### Do not mock these

- **Value objects and DTOs**: `Order`, `Address`, `Money` -- just instantiate them directly.
- **Simple pure logic**: Math, string formatting, mapping functions -- test them with real inputs.
- **Collections**: `List<T>`, `Dictionary<K,V>` -- use real collections.
- **Records and POCOs**: They have no behavior to replace.
- **The system under test**: If you mock half the class, the test proves nothing.

### Prefer fakes or real implementations for

- **In-memory databases**: `UseInMemoryDatabase` or SQLite in-memory for simple EF Core tests.
- **File system**: Use `System.IO.Abstractions` with `MockFileSystem`, or a temp directory.
- **Time**: Inject `TimeProvider` (or `ISystemClock`) rather than mocking `DateTime.Now`.
- **Configuration**: Use `IOptions<T>` with `Options.Create(new MyConfig { ... })`.

### Signs you are over-mocking

- Tests break when you refactor internals but behavior is unchanged.
- Test setup is longer than the assertion.
- Every test mocks the same 5 dependencies with identical setup.
- You are mocking concrete classes that you own (extract an interface or restructure).

```csharp
// BAD: mocking a value object
var mockOrder = new Mock<Order>(); // Order is a simple class, just new it up

// GOOD: use a real instance
var order = new Order { Id = 1, Total = 100m, Status = OrderStatus.Pending };

// BAD: mocking IOptions<T>
var mockOptions = new Mock<IOptions<SmtpSettings>>();
mockOptions.Setup(o => o.Value).Returns(new SmtpSettings { Host = "localhost" });

// GOOD: use Options.Create
var options = Options.Create(new SmtpSettings { Host = "localhost" });
```

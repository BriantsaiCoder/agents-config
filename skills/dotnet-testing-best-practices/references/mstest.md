# MSTest-Specific Patterns (MSTest 3.x / 4.x)

Target skill covers xUnit by default. This file is the MSTest cheat sheet — all 12 Golden Rules still apply; only attributes/APIs change.

## Framework Comparison

| Concept | xUnit | NUnit | MSTest 3.x/4.x |
|---|---|---|---|
| Test class | *(none)* | `[TestFixture]` | `[TestClass]` (seal by default) |
| Test method | `[Fact]` | `[Test]` | `[TestMethod]` |
| Parameterised | `[Theory]` + `[InlineData]` / `[MemberData]` | `[TestCase]` / `[TestCaseSource]` | `[TestMethod]` + `[DataRow]` / `[DynamicData]` |
| Per-test setup | Constructor | `[SetUp]` | Constructor (preferred) or `[TestInitialize]` for async |
| Per-test teardown | `IDisposable.Dispose` | `[TearDown]` | `[TestCleanup]` or `DisposeAsync` |
| Per-class setup | `IClassFixture<T>` | `[OneTimeSetUp]` | `[ClassInitialize]` (static) |
| Assembly setup | *(custom)* | `[SetUpFixture]` | `[AssemblyInitialize]` |
| Exception (derived) | `Assert.Throws<T>` | `Assert.Throws<T>` | `Assert.Throws<T>` |
| Exception (exact) | — | — | `Assert.ThrowsExactly<T>` (3.8+) |
| Category | `[Trait("Category","…")]` | `[Category("…")]` | `[TestCategory("…")]` |
| Skip | `Skip = "…"` on Fact | `[Ignore("…")]` | `[Ignore("…")]` |

Argument order reminder: MSTest is expected-first — `Assert.AreEqual(expected, actual)`.

Project setup: use `MSTest.Sdk` (3.x+) for simplified `.csproj`; analyzers ship with the package (`MSTEST0020` enforces constructor over `[TestInitialize]`).

## Modern Assertion APIs (MSTest 3.x+)

Prefer the new `Assert` members over `[ExpectedException]`, `CollectionAssert`, and LINQ helpers — better failure messages.

```csharp
var ex = Assert.Throws<ArgumentException>(() => Method(null));            // T or derived
var ex = Assert.ThrowsExactly<InvalidOperationException>(() => Method()); // exact (3.8+)
var ex = await Assert.ThrowsAsync<HttpRequestException>(async () => await client.GetAsync(url));

Assert.ContainsSingle(items);                          // vs items.Single()
Assert.HasCount(5, items);
Assert.Contains(expected, collection);
Assert.StartsWith("prefix", actual);
Assert.MatchesRegex(@"\d{3}-\d{4}", phone);
Assert.IsGreaterThan(0, actual);
Assert.IsInRange(actual, low, high);
var handler = Assert.IsInstanceOfType<MyHandler>(result);  // 4.x returns typed; 3.x uses out-param
Assert.That(result.Count > 0);                              // 4.0+ auto-captures expression
```

## Data-Driven Tests

Prefer `ValueTuple` or `TestDataRow` over `IEnumerable<object[]>` — `object[]` loses type safety.

```csharp
[TestMethod]
[DataRow(1, 2, 3)]
[DataRow(-1, 1, 0, IgnoreMessage = "Known issue #123")]  // MSTest 3.8+
public void Add_ReturnsSum(int a, int b, int expected) =>
    Assert.AreEqual(expected, Calculator.Add(a, b));

public static IEnumerable<(int a, int b, int expected)> Cases => [(1, 2, 3), (0, 0, 0)];

[TestMethod, DynamicData(nameof(Cases))]  // type-safe since 3.7+
public void Add_DynamicCases(int a, int b, int expected) =>
    Assert.AreEqual(expected, Calculator.Add(a, b));
```

## TestContext

Preferred access is **constructor injection** (MSTest 3.6+) — avoids nullable warnings, enables `readonly`.

```csharp
[TestClass]
public sealed class MyTests(TestContext testContext)
{
    [TestMethod, Timeout(5000)]
    public async Task LongRunning() =>
        await _client.GetAsync(url, testContext.CancellationToken);  // cooperative cancel with [Timeout]
}
```

Key members: `CancellationToken`, `WriteLine`, `AddResultFile`, `CurrentTestOutcome`, `TestException` (3.7+, in cleanup).

Do **not** mark `TestContext` property nullable or `= null!` — MSTest suppresses CS8618 for it already.

## MSTest-Unique Attributes

`[Retry(3)]` (3.9+, prefer fixing isolation per Rule 9 over masking), `[OSCondition(OperatingSystems.Windows)]` (3.10+), `[CICondition]` / `[CICondition(ConditionMode.Exclude)]`, `[WorkItem(12345)]` / `[GitHubWorkItem("url")]` (3.8+), `[DoNotParallelize]` on class, assembly `[assembly: Parallelize(Workers=4, Scope=ExecutionScope.MethodLevel)]`.

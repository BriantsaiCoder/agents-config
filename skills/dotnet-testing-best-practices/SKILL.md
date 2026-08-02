---
name: dotnet-testing-best-practices
description: 'Use when writing, running, or reviewing .NET tests — xUnit [Fact]/[Theory], fixtures, IAsyncLifetime, NUnit/MSTest layout, Moq/NSubstitute mocks, AutoFixture/Bogus data, FluentAssertions, WebApplicationFactory integration tests, Testcontainers for real DBs, `dotnet test` execution, code coverage, BenchmarkDotNet micro-benchmarks, or flaky test diagnosis. Apply even when user just says "add a test for X", "run the tests", "this test is flaky", "benchmark this method", or "we need integration tests".'
---

# .NET Testing Best Practices

xUnit v3 primary (NUnit alt). Compose Moq/NSubstitute, AutoFixture/Bogus, WebApplicationFactory, Testcontainers. Assert with the built-in `Assert` by default — FluentAssertions v8+ requires a paid licence for commercial use (v7 is the last permanently open-source line; pin `7.*`, or use AwesomeAssertions/Shouldly). Not for production code (`dotnet-core-best-practices` / `dotnet-framework-best-practices`) or E2E (Playwright). Cross-ref: `ef-core-best-practices`, `dapper-best-practices`. Detail in `references/code-patterns.md#rule-N`.

## 13 Golden Rules

1. **AAA layout, one logical assertion per test.**
2. **Name `Method_Scenario_ExpectedResult`.**
3. **`[Theory]` + `[InlineData]`/`[MemberData]`/`[ClassData]` over copy-paste.**
4. **Mock only what you don't own.** Strict mocks on own interfaces = red flag.
5. **Moq OR NSubstitute, not both.**
6. **AutoFixture for test data; Bogus for realistic fakes.** No hand-crafting irrelevant fields.
7. **`WebApplicationFactory<Program>` for integration** — boots full pipeline in-memory; catches routing/DI/middleware bugs. → `references/integration-testing.md`.
8. **Testcontainers for DB, not EF in-memory.** In-memory ignores constraints / SQL semantics.
9. **Isolate tests** — no shared mutable state, no order dependency. `IAsyncLifetime` per-test.
10. **Test observable behavior, not implementation.** Public API only.
11. **Keep tests fast.** Unit <10ms, integration <1s, E2E <10s. `IClassFixture<T>` for expensive shared context.
12. **Coverage guides, not goals.** Cover business rules, validation, errors; skip POCOs/DTOs/generated.
13. **A benchmark is a test whose assertion is a number.** Release mode, `[Benchmark(Baseline = true)]`, one variable at a time; too few iterations to finish the statistics = not evidence.

## Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | Tests interdependent (order / shared state) | 9 |
| Critical | Tests missing assertions | — |
| High | Strict mocks on own interfaces | 4 |
| High | DB tests on EF in-memory for behavior | 8 |
| High | Test names unclear (`Test1`) | 2 |
| Medium | Parameterized tests copy-pasted | 3 |
| Medium | Test data hand-crafted with irrelevant details | 6 |
| Medium | Implementation details tested | 10 |
| Low | Both Moq and NSubstitute in same project | 5 |
| Low | Trivial getters/DTOs tested for coverage | 12 |

## xUnit Reminders

- `[Fact]` one scenario; `[Theory]` parameterized.
- Constructor for per-test init; `IAsyncLifetime` for async setup/teardown — **v3: `IAsyncLifetime : IAsyncDisposable`, both members return `ValueTask`; v2: both return `Task`.**
- `IClassFixture<T>` / `ICollectionFixture<T>` only for expensive shared context (v3 adds `[assembly: AssemblyFixture(typeof(T))]`); mutable data per-test.
- Be explicit about parallelization. Disable parallel only for shared external resources, not to hide order bugs.
- `Assert.Throws<T>` / `Assert.ThrowsAsync<T>` for exceptions.

## Reference Navigation

- `references/code-patterns.md` — Rules 1–12 code, structure, AAA, speed
- `references/mocking-frameworks.md` — Moq, NSubstitute, HttpClient/ILogger, AutoFixture
- `references/integration-testing.md` — WebApplicationFactory, Testcontainers, DB, auth, Respawn, CI/CD
- `references/mstest.md` — MSTest 3.x/4.x, Assert, TestContext, DataRow
- `references/cli.md` — `dotnet test` CLI, filters, `--blame`, parallelism
- `references/benchmarks.md` — BenchmarkDotNet: baseline comparison, `[MemoryDiagnoser]`, reading variance and multimodal results

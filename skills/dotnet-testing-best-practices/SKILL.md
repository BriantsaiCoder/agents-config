---
name: dotnet-testing-best-practices
description: 'Use when writing, running, or reviewing .NET tests — xUnit [Fact]/[Theory], fixtures, IAsyncLifetime, NUnit/MSTest, Moq/NSubstitute mocks, AutoFixture/Bogus data, WebApplicationFactory integration tests, Testcontainers, code coverage, BenchmarkDotNet micro-benchmarks, or flaky test diagnosis. Apply even when user just says "add a test for X", "run the tests", "this test is flaky", "benchmark this method", or "we need integration tests".'
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
10. **Test observable behavior, not implementation.** Public API only. 生成測試時，將每個明示的 scenario、variant 與 qualifier 對應至精確命名的 public behavior，並回報 requirement → test evidence。
11. **Keep tests fast.** Unit <10ms, integration <1s, E2E <10s. `IClassFixture<T>` for expensive shared context.
12. **Coverage guides, not goals.** Cover business rules, validation, errors; skip POCOs/DTOs/generated.
13. **A benchmark is a test whose assertion is a number.** Release mode, `[Benchmark(Baseline = true)]`, one variable at a time; too few iterations to finish the statistics = not evidence.

## Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | Tests interdependent (order / shared state) | 9 |
| Critical | Tests missing assertions | — |
| Critical | **Assertion-free coverage touching** — a class calls every public member in declaration order but never asserts an observable contract. Distinct from one accidental omission: the tell is systematic surface coverage | 12 |
| Critical | **Self-referential assertion** — `Assert.Equal(dto.Name, dto.Name)` or another expression whose two sides are the same value | — |
| Critical | **Swallowed exception** — `try { Act(); } catch (Exception) { }` or a catch that only logs, so failure cannot fail the test. A deliberate no-throw test is valid when that is the named behavior | — |
| Critical | **Always-true assertions** — `Assert.True(true)`, `Assert.Equal(x, x)`, any condition that cannot fail | — |
| Critical | **Commented-out assertions** — the test still runs and still counts toward coverage | — |
| Critical | **Missing `await` on an async assertion** — `async Task` test calling `Assert.ThrowsAsync<T>(...)` without `await`. Silently passes even when the assertion would have failed | — |
| High | Strict mocks on own interfaces | 4 |
| High | DB tests on EF in-memory for behavior | 8 |
| High | Test names unclear (`Test1`) | 2 |
| High | **Broad exception acceptance** — `Assert.ThrowsAny<Exception>(...)`, `Record.Exception`, or `catch (Exception)` without an exact-type and relevant-details assertion when the contract requires a specific failure. `Record.Exception` remains valid for an explicit no-throw contract or when followed by those assertions | — |
| Medium | Parameterized tests copy-pasted | 3 |
| Medium | Test data hand-crafted with irrelevant details | 6 |
| Medium | Implementation details tested | 10 |
| Low | Both Moq and NSubstitute in same project | 5 |
| Low | Trivial getters/DTOs tested for coverage | 12 |
| Low | **Assertion message repeats the assertion** — `Assert.True(a == b, "a and b are not equal")` adds nothing; say what the business rule is | — |

Calibrate honestly: Critical/High is for false confidence and unreliability only. Two tests covering distinct boundaries (zero vs negative) are not duplicates — separate cases give clearer failure diagnostics.

## xUnit Version Traps

- `IAsyncLifetime` — **v3: `IAsyncLifetime : IAsyncDisposable`, both members return `ValueTask`; v2: both return `Task`.** Fixtures and parallelism → `references/code-patterns.md` / `references/cli.md`.
- xUnit `Assert.Throws<T>` / `Assert.ThrowsAsync<T>` require the exact exception type; use `ThrowsAny<T>` only when derived exceptions are part of the contract. Disable parallelism only for shared external resources, never to hide order bugs.

## Reference Navigation

- `references/code-patterns.md` — Rules 1–12 code, structure, AAA, speed
- `references/mocking-frameworks.md` — Moq, NSubstitute, HttpClient/ILogger, AutoFixture, finding what needs a seam
- `references/coverage-crap.md` — Rule 12 in numbers: CRAP formula, coverage collection, why a CI line threshold isn't this
- `references/integration-testing.md` — WebApplicationFactory, Testcontainers, DB, auth, Respawn, CI/CD
- `references/mstest.md` — MSTest 3.x/4.x, Assert, TestContext, DataRow
- `references/cli.md` — `dotnet test` CLI, filters, `--blame`, parallelism
- `references/benchmarks.md` — BenchmarkDotNet baselines, `[MemoryDiagnoser]`, variance

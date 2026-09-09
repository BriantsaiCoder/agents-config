---
name: dotnet-testing-best-practices
description: "Write, run, review, or diagnose .NET tests and benchmarks using the project’s existing framework and test infrastructure."
---

# .NET Testing Best Practices

Inspect the test project's framework/version, target framework, dependencies and conventions before changing tests. Reuse its runner, fixtures and assertion tools; add a dependency only for an actual unmet requirement. For production code use `dotnet-core-best-practices` / `dotnet-framework-best-practices`; browser E2E belongs to Playwright.

## Behavioral evidence

- Test observable contracts through the existing public or project-approved boundary. Map each explicit scenario, variant and qualifier to requirement → test evidence. Keep expected results independent of the implementation under test.
- Use one coherent scenario per test, enough assertions to establish its outcome, and a name that identifies behavior and boundary. Distinct zero/negative boundaries are not duplicates; parameterize only when it improves diagnostics.
- Check for false confidence: missing or commented-out assertions, systematic surface calls without a contract assertion, `Assert.True(true)`, self-comparisons, swallowed failures, or async assertions whose result is never awaited. An intentional no-throw test is valid when that is the named contract.
- Match the required exception type and relevant details. Broad `ThrowsAny<Exception>`, `Record.Exception`, or `catch (Exception)` is insufficient for a specific-failure contract; `Record.Exception` is valid for no-throw or with the needed follow-up assertions.
- Isolate mutable state and remove order dependencies. Share expensive context only with explicit ownership/reset; disable parallelism for unavoidable shared external resources, not to hide order bugs.
- Choose doubles for meaningful boundaries, not internal call choreography. Reuse simple data/builders and existing mocking tools; AutoFixture/Bogus are optional. A strict mock is a problem when it fixes implementation details rather than a required interaction.
- Integration tests must preserve the semantics under test: EF in-memory cannot prove relational constraints or provider SQL behavior. Use the real provider via existing test infrastructure (Testcontainers if appropriate); use WebApplicationFactory when HTTP routing/DI/middleware is the contract.
- Choose targeted tests and broader checks by affected behavior and risk. Measure slowness against the project's baseline and environment; use finite runner bounds, not universal per-test millisecond limits. Coverage guides investigation, not tests of trivial DTOs for a percentage.
- Rate findings by demonstrated false confidence, unreliability and business impact. Naming, helper style and tool preferences alone do not justify High/Critical severity.

## Version and tool traps

- xUnit `IAsyncLifetime`: **v3 extends `IAsyncDisposable`, both members return `ValueTask`; v2 members return `Task`.** Match the installed package, not the target framework alone.
- xUnit `Assert.Throws<T>` / `Assert.ThrowsAsync<T>` require the exact exception type; `ThrowsAny<T>` is for contracts intentionally allowing derived exceptions. Await asynchronous assertions.
- Prefer the project's existing assertion tool or built-in `Assert`. FluentAssertions v8+ requires a paid licence for commercial use; v7 is the last permanently open-source line. Verify licence/version before upgrading; do not add or pin a library merely to follow this skill. AwesomeAssertions/Shouldly are alternatives when a change is needed.
- BenchmarkDotNet measurements need Release mode, a recorded baseline, controlled variables, sufficient iterations and variance. A timing number without these is not performance evidence.

## Load references for the relevant branch

- [code-patterns.md](references/code-patterns.md): AAA, data-driven tests, fixtures and behavior assertions; examples are optional patterns, not dependency mandates.
- [mocking-frameworks.md](references/mocking-frameworks.md): existing Moq/NSubstitute, HttpClient/ILogger, data tools and seam diagnosis.
- [integration-testing.md](references/integration-testing.md): WebApplicationFactory, real DB/provider, auth and reset/CI setup.
- [mstest.md](references/mstest.md): installed MSTest 3.x/4.x APIs, TestContext and DataRow differences.
- [cli.md](references/cli.md): runner filters, blame and parallelism.
- [coverage-crap.md](references/coverage-crap.md): coverage collection and CRAP interpretation; thresholds do not replace behavior evidence.
- [benchmarks.md](references/benchmarks.md): BenchmarkDotNet baselines, memory and variance.

---
name: dotnet-test
version: 0.1.0
kind: cli
description: Run .NET tests using dotnet CLI. Use when task involves executing unit tests, generating code coverage reports, or running benchmarks.
inputs:
  target: [all, project, specific]
  configuration: [Debug, Release]
  coverage: ['true', 'false']
  project_path: string
contracts:
  success: 'Tests pass with zero failures; coverage data generated if requested'
  failure: 'Non-zero exit code, test failures, or coverage generation errors'
---

# .NET Test Router

This retained trigger routes routine test execution to the canonical testing skill while keeping the corpus's unique BenchmarkDotNet procedure.

## Route

- Unit/integration tests, filters, flaky-test diagnosis, coverage, TRX, `--blame`, xUnit/NUnit/MSTest patterns → **REQUIRED SUB-SKILL:** use `dotnet-testing-best-practices` and its [CLI](../dotnet-testing-best-practices/references/cli.md) / [integration](../dotnet-testing-best-practices/references/integration-testing.md) references.
- Micro-benchmark creation, execution, baseline comparison, allocations, outliers, variance, or multimodal results → follow [`references/run-benchmarks.md`](references/run-benchmarks.md).
- Build-only failures → use the repo's normal build workflow; this skill does not own compilation or static analysis.

Never assume a `./dotnet` directory, solution name, test framework, or benchmark project. Discover the nearest `.sln`, `.slnx`, or `.csproj` and reuse repository commands before running anything.

## Completion

- Preserve the exact command, working directory, configuration, exit code, and artifact path.
- A benchmark result is not evidence unless it ran in Release mode and includes enough iterations for BenchmarkDotNet to complete its statistical analysis.
- Report test/benchmark failures as failures; do not silently skip or replace the requested target.

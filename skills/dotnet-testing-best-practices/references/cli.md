# `dotnet test` CLI Cheat Sheet

Practical CLI usage for running, filtering, and debugging .NET tests. Filter property names vary slightly by framework (table at bottom).

## Build-First Workflow

```bash
# Build once, fail fast on compile errors
dotnet build -p:WarningLevel=0 /clp:ErrorsOnly --verbosity minimal

# Then run tests without rebuilding (much faster iteration)
dotnet test path/to/Tests.csproj --no-build --verbosity minimal
```

## Filtering

```bash
dotnet test --no-build --filter "Name~Create"                        # method contains
dotnet test --no-build --filter "ClassName=MyApp.Tests.OrderTests"   # class exact
dotnet test --no-build --filter "FullyQualifiedName~MyApp.Tests.Unit"
dotnet test --no-build --filter "Category=Integration"               # xUnit/NUnit trait
dotnet test --no-build --filter "Category!=Slow"                     # exclude
dotnet test --no-build --filter "ClassName=OrderTests&Name~Validate" # AND
dotnet test --no-build --filter "Name~Create|Name~Update"            # OR
dotnet test --no-build --list-tests                                   # discovery only
```

Operators: `=` exact, `!=` not equal, `~` contains, `!~` not contains, `&` AND, `|` OR.

| Property | xUnit | MSTest | NUnit |
|---|---|---|---|
| Method | `Name` | `Name` | `Name` |
| Class | `ClassName` | `ClassName` | `ClassName` |
| Category / Trait | `Category` | `TestCategory` | `Category` |

xUnit `ITestOutputHelper` output only shows at detailed verbosity: `dotnet test --no-build --logger "console;verbosity=detailed"`.

## Blame Mode (crash / hang diagnosis)

Use when the test host crashes, hangs, or CI fails mysteriously.

```bash
dotnet test --blame                                      # log order → Sequence.xml
dotnet test --blame-crash --blame-crash-dump-type mini   # crash dump (or full)
dotnet test --blame-hang --blame-hang-timeout 5m --blame-hang-dump-type mini

# Recommended combo for flaky CI
dotnet test --blame --blame-crash --blame-hang --blame-hang-timeout 5m \
  --logger trx --results-directory ./TestResults
```

Start with `mini` dumps (~5 MB, stack + modules); escalate to `full` only when insufficient. Analyse with `dotnet-dump analyze crash_dump.dmp`.

## Parallel Execution

Defaults: test projects run in parallel at solution level; xUnit runs classes in parallel by default, NUnit/MSTest do not.

```bash
dotnet test -p:MaxCpuCount=1           # limit parallel assemblies
dotnet test -p:TestTfmsInParallel=false # disable multi-TFM parallelism (.NET 9+)
```

xUnit knobs via `xunit.runner.json`: `{ "parallelizeTestCollections": true, "maxParallelThreads": 4 }`. Group dependent xUnit tests into a shared `[Collection]` with `[CollectionDefinition(..., DisableParallelization = true)]` so they run sequentially. Persistent config via `test.runsettings` → `dotnet test --settings test.runsettings`.

## Common Symptoms

- **Pass alone, fail in parallel** → shared state / race (Rule 9). Group via `[Collection]` + `DisableParallelization`, then fix isolation.
- **Random CI failures, no stack** → host crash. `--blame --blame-crash` + inspect `Sequence.xml` + dump.
- **Hangs indefinitely** → deadlock / sync-over-async. `--blame-hang --blame-hang-timeout 3m` + analyse dump.
- **High CI memory** → too many parallel workers. Lower `maxParallelThreads` or `-p:MaxCpuCount=2`.

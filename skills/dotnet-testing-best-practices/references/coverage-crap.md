# Coverage and CRAP — Rule 12 in numbers

Rule 12 says coverage guides, not goals. CRAP (Change Risk Anti-Patterns) is how you turn that into a number: it weights coverage by how much the method could hurt you if it were wrong.

## The formula

```
CRAP(m) = comp(m)² × (1 − cov(m))³ + comp(m)
```

`comp` = cyclomatic complexity of the method, `cov` = its line-coverage ratio (0.0–1.0).

| CRAP | Risk | Reading |
|---|---|---|
| < 5 | Low | Simple and well tested |
| 5 ≤ CRAP < 15 | Moderate | Acceptable for most code |
| 15 ≤ CRAP ≤ 30 | High | Needs more tests or simplification |
| > 30 | Critical | Refactor *and* cover |

Two anchors worth memorising: a method at 100% coverage scores exactly `comp` — that is its floor. A method at 0% coverage scores `comp² + comp`. The cubed coverage term is what makes CRAP useful: on a complex method, the first slice of coverage buys far more than the last.

## How much coverage would fix it

To reach CRAP < 15, coverage must satisfy the strict inequality:

```
cov > 1 − ((15 − comp) / comp²)^(1/3)
```

**This only has a solution when `comp < 15`.** At `comp ≥ 15` the floor (`comp` at 100% coverage) already meets or exceeds the threshold — no amount of testing gets that method below it. When reporting whole percentages, use `max(0, floor(bound × 100) + 1)`, including the strict-bound increment when the bound is already an integer. For `comp² + comp < 15` (integer complexity 1–3), 0% already meets this numeric threshold; report 0%, never a negative target, while still recommending tests for non-trivial behavior. Say so plainly: *"complexity 18 cannot reach CRAP < 15 through testing alone; extract sub-methods first."* Reporting a coverage target for such a method is worse than useless, because someone will go chase it.

## Counting complexity

Base 1 per method; +1 for each of `if`, `else if`, each `case`, `for`, `foreach`, `while`, `do…while`, each `catch`, `&&`, `||`, `??`, `?.`, `? :`, and each pattern-match arm.

Compute it from the current source. A `// complexity: 7` comment left by a previous author is not evidence.

## Getting real coverage

| Package | Command | Output |
|---|---|---|
| `coverlet.collector` | `dotnet test --collect:"XPlat Code Coverage" --results-directory ./TestResults` | `TestResults/**/coverage.cobertura.xml` — search recursively, the GUID directory is not stable |
| `Microsoft.Testing.Extensions.CodeCoverage` (.NET 9 SDK or earlier) | `dotnet test -- --coverage --coverage-output-format cobertura --coverage-output ./TestResults/coverage.cobertura.xml` | Requires `TestingPlatformDotnetTestSupport`; `--coverage-output` is a file path |
| same (.NET 10+) | `dotnet test --coverage --coverage-output-format cobertura --coverage-output ./TestResults/coverage.cobertura.xml` | Requires Microsoft.Testing.Platform selected in `global.json` |

### Never estimate coverage

A guessed coverage figure produces a wrong CRAP score, and it is wrong in the direction that matters — it under-reports risk on exactly the methods this metric exists to find. If the first command produces no Cobertura XML, work down this list without changing the project or machine by default:

1. Check which provider the test project already references and use that provider's command above.
2. Probe an existing repo-local tool manifest (`dotnet tool list --local`) and `dotnet-coverage` on `PATH`. If neither exists, report the blocker and request authorization before adding a package or tool; prefer a repo-local manifest over a global install.
3. If `dotnet-coverage` is already available, collect out of process with `dotnet-coverage collect -f cobertura -o coverage.cobertura.xml "dotnet test <test.csproj>"`.
4. If an existing run produced only binary `.coverage`, convert it with `dotnet-coverage merge -o coverage.cobertura.xml -f cobertura <input.coverage>`.
5. Tests fail but ran → coverage from the tests that executed is still real. Continue with it and say which tests failed.

If every path fails: report that coverage could not be collected, show the commands and their errors, and stop. Report complexity alone if it helps. Never publish a CRAP number derived from an assumed percentage.

## Reading the Cobertura XML

Take each `<method>`'s `line-rate` under `<class>/<methods>`. Where method-level `line-rate` is absent, compute `hit lines / total lines` from that method's `<lines>` elements.

Compiler-generated names will not match source for async methods, lambdas, and local functions — **match by line range** when names do not align. Exclude `*.g.cs` / `*.Designer.cs` unless asked.

## Reporting

Sorted highest-CRAP first, with complexity, coverage, score, and risk band per method. Then three things the raw table does not give:

- **Summary** — methods analysed, count per risk band.
- **Top offenders** — CRAP > 30, each with a specific recommendation (which branches are uncovered, or which nested block to extract).
- **Quick wins** — high complexity where a small coverage increase drops the score a lot. This is where the cubed term pays.

Spot-check one method by hand against the formula before publishing, and confirm a 100%-covered method scores exactly its complexity. If it does not, the coverage parse is wrong.

## A CI line-coverage threshold is not this

A gate like `/p:Threshold=25 /p:ThresholdType=line` is satisfied by testing the easy half of the codebase. It cannot distinguish a fully covered DTO from an uncovered 12-branch decision method, and CRAP exists precisely because that distinction is the whole risk. Passing the threshold is not evidence that the risky methods are covered — run the numbers on the methods that carry the business rules.

## Primary sources

Last verified: 2026-08-05.

- Alberto Savoia's original [CRAP formula](https://www.artima.com/weblogs/viewpost.jsp?thread=215899). The risk bands above are this skill's triage policy, not thresholds claimed by that source.
- Microsoft Learn: [Microsoft.Testing.Platform code coverage](https://learn.microsoft.com/en-us/dotnet/core/testing/microsoft-testing-platform-code-coverage).
- Microsoft Learn: [`dotnet-coverage` collection and merge](https://learn.microsoft.com/en-us/dotnet/core/additional-tools/dotnet-coverage).

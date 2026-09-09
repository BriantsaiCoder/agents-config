---
name: test-gap-analysis
description: "Statically assess whether tests catch plausible code mutations when test effectiveness or missed cases are questioned; empirical mutation runs require explicit authorization."
license: MIT
---

# Test Gap Analysis via Pseudo-Mutation

A normal analysis is read-only static reasoning about whether existing tests would catch plausible production changes. Line/branch coverage shows execution, not assertion strength. Even empirical mutation scores cover only the sampled mutations; they do not prove absence of defects.

Writing tests belongs to `tdd` or the stack's testing skill. Test smells (flakiness, naming, vacuous assertions) belong to that testing skill; use them here only to judge whether a candidate could be caught. Requests to run mutation frameworks such as Stryker or mutmut belong to those tools, not this static workflow.

## 1. Establish scope and evidence

Read the requested production code and corresponding tests. Identify the installed language/framework version, discovery markers, assertion APIs and setup/teardown conventions. For .NET, read [dotnet.md](references/dotnet.md), including exact exception types and awaited TUnit assertions. For other languages, derive these from the test project.

Map each production behavior to tests by tracing public callers, private helpers, fixtures and shared examples. Mere execution is not evidence of a catch: the test needs an independent expected result that changes under the mutation. Missing, tautological, self-derived or unawaited assertions cannot establish that result.

## 2. Select and evaluate mutations

Inspect nontrivial boundaries, boolean logic, return values, error propagation, arithmetic and null handling. Read [mutation-catalog.md](references/mutation-catalog.md) when choosing concrete changes or mapping them to a language. Skip generated code, generated migrations, trivial getters and boilerplate. Do not skip handwritten migration or other risky logic solely because of its filename.

For each candidate, record the original location/code, hypothetical change, covering tests and the assertion that would detect it. Trace caller guards before declaring a gap. Exclude **Equivalent** changes that cannot alter reachable behavior; C#/TypeScript non-null assertions are compile-time-only, unlike runtime Swift/Kotlin/Rust unwraps. Go bare error passthroughs alone need no extra mutation; wrapping, logging or branching on the error may matter.

| Static label | Evidence required |
|---|---|
| **Predicted killed** | Identify the relevant assertion and explain why it would fail. |
| **Survivor candidate (unverified)** | Explain why traced assertions may miss the change; do not claim a verified gap. |
| **No-coverage candidate (unverified)** | No test path found within the stated scope; record discovery limits. |
| **Equivalent** | Explain why reachable observable behavior is unchanged. |

Static mode reports unverified candidate counts without percentages or a mutation score. An uncertain call graph or oracle lowers confidence; it does not establish survival.

## 3. Optional empirical confirmation

Static analysis is the default. When the user explicitly authorizes empirical confirmation, load [empirical-confirmation.md](references/empirical-confirmation.md) for isolation, bounded green baseline, calibrated timeouts, per-mutant execution, cleanup/hash proof, and mode-correct reporting. Without that authorization or required execution capability, retain static labels and do not report a mutation score.


## 4. Calibrate and report

Use risk and observable behavior to prioritize, not mutation count. Account for redundant defensive checks and domain constraints. Combine candidates sharing one missing scenario into one test recommendation. When substantive mutations are caught, lead with that strength; do not inflate severity or demand 100% kills for low-risk code.

Report scope, mode and limitations, then findings with file/method/line, original code, mutation category/change, covering tests, missing assertion and concrete recommended test. Include no-coverage areas and strengths using mode-correct labels. If execution catches a predicted survivor, remove it as a gap.

Executed outcomes and mutation scores require the full evidence contract in [empirical-confirmation.md](references/empirical-confirmation.md); static reasoning never certifies Killed/Survived or verified No coverage.

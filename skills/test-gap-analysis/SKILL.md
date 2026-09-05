---
name: test-gap-analysis
description: "Performs static pseudo-mutation analysis on production code in any language to find gaps in existing tests. Use when the user asks to find weak or shallow tests, discover untested edge cases, or check whether tests would catch a bug — e.g. \"would my tests catch it if someone changed the code\", \"would a subtle logic or boundary change slip past the current tests\", \"are my tests strong enough to catch a subtle bug\". Evaluates test effectiveness through mutation-style reasoning: analyzes mutation points (boundaries, boolean flips, null returns, exception removal, arithmetic changes) and checks whether tests would detect each. Polyglot: .NET, Python, TS/JS, Java, Go, Ruby, Rust, Swift, Kotlin, PowerShell, C++. DO NOT USE FOR: writing new tests (use tdd, or the stack's testing skill such as dotnet-testing-best-practices), auditing test quality — flakiness, naming, missing or tautological assertions (use the stack's testing skill), or running actual mutation testing tools (Stryker, mutmut, PIT, cargo-mutants)."
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

Static reasoning can produce false survivors. Enter empirical mode only with **explicit mutation authorization**; an analysis or review request alone is not authorization to edit production code.

1. **Isolate and fingerprint.** Create an isolated temporary copy or worktree from the target HEAD. Record the original production-file hashes and package manifest. Never mutate the user's active checkout.
2. **Establish a bounded green baseline.** Run the full affected test suite (`dotnet test <affected-project>`, `pytest <affected-suite>`, `npm test`, `go test ./...`, `cargo test`, …) inside that isolation and record the pass count and elapsed duration. Before each mutation, also time its exact narrow command while unmutated. Every empirical test command needs a finite runner/host timeout that can terminate the spawned test process tree; use an existing native mechanism and stay static if none is available. Set each mutant timeout from the corresponding unmutated duration: `duration × 2 + 30 seconds`, or a larger project-owned bound, and record the calculation. Missing timing evidence, a baseline timeout, or a baseline failure stops empirical work; do not repair project wiring as part of this analysis.
3. **Apply one candidate mutation** to the isolated production file.
4. **Triage narrowly, certify broadly.** Run the narrowest covering tests first under its calibrated narrow-command timeout. A relevant assertion failure kills the mutant; compile/setup failures remain unverified. On timeout, terminate and wait for the spawned test process tree, classify the mutant **TimedOut** (detected/killed), and continue directly to cleanup. If narrow tests stay green, run the full affected test project or suite under its separately calibrated full-suite timeout; only a fully green affected suite confirms **Survived**.
5. **Always undo and prove cleanup.** After green, red, error, or timeout, apply the inverse edit with the same editing tool, then require the production-file hashes to match the baseline before the next mutation. If process-tree termination or cleanup cannot be proven, stop and leave the isolation intact for recovery. Do **not** use `git stash`, `git stash -u`, `git checkout --`, or `git restore`; those can affect unrelated worktree state.
6. **Close the isolation.** Re-run the full affected suite, confirm the package manifest has no unexpected diff, and then remove the temporary copy/worktree.
7. **Report what ran.** State the affected-suite command and timeout, empirical killed/timed-out counts, mutation score, and cleanup/hash evidence.

Without authorization, isolation, a green baseline, or a runnable suite, stay in static mode: label each candidate **unverified (static reasoning)**, downgrade confidence, and do not publish a mutation score.

## 4. Calibrate and report

Use risk and observable behavior to prioritize, not mutation count. Account for redundant defensive checks and domain constraints. Combine candidates sharing one missing scenario into one test recommendation. When substantive mutations are caught, lead with that strength; do not inflate severity or demand 100% kills for low-risk code.

Report scope, mode and limitations, then findings with file/method/line, original code, mutation category/change, covering tests, missing assertion and concrete recommended test. Include no-coverage areas and strengths using mode-correct labels. If execution catches a predicted survivor, remove it as a gap.

Only executed evidence supports **Killed**, **TimedOut**, **Survived**, or verified **No coverage**. Killed requires a relevant test failure, not a compile/setup failure; errors without a meaningful verdict remain unverified. TimedOut requires calibrated timing and confirmed process-tree termination. Survived requires a green full affected suite while mutated. Claim No coverage only with execution evidence for that path, otherwise retain the static candidate label.

For a completed empirical run, report commands, pass counts, durations, timeout calculations, per-mutant outcomes and final restoration/hash evidence. Exclude equivalents and unresolved invalid/error outcomes from the score and disclose their counts; an incomplete run cannot certify all candidates.

`Mutation score = (Killed + TimedOut) / (Killed + TimedOut + Survived + No coverage)`

If that denominator is zero, report `Mutation score: N/A`; omit percentages and threshold judgments. Scores apply only to the evaluated sample and stated test scope.

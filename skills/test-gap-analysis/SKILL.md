---
name: test-gap-analysis
description: "Performs static pseudo-mutation analysis on production code in any language to find gaps in existing tests. Use when the user asks to find weak or shallow tests, discover untested edge cases, or check whether tests would catch a bug — e.g. \"would my tests catch it if someone changed the code\", \"would a subtle logic or boundary change slip past the current tests\", \"are my tests strong enough to catch a subtle bug\". Evaluates test effectiveness through mutation-style reasoning: analyzes mutation points (boundaries, boolean flips, null returns, exception removal, arithmetic changes) and checks whether tests would detect each. Polyglot: .NET, Python, TS/JS, Java, Go, Ruby, Rust, Swift, Kotlin, PowerShell, C++. DO NOT USE FOR: writing new tests (use tdd, or the stack's testing skill such as dotnet-testing-best-practices), auditing test quality — flakiness, naming, missing or tautological assertions (use the stack's testing skill), or running actual mutation testing tools (Stryker, mutmut, PIT, cargo-mutants)."
license: MIT
---

# Test Gap Analysis via Pseudo-Mutation

Analyze production code in any supported language by reasoning about hypothetical mutations. Empirical confirmation is an optional, separately authorized mode; a normal analysis request stays read-only.

> **Language-specific guidance**: for .NET, read `references/dotnet.md` — it names the test-discovery markers, per-framework assertion APIs, and setup/teardown attributes the mutation catalog below assumes. For other languages, derive the same three things from the codebase itself; the catalog is language-neutral.

## Why Pseudo-Mutation Matters

Code coverage tells you what code ran during tests. It does **not** tell you whether tests would fail if that code were wrong. A method can have 100% line coverage but zero tests that would catch a sign flip, an off-by-one error, or a removed null check.

Pseudo-mutation analysis asks: _"If I changed this line, would any test fail?"_ When the answer is "no," you've found a test gap.

| Coverage Metric | What It Measures | What It Misses |
|----------------|-----------------|----------------|
| Line coverage | Which lines executed | Whether assertions verify those lines' behavior |
| Branch coverage | Which branches taken | Whether both branches produce different asserted outcomes |
| **Mutation score** | Whether tests detect code changes | Nothing — this is the gold standard |

This skill uses **static pseudo-mutation** to find candidates at the speed of code review. With explicit mutation authorization, Step 4b can confirm candidates in an isolated temporary copy; otherwise the report remains static and labels its confidence honestly.

## When to Use

- User asks "would my tests catch a bug in this code?"
- User wants to find weak or shallow tests
- User wants to evaluate test effectiveness beyond coverage
- User asks for static or pseudo-mutation analysis
- User asks "where are my tests blind?"
- User wants to prioritize which tests to strengthen

## When Not to Use

- User wants to write new tests from scratch (use `tdd`, or the stack's testing skill — `dotnet-testing-best-practices`, `jest-best-practices`, `vitest`, `testing-library-react-best-practices`)
- User wants to detect test anti-patterns like flakiness, poor naming, or assertions that verify nothing (use the stack's testing skill — for .NET, `dotnet-testing-best-practices` carries the Severity Checklist)
- User wants to run an actual mutation testing framework (Stryker for .NET/JS/TS, mutmut for Python, PIT for Java, go-mutesting for Go, cargo-mutants for Rust, mutant for Ruby) — help them directly with the tool
- User only wants code coverage numbers (out of scope)

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| Production code | Yes | The source files to analyze for mutation points |
| Test code | Yes | The test files that cover the production code |
| Focus area | No | A specific mutation category or code region to focus on |

## Workflow

### Step 1: Detect language and load the reference

Identify the target codebase's language and test framework. For .NET, read `references/dotnet.md`. The mutation catalog below uses language-neutral concepts; the reference tells you how each concept maps in the language you are analyzing (e.g., `null` vs `None` vs `nil` vs `undefined`, `throw` vs `raise` vs `panic!` vs `return err`). For a language with no reference file here, read the test project itself to establish the same three things — how test files are marked, which assertion API is in use, and where setup/teardown lives — before applying the catalog.

### Step 2: Gather production and test code

Read both the production code and its corresponding test files. If the user points to a directory, identify production/test pairs by convention — defaults differ by language: `.cs` ↔ `*Tests.cs`/`*.Tests.cs` (.NET), `foo.py` ↔ `test_foo.py`/`foo_test.py` (Python), `foo.ts` ↔ `foo.test.ts`/`foo.spec.ts` (JS/TS), `Foo.java` ↔ `FooTest.java`/`FooTests.java` (Java), `foo.go` ↔ `foo_test.go` (Go), `foo.rb` ↔ `foo_spec.rb`/`test_foo.rb` (Ruby), `lib.rs` ↔ inline `#[cfg(test)] mod tests` or `tests/foo.rs` (Rust), `Foo.swift` ↔ `FooTests.swift` (Swift), `Foo.kt` ↔ `FooTest.kt`/`FooSpec.kt` (Kotlin), `Foo.ps1` ↔ `Foo.Tests.ps1` (Pester), `foo.cpp` ↔ `foo_test.cpp`/`test_foo.cpp` (C++).

Establish which production methods are exercised by which test methods — trace this through method calls in test code, setup, helper methods, and shared examples.

### Step 3: Identify mutation points

Scan the production code and annotate every location where a mutation could reveal a test gap. Use the mutation catalog below.

#### Boundary Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `<` | `<=` | Off-by-one at upper bound |
| `>` | `>=` | Off-by-one at lower bound |
| `<=` | `<` | Boundary inclusion |
| `>=` | `>` | Boundary inclusion |
| `== 0` | `== 1` or `<= 0` | Zero-boundary handling |
| `i < length` | `i < length - 1` or `i <= length` | Loop boundary |
| `index + 1` | `index` or `index + 2` | Index arithmetic |

#### Boolean and Logic Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `&&` | `\|\|` | Condition independence |
| `\|\|` | `&&` | Condition necessity |
| `!condition` | `condition` | Negation correctness |
| `if (x)` | `if (!x)` | Branch selection |
| `true` (constant) | `false` | Hardcoded assumption |
| `flag \|\| other` | `other` | Short-circuit first operand |

#### Return Value Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `return result` | `return null` / `return None` / `return nil` / `return undefined` | Null/None/nil handling downstream |
| `return result` | `return default(T)` / `return T()` / `return ""` / `return 0` | Default value handling |
| `return true` | `return false` | Boolean return verification |
| `return list` | `return new List<T>()` / `return []` / `return Array.Empty<T>()` / `return make([]T, 0)` / `return Vec::new()` / `return @[]` | Empty collection handling |
| `return count` | `return 0` or `return count + 1` | Numeric return verification |
| `return string` | `return ""` or `return null`/`None`/`nil` | String return verification |
| `return Ok(x)` | `return Err(...)` (Rust) | Result/error variant |
| `return value, nil` | `return zero, err` (Go) | Error tuple |

#### Exception / Error Removal Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `throw new ArgumentNullException(...)` (.NET) / `raise ValueError(...)` (Python) / `throw new Error(...)` (JS) / `throw new IllegalArgumentException(...)` (Java) / `panic!(...)` (Rust) / `panic(...)` (Go) / `raise ArgumentError` (Ruby) / `throw RuntimeException(...)` (Kotlin) / `throw FooError.bar` (Swift) / `throw "..."` (Pester) / `throw std::invalid_argument(...)` (C++) | _(remove entire throw/raise/panic)_ | Guard clause verification |
| `if (x == null) throw ...` / `if x is None: raise ...` / `if (!x) throw ...` / `if x == nil { return err }` (Go) / `assert!(x.is_some())` (Rust) | _(remove entire guard)_ | Null/None/nil guard testing |
| `if (!IsValid()) throw ...` / `if not is_valid(): raise ...` / etc. | _(remove entire check)_ | Validation testing |
| `return err` after error check (Go) | _(remove or swallow error)_ | Error propagation |
| `?` operator (Rust) | `.unwrap()` or `.expect(...)` | Error short-circuit |

#### Arithmetic Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `a + b` | `a - b` | Addition correctness |
| `a - b` | `a + b` | Subtraction correctness |
| `a * b` | `a / b` | Multiplication correctness |
| `a / b` | `a * b` | Division correctness |
| `a % b` | `a / b` | Modulo correctness |
| `x++` | `x--` | Increment direction |
| `-value` | `value` | Sign flip |

#### Null / None / Nil-Check Removal Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `if (x == null) return ...` / `if x is None: return ...` / `if (!x) return ...` / `if x == nil { return ... }` / `unless x; return; end` (Ruby) / `if x.is_none() { return ... }` (Rust) | _(remove null/None/nil check)_ | Null path coverage |
| `if (x != null) { ... }` / `if x is not None: ...` / `if x: ...` / `if x != nil { ... }` / `x?.let { ... }` (Kotlin) / `if let Some(x) = ... { ... }` (Rust) | _(always enter block)_ | Null/None/nil guard necessity |
| `x ?? defaultValue` (.NET/JS/Swift) / `x or defaultValue` (Python) / `x \|\| defaultValue` (JS) / `x.unwrap_or(defaultValue)` (Rust) / `x \|\| defaultValue` (Kotlin: `x ?: defaultValue`) | `x` (drop coalescing) | Null coalescing coverage |
| `x?.Method()` (.NET/Swift/Kotlin) / `x && x.method()` (JS) / `x and x.method()` (Python) | `x.Method()` | Null-conditional coverage |
| `x!` (Swift) / `x!!` (Kotlin) / `.unwrap()` (Rust) | `x` | Runtime force-unwrap necessity; C# and TypeScript `!` are compile-time-only and therefore equivalent mutants |

### Step 4: Evaluate each mutation against tests

For each identified mutation point, reason about whether existing tests would detect the change:

1. **Find covering tests** — Which test methods exercise the mutated line? Follow call chains through helpers and setup methods.
2. **Check assertion relevance** — Do those tests assert something that would change if the mutation were applied? A test that calls the method but only asserts an unrelated property would NOT catch the mutation.
3. **Classify the mutation** as:

| Verdict | Meaning | Action |
|---------|---------|--------|
| **Killed** | At least one test would fail if this mutation were applied | No action needed — tests are effective here |
| **TimedOut** | The mutated test command exceeded its finite timeout and its process tree was terminated | Count as detected/killed; the mutation introduced non-termination or pathological delay |
| **Survived** | No test would fail — the mutation would go undetected | This is a test gap — recommend a test improvement |
| **No coverage** | No test exercises this code path at all | Worse than survived — the code is untested |
| **Equivalent** | The mutation produces identical behavior (e.g., `x * 1` → `x / 1`) | Skip — not a real mutation |

Until Step 4b completes, **Killed** and **Survived** are provisional static classifications. A read-only run reports them as predicted kills and survivor candidates; it does not publish an empirical mutation score.

### Step 4b: Verify every reported survivor by running the tests

Static reasoning can produce false survivors. Enter empirical mode only with **explicit mutation authorization**; an analysis or review request alone is not authorization to edit production code.

1. **Isolate and fingerprint.** Create an isolated temporary copy or worktree from the target HEAD. Record the original production-file hashes and package manifest. Never mutate the user's active checkout.
2. **Establish a bounded green baseline.** Run the full affected test suite (`dotnet test <affected-project>`, `pytest <affected-suite>`, `npm test`, `go test ./...`, `cargo test`, …) inside that isolation and record the pass count and elapsed duration. Before each mutation, also time its exact narrow command while unmutated. Every empirical test command needs a finite runner/host timeout that can terminate the spawned test process tree; use an existing native mechanism and stay static if none is available. Set each mutant timeout from the corresponding unmutated duration: `duration × 2 + 30 seconds`, or a larger project-owned bound, and record the calculation. Missing timing evidence, a baseline timeout, or a baseline failure stops empirical work; do not repair project wiring as part of this analysis.
3. **Apply one candidate mutation** to the isolated production file.
4. **Triage narrowly, certify broadly.** Run the narrowest covering tests first under its calibrated narrow-command timeout. A red result kills the mutant. On timeout, terminate and wait for the spawned test process tree, classify the mutant **TimedOut** (detected/killed), and continue directly to cleanup. If narrow tests stay green, run the full affected test project or suite under its separately calibrated full-suite timeout; only a fully green affected suite confirms **Survived**.
5. **Always undo and prove cleanup.** After green, red, error, or timeout, apply the inverse edit with the same editing tool, then require the production-file hashes to match the baseline before the next mutation. If process-tree termination or cleanup cannot be proven, stop and leave the isolation intact for recovery. Do **not** use `git stash`, `git stash -u`, `git checkout --`, or `git restore`; those can affect unrelated worktree state.
6. **Close the isolation.** Re-run the full affected suite, confirm the package manifest has no unexpected diff, and then remove the temporary copy/worktree.
7. **Report what ran.** State the affected-suite command and timeout, empirical killed/timed-out counts, mutation score, and cleanup/hash evidence.

Without authorization, isolation, a green baseline, or a runnable suite, stay in static mode: label each candidate **unverified (static reasoning)**, downgrade confidence, and do not publish a mutation score.

### Step 5: Calibrate findings

Before reporting, apply these calibration rules:

- **Don't flag trivial code.** Simple property getters (`return _name;`), auto-properties, and boilerplate don't need mutation analysis. Focus on logic, conditions, calculations, and error handling.
- **Consider defensive depth.** If a null guard has a survived mutation but the caller also checks for null, note the redundancy but rate it lower priority.
- **Equivalent mutations are not gaps.** If changing `>=` to `>` doesn't alter behavior because the `==` case is impossible given the domain, mark it Equivalent and skip.
- **Private methods reached through public API are valid targets.** Trace through the call chain — a private method called from a tested public method may still have survived mutations if the test doesn't assert the specific behavior affected.
- **Rate by risk, not count.** A single survived mutation in payment calculation logic is more important than five survived mutations in logging code.
- **When most mutations are killed, lead with that.** A strong suite with one or two minor survivors is a good result: say "the tests are strong" first and present the survivors as minor improvements. Do not attach "critical" / "HIGH RISK" framing to a suite that kills the substantive mutations.
- **Never claim a gap you did not verify.** If Step 4b confirmed the mutation is caught, it is not a finding. Prefer under-claiming: a missed gap costs the user far less than a false alarm that sends them writing redundant tests.

### Step 6: Report findings

Present the analysis in this structure:

1. **Summary** — Use the template for the mode that actually ran.

   Static mode reports unverified candidate counts without percentages or a mutation score:
   ```
   | Metric                  | Count |
   |-------------------------|-------|
   | Mutation candidates     | 42    |
   | Predicted killed        | 28    |
   | Survivor candidates     | 10    |
   | No-coverage candidates  | 2     |
   | Equivalent (skipped)    | 2     |
   ```

   Empirical mode may report verified verdicts and a mutation score. Equivalents stay outside the denominator:

   `Mutation score = (Killed + TimedOut) / (Killed + TimedOut + Survived + No coverage)`

   If that denominator is zero, report `Mutation score: N/A`; omit percentages and any threshold judgment.

   ```
   | Metric              | Value    |
   |---------------------|----------|
   | Mutation points      | 42       |
   | Killed               | 28 (70%) |
   | TimedOut             | 0 (0%)   |
   | Survived             | 10 (25%) |
   | No coverage          | 2 (5%)   |
   | Equivalent (skipped) | 2        |
   | Mutation score       | 70%      |
   ```

2. **Test Gaps** — In static mode label each item **Survivor candidate (unverified)**. Only empirical mode may label an item **Survived mutation**. For each item, report:
   - **Location**: File, method, line
   - **Mutation category**: Boundary / Boolean / Return value / Exception / Arithmetic / Null-check
   - **Original code**: The current code
   - **Hypothetical mutation**: What would change
   - **Why it survives**: Which tests cover this code and why their assertions miss it
   - **Recommended fix**: A concrete test assertion or new test case that would kill this mutation

   Group by priority: high-risk survived mutations first (business logic, calculations, security checks), lower-risk last (logging, formatting).

3. **No-Coverage Zones** — Code paths that no test reaches at all. These are worse than survived mutations.

4. **Strengths** — Static mode reports predicted catches; empirical mode reports killed mutations. Highlight effective assertions without presenting predictions as executed evidence.

5. **Recommendations** — Prioritized list:
   - Which survived mutations to address first (by risk)
   - Specific test methods to add or strengthen
   - Patterns the team can adopt to prevent future gaps (e.g., always test boundary values, always assert exception types)

## Validation

- [ ] Empirical mode had explicit mutation authorization and used an isolated temporary copy/worktree (or every candidate is labelled unverified static reasoning)
- [ ] The full affected test suite was green before and after; every empirical survivor also passed it while mutated
- [ ] Every empirical test command had a finite timeout; timed-out process trees were terminated before inverse-edit cleanup
- [ ] Each mutant timeout was calculated from the same command's unmutated duration (`duration × 2 + 30 seconds`, or a recorded larger project bound)
- [ ] Every applied mutation was inversely edited, original file hashes match, and the active checkout was never modified
- [ ] Every point uses mode-correct labels: predicted/candidate/unverified for static; Killed/Survived only for empirical
- [ ] Every survivor candidate or verified survivor includes the original code, the hypothetical change, and why tests miss it
- [ ] Every survivor candidate or verified survivor includes a concrete recommended fix (a test assertion or test case)
- [ ] Equivalent mutations are correctly identified and excluded from the score
- [ ] Mutation score uses `(Killed + TimedOut) / (Killed + TimedOut + Survived + No coverage)`
- [ ] A zero score denominator is reported as `N/A`, without percentages or threshold judgments
- [ ] Trivial code (simple getters, auto-properties) is excluded from analysis
- [ ] Findings are prioritized by risk, not just listed in source order
- [ ] Report includes strengths using predicted catches or verified kills according to mode
- [ ] Mutation categories are correctly labeled

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Reporting survivors you never ran | In static mode call them candidates. In authorized empirical mode, require both narrow triage and the full affected suite before calling one Survived |
| Overstating severity on a strong suite | If the substantive mutations are killed, open with "tests are strong" and frame the remainder as minor improvements |
| Publishing your reasoning as it changes | Settle the verdict first; never emit "wait, no… this is killed… let me recalibrate" in the report |
| Leaving a mutation applied | Mutate only an isolated temporary copy/worktree, inverse-edit each change, and verify the original file hash before continuing |
| Analyzing trivial code | Skip auto-properties, simple getters, `@dataclass`/`record`/`data class` accessors, `#[derive]` impls — focus on logic |
| Reporting equivalent mutations as gaps | If the mutation doesn't change behavior, it's not a gap — mark Equivalent |
| Ignoring call chains | A private/internal/unexported helper called from a tested public method is reachable — trace the chain |
| Over-counting mutations in generated code | Skip auto-generated code (`*.g.cs`, `*.designer.cs`, `*_pb.go`, `*.pb.dart`), designer files, migration files, generated mocks/stubs |
| Recommending a new test for every survived mutation | Multiple survived mutations in the same method often share a single missing test — recommend one test that kills several |
| Ignoring production context | A survived mutation in `ToString()` / `__repr__` / `toString()` formatting is less important than one in `CalculateTotal()` — prioritize by business risk |
| Claiming 100% kill rate is required | Some mutations in low-risk code are acceptable to leave — acknowledge this in the report |
| Not considering integration with other skills | If gaps are found, hand the missing tests to `tdd` or the stack's testing skill; that skill's own anti-pattern checklist audits the tests you already have |
| Forgetting Go's error idiom | Removing `if err != nil { return err }` is a valid mutation target only when the function actually does something else with `err` (e.g., wrap, log, branch). Bare passthroughs in idiomatic Go are not meaningful gaps. |
| Forgetting Rust's `?` operator | `?` propagates `Err`/`None` short-circuits. Mutating `expr?` → `expr.unwrap()` panics instead of returning — flag as Exception/Panic mutation when tests should observe the propagated error. |

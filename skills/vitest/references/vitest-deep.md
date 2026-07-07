# Vitest — Deep Dive (mocks, coverage, anti-patterns)

This file holds the longer-form patterns that the SKILL.md links to. Read when authoring or reviewing Vitest config / mocks / coverage in detail.

## Mock Strategy Decision Tree

| Situation | Approach |
|---|---|
| Module exports a function I want to control | `vi.mock('./module', () => ({ foo: vi.fn() }))` at top level |
| Need different mock per test | `vi.mocked(foo).mockImplementationOnce(...)` inside `it` |
| Spy on real implementation, verify it ran | `vi.spyOn(obj, 'method')` — keeps original behavior unless `.mockImplementation()` |
| Time / Date / `setTimeout` | `vi.useFakeTimers()` in `beforeEach`, `vi.useRealTimers()` in `afterEach` |
| `Math.random` / `crypto.randomUUID` | `vi.spyOn(Math, 'random').mockReturnValue(0.5)` or seed; never assert on real randomness |
| Network call | MSW (preferred) > `vi.mock('fetch')` — MSW survives integration tests |
| Module path resolution / static asset | Configure `resolve.alias` in `vitest.config.ts`, not per-test |

Always pair `vi.mock` with `vi.restoreAllMocks()` (or `clearMocks: true` in config) to avoid leaking between tests.

## Anti-Patterns

- **`beforeAll` setting up shared mutable state.** Tests run in unspecified order and may run in parallel — use `beforeEach` + fresh fixtures.
- **Asserting on console output.** Capture with `vi.spyOn(console, 'error')` only when the contract genuinely requires logging; otherwise it tests implementation, not behavior.
- **Snapshot testing UI components without serializer trimming.** Snapshots blow up with whitespace / inline-style noise. Prefer Testing Library queries + explicit assertions.
- **`expect(fn()).toThrow()` without a matcher argument.** Catches *any* throw including the test's own bugs. Always pass expected error class or message.
- **Using `vi.mock` inside `it` / `beforeEach`.** `vi.mock` is hoisted to top of file at parse time — runtime calls don't work as expected. Use `vi.doMock` for dynamic cases (and re-import the module after).
- **Type tests without `// @ts-expect-error`.** A type test that compiles by accident is a passing test that proves nothing. Use `expectTypeOf<X>().toBeNever()` style assertions.

## Coverage Guidance

- Default thresholds (`statements`, `branches`, `functions`, `lines` ≥ 80%) are a starting point, not a goal. Aim for **branch coverage** in critical paths (auth, payment, persistence).
- Exclude generated code, type-only files (`*.d.ts`), test utilities, and barrel files via `coverage.exclude`.
- Use `v8` provider (default in Vitest 3) for speed; switch to `istanbul` only if you need source-map–based reports for older toolchains.
- `coverage.thresholds.autoUpdate: true` is dangerous — it silently lowers thresholds when coverage drops. Don't enable.

## Type Testing — When To Use

Use `expectTypeOf` / `assertType` only when the contract is a *type* not a runtime value: generic constraints, conditional return types, branded types, discriminated unions. Don't write type tests for things runtime tests cover; they're slow to maintain and the typecheck error messages are awful.

## Review Checklist

- Tests are deterministic — no real time, no real network, no order dependency, no shared module state.
- `vi.mock`, `vi.spyOn`, fake timers, env mutations all restored after each test (or `clearMocks: true` in config).
- DOM tests use the right environment for what they're testing.
- Async tests `await` promises and UI updates (Testing Library's `findBy*` for re-renders).
- Coverage measures meaningful source — not generated output, not test utilities.
- Type-level tests use `expectTypeOf` / `assertType` only for contracts runtime can't express.

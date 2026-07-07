---
name: jest-best-practices
description: 'Use when configuring, reviewing, or debugging existing Jest suites — jest.config, babel/ts-jest, ESM/CJS mocking, jsdom, fake timers, snapshots, coverage, flaky Jest tests. Symptoms: ESM transform error, jest.mock not hoisting, mock leaks, timer leaks, snapshot drift, coverage gaps, ts-jest deprecation. Apply even when user says "jest config broken", "mock not working", "passes alone fails in suite". For RTL queries/userEvent, use testing-library-react-best-practices.'
---

# Jest Best Practices

Project-owned runner. Preserve existing stack unless user asks migration; fix at the failing boundary. Scope: runner / config / transforms / mocks / timers / snapshots / coverage / triage. RTL query/userEvent → `testing-library-react-best-practices`.

## Setup Triage

Read before changing:

- `package.json` scripts + Jest packages.
- `jest.config.*`, `babel.config.*`, `tsconfig*.json`, framework / CI config.
- `setupFiles` / `setupFilesAfterEnv`, custom env, resolver, transform, `moduleNameMapper`.
- Module system: CJS, Babel-transformed ESM, native ESM, mixed.

Use repo test script. Targeted first (`-t "name"`), full suite after.

## Decision Map

| Need | Prefer |
|---|---|
| Pure Node | `testEnvironment: "node"` |
| React/Vue DOM | `jsdom` + framework utils |
| RTL assertions | `testing-library-react-best-practices` |
| TS fast transpile | Babel/SWC + separate `tsc --noEmit` |
| TS diagnostics in Jest | `ts-jest` (slower) |
| CSS/assets/aliases | `moduleNameMapper` matching bundler/tsconfig |
| Missing jsdom APIs | Stable mocks in setup before importing |
| Network | MSW / boundary mocks, never live |

Babel TS does not prove types. Keep typecheck separate unless using `ts-jest` diagnostics.

## Mocking Pitfalls

Boundaries only — full → `references/jest-deep.md`. Jest-specific:

- **CJS / Babel:** `jest.mock()` hoisted above imports. Factory vars must be `mock`-prefixed or lazy.
- **Native ESM:** static imports run before mock setup. Use `@jest/globals` + `jest.unstable_mockModule()` + dynamic `import()`, not `jest.mock()`.
- **Manual mocks** in case-sensitive `__mocks__/`. Stale ones silently override.
- **Mock-then-import order:** mocking after importer captured real module = no-op.

## Config Guardrails

- `testEnvironment` narrow: `node` for logic, `jsdom` only when DOM needed.
- Custom matchers (`@testing-library/jest-dom`) in `setupFilesAfterEnv`.
- Aliases consistent with `tsconfig.paths` / bundler.
- Exclude generated, build, `*.d.ts`, utilities from coverage.
- Snapshot only stable, small outputs.

## Common Mistakes

- **Babel TS = typecheck.** No. Run `tsc --noEmit`.
- **Mocking after captured ref.** No-op.
- **`jest.mock()` in native ESM.** Use `unstable_mockModule` + dynamic.
- **Migrating to Vitest because config annoying.** Only if user asks.

Flake triage, full mocking, ESM example, validation → `references/jest-deep.md`.

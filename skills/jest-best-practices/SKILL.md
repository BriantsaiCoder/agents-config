---
name: jest-best-practices
description: "Configure, review, or debug the Jest runner, transforms, mocks, timers, snapshots, and coverage. React Testing Library queries use its own skill."
---

# Jest Best Practices

Project-owned runner. Preserve existing stack unless user asks migration; fix at the failing boundary. Scope: runner / config / transforms / mocks / timers / snapshots / coverage / triage. RTL query/userEvent → `testing-library-react-best-practices`.

## Setup Triage

Read before changing:

- `package.json` scripts + Jest packages.
- `jest.config.*`, `babel.config.*`, `tsconfig*.json`, framework / CI config.
- `setupFiles` / `setupFilesAfterEnv`, custom env, resolver, transform, `moduleNameMapper`.
- Module system: CJS, Babel-transformed ESM, native ESM, mixed.

Use repo test script. Targeted first (`-t "name"`); then run the relevant package/suite when scope or shared config warrants it, plus repo-required CI checks.

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
- Preserve the repo's coverage contract. Generated/build outputs and declarations without runtime behavior may be excluded; include handwritten utilities according to their observable behavior, not their directory name.
- Snapshot only stable, small outputs.

## Common Mistakes

- **Migrating to Vitest because config annoying.** Only if user asks.

Flake triage, full mocking, ESM example, validation → `references/jest-deep.md`.

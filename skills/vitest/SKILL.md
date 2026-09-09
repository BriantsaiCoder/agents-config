---
name: vitest
description: "Configure, review, or debug Vitest runner behavior, mocks, timers, coverage, and environments. Vite builds and plugins use vite."
---

# Vitest

> Vitest 4.x. Verify installed version — 3.x→4.x removed `coverage.all` / `coverage.extensions` and the third options arg on `test`/`describe`, and reshaped browser mode; 1.x→2.x→3.x changed mocks and projects (was `workspace`).

Vite-native runner. Looks like Jest, but value is *Vite-shared* config: same plugins / aliases / env. Pain comes from treating it as Jest. Scope: runner / config / mocking / timers / coverage / environments. RTL patterns → `testing-library-react-best-practices`; component architecture → React/Vue skill.

## Workflow

1. Read `package.json` test scripts, `vitest.config.*` / `vite.config.*` (`test` block), `setupFiles` / `globalSetup`, environment.
2. Narrowest test level:
   - Pure logic → no env, import + assert.
   - DOM / component → `jsdom` / `happy-dom`.
   - Real browser quirks → browser mode (Playwright / WebDriver).
   - Multi-module integration → integration project, not E2E.
   - Type-only contract → `expectTypeOf` / `assertType`.
3. Mock external boundaries only — network, clock, storage, fs, env, SDKs. Never mock unit under test.
4. Isolation: clean DOM, restore mocks, reset timers, no shared state.
5. Match project conventions (`expect` vs `assert`, fixtures, coverage).
6. Targeted first (`vitest run file.test.ts -t "pattern"`), broader only when shared.

## Environment Decision

| Need | Pick | Why |
|---|---|---|
| Functions, no DOM | `node` | Fastest |
| Vue/React render | `jsdom` | Most compatible with RTL; slowest |
| Light DOM | `happy-dom` | ~2× faster; missing canvas / MO edges |
| Real browser APIs | browser mode | Heaviest; only when polyfill mismatches |

Per-file: `// @vitest-environment jsdom` top.

## Mocking, Coverage, Anti-Patterns

Mock tree / coverage / anti-patterns / type-testing / review → `references/vitest-deep.md`.

Jest gotchas:

- `vi.mock` hoisted at parse — calls inside `it`/`beforeEach` fail; use `vi.doMock` + dynamic re-import.
- `clearMocks: true` in config > scattering `vi.restoreAllMocks()`.
- Vite alias / plugins flow through — don't re-declare.
- Browser mode reshaped in 3.x and again in 4.0 — 4.0 takes `provider: playwright()` from `@vitest/browser-playwright` (string names gone) + `instances: [{ browser: 'chromium' }]`, and context imports moved from `@vitest/browser/context` to `vitest/browser`.

## Reference Map

- `references/vitest-deep.md` — mocking, coverage, anti-patterns, review
- `references/core-config.md`, `references/core-cli.md` — `vitest.config.ts`, projects, CLI
- `references/core-{test-api,describe,expect,hooks}.md` — `it`/`describe`/matchers/hooks
- `references/features-mocking.md`, `references/advanced-vi.md` — mocks, spies, timers
- `references/features-{coverage,snapshots,filtering}.md` — coverage, snapshots, filter
- `references/advanced-{environments,projects,type-testing}.md` — env, multi-project, types

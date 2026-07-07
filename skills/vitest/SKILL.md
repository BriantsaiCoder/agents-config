---
name: vitest
description: 'Use when configuring or debugging the Vitest runner: vitest.config, Vite-shared config, vi.mock/spyOn, mock reset issues, fake timers, coverage wrong, jsdom/happy-dom environment, projects, type testing, browser mode, slow or flaky tests. Apply even when user just says "tests are slow", "vi.mock not working", "fake timers leaking", "coverage report wrong", or asks why a Jest pattern misbehaves under Vitest.'
---

# Vitest

> Vitest 3.x. Verify installed version — 1.x→2.x→3.x had breaking changes in mocks, projects (was `workspace`), browser mode.

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
- Browser mode API changed in 3.x — verify version.

## Reference Map

- `references/vitest-deep.md` — mocking, coverage, anti-patterns, review
- `references/core-config.md`, `references/core-cli.md` — `vitest.config.ts`, projects, CLI
- `references/core-{test-api,describe,expect,hooks}.md` — `it`/`describe`/matchers/hooks
- `references/features-mocking.md`, `references/advanced-vi.md` — mocks, spies, timers
- `references/features-{coverage,snapshots,filtering}.md` — coverage, snapshots, filter
- `references/advanced-{environments,projects,type-testing}.md` — env, multi-project, types

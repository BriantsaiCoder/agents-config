---
name: frontend-release-verification
description: "Assess frontend release readiness when preparing deployment, selecting release gates, or verifying user journeys and rendered behavior."
---

# Frontend Release Verification

## Core Principle

Evidence matched to risk. Use repo's existing scripts and test stack first; never invent commands, add framework, or claim deploy-ready without concrete command + browser evidence.

## Workflow

1. Inspect repo: `package.json` scripts, lockfile, framework / test / E2E / CI config, `AGENTS.md`. Existing tools decide commands; skill decides minimum evidence.
2. Classify by highest-risk touched behavior:
   - Pure logic → lint/typecheck + targeted unit tests.
   - Component/form/UI state → component/integration + build + visual/RWD smoke.
   - Routing/auth/API/data mutation → browser smoke or E2E on changed path.
   - CSS/layout/design system → mobile + desktop visual + a11y smoke.
   - Dependency/build/env → full relevant test suite + build.
   - Auth/checkout/payment → E2E happy + error path + rollback note.
3. Run narrowest gate set that blocks bad release. Expand only when shared behavior / high-risk / config changed.
4. Required framework absent → report gap + closest lightweight verification. No scaffolding without user ask.

## Minimum Gate Map

| Gate | Evidence |
|---|---|
| Static | Existing `lint` + `typecheck`, or explain if combined |
| Unit/component | Vitest/Jest; target changed behavior |
| Build | Repo-configured build script |
| Browser/E2E | Playwright/Cypress / Playwright MCP / Browser Use |
| Visual/RWD | Screenshots / manual evidence per affected screen |
| A11y | axe/Lighthouse if present, else keyboard/focus/label/role/contrast smoke |

Use the package manager and clean-install command configured by the repo or CI. Local agent may skip install if deps are present and the lockfile is unchanged.

## Deployment Gates Beyond CI

MUST pass three — see `references/deployment-gates.md` for thresholds + config + skip rules.

1. **Bundle Size** — `size-limit` / `bundlewatch`; absolute cap + diff vs base.
2. **Lighthouse CI** — `@lhci/cli` on PR preview; LCP ≤ 2.5s, CLS ≤ 0.1, INP ≤ 200ms.
3. **Staging Smoke E2E** — Playwright `staging` project, critical-path subset, blocks prod on red.

Browser smoke acceptance (no blank, journey works, console clean, mobile + desktop) — same reference.

## Skill Routing

- `vitest` — runner config, mocks, coverage.
- `jest-best-practices` — existing Jest.
- `testing-library-react-best-practices` — Testing Library.
- `playwright-best-practices` — E2E, smoke, visual, a11y, traces, CI artifacts.
- `css-ui-best-practices` — a11y, responsive, layout, contrast, Core Web Vitals.
- `vite` / `react-best-practices` / `vue-best-practices` / `next-best-practices` / `nuxt` — framework.
- `dependency-security-scan` — secret/CVE/container scan.
- `backend-release-verification` — API counterpart.

## Completion Report

- Commands run + pass/fail.
- Browser journey, viewport evidence, console/page-error status.
- Skipped gates + reason.
- Test gaps / residual risk.
- Deploy-readiness judgment when asked.

## Common Mistakes

- Unit tests alone for user-facing release.
- Running commands from memory.
- Adding new framework without approval.
- Ignoring console/page errors.
- Visual/RWD clean without mobile + desktop evidence.
- Arbitrary sleeps in committed browser tests.

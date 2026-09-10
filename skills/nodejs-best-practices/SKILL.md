---
name: nodejs-best-practices
description: "Write, review, or test Node.js backend services, covering request handling, async behavior, validation, and integration boundaries."
---

# Node.js & Express Best Practices

Frontend-only components / Deno / Bun-exclusive runtimes out of scope.

## Mode

1. **Writing** — complete boundary validation, error handling, and necessary tests within authorized changes. Reuse installed libraries; new architecture/dependencies or external effects follow S2. Review-only work produces findings.
2. **Reviewing** — checklist. Priority: security (injection, auth) → correctness (errors, async) → tests → perf.

## Golden Rules

Rule explanations → `references/rules-expanded.md`; writing/reviewing workflow → `references/working-patterns.md`.

1. **Structure by feature, not technical role.**
2. **Propagate async errors.** Express 4 needs explicit rejection forwarding; Express 5 forwards returned Promise rejections. Never empty `catch {}`.
3. **Validate inputs at boundaries with the existing validator**; Zod/Joi are options when already selected.
4. **Env config validated at startup.**
5. **TS strict; `unknown` not `any`.**
6. **Express error middleware: 4 params `(err, req, res, next)`.**
7. **Never block event loop.** No sync I/O / CPU loops on request paths.
8. **Connection pooling + parameterized queries.**
9. **Structured logging with the repo logger** and existing correlation mechanism; use `AsyncLocalStorage` when context propagation requires it.
10. **Test at right level.** Unit pure logic; `supertest` for HTTP without port; testcontainers for real DBs.
11. **Lockfiles committed, `npm ci` in CI, audit dependencies.**
12. **Multi-stage Docker, non-root, signal handling.**

## Backend Testing Rules

1. Read test scripts, runner config, setup files, app factory, testcontainer availability.
2. Narrowest layer proving behavior: unit / route-service-DB / contract / smoke.
3. Real migrations + isolated state for DB integration.
4. Block unmocked outbound HTTP; clean mocks between tests.
5. Mock only third-party SaaS / time / randomness / expensive fs.
6. Targeted first, broaden only when shared infra changes.

## Skill Routing

- `vitest` — Vitest config, `vi.mock`, timers, coverage, projects, browser mode.
- `jest-best-practices` — Jest config, ts-jest, ESM mocking, timers, snapshots.
- `testing-library-react-best-practices` — RTL queries.
- `backend-release-verification` — release gate.

## Reference Map

- `references/rules-expanded.md` — rule explanations
- `references/project-structure-errors.md` — feature folders, custom errors
- `references/security-validation.md` — Zod/Joi, env validation, secrets
- `references/api-design.md` — middleware order, TS setup, Pino + AsyncLocalStorage
- `references/performance-async.md` — event loop, `worker_threads`, streaming, DB pools
- `references/testing.md` — unit + integration, `supertest`
- `references/backend-testing-patterns.md` — testcontainers, nock, fixtures, coverage, CI
- `references/deployment-docker.md` — multi-stage Dockerfile, lockfile + audit
- `references/working-patterns.md` — writing/reviewing workflow

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.

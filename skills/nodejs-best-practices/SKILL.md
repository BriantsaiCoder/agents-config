---
name: nodejs-best-practices
description: 'Use when writing, reviewing, or testing Node.js JS/TS backend server code — Express/Fastify/Koa/NestJS/Hono routes/middleware, req/res, ESM/CJS interop, tsconfig, request validation, auth, DB clients, background jobs, async error propagation, supertest, testcontainers, nock, API review, API tests, scaffold Express API, unhandled-rejecting, wire up middleware, mock outbound call.'
---

# Node.js & Express Best Practices

Frontend-only components / Deno / Bun-exclusive runtimes out of scope.

## Mode

1. **Writing** — apply rules proactively. Don't ask before validation / error handling / tests.
2. **Reviewing** — checklist. Priority: security (injection, auth) → correctness (errors, async) → tests → perf.

## Golden Rules

Rule explanations → `references/rules-expanded.md`; writing/reviewing workflow → `references/working-patterns.md`.

1. **Structure by feature, not technical role.**
2. **Propagate async errors.** Express 4 needs explicit rejection forwarding; Express 5 forwards returned Promise rejections. Never empty `catch {}`.
3. **Validate inputs at boundary** (Zod / Joi).
4. **Env config validated at startup.**
5. **TS strict; `unknown` not `any`.**
6. **Express error middleware: 4 params `(err, req, res, next)`.**
7. **Never block event loop.** No sync I/O / CPU loops on request paths.
8. **Connection pooling + parameterized queries.**
9. **Structured logging (Pino) + correlation IDs via `AsyncLocalStorage`.**
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

Open one at a time.

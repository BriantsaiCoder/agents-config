# Node.js Working Patterns & Critical Snippets

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Critical Patterns — Always Include

These four patterns are the ones most commonly missed in generated code. Add them by default to every
Express project, even demos. They are condensed here as one-liners so you can copy-paste the shape; full
examples and edge cases live in the references listed.

1. **Version-aware async errors** — use the [Express error propagation rules](api-design.md#the-async-handler-wrapper). Add or reuse explicit rejection forwarding on Express 4; do not require a wrapper for returned Promises on Express 5.

2. **Security middleware order** — `app.use(helmet()); app.use(cors()); app.use(express.json({ limit: '1mb' }));`
   helmet first, body-size limit mandatory.
   *(Rule 6. See `references/security-validation.md`.)*

3. **Parameterised queries only** — `pool.query('SELECT * FROM users WHERE id = $1', [id])`. Never
   string-interpolate into SQL. Applies to raw drivers (`pg`, `mysql2`), query builders (`knex`), and
   ORMs — always use their parameter binding API.
   *(Rule 8. See `references/performance-async.md`.)*

4. **Environment config validated at startup with the existing validator** — validate required env
   vars once at boot and export typed `config`. When Zod is already selected, a `z.object({...})`
   schema and `envSchema.parse(process.env)` are one example; do not add Zod to follow it.
   Never read `process.env.X` in business logic.
   *(Rule 4. See `references/security-validation.md`.)*

---

## Working pattern for *writing* new Node.js code

1. Confirm the runtime and framework (Express, Fastify, plain `http`). Check Node version and ESM vs CommonJS.
2. Set up TypeScript strict mode if not already configured.
3. **Add `helmet()`, `cors()`, and `express.json({ limit: '1mb' })` to app setup** — these are non-negotiable.
4. Create or locate the feature directory. Add route, service, and validation files; keep services pure where possible, without Express types.
5. Define the input validation contract with the existing validator; Zod/Joi examples apply only when already selected.
6. **Validate environment config at startup with the existing validator** (Critical Pattern 4); `config = envSchema.parse(process.env)` applies when Zod is selected. Never access `process.env` directly elsewhere.
7. Implement the handler with async/await and the version-aware propagation from Critical Pattern 1. Do not swallow errors.
8. Add error handling — custom `AppError` for expected errors, let unexpected ones propagate to the four-parameter error middleware registered after routes.
9. Use **parameterized queries** (`$1`, `?`) for any database access. Get connections from a **pool** (`pg.Pool`), never `new Client()` per request. Use explicit transactions for multi-statement writes.
10. Add structured logging at key decision points (not every line), with request IDs propagated through `AsyncLocalStorage`.
11. Write integration tests with `supertest` for the happy path and key error paths.

## Working pattern for *reviewing* Node.js code

Walk the file top-to-bottom and check, in this order:

1. **Security**: any string concatenation in SQL/FS/shell paths or commands? Missing input validation or `helmet()`? Secrets in code?
   Raw `req.body` passed to DB without validation? → Flag with severity HIGH.
2. **Error handling**: empty `catch {}`? `catch (e) { console.log(e) }` without re-throwing or returning error
   response? Missing rejection forwarding for the installed Express version or detached async work? Error middleware with wrong arity (3 params instead of 4), or registered before routes? Missing operational vs programmer error classification?
3. **Event loop safety**: sync `fs` / `crypto` on request path? CPU-heavy loop or heavy regex? Large JSON.parse without
   size limit? Missing request body size limit (`express.json({ limit: '1mb' })`)?
4. **Async hygiene**: `.then().catch()` mixed with `async/await`? Missing `await`? Fire-and-forget promises
   without explicit intent? Unhandled rejections in `setInterval` / `setImmediate`? Callback-style code that should be promisified?
5. **Database**: `new Client()` per request instead of pool? Missing connection release? N+1 queries in a loop? Missing transactions on multi-step writes?
6. **Config**: hardcoded URLs, ports, secrets? `process.env.X` accessed deep in business logic instead of
   validated config object?
7. **Dependencies**: `node_modules` in git? Missing lockfile? Known vulnerable packages?
8. **Docker/deployment**: running as root? Single-stage image with dev dependencies? Missing `.dockerignore`? `npm install` instead of `npm ci`? Missing health check or signal handling (`dumb-init` / `--init`)?
9. **Logging/tests**: Production `console.log` instead of structured logging? PII in logs or missing request IDs? Over-mocked internals or missing route-level integration tests?

Report findings grouped by severity (security > correctness > performance > style), each with a concrete fix.

---

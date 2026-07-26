# Node.js Working Patterns & Critical Snippets

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Critical Patterns — Always Include

These four patterns are the ones most commonly missed in generated code. Add them by default to every
Express project, even demos. They are condensed here as one-liners so you can copy-paste the shape; full
examples and edge cases live in the references listed.

1. **`asyncHandler` wrapper — Express 4 only** — on Express 4, every `router.get/post/...` with an `async`
   handler must be wrapped so rejections reach the error middleware. Shape:
   `const asyncHandler = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);`
   **Express 5 forwards rejected promises to the error middleware natively — drop the wrapper there.**
   *(Rules 2 + 6. See `references/api-design.md`.)*

2. **Security middleware order** — `app.use(helmet()); app.use(cors()); app.use(express.json({ limit: '1mb' }));`
   helmet first, body-size limit mandatory.
   *(Rule 6. See `references/security-validation.md`.)*

3. **Parameterised queries only** — `pool.query('SELECT * FROM users WHERE id = $1', [id])`. Never
   string-interpolate into SQL. Applies to raw drivers (`pg`, `mysql2`), query builders (`knex`), and
   ORMs — always use their parameter binding API.
   *(Rule 8. See `references/performance-async.md`.)*

4. **Environment config validated with Zod at startup** — define a `z.object({...})` schema for every
   required env var, `envSchema.parse(process.env)` once at boot, export the resulting typed `config`.
   Never read `process.env.X` in business logic.
   *(Rule 4. See `references/security-validation.md`.)*

---

## Working pattern for *writing* new Node.js code

1. Confirm the runtime and framework (Express, Fastify, plain `http`). Check Node version and ESM vs CommonJS.
2. Set up TypeScript strict mode if not already configured.
3. **Add `helmet()`, `cors()`, and `express.json({ limit: '1mb' })` to app setup** — these are non-negotiable.
4. Create or locate the feature directory. Add route, service, and validation files.
5. Write input validation schema (Zod/Joi) first — this defines the contract.
6. **Validate environment config with Zod at startup** (`config = envSchema.parse(process.env)`) — never access `process.env` directly elsewhere.
7. Implement the route handler with async/await. **On Express 4, always wrap with `asyncHandler`** (Express 5 handles async rejections natively) — never use bare try/catch in route handlers.
8. Add error handling — custom `AppError` for expected errors, let unexpected ones propagate to error middleware.
9. Use **parameterized queries** (`$1`, `?`) for any database access. Get connections from a **pool** (`pg.Pool`), never `new Client()` per request.
10. Add structured logging at key decision points (not every line).
11. Write integration tests with `supertest` for the happy path and key error paths.

## Working pattern for *reviewing* Node.js code

Walk the file top-to-bottom and check, in this order:

1. **Security**: any string concatenation in SQL/shell commands? Missing input validation? Secrets in code?
   Raw `req.body` passed to DB without validation? → Flag with severity HIGH.
2. **Error handling**: empty `catch {}`? `catch (e) { console.log(e) }` without re-throwing or returning error
   response? Async handler without wrapper? Error middleware with wrong arity (3 params instead of 4)?
3. **Event loop safety**: sync `fs` / `crypto` on request path? CPU-heavy loop? Large JSON.parse without
   size limit? Missing request body size limit (`express.json({ limit: '1mb' })`)?
4. **Async hygiene**: `.then().catch()` mixed with `async/await`? Missing `await`? Fire-and-forget promises
   without explicit intent? Callback-style code that should be promisified?
5. **Database**: `new Client()` per request instead of pool? Missing connection release? N+1 queries in a loop?
6. **Config**: hardcoded URLs, ports, secrets? `process.env.X` accessed deep in business logic instead of
   validated config object?
7. **Dependencies**: `node_modules` in git? Missing lockfile? Known vulnerable packages?
8. **Docker/deployment**: running as root? Missing `.dockerignore`? `npm install` instead of `npm ci`?
   Missing health check endpoint?

Report findings grouped by severity (security > correctness > performance > style), each with a concrete fix.

---

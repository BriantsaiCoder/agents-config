# Node.js / Express Golden Rules — Expanded

The Why behind each rule.

## 1. Structure by feature, not by technical role

`users/`, `orders/`, `products/` each holding routes + service + validation + types — not `controllers/`, `services/`, `models/` siloed by role.

**Why**: Feature folders keep related code together, reduce cross-directory imports. Working on "orders" → one directory, not four.

## 2. async/await + proper error propagation

Check the Express major version before choosing error propagation; see [async error handling](api-design.md#the-async-handler-wrapper). Custom error classes (`AppError` with `statusCode` + `isOperational`). Never `catch {}` empty.

**Why**: Unhandled promise rejection crashes the process in Node 15+. Silent catches hide bugs.

## 3. Validate inputs at the boundary

Zod / Joi for `req.body`, `req.params`, `req.query` at route entry. 400 + structured errors on failure. Never raw input → DB / FS / shell.

**Why**: Boundary validation = inner code can trust inputs. Fewer defensive checks, no injection slipping through.

## 4. Env-based config with validation

`dotenv` in dev. Validate required config at startup with Zod schema — fail fast. Never hardcode secrets / connection strings / API keys.

**Why**: Missing `DATABASE_URL` at startup = 5-second fix; at 3 AM on first user hit = incident.

## 5. TypeScript strict mode

`"strict": true`. `unknown` + narrow, never `any`. Annotate signatures + exports; let inference do the rest.

**Why**: TS value comes from compile-time errors. Every `any` is a hole. Strict mode = the checks that catch real bugs.

## 6. Express middleware correctness

Error middleware needs 4 params `(err, req, res, next)` and must follow the routes. `helmet()`, `cors()`, request-ID middleware. Use the version-aware error propagation in Rule 2.

**Why**: Express identifies error middleware by arity. 3 params = regular; 4 = error handler. Missing param silently turns it into regular middleware that never runs on errors.

## 7. Never block the event loop

No `fs.readFileSync` / `crypto.pbkdf2Sync` / CPU loops on request paths. `fs.promises`, async crypto, `worker_threads` for CPU, streams for large payloads.

**Why**: Single thread. 100ms block = every concurrent request waits 100ms → cascading timeouts under load.

## 8. Connection pooling + parameterized queries

`pg.Pool` (not `pg.Client` per request). Pool for MySQL / MongoDB. `$1` / `?` / ORM binding — never concat SQL.

**Why**: New TCP per query = 5–10ms + connection-limit exhaustion. Concat = #1 SQLi cause.

## 9. Structured logging with correlation IDs

Pino (perf-recommended) / Winston. JSON format. Request ID from `X-Request-Id` or `crypto.randomUUID()` on every log line. `AsyncLocalStorage` to propagate context.

**Why**: Structured logs = searchable. Correlation IDs trace one request across services + log entries.

## 10. Test at the right level

Unit-test pure logic (validators, transformers, calc). Integration-test routes with `supertest`. Mock only external boundaries (DB, HTTP, queues), never internal modules.

**Why**: Over-mocking = tests pass when code is broken. Real-Express tests catch middleware order, validation, serialization bugs.

## 11. Manage dependencies deliberately

Commit lockfiles. `npm ci` in CI/CD. `npm audit`. Pin major versions of critical deps.

**Why**: `npm install` can silent-upgrade minor/patch. No lockfile → divergent builds. Supply chain attacks are real.

## 12. Containerize correctly

Multi-stage Docker (build with devDeps, prod with runtime only). `USER node`. `NODE_ENV=production`. `dumb-init` / `--init` for signals. `COPY package*.json` first for layer cache.

**Why**: Root in container = vulnerability gives attacker root. Missing signal handling = `docker stop` drops in-flight requests.

## Working Patterns

For writing or reviewing Node.js code, use [working-patterns.md](working-patterns.md).

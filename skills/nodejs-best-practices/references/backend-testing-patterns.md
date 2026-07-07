# Node.js Backend Testing Patterns

## Contents
- Test runner choice
- Layered testing strategy
- HTTP layer testing with supertest
- Database testing with testcontainers
- Outbound HTTP mocking with nock
- Mocking boundaries, fixtures, coverage, CI, common mistakes

## Test Runner Choice

| Runner | When |
|---|---|
| **Vitest** (default) | New projects. Fast, ESM-native, TypeScript out of the box, Jest-compatible API |
| **Jest** | Existing Jest project — don't migrate without reason. Use `ts-jest` or `babel-jest` |
| **node:test** (built-in) | Zero-dep CLI tools / libraries. Not worth it for app servers |

Do not mix runners in one repo. If a monorepo has both frontend (Vitest) and backend, keep both Vitest with separate configs.

## Layered Testing Strategy

| Layer | Scope | Tools | Run frequency |
|---|---|---|---|
| **Unit** | Pure functions, domain logic, validators | Vitest/Jest, no mocks needed if logic is pure | Every save (watch mode) |
| **Integration** | Route → service → DB → external HTTP | testcontainers + supertest + nock | Every PR |
| **Contract** | API consumer/provider compatibility | Pact (consumer-driven) or Schemathesis (OpenAPI) | Every PR if cross-team API |
| **E2E** | Real deployed environment | Playwright / k6 smoke against staging | Pre-deploy |

Unit tests should be 70%+ of count, integration 25%, contract/E2E 5% — but coverage matters less than "every critical path has at least one integration test that hits a real DB".

## HTTP Layer Testing — supertest

```ts
import request from 'supertest';
import { createApp } from '../src/app';

describe('POST /users', () => {
  const app = createApp();  // factory returns Express/Fastify instance, NOT listening

  it('creates user with valid payload', async () => {
    const res = await request(app)
      .post('/users')
      .send({ email: 'a@b.com', name: 'Alice' })
      .expect(201);

    expect(res.body).toMatchObject({ email: 'a@b.com' });
  });
});
```

Key rules:
- **Never** call `app.listen()` in tests — supertest binds to ephemeral port internally.
- Export an app factory (`createApp()`), not a listening server.
- One `app` per `describe` is fine; do not share across files unless tests are read-only.

## Database Testing — testcontainers

```ts
import { PostgreSqlContainer, StartedPostgreSqlContainer } from '@testcontainers/postgresql';

let container: StartedPostgreSqlContainer;
let connectionString: string;

beforeAll(async () => {
  container = await new PostgreSqlContainer('postgres:16').start();
  connectionString = container.getConnectionUri();
  await runMigrations(connectionString);  // real migration files
}, 60_000);

afterAll(async () => {
  await container.stop();
});

beforeEach(async () => {
  await truncateAllTables(connectionString);  // or use savepoint/rollback per test
});
```

Rules:
- One container per test file (or shared via global setup if startup cost dominates).
- Run **real migrations** against the container — this catches migration bugs as a side benefit.
- Reset state between tests: truncate or transaction-rollback. Do not rely on test ordering.
- Increase test timeout (60s+) to accommodate container startup.

## Outbound HTTP Mocking — nock

```ts
import nock from 'nock';

beforeEach(() => nock.cleanAll());
afterAll(() => nock.restore());

it('handles 503 from payment API with retry', async () => {
  nock('https://payment.api')
    .post('/charge').reply(503)
    .post('/charge').reply(200, { id: 'ch_123' });

  const result = await chargeWithRetry(/* ... */);
  expect(result.id).toBe('ch_123');
});
```

Rules:
- Use `nock.disableNetConnect()` in test setup to fail loudly on un-mocked outbound calls.
- Allow loopback for testcontainers: `nock.enableNetConnect(/(127\.0\.0\.1|localhost)/)`.
- Always `nock.cleanAll()` between tests to prevent interceptor leak.
- Do not use nock for in-process function mocks — that's `vi.mock` / `jest.mock` territory.

## Mocking Boundaries (cheat sheet)

| What | How |
|---|---|
| Database | testcontainers (do not mock) |
| HTTP outbound (REST / SOAP) | nock |
| Time | `vi.useFakeTimers()` / `jest.useFakeTimers()` |
| Randomness | inject seed into RNG; never `Math.random` directly in domain code |
| File system (small) | tmp dir via `node:fs` + `os.tmpdir()` |
| File system (heavy) | memfs |
| Environment variables | `vi.stubEnv()` / set in test setup, restore in afterEach |
| Crypto / UUID | inject as constructor param, mock with deterministic value |
| Background jobs / queue | testcontainers Redis + BullMQ in-memory mode for unit |

## Test Data — Fixtures vs Factories

- **Factory** (recommended): `userFactory.build({ email: 'a@b.com' })` returns a complete object with sensible defaults. Use [Fishery](https://github.com/thoughtbot/fishery) or hand-rolled.
- **Fixture file** only for static reference data (e.g. seed JSON for migration tests).
- Never share mutable test objects across tests — flake source.

## Coverage Configuration

- **Threshold**: 80% line / 70% branch on application code, exclude generated / config / migration files.
- Use `--coverage` only in CI, not in watch mode (slow).
- Fail CI if threshold drops, not on absolute number — coverage is regression detector, not quality metric.

## CI Parallelization

- Vitest: `--pool=threads` for CPU-bound, `--pool=forks` for tests with shared global state.
- Jest: `--maxWorkers=50%` on CI (avoid OOM).
- Testcontainers in parallel: ensure each worker gets its own container (use `--runInBand` if container startup is the bottleneck and parallelization isn't helping).
- Cache testcontainer images on CI runner (Docker layer cache).

## Common Mistakes

- **Mocking the database** with sinon/jest.mock → schema drift, query bugs, migration regressions never caught.
- **Calling `app.listen()` in tests** → port conflicts, slow teardown, leaked handles preventing exit.
- **Sharing testcontainer state across tests** without reset → flaky on parallel run.
- **Forgetting `nock.cleanAll()`** between tests → intercepts leak across test files.
- **Real outbound HTTP** because `nock` was forgotten → test passes locally, fails on CI without network, hits rate limits, leaks credentials.
- **`done()` callback** in modern tests → use `async/await` only.
- **Snapshot tests for API response** → snapshots become noisy on every minor field add. Use explicit `expect(...).toMatchObject(...)`.
- **Coverage as the goal** instead of "every critical path has an integration test that hits real DB".
- **Not seeding container with realistic volume** → query performance bugs only show up in production.

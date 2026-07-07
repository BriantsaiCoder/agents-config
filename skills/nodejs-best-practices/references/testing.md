# Testing Strategy

Covers **Rule 10** (test at the right level).

---

## Table of Contents

- [Testing Pyramid for Node.js](#testing-pyramid-for-nodejs)
- [Unit Testing Pure Logic](#unit-testing-pure-logic)
- [Integration Testing with Supertest](#integration-testing-with-supertest)
- [Test Setup and Teardown](#test-setup-and-teardown)
- [What to Mock (and What Not To)](#what-to-mock-and-what-not-to)
- [Testing Patterns and Utilities](#testing-patterns-and-utilities)

---

## Testing Pyramid for Node.js

| Level | What to test | Tools | Speed |
|-------|-------------|-------|-------|
| **Unit** | Pure functions, validators, transformers, business logic | Jest / Vitest | Fast (~ms) |
| **Integration** | Routes + middleware + validation + service layer | Supertest + Jest/Vitest | Medium (~100ms) |
| **E2E** | Critical user flows through the full stack | Playwright / Cypress | Slow (~seconds) |

### Framework recommendation

- **Vitest** — recommended for new TypeScript projects. Native ESM, fast, excellent TypeScript support.
- **Jest** — mature, huge ecosystem, good for existing projects. Needs `ts-jest` or SWC for TypeScript.
- Both work. Pick one and be consistent.

---

## Unit Testing Pure Logic

Unit tests are for code with no I/O — validators, transformers, business rules, utility functions.

```typescript
// src/orders/orders.service.test.ts
import { describe, it, expect } from 'vitest';
import { calculateOrderTotal, applyDiscount } from './orders.utils';

describe('calculateOrderTotal', () => {
  it('sums item prices with quantities', () => {
    const items = [
      { price: 10.00, quantity: 2 },
      { price: 5.50, quantity: 1 },
    ];
    expect(calculateOrderTotal(items)).toBe(25.50);
  });

  it('returns 0 for empty items', () => {
    expect(calculateOrderTotal([])).toBe(0);
  });

  it('handles fractional cents correctly', () => {
    const items = [
      { price: 0.1, quantity: 3 },
      { price: 0.2, quantity: 1 },
    ];
    // Floating point: 0.1 * 3 + 0.2 = 0.5 (not 0.30000000000000004 + 0.2)
    expect(calculateOrderTotal(items)).toBeCloseTo(0.5);
  });
});

describe('applyDiscount', () => {
  it('applies percentage discount', () => {
    expect(applyDiscount(100, { type: 'percentage', value: 10 })).toBe(90);
  });

  it('does not go below zero', () => {
    expect(applyDiscount(5, { type: 'fixed', value: 10 })).toBe(0);
  });

  it('throws on negative discount value', () => {
    expect(() => applyDiscount(100, { type: 'percentage', value: -5 }))
      .toThrow('Discount value must be positive');
  });
});
```

---

## Integration Testing with Supertest

Integration tests exercise the full Express middleware chain — routing, validation, error handling, and
response serialization. This is where you catch real bugs.

```typescript
// src/users/users.integration.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { app } from '../app';
import { pool } from '../config/database';

describe('POST /api/users', () => {
  afterAll(async () => {
    // Clean up test data
    await pool.query("DELETE FROM users WHERE email LIKE '%@test.example.com'");
    await pool.end();
  });

  it('creates a user with valid input', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({
        email: 'john@test.example.com',
        name: 'John Doe',
        password: 'securePassword123',
      })
      .expect(201);

    expect(response.body).toMatchObject({
      email: 'john@test.example.com',
      name: 'John Doe',
    });
    expect(response.body).not.toHaveProperty('password'); // Never expose password
    expect(response.body).toHaveProperty('id');
  });

  it('returns 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({
        email: 'not-an-email',
        name: 'Jane',
        password: 'securePassword123',
      })
      .expect(400);

    expect(response.body.error.message).toBe('Validation failed');
    expect(response.body.error.details).toContainEqual(
      expect.objectContaining({ path: 'email' }),
    );
  });

  it('returns 409 for duplicate email', async () => {
    // First create succeeds
    await request(app)
      .post('/api/users')
      .send({
        email: 'duplicate@test.example.com',
        name: 'First',
        password: 'securePassword123',
      })
      .expect(201);

    // Second create with same email fails
    await request(app)
      .post('/api/users')
      .send({
        email: 'duplicate@test.example.com',
        name: 'Second',
        password: 'securePassword123',
      })
      .expect(409);
  });
});

describe('GET /api/users/:id', () => {
  it('returns 404 for non-existent user', async () => {
    await request(app)
      .get('/api/users/00000000-0000-0000-0000-000000000000')
      .expect(404);
  });

  it('returns 400 for invalid UUID', async () => {
    await request(app)
      .get('/api/users/not-a-uuid')
      .expect(400);
  });
});
```

### Testing authenticated routes

```typescript
describe('GET /api/orders (authenticated)', () => {
  let authToken: string;

  beforeAll(async () => {
    // Create a test user and get a token
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'testPassword123' });
    authToken = res.body.token;
  });

  it('returns orders for authenticated user', async () => {
    const response = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${authToken}`)
      .expect(200);

    expect(response.body.data).toBeInstanceOf(Array);
    expect(response.body.meta).toHaveProperty('total');
  });

  it('returns 401 without token', async () => {
    await request(app)
      .get('/api/orders')
      .expect(401);
  });

  it('returns 401 with expired token', async () => {
    await request(app)
      .get('/api/orders')
      .set('Authorization', 'Bearer expired.jwt.token')
      .expect(401);
  });
});
```

---

## Test Setup and Teardown

### Database setup for integration tests

```typescript
// test/setup.ts
import { pool } from '../src/config/database';

// Run migrations before all tests
beforeAll(async () => {
  // Use a test-specific database or run migrations
  await pool.query('BEGIN');
});

afterEach(async () => {
  // Rollback after each test for isolation
  await pool.query('ROLLBACK');
  await pool.query('BEGIN');
});

afterAll(async () => {
  await pool.query('ROLLBACK');
  await pool.end();
});
```

### Vitest configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./test/setup.ts'],
    // Run integration tests separately (slower)
    include: ['src/**/*.test.ts'],
    // Timeout for integration tests
    testTimeout: 10_000,
    // Coverage
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      exclude: ['node_modules', 'dist', 'test'],
    },
  },
});
```

---

## What to Mock (and What Not To)

### Mock at boundaries, not internals

| Mock this | Don't mock this |
|-----------|----------------|
| External HTTP calls (APIs) | Your own service layer |
| Database (only for unit tests) | Express middleware chain |
| Message queues | Validation logic |
| Email/SMS services | Error handling |
| Clock/timers (for time-dependent logic) | Internal helper functions |

### Mocking external HTTP calls

```typescript
import { vi, describe, it, expect } from 'vitest';

// Mock the fetch call to an external API
vi.mock('node-fetch', () => ({
  default: vi.fn(),
}));

import fetch from 'node-fetch';
const mockFetch = vi.mocked(fetch);

describe('PaymentService', () => {
  it('handles payment gateway timeout', async () => {
    mockFetch.mockRejectedValueOnce(new Error('ETIMEDOUT'));

    await expect(paymentService.charge('order-123', 99.99))
      .rejects.toThrow('Payment gateway unavailable');
  });
});
```

### Why not mock internal modules?

```typescript
// BAD: mocking your own repository — tests pass even if the real query is wrong
vi.mock('./users.repository');
const mockRepo = vi.mocked(usersRepository);
mockRepo.findById.mockResolvedValue({ id: '1', name: 'Test' });

// This test proves nothing about whether the route actually works.
// It only tests that usersService calls usersRepository.findById — which is obvious from the code.

// GOOD: test against a real (or in-memory) database
// The integration test in the previous section catches real bugs:
// - Wrong SQL query
// - Missing validation
// - Incorrect response shape
// - Middleware ordering issues
```

---

## Testing Patterns and Utilities

### Test data builders

```typescript
// test/builders/user.builder.ts
import { CreateUserInput } from '../../src/users/users.types';

export function buildCreateUserInput(overrides: Partial<CreateUserInput> = {}): CreateUserInput {
  return {
    email: `user-${Date.now()}@test.example.com`,
    name: 'Test User',
    password: 'securePassword123',
    role: 'user',
    ...overrides,
  };
}

// Usage in tests:
const input = buildCreateUserInput({ role: 'admin' });
```

### Testing error responses

```typescript
// Helper to assert error response shape
function expectErrorResponse(response: request.Response, statusCode: number, messagePattern?: RegExp) {
  expect(response.status).toBe(statusCode);
  expect(response.body).toHaveProperty('error');
  expect(response.body.error).toHaveProperty('message');
  if (messagePattern) {
    expect(response.body.error.message).toMatch(messagePattern);
  }
}
```

### Test organization

```
src/
├── users/
│   ├── users.service.ts
│   ├── users.utils.ts
│   ├── users.utils.test.ts          # Unit tests (pure logic)
│   └── users.integration.test.ts    # Integration tests (routes)
└── orders/
    ├── orders.service.ts
    ├── orders.utils.test.ts
    └── orders.integration.test.ts
```

### npm scripts

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:unit": "vitest run --include='**/*.utils.test.ts'",
    "test:integration": "vitest run --include='**/*.integration.test.ts'"
  }
}
```

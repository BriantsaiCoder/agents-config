# Project Structure & Error Handling

Covers **Rule 1** (feature-based structure) and **Rule 2** (async/await error propagation).

---

## Table of Contents

- [Feature-Based Project Structure](#feature-based-project-structure)
- [Custom Error Classes](#custom-error-classes)
- [Async Handler Wrapper](#async-handler-wrapper)
- [Express Error Middleware](#express-error-middleware)
- [Process-Level Error Handling](#process-level-error-handling)

---

## Feature-Based Project Structure

### Recommended layout

```
src/
├── app.ts                    # Express app setup, middleware registration
├── server.ts                 # HTTP server bootstrap, graceful shutdown
├── config/
│   └── env.ts                # Validated environment config (see security-validation.md)
├── common/
│   ├── errors.ts             # AppError, NotFoundError, ValidationError
│   ├── middleware/
│   │   ├── error-handler.ts  # Central error middleware
│   │   ├── request-id.ts     # X-Request-Id propagation
│   │   ├── validate.ts       # Generic Zod/Joi validation middleware
│   │   └── async-handler.ts  # Async wrapper
│   └── types/
│       └── express.d.ts      # Request augmentation (requestId, user, etc.)
├── users/
│   ├── users.router.ts       # Express router for /api/users
│   ├── users.service.ts      # Business logic
│   ├── users.repository.ts   # Database access
│   ├── users.schema.ts       # Zod validation schemas
│   ├── users.types.ts        # TypeScript interfaces
│   └── users.test.ts         # Integration tests
├── orders/
│   ├── orders.router.ts
│   ├── orders.service.ts
│   ├── orders.repository.ts
│   ├── orders.schema.ts
│   └── orders.test.ts
└── health/
    └── health.router.ts      # GET /health for container probes
```

### Why not controllers/services/models?

The traditional MVC layout (`controllers/`, `services/`, `models/`) scatters related code across the tree.
Adding a new "products" feature means touching 3-4 directories. Feature folders keep everything together:

```
# Adding a new feature:
# MVC style: touch controllers/products.ts, services/products.ts, models/product.ts, routes/products.ts
# Feature style: mkdir src/products/ and add all files there
```

### Router registration pattern

```typescript
// src/app.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { requestId } from './common/middleware/request-id';
import { errorHandler } from './common/middleware/error-handler';
import { usersRouter } from './users/users.router';
import { ordersRouter } from './orders/orders.router';
import { healthRouter } from './health/health.router';

const app = express();

// Security & parsing middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(requestId);

// Feature routers
app.use('/api/users', usersRouter);
app.use('/api/orders', ordersRouter);
app.use('/health', healthRouter);

// Error handler MUST be registered last
app.use(errorHandler);

export { app };
```

---

## Custom Error Classes

Distinguish between **operational errors** (expected, like "user not found" or "invalid input") and
**programmer errors** (bugs, like TypeError or null reference). Operational errors get a friendly response;
programmer errors get a generic 500.

```typescript
// src/common/errors.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly isOperational = true,
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string | number) {
    super(`${resource} with id '${id}' not found`, 404);
  }
}

export class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly errors: Record<string, string[]> = {},
  ) {
    super(message, 400);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409);
  }
}
```

### Usage in service layer

```typescript
// src/users/users.service.ts
import { NotFoundError, ConflictError } from '../common/errors';

export class UsersService {
  constructor(private readonly repo: UsersRepository) {}

  async getById(id: string): Promise<User> {
    const user = await this.repo.findById(id);
    if (!user) throw new NotFoundError('User', id);
    return user;
  }

  async create(data: CreateUserInput): Promise<User> {
    const existing = await this.repo.findByEmail(data.email);
    if (existing) throw new ConflictError(`Email '${data.email}' is already registered`);
    return this.repo.insert(data);
  }
}
```

---

## Async Handler Wrapper

Express does not natively catch promise rejections from async handlers. Without a wrapper, an unhandled
rejection crashes the process (Node 15+) or silently hangs the request.

```typescript
// src/common/middleware/async-handler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * Wraps an async route handler so rejected promises are forwarded to Express error middleware.
 */
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>,
): RequestHandler => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
```

### Usage

```typescript
// src/users/users.router.ts
import { Router } from 'express';
import { asyncHandler } from '../common/middleware/async-handler';
import { validate } from '../common/middleware/validate';
import { createUserSchema, getUserParamsSchema } from './users.schema';

const router = Router();

router.get(
  '/:id',
  validate({ params: getUserParamsSchema }),
  asyncHandler(async (req, res) => {
    const user = await usersService.getById(req.params.id);
    res.json(user);
  }),
);

router.post(
  '/',
  validate({ body: createUserSchema }),
  asyncHandler(async (req, res) => {
    const user = await usersService.create(req.body);
    res.status(201).json(user);
  }),
);

export { router as usersRouter };
```

**Note:** Express 5 (currently in beta) natively catches async rejections, making this wrapper unnecessary.
Until Express 5 is stable, always use the wrapper.

---

## Express Error Middleware

The centralized error handler converts errors into consistent API responses.

```typescript
// src/common/middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors';
import { logger } from '../../config/logger';

// IMPORTANT: Express identifies error middleware by its 4-parameter signature.
// Removing any parameter (even if unused) breaks error routing.
export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction,  // Must be present even though unused
): void => {
  if (err instanceof AppError && err.isOperational) {
    // Expected operational error — log at warn level, return structured response
    logger.warn({ err, requestId: req.id }, err.message);
    res.status(err.statusCode).json({
      error: {
        message: err.message,
        ...(err instanceof ValidationError && { details: err.errors }),
      },
    });
    return;
  }

  // Unexpected error (programmer bug) — log full stack, return generic 500
  logger.error({ err, requestId: req.id }, 'Unhandled error');
  res.status(500).json({
    error: { message: 'Internal server error' },
  });
};
```

### Common mistakes

| Mistake | Why it breaks | Fix |
|---------|--------------|-----|
| Error handler with 3 params | Express treats it as regular middleware | Add `_next` as 4th param |
| `app.use(errorHandler)` before routes | Error handler never receives errors | Register error handler **after** all routes |
| `res.json(err)` | Serializes `Error` as `{}` (non-enumerable props) | Extract message/statusCode explicitly |
| `catch (e) { console.log(e) }` in route | Swallows error, request hangs forever | Use `asyncHandler` + let error reach middleware |

---

## Process-Level Error Handling

For errors that escape Express's middleware chain — unhandled rejections and uncaught exceptions.

```typescript
// src/server.ts
import { app } from './app';
import { logger } from './config/logger';

const server = app.listen(config.port, () => {
  logger.info(`Server listening on port ${config.port}`);
});

// Graceful shutdown
const shutdown = (signal: string) => {
  logger.info(`${signal} received, shutting down gracefully`);
  server.close(() => {
    logger.info('HTTP server closed');
    // Close DB pools, message queues, etc.
    process.exit(0);
  });

  // Force exit if graceful shutdown takes too long
  setTimeout(() => {
    logger.error('Graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, 10_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Catch unhandled rejections — log and continue (operational) or exit (bug)
process.on('unhandledRejection', (reason: unknown) => {
  logger.error({ err: reason }, 'Unhandled promise rejection');
  // In production, you may want to exit and let the orchestrator restart:
  // process.exit(1);
});

// Catch uncaught exceptions — always exit (the process is in an undefined state)
process.on('uncaughtException', (err: Error) => {
  logger.fatal({ err }, 'Uncaught exception — exiting');
  process.exit(1);
});
```

### Decision guide: exit or recover?

| Error type | Action | Reason |
|-----------|--------|--------|
| `uncaughtException` | Always exit | Process state is corrupted |
| `unhandledRejection` (operational, e.g., DB timeout) | Log + continue | Process is still healthy |
| `unhandledRejection` (programmer error) | Exit | Bug may have corrupted state |
| SIGTERM / SIGINT | Graceful shutdown | Let in-flight requests complete |

# API Design, TypeScript & Logging

Covers **Rule 5** (TypeScript strict mode), **Rule 6** (Express middleware), and **Rule 9** (structured logging).

---

## Table of Contents

- [TypeScript Configuration](#typescript-configuration)
- [Express Middleware Patterns](#express-middleware-patterns)
- [REST API Response Conventions](#rest-api-response-conventions)
- [Structured Logging with Pino](#structured-logging-with-pino)
- [Request ID and Correlation](#request-id-and-correlation)

---

## TypeScript Configuration

### Recommended tsconfig.json for Node.js

```json
{
  "compilerOptions": {
    "target": "ES2024",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "lib": ["ES2024"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": false
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

`module: nodenext` is what enables Node 22+ semantics such as `require("esm")`; the older `Node16` value
still compiles but locks the file to Node 16 module semantics. On TypeScript 5.9+ prefer
`"module": "node20"` — a fixed snapshot of Node 20/22/24 semantics that will not drift when TypeScript is
upgraded, with `moduleResolution` inferred automatically (no need to write it). Keep `target`/`lib` aligned
with the runtime this skill's Dockerfile pins (`node:24-alpine`) — `ES2024` is what `@tsconfig/node24` ships.
Drop to `ES2023` (the TS Node-Target-Mapping value for Node 22) only if you must still run on Node 22.

### Key strict mode rules and why they matter

| Option | What it catches |
|--------|----------------|
| `strict: true` | Enables all strict checks below (and future ones) |
| `noImplicitAny` | Forces explicit types where inference fails |
| `strictNullChecks` | Prevents `undefined is not an object` at runtime |
| `strictFunctionTypes` | Catches wrong callback signatures |
| `noUncheckedIndexedAccess` | `array[0]` returns `T | undefined`, not just `T` |

### Avoiding `any`

```typescript
// Bad: any hides bugs
function processData(data: any) {
  return data.items.map((i: any) => i.name); // no type checking at all
}

// Good: use unknown and narrow
function processData(data: unknown): string[] {
  if (!isDataResponse(data)) {
    throw new AppError('Invalid data format', 400);
  }
  return data.items.map((i) => i.name); // fully typed after narrowing
}

// Good: use generics for reusable functions
function parseJson<T>(raw: string, schema: z.ZodType<T>): T {
  return schema.parse(JSON.parse(raw));
}
```

### ESM vs CommonJS

For new projects, prefer ESM (`"type": "module"` in `package.json`):

```json
// package.json
{
  "type": "module",
  "engines": { "node": ">=24" }
}
```

For existing CommonJS projects, migration is optional. Both work fine with TypeScript.

---

## Express Middleware Patterns

### Middleware execution order matters

```typescript
const app = express();

// 1. Security headers (first — protects all responses)
app.use(helmet());

// 2. CORS (before routes — preflight requests need it)
app.use(cors({ origin: config.ALLOWED_ORIGINS }));

// 3. Request parsing
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// 4. Request ID / correlation (before routes — logs need it)
app.use(requestId);

// 5. Request logging (before routes — logs the incoming request)
app.use(requestLogger);

// 6. Routes
app.use('/api/users', usersRouter);
app.use('/api/orders', ordersRouter);
app.use('/health', healthRouter);

// 7. 404 handler (after routes — catches unmatched requests)
app.use((req, res) => {
  res.status(404).json({ error: { message: `Route ${req.method} ${req.path} not found` } });
});

// 8. Error handler (LAST — catches errors from all above)
app.use(errorHandler);
```

### The async handler wrapper

Check the installed Express major version in the project manifest/lockfile.

- **Express 4:** explicitly forward async handler rejections to `next(err)`; reuse an existing wrapper or equivalent `.catch(next)` handling.
- **Express 5:** rejections from a Promise returned by a route handler/middleware reach the error middleware automatically. An `async` handler returns such a Promise; no wrapper is required. Existing working wrappers need not be removed.
- **Both versions:** callback errors and detached/unreturned asynchronous work are outside that returned Promise. Forward callback errors with `next(err)` and catch detached rejections explicitly; a surrounding async handler alone does not catch them.
- Register error middleware with all four parameters `(err, req, res, next)` after routes. Do not swallow errors.

See [Express error handling](https://expressjs.com/en/guide/error-handling/). The wrapper below is an Express 4 example; it remains compatible with Express 5.

```typescript
// src/common/middleware/async-handler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express';

export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>,
): RequestHandler => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
```

### Authentication middleware pattern

```typescript
// src/common/middleware/authenticate.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../../config/env';
import { UnauthorizedError } from '../errors';

export interface AuthenticatedRequest extends Request {
  user: { id: string; email: string; role: string };
}

export const authenticate = (
  req: Request,
  _res: Response,
  next: NextFunction,
): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing or invalid Authorization header');
  }

  try {
    const token = authHeader.slice(7);
    const payload = jwt.verify(token, config.JWT_SECRET) as AuthenticatedRequest['user'];
    (req as AuthenticatedRequest).user = payload;
    next();
  } catch {
    throw new UnauthorizedError('Invalid or expired token');
  }
};
```

### Role-based authorization

```typescript
export const authorize = (...roles: string[]) => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const user = (req as AuthenticatedRequest).user;
    if (!roles.includes(user.role)) {
      throw new ForbiddenError(`Role '${user.role}' is not authorized for this action`);
    }
    next();
  };
};

// Express 4 usage (the existing wrapper is also compatible with Express 5):
router.delete('/:id', authenticate, authorize('admin'), asyncHandler(deleteUser));
```

---

## REST API Response Conventions

### Consistent response format

```typescript
// Success responses
{ "data": { ... } }                    // Single resource
{ "data": [...], "meta": { ... } }     // Collection with pagination

// Error responses
{
  "error": {
    "message": "Human-readable description",
    "details": [...]                    // Optional validation details
  }
}
```

### Pagination response

```typescript
interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Service method
async list(query: ListUsersQuery): Promise<PaginatedResponse<User>> {
  const { page, limit } = query;
  const offset = (page - 1) * limit;

  const [users, total] = await Promise.all([
    this.repo.findMany({ offset, limit }),
    this.repo.count(),
  ]);

  return {
    data: users,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

### HTTP status codes

| Operation | Success | Common errors |
|-----------|---------|---------------|
| GET single | 200 | 404 (not found) |
| GET list | 200 | 400 (bad query params) |
| POST create | 201 | 400 (validation), 409 (conflict) |
| PUT/PATCH update | 200 | 400, 404, 409 |
| DELETE | 204 (no body) | 404 |
| Auth failure | — | 401 (unauthenticated), 403 (forbidden) |

---

## Structured Logging with Pino

### Why Pino?

Pino is ~5x faster than Winston because it uses a separate worker thread for log processing.
It outputs JSON by default, which is what log aggregators (Datadog, ELK, CloudWatch) expect.

### Setup

```typescript
// src/config/logger.ts
import pino from 'pino';
import { config } from './env';

export const logger = pino({
  level: config.LOG_LEVEL,
  // Human-readable output in development
  ...(config.NODE_ENV === 'development' && {
    transport: {
      target: 'pino-pretty',
      options: { colorize: true },
    },
  }),
  // Redact sensitive fields
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.token'],
    censor: '[REDACTED]',
  },
});
```

### Request logging middleware

```typescript
// src/common/middleware/request-logger.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../../config/logger';

export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      duration,
      requestId: req.id,
    };

    if (res.statusCode >= 500) {
      logger.error(logData, 'Request failed');
    } else if (res.statusCode >= 400) {
      logger.warn(logData, 'Request error');
    } else {
      logger.info(logData, 'Request completed');
    }
  });

  next();
};
```

### Logging best practices

| Do | Don't |
|----|-------|
| Log at meaningful decision points | Log every function entry/exit |
| Include context (requestId, userId, orderId) | Log raw request bodies (PII risk) |
| Use appropriate levels (error/warn/info/debug) | Use `console.log` in production |
| Redact sensitive fields | Log passwords, tokens, or secrets |
| Use child loggers for context | Pass logger as a function parameter everywhere |

---

## Request ID and Correlation

### Using AsyncLocalStorage (Node.js 16+)

`AsyncLocalStorage` propagates context through the async call chain without passing it as a parameter:

```typescript
// src/common/context.ts
import { AsyncLocalStorage } from 'node:async_hooks';

interface RequestContext {
  requestId: string;
  userId?: string;
}

export const requestContext = new AsyncLocalStorage<RequestContext>();

// Helper to get current context
export const getRequestId = (): string => {
  return requestContext.getStore()?.requestId ?? 'no-request-id';
};
```

### Request ID middleware

```typescript
// src/common/middleware/request-id.ts
import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'node:crypto';
import { requestContext } from '../context';

export const requestId = (req: Request, res: Response, next: NextFunction): void => {
  const id = (req.headers['x-request-id'] as string) || randomUUID();

  // Augment request object
  req.id = id;

  // Set response header for client correlation
  res.setHeader('x-request-id', id);

  // Run the rest of the request inside AsyncLocalStorage context
  requestContext.run({ requestId: id }, () => next());
};
```

### Logger with automatic request context

```typescript
// src/config/logger.ts
import pino from 'pino';
import { requestContext } from '../common/context';

export const logger = pino({
  level: config.LOG_LEVEL,
  mixin() {
    const store = requestContext.getStore();
    return store ? { requestId: store.requestId, userId: store.userId } : {};
  },
});
```

Now every log line automatically includes `requestId` without passing it manually:

```typescript
// Anywhere in the codebase:
logger.info({ orderId: '123' }, 'Processing order');
// Output: {"level":30,"requestId":"abc-def","orderId":"123","msg":"Processing order"}
```

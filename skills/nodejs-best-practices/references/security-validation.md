# Security & Input Validation

Covers **Rule 3** (validate all inputs at the boundary) and **Rule 4** (environment-based config with validation).

---

## Table of Contents

- [Input Validation with Zod](#input-validation-with-zod)
- [Validation Middleware Pattern](#validation-middleware-pattern)
- [Common Validation Patterns](#common-validation-patterns)
- [Environment Config with Validation](#environment-config-with-validation)
- [Security Checklist](#security-checklist)

---

## Input Validation with Zod

Zod is the recommended validation library for TypeScript Node.js projects. It provides runtime validation
with automatic TypeScript type inference — write the schema once, get both validation and types.

```typescript
// src/users/users.schema.ts
import { z } from 'zod';

export const createUserSchema = z.object({
  email: z.string().email('Invalid email format'),
  name: z.string().min(1, 'Name is required').max(100),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  role: z.enum(['user', 'admin']).default('user'),
});

export const updateUserSchema = createUserSchema.partial().omit({ password: true });

export const getUserParamsSchema = z.object({
  id: z.string().uuid('Invalid user ID format'),
});

export const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional(),
  role: z.enum(['user', 'admin']).optional(),
});

// TypeScript types are inferred automatically
export type CreateUserInput = z.infer<typeof createUserSchema>;
export type UpdateUserInput = z.infer<typeof updateUserSchema>;
export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;
```

### Why Zod over Joi?

| Feature | Zod | Joi |
|---------|-----|-----|
| TypeScript inference | Built-in, zero duplication | Requires separate type definitions |
| Bundle size | ~13KB | ~150KB |
| Dependencies | Zero | Multiple |
| Error format | Structured, predictable | Verbose, harder to customize |
| Ecosystem | Growing rapidly (40M+ weekly downloads) | Mature, battle-tested |

Both are good choices. Use Zod for TypeScript projects (type inference is a huge win).
Use Joi if the team already uses it or needs Joi-specific features (conditional validation, references).

---

## Validation Middleware Pattern

A reusable middleware that validates `body`, `params`, and/or `query` against Zod schemas:

```typescript
// src/common/middleware/validate.ts
import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';

interface ValidationSchemas {
  body?: AnyZodObject;
  params?: AnyZodObject;
  query?: AnyZodObject;
}

export const validate = (schemas: ValidationSchemas) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      if (schemas.body) req.body = schemas.body.parse(req.body);
      if (schemas.params) req.params = schemas.params.parse(req.params) as any;
      if (schemas.query) req.query = schemas.query.parse(req.query) as any;
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({
          error: {
            message: 'Validation failed',
            details: err.errors.map((e) => ({
              path: e.path.join('.'),
              message: e.message,
            })),
          },
        });
        return;
      }
      next(err);
    }
  };
};
```

### Usage in routes

```typescript
router.post(
  '/',
  validate({ body: createUserSchema }),
  asyncHandler(async (req, res) => {
    // req.body is now typed and validated
    const user = await usersService.create(req.body);
    res.status(201).json(user);
  }),
);

router.get(
  '/',
  validate({ query: listUsersQuerySchema }),
  asyncHandler(async (req, res) => {
    // req.query.page and req.query.limit are numbers (coerced by Zod)
    const result = await usersService.list(req.query as ListUsersQuery);
    res.json(result);
  }),
);
```

---

## Common Validation Patterns

### Pagination

```typescript
export const paginationSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  sortBy: z.string().optional(),
  sortOrder: z.enum(['asc', 'desc']).default('asc'),
});
```

### Date ranges

```typescript
export const dateRangeSchema = z
  .object({
    startDate: z.coerce.date(),
    endDate: z.coerce.date(),
  })
  .refine((data) => data.endDate > data.startDate, {
    message: 'endDate must be after startDate',
    path: ['endDate'],
  });
```

### File upload validation

```typescript
// Validate after multer processes the upload
export const fileUploadSchema = z.object({
  mimetype: z.enum(['image/jpeg', 'image/png', 'image/webp']),
  size: z.number().max(5 * 1024 * 1024, 'File must be under 5MB'),
});
```

### Sanitizing string inputs

```typescript
// Strip HTML, trim whitespace, normalize
const sanitizedString = z.string().trim().transform((val) =>
  val.replace(/<[^>]*>/g, '') // strip HTML tags
);
```

---

## Environment Config with Validation

Never access `process.env` directly throughout the codebase. Validate once at startup, export a typed object.

```typescript
// src/config/env.ts
import { z } from 'zod';
import 'dotenv/config'; // Load .env in development

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),

  // Database
  DATABASE_URL: z.string().url(),
  DB_POOL_MIN: z.coerce.number().default(2),
  DB_POOL_MAX: z.coerce.number().default(10),

  // Auth
  JWT_SECRET: z.string().min(32, 'JWT secret must be at least 32 characters'),
  JWT_EXPIRES_IN: z.string().default('1h'),

  // External services
  REDIS_URL: z.string().url().optional(),
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),

  // Logging
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
});

// This throws at startup if any required var is missing — fail fast
export const config = envSchema.parse(process.env);
export type Config = z.infer<typeof envSchema>;
```

### .env.example file

Always commit a `.env.example` file with placeholder values so new developers know what's needed:

```bash
# .env.example
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
JWT_SECRET=change-this-to-a-random-string-at-least-32-chars
LOG_LEVEL=debug
```

### Accessing config in services

```typescript
// Correct: import validated config
import { config } from '../config/env';

const pool = new Pool({ connectionString: config.DATABASE_URL });

// Wrong: accessing process.env directly deep in business logic
// const url = process.env.DATABASE_URL; // No validation, could be undefined
```

---

## Security Checklist

### Injection prevention

| Attack vector | Prevention |
|--------------|------------|
| SQL injection | Parameterized queries (`$1`, `?`) — never concatenate |
| NoSQL injection | Validate input types, avoid `$where`, use typed queries |
| Command injection | Never pass user input to shell commands. Use `execFile()` with explicit args array instead of `exec()` with string interpolation |
| Path traversal | Validate and normalize paths with `path.resolve()`, reject `..` sequences |
| XSS (if serving HTML) | Use templating engine auto-escaping, CSP headers via `helmet()` |
| Prototype pollution | Freeze objects, use `Object.create(null)` for lookup maps, validate JSON depth |

### HTTP security headers (via helmet)

```typescript
import helmet from 'helmet';

app.use(helmet()); // Sets ~15 security headers with sane defaults

// Customize if needed:
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
    },
  },
  crossOriginResourcePolicy: { policy: 'same-site' },
}));
```

### Rate limiting

```typescript
import rateLimit from 'express-rate-limit';

// Global rate limit
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per window per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { message: 'Too many requests, please try again later' } },
}));

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: { message: 'Too many login attempts' } },
});
app.use('/api/auth', authLimiter);
```

### Request body limits

```typescript
// Always set a body size limit — prevents memory exhaustion attacks
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
```

### Secrets management

- Never commit `.env` files (add to `.gitignore`)
- Use `JWT_SECRET` of at least 32 random characters
- Rotate secrets periodically
- In production, use a secrets manager (AWS Secrets Manager, Vault, etc.)
- Never log secrets — redact sensitive fields in error serialization

### Dependency security

```bash
# Check for known vulnerabilities
npm audit

# Fix automatically where possible
npm audit fix

# For CI/CD: fail the build on vulnerabilities
npm audit --audit-level=high
```

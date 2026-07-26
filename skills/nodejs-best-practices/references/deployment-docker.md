# Deployment & Docker

Covers **Rule 11** (manage dependencies deliberately) and **Rule 12** (containerize correctly).

---

## Table of Contents

- [Dependency Management](#dependency-management)
- [Docker Best Practices](#docker-best-practices)
- [Health Check Endpoints](#health-check-endpoints)
- [Graceful Shutdown](#graceful-shutdown)
- [Environment Configuration](#environment-configuration)
- [CI/CD Pipeline Essentials](#cicd-pipeline-essentials)

---

## Dependency Management

### Package manager comparison

| Feature | npm | pnpm | Yarn |
|---------|-----|------|------|
| Speed | Moderate | Fastest | Fast |
| Disk usage | High (flat node_modules) | Low (content-addressable store) | Moderate |
| Monorepo support | Workspaces | Best (strict, efficient) | Workspaces |
| Phantom dependencies | Possible | Prevented (strict mode) | Possible |
| Recommended for | Most projects | Monorepos, disk-constrained | Legacy projects |

### Lockfile discipline

```bash
# Development: install from package.json, update lockfile
npm install

# CI/CD: install from lockfile ONLY — deterministic, fast, fail on mismatch
npm ci

# NEVER use `npm install` in CI — it may silently upgrade versions
```

### Auditing dependencies

```bash
# Check for known vulnerabilities
npm audit

# Show only high+ severity
npm audit --audit-level=high

# Fix what can be auto-fixed
npm audit fix

# For production, fail CI on vulnerabilities
npm audit --production --audit-level=high
```

### .npmrc for consistent installs

```ini
# .npmrc — commit this file
engine-strict=true
save-exact=true
package-lock=true
```

### engines field in package.json

```json
{
  "engines": {
    "node": ">=24.0.0",
    "npm": ">=10.0.0"
  }
}
```

---

## Docker Best Practices

### Production Dockerfile (multi-stage)

```dockerfile
# Stage 1: Build
FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files first for layer caching
COPY package.json package-lock.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci

# Copy source and build
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Stage 2: Production
FROM node:24-alpine AS production

# Security: run as non-root user
RUN apk add --no-cache dumb-init
USER node

WORKDIR /app

# Copy package files and install production-only deps
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy built output from builder stage
COPY --chown=node:node --from=builder /app/dist ./dist

# Set production environment
ENV NODE_ENV=production

# Use dumb-init for proper signal handling (PID 1 problem)
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "dist/server.js"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => { if (!r.ok) throw 1 })"

EXPOSE 3000
```

### .dockerignore

```
node_modules
dist
.git
.gitignore
.env
.env.*
*.md
.vscode
.idea
coverage
test
*.test.ts
*.spec.ts
docker-compose*.yml
```

### Key Docker decisions explained

| Decision | Why |
|----------|-----|
| Multi-stage build | Final image has no devDependencies, TypeScript, or source code — smaller and more secure |
| `node:24-alpine` | Minimal base image (~50MB vs ~350MB for non-alpine). Pin major version. |
| `USER node` | Run as non-root. The `node` user exists in official Node images. |
| `dumb-init` | Properly forwards signals to Node. Without it, `docker stop` sends SIGTERM but Node (as PID 1) doesn't handle it, causing a 10s timeout then SIGKILL. |
| `npm ci --omit=dev` | No devDependencies in production. Deterministic install. |
| COPY package files first | Docker layer caching: dependencies only rebuild when package files change. |
| `npm cache clean --force` | Reduce image size by removing npm's cache. |

### Docker Compose for development

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      target: builder  # Use build stage for development
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
    volumes:
      - ./src:/app/src  # Hot reload
    depends_on:
      db:
        condition: service_healthy
    command: npx tsx watch src/server.ts

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

---

## Health Check Endpoints

Every production service needs a health check endpoint for container orchestration (Kubernetes, ECS, etc.).

```typescript
// src/health/health.router.ts
import { Router } from 'express';
import { pool } from '../config/database';

const router = Router();

// Liveness probe — is the process alive?
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Readiness probe — can the service handle requests?
router.get('/health/ready', async (req, res) => {
  const checks: Record<string, string> = {};

  try {
    await pool.query('SELECT 1');
    checks.database = 'ok';
  } catch {
    checks.database = 'error';
  }

  // Add more checks: Redis, external APIs, etc.

  const allOk = Object.values(checks).every((v) => v === 'ok');
  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ok' : 'degraded',
    checks,
  });
});

export { router as healthRouter };
```

---

## Graceful Shutdown

When the orchestrator sends SIGTERM, the app should:
1. Stop accepting new connections
2. Finish in-flight requests
3. Close database pools and other resources
4. Exit cleanly

```typescript
// src/server.ts
import { app } from './app';
import { config } from './config/env';
import { pool } from './config/database';
import { logger } from './config/logger';

const server = app.listen(config.PORT, () => {
  logger.info({ port: config.PORT }, 'Server started');
});

// Keep-alive timeout should be higher than the load balancer's idle timeout
server.keepAliveTimeout = 65_000; // AWS ALB default is 60s

const shutdown = async (signal: string) => {
  logger.info({ signal }, 'Shutdown signal received');

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    // Close database pool
    try {
      await pool.end();
      logger.info('Database pool closed');
    } catch (err) {
      logger.error({ err }, 'Error closing database pool');
    }

    process.exit(0);
  });

  // Force exit after timeout
  setTimeout(() => {
    logger.error('Graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, 15_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

---

## Environment Configuration

### NODE_ENV usage

```typescript
// NODE_ENV should ONLY control runtime behavior — not application logic
// Use it for:
const isDev = config.NODE_ENV === 'development';

// 1. Pretty logging in development
if (isDev) { /* pino-pretty transport */ }

// 2. Detailed error responses in development
if (isDev) { /* include stack trace in error response */ }

// 3. Scope validation in development
if (isDev) { /* enable ValidateScopes equivalent */ }

// DON'T use NODE_ENV for:
// - Feature flags (use a proper feature flag system)
// - Database selection (use DATABASE_URL)
// - API keys (use env vars per service)
```

### Production checklist

| Setting | Value | Why |
|---------|-------|-----|
| `NODE_ENV` | `production` | Disables dev tools, enables optimizations |
| `express.json({ limit })` | `'1mb'` or less | Prevents memory exhaustion |
| Trust proxy | `app.set('trust proxy', 1)` | Correct IP behind load balancer |
| HTTPS | Terminate at LB, not Node | Node shouldn't handle TLS directly |
| Logs | JSON to stdout | Let the platform handle log routing |
| Secrets | Env vars / secrets manager | Never in code or config files |

---

## CI/CD Pipeline Essentials

### GitHub Actions example

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm

      - run: npm ci                    # Deterministic install
      - run: npm run lint              # Type check + lint
      - run: npm run build             # Compile TypeScript
      - run: npm test                  # Run all tests
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test
          JWT_SECRET: test-secret-at-least-32-characters-long

      - run: npm audit --audit-level=high  # Security check
```

Keep `node-version` on the same major as the Dockerfile base image (`node:24-alpine` above) — a green CI on
a different major is no evidence the production image runs. Node 18 and 20 are past end-of-life (20 "Iron"
left Maintenance in April 2026); only Active LTS or Maintenance LTS lines belong in a CI matrix.

### Pre-commit hooks (optional)

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.ts": ["eslint --fix", "prettier --write"]
  }
}
```

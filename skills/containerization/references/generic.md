# Generic Multi-Stage Dockerfile Patterns

Language-agnostic patterns for building production-ready container images. Read this when the project is **not** .NET (those have their own references) — typically Node.js, Python, Go, Java, or static sites.

## Required Workflow

1. Detect language, package manager, lockfile, build command, runtime command, and required OS packages.
2. Choose **separate stages** for dependency restore, build/test if needed, and runtime.
3. Copy manifest + lockfiles **before** source files to maximize layer caching.
4. Install dependencies with deterministic commands: `npm ci`, `pip install -r requirements.txt`, `go mod download`, `mvn dependency:go-offline`, etc.
5. Build in a builder image; copy only runtime artifacts into the final image.
6. Run as a **non-root user** where the base image supports it.
7. Add/update `.dockerignore` so build context excludes dependencies, build output, secrets, and VCS noise.
8. Verify with `docker build` when Docker is available; otherwise document the exact command that couldn't run.

## Review Checklist

- Final image excludes source, test files, package caches, and build tools unless required at runtime.
- Lockfile copied and used; dependency installation is reproducible.
- Secrets not copied into the image or baked into `ENV`.
- Runtime user is non-root, or there's a clear reason it can't be.
- Health check, exposed port, entrypoint, and signal handling match the app type.
- Framework-specific publish/build output is used (compiled server bundle, static `dist/`, etc.).

## Defaults

- Prefer official `slim` / `runtime` / `distroless` images over full SDK images in the final stage.
- Pin image tags by `major.minor` when the project doesn't pin more strictly. Avoid `latest`.
- Follow existing project conventions over generic templates.

## Language Notes

### Node.js

```dockerfile
# Build stage
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM node:24-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

Common gotchas:
- Don't bake `NODE_ENV=production` *before* `npm ci` in the build stage — devDeps are needed for building.
- For SSR/Next.js, copy `.next/standalone` and `.next/static` rather than the whole `.next/` for smaller images.

### Python

```dockerfile
FROM python:3.13-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt

FROM python:3.13-slim
WORKDIR /app
COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links /wheels /wheels/*
COPY . .
RUN useradd -r app && chown -R app /app
USER app
CMD ["python", "-m", "myapp"]
```

For `poetry` / `uv`: prefer the lockfile they own — use `poetry export` to `requirements.txt` for the wheel cache pattern.

### Go

```dockerfile
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app ./cmd/app

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

Distroless static gives ~5MB images and runs as non-root by default.

Go's security policy only supports the two most recent major releases. As of 2026-07 that means 1.26 and 1.25; a builder pinned to 1.24 or older no longer receives security fixes and imports CVEs into the build stage.

### Java (Maven)

```dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre
COPY --from=build /src/target/*.jar /app.jar
USER 1000:1000
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

For Spring Boot 3+ with native image: use the `native` profile and `spring-boot:build-image`, or write a separate native Dockerfile with `paketobuildpacks/builder-jammy-tiny`.

## Anti-Patterns

- **Single-stage Dockerfile** that ships SDK + source + build tools. Inflates image, expands attack surface.
- **`COPY . .` before `COPY package.json`.** Breaks Docker's layer cache on every source change.
- **`apt-get install` without `&& rm -rf /var/lib/apt/lists/*`.** Bloats image with package metadata.
- **Running as root in final stage.** Non-root is the default expectation; only deviate with an explicit reason (e.g., needs to bind port < 1024 without `CAP_NET_BIND_SERVICE`).
- **Embedding secrets via `ENV` or build args.** They're visible in image history. Use BuildKit secrets (`--mount=type=secret`) at build time and runtime injection (env files, secret managers, orchestrator) at run time.
- **`HEALTHCHECK` calling `curl localhost`.** Requires curl in image; just use a slim health endpoint and `wget --spider` or built-in tools when available.
- **Not pinning base image** to a digest in supply-chain-sensitive contexts. Use `image@sha256:...` for reproducibility.

## .dockerignore Essentials

```
**/node_modules
**/__pycache__
**/.git
**/.gitignore
**/.dockerignore
**/Dockerfile*
**/.env*
**/*.log
**/.DS_Store
**/dist
**/build
**/.vscode
**/.idea
**/coverage
```

Keep `.env.example` (no real values) but never `.env*` with real values.

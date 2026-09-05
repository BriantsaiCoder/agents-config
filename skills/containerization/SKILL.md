---
name: containerization
description: Use when writing or reviewing Dockerfiles for any stack — multi-stage builds, .dockerignore, Linux/Windows containers, image size, build caching, non-root users, ASP.NET Core, .NET Framework + IIS, Node.js, Python, Go, Java.
---

# Containerization

Use this skill for production-grade container images: small, reproducible, cache-friendly, and safe to run as non-root. The same multi-stage discipline applies across stacks; differences live in language-specific reference files.

## Core Workflow

1. **Detect the stack.** Read `package.json` / `*.csproj` / `pyproject.toml` / `go.mod` / `pom.xml` etc. Identify language, package manager, lockfile, build command, runtime command, target OS (Linux vs Windows), and any required native packages.
2. **Pick the right reference** (see Reference Map below) and read it before editing.
3. **Apply multi-stage discipline:**
   - Stage 1 (builder): SDK / build tools + restore deps + build artifact.
   - Stage 2 (runtime): minimal base + copy only the published output.
4. **Cache lockfile and manifest layers** by copying them *before* source files.
5. **Run as non-root** in the final image where the base supports it.
6. **Maintain `.dockerignore`** so build context excludes dependencies, build output, secrets, and VCS noise.
7. **Verify** with `docker build` when Docker is available; otherwise document the exact blocker.

## Reference Map

| Stack | Read |
|---|---|
| ASP.NET Core / .NET 6+ / Linux container / Kestrel / `mcr.microsoft.com/dotnet/*` | `references/dotnet-aspnet-core.md` |
| ASP.NET .NET Framework / IIS / Windows container / `mcr.microsoft.com/dotnet/framework/*` | `references/dotnet-framework.md` |
| Node.js / Python / Go / Java / generic multi-stage | `references/generic.md` |

For mixed solutions (e.g., .NET 8 API + Python data pipeline) read both relevant references.

## Universal Review Checklist

- Base image matches the target framework/runtime AND OS requirements.
- Build stage restores dependencies before copying full source (cache-friendly).
- Runtime image contains only published output and required runtime dependencies — no SDK, no source, no test fixtures.
- Container runs as non-root where supported by the base image.
- `.dockerignore` excludes build output, VCS files (`.git`), local secrets (`.env*`), dependency caches (`node_modules`, `__pycache__`).
- Image tags pinned at minimum `major.minor`; for supply-chain-sensitive contexts pin to digest.
- Health check, exposed port, entrypoint, and signal handling match the app type.
- No secrets baked via `ENV` or build args. Use BuildKit secrets at build time, env injection at runtime.

## Boundary

This skill covers **Dockerfile authoring**. It does not cover:

- Docker Compose service networking (use ad-hoc docs / Compose reference).
- Kubernetes manifests, Helm charts.
- Infrastructure rollout planning (use `backend-release-verification` / `frontend-release-verification` skills + shared `dev-workflow` [T0-8] / S2 authorization gate).
- CI/CD pipeline definition (separate concern; this skill produces the artifact, the pipeline ships it).

If the user's request is one of the above, point to the appropriate skill instead.

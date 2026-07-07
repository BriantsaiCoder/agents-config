# Codebase Documentation Blueprint

Use this reference when the user asks for `.github/copilot/*.md` style documents — architecture blueprint, code exemplars, folder structure blueprint — generated from a repository scan. This is for **AI-assisted development context files**, not user-facing READMEs.

## When To Use

- Establishing coding standards for a team that uses Copilot/Cursor/Claude Code.
- Documenting an existing codebase to give AI tools authoritative context.
- Onboarding new developers via concrete, evidence-backed reference material.
- Maintaining architectural consistency as the codebase evolves.
- Generating `.github/copilot/*.md` documents for Copilot context.

## Output Modes

| Mode | Produces | Section reference |
|---|---|---|
| `architecture` | `.github/copilot/Project_Architecture_Blueprint.md` | "Architecture Blueprint" below |
| `exemplars` | `.github/copilot/exemplars.md` | "Code Exemplars" below |
| `folder-structure` | `.github/copilot/Project_Folders_Structure_Blueprint.md` | "Folder Structure" below |
| `all` (default) | All three in one pass | All three sections |

## Shared Auto-Detection Pipeline

Run once, reuse for all output modes.

### Step 1: Technology Stack Detection

When project type is auto-detected, scan for:

- **.NET**: `*.sln`, `*.csproj`, `*.fsproj`, `*.vbproj`, `global.json`, `Directory.Build.props`
- **Java**: `pom.xml`, `build.gradle`, `settings.gradle`, `gradlew`
- **JS/TS**: `package.json` deps, `tsconfig.json`
- **React**: `react` in deps, `react-scripts`, `next.config.*`
- **Angular**: `angular.json`, `@angular/*`
- **Vue/Nuxt**: `vue` in deps, `nuxt.config.*`
- **Python**: `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile`
- **Node.js**: `package.json` without React/Angular/Vue markers
- **Flutter**: `pubspec.yaml`, `android/` + `ios/`
- **Go**: `go.mod`, `go.sum`
- **Rust**: `Cargo.toml`, `Cargo.lock`

Record the technology signatures and versions found.

### Step 2: Structural Pattern Detection

- **Monorepo indicators**: `lerna.json`, `nx.json`, `turborepo.json`, `pnpm-workspace.yaml`, multiple project files at root.
- **Microservices indicators**: multiple service directories with repeated structure, per-service `Dockerfile`, inter-service comm (APIs / message brokers), service discovery / API gateway config.
- **Frontend indicators**: `wwwroot/`, `public/`, `dist/`, `static/`, UI framework files, frontend build config (webpack/vite/rollup).
- **Architecture pattern detection** (Clean / Layered / Hexagonal / etc.): analyze folder organization, namespacing, dependency flow, component boundaries, interface segregation.

## Architecture Blueprint Output

A 17-section template covering:

1. Overview — high-level purpose, deployment model.
2. Visualization — C4 / dependency diagrams (ASCII / Mermaid).
3. Core components — concrete classes/modules with file paths.
4. Layers — presentation / domain / data / cross-cutting, mapped to actual folders.
5. Data — entities, persistence, query patterns.
6. Cross-cutting concerns — logging, auth, validation, caching.
7. Service communication — internal RPC, message bus, HTTP clients.
8. Tech-specific patterns — `WebApplication.CreateBuilder`, EF Core context lifetime, DI setup, etc.
9. Implementation patterns — Result type, error handling, async flow.
10. Testing — test pyramid, naming, fixtures, integration setup.
11. Deployment — Docker, CI, environments.
12. Extension — how to add a new feature/module/endpoint.
13. Examples — concrete walkthroughs from the actual code.
14. Decision records — ADRs (link to existing or list inferred decisions).
15. Governance — branching, review, release.
16. New development blueprint — template for new modules.
17. Maintenance metadata — generation date, regen guidance.

Every claim must reference a real file (`src/services/UserService.cs:42`).

## Code Exemplars Output

Identify ~3-5 reference implementations per category. Categories:

- **By Pattern Type**: Repository, Service, Controller, Component, Composable, Hook, Middleware, Filter.
- **By Architecture Layer**: Domain, Application, Infrastructure, Presentation.
- **By File Type**: Test, Migration, DTO, Validator.

Selection criteria:

- File is exemplary of the convention (uses the patterns the team values).
- File is non-trivial (illustrates real decision-making).
- File is stable (recently changed but not actively churning).

For each exemplar, include:

- Path
- 1-2 sentence summary
- The patterns it demonstrates (cite specific lines)
- Why future code in this category should look like this

## Folder Structure Output

Visualization styles:

- **ASCII tree** (default for ≤ 5 levels deep): `└──`, `├──`.
- **Markdown list** (better for nested deep): bulleted hierarchy.
- **Table** (for monorepos): one row per project/package with purpose column.

Include:

- Top-level folders with one-line purpose.
- Key directory analysis by tech stack (`src/`, `app/`, `apps/`, `packages/`, `services/`, `wwwroot/`, etc.).
- File placement patterns ("controllers go in `Controllers/`, named `*Controller.cs`").
- Naming conventions (PascalCase for classes, kebab-case for components, etc.).
- Build organization (where `dist/`, `bin/`, `obj/` go — and confirm they're gitignored).
- Extension templates ("when adding a new service, create…").

## Common Rules (All Modes)

1. **Only reference actual files.** No hypothetical examples, no placeholders. Verify every path exists before writing.
2. **Self-contained output.** Each document readable without external context.
3. **Include generation metadata** — generation date, regen guidance.
4. **Output location**: default `.github/copilot/<filename>.md` unless user specifies otherwise.
5. **Concrete over abstract** — every pattern claim backed by a real file reference.
6. **No version-specific dependencies in architecture docs.** Describe capability ("OAuth 2.0 library") not implementation ("Microsoft.AspNetCore.Authentication.JwtBearer v6.0.1").

## Review Checklist (before committing)

- All file paths verified to exist.
- No hypothetical examples or TODO markers.
- Auto-detection results accurate (spot-check 5 random claims).
- Output to `.github/copilot/` (or user-specified path).
- Generation date + regen guidance included.
- Cross-document consistency (architecture & folder docs agree on layer boundaries).
- For exemplars: max examples per category respected (default 3-5).
- For folder structure: generated dirs (`node_modules`, `bin`, `obj`) excluded unless requested.

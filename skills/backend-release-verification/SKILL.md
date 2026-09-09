---
name: backend-release-verification
description: "Assess production readiness of backend, API, worker, or service changes when preparing a release or deployment."
---

# Backend Release Verification

Evidence matched to production risk. Use repo's existing scripts / CI / envs / deploy docs first; don't invent tools or claim deploy-ready without concrete command + env + rollback evidence.

## Workflow

1. **Inspect repo** — `AGENTS.md`, CI, build scripts, test projects, Dockerfile, migration, health endpoints, deploy docs. Repo decides commands; skill decides minimum evidence.
2. **Classify by highest-risk behavior**:
   - Logic → build + unit/integration.
   - API contract → contract/smoke + back-compat.
   - DB/migration → apply test + schema compat + rollback.
   - Auth / secrets / payment / prod config → security regression + rollback note.
   - Jobs / queues / integrations → dependency-path smoke + retry/idempotency.
   - Dep / container / runtime → full suite + artifact verify + staging smoke.
   - Perf path → baseline compare before promotion.
3. **Narrowest blocking gate set.** Expand for shared / high-risk / infra / migration.
4. **Tool/env absent** → report gap + lightweight verification. Don't scaffold infra unless asked.

## Minimum Gate Map

| Gate | Evidence |
|---|---|
| Artifact | CI artifact / image traceable to SHA / version / digest |
| Build | Release build + typecheck / lint / static analysis |
| Tests | Unit + integration + contract/API smoke |
| Data | Migration tested or N/A; rollback / forward-fix known |
| Security | Secret + dep + container scan; auth regression when touched |
| Staging | Staging deploy + API smoke (`/health`, k6, Schemathesis) |
| Reliability | Perf baseline for hot paths; queue / worker smoke |
| Observability | Health, logs, metrics, traces, alerts for go/no-go |
| Release | Rollback plan, go/no-go metrics, owner, residual risk |

Low-risk → lightweight subset; report MUST list skipped + residual risk.

## Skill Routing

- Rollout / rollback — shared `dev-workflow` [T0-8] / S2 authorization gate.
- `dotnet-testing-best-practices` / `nodejs-best-practices` — tests.
- `auth-implementation-patterns` — auth / authz / tenant.
- `containerization` — Docker / image / health.
- `dotnet-logging-best-practices` — structured logs / correlation.
- `dapper-` / `ef-core-` / `mysql-` / `postgresql-best-practices` — data / migration.
- `dependency-security-scan` — secret / dep CVE / image / SBOM.
- Smoke: `curl --fail` (health); `k6 run --vus 1 --duration 30s` (API); `schemathesis run <openapi-url>` (schema).
- Contract: Pact / Schemathesis / Dredd.

## Completion Report

Commands + pass/fail; env (staging URL); artifact (SHA / version / digest); migration + rollback path; security / perf / observability gates run or skipped; go/no-go + owner + gaps + residual risk.

## Common Mistakes

- CI green ≠ prod readiness.
- Memory commands vs repo scripts.
- Ignoring migrations because build passed.
- Skipping staging smoke for API / worker / queue.
- Release without rollback + observability.
- Pact provider verification skipped.

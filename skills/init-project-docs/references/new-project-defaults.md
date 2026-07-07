# New Project Defaults — Observability / Dependency / CI-CD

Apply when scaffolding a **new** project. Skip if project already has equivalents. Documenting an existing project? Don't impose these.

## Observability

- **Tracing:** OpenTelemetry. .NET Core → Serilog + OTel exporter. Node.js → `@opentelemetry/*`.
- **Health endpoints:** `/health` (liveness) + `/health/ready` (readiness).
- **Correlation ID:** HTTP header `X-Correlation-ID`; log field `correlationId`.
- **Pre-launch verification:** metrics (RED — rate / error / duration), logs, traces all wired.

## Dependency Management

- **Auto-update:** Renovate or Dependabot.
- **Merge policy:** auto-merge patch, review minor, discuss major via PR.
- **Lockfile:** committed. If no pre-commit hook, propose `lint-staged` + check-lockfile rule.

## CI / CD

- **Minimum pipeline:** lint → test → build → (optional) security scan.
- **Release artifact:** SBOM in CycloneDX format.

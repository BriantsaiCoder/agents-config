---
name: dependency-security-scan
description: "Set up or assess secret, dependency, container, and SBOM scanning when security scan coverage or CI gates are requested."
---

# Dependency & Security Scan

## Core Principle

For release/setup scope, define explicit CI thresholds. A scan-only baseline supplies evidence and recommendations without changing hooks or CI policy. Secret leakage is non-downgradable — any positive finding blocks merge regardless of severity. Dependency / container CVEs are downgradable only when threshold and rationale are explicit.

## Tool & Threshold References

- Tool selection per layer (secret / dep / container / SBOM) — see [tool-matrix](references/tool-matrix.md).
- CI gate thresholds + failure response + exception process — see [ci-gate-threshold](references/ci-gate-threshold.md).

## Workflow

### Authorized new project setup

1. Add `gitleaks` pre-commit hook (catch secrets before they touch the repo).
2. Add CI workflow with one tool per layer per `tool-matrix.md`.
3. Generate SBOM as release artifact.
4. Document gate thresholds in `SECURITY.md` or repo README.

### Existing project audit (one-shot baseline)

1. Run applicable scans in the authorized environment and enumerate findings; do not upload source or findings to a new external scanner without authorization.
2. For scan-only scope, report severity, remediation priorities, and proposed CI thresholds.
3. Implement fixes or gate setup only within existing exact authorization. Prepare concrete hook/CI-policy changes and confirm uncovered effects before enabling them. Preserve secret blocking and documented CVE exceptions.

### Failure response

See [ci-gate-threshold](references/ci-gate-threshold.md) for secret post-merge / new CVE / container CVE handling.

## Common Mistakes

- Running scan once locally and never adding to CI → regression sneaks in next PR.
- Dependency scan only checking direct deps and missing transitives.
- Container scan only against base image, ignoring application-layer dependencies copied into the image.
- SBOM generated but not attached to release artifact → cannot answer "what versions are in production?" during incident response.
- Treating "high CVE acceptable for now" as permanent → always require expiry date and re-review trigger.
- Two overlapping tools producing duplicate alerts → triage fatigue, real signals get ignored.
- Running scan only on default branch, not on PRs → bad code merges first, scan fails after.

## Skill Routing

- `containerization` for Dockerfile / image build best practices that minimize CVE surface (smaller base, multi-stage, non-root).
- `auth-implementation-patterns` for application-layer auth secrets handling (JWT signing keys, refresh token rotation).
- `backend-release-verification` for how this scan fits into the broader release gate map.
- `init-project-docs` for scaffolding `SECURITY.md` and CI workflow templates in new projects.

## Completion Report

When claiming security scan is set up, include:

- Tools chosen per layer with rationale.
- CI workflow path and trigger (PR / push / schedule).
- Gate threshold per layer (what blocks vs warns).
- Baseline findings count after first run + remediation plan.
- SBOM artifact location and retention policy.
- Exception process for accepted CVEs (owner + expiry).

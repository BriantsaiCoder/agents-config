---
name: security-audit
description: "Run a whole-codebase adversarial security audit with persisted evidence and independent validation when the user requests that full audit scope."
---

# Security Audit

You are a security auditor. Your job is to find **exploitable vulnerabilities with real impact**.

## Platform terminology

This skill is agent-neutral. In the methodology:

- **Task tool** means the coding agent's delegation or sub-agent mechanism.
- **`research` agent** means a delegated agent optimized for focused codebase exploration and factual validation.
- **`general` agent** means a delegated agent that can investigate a substantial, independently scoped attack surface.
- **`subagent_type`** means the equivalent delegated-agent role supported by the current platform.

Delegation follows shared `dev-workflow` INT-4: use it only for substantial independent work where it materially improves coverage or wall-clock time, keep the spawn count low, and let the main context handle small or tightly coupled work. Preserve the Phase 3 independent security-validation boundary through the separate-validator or fresh-context fallback defined in `VALIDATION-AND-REPORTING.md`; if neither is available, keep candidates unconfirmed under that file's retention contract.

## Setup and principles

[setup.md](references/setup.md) owns target／output-directory resolution and prior-run coverage; load it before Phase 1. [principles.md](references/principles.md) owns the exploitability bar, dynamic baseline, severity axes, and the anti-pattern list; load it before Phase 2, reuse that version when rating findings, and reload only when missing from context or changed.

## Workflow overview

Follow all five phases in order:

1. **Recon** — Run Phase 1 from [RECONNAISSANCE.md](RECONNAISSANCE.md) to map the application's architecture, trust boundaries, and input surfaces.
2. **Hunt** — Use [HUNTING.md](HUNTING.md) for Phase 2 orchestration, methodology, and validation rules; select scopes from [ATTACK-CLASSES.md](ATTACK-CLASSES.md).
3. **Validate** — Use Phase 3 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md) to complete every schema-backed factual and remediation field, consolidate duplicates, and independently try to disprove the entire candidate record.
4. **Report** — Use Phase 4 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md) to derive `REPORT.md` and `FINDINGS-DETAIL.md` from validated records.
5. **Structured output and reconciliation** — Use Phase 5 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md), `report-schema.json`, and `validate-findings.cjs` to serialize and structurally validate the Phase 3 records, then reconcile the prose outputs without adding unvalidated content.

---
name: security-audit
description: "Run a whole-codebase adversarial security audit with persisted evidence and independent validation when the user requests that full audit scope."
---

# Security Audit

You are a security auditor. Your job is to find **exploitable vulnerabilities with real impact**.

## Platform terminology

This skill is agent-neutral. In the methodology:

- **Task tool** means the coding agent's delegation or sub-agent mechanism.
- **`research` agent** means a delegated agent optimized for focused codebase exploration and factual verification.
- **`general` agent** means a delegated agent that can investigate broadly and spawn focused research agents.
- **`subagent_type`** means the equivalent delegated-agent role supported by the current platform.

Use the platform's equivalent capabilities while preserving the specified roles, parallelism, prompts, and independence boundaries.

## Setup and principles

[setup.md](references/setup.md) owns target／output-directory resolution and prior-run coverage; load it before Phase 1. [principles.md](references/principles.md) owns the exploitability bar, dynamic baseline, severity axes, and the anti-pattern list; load it before Phase 2 and again when rating findings.

## Workflow overview

Follow all six phases in order:

1. **Recon** — Run Phase 1 from [RECONNAISSANCE.md](RECONNAISSANCE.md) to map the application's architecture, trust boundaries, and input surfaces.
2. **Hunt** — Use [HUNTING.md](HUNTING.md) for Phase 2 orchestration, methodology, and validation rules; select scopes from [ATTACK-CLASSES.md](ATTACK-CLASSES.md).
3. **Validate** — Use Phase 3 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md) to consolidate duplicates and independently try to disprove every finding.
4. **Report** — Use Phase 4 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md) to write `REPORT.md` and `FINDINGS-DETAIL.md`.
5. **Structured output** — Use Phase 5 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md), `report-schema.json`, and `validate-findings.cjs` to write and validate `findings.json`.
6. **Independent verification** — Use Phase 6 in [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md) to verify every factual claim and reconcile all outputs.

# security-audit

A coding-agent skill that turns your agent into a security auditor. It runs a five-phase pipeline -- recon, hunting, independent adversarial validation, reporting, and reconciled structured output -- to find exploitable vulnerabilities with real impact. Delegation is conditional on substantial independent work under the shared workflow.

This is the skill that seeded Cloudflare's vulnerability discovery harness, described in [Build your own vulnerability harness](https://blog.cloudflare.com/build-your-own-vulnerability-harness). The harness grew into a multi-stage, fleet-wide system; this skill is the single-repo starting point it evolved from.

## What it does

The skill runs a structured audit in five phases:

1. **Recon** -- map the application's architecture, trust boundaries, and input surfaces. Produces `architecture.md`.
2. **Hunt** -- attack the codebase from relevant angles (injection, access control, business logic, cryptography, feature abuse, chained attacks, and a wildcard), delegating only substantial independent tracks.
3. **Validate** -- complete each schema-backed candidate record, then have an independent validator try to *disprove* every factual and remediation field. Adversarial review kills false positives.
4. **Report** -- derives `REPORT.md` and `FINDINGS-DETAIL.md` from the validated records.
5. **Structured output and reconciliation** -- serializes those records to `findings.json`, validates structure with `validate-findings.cjs`, and reconciles the prose outputs without adding unvalidated content.

Multiple runs against the same repo are additive. Each run explores different code paths; the skill reads prior `findings.json` files to skip known issues and target gaps.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Platform terminology, workflow overview, and pointers to setup and principles |
| `references/setup.md` | Prerequisites, output directory default, and prior-run context |
| `references/principles.md` | Core principles and audit anti-patterns |
| `RECONNAISSANCE.md` | Phase 1 reconnaissance prompts and synthesis instructions |
| `HUNTING.md` | Phase 2 orchestration, hunting methodology, and validation rules |
| `ATTACK-CLASSES.md` | Core, wildcard, and obvious-things attack prompts |
| `VALIDATION-AND-REPORTING.md` | Phases 3–5 validation, reporting, and reconciliation |
| `report-schema.json` | JSON schema for `findings.json` (confirmed and rejected finding structures) |
| `validate-findings.cjs` | Zero-dependency Node.js validator that checks `findings.json` against the schema |

## Installation

Install the skill with the [Skills CLI](https://skills.sh):

```bash
npx skills add https://github.com/cloudflare/security-audit-skill \
  --skill security-audit
```

Use `--global` for a user-level installation:

```bash
npx skills add https://github.com/cloudflare/security-audit-skill \
  --skill security-audit \
  --global
```

Run `npx skills --help` for agent-selection and non-interactive options.

## Usage

Start your coding agent in (or pointed at) the codebase you want to audit, then ask it to do a security audit:

```
security audit this codebase
```

```
find security vulnerabilities in ./src
```

```
do a security review, output to ~/audits/my-project
```

The skill activates automatically when the request matches its trigger (security audit, find vulnerabilities, pen-test the code, etc.). It defaults the output directory to `~/security-audit-skill/<repo-name>/run-<N>` and asks only when that path is not writable.

## Requirements

- A coding agent with tool use and an independent validation path; delegation support can parallelize substantial independent tracks
- Node.js (for `validate-findings.cjs` schema validation in Phase 5)

## Design principles

- **Only report what you can exploit.** Every finding needs a concrete attack scenario, not "an attacker could theoretically..."
- **Adversarial validation.** The agent that checks a finding is never the agent that found it.
- **Severity requires impact.** Likelihood x impact, not deviation from a checklist.
- **Defense-in-depth gaps are not vulnerabilities.** If Layer A prevents the attack, the absence of Layer B is a hardening note.
- **Multiple runs improve coverage.** Testing shows a single run finds roughly half the total vulnerabilities across multiple runs.

## Contact

Questions, feedback, or comparing notes on AI-driven security tooling: security-ai-research@cloudflare.com

## License

MIT -- see [LICENSE](LICENSE).

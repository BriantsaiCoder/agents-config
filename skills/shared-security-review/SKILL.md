---
name: shared-security-review
description: 'Use when asked for a focused code security review — "check this repo for SQL injection or XSS", "is my code secure", "map the attack surface" — or to scan a path, branch, or every changed file for injection, exposed secrets, weak crypto, broken auth/access control, insecure dependencies, or business-logic flaws. Uses cross-file data-flow reasoning across common languages including C#/.NET. CI/CD gates, SBOM, or container scans → dependency-security-scan. Whole-codebase adversarial audit that persists artifacts → security-audit.'
---

# Security Review

AI scanner reasoning like a human researcher — data flow, component interaction, beyond pattern-matching.

## When to Use

- "Scan / audit / review for security"
- Injection, secrets, weak crypto, broken auth, IDOR, SSRF
- Dependencies CVEs, user input → dangerous sinks
- `/shared-security-review` or `/shared-security-review <path>`

## How It Works

1. Reads with context, intent, data flow.
2. Traces across files.
3. Self-verifies to filter false positives.
4. Severity: CRITICAL / HIGH / MEDIUM / LOW / INFO.
5. Proposes targeted patches.
6. Requires human approval; nothing auto-applied.

## Workflow

For a branch/diff review, first account for every changed file with
`references/changed-file-attack-surface.md`. Then follow the 8 steps in
`references/workflow.md`: Scope → Dependencies → Secrets → Vulnerability Scan →
Cross-File Flow → Self-Verify → Report → Patches.

## Severity Guide

| Severity | Meaning | Example |
|---|---|---|
| CRITICAL | Immediate exploit; breach likely | SQLi, RCE, auth bypass |
| HIGH | Exploit path exists | XSS, IDOR, hardcoded secrets |
| MEDIUM | Conditional / chaining | CSRF, open redirect, weak crypto |
| LOW | Best-practice violation | Verbose errors, missing headers |
| INFO | Observation | Outdated dep without CVE |

## Output Rules

- Findings summary table first (counts by severity).
- Never auto-apply patches; human review only.
- Confidence rating per finding (High / Medium / Low).
- Group by category, not file.
- Specific: file path, line, snippet.
- Plain-English risk: what attacker could do.
- Clean → "No vulnerabilities found" + scope.

## Reference Files

- `references/workflow.md` — 8-step workflow
- `references/vuln-categories.md` — SQLi / XSS / cmdi / SSRF / BOLA / IDOR / JWT / CSRF / secrets / crypto / supply chain / race / path traversal / error-path handling
- `references/secret-patterns.md` — regex / entropy / CI-CD risks (.env, Actions, Docker, Terraform)
- `references/language-patterns.md` — Express / React / Next / Django / Flask / FastAPI / Spring / PHP / Go / Rails / Rust
- `references/vulnerable-packages.md` — npm / pip / Maven / Rubygems / Cargo / Go CVE watchlist
- `references/report-format.md` — structured output template
- `references/changed-file-attack-surface.md` — exhaustive internal coverage ledger for branch/diff reviews

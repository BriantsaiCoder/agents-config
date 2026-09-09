---
name: shared-security-review
description: "Review security of a specified code path, diff, or focused attack surface; propose evidence-backed fixes. Whole-codebase adversarial audits use security-audit."
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
6. Reviewers stay read-only. For an authorized review-and-fix request, return accepted findings to the implementation owner for scoped fixes and verification under shared S2.

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
- A review-only request produces findings. Existing authorization for specific fixes permits the implementation owner to apply them under S2; it does not authorize reviewer writes or unrelated side effects.
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

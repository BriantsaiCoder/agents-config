<!-- last-verified: 2026-07-26 -->
# Security Review Workflow

Use the applicable stages to cover the requested scope; prior unchanged evidence may be reused. Review completion requires traceable scope, cross-file evidence, and a disposition for every finding.

## Step 1 — Scope Resolution

- If a path was provided (`/shared-security-review src/auth/`), scan only that scope.
- Use the stated path, diff, or attack surface. If scope is materially unclear, inspect repository context and clarify only the missing boundary; a full adversarial audit with persisted artifacts routes to `security-audit`.
- Identify language(s) and framework(s) (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile`, `composer.json`, etc.).
- Read `language-patterns.md` to load language-specific vulnerability patterns.

## Step 2 — Dependency Audit

Audit dependencies first (fast wins):

- **Node.js** — `package.json` + `package-lock.json`
- **Python** — `requirements.txt` / `pyproject.toml` / `Pipfile`
- **Java** — `pom.xml` / `build.gradle`
- **Ruby** — `Gemfile.lock`
- **Rust** — `Cargo.toml`
- **Go** — `go.sum`

Flag packages with known CVEs, deprecated crypto libs, or suspiciously old pinned versions.

**REQUIRED SUB-SKILL:** Use `dependency-security-scan` with a live advisory
source. Use `vulnerable-packages.md` only for review signals and source routing;
it is not an authoritative safe-version table.

## Step 3 — Secrets & Exposure Scan

Scan ALL files (config, env, CI/CD, Dockerfiles, IaC):

- Hardcoded API keys, tokens, passwords, private keys
- `.env` files committed by mistake
- Secrets in comments or debug logs
- Cloud credentials (AWS, GCP, Azure, Stripe, Twilio, etc.)
- DB connection strings with embedded credentials

Read `secret-patterns.md` for regex patterns and entropy heuristics.

## Step 4 — Vulnerability Deep Scan

Reason about the code — don't pattern-match. Read `vuln-categories.md` for full per-category detail.

**Injection**

- SQL: raw queries, ORM misuse, second-order SQLi
- XSS: unescaped output, raw HTML insertion APIs (e.g. React's `dangerouslySetInnerHTML`, `innerHTML`), template injection
- Command: `exec` / `spawn` / `system` with user input
- LDAP, XPath, Header, Log injection

**Auth & Access**

- Missing auth on sensitive endpoints
- BOLA / IDOR
- JWT weaknesses (`alg:none`, weak secret, no expiry)
- Session fixation, missing CSRF
- Privilege escalation paths
- Mass assignment / parameter pollution

**Data Handling**

- Sensitive data in logs, errors, API responses
- Missing encryption at rest / in transit
- Insecure deserialization
- Path traversal
- XXE
- SSRF

**Cryptography**

- MD5 / SHA1 / DES for security
- Hardcoded IVs or salts
- `Math.random()` for tokens
- Missing TLS cert validation

**Business Logic**

- TOCTOU race conditions
- Integer overflow in financial calc
- Missing rate limit on sensitive endpoints
- Predictable resource identifiers

## Step 5 — Cross-File Data Flow

Holistic pass:

- Trace user-controlled input from entry points (HTTP params/headers/body, file uploads) to sinks (DB query, `exec`, HTML output, file write).
- Identify vulnerabilities only visible across files.
- Check trust boundaries between services / modules.

## Step 6 — Verdict, Confidence & Severity

For EACH finding — **record, do not delete**. Step 7 is the only place findings leave this
review, so anything dropped here is unrecoverable downstream; a reviewer re-judging its own
findings before reporting drops borderline-but-real ones. Same rationale as `[S5-4]` in
`../../dev-workflow/SKILL.md` (host path: `~/.agents/skills/dev-workflow/SKILL.md`).

1. Re-read the code with fresh eyes.
2. Ask: "Is this actually exploitable, or did I miss sanitization?" — record the answer as the
   confidence rating below; do not use it as a delete condition.
3. Assign a **Verdict** — this replaces the old "discard" step, so a finding you now believe
   is wrong still reaches the report, labelled. (Named Verdict, not Disposition: `report-format.md`
   already uses Disposition for the Changed-file Coverage Ledger's per-file column, whose values
   are mapped / no attack surface / skipped — a different axis.)
   - `exploitable` — stands as written.
   - `mitigated-upstream` — framework / middleware already handles it. Name the mitigation.
   - `not-exploitable` — you re-read and it does not hold (sanitization was present, path
     unreachable). Say what you missed the first time. This is the slot for a false positive;
     do not express it by lowering confidence, and do not delete the finding.
4. Assign a **Confidence** per the Ratings Guide in `report-format.md` — that table is the single
   definition; do not restate or re-scale it here.
5. Assign final severity (CRITICAL / HIGH / MEDIUM / LOW / INFO) from attacker prerequisites, reachability, and concrete impact. Vulnerability category alone does not determine severity; keep confidence independent. Explain the rating and preserve findings for caller triage.

Report every finding in Step 7 with Verdict, Confidence and severity attached. Filtering, if
wanted, is the caller's pass — not this one.

## Step 7 — Generate Report

Output per `report-format.md`.

## Step 8 — Propose Patches

For every CRITICAL and HIGH finding:

- Show vulnerable code (before).
- Show fixed code (after).
- Explain what changed and why.
- Preserve original style, names, structure.
- Add an inline comment explaining the fix.

Report the actual mode and state. For review-only work, state that proposed patches were not applied. For an already-authorized review-and-fix request, hand accepted findings to the implementation owner, who completes scoped fixes and applicable verification under shared S2; retain any high-risk or external-effect gate not covered by the authorization.

# Security Review Workflow

Follow these steps **in order** for every review.

## Step 1 — Scope Resolution

- If a path was provided (`/security-review src/auth/`), scan only that scope.
- If no path given, scan the **entire project** starting from the root.
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

Flag packages with known CVEs, deprecated crypto libs, or suspiciously old pinned versions. Read `vulnerable-packages.md` for the curated watchlist.

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

## Step 6 — Self-Verification

For EACH finding:

1. Re-read the code with fresh eyes.
2. Ask: "Is this actually exploitable, or did I miss sanitization?"
3. Check if framework / middleware already handles this upstream.
4. Downgrade or discard non-genuine findings.
5. Assign final severity: CRITICAL / HIGH / MEDIUM / LOW / INFO.

## Step 7 — Generate Report

Output per `report-format.md`.

## Step 8 — Propose Patches

For every CRITICAL and HIGH finding:

- Show vulnerable code (before).
- Show fixed code (after).
- Explain what changed and why.
- Preserve original style, names, structure.
- Add an inline comment explaining the fix.

State explicitly: **"Review each patch before applying. Nothing has been changed yet."**

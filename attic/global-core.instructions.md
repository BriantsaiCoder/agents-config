---
name: "Global Core Engineering Rules"
description: "Portable core rules for Copilot across workspaces."
applyTo: "**"
---

> FP:COPILOT-CORE-2026Q3 — resident core rules for Copilot (B0 stopgap; superseded by generated file at migration Step 9).

# Core priorities

- Follow this order when instructions conflict: user request > repository instructions > these global rules.
- Do not claim completion without concrete evidence.

# Safety and security

- Never assume file paths, API names, or config keys without verifying them.
- Do not store tokens, credentials, or secrets in frontend `localStorage` or `sessionStorage`.
- If a task is ambiguous, stop and ask instead of guessing.

# Workflow and change discipline

- Plan first for non-trivial work (multi-step, multi-file, or architecture-impacting tasks).
- Keep changes scoped to the request; avoid unrelated refactors in the same change.
- Follow the existing style and conventions in edited files.
- Remove dead code introduced by your own changes.

# Verification and quality

- Define outcomes in verifiable terms (for example: failing test first, then passing after fix).
- Run relevant build/test/lint checks before claiming a task is done.
- If checks cannot run, explicitly state why and what remains unverified.

# Git guardrails

- Never force-push to `main` or `master`.
- Only use `--force-with-lease` on non-protected branches when force push is truly required.
- Keep dependency manifest and lockfile updates in the same commit.

# High-risk change safety

- High-risk changes (auth, payment, DB migration, bulk data deletion, crypto, multi-tenant data boundaries, rate limiting, deploy pipelines) must include a rollback strategy.
- DB migrations must be staged: expand → dual-write → backfill → switch reads → remove legacy. Never ship a breaking schema change in the same deploy as its consumer changes.

# Merge gate

- Before merging a PR, require green CI and address bot review comments. Bot review is asynchronous (typically 2–3 minutes after the PR opens); an empty review at open time is a delay, not an absence — wait or re-check before concluding the PR has no bot feedback.

# Documentation and comments

- Public APIs should include doc comments (purpose, parameters, return value, and errors if applicable).
- Comments should explain **why**, not restate what the code already says.

# Communication

- When asking for decisions, provide options with one recommended default and key trade-offs.

---
name: acquire-codebase-knowledge
description: "Map repository architecture, conventions, and risks when repository-wide discovery or onboarding is requested; documentation refresh uses init-project-docs."
metadata:
  argument-hint: 'Optional: specific area to focus on, e.g. "architecture only", "testing and concerns"'
---

# Acquire Codebase Knowledge

Maps the requested codebase scope from verifiable files or terminal output — never infer.

## Output Contract

1. Full map mode 建立並驗證完整七份文件：`docs/codebase/STACK.md`, `STRUCTURE.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `INTEGRATIONS.md`, `TESTING.md`, `CONCERNS.md`.
2. Focus Area Mode 只更新授權的 focus 文件。
3. Every claim is traceable to source / config / terminal output.
4. Unknowns are marked `[TODO]`; intent-dependent gaps are marked `[ASK USER]`.
5. Each changed doc has an "evidence" list with file paths.
6. Final response includes numbered `[ASK USER]` questions + intent-vs-reality divergences.

## Workflow

```
- [ ] Phase 1: Scan + read intent
- [ ] Phase 2: Investigate per template
- [ ] Phase 3 (Full map only): Populate seven docs
- [ ] Phase 4: Validate + present + resolve [ASK USER]
```

## Focus Area Mode

Determine the focus from the request and existing docs (for example, "architecture only" or "testing and concerns"):

1. Run the Phase 1 scan for the requested focus and keep its output in the session. Focus and read-only scans use stdout; pass `--output` only when persistence of that scan artifact is authorized.
2. 只更新授權的 focus 文件；非 focus 文件保持既有狀態，不補 `[TODO]` stub。
3. Validate only the changed focus documents in Phase 4.

Read-only mode 只在 session 回傳分析，不建立文件。Full map mode 才擁有完整七份文件的建立與驗證責任。

### Phase 1: Scan + Intent

1. From project root, use stdout for Focus Area and read-only work so the scan creates no documentation artifact:
   ```bash
   python3 "$SKILL_ROOT/scripts/scan.py"
   ```
   For Full map mode, or when the request explicitly authorizes a persistent scan artifact, write it under the authorized output path:
   ```bash
   python3 "$SKILL_ROOT/scripts/scan.py" --output docs/codebase/.codebase-scan.txt
   ```
2. Read `PRD` / `TRD` / `README` / `ROADMAP` / `SPEC` / `DESIGN`.
3. Summarise stated intent before reading source.

### Phase 2: Investigate

Use scan output. Load [`references/inquiry-checkpoints.md`](references/inquiry-checkpoints.md) for per-template questions.

Stack ambiguous (multi-manifest / unfamiliar files / no `package.json`) → [`references/stack-detection.md`](references/stack-detection.md).

Monorepo / TS aliases / generated output / churn-fragile traps → [`references/discovery-pitfalls.md`](references/discovery-pitfalls.md).

### Phase 3: Populate (Full map only)

Copy `assets/templates/` into `docs/codebase/`. Fill order:

1. `STACK.md` — language, runtime, frameworks, deps
2. `STRUCTURE.md` — layout, entry points, key files
3. `ARCHITECTURE.md` — layers, patterns, data flow
4. `CONVENTIONS.md` — naming, format, error handling, imports
5. `INTEGRATIONS.md` — APIs, DBs, auth, monitoring
6. `TESTING.md` — frameworks, organization, mocking
7. `CONCERNS.md` — debt, bugs, security, perf

`[TODO]` for code-undeterminable; `[ASK USER]` for team intent.

Focus Area Mode skips this seven-document generation step and updates only the already authorized focus documents from the Phase 2 evidence.

### Phase 4: Validate

1. Validate each against `inquiry-checkpoints.md`.
2. Confirm evidence ref per non-trivial claim.
3. Fix + re-validate until all pass.

Present summary, numbered `[ASK USER]`, Intent vs Reality divergences.

Pass: no unsupported claims, no empty required sections, unknowns `[TODO]`, intent gaps `[ASK USER]`.

## Bundled Assets

- `scripts/scan.py` — Phase 1
- `references/inquiry-checkpoints.md` — Phase 2 per-template
- `references/stack-detection.md` — Phase 2 if ambiguous
- `references/discovery-pitfalls.md` — monorepo / aliases / generated
- `assets/templates/*.md` — Phase 3

Default: only "Core Sections (Required)". Extended: add optional only if complexity justifies.

## See also

Engineer-facing docs in `docs/codebase/`. For AI-assist context (`CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md` / `.claude/`), use `init-project-docs` — complementary, run in sequence.

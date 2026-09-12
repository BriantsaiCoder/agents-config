---
name: acquire-codebase-knowledge
description: "Repo 全貌探索／onboarding 時使用：依 evidence 建立地圖；七份文件只在文件產出已授權時寫入，局部導覽用 mp-zoom-out。"
metadata:
  argument-hint: 'Optional: specific area to focus on, e.g. "architecture only", "testing and concerns"'
---

# Acquire Codebase Knowledge

Maps the requested codebase scope from verifiable files or terminal output — never infer.

## Output Contract

1. 文件產出已授權的 Full map mode 建立並驗證完整七份文件：`docs/codebase/STACK.md`, `STRUCTURE.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `INTEGRATIONS.md`, `TESTING.md`, `CONCERNS.md`.
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

Default to repository-wide analysis unless the user requests a narrower focus. Enter Full map mode when the existing request or approval covers the seven codebase documents; complete that authorized output without asking again. Otherwise return the map in the session and skip Phase 3. An explicit read-only request creates no files.

## Focus Area Mode

Determine the focus from the request and existing docs (for example, "architecture only" or "testing and concerns"):

1. Run the Phase 1 scan for the requested focus and keep its output in the session. Focus and read-only scans use stdout; pass `--output` only when persistence of that scan artifact is authorized.
2. 只更新授權的 focus 文件；非 focus 文件保持既有狀態，不補 `[TODO]` stub。
3. Validate only the changed focus documents in Phase 4.

Read-only mode 只在 session 回傳分析，不建立文件。Full map mode 才擁有完整七份文件的建立與驗證責任。

### Phase 1: Scan + Intent

1. From project root, use stdout unless a persistent scan artifact is already authorized:
   ```bash
   python3 "$SKILL_ROOT/scripts/scan.py"
   ```
   When the existing request or approval covers a persistent scan artifact, write it under the authorized output path:
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

In authorized Full map mode, copy `assets/templates/` into `docs/codebase/`. Fill order:

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

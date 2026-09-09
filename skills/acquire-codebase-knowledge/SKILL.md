---
name: acquire-codebase-knowledge
description: "Map an existing repository into evidence-backed codebase documents when the user requests repository-level discovery, documentation, or onboarding."
metadata:
  argument-hint: 'Optional: specific area to focus on, e.g. "architecture only", "testing and concerns"'
---

# Acquire Codebase Knowledge

Produces seven docs in `docs/codebase/`. Only document what is verifiable from files or terminal output — never infer.

## Output Contract

1. These files exist in `docs/codebase/`: `STACK.md`, `STRUCTURE.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `INTEGRATIONS.md`, `TESTING.md`, `CONCERNS.md`.
2. Every claim traceable to source / config / terminal output.
3. Unknowns marked `[TODO]`; intent-dependent marked `[ASK USER]`.
4. Each doc has an "evidence" list with file paths.
5. Final response includes numbered `[ASK USER]` questions + intent-vs-reality divergences.

## Workflow

```
- [ ] Phase 1: Scan + read intent
- [ ] Phase 2: Investigate per template
- [ ] Phase 3: Populate seven docs
- [ ] Phase 4: Validate + present + resolve [ASK USER]
```

## Focus Area Mode

User supplies focus ("architecture only" / "testing and concerns"):

1. Run Phase 1 in full.
2. Complete focus-area docs first.
3. Non-focus docs: keep required sections, `[TODO]` unknowns.
4. Phase 4 validation on all seven.

### Phase 1: Scan + Intent

1. From project root:
   ```bash
   python3 "$SKILL_ROOT/scripts/scan.py" --output docs/codebase/.codebase-scan.txt
   ```
2. Read `PRD` / `TRD` / `README` / `ROADMAP` / `SPEC` / `DESIGN`.
3. Summarise stated intent before reading source.

### Phase 2: Investigate

Use scan output. Load [`references/inquiry-checkpoints.md`](references/inquiry-checkpoints.md) for per-template questions.

Stack ambiguous (multi-manifest / unfamiliar files / no `package.json`) → [`references/stack-detection.md`](references/stack-detection.md).

Monorepo / TS aliases / generated output / churn-fragile traps → [`references/discovery-pitfalls.md`](references/discovery-pitfalls.md).

### Phase 3: Populate

Copy `assets/templates/` into `docs/codebase/`. Fill order:

1. `STACK.md` — language, runtime, frameworks, deps
2. `STRUCTURE.md` — layout, entry points, key files
3. `ARCHITECTURE.md` — layers, patterns, data flow
4. `CONVENTIONS.md` — naming, format, error handling, imports
5. `INTEGRATIONS.md` — APIs, DBs, auth, monitoring
6. `TESTING.md` — frameworks, organization, mocking
7. `CONCERNS.md` — debt, bugs, security, perf

`[TODO]` for code-undeterminable; `[ASK USER]` for team intent.

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

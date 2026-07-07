---
name: init-project-docs
description: Use when initializing or refreshing AI-assisted project documentation across Claude Code / Codex CLI / GitHub Copilot CLI — detects the running host and produces its native files (CLAUDE.md / AGENTS.md / copilot-instructions.md, settings, rules, hooks, agents), plus host-neutral README, coding standards, architecture blueprints, docs/. For repo-level discovery producing docs/codebase maps, use acquire-codebase-knowledge.
---

# Init Project Docs

## Overview

Create or refresh AI-assisted dev docs **from the actual project** — project-specific, never generic.

**Cross-host.** This skill runs under Claude Code, Codex CLI, or GitHub Copilot CLI. Phase 0.5 detects the host; host-specific outputs (instruction file, settings, hooks, agents, path-scoped rules) are routed via `references/host-matrix.md`. Host-neutral outputs (`docs/`, baseline files, summary) are produced the same way regardless of host.

**Shared core + host adapters.** Discovery, docs quality, and rule content are shared. `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, settings, hooks, and agents are adapters that must match the target host's native format.

## Reference Map

Single-output ask → read that reference, skip the Phases.

| Ask | Reference |
|---|---|
| Full refresh / multi-output | Phases 0–7 |
| README | `references/README.md` |
| Standards | `references/coding-standards.md` |
| Copilot (quick / full) | `references/copilot-instructions.md` / `-detailed.md` |
| Arch (quick / full) | `references/codebase-blueprint.md` / `architecture-blueprint-detailed.md` |
| `AGENTS.md` | `references/agentsmd.md` |

Host routing (any output, all phases): `references/host-matrix.md`.

## Operating Rules

- **Detect first.** No assumptions on stack, commands, folders, tooling, runtime — or host (Phase 0.5).
- **Merge, never overwrite** user-authored settings, hooks, rules, agents, docs, instruction file — for whichever host(s) you target.
- **Route via `references/host-matrix.md`.** Never hard-code Claude paths; every host-specific filename/format comes from that table.
- **Ask before risky actions:** `git init`, chmod hooks, commits, perms.
- **Never write secret values** — `.env.example` = key names only.
- Prefer skill references over boilerplate; every claim from real files.

## Phase 0: Detect

Inspect manifests, frameworks, data access, tests, monorepo signals, AI files. Run `bash scripts/detect-stack.sh` if present; summarize and flag uncertain inferences first.

## Phase 0.5: Detect Host

Determine which agent(s) to produce native files for. Before Phase 1, run a **host confirmation gate**.

1. **Self-knowledge first.** You know which agent you are (Claude Code / Codex CLI / Copilot CLI from your own runtime) — that is the most reliable signal.
2. **Corroborate** with `bash scripts/detect-host.sh` (env signals + home dirs). If `suggested` disagrees with (1), trust (1) but mention the mismatch.
3. **Report before continuing:** show `detected_host`, script `suggested`, `ambiguous`, `other_homes`, and proposed `target_hosts`.
4. **Stop for confirmation** if `ambiguous=true`, self-knowledge is genuinely unclear, or `other_homes` is non-empty and the current user request did not explicitly confirm target hosts.

**Output scope — confirmed single, opt-in multi:** proposed default is the detected host only, but do not enter Phase 1 until host scope is confirmed when `other_homes` exists. An explicit current-turn request such as "Codex only", "Claude + Codex", or "all three" counts as confirmation; otherwise ask the user to confirm detected-host-only vs adding specific `other_homes`. All host-specific filenames/formats come from `references/host-matrix.md`.

**Codex-only catalog confirmation:** for Codex targets, host confirmation only confirms Codex-native output scope (`AGENTS.md`, `.codex/config.toml`, `.codex/agents/`). It does **not** mean docs-only. In full init / refresh, after Phase 0.5 and before writing `AGENTS.md`, show the full Phase 4–6 catalogs with recommendation markers and wait for user selection, unless the current request explicitly says `docs-only`, `core-docs-only`, `no hooks`, `no agents`, or asks for a single output. If the user says "use recommended", select the `Recommended` items.

## Phase 1: Core Docs

```
<instruction-file>   ← host-matrix: CLAUDE.md / AGENTS.md / .github/copilot-instructions.md
docs/  README  ARCHITECTURE  DEVELOPMENT  FEATURES  TESTING  CHANGELOG
       plans/archive/
```

`docs/` and the inclusion test are **host-neutral** — same for every host. Only sections the project supports; files >500 lines → split + index. Per-doc content guide + templates: `references/docs-examples.md`.

**Inclusion test:** record a fact only if *"would another dev's module break without it?"* is yes — else skip as filler.

**Instruction file (host-routed):** filename per `references/host-matrix.md`. Content starts from one neutral template; the host-varying parts are file path, skill-call syntax (`Skill` tool / `$skill` / `/skill`), and whether rules can be path-scoped. **Codex has no path-scoped rules** → fold the Phase 4 rules content into `AGENTS.md` sections. In an all-host run, generate full `CLAUDE.md` and full `AGENTS.md`; if Copilot is also targeted and `AGENTS.md` exists, keep `.github/copilot-instructions.md` as a thin Copilot adapter that points to `AGENTS.md` / `docs/` and only adds Copilot-specific behavior.

**Required:** the instruction file; `docs/DEVELOPMENT.md` — plan archival flow (file naming + User Story→Spec→Tasks + archival). Templates: `references/docs-examples.md`.

## Phase 2: Settings

Settings file + format per `references/host-matrix.md` (Claude → JSON, Codex → TOML, Copilot → no Claude-style repo permissions/sandbox settings). Update only after showing the diff. Settings are **incremental** — merge permission/sandbox/network/hooks entries, never replace.

- **Claude (JSON):** use `scripts/merge-settings.py` (just point it at the right path).
- **Codex (TOML):** no script — merge with your own Edit tool into the TOML blocks host-matrix specifies; show diff first.
- **Copilot:** no Claude-style repo permissions/sandbox settings file; if a Claude template contains `deny` entries, convert them to a portable project guard hook per `references/settings-templates/copilot/README.md`.

Templates: Claude → `references/settings-templates/claude/<stack>.json` (pick `settings_template` + `settings_addons` from `detect-stack.sh`); Codex → `references/settings-templates/codex/README.md`; Copilot → `references/settings-templates/copilot/README.md`.

## Phase 3: Baseline Files

Offer when missing: `.gitignore` (always ignore `.claude/settings.local.json`, `.env*`), `.editorconfig`, `.env.example` (keys only), `CONTRIBUTING.md`/`SECURITY.md` (OSS/requested), `.github/workflows/ci.yml`. No `git init` / baseline commit without approval.

## Phase 4–6: Rules / Hooks / Agents

Show each catalog as a **multi-select list**; mark Phase 0-recommended items, user picks. Per-item metadata lives in reference file headers. Destination paths/formats per `references/host-matrix.md`.

For Codex targets, show the **full catalog**. Do not hide or omit non-recommended items. Mark every item as `Recommended`, `Optional`, or `Not recommended`, with one concise reason from Phase 0 evidence. Recommendation markers are advisory only: the user may select any catalog item, including `Not recommended` items, and current-turn user selection wins.

- **Rules** (`references/rules/`): `api-design`, `db-access`, `frontend`, `observability`, `testing` (path-scoped — set `paths:` to Phase 0 globs, delete the placeholder comment, else never matches); `git-commit`, `security` (global, leave as-is). Rule **content is host-neutral**. Routing: Claude → `.claude/rules/*.md`; Copilot → `.github/instructions/<name>.instructions.md` (`paths:`→`applyTo:`) or fold into `copilot-instructions.md`; **Codex has no path-scoping** → fold rule content into `AGENTS.md` sections.
- **Hooks** (`references/hooks/`): `protect-files` (擋敏感檔), `auto-format` (編輯後格式化), `run-tests` (編輯後跑測試), `auto-api-docs` (路由檔變更後同步文件), `compact-reminder` (compact 後重注規則), `notify` (等待/完成通知). The `.sh` scripts are **shared across hosts** (a host-agnostic input shim at the top normalizes each host's env/stdin). Only the **registration** differs — use `references/hooks/{claude,codex,copilot}/` templates. Codex hook matcher is a tool-name regex per current Codex docs, not a command prefix. Need `chmod +x` + settings edits — confirm first.
- **Agents** (`references/agents/`): `code-reviewer`, `debug-expert`, `security-auditor`, `refactor-assistant` (opus); `doc-writer`, `test-runner`, `git-commit` (sonnet). Claude → `.claude/agents/*.md` (use `.md` as-is); Copilot → `.github/agents/*.agent.md` (convert frontmatter/tools per `references/agents/copilot/README.md`); Codex → `.codex/agents/*.toml` for repo-specific agents, or `~/.codex/agents/*.toml` only when the user explicitly requests global agents (convert per `references/agents/codex/README.md`).

Codex recommendation markers:

- **Rules:** mark `api-design` as `Recommended` when API routes are present; `db-access` when DB/SQL/data-access code is present; `testing` when tests exist; `security` when auth, admin, secrets, payment-like env, or sensitive config appears. Still list every other rule and mark it `Optional` or `Not recommended` with a reason.
- **Hooks:** mark `protect-files` as `Recommended` by default; `run-tests` when a test script exists; `auto-api-docs` when an OpenAPI / Swagger / API-doc script exists; `auto-format` only when formatter or lint tooling is present. Still list `compact-reminder` and `notify` as appropriate for session UX / long-doc workflows.
- **Agents:** mark `code-reviewer` as a general repo baseline; `test-runner` when tests exist; `security-auditor` when auth, admin, secrets, or payment-like surfaces appear. Mark `debug-expert`, `refactor-assistant`, `doc-writer`, and `git-commit` from current task intent and repo state, but still show them.

## Phase 7: Summary

Report: files created/updated, why, skipped phases, verification, follow-ups.

## Validation

Before reporting done: Operating Rules held, inclusion test applied, settings/hooks/agents reference real paths, no rule keeps a `{偵測到的…}` placeholder. Host check: every host-specific file lands at its `host-matrix.md` path in the right format (no `.claude/` paths leaked into a Codex/Copilot run); Codex TOML is valid and uses current `hooks` / subagent keys; Codex rules folded into `AGENTS.md`; Copilot rules use `.github/instructions/*.instructions.md` with `applyTo:`; Copilot agents use `.agent.md` plus Copilot tool ids; Copilot thin adapter avoids duplicating `AGENTS.md` content when both files are generated. For Codex full init / refresh, Phase 7 must report selected Phase 4–6 items, "use recommended", or the explicit current-turn opt-out; otherwise status is pending catalog confirmation.

## See also

- `references/new-project-defaults.md` — Observability / Dependency / CI-CD baseline.
- `acquire-codebase-knowledge` — complementary; engineer docs in `docs/codebase/`.

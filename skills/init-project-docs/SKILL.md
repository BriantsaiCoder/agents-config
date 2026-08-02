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

先讀取共用的 stack/template catalog `references/README.md`，再從 `references/host-matrix.md` 查每個 target host 的 destination、schema、merge strategy 與 current feature boundary。

- 寫入前先顯示 diff；settings 一律增量合併並保留未知或使用者自訂的 keys。
- 只使用 Phase 0 evidence 選出的 template（`settings_template` + `settings_addons`）。
- 依 matrix 做 host-specific conversion；不同 host format 不可直接互換。

## Phase 3: Baseline Files

缺少時提供：`.gitignore`（一律忽略 `.claude/settings.local.json`、`.github/copilot/settings.local.json`、`.env*`）、`.editorconfig`、只含 keys 的 `.env.example`、OSS／明示要求時的 `CONTRIBUTING.md`／`SECURITY.md`，以及 `.github/workflows/ci.yml`。未獲核准不得執行 `git init` 或 baseline commit。

## Phase 4–6: Rules / Hooks / Agents

從 `references/README.md` 載入共用 Rules／Hooks／Agents catalogs；target-host destination、conversion 與建議標記一律讀 `references/host-matrix.md`。

每個 catalog 都以 **multi-select list** 顯示。Codex target 必須列出全部項目，並依 Phase 0 evidence 標成 `Recommended`、`Optional` 或 `Not recommended`，每項附一個理由。標記僅供建議；本輪使用者選擇優先。

只建立使用者選取的項目。變更 executable bit 或 settings／hook registration 前先詢問；既有檔採增量合併，host-neutral content 與 host adapter 分開維護。

## Phase 7: Summary

回報建立／更新的檔案、原因、略過的 phases、驗證結果與 follow-ups。

## Validation

回報完成前逐項檢查：

- [ ] Operating Rules 已遵守、inclusion test 已套用，且沒有未解析的 `{偵測到的…}` placeholder。
- [ ] 每個產出 reference 都能解析到真實路徑；不得把某 host 的 filename、tool 或 config key 洩漏到另一 host。
- [ ] JSON／TOML／YAML artifacts 均可 parse；settings／hooks／agents 使用 current `host-matrix.md` schema。
- [ ] Rules 保留 target-host scoping：Claude `paths:`、Copilot `applyTo:`、Codex content 併入 `AGENTS.md`。
- [ ] 用 fresh target-host session inventory 驗證產出的 hooks 與 agents；blocking hook 另跑一個 safe negative canary。
- [ ] Phase 7 已記錄 Phase 4–6 selection、`use recommended` 或本輪明示 opt-out；否則狀態維持 pending confirmation。

## See also

- `references/new-project-defaults.md` — Observability / Dependency / CI-CD baseline.
- `acquire-codebase-knowledge` — complementary; engineer docs in `docs/codebase/`.

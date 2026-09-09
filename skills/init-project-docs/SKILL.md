---
name: init-project-docs
description: Use when initializing or refreshing project docs and native AI instructions for Claude Code, Codex CLI, or GitHub Copilot CLI. Covers README, architecture, standards, settings, rules, hooks, and agents; use `acquire-codebase-knowledge` for discovery maps.
---

# Init Project Docs

產出只採 repo evidence；host-native 規格查 [host matrix](references/host-matrix.md)。單一 output 只讀對應 reference；full refresh 走完整流程。

## Step 1：偵測 repo 與 host

檢查 manifests、versions、source/tests、commands、CI 與既有 docs；可跑 `bash scripts/detect-stack.sh`。以 runtime self-knowledge 判定 host，再用 `bash scripts/detect-host.sh` 佐證。

回報 `detected_host`、`suggested`、`ambiguous`、`other_homes`、`target_hosts`。Host scope gate 僅適用 host-specific instructions、config、hooks、agents；host-neutral README／architecture 記 `N/A`。若 host-specific output scope 的 host 不明、ambiguous，或有未指定的 other homes，停止並確認該 scope；已由 user/session 明確授權的 target hosts 直接沿用，不重問。Codex full refresh 寫檔前須展示 Phase 4–6 catalogs，除非本輪已限縮 output。

**完成條件：**stack／commands 有路徑 evidence，target hosts 有 confirmation 或 host-neutral `N/A`，不確定推論已標記，既有授權 scope 已保留。

## Step 2：選擇 outputs 與 references

- 單一 output：讀 [README guide](references/docs-examples.md#readmemd)、[standards](references/coding-standards.md)、[Copilot](references/copilot-instructions.md)、[architecture](references/codebase-blueprint.md) 或 [AGENTS](references/agentsmd.md)；只在要求 full variant 時讀 [architecture detailed](references/architecture-blueprint-detailed.md) 或 [Copilot detailed](references/copilot-instructions-detailed.md)。
- Full docs：讀 [docs examples](references/docs-examples.md)，只保留會影響其他 module／integration 的事實。
- Settings 與 Phase 4–6：先讀取共用的 stack/template catalog `references/README.md`，再依 [host matrix](references/host-matrix.md) 顯示完整 multi-select catalogs 與 `Recommended`／`Optional`／`Not recommended` 理由。
- 新專案無等價 baseline 時讀 [new-project defaults](references/new-project-defaults.md)。依 repo evidence 建立 `.gitignore`、`.editorconfig`、key-only `.env.example` 與 CI；忽略 secret-bearing `.env*`／host-local settings，CI command 取自 repo script。

先顯示 proposed diff，只建立使用者選取的項目。

**完成條件：**每個 artifact 都有 target path、evidence、reference 與 selection／authorization。

## Step 3：增量落盤

Merge user-authored content，不覆寫未知 keys／hooks／rules／agents。每個 host 只用 matrix 當前 schema；不得互換 JSON／TOML／YAML。Secrets 只寫 key names；`.env.example` 不含 values。`git init`、chmod、commit、permission 或 hook registration 先取得授權。

Full core docs 依 catalog 產生 instruction file 與 repo 支援的 `docs/`；`docs/DEVELOPMENT.md` 保留 User Story → Spec → Tasks 與 plan archive 流程。Codex rules 併入 `AGENTS.md`；multi-host 各產 native instruction file。

**完成條件：**diff 僅含已選 outputs，所有 claims／commands／paths 可由 repo 驗證，既有內容與 secrets boundary 保留。

## Step 4：驗證與摘要

- [ ] 無 unresolved placeholders；每個 referenced path 存在。
- [ ] JSON／TOML／YAML 可 parse，且 host filename、tool、scope 沒有串台。
- [ ] Fresh target-host inventory 能看到產出的 hooks／agents；blocking hook 有 safe negative canary。
- [ ] Phase 4–6 selection、`use recommended` 或本輪 opt-out 已記錄，否則維持 pending confirmation。
- [ ] 摘要列出 created／updated files、原因、skipped phases、validation commands 與 follow-ups。

**完成條件：**所有適用 checkbox 有 command/probe evidence；任何 FAIL 回到 Step 3，不宣稱完成。

<!-- status: PROPOSAL | created: 2026-07-07 | author-model: claude-fable-5 | readers: AI models（Opus / Sonnet / Codex GPT 5.5+）| consumed-by: 無（本目錄不被任何 CLI 注入，僅供查閱） -->
# 提案：三 AI CLI 共用設定層 + Canonical Workflow

> 適用：全 host｜載入：無（PROPOSAL，未生效）
>
> **狀態：PROPOSAL——本目錄是制度 blueprint，尚未執行任何遷移。**
> live 設定（`~/.claude/`、`~/.codex/`、`~/.copilot/`）在用戶明確批准前一律不動。
> 批准後依 [04-migration.md](04-migration.md) 逐步執行，每步含驗證與回滾。

## 一句話

三家 CLI（Claude Code / Codex CLI / Copilot CLI）目前只有 Claude 真正載入完整規則；本提案把「規則正本」（設定層）與「開發 workflow 正本」（workflow 層）都收斂進 `~/.agents/`，各家以**已驗證的原生機制**消費，讓三家跑同一條 workflow。

## 為什麼需要（審計實證，詳見 01）

1. **Codex**：`AGENTS.override.md`（~1.5KB）整檔取代 32KB `AGENTS.md`——10 大防線（Hard Rules、DB migration 分段、release gates…）休眠至少一個月，無人察覺。
2. **Copilot**：`copilot-instructions.md` 宣稱「已自動載入 ~/.claude/CLAUDE.md」——經 CLI 1.0.69 bundle 逐字驗證**為假**。實際殘存覆蓋僅 `global-core.instructions.md` 45 行英文摘要（缺 rollback 義務、DB migration 分段、merge-gate；精度修正見 06 C-R2），且構成第三份無同步平行正本；另有 9 個指向不存在 skill 的死引用。
3. **Claude**：規則全生效，但正本、Codex 副本、Copilot 副本三處各自漂移，無同步機制。
4. **好消息**：workflow 的「原料」已平權——50 個共用 skill 三家全通、superpowers 14 件套三家同版 6.1.1、plan mode / todo / MCP 四件套三家原生。缺的只是**路由層**與同步制度。

## 文件地圖

| 檔 | 內容 | 對應來源 |
|----|------|----------|
| [01-audit-findings.md](01-audit-findings.md) | 審查發現全錄：三家 live 層真相、失效防線、hooks 盤點、skill 平權、4 面結構牆、破口清單 | 兩輪多 agent 審計（2026-07-06/07） |
| [02-config-layer.md](02-config-layer.md) | 設定層制度：tier 分層 + agents-sync 生成器 + fingerprint 探針 + no-clobber + 衝突裁決鏈 | 設定層判決優勝案（33/40 分）+ 8 項嫁接 |
| [03-workflow-layer.md](03-workflow-layer.md) | Canonical dev-workflow：S0–S6 + BUGFIX 鏈、四態 gate、host adapters、gap closures | workflow 層判決優勝案（31/40 分）+ 10 項嫁接 |
| [04-migration.md](04-migration.md) | 合併遷移序（Step 0–13 + 並行待辦）、分段選項、rollback 總表 | 兩案合流 |
| [05-ai-reader-conventions.md](05-ai-reader-conventions.md) | AI 讀者書寫規範 11 條（遷移後落地為 `~/.agents/CONVENTIONS.md`） | 設定層優勝案 + 嫁接 |
| [06-final-review.md](06-final-review.md) | Fable 5 最終審查：六檔裁決、live 快照（2026-07-07）、B0 止血批裁決、精度修正、接手指令 | 同日批判性複審 + live 再驗證 |

## 兩案整合裁決：Codex 注入檔的處置（本提案唯一需要明示的合成點）

設定層案要求**刪除** `AGENTS.override.md`、部署生成的 `~/.codex/AGENTS.md`；workflow 層案要求把 ROUTING 區塊 **stamp 進** `AGENTS.override.md`（因為它是當下唯一 live 注入檔）。兩案不矛盾，裁決如下：

- **統一原則：ROUTING 區塊永遠進「當下實際被載入的檔」，載入與否以 fingerprint 探針判定，不以檔案存在判定。**
- **終局形態（完整遷移）**：override 刪除歸檔 → ROUTING 區塊併入 `agents-sync` 生成管線，成為 `dist/codex-AGENTS.md` 的一個組裝段。workflow 案的獨立 `sync-routing.sh` **不再需要**——其功能是 `agents-sync` 的一個 stage。
- **過渡形態（若先只做 workflow 層）**：ROUTING stamp 進現行 live 的 `AGENTS.override.md`（fenced markers）；啟動設定層遷移刪 override 時，stamp 目標隨之轉移，markers 機制不變。
- 同理合併：workflow 案的 `~/.agents/ROUTING.md` 與設定層案的 `core/skill-routing.md` 合為**單一檔 `core/routing.md`**，避免兩個路由正本。

## 啟用條件與 rollback（總覽）

- 前置（不可跳）：`git init ~/.agents` + baseline commit（Step 1）、遷移前 tar 快照（Step 0）。
- 每步自帶機械驗證（探針指令 + 預期輸出）與獨立回滾；總回滾點 = Step 0 快照。
- 安全三項（rotate stitch key、移除 zsh autopilot function、`chrome-devtoolss` 改名）已升入 **B0 止血批**（見 04；裁決依據 06 C-R1），不再列帶外——它們是「正在流血」的暴露，前置於任何遷移方案。

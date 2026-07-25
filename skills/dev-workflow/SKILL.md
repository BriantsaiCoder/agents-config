---
name: dev-workflow
description: 所有開發任務都路由經過的 canonical workflow 正本——S0 路由 → S1 需求 → S2 計畫⏸ → S3 實作(TDD) → S4 驗證 → S5 審查 → S6 收尾，另含 BUGFIX 鏈、X0 機械判定契約與四態 gate 制度。routing 由三家注入層逐名點名觸發，不靠本 description；此描述僅供 Claude 與人類閱讀。
---

<!-- tier: workflow | consumed-by: claude,codex,copilot | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md | last-verified: 2026-07-14 -->

# dev-workflow — 三主機共用開發 workflow 正本

> 讀者是 AI 模型。任何開發任務先讀本檔並照 S0 路由；bug 走 BUGFIX 鏈；輕量任務走 skill `sdd`。
> 骨架 = Claude / Codex / Copilot 三家 100% 可執行的最大公約數；標「enhancement」者缺席時 workflow 仍完整成立。
> 指紋（context 載入驗證用，勿刪）：FP:DEVWF-2026Q3。

## X1 選用的持久化產物

需求與計畫先留在 session 內的 host plan/todo 或對話 artifact；**取得用戶核准前不得為了滿足 workflow 而寫 repo**。產物路徑對照表（含最早持久化階段）見 `references/canonical-s1-s6.md` 的 X1 表；未建立不阻擋 S1–S3。

## X0 機械判定契約

每個 gate 四段式：ENTER / ACTION / EXIT / FAILURE。ENTER 與 EXIT 只允許四種機械形態之一——(1) 檔案存在性（某檔存在 / checkbox 全勾 / 必填節非空）；(2) 用戶關鍵字（引用用戶原句）；(3) 指令 exit code（某指令 exit 0）；(4) session 內 host plan/todo 或對話 artifact 存在，並附可引用的標題／摘錄。禁止寫需要人類散文判斷的 EXIT。

## 四態 gate 制度（全鏈通則）

- 每個 gate 標 `PASS` / `FAIL` / `UNAVAILABLE`（須附 probe 失敗證據）/ `SKIPPED`（須附理由）。
- 無證據不得宣稱完成；證據 = 指令 + exit code、輸出摘錄、或探針結果。
- Closeout ledger 之後偵測到新 commit → 前次 closeout 失效，MUST 重跑 S4–S6。
- 每階段完成回報三欄一行：`目前階段 / 下一步 / 是否可驗證`，不靜默跳步。

## 常駐攔截規則（最高風險，防新鮮 skill prose 搶贏路由）

- [INT-1] MUST 收尾類 skill（`finishing-a-development-branch` 等）只在 S4 且 S5 兩者皆 PASS 後 invoke。觸發：任務進入 S6，或偵測收尾 skill 被 routing 選中。例外：無。驗證：S4/S5 gate 四態皆 PASS 且有證據。
- [INT-2] MUST 在 fix 之前先有 failing regression test（紅→綠）。觸發：任務為 BUGFIX 或修改既有行為。例外：無可測 seam 時允許以「記錄架構問題」替代，但 MUST 明確標記例外並於 fix 落地後交接 `mp-improve-codebase-architecture`。驗證：commit 序中紅測早於 fix。
- [INT-3] 命中 [T0-8] 時，MUST NOT 在 auto / autopilot 模式豁免 S2 ⏸ plan gate；未命中時可引用用戶明確的 change／build／fix 原句將 S2 標為 SKIPPED。觸發：任務將改檔。例外：無。驗證：S2 EXIT 含計畫核准原句，或 SKIPPED 理由 + 用戶實作原句。

## Canonical 骨架（S0–S6）

### S0 ROUTE 進場判定（決策表由上而下第一命中即定路）

| 序 | 命中條件（皆為 X0 四形態，無散文估計） | 定路 |
|----|---------|------|
| 1 | 無 manifest 或原始碼 < 5 檔（可用指令計數） | NEW-PROJECT（先依 [T0-8] 判定是否需 S2，再落地骨架 + baseline commit） |
| 2 | 描述含錯誤行為 / 測試失敗 / regression 關鍵字 | BUGFIX 鏈 |
| 3 | 接手且 `docs/codebase/` 不存在 | 先提議 `acquire-codebase-knowledge`，完成後回 S0 |
| 4 | 用戶明說走小需求 / sdd / 輕量；或列出的 target file = 1、actionable tasks ≤3，且未命中 [T0-6] / [T1-1] / public API / schema / deploy pipeline | LIGHT tier（session plan；核准後可按需持久化到 `sdd/<slug>/`） |
| 5 | 以上皆非 | HEAVY tier（機械預設；核准後可按需持久化到 `docs/superpowers/plans/`） |

- ENTER：session 收到開發任務訊息（用戶送出的請求文字存在）。
- ACTION：由上而下逐列比對本表，第一命中即定 tier。先列 target files 與 actionable tasks 再計數；不以「≤1 天」等主觀工時估計定路。LIGHT 條件不完整即機械預設 HEAVY，不必為 tier 選擇中斷工作。
- EXIT：第 1–3 列命中 = manifest 檔數 / 描述關鍵字 / `docs/codebase/` 存在性；LIGHT（第 4 列）= 用戶原句，或 target file / task 計數 + risk trigger 掃描；HEAVY（第 5 列）= 第 4 列不成立。四形態齊備，散文估計不入 gate。
- FAILURE：需求本身有多種合理解讀且將改變檔案或行為 → 依 [T0-5] 攤開假設與影響後發問；tier 不確定本身不構成 blocker，走 HEAVY。

S0 定路後，**S1–S6 與 BUGFIX 鏈的完整 ENTER / ACTION / EXIT / FAILURE 契約讀 `references/canonical-s1-s6.md`**。下表只留階段目的與 EXIT gate（[INT-1] 與 host delta 的時機判定靠它，不需載入完整契約）。

| 階段 | 目的 | EXIT gate（機械） |
|------|------|------------------|
| S1 NEEDS | HEAVY → `mp-grill-with-docs`；LIGHT → 答 3 問（為何做 / 改什麼 / 影響範圍） | 需求摘要 artifact 存在且含目標、範圍、驗收條件 |
| S2 PLAN ⏸ | 依 [T0-8] 判定；命中則核准前不得改檔 | plan artifact + 用戶開始實作原句；未命中 = SKIPPED + 理由 + 用戶原句 |
| S3 IMPLEMENT | 開 `feat/`／`fix/` 分支，逐 task 紅→綠；動高扇入共用檔前跑 `deps-check`，stack `*-best-practices` MUST 套 | todo 全完成（或 checkbox 全勾）且全套測試 exit 0 |
| S4 VERIFY | 機械 gate（build/test/lint、前端 Playwright、部署則 release-verification + `dependency-security-scan`）＋散文檢核入 ledger | 所有適用機械 gate exit 0；不適用者標 SKIPPED + 理由 |
| S5 REVIEW | 記錄 reviewer 型別 + 結論；回饋逐條技術評估，不表演式同意 | 0 條未處理 actionable findings |
| S6 CLOSEOUT | Preflight 8 rows → bot-review triage → zh-TW Conventional Commit + squash merge + 刪分支 → BUGFIX 跑 `bug-fix-settlement` → 動架構同步 mermaid | PR body 含 8 rows 且每 row 有證據；非 PR 路徑輸出 Closeout Ledger（每 row 四態 + 證據） |
| BUGFIX 鏈 | 同骨架映射：S1 = reproduce + root cause（紅測 MUST 先於 fix，[INT-2]）→ S3 紅→綠 → S6 含 `bug-fix-settlement` | 各階段同上；escalation 見 reference |

- 收尾 skill `finishing-a-development-branch` 只在 S6 invoke（[INT-1]）。
- 任一 gate FAIL → 回 S3；S2 缺確認原句 → 停在 ⏸（[INT-3]）。

## Host adapters（只放能力差異與名稱映射，不重複 canonical）

### Claude
- 映射：plan = EnterPlanMode；todo = TodoWrite；子代理 = Task / Agent。
- enhancement：S2 前 `superpowers:brainstorming`（HEAVY）；S3 `superpowers:executing-plans` / `subagent-driven-development`；S4 `code-simplifier` agent 可代跑 4 檢核（前置：repo CLAUDE.md 掛 stack rules，缺則跳過並回報）；S5 `superpowers:requesting-code-review` 或 stack 專精 agent 擇一；S6 `finishing-a-development-branch`（僅 [INT-1] 成立後）；前端 `uiux-reviewer`（Claude-only；另兩家該步標 UNAVAILABLE + 理由即合規）。

### Codex
- 映射：plan = Plan Mode（`<proposed_plan>` 收斂）；todo = update_plan；子代理 = spawn_agent / wait_agent。
- enhancement：S3 / S5 僅在至少兩個可獨立驗證、file ownership 不重疊的 subtasks，且用戶／repo instructions 明確允許 delegation 時 multi_agent spawn；否則標 SKIPPED（附理由），不做 smoke spawn。S4 codex-security 疊加；S6 heartbeat PR 監控。
- 守護：`~/.codex/hooks.json` 的 PreToolUse(Bash) Git guard + `~/.codex/rules/default.rules` forbidden rules 共同攔截已知危險 force push；PreToolUse 對 unified_exec 覆蓋不完整且 prefix rule 僅涵蓋明列型態，仍須 tier0 prose + repo pre-commit/CI 疊加；architecture-html-doc 退役為 mermaid→HTML 衍生器（勿手改衍生圖，見 `references/canonical-s1-s6.md` X1 表 S6）。

### Copilot
- 映射：plan = --mode plan（requestExitPlanMode）；todo = update_todo；子代理 = task 工具 / --agent。
- S2 強制令：命中 [T0-8] 時，非 plan 模式改檔前 MUST 先輸出計畫並取得用戶明確確認（補償 autopilot alias 風險）。
- S5：內建 code-review agent 或泛用 subagent + references/reviewer-template.md；.NET 深審降級為已知取捨（實測不足再轉寫 `.agent.md`，延後決策避免預養第三格式）。
- 守護：Copilot 已支援 user-level hooks（`~/.copilot/hooks/` + config.json inline），現況未配置；機械守護目前依賴 repo 層 `.github/hooks/` + pre-commit + CI。
- MCP：chrome-devtools（已更名，見 B0.5）；codegraph 視需要補。

## References（以路徑引用，不 inline 完整內容）

- `references/canonical-s1-s6.md` — S1–S6 + BUGFIX 鏈的完整四段式契約與 X1 產物表（S0 定路後讀）。
- `references/ledgers.md` — Preflight 8 rows / Closeout / Postflight 定義 + 範例。
- `references/review-triage.md` — bot-review triage 合併規格（異步等待 + thread-aware + 子集教訓）。
- `references/reviewer-template.md` — S5 泛用 reviewer prompt（無專屬 agent 的 host 直接餵這份）。

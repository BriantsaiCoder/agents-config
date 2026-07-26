---
name: dev-workflow
description: 收到任何開發任務（feature、bug fix、refactor、接手陌生 repo、release）時先讀本檔並照 S0 決策表路由——這是所有開發任務共用的 canonical workflow 正本：S0 路由 → S1 需求 → S2 計畫⏸ → S3 實作(TDD) → S4 驗證 → S5 審查 → S6 收尾，另含 BUGFIX 鏈、X0 機械判定契約與四態 gate 制度。三家注入層另以逐名點名觸發，不單靠本 description。
---

<!-- tier: workflow | consumed-by: claude,codex,copilot | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md | last-verified: 2026-07-14 -->

# dev-workflow — 三主機共用開發 workflow 正本

> 讀者是 AI 模型。任何開發任務先讀本檔並照 S0 路由；bug 走 BUGFIX 鏈；輕量任務走 skill `sdd`。
> 骨架 = Claude / Codex / Copilot 三家 100% 可執行的最大公約數；標「enhancement」者缺席時 workflow 仍完整成立。
> 指紋（context 載入驗證用，勿刪）：FP:DEVWF-2026Q3。

## X1 選用的持久化產物（後續階段引用此表，不重複拼路徑字串）

需求與計畫先留在 session 內的 host plan/todo 或對話 artifact；取得用戶核准前不得為了滿足 workflow 而寫 repo。下表只在用戶／repo 明確要求，或核准後確有跨 session、多人交接、稽核價值時持久化；未建立不阻擋 S1–S3。

| 產物 | 路徑 | 最早持久化階段 |
|------|------|---------|
| 領域詞彙 glossary | `CONTEXT.md` | S2 核准後（HEAVY） |
| 架構決策紀錄 | `docs/adr/` | S2 核准後（HEAVY，lazily 建立） |
| 設計 spec | `docs/superpowers/specs/` | S2 核准後（HEAVY） |
| 實作計畫 doc | `docs/superpowers/plans/` | S2 核准後（HEAVY） |
| 輕量提案 | `sdd/<slug>/proposal.md` | S2 核准後（LIGHT） |
| 輕量任務清單 | `sdd/<slug>/tasks.md` | S2 核准後（LIGHT） |
| 整庫測繪 + 架構 mermaid | `docs/codebase/`（含 `ARCHITECTURE.md`） | S0 接手時 `acquire-codebase-knowledge`；S6 動架構時同步 |
| 專案教訓 | `tasks/lessons.md` | S6（沉澱） |

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

### S1 NEEDS

- ENTER：S0 tier 已定。
- ACTION：HEAVY → `mp-grill-with-docs` 拷問需求；LIGHT → 回答 3 問（為什麼做 / 要改什麼 / 影響範圍）。先把結果留在 session artifact；X1 產物只依表頭規則按需持久化。
- EXIT：session 內需求摘要 artifact 存在，且含目標、範圍、驗收條件；若已持久化則對應 X1 檔案存在亦可作證。
- FAILURE：關鍵模糊未決 → 停下發問（攤開假設 X、影響範圍 Y），禁止靜默推進（[T0-5]）。

### S2 PLAN ⏸（依 [T0-8] 判定）

- ENTER：S1 EXIT 的 session 或 file artifact 存在。
- ACTION：先依 [T0-8] 判定。命中時，進 plan 模式或取得用戶明確確認前不得改檔（plan 工具名的 host 映射見文末 `## Host adapters` 各 host 段）；LIGHT plan 每條 task ≤1h、≤3 條、含驗收情境與測試名（紅→綠），超過即升 HEAVY；HEAVY 先提出 design spec 並簽核，再提出 implementation plan。未命中時，以用戶明確的 change／build／fix 原句作為授權，將本 gate 標為 SKIPPED。取得核准後才依 X1 規則按需寫 repo plan file。executor enhancement：`superpowers:writing-plans`；缺 plugin 時直接在 session 產完整 plan artifact。
- EXIT：命中 [T0-8] 時，session plan artifact（或已持久化的 X1 plan file）存在且引用用戶明確說開始實作的原句；HEAVY 另需引用用戶簽核 design spec 的原句。未命中時，S2 = SKIPPED，附理由 + 用戶實作原句。
- FAILURE：命中 [T0-8] 但無確認原句 → 停在 S2 ⏸；禁以「合理推定同意」代替引用（[INT-3]）。

### S3 IMPLEMENT（TDD 內嵌）

- ENTER：S2 EXIT 成立（plan artifact + 用戶確認原句，或 SKIPPED 理由 + 用戶實作原句）。
- ACTION：先開分支（`feat/` 或 `fix/`）；用 host todo 或已持久化的 tasks file 逐 task 追蹤紅→綠，紅燈輸出即證據；動高扇入共用檔前 MUST 跑 `deps-check`；stack `*-best-practices` skill MUST 套。subagent 回報 ≠ 完成證據，主 context MUST 親自驗（why：收自 Codex 反向統一，2026-07-07）。
- EXIT：host todo 全完成（或 tasks file checkbox 全勾）且全套測試指令 exit 0。
- FAILURE：同一 bug 連 3 次修復失敗 → 停手，用戶確認後交接 `mp-improve-codebase-architecture`；flaky / 效能找不到根因 → `mp-diagnose`。

### S4 VERIFY

- ENTER：S3 EXIT 成立（tracked tasks 全完成 + 測試 exit 0）。
- ACTION 分兩類，EXIT 只由機械 gate 決定：
  - 機械 gate（標四態 + exit code / 產物證據）：(a) build / test / lint 全跑；(c) 前端 UI 變更跑 Playwright 產出截圖證據（headed 優先，缺 GUI 明確回報 fallback headless）；(d) 會部署 → `frontend-release-verification` 或 `backend-release-verification` + `dependency-security-scan`（三者正交必跑，非三選一）。
  - 散文檢核（記錄於 ledger，非機械 gate、不以四態標記；定義見 references/ledgers.md）：(b) Self-simplification 4 檢核——無 unrequested abstraction、無新依賴、無單一使用點抽象層、無 speculative config；(e) 中高風險 baseline capture（改動前後 API response / query count / 輸出樣本對照）。
- EXIT：所有適用的機械 gate 指令 exit 0（前端未動 → (c) 標 SKIPPED；不部署 → (d) 標 SKIPPED 附理由）。散文檢核 (b)(e) 已寫入 Preflight / Closeout ledger，不作為 EXIT 條件。
- FAILURE：任一機械 gate FAIL → 回 S3。

### S5 REVIEW

- ENTER：S4 EXIT 成立（各 gate PASS 有證據）。
- ACTION：記錄 reviewer 型別 + 結論；回饋逐條技術評估（採納或有據 pushback，不表演式同意）；UNAVAILABLE 只能在附 probe 失敗證據後標記，禁默默降級成自審。
- EXIT：0 條未處理 actionable findings（findings 清單為空或全標 resolved）。
- FAILURE：findings 是 bug → 回 S3 且先寫紅測（[INT-2]）。

### S6 CLOSEOUT

- ENTER：S4 且 S5 兩者 EXIT 皆成立（[INT-1] 時機閘）。
- ACTION：
  1. Preflight Ledger 8 rows 寫進 PR body（8 row 定義見 references/ledgers.md）。
  2. Bot-review triage（合併規格見 references/review-triage.md）：開 Ready PR 後 task 保持 active，每次 push 跑 `~/.agents/bin/pr-review-gate <PR>`；等 Copilot review 異步完成，勿誤判「無」；thread-aware 逐條讀、正確 actionable 自動修、已修 thread resolve、錯誤 / YAGNI 附 technical reason 不盲修；修後 push、re-request、重跑 gate，直到 current HEAD 為 PASS。bot findings = 子集，改共用函式反模式時另跑 `deps-check` / grep 枚舉全 caller（why：PR #34 漏 8 條、PR #36 漏 2 caller）。
  3. zh-TW Conventional Commit、squash merge 預設（[T0-9]；四態 PASS 前不得 merge，正本 references/review-triage.md）、合併後刪分支（remote + 已併入 local）。
  4. BUGFIX 鏈 MUST 跑 `bug-fix-settlement`（即使結論不沉澱也 MUST 輸出評估摘要）。
  5. 動到架構 → 同步 `docs/codebase/ARCHITECTURE.md` mermaid（HTML 一律 opt-in、勿手改衍生圖）。
  - 收尾 skill `finishing-a-development-branch` 只在此 invoke（[INT-1]）。
- EXIT：PR body 含 8 rows 且每 row 有證據，且 `pr-review-gate` 對 current PR head 回 PASS；非 PR 路徑下 Closeout Ledger 已輸出且每 row 標四態 + 證據。
- FAILURE：缺 row／缺證據 → 不得 push / 開 PR；gate 為 FINDINGS／FAIL → 回 S3，WAIT_* → heartbeat 後重查，UNAVAILABLE → 附 probe 證據且不得提示 merge。

### BUGFIX 鏈（同骨架映射）

- S1 = reproduce + root cause。鐵則 inline：failing regression test MUST 先於 fix（[INT-2]）；無 seam 允許「記錄架構問題」例外但 MUST 明確標記，且 fix 落地後交接 `mp-improve-codebase-architecture`。
- S2 = 依 [T0-8] 判定；命中時將 root cause + 修法在 session plan 攤開等用戶確認，未命中時以用戶明確 fix 原句標 SKIPPED。
- S3 = 紅測 → fix → 綠。
- S4 → S5 → S6（S6 含 `bug-fix-settlement`）。
- escalation：重現率 <50% / flaky / 效能 regression 找不到根因 → `mp-diagnose`。

## Host adapters（只放能力差異與名稱映射，不重複 canonical）

### Claude
- 映射：plan = EnterPlanMode；todo = TodoWrite；子代理 = Task / Agent。
- enhancement：S2 前 `superpowers:brainstorming`（HEAVY）；S3 `superpowers:executing-plans` / `subagent-driven-development`；S4 `code-simplifier` agent 可代跑 4 檢核（前置：repo CLAUDE.md 掛 stack rules，缺則跳過並回報）；S5 `superpowers:requesting-code-review` 或 stack 專精 agent 擇一；S6 `finishing-a-development-branch`（僅 [INT-1] 成立後）；前端 `uiux-reviewer`（Claude-only；另兩家該步標 UNAVAILABLE + 理由即合規）。

### Codex
- 映射：plan = Plan Mode（`<proposed_plan>` 收斂）；todo = update_plan；子代理 = spawn_agent / wait_agent。
- enhancement：S3 / S5 僅在至少兩個可獨立驗證、file ownership 不重疊的 subtasks，且用戶／repo instructions 明確允許 delegation 時 multi_agent spawn；否則標 SKIPPED（附理由），不做 smoke spawn。S4 codex-security 疊加；S6 heartbeat PR 監控。
- 守護：`~/.codex/hooks.json` 的 PreToolUse(Bash) Git guard + `~/.codex/rules/default.rules` forbidden rules 共同攔截已知危險 force push；PreToolUse 對 unified_exec 覆蓋不完整且 prefix rule 僅涵蓋明列型態，仍須 tier0 prose + repo pre-commit/CI 疊加；architecture-html-doc 退役為 mermaid→HTML 衍生器（勿手改衍生圖，見 X1 表 S6）。

### Copilot
- 映射：plan = --mode plan（requestExitPlanMode）；todo = update_todo；子代理 = task 工具 / --agent。
- S2 強制令：命中 [T0-8] 時，非 plan 模式改檔前 MUST 先輸出計畫並取得用戶明確確認（補償 autopilot alias 風險）。
- S5：內建 code-review agent 或泛用 subagent + references/reviewer-template.md；.NET 深審降級為已知取捨（實測不足再轉寫 `.agent.md`，延後決策避免預養第三格式）。
- 守護：Copilot 已支援 user-level hooks（`~/.copilot/hooks/` + config.json inline），現況未配置；機械守護目前依賴 repo 層 `.github/hooks/` + pre-commit + CI。
- MCP：chrome-devtools（已更名，見 B0.5）；codegraph 視需要補。

## References（以路徑引用，不 inline 完整內容）

- `references/ledgers.md` — Preflight 8 rows / Closeout / Postflight 定義 + 範例。
- `references/review-triage.md` — bot-review triage 合併規格（異步等待 + thread-aware + 子集教訓）。
- `references/reviewer-template.md` — S5 泛用 reviewer prompt（無專屬 agent 的 host 直接餵這份）。

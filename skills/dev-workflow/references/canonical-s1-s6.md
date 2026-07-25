<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | referenced-from: dev-workflow/SKILL.md S1–S6 + BUGFIX | generated-from: dev-workflow/SKILL.md（2026-07-25 漸進揭露拆分，內容逐字搬移未改語意）| last-verified: 2026-07-25 -->

# canonical-s1-s6 — S1–S6 與 BUGFIX 鏈的完整 gate 定義

> S0 決策表留在 `SKILL.md`（routing 靠它定路）；本檔在 S0 定路後才讀。
> 每階段的 ENTER / ACTION / EXIT / FAILURE 四段式契約見 `SKILL.md` 的 `## X0 機械判定契約`；四態標記通則見 `## 四態 gate 制度`；[INT-1]–[INT-3] 攔截規則常駐於 `SKILL.md`，本檔不重複。

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

## S1 NEEDS

- ENTER：S0 tier 已定。
- ACTION：HEAVY → `mp-grill-with-docs` 拷問需求；LIGHT → 回答 3 問（為什麼做 / 要改什麼 / 影響範圍）。先把結果留在 session artifact；X1 產物只依表頭規則按需持久化。
- EXIT：session 內需求摘要 artifact 存在，且含目標、範圍、驗收條件；若已持久化則對應 X1 檔案存在亦可作證。
- FAILURE：關鍵模糊未決 → 停下發問（攤開假設 X、影響範圍 Y），禁止靜默推進（[T0-5]）。

## S2 PLAN ⏸（依 [T0-8] 判定）

- ENTER：S1 EXIT 的 session 或 file artifact 存在。
- ACTION：先依 [T0-8] 判定。命中時，進 plan 模式或取得用戶明確確認前不得改檔（plan 工具名的 host 映射見 `SKILL.md` 的 `## Host adapters` 各 host 段）；LIGHT plan 每條 task ≤1h、≤3 條、含驗收情境與測試名（紅→綠），超過即升 HEAVY；HEAVY 先提出 design spec 並簽核，再提出 implementation plan。未命中時，以用戶明確的 change／build／fix 原句作為授權，將本 gate 標為 SKIPPED。取得核准後才依 X1 規則按需寫 repo plan file。executor enhancement：`superpowers:writing-plans`；缺 plugin 時直接在 session 產完整 plan artifact。
- EXIT：命中 [T0-8] 時，session plan artifact（或已持久化的 X1 plan file）存在且引用用戶明確說開始實作的原句；HEAVY 另需引用用戶簽核 design spec 的原句。未命中時，S2 = SKIPPED，附理由 + 用戶實作原句。
- FAILURE：命中 [T0-8] 但無確認原句 → 停在 S2 ⏸；禁以「合理推定同意」代替引用（[INT-3]）。

## S3 IMPLEMENT（TDD 內嵌）

- ENTER：S2 EXIT 成立（plan artifact + 用戶確認原句，或 SKIPPED 理由 + 用戶實作原句）。
- ACTION：先開分支（`feat/` 或 `fix/`）；用 host todo 或已持久化的 tasks file 逐 task 追蹤紅→綠，紅燈輸出即證據；動高扇入共用檔前 MUST 跑 `deps-check`；stack `*-best-practices` skill MUST 套。subagent 回報 ≠ 完成證據，主 context MUST 親自驗（why：收自 Codex 反向統一，2026-07-07）。
- EXIT：host todo 全完成（或 tasks file checkbox 全勾）且全套測試指令 exit 0。
- FAILURE：同一 bug 連 3 次修復失敗 → 停手，用戶確認後交接 `mp-improve-codebase-architecture`；flaky / 效能找不到根因 → `mp-diagnose`。

## S4 VERIFY

- ENTER：S3 EXIT 成立（tracked tasks 全完成 + 測試 exit 0）。
- ACTION 分兩類，EXIT 只由機械 gate 決定：
  - 機械 gate（標四態 + exit code / 產物證據）：(a) build / test / lint 全跑；(c) 前端 UI 變更跑 Playwright 產出截圖證據（headed 優先，缺 GUI 明確回報 fallback headless）；(d) 會部署 → `frontend-release-verification` 或 `backend-release-verification` + `dependency-security-scan`（三者正交必跑，非三選一）。
  - 散文檢核（記錄於 ledger，非機械 gate、不以四態標記；定義見 `ledgers.md`）：(b) Self-simplification 4 檢核——無 unrequested abstraction、無新依賴、無單一使用點抽象層、無 speculative config；(e) 中高風險 baseline capture（改動前後 API response / query count / 輸出樣本對照）。
- EXIT：所有適用的機械 gate 指令 exit 0（前端未動 → (c) 標 SKIPPED；不部署 → (d) 標 SKIPPED 附理由）。散文檢核 (b)(e) 已寫入 Preflight / Closeout ledger，不作為 EXIT 條件。
- FAILURE：任一機械 gate FAIL → 回 S3。

## S5 REVIEW

- ENTER：S4 EXIT 成立（各 gate PASS 有證據）。
- ACTION：記錄 reviewer 型別 + 結論；回饋逐條技術評估（採納或有據 pushback，不表演式同意）；UNAVAILABLE 只能在附 probe 失敗證據後標記，禁默默降級成自審。
- EXIT：0 條未處理 actionable findings（findings 清單為空或全標 resolved）。
- FAILURE：findings 是 bug → 回 S3 且先寫紅測（[INT-2]）。

## S6 CLOSEOUT

- ENTER：S4 且 S5 兩者 EXIT 皆成立（[INT-1] 時機閘）。
- ACTION：
  1. Preflight Ledger 8 rows 寫進 PR body（8 row 定義見 `ledgers.md`）。
  2. Bot-review triage（合併規格見 `review-triage.md`）：等 Copilot review 異步 2–3 分鐘，勿誤判「無」；thread-aware 逐條讀、正確 actionable 自動修、已修 thread resolve、錯誤 / YAGNI 附 technical reason 不盲修；bot findings = 子集，改共用函式反模式時另跑 `deps-check` / grep 枚舉全 caller（why：PR #34 漏 8 條、PR #36 漏 2 caller）。
  3. zh-TW Conventional Commit、squash merge 預設（[T0-9]；四態 PASS 前不得 merge，正本 `review-triage.md`）、合併後刪分支（remote + 已併入 local）。
  4. BUGFIX 鏈 MUST 跑 `bug-fix-settlement`（即使結論不沉澱也 MUST 輸出評估摘要）。
  5. 動到架構 → 同步 `docs/codebase/ARCHITECTURE.md` mermaid（HTML 一律 opt-in、勿手改衍生圖）。
  - 收尾 skill `finishing-a-development-branch` 只在此 invoke（[INT-1]）。
- EXIT：PR body 含 8 rows 且每 row 有證據；非 PR 路徑下 Closeout Ledger 已輸出且每 row 標四態 + 證據。
- FAILURE：缺 row 或缺證據 → 不得 push / 開 PR。

## BUGFIX 鏈（同骨架映射）

- S1 = reproduce + root cause。鐵則 inline：failing regression test MUST 先於 fix（[INT-2]）；無 seam 允許「記錄架構問題」例外但 MUST 明確標記，且 fix 落地後交接 `mp-improve-codebase-architecture`。
- S2 = 依 [T0-8] 判定；命中時將 root cause + 修法在 session plan 攤開等用戶確認，未命中時以用戶明確 fix 原句標 SKIPPED。
- S3 = 紅測 → fix → 綠。
- S4 → S5 → S6（S6 含 `bug-fix-settlement`）。
- escalation：重現率 <50% / flaky / 效能 regression 找不到根因 → `mp-diagnose`。

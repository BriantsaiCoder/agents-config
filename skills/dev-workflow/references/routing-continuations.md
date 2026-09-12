# Routing continuations

依命中的 intake／tracker、跨 session／ticket、research、skill audit 或 handoff section 載入；同版已在 context 時沿用。

命中 user-only skill 時依 [INT-7] 推薦該 host 的 explicit invocation command 並等待。需要 delegation 時套 [INT-4]。

## Intake and tracker

tracker contract 優先 repo `docs/agents/issue-tracker.md`，否則讀 `~/.agents/docs/agents/issue-tracker.md`；`setup-matt-pocock-skills` 只在使用者明示時執行（[INT-5]）。

| Need | Route |
|---|---|
| 外部 issue／PR 的初始評估 | `triage` |
| 使用者明示訪談／壓測 under-specified plan／decision／idea | `grilling`；領域詞彙／ADR 加 `domain-modeling` |
| 使用者明示邊討論邊產生 glossary／ADR | `grill-with-docs`（內含 `grilling` + `domain-modeling`） |
| 把已決內容整理成 spec | `to-spec` |
| 拆 tracer-bullet tickets | `to-tickets` |
| 超過單一 session 的決策地圖 | `wayfinder` |

Question eligibility：MUST 先查既有 context、code 與 sensible defaults，只問真正阻擋下一步且屬 user-owned 的 decision。其餘澄清不進 `grilling`，依 S2 判 plan gate 後由 host plan mode 承接；提問載體與批次規則見 host adapter。`ask-matt` 只涵蓋 Matt subset，缺項回 S0 表。

## Session and ticket transitions

Phase boundary 依序選成本最低且有效的 transition：Continue 用於下一階段仍需要目前 primary context 且 context 仍可用；`clear` 用於既有 context 已無關；`handoff` 只用於跨 harness／directory／person 或可攜式 mid-phase split；`subagent` 只用於 [INT-4] 下的 independent scope；`compact` 用於同一任務的相關 context 必須延續且沒有更便宜的分支。`compact` 只在 phase boundary 使用；mid-phase 必須保留脈絡時走 `handoff`。`grilling` → `to-spec` → `to-tickets` 只要 reasoning context 仍可用就留在同一 context；否則在最近的 phase boundary 依前述順序選擇，不設固定 token threshold。Transition 不擴張也不機械式抹除 authorization；S2 只重用 exact、evidenced scope。驗證：`tests/mattpocock-workflow.sh` 的 routing continuation assertions。

- `triage`、`grilling` 或 `wayfinder` 釐清需求後，單一 session 可完成的 coherent vertical slice 直接進 S2，不等待額外 skill invocation。
- 多個可獨立驗收的 implementation slices：無 canonical spec 時依序推薦使用者顯式 invoke `to-spec` → `to-tickets`；已有完整 spec／agent-ready issue 時略過 `to-spec`，直接推薦 `to-tickets`。
- 每張 ticket 以 fresh session 開始，明確 change／build／fix 原句可直接授權 in-scope local implementation 與 non-destructive verification；先進 isolated branch／worktree，再依 adapter 執行，fresh session 不豁免 S2／[T0-8]。
- `wayfinder` 只處理跨 session 的決策迷霧；決策已清楚但實作量大時走 spec／tickets 分流。
## Skill audit and vendored changes

- Skill audit finding 要求修改時先跑 vendored gate；execution 依 [Step 0](../../auditing-skill-folder/step0-vendored-gate.md) 的 recorded override contract，再進 S2；finding／既有 fork 記錄本身不授權新變更。
## Handoff

session 中斷且重要 context 尚未進 canonical artifact 時 route 到 `handoff`；依 [INT-7] 等使用者明示 invoke。

- 使用者明示要換 session、交接或讓另一個 agent 接手時，`handoff` 只橋接仍未進入 spec、ticket 或 wayfinder map 的重要 context；需要時依 [INT-7] 推薦 host-specific command 並等待使用者啟動。
- Agent 因 blocker 或 session 邊界必須停止且工作未完成時，若仍有未落盤的重要 context，將 `handoff` 列為唯一 next action；已有 canonical artifact 時只引用、不重複內容。一般 context compaction、任務已完成或只是內容很長 MUST NOT 觸發 `handoff`；same-conversation `/compact` 也 MUST NOT 觸發 `handoff`。

## Research

Route 到 `research` 時，background agent 依 [INT-4] 自主判定；將 findings 寫入 repo Markdown 仍受 S2 authorization，未獲授權不得落盤。

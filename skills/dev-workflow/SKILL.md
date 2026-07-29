---
name: dev-workflow
description: 收到任何開發任務時先讀本檔。這是三 host 共用的 thin kernel：S0 route 到 Matt Pocock skills，S2 處理授權與風險，完成後只保留 S4 驗證、S5 審查、S6 收尾。
---

<!-- tier: workflow | consumed-by: claude,codex,copilot | last-verified: 2026-07-29 -->

# dev-workflow — thin routing and governance kernel

> 方法由 Matt Pocock skills 提供；本檔只管 routing、authorization、risk、RED→GREEN、S4–S6 與 host adapters。
> 指紋：FP:DEVWF-2026Q3。

## Gate contract

- Gate 只用 `PASS`／`FAIL`／`SKIPPED`（附理由）／`UNAVAILABLE`（附 probe evidence）。
- Evidence 必須是指令 exit code、輸出／產物 probe，或可引用的 user／session artifact。
- Closeout 後若出現新 commit，S4–S6 全部失效並重跑。

## Always-on guards

- [INT-1] push／open PR／merge／final closeout MUST 只在 S4、S5 適用 gate PASS 後執行。觸發：任一收尾動作。例外：SKIPPED／UNAVAILABLE 須附理由或 probe。驗證：S4/S5 ledger 與 evidence 齊備。
- [INT-2] MUST 在 fix 前先有 failing regression test（RED→GREEN）。觸發：BUGFIX 或改既有 behavior。例外：無可測 seam 時記錄架構問題，fix 後交接 `codebase-design`。驗證：RED evidence 早於 fix。
- [INT-3] 命中 [T0-8] 時 MUST 停在 S2 等明確核准；auto／autopilot 不豁免。觸發：將改檔且屬 plan-first／中高風險。例外：未命中時可引用 user 的 change／build／fix 原句標 SKIPPED。驗證：核准原句或 SKIPPED evidence。
- [INT-4] Delegation 的寫入 ownership 與 read-only evidence scope MUST 不重疊；未獲 user／repo／higher instruction 授權即 SKIPPED。Subagent 回報不是完成證據，main context MUST 重驗。觸發：任何 delegation。例外：skill 明定的固定 fan-out。驗證：scope 清單 + main-context probe。
- [INT-5] `setup-matt-pocock-skills` 只有使用者明示才可執行；先讀 repo `docs/agents/issue-tracker.md`，不存在才讀 `~/.agents/docs/agents/issue-tracker.md`。觸發：Matt skill 需要 tracker contract。例外：無。驗證：contract 存在或引用使用者 setup 原句。
- [INT-6] 顯式 `implement` 必須先建立 branch／isolated worktree，再執行；忽略 upstream 的 current-branch commit 指示，完成後返回 S4–S6。觸發：使用者顯式 invoke `implement`。例外：無。驗證：isolated branch + S4–S6 ledger。

## S0 ROUTE

由上而下套用需要的 method skills；可組合，不複製其方法 prose：

| Need | Route |
|---|---|
| 外部 issue／PR 的初始評估 | `triage` |
| 需求壓測／決策澄清 | `grilling`；領域詞彙與 ADR 另加 `domain-modeling` |
| 使用者明示邊討論邊產生 glossary／ADR | `grill-with-docs`（內含 `grilling` + `domain-modeling`） |
| 把已決內容整理成 spec | `to-spec` |
| 拆 tracer-bullet tickets | `to-tickets` |
| 超過單一 session 的決策地圖 | `wayfinder` |
| session 中斷且重要 context 尚未進 canonical artifact | `handoff` |
| 需求已清楚且單一 session 可完成（含已核准 spec／ticket） | kernel 的 `implement` adapter；每個 slice 用 `tdd` |
| hard bug／flaky／performance diagnosis | `diagnosing-bugs` |
| code review | `code-review` |
| 架構、deep module、seam 設計 | `codebase-design`；候選取捨另加 `grilling` |
| 陌生 repo | `acquire-codebase-knowledge` |
| 單檔且 ≤3 tasks 的低風險 change | `sdd` |
| skill 建立／修改／稽核 | `writing-great-skills`／`auditing-skill-folder` |

Routing 前先確認 skill path 存在；需要 delegation 時套 [INT-4]。

### Routing continuations

- `triage`、`grilling` 或 `wayfinder` 釐清需求後，單一 session 可完成的 coherent vertical slice 進 `implement`。
- 多個可獨立驗收的 implementation slices：無 canonical spec 時依序跑 `to-spec` → `to-tickets`；已有完整 spec／agent-ready issue 時略過 `to-spec`，直接跑 `to-tickets`。
- 每張 ticket 以 fresh session 開始，先進 isolated branch／worktree，再依 `implement` adapter 執行；fresh session 不豁免 S2。
- `wayfinder` 只處理跨 session 的決策迷霧；決策已清楚但實作量大時走 spec／tickets 分流。
- `handoff` 只橋接中斷時仍未進入 spec、ticket 或 wayfinder map 的重要 context；已有 canonical artifact 時只引用，不重複內容。

## S2 AUTHORIZE

1. 先依 [T0-8] 與 [INT-3] 判定 plan gate；schema、auth、payment、migration、deployment 與 destructive change 另附 rollback。
2. 核准前只保留 session plan／todo；只有 user／repo 要求或確有跨-session 價值時，才持久化到 `docs/agents/specs/`、`docs/agents/plans/` 或 `sdd/<slug>/`。
3. 有多種合理解讀且會改檔時，列假設與影響後停下發問；不得用 delegation 迴避授權（[INT-4]）。

## Implementation adapters

### BUGFIX RED → GREEN

先用 `diagnosing-bugs` 建立可重現 feedback loop（simple deterministic bug 可直接最小 repro），再依 [INT-2] 寫 failing regression test；只做最小 fix，看到 GREEN 後才進 S4。無 seam 必須明標例外與後續 `codebase-design`。

### Approved implementation

`implement` 必須先進 isolated worktree／branch，依 `tdd` 做 one-test→one-implementation vertical slices；`implement` 在 current/main 上 commit 是禁止的（MUST NOT），且完成後必須返回 S4 → S5 → S6。Delegation 依 [INT-4]。

每輪 GREEN 後只允許一個不改 behavior 的 micro-refactor，並立即重跑當輪 test；wide／structural refactor 留到獨立核准 change 或 S5 finding，RED 時不得 refactor。

## S4 VERIFY

- Build／test／lint 與 task-specific probes 全跑；UI 變更留 browser evidence。
- 會部署時另跑 `frontend-release-verification` 或 `backend-release-verification`，再跑 `dependency-security-scan`；不部署標 SKIPPED。
- 中高風險附 before／after baseline；記錄 command、exit code 與必要輸出，不以「應該」代替。
- 任一 gate FAIL 回 implementation；delegated work 依 [INT-4] 由 main context 重驗。

## S5 REVIEW

- 用 `code-review` 分開執行 Standards 與 Spec；各軸只能標 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`。
- Spec 不存在可標 SKIPPED；缺 reviewer capability 必須附 UNAVAILABLE probe，不得假裝自審等價。
- Actionable finding 回 implementation；bug finding 先補 RED test（[INT-2]）。Delegation 依 [INT-4]。

## S6 CLOSEOUT

- 只有 [INT-1] 成立才 commit／push／open PR／merge／final closeout；commit／PR 用 zh-TW Conventional Commits。
- PR 路徑依 `references/ledgers.md` 填 Preflight／Closeout ledger，依 `references/review-triage.md` 等待並處理 bot review；Ready PR 後每次 push 跑 `bin/pr-review-gate <PR>` 對 current HEAD 重查至 PASS（[T1-11]）；merge 前 CI 綠。
- BUGFIX 跑 `bug-fix-settlement`；架構變更同步 current architecture docs。
- 合併後依 repo policy 清理已合併 branch；不得 force-push main／master。

## Host adapters

### Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent。
- S5 的 `code-review` 固定 fan-out 受 [INT-4] 管理；`uiux-reviewer` 是 Claude-only。

### Codex

- plan = Plan Mode；todo = update_plan；子代理 = spawn_agent／wait_agent。
- `implement` 先用 `bin/agents-branch` 或 repo worktree 建 isolated branch；S6 用 PR heartbeat。
- Git guard 由 `~/.codex/hooks.json` 與 `~/.codex/rules/default.rules` 疊加，不能取代 tier0／CI。

### Copilot

- plan = `--mode plan`；todo = update_todo；子代理 = `task` 工具。
- 命中 [T0-8] 時，非 plan mode 必須先提出計畫並取得核准。
- S5 同一 response 用兩個 `task` 跑 Standards／Spec；Copilot user-level hooks 已配置於 `~/.copilot/hooks/guard-git-push.{json,sh}`。

## References

- `references/ledgers.md`
- `references/review-triage.md`
- `references/reviewer-template.md`

---
name: dev-workflow
description: 收到任何開發任務時先讀本檔。這是三 host 共用的 thin kernel：S0 route 到 Matt Pocock skills，S2 處理授權與風險，完成後只保留 S4 驗證、S5 審查、S6 收尾。
---

<!-- tier: workflow | consumed-by: claude,codex,copilot | last-verified: 2026-07-30 -->

# dev-workflow — thin routing and governance kernel

> 方法由 Matt Pocock skills 提供；本檔只管 routing、authorization、risk、RED→GREEN、S4–S6 與 host adapters。
> 指紋：FP:DEVWF-2026Q3。

## Gate contract

- Gate 只用 `PASS`／`FAIL`／`SKIPPED`（附理由）／`UNAVAILABLE`（附 probe evidence）。
- Evidence 必須是指令 exit code、輸出／產物 probe，或可引用的 user／session artifact。
- Closeout 後若出現新 commit，S4–S6 全部失效並重跑。

## Always-on guards

- [INT-1] push／open PR／merge／final closeout MUST 只在 S4、S5 適用 gate PASS 後執行。觸發：任一收尾動作。例外：SKIPPED／UNAVAILABLE 須附理由或 probe。驗證：S4/S5 ledger 與 evidence 齊備。
- [INT-2] MUST 在 fix 前先有 failing regression test（RED→GREEN）；既有 public behavior seam 視為已確認，只有新增 seam 才需另向使用者確認。觸發：BUGFIX 或改既有 behavior。例外：無可測 seam 時記錄架構問題，fix 後交接 `codebase-design`。驗證：RED evidence 早於 fix。
- [INT-3] 命中 [T0-8] 時 MUST 停在 S2 等明確核准；auto／autopilot 不豁免。觸發：將改檔且屬 plan-first／中高風險。例外：未命中時可引用 user 的 change／build／fix 原句標 SKIPPED。驗證：核准原句或 SKIPPED evidence。
- [INT-4] Delegation 只用於可獨立平行的實質工作；預設 1 個，未經 user／repo／higher instruction 明示最多 2 個。S5 `code-review` 的 Standards／Spec 恰好 2 個 read-only review agents 視為 workflow 已授權；`wayfinder` research fan-out 每批最多 2 個，超過須取得額外授權。寫入 ownership 與 read-only evidence scope MUST 不重疊；未獲 user／repo／higher instruction 授權即 SKIPPED。Subagent 回報不是完成證據，main context MUST 重驗。觸發：任何 delegation。例外：無。驗證：scope 清單 + main-context probe。
- [INT-5] `setup-matt-pocock-skills` 只有使用者明示才可執行；先讀 repo `docs/agents/issue-tracker.md`，不存在才讀 `~/.agents/docs/agents/issue-tracker.md`。觸發：Matt skill 需要 tracker contract。例外：無。驗證：contract 存在或引用使用者 setup 原句。
- [INT-6] 顯式 `implement` 必須先建立 branch／isolated worktree，再執行；忽略 upstream 的 current-branch commit 指示，完成後返回 S4–S6。觸發：使用者顯式 invoke `implement`。例外：無。驗證：isolated branch + S4–S6 ledger。
- [INT-7] `disable-model-invocation: true` 的 user-only skill MUST NOT 由 model 自動 invoke 或假裝已 invoke；S0 只能推薦下一個 host-specific command，並等待使用者明示啟動。觸發：route 命中 user-only skill。例外：無。驗證：skill frontmatter + 使用者 invocation 原句。

退役 ID 殼標記（CONVENTIONS 規則 3：ID 永不重編、永不回收，舊 transcript 與 commit message 可能仍引用）：`[R-1 DEPRECATED→INT-1 2026-07]`、`[R-2 DEPRECATED→INT-2 2026-07]`。兩者原定義於 `core/routing.md`，該檔 2026-07-30 退役至 `attic/core/`；條文語意由上方 [INT-1]／[INT-2] 逐項承接。

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
| 需求已清楚且單一 session 可完成（含已核准 spec／ticket） | 推薦使用者顯式 invoke `implement`；啟動後由 kernel adapter 管理，每個 slice 用 `tdd` |
| hard bug／flaky／performance diagnosis | `diagnosing-bugs` |
| code review | `code-review` |
| 高扇入共用介面變更 | MUST 先用 `deps-check` 列出完整 callers |
| Security | code／diff／path 的 focused data-flow review → `security-review`；使用者明示 whole-codebase adversarial audit／pen-test 且接受持久化 artifacts → `security-audit`；CI／pre-commit／SBOM／container gate → `dependency-security-scan` |
| 架構、deep module、seam 設計 | `codebase-design`；候選取捨另加 `grilling` |
| 陌生 repo | `acquire-codebase-knowledge` |
| 單檔且 ≤3 tasks 的低風險 change | `sdd` |
| 單一 skill 建立／修改 | `writing-great-skills` |
| skill folder keep／trim／delete／migrate 稽核 | `auditing-skill-folder`；verdict 不授權修改 |
| 單一 skill trigger failure | `diagnosing-bugs` 建 RED canary；需要改寫時續接 `writing-great-skills` |
| 使用者明示要掃整庫 deepening 機會 | `improve-codebase-architecture`（explicit-only） |

Routing 前先確認 skill path 與 frontmatter。Route 只選方法，不等於已 invoke；命中 user-only skill 時依 [INT-7] 推薦該 host 的 explicit invocation command 並等待。需要 delegation 時套 [INT-4]。

### Routing continuations

- `triage`、`grilling` 或 `wayfinder` 釐清需求後，單一 session 可完成的 coherent vertical slice 推薦使用者顯式 invoke `implement`。
- 多個可獨立驗收的 implementation slices：無 canonical spec 時依序推薦使用者顯式 invoke `to-spec` → `to-tickets`；已有完整 spec／agent-ready issue 時略過 `to-spec`，直接推薦 `to-tickets`。
- 每張 ticket 以 fresh session 開始，由使用者顯式 invoke `implement`；啟動後先進 isolated branch／worktree，再依 adapter 執行，fresh session 不豁免 S2。
- `wayfinder` 只處理跨 session 的決策迷霧；決策已清楚但實作量大時走 spec／tickets 分流。
- Skill audit finding 要求修改時先跑 vendored gate；`VND` 只回報、整體替換或移除，self-owned 才進 S2。
- 使用者明示要換 session、交接或讓另一個 agent 接手時，`handoff` 只橋接仍未進入 spec、ticket 或 wayfinder map 的重要 context；需要時依 [INT-7] 推薦 host-specific command 並等待使用者啟動。
- Agent 因 blocker 或 session 邊界必須停止且工作未完成時，若仍有未落盤的重要 context，將 `handoff` 列為唯一 next action；已有 canonical artifact 時只引用、不重複內容。一般 context compaction、任務已完成或只是內容很長 MUST NOT 觸發 `handoff`；same-conversation `/compact` 也 MUST NOT 觸發 `handoff`。

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
- Skill change 另驗 frontmatter、relative references 與 skill scripts；model-invoked 跑 positive/negative trigger canary，user-only 跑 explicit-only canary。
- 會部署時另跑 `frontend-release-verification` 或 `backend-release-verification`，再跑 `dependency-security-scan`；不部署標 SKIPPED。
- 中高風險附 before／after baseline；記錄 command、exit code 與必要輸出，不以「應該」代替。
- 任一 gate FAIL 回 implementation；delegated work 依 [INT-4] 由 main context 重驗。

## S5 REVIEW

- [S5-1] S5 MUST 依風險與 PR 狀態決定兩軸深度：中高風險或進 PR 執行 Standards 與 Spec，global workflow／security config 不得視為 trivial。觸發：進入 S5。例外：低風險且不進 PR 的 docs／local config／trivial change 可附理由標 `SKIPPED`。驗證：risk ledger + Standards／Spec status。
- [S5-2] Working tree dirty review MUST 在讀任何 raw diff 前完成 `references/dirty-review-package.md`；任一 finding 即 FAIL。觸發：working tree dirty review。例外：clean／fixed-point review 改用 `code-review`。驗證：三類 gitleaks exit code + package manifest。
- 各軸只能標 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`。
- Spec 不存在可標 SKIPPED；缺 reviewer capability 必須附 UNAVAILABLE probe，不得假裝自審等價。
- Actionable finding 回 implementation；bug finding 先補 RED test（[INT-2]）。Delegation 依 [INT-4]。

## S6 CLOSEOUT

- 只有 [INT-1] 成立才 commit／push／open PR／merge／final closeout；commit／PR 用 zh-TW Conventional Commits。
- PR 路徑依 `references/ledgers.md` 填 Preflight／Closeout ledger；Ready PR 的 current-HEAD CI／bot-review gate 與唯一 command 由 `references/review-triage.md` 定義，該 gate PASS 才可 merge。
- BUGFIX 跑 `bug-fix-settlement`；架構變更同步 current architecture docs。
- 「分析 conflict」不得授權 resolve、stage 或 commit；只有使用者明示「解決 conflict」時才可執行 `resolving-merge-conflicts`。
- 合併後依 repo policy 清理已合併 branch；不得 force-push main／master。

## Host adapters

### Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent。
- user-only skill command = `/<skill-name>`。
- S5 適用時，`code-review` 的 Standards／Spec 可在 [INT-4] 上限內平行；`uiux-reviewer` 是 Claude-only。

### Codex

- plan = Plan Mode；todo = update_plan；子代理 = spawn_agent／wait_agent。
- user-only skill command = `$<skill-name>`。
- Codex native Local/Worktree Handoff 只移動同一 chat 與 code，MUST NOT 觸發 Matt `$handoff`；跨 session／agent 文件仍走 `$handoff`。
- `implement` 先用 `~/.agents/bin/agents-branch` 或 repo worktree 建 isolated branch；S6 用 PR heartbeat。
- Git guard 由 `~/.codex/hooks.json` 與 `~/.codex/rules/default.rules` 疊加，不能取代 tier0／CI。

### Copilot

- plan = `--mode plan`；todo = update_todo；子代理 = `task` 工具。
- user-only skill command = `/<skill-name>`。
- 命中 [T0-8] 時，非 plan mode 必須先提出計畫並取得核准。
- S5 適用且 working tree dirty 時，預設 1 個 `task` review current package；兩軸獨立且平行有實益時，依 [INT-4] 增至 2 個；clean／fixed-point review 才執行 `code-review`。
- Copilot user-level hooks 已配置於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- 子代理沿用模型預設 effort；僅 hard debugging、security、migration 或高風險 review 升 `high`，`xhigh`／`max` 需量測證明收益。

## References

- `references/ledgers.md`
- `references/review-triage.md`
- `references/reviewer-template.md`
- `references/dirty-review-package.md`

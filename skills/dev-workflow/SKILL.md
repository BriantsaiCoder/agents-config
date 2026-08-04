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
- Closeout 後若出現新 commit：**S4 MUST 全跑**（build／test／lint 不分檔案，回歸可能跨檔）；**S5 只對新 commit 觸及的檔案重審**，未觸及範圍沿用前次 findings；**S6 MUST 重跑並重出完整 Closeout Ledger**——六列一列不少，未受影響的列引用前次結果並註明所依據的 baseline SHA（`ledgers.md` 的呈現分級只省版面，不省列）。範圍以 `git diff --name-only <前次 closeout SHA>..HEAD` 判定，不由審查者裁量。CI 與 bot-review gate 依 `references/review-triage.md` 對 current HEAD 一律整份重查，不適用本條收斂。

## Always-on guards

- [INT-1] push／open PR／merge／final closeout MUST 只在 S4、S5 適用 gate PASS 後執行。觸發：任一收尾動作。例外：SKIPPED／UNAVAILABLE 須附理由或 probe。驗證：S4/S5 ledger 與 evidence 齊備。
- [INT-2] MUST 在 fix 前先有 failing regression test（RED→GREEN）；既有 public behavior seam 視為已確認，只有新增 seam 才需另向使用者確認。觸發：BUGFIX 或改既有 behavior。例外：無可測 seam 時記錄架構問題，fix 後交接 `codebase-design`。驗證：RED evidence 早於 fix。
- [INT-3] 命中 [T0-8] 時 MUST 停在 S2 等明確核准；auto／autopilot 不豁免。觸發：將改檔且屬 plan-first／中高風險。例外：未命中時可引用 user 的 change／build／fix 原句標 SKIPPED。驗證：核准原句或 SKIPPED evidence。
- [INT-4] Delegation 的**約束**不變，改變的只有**誰決定**。任何 delegation 機制只在工作可獨立平行且預期能實質改善品質或 wall-clock time 時使用；是否委派、何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定並直接執行，MUST NOT 為此停下發問。不得設定 user-authored 的固定數量、併發、累計或 S 階段限制；host/runtime 可用容量仍是技術上限。無條件約束（不因任何授權而放寬）：序列相依工作 MUST 序列化或合併；併發 subagent 的寫入 ownership MUST 不重疊；main context MUST 重驗其回報，subagent 回報不是完成證據；**無條件約束不在可授權範圍內**，即使取得授權也 MUST NOT 執行衝突工作。S5 Standards／Spec outcomes 與 downstream research coverage 在各自 gate 命中時仍須完成；如使用 review agents，MUST 為 read-only，數量與批次由 AI 決定。下游 skill 的固定 spawn 時機／數量一律由本條覆寫為 advisory choreography；coverage、outcome 與 independence requirements 保留。MUST NOT 用 delegation 迴避 S2 授權或 [T0-8] plan gate，被委派工作仍套用原 gate；條件模糊時依 [T0-5] 停下發問。觸發：任何 delegation。例外：host/runtime 技術容量與 higher-priority instructions。驗證：scope 可獨立平行 + 寫入 ownership 不重疊 + main-context probe + policy 無固定數量／時機／階段限制。
- [INT-5] `setup-matt-pocock-skills` 只有使用者明示才可執行；先讀 repo `docs/agents/issue-tracker.md`，不存在才讀 `~/.agents/docs/agents/issue-tracker.md`。觸發：Matt skill 需要 tracker contract。例外：無。驗證：contract 存在或引用使用者 setup 原句。
- [INT-6] 顯式 `implement` 必須先建立 branch／isolated worktree，再執行；忽略 upstream 的 current-branch commit 指示，完成後返回 S4–S6。觸發：使用者顯式 invoke `implement`。例外：無。驗證：isolated branch + S4–S6 ledger。
- [INT-7] `disable-model-invocation: true` 的 user-only skill MUST NOT 由 model 自動 invoke 或假裝已 invoke；S0 只能推薦下一個 host-specific command，並等待使用者明示啟動。觸發：route 命中 user-only skill。例外：無。驗證：skill frontmatter + 使用者 invocation 原句。
- [INT-8] 已列出且經核准的多項工作 MUST 逐項執行至清單完成，不得每項完成即停下等待確認；使用者以「全部做完」「依照建議執行」「自行處理」等 blanket authorization 核准時，只涵蓋該原句之前已明列的 scope／編號項目。只有命中 [T0-5] 模糊、[T0-8]／[INT-3] plan gate，或需使用者裁決的取捨才可中斷，中斷時只問該一項；後續新發現 MUST 只分列清單外 follow-up，未確認不得實作。觸發：單次任務含 ≥2 個已核准項目。例外：無。驗證：核准原句早於 scope 清單外的新發現 + 回覆為單次彙總（各項 status + evidence），非逐項往返。
- [INT-9] Kernel route 到 [tdd](../tdd/SKILL.md) 時 MUST 以 [INT-2] 視既有 public behavior seam 為已確認，只有新增 seam 才需先向使用者確認；每輪 GREEN 後可做一次不改 behavior 的 micro-refactor，且 MUST 立即重跑當輪 test。本條覆寫該 upstream skill 的逐 seam 重問與「refactor 不在 loop」敘述。觸發：任何由本 kernel 管理的 tdd cycle。例外：無。驗證：seam state + RED／GREEN／retest evidence。

- [INT-10] 全域設定與 security config 的變更 MUST 走 PR 路徑：isolated branch → Ready PR → `references/review-triage.md` 的 bot-review gate → squash merge → 刪 branch；MUST NOT 直接 push 到 main／master。範圍（命中任一即適用）：三 host 入口檔（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.copilot/copilot-instructions.md`）、tier0／tier1／tier2、本 kernel 與其 `references/`、三 host 的 hooks 與 permission／sandbox settings、CI workflow。理由：[T0-9] 的觸發是「merge 前」，不開 PR 就沒有 merge 動作，該 gate 連同它唯一的獨立視角（bot review）會被整條繞過，且全程不違反任何既有條文——2026-08-03 有四個此類 commit 即如此落地，CI 全綠但 bot review 從未產生。本條補的是路徑選擇的觸發條件，[INT-1] 管的是時機、[S5-1] 管的是 review 深度，兩者都無法阻止「不開 PR」。Git-native `pre-push` safety rail 由 `hooks/pre-push-global-config.sh` 提供，執行 `bash hooks/install-hooks.sh --global-pre-push` 後才生效；未安裝時沒有機械 enforcement，`--no-verify` 可略過，且不保證 `--mirror` 的隱式刪除。觸發：diff 命中上列任一範圍。例外：使用者當下明示直接推 main。驗證：PR 編號 + `references/review-triage.md` 定義的四態 gate PASS 紀錄；例外時引用使用者原句。

退役 ID 殼標記（CONVENTIONS 規則 3：ID 永不重編、永不回收，舊 transcript 與 commit message 可能仍引用）：`[R-1 DEPRECATED→INT-1 2026-07]`、`[R-2 DEPRECATED→INT-2 2026-07]`。兩者原定義於 `core/routing.md`，該檔 2026-07-30 退役至 `attic/core/`；條文語意由上方 [INT-1]／[INT-2] 逐項承接。

## S0 ROUTE

由上而下套用需要的 method skills；可組合，不複製其方法 prose：

| Need | Route |
|---|---|
| 外部 issue／PR 的初始評估 | `triage` |
| 使用者明示要求接受訪談或壓測（對象為 under-specified plan／decision／idea；對象 under-specified 本身不構成 trigger） | `grilling`；領域詞彙與 ADR 另加 `domain-modeling` |
| 使用者明示邊討論邊產生 glossary／ADR | `grill-with-docs`（內含 `grilling` + `domain-modeling`） |
| 把已決內容整理成 spec | `to-spec` |
| 拆 tracer-bullet tickets | `to-tickets` |
| 超過單一 session 的決策地圖 | `wayfinder` |
| session 中斷且重要 context 尚未進 canonical artifact | `handoff` |
| 需求已清楚且單一 session 可完成（含已核准 spec／ticket） | 推薦使用者顯式 invoke `implement`；啟動後由 kernel adapter 管理，每個 slice 用 `tdd` |
| hard bug／flaky／performance diagnosis | `diagnosing-bugs` |
| code review | `code-review` |
| 高扇入共用介面變更 | MUST 先用 `deps-check` 列出完整 callers |
| Security | code／diff／path 的 focused data-flow review → `shared-security-review`；使用者明示 whole-codebase adversarial audit／pen-test 且接受持久化 artifacts → `security-audit`；CI／pre-commit／SBOM／container gate → `dependency-security-scan` |
| 架構、deep module、seam 設計 | `codebase-design`；另命中上列明示 trigger 時才組合 `grilling` |
| 陌生 repo | `acquire-codebase-knowledge` |
| primary-source background research／citable Markdown evidence | `research` |
| current library／framework／SDK／API／CLI／cloud lookup | `context7-mcp` |
| Microsoft concepts／tutorial／config；API signature／SDK sample | 前者 `microsoft-docs`；後者 `microsoft-code-reference` |
| 新 UI／redesign／缺少 visual direction | `ui-ux-pro-max`；再交給 host:codex-only Product Design ideation 或 host:claude-only frontend-design |
| 單檔且 ≤3 tasks 的低風險 change | `sdd` |
| 單一 skill behavior／invocation／description／pruning（skill scaffolding 由 host creator 負責） | `writing-great-skills` |
| skill folder keep／trim／delete／migrate 稽核 | `auditing-skill-folder`；verdict 不授權修改 |
| 單一 skill trigger failure | MUST 先有 preserved RED canary；caller 未提供時才由 `diagnosing-bugs` 建立；`auditing-skill-folder` Step 2c RED 或 diagnosis handoff 後續接 `writing-great-skills` |
| 使用者明示要掃整庫 deepening 機會 | `improve-codebase-architecture`（explicit-only） |

Routing 前先確認 skill path 與 frontmatter。Route 只選方法，不等於已 invoke；命中 user-only skill 時依 [INT-7] 推薦該 host 的 explicit invocation command 並等待。需要 delegation 時套 [INT-4]。

澄清類 routing 的 question eligibility：MUST 先查既有 context、code 與 sensible defaults，只問真正阻擋下一步且屬 user-owned 的 decision。其餘澄清不進 `grilling`，依 S2 判 plan gate 後由各 host 的 plan mode 承接。提問載體與批次規則屬 host adapter。

本表是 routing 的 single source。`ask-matt` 自述為「a router over the skills in this repo」，實際只涵蓋 22 支 Matt skill 中的 20 支（漏自身與 `resolving-merge-conflicts`）加 `/compact`，完全不含本表的自有與其他 vendored 項：`deps-check`、三支 security、`context7-mcp`、兩支 Microsoft docs、`ui-ux-pro-max`、`sdd`、`auditing-skill-folder`、`web-design-reviewer`、`bug-fix-settlement`、`acquire-codebase-knowledge`。它是 pinned upstream，描述不修；使用者叫它時把它當 Matt subset 的視圖，缺項回本表補齊。

Route 到 `research` 時，background agent 依 [INT-4] 自主判定；將 findings 寫入 repo Markdown 仍受 S2 authorization，未獲該授權不得落盤。

### Routing continuations

- `triage`、`grilling` 或 `wayfinder` 釐清需求後，單一 session 可完成的 coherent vertical slice 推薦使用者顯式 invoke `implement`。
- 多個可獨立驗收的 implementation slices：無 canonical spec 時依序推薦使用者顯式 invoke `to-spec` → `to-tickets`；已有完整 spec／agent-ready issue 時略過 `to-spec`，直接推薦 `to-tickets`。
- 每張 ticket 以 fresh session 開始，由使用者顯式 invoke `implement`；啟動後先進 isolated branch／worktree，再依 adapter 執行，fresh session 不豁免 S2。
- `wayfinder` 只處理跨 session 的決策迷霧；決策已清楚但實作量大時走 spec／tickets 分流。
- Skill audit finding 要求修改時先跑 vendored gate；`VND` 只回報、整體替換或移除，self-owned 才進 S2。
- 使用者明示要換 session、交接或讓另一個 agent 接手時，`handoff` 只橋接仍未進入 spec、ticket 或 wayfinder map 的重要 context；需要時依 [INT-7] 推薦 host-specific command 並等待使用者啟動。
- Agent 因 blocker 或 session 邊界必須停止且工作未完成時，若仍有未落盤的重要 context，將 `handoff` 列為唯一 next action；已有 canonical artifact 時只引用、不重複內容。一般 context compaction、任務已完成或只是內容很長 MUST NOT 觸發 `handoff`；same-conversation `/compact` 也 MUST NOT 觸發 `handoff`。

### UI/Web design continuation

- 新 UI／redesign 且沒有 URL、Figma、screenshot 或 mockup：先用 `ui-ux-pro-max` 產生 design-system guidance，再由 host ideation 能力提出恰好 3 個 visual directions；使用者選定後才寫 code。
- 已有 visual target：略過 ideation，保留該 target 與 repo 現行 design system 為 source of truth。
- 小型既有 UI 變更：預設不跑完整 design-system generation；只有現行規範留白時才做 targeted lookup。
- 實作交給對應 stack skill；visual asset 需要時才用 host image tools；完成後依 S4 留 browser evidence，並由 `web-design-reviewer` 做 rendered-page QA。

## S2 AUTHORIZE

1. 先依 [T0-8] 與 [INT-3] 判定 plan gate；schema、auth、payment、migration、deployment 與 destructive change 另附 rollback。
2. 核准前只保留 session plan／todo；只有 user／repo 要求或確有跨-session 價值時，才持久化到 `docs/agents/specs/`、`docs/agents/plans/` 或 `sdd/<slug>/`。
3. 有多種合理解讀且會改檔時，列假設與影響後停下發問；不得用 delegation 迴避授權（[INT-4]）。

## Implementation adapters

### BUGFIX RED → GREEN

先用 `diagnosing-bugs` 建立可重現 feedback loop（simple deterministic bug 可直接最小 repro），再依 [INT-2] 寫 failing regression test；只做最小 fix，看到 GREEN 後才進 S4。無 seam 必須明標例外與後續 `codebase-design`。

### Approved implementation

`implement` 必須先進 isolated worktree／branch，依 `tdd` 做 one-test→one-implementation vertical slices；`implement` 在 current/main 上 commit 是禁止的（MUST NOT），且完成後必須返回 S4 → S5 → S6。Delegation 依 [INT-4]。

`tdd` cycle 套 [INT-9]；wide／structural refactor 留到獨立核准 change 或 S5 finding，RED 時不得 refactor。

## S4 VERIFY

- Build／test／lint 與 task-specific probes 全跑；UI 變更留 browser evidence。
- Skill change 另驗 frontmatter、relative references 與 skill scripts；model-invoked 跑 positive/negative trigger canary，user-only 跑 explicit-only canary。
- 會部署時另跑 `frontend-release-verification` 或 `backend-release-verification`，再跑 `dependency-security-scan`；不部署標 SKIPPED。
- 中高風險附 before／after baseline；記錄 command、exit code 與必要輸出，不以「應該」代替。
- 任一 gate FAIL 回 implementation；delegated work 依 [INT-4] 由 main context 重驗。

## S5 REVIEW

- [S5-1] S5 MUST 依風險與 PR 狀態決定兩軸深度：中高風險或進 PR 執行 Standards 與 Spec，global workflow／security config 不得視為 trivial。觸發：進入 S5。例外：低風險且不進 PR 的 docs／local config／trivial change 可附理由標 `SKIPPED`。驗證：risk ledger + Standards／Spec status。
- [S5-2] Working tree dirty review MUST 在讀任何 raw diff 前完成 `references/dirty-review-package.md`；任一 finding 即 FAIL。觸發：working tree dirty review。例外：clean／fixed-point review 改用 `code-review`。驗證：三類 gitleaks exit code + package manifest。
- [S5-3] S5 的 review agent prompt MUST 含 house over-engineering baseline 兩條全文，不論 reviewer 型別（`code-review` 的 Standards 軸、`dotnet-code-reviewer` 等專屬 agent、或 `references/reviewer-template.md` 泛用 prompt 皆適用）：**Reinvented Stdlib** — 手刻標準庫或平台已提供的功能 → 指名該 API 取代；**Redundant Dependency** — 為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。兩條為 judgement call，documented repo standard 覆寫之。補這兩條是因為 Preflight ledger 的 Self-simplification 只做自檢，無獨立視角。觸發：進入 S5 且 review 非 SKIPPED。例外：無。驗證：review agent prompt 含該兩條全文。
- [S5-4] Review agent prompt MUST NOT 設 word count、字數或 finding 數量上限，MUST NOT 指示 reviewer「只報高嚴重度」「保守回報」「避免誤報」或在回報前自行丟棄項目。MUST 指示 reviewer 回報所有命中項（含 nitpick 與 `question:`）並逐條標 severity 與 confidence；篩選與排序由 main context 在 aggregate 階段以獨立 pass 完成，且**只在單一軸內進行**——跨軸不合併、不重排，該分離由 `skills/code-review/SKILL.md` 第 5 步定義，本條不覆寫之。理由：severity／數量過濾會壓低 recall（review-policy audit, 2026-08-02）。本條覆寫 `skills/code-review/SKILL.md`、`references/reviewer-template.md` 與 host agent 定義中相衝突的字數或過濾指示。觸發：組裝任何 review agent prompt。例外：無。驗證：prompt 內無字數／數量上限字樣，且含「全部回報、下游過濾」指示。
- 各軸只能標 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`。
- Spec 不存在可標 SKIPPED；缺 reviewer capability 必須附 UNAVAILABLE probe，不得假裝自審等價。
- Actionable finding 回 implementation；bug finding 先補 RED test（[INT-2]）。Delegation 依 [INT-4]。

## S6 CLOSEOUT

- 只有 [INT-1] 成立才 commit／push／open PR／merge／final closeout；commit／PR 用 zh-TW Conventional Commits。全域設定／security config 的**路徑選擇**依 [INT-10]（[INT-1] 只管時機，不管走不走 PR）。
- PR 路徑依 `references/ledgers.md` 填 Preflight／Closeout ledger；Ready PR 的 current-HEAD CI／bot-review gate 與唯一 command 由 `references/review-triage.md` 定義，該 gate PASS 才可 merge。
- BUGFIX 跑 `bug-fix-settlement`；架構變更同步 current architecture docs。
- 「分析 conflict」不得授權 resolve、stage 或 commit；只有使用者明示「解決 conflict」時才可執行 `resolving-merge-conflicts`。
- 執行 `resolving-merge-conflicts` 時只 stage 授權 scope 內已解決檔案，MUST NOT `git add -A`；若必要意圖無法安全保留或沒有解法符合 merge goal，停止並回報 trade-off，取得使用者確認後可 abort，不受上游「always resolve／stage everything」指示約束。
- 合併後依 repo policy 清理已合併 branch；不得 force-push main／master。

## Host adapters

**加嚴契約**：Host adapter 對本 kernel 只可加嚴，MUST NOT 放鬆其 MUST 或無條件約束；放鬆需 user 當下明示。加一條 kernel 沒有的 host-specific 約束屬加嚴，正當（例：Opus 5 的 delegation 收斂只寫在 Claude adapter）。本條寫在 seam 上而非 tier0 裁決鏈，是因為這組關係不是線性位階——host 可加、不可減，鏈上任一個位置都只能編碼其中一半；形狀比照 tier0 的「repo 層對 tier0 只可加嚴不可放鬆」。

Matt skill body 的 `/skill-name` 只表示 skill routing；需要顯式 invocation 時，實際 command 前綴與啟動權限以本節對應 host adapter 為準。

### Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent；決策提問 = AskUserQuestion。
- 決策提問 cadence：同一 ready frontier 上彼此獨立的 1–4 個 blocker MUST 合併在同一次 `AskUserQuestion`；dependent 題等前一批回答後再問。Skip／dismiss MUST NOT 視為答案、核准或採用預設值。
- user-only skill command = `/<skill-name>`。
- S5 適用時，Standards／Spec outcomes 仍須覆蓋；是否平行與 subagent 數量由 AI 依 [INT-4] 自主決定，review agent 保持 read-only；`uiux-reviewer` 是 Claude-only。

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
- S5 適用且 working tree dirty 時，依 [INT-4] 由 AI 自主決定是否、何時及使用多少 read-only `task` 完成 Standards／Spec outcomes；clean／fixed-point review 才執行 `code-review`。
- Copilot user-level hooks 已配置於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- 子代理沿用模型預設 effort；僅 hard debugging、security、migration 或高風險 review 升 `high`，`xhigh`／`max` 需量測證明收益。

## References

- `references/ledgers.md`
- `references/review-triage.md`
- `references/reviewer-template.md`
- `references/dirty-review-package.md`

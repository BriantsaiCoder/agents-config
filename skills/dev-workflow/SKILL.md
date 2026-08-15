---
name: dev-workflow
description: 開發任務必讀：三 host S0/S2/S4–S6 kernel。
---

<!-- FP:DEVWF-2026Q3 | tier: workflow | consumed-by: claude,codex,copilot -->

# dev-workflow

## Gate contract

- Gate 只用 `PASS`／`FAIL`／`SKIPPED`（理由）／`UNAVAILABLE`（probe）。
- Evidence = command exit／output、artifact probe 或 user／session artifact。
- Closeout 後的新 commit 依 `references/ledgers.md` 重驗；current HEAD CI／review 依 `references/review-triage.md` 整份重查。

## Always-on guards

- [INT-1] push／open PR／merge／final closeout MUST 只在 S4、S5 適用 gate PASS 後執行。觸發：任一收尾動作。例外：SKIPPED／UNAVAILABLE 須附理由或 probe。驗證：S4/S5 ledger 與 evidence 齊備。
- [INT-2] BUGFIX／既有 behavior 變更若有 stable、valuable 的 behavior seam，MUST 先有 failing regression test（RED→GREEN）；否則 MUST 以同一 minimal repro 留下 before／after evidence，並記錄不採 RED 的理由，MUST NOT 為流程新增低價值 seam。既有 public behavior seam 視為已確認，只有新增 seam 才需另向使用者確認。觸發：BUGFIX 或既有 behavior 變更。例外：無。驗證：RED evidence 早於 fix，或同一 repro 的 before／after evidence。
- [INT-3] [T0-8] protected gate MUST 停在 S2 等核准；auto／autopilot 不豁免，Medium-risk MUST NOT 成為第二次確認 gate。觸發：plan-first、architecture／High-risk、未授權 external／protected side effect、material scope expansion。例外：清楚、in-scope、local、reversible 的 Low／Medium-risk user-requested work 可做，Medium 留 session plan。驗證：protected gate 有核准原句；direct path 有 user 原句 + risk／reversibility。
- [INT-4] Delegation MUST 先讀並遵守 [delegation contract](references/delegation.md)；MUST NOT 用 delegation 迴避 S2 授權或 [T0-8] plan gate。觸發：任何 delegation。例外：host/runtime 容量與 higher-priority instructions。驗證：reference contract 全數成立。
- [INT-5] `setup-matt-pocock-skills` MUST 只在使用者明示時執行；tracker contract 優先 repo `docs/agents/issue-tracker.md`，否則讀 `~/.agents/docs/agents/issue-tracker.md`。觸發：需 tracker contract。例外：無。驗證：contract 或 setup 原句。
- [INT-6] 任何已核准、預計納入 VCS 的檔案新增／修改，首次寫入前 MUST 位於 task branch／worktree（非 main／master）；否則先建，current-branch 不得覆寫。觸發：新增／修改。例外：無。驗證：pre-write branch／baseline + S4–S6。
- [INT-7] `disable-model-invocation: true` 的 user-only skill MUST NOT 自動 invoke；S0 只推薦 host-specific explicit invocation command 並等待使用者啟動。觸發：命中 user-only skill。例外：無。驗證：frontmatter + invocation 原句。
- [INT-8] 核准清單與已核准 scope 內 local、reversible 工作 MUST 一次執行至完成，不得逐項重問或中途停下等指令；回報進度不是停止條件。blanket authorization 只涵蓋原句前已明列 scope。只有 [T0-5]、[T0-8]／[INT-3]、user-owned 取捨或工具／環境阻塞可中斷；新發現只列 follow-up，未核准不得做。觸發：≥2 個已核准項目，或已核准 scope 內實作。例外：無。驗證：核准原句早於新增 scope + 單次彙總 status／evidence。
- [INT-9] Kernel 只在 [INT-2] 選定 stable／valuable seam 時 route 到 [tdd](../tdd/SKILL.md)；既有 public behavior seam 視為已確認，只有新增 seam 才需先向使用者確認；每輪 GREEN 後可做一次不改 behavior 的 micro-refactor，且 MUST 立即重跑當輪 test。本條覆寫 upstream 的逐 seam 重問與固定 choreography。觸發：kernel 管理的 tdd cycle。例外：無。驗證：RED／GREEN／retest evidence。

- [INT-10] 全域／security config MUST 走 isolated branch → Ready PR → bot-review gate → squash merge → 刪 branch；MUST NOT 直接 push main／master。範圍：`CLAUDE.md`／`AGENTS.md`／`copilot-instructions.md`、tier0／tier1／tier2、kernel／references、hooks、permission／sandbox、CI workflow，以及 plugin install／enable、MCP 啟用、新 credential 或 external tool capability。`pre-push` 未安裝時沒有機械 enforcement；`--no-verify` 可略過且不保證 `--mirror` 隱式刪除。觸發：diff 命中範圍。例外：使用者當下明示直接推 main。驗證：PR + review-triage gate PASS；例外引用原句。

[R-1 DEPRECATED→INT-1 2026-07] [R-2 DEPRECATED→INT-2 2026-07]

## S0 ROUTE

由上而下 route；可組合：

| Need | Route |
|---|---|
| 外部 issue／PR 的初始評估 | `triage` |
| 使用者明示訪談／壓測 under-specified plan／decision／idea | `grilling`；領域詞彙／ADR 加 `domain-modeling` |
| 使用者明示邊討論邊產生 glossary／ADR | `grill-with-docs`（內含 `grilling` + `domain-modeling`） |
| 把已決內容整理成 spec | `to-spec` |
| 拆 tracer-bullet tickets | `to-tickets` |
| 超過單一 session 的決策地圖 | `wayfinder` |
| session 中斷且重要 context 尚未進 canonical artifact | `handoff` |
| 清楚且單一 session 可完成的需求／已核准 spec／ticket | 進 S2；VCS 變更套 [INT-6] |
| hard bug／flaky／performance diagnosis | `diagnosing-bugs` |
| code review | `code-review` |
| 高扇入共用介面變更 | MUST 先用 `deps-check` 列出完整 callers |
| Security | focused code／diff／path → `shared-security-review`；明示 whole-codebase audit／pen-test 且接受 artifacts → `security-audit`；SBOM／CI gate → `dependency-security-scan` |
| 架構、deep module、seam 設計 | `codebase-design`；另命中上列明示 trigger 時才組合 `grilling` |
| 陌生 repo | `acquire-codebase-knowledge` |
| repo docs／host-native AI 指令的初始化或整體 refresh | `init-project-docs`；探索地圖另走 `acquire-codebase-knowledge` |
| primary-source background research／citable Markdown evidence | `research` |
| Microsoft concepts／tutorial／config；API signature／SDK sample | 前者 `microsoft-docs`；後者 `microsoft-code-reference` |
| third-party library／SDK／API／CLI current lookup | provider-native official docs；absent／`UNAVAILABLE` 才 Context7 fallback（`context7-mcp`） |
| 新 UI／redesign／缺 visual direction | `ui-ux-pro-max`；host ideation capability 接續 |
| 單檔且 ≤3 tasks 的低風險 change | `sdd` |
| 既有單一 skill behavior／invocation／description／pruning，或既有 AGENTS.md／CLAUDE.md／pointed-at agent doc 的 authoring 品質 | `writing-for-agents`；canonical placement 先由 host workflow 決定，skill scaffolding 歸 host creator |
| skill folder keep／trim／delete／migrate 稽核 | `auditing-skill-folder`；verdict 不授權修改 |
| 單一 skill trigger failure | MUST 有 preserved RED；caller 無則 `diagnosing-bugs` 建；Step 2c RED／diagnosis 後接 `writing-for-agents` |
| 使用者明示要掃整庫 deepening 機會 | `improve-codebase-architecture`（explicit-only） |

先驗 path/frontmatter；route≠invoke。Intake、skill audit／VND、跨 session／ticket、research、handoff MUST 讀 [continuations](references/routing-continuations.md)。

## S2 AUTHORIZE

1. mutation／side effect 一律先讀 [authorization matrix](references/authorization-matrix.md)；mechanical trigger 決定 risk floor，AI 自評不得降級。
2. 核准前只留 session plan／todo；user／repo 要求或跨-session 才寫 `docs/agents/specs/`、`docs/agents/plans/`、`sdd/<slug>/`。Delegation 不得繞過授權（[INT-4]）。
3. 寫入前 MUST 記 `Delivery Scope: Local-only／PR-closeout`；後者須核准並依 S6，否則 `Local-only`。

## Implementation adapters

### BUGFIX RED → GREEN

用 `diagnosing-bugs` 建可重現 loop（deterministic bug 可用最小 repro）；stable／valuable seam 依 [INT-2] 寫 RED，否則留同一 repro before／after 與理由。最小 fix GREEN 後進 S4。

### Approved implementation

依 [INT-6]；`implement` 須在 branch／worktree，main／master 不得寫；完成回 S4→S5→S6；Delegation 依 [INT-4]。

`tdd` cycle 套 [INT-9]；wide／structural refactor 留到獨立核准 change 或 S5 finding，RED 時不得 refactor。

## S4 VERIFY

- Risk=blast radius/reversibility/contract/data/security;global workflow/security config=High,疑則上調。
- Low=targeted;Medium=affected suite/build/lint;High=full CI-equivalent+integration/E2E/security。只跑非等價增益 checks;M/H=before/after。Behavior-affecting edit、正式 spec artifact／明列 acceptance criteria、Medium／High／PR 或新增／修改 custom gate 讀 [evidence integrity](references/evidence-integrity.md)。
- Skill change 另驗 frontmatter、relative references 與 skill scripts；model-invoked 跑 positive/negative trigger canary，user-only 跑 explicit-only canary。UI 變更留 browser evidence。
- 會部署時另跑 `frontend-release-verification` 或 `backend-release-verification`，再跑 `dependency-security-scan`；不部署標 SKIPPED。
- 記錄 command、exit code 與必要輸出，不以「應該」代替。
- 任一 gate FAIL 回 implementation；delegated work 依 [INT-4] 由 main context 重驗。

## S5 REVIEW

- [S5-1] S5 MUST 依風險與 PR 狀態決定兩軸深度：中高風險或進 PR 執行 Standards 與 Spec，global workflow／security config 不得視為 trivial。觸發：進入 S5。例外：低風險且不進 PR 的 docs／local config／trivial change 可附理由標 `SKIPPED`。驗證：risk ledger + Standards／Spec status。
- [S5-2] Working tree dirty review MUST 在讀任何 raw diff 前完成 `references/dirty-review-package.md`；任一 finding 即 FAIL。觸發：working tree dirty review。例外：clean／fixed-point review 改用 `code-review`。驗證：三類 gitleaks exit code + package manifest。
- [S5-3] 非 SKIPPED 的 Standards 軸 prompt MUST 套用 `references/reviewer-template.md` 的 canonical over-engineering contract；專屬 reviewer 也須收到等價完整 contract。觸發：S5 review。例外：無。驗證：prompt evidence。
- [S5-4] Reviewer output MUST 套用 `references/reviewer-template.md` 的「全部回報、下游過濾」與單軸 aggregate contract。觸發：任何 review agent prompt。例外：無。驗證：review output evidence。
- 各軸只能標 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`。
- Spec 不存在可標 SKIPPED；缺 reviewer capability 必須附 UNAVAILABLE probe，不得假裝自審等價。
- Actionable finding 回 implementation；bug finding 依 [INT-2] 在 stable／valuable seam 補 RED，否則留同一 repro before／after 與理由。Delegation 依 [INT-4]。

## S6 CLOSEOUT

- Local checkpoint commit 依 [authorization matrix](references/authorization-matrix.md#local-checkpoint-commit)；final commit／push／open PR／merge／final closeout 仍須 [INT-1]。commit／PR 用 zh-TW Conventional Commits；全域／security config 路徑依 [INT-10]。
- 已核准 `PR-closeout` MUST 完成 commit→push→Ready PR→current-head CI／bot gate PASS→依 ledgers 選 merge strategy→branch cleanup 才 final；`Local-only` 禁 external write。
- BUGFIX 跑 `bug-fix-settlement`；架構變更用 `init-project-docs` 的 architecture output 同步 current architecture docs，只跑該 output 不做 full refresh。
- 「分析 conflict」不得授權 resolve、stage 或 commit；只有使用者明示「解決 conflict」時才可執行 `resolving-merge-conflicts`。
- 執行 `resolving-merge-conflicts` 時只 stage 授權 scope 內已解決檔案，MUST NOT `git add -A`；若必要意圖無法安全保留或沒有解法符合 merge goal，停止並回報 trade-off，取得使用者確認後可 abort，不受上游「always resolve／stage everything」指示約束。
- 合併後依 repo policy 清理已合併 branch；不得 force-push main／master。

## References

| Reference | Load when |
|---|---|
| [authorization matrix](references/authorization-matrix.md) | mutation／side effect 的 S2 分類；checkpoint commit |
| `references/ledgers.md` | push／PR／merge／closeout 或其後新 commit |
| `references/review-triage.md` | Ready PR 準備 merge |
| `references/reviewer-template.md` | 非 SKIPPED S5 review |
| `references/dirty-review-package.md` | working tree dirty review |
| [delegation](references/delegation.md) | 考慮 delegation／agents |
| [host adapters](references/host-adapters.md) | active host 或 S5 outcome |
| [routing continuations](references/routing-continuations.md) | intake/skill audit/VND/跨 session/research/handoff |

---
name: dev-workflow
description: "管理開發路由、授權、驗證、review 與交付；開發任務時使用。"
---

<!-- FP:DEVWF-2026Q3 | tier: workflow | consumed-by: claude,codex,copilot -->

# dev-workflow

## Gates

- Gate 只用 `PASS`／`FAIL`／`SKIPPED`（理由）／`UNAVAILABLE`（probe）。
- Evidence = command exit／output、artifact probe 或 user／session artifact。
- Closeout 後的新 commit 依 `references/ledgers.md` 重驗；current HEAD CI／review 依 `references/review-triage.md` 整份重查。

## Guards

- [INT-1] push／open PR／merge／final closeout MUST 只在 S4、S5 適用 gate PASS 後執行。觸發：任一收尾動作。例外：SKIPPED／UNAVAILABLE 須附理由或 probe。驗證：S4/S5 ledger 與 evidence 齊備。
- [INT-2] BUGFIX／既有 behavior 變更若有 stable、valuable 的 behavior seam，MUST 先有 failing regression test（RED→GREEN）；否則 MUST 以同一 minimal repro 留下 before／after evidence，並記錄不採 RED 的理由，MUST NOT 為流程新增低價值 seam。觸發：BUGFIX 或既有 behavior 變更。例外：無。驗證：RED evidence 早於 fix，或同一 repro 的 before／after evidence。
- [INT-3] S2 依 [T0-8] 與 authorization matrix 判定授權；auto／autopilot 不豁免 protected gate，Medium-risk 本身 MUST NOT 成為第二次確認 gate。觸發：進入 S2。例外：無。驗證：matrix 分類 + 適用時的核准原句。
- [INT-4] Delegation MUST 遵守 [contract](references/delegation.md)；已讀同版可重用；MUST NOT 用 delegation 迴避 S2 授權或 [T0-8] plan gate。觸發：任何 delegation。例外：host/runtime 容量與 higher-priority instructions。驗證：reference contract 全數成立。
- [INT-5] `setup-matt-pocock-skills` MUST 只在使用者明示時執行；需 tracker contract 時 MUST 讀 [intake](references/routing-continuations.md#intake-and-tracker)。觸發：需 tracker contract。例外：無。驗證：contract 或 setup 原句。
- [INT-6] 任何已核准、預計納入 VCS 的檔案新增／修改，首次寫入前 MUST 位於 task branch／worktree（非 main／master）；否則先建，current-branch 不得覆寫。觸發：新增／修改。例外：無。驗證：pre-write branch／baseline + S4–S6。
- [INT-7] `disable-model-invocation: true` 的 user-only skill MUST NOT 自動 invoke；S0 只推薦 host-specific explicit invocation command 並等待使用者啟動。觸發：命中 user-only skill。例外：無。驗證：frontmatter + invocation 原句。
- [INT-8] 核准清單與已核准 scope 內 local、reversible 工作 MUST 一次執行至完成，不得逐項重問或中途停下等指令；回報進度不是停止條件。blanket authorization 只涵蓋原句前已明列 scope。只有 [T0-5]、[T0-8]／[INT-3]、user-owned 取捨或工具／環境阻塞可中斷；因 skill 而確認／暫停／未完成時 MUST 附已讀 SKILL.md 連結、原句、適用理由，區分明文／推論；新發現屬已核准 scope 內必要修正且未新增未授權副作用時直接完成；超出原 scope 才列 follow-up，未核准不得做。觸發：≥2 個已核准項目，或已核准 scope 內實作。例外：無。驗證：核准原句早於新增 scope + 單次彙總 status／evidence。
- [INT-9] Kernel 只在 [INT-2] 選定 stable／valuable seam 時 route 到 [tdd](../tdd/SKILL.md)；MUST 套 [implementation](references/implementation.md) 的 seam／refactor 程序，覆寫下游同類條款。觸發：kernel 管理的 tdd cycle。例外：無。驗證：RED／GREEN／retest evidence。

- [INT-10] 全域／security config MUST 走 isolated branch → Ready PR → bot-review gate → squash merge → 刪 branch；MUST NOT 直接 push main／master。範圍：`CLAUDE.md`／`AGENTS.md`／`copilot-instructions.md`、tier0／tier1／tier2、kernel／references、hooks、permission／sandbox、CI workflow，以及 plugin install／enable、MCP 啟用、新 credential 或 external tool capability。Git guard 的限制依 [closeout operations](references/ledgers.md#closeout-operations)。觸發：diff 命中範圍。例外：使用者當下明示直接推 main。驗證：PR + review-triage gate PASS；例外引用原句。

## S0 ROUTE

依需求 route；可組合：

| Need | Route |
|---|---|
| Issue／PR intake、明示訪談、spec／tickets／決策地圖或跨 session handoff | MUST 依 [continuations](references/routing-continuations.md) 對應 section 選路；user-only 仍套 [INT-7] |
| 清楚且單一 session 可完成的需求／已核准 spec／ticket | 進 S2；VCS 變更套 [INT-6] |
| hard bug／flaky／performance diagnosis | `diagnosing-bugs` |
| code review | `code-review` |
| 高扇入共用介面變更 | MUST 先用 `deps-check` 列出完整 callers |
| Security | focused code／diff／path → `shared-security-review`；明示 whole-codebase audit／pen-test 且接受 artifacts → `security-audit`；SBOM／CI gate → `dependency-security-scan` |
| 架構、deep module、seam 設計 | `codebase-design`；另命中上列明示 trigger 時才組合 `grilling` |
| local code: system map | `mp-zoom-out` |
| Explicit repo-level map/docs/onboarding | `acquire-codebase-knowledge` |
| repo docs 初始化或整體 refresh | `init-project-docs` |
| substantial／background research report | `research`；單一 provider API/docs 查詢走下列 docs owner |
| Microsoft concepts／tutorial／config；API signature／SDK sample | 前者 `microsoft-docs`；後者 `microsoft-code-reference` |
| third-party library／SDK／API／CLI current lookup | provider-native official docs；absent／`UNAVAILABLE` 才 Context7 fallback（`context7-mcp`） |
| 新 UI／redesign／缺 visual direction | `ui-ux-pro-max`；host ideation capability 接續 |
| 單檔、單一行為且 ≤3 tasks 的低風險 change | 在 session 記行為、影響檔案與情境式驗收條件，進 S2 |
| 既有 skill／AGENTS.md／CLAUDE.md／agent doc 的 behavior、trigger 或 authoring | `writing-for-agents`；host workflow 選 canonical owner，新 skill 歸 host creator |
| skill folder keep／trim／delete／migrate 稽核 | `auditing-skill-folder`；verdict 不授權修改 |
| 單一 skill trigger failure | MUST 有 preserved RED；caller 無則 `diagnosing-bugs` 建；Step 2c RED／diagnosis 後接 `writing-for-agents` |
| 使用者明示要掃整庫 deepening 機會 | `improve-codebase-architecture`（explicit-only） |

先驗 path/frontmatter；route≠invoke。[Continuations](references/routing-continuations.md) 管 intake、跨 session／ticket、research 與 handoff 的轉換；只在命中該 transition 且 context 缺同版內容時 MUST 讀對應 section。Skill audit／VND 依 `auditing-skill-folder` Step 0；來源或狀態改變只更新相依 evidence。

## S2 AUTHORIZE

1. [Matrix](references/authorization-matrix.md) 管 mutation／side effect；首次分類或 effect／risk 改變時查閱，其餘沿用。mechanical trigger 決定 risk floor，AI 自評不得降級。
2. 核准前只留 session plan／todo；user／repo 要求或跨-session 才寫 `docs/agents/specs/`、`docs/agents/plans/`；SDD 產物／歸檔讀 [reference](references/sdd-artifacts.md)。Delegation 不得繞過授權（[INT-4]）。
3. 寫入前 MUST 記 `Delivery Scope: Local-only／PR-closeout`；後者須核准並依 S6，否則 `Local-only`。

## Implementation

### BUGFIX RED → GREEN

用 `diagnosing-bugs` 建可重現 loop（deterministic bug 可用最小 repro）；stable／valuable seam 依 [INT-2] 寫 RED，否則留同一 repro before／after 與理由。最小 fix GREEN 後進 S4。

### Approved implementation

依 [INT-6]；`implement` 須在 branch／worktree，main／master 不得寫；完成回 S4→S5→S6；Delegation 依 [INT-4]。

`tdd` cycle 套 [INT-9] 與 [implementation](references/implementation.md)。

## S4 VERIFY

- Risk floor 與授權分類只由 [matrix](references/authorization-matrix.md) 管；依 blast radius／reversibility／contract／data／security 判定，疑則上調。Policy、capability 與跨 host routing 維持 High；純排版與 personal preference 按 matrix 的實際 effect 分類。
- Low=targeted;Medium=affected suite/build/lint;High=full CI-equivalent+適用 integration/E2E/security。只跑非等價增益 checks。Behavior-affecting edit、正式 spec artifact／明列 acceptance criteria、Medium／High／PR 或新增／修改 custom gate 讀 [evidence integrity](references/evidence-integrity.md)。
- Skill change 驗 frontmatter、relative references，依變更面選 checks：description／invocation policy 變更跑相關 positive/negative trigger canary，user-only 跑 explicit-only canary；流程語意變更驗受影響流程，script 變更驗該 script。純排版／typo 用 parse、links、diff；完成 repo 明列 required checks，未變部分沿用有效 evidence。UI 變更留 browser evidence。
- 會部署時另跑 `frontend-release-verification` 或 `backend-release-verification`，再跑 `dependency-security-scan`；不部署標 SKIPPED。
- 記錄 command、exit code 與必要輸出，不以「應該」代替。
- 任一 gate FAIL 回 implementation；本機測試依 S2 的已授權範圍；delegated work 依 [INT-4] 由 main context 重驗。

## S5 REVIEW

- [S5-1] S5 MUST 依風險與 PR 狀態決定兩軸深度：中高風險或進 PR 執行 Standards 與 Spec，global workflow／security config 的 policy／capability 變更不得視為 trivial。觸發：進入 S5。例外：低風險且不進 PR 的 docs／local config／trivial change 可附理由標 `SKIPPED`。驗證：risk ledger + Standards／Spec status。
- [S5-2] Working tree dirty review MUST 在讀任何 raw diff 前完成 `references/dirty-review-package.md`；任一 finding 即 FAIL。觸發：working tree dirty review。例外：clean／fixed-point review 改用 `code-review`。驗證：三類 gitleaks exit code + package manifest。
- [S5-3] Standards prompt MUST 套用 [reviewer contract](references/reviewer-template.md#s5-dispatch-and-output-gates) 的完整 canonical over-engineering contract。
- [S5-4] Reviewer output MUST 套同一 reference 的 evidence-first actionable／單軸 aggregate contract，不得以字數／條數截斷 findings。
- 各軸只能標 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`。
- Spec 不存在可標 SKIPPED；缺 reviewer capability 必須附 UNAVAILABLE probe，不得假裝自審等價。
- Actionable finding 回 implementation；bug finding 依 [INT-2] 在 stable／valuable seam 補 RED，否則留同一 repro before／after 與理由。Delegation 依 [INT-4]。

## S6 CLOSEOUT

- Local checkpoint commit 依 [matrix](references/authorization-matrix.md#local-checkpoint-commit)；final commit／push／open PR／merge／final closeout 仍須 [INT-1]。commit／PR 格式與語言依 repo／active host instructions；全域／security config 路徑依 [INT-10]。
- 已核准 `PR-closeout` MUST 完成 commit→push→Ready PR→current-head CI／bot gate PASS→依 ledgers 選 merge strategy→branch cleanup 才 final；`Local-only` 禁 external write。
- BUGFIX 跑 `bug-fix-settlement`；架構變更用 `init-project-docs` 的 architecture output 同步 current architecture docs，只跑該 output 不做 full refresh。
- `resolving-merge-conflicts`、scoped staging／abort 與 branch cleanup MUST 依 [closeout operations](references/ledgers.md#closeout-operations)；分析不授權 mutation。

## References

| Reference | Load when |
|---|---|
| [matrix](references/authorization-matrix.md) | mutation／side effect 的 S2 分類；checkpoint commit |
| `references/ledgers.md` | push／PR／merge／closeout 或其後新 commit |
| `references/review-triage.md` | Ready PR 準備 merge |
| `references/reviewer-template.md` | 非 SKIPPED S5 review |
| `references/dirty-review-package.md` | working tree dirty review |
| [delegation](references/delegation.md) | 考慮 delegation／agents |
| [host adapters](references/host-adapters.md) | active host 或 S5 outcome |
| [routing continuations](references/routing-continuations.md) | 命中的 intake／tracker／跨 session／research／handoff section |
| [implementation](references/implementation.md) | kernel 管理的 tdd cycle／micro-refactor |

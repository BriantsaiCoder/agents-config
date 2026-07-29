# Phase 4 v2 Stage 1 — live baseline exception remediation evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 preflight。
> 結論：**單一 live untracked proposal 已以 exact path / SHA-256 / size 建立 temporary baseline exception；target 未修改或移動。未執行 SaaS、未重跑 Stage 1、未進 Stage 2。**

## 1. Authorization and baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- remediation baseline：`2746c36050f84d067af652bb5795afe036c9ef51`
- 使用者授權：不得修改或移動 `_population.md`；只將 exact path、SHA-256、size 納入 Stage 1 temporary baseline exception。
- 明確未做：SaaS、Stage 1 rerun、Stage 2、live file edit / move、wildcard exclusion、directory-wide exclusion。

風險為中：baseline exception 若過寬會遮蔽 live drift。Rollback 只需 revert 本 isolated candidate 的 data / evidence commit；live target 不需 rollback。

## 2. Temporary exception contract

Companion contract：

`33-phase4-v2-stage1-live-baseline-exception.json`

唯一例外：

- relative path：`proposals/2026-07-28-skill-writing-audit/_population.md`
- absolute path：`/Users/pochientsai/.agents/proposals/2026-07-28-skill-writing-audit/_population.md`
- Git status：`??`
- SHA-256：`db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
- size：`2348` bytes
- match policy：`absent-or-exact`
- expiry：Phase 4 v2 Stage 1 closeout後失效

Fail-closed semantics：

1. target不存在時，不形成 drift。
2. target存在時，path、Git status、SHA-256、size必須全部完全相符。
3. target內容或size改變，Stage 1必須在SaaS前FAIL。
4. 任何其他新增live drift仍在SaaS前FAIL。
5. exception不得套用到Stage 2。

## 3. Local verification

| Gate | Result |
|---|---|
| JSON parse | PASS |
| Contract shape | PASS — version 1、scope exact、temporary true、exceptions 1 |
| Wildcard / directory exclusion | PASS — 0 |
| Target path | PASS — exact |
| Target Git status | PASS — `??` |
| Target SHA-256 | PASS — exact |
| Target size | PASS — `2348` |
| Target before / after metadata | PASS — unchanged |
| Candidate `git diff --check` | PASS |
| Credential pattern scan | PASS — 0 hit |
| SaaS attempts | PASS — `0` |

Target before / after：

- birth / modify / change：`2026-07-28 07:13:01 CST`
- SHA-256：`db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
- size：`2348` bytes

## 4. Scope and rollback

Candidate-only changes：

1. 新增 single-entry temporary exception JSON。
2. 新增本 evidence。

沒有修改 matrix、schema、launcher、harness、live config、plugin或target。需要撤銷時，只在 isolated branch revert本 commit；禁止以刪除或移動live target作rollback。

## 5. Budget and roadmap

- Stage 1 SaaS runs：`0`
- review carriers：`0`
- retries：`0`

- M0 — COMPLETE
- M1 — CURRENT：temporary baseline exception local verification完成；停在 Stage 1 fresh rerun budget gate
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 Phase 4 v2 Stage 1 fresh rerun authorization**。未取得新的6-run授權前，不執行任何row；不得由本 exception自動進Stage 2。

## Closeout Ledger

- Self-simplification — PASS：data-only single-entry contract；沒有新增validator framework、wildcard或shared code。
- Diff self-review — PASS：只新增兩個candidate evidence files；live target不在diff。
- Relevant verification — PASS：本檔第3節；exception present時 exact match，mismatch / additional drift fail-closed。
- Review gate — UNAVAILABLE：本 remediation 禁止SaaS與額外review carrier；primary context完成self-review。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge。
- Residual risks — target來源未能精確歸因且內容有分類錯誤；exception只承認其存在，不認可內容正確性。

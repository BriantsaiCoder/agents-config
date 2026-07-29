# Phase 4 v2 two-host waiver — Stage 2 budget-gate evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 acceptance amendment。
> 結論：**使用者明示將Copilot從M1 acceptance與Stage 2 scope排除。Claude與Codex Stage 1 gate改為PASS_WITH_USER_WAIVER；原three-host Stage 1與Copilot verdict仍為FAIL且不改寫。目前停在two-host Stage 2 budget 30 gate，SaaS授權0、Stage 2 attempts 0。**

## 1. Explicit user decision

使用者原句：

> 確認Copilot從M1 acceptance與Stage 2 scope排除；
> Stage 2只驗證Claude與Codex。

本decision只改變後續M1 acceptance與Stage 2 scope，不回溯修改既有raw artifacts、row verdict或evidence。

## 2. Candidate and append-only contract

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- amendment起始 HEAD：`c9c72eb1937ee44fef3b1d59c9af115ca6600f65`
- waiver contract commit：`9bfdd1c50d9763c5f8965516601e112854c9e824`
- waiver contract：`43-phase4-v2-two-host-acceptance-waiver.json`
- waiver contract SHA-256：`e6590fb9503c87bd83e9fe26d806f763a68610a61bb0b2bc0d65f7a0e99a2df8`

原fail-fast evidence保持原樣：

- path：`42-phase4-v2-stage1-reauthorized-copilot-network-metadata-fail-fast-evidence.md`
- commit：`c9c72eb1937ee44fef3b1d59c9af115ca6600f65`
- SHA-256：`5e8a5012ea02102b4b2fcb7c0a6b7c1f81644f0d56e4f90768ab4c01e8cf9fe3`

## 3. Stage 1 acceptance after waiver

| Host | Requirement | Historical rows | Historical verdict | Waiver treatment |
|---|---|---:|---|---|
| Claude | required | 2 / 2 | PASS | required PASS |
| Codex | required | 2 / 2 | PASS | required PASS |
| Copilot | excluded | A FAIL；B unexecuted | FAIL | accepted risk / excluded；不得改標PASS |

Gate vocabulary：

- Claude + Codex two-host Stage 1：**PASS_WITH_USER_WAIVER**
- 原three-host Stage 1：**FAIL**
- Copilot：**FAIL / EXCLUDED**
- three-host migration-safety PASS：禁止宣稱

## 4. Exact two-host Stage 2 scope

Canonical matrix：

- path：`27-phase4-v2-canary-matrix.jsonl`
- SHA-256：`93015a2b5b15aa495d98dbc9a1228a1c1b7c848469a3185dde4827c92135d8b7`
- selection：Stage 2 rows依canonical `run_order`過濾exact hosts `claude`、`codex`
- ordered 24-row scope SHA-256：`9bf77683f99428adc126a88599ebcc1d71869b4a69a707161a4335f17207a65e`
- exact ordered IDs：以waiver contract的`stage2_scope.ordered_top_level_rows`為唯一清單

| Host | Top-level rows | Review carriers | Total SaaS |
|---|---:|---:|---:|
| Claude | 12 | 3 | 15 |
| Codex | 12 | 3 | 15 |
| Copilot | 0 | 0 | 0 |
| **Total** | **24** | **6** | **30** |

Required-host semantics保持：

- retry budget per row：0
- Claude或Codex任一row FAIL / UNAVAILABLE：立即停止全部後續row
- unused budget：不得挪用
- Copilot rows / carriers：不得建立或執行

## 5. Current Stage 2 gate

| Gate item | State |
|---|---|
| Stage 2 budget granted | false |
| Authorized SaaS runs | 0 |
| Stage 2 execution authorized | false |
| Fresh Stage 2 scratch | not created |
| Fresh Stage 2 live exception | not created |
| Stage 2 attempts | 0 |

前次`41-phase4-v2-stage1-reauthorized-fresh-rerun-live-baseline-exception.json`是Stage-1-only且已隨closeout失效，禁止重用於Stage 2。

未來若重新授權Stage 2：

1. 必須以當時candidate HEAD與clean state重新preflight。
2. 必須重新驗證live fingerprints與所有dirty / untracked attribution。
3. 若`_population.md`仍為同一exact path / SHA-256 / size，才可另建Stage-2-only exact-match exception。
4. 必須建立fresh Stage 2 scratch，不覆寫任何historical / Stage 1 artifacts。
5. 必須取得SaaS budget exactly 30的新grant。

## 6. Local verification

| Gate | Result |
|---|---|
| Waiver JSON parse / semantic assertions | PASS |
| Exact required / excluded hosts | PASS — Claude、Codex required；Copilot excluded |
| Canonical matrix SHA-256 | PASS |
| Exact ordered 24-row list / SHA-256 | PASS |
| Budget arithmetic | PASS — 24 top-level + 6 carriers = 30 |
| Per-host arithmetic | PASS — Claude 15、Codex 15、Copilot 0 |
| Historical evidence SHA-256 | PASS |
| Historical required Stage 1 rows | PASS — 4 / 4 |
| Copilot historical FAIL preservation | PASS |
| Copilot B unexecuted preservation | PASS |
| `bash -n` / ShellCheck | PASS — 4 Phase 4 scripts |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `33 PASS / 0 FAIL` |
| Launcher plans | PASS — `6 PASS / 0 FAIL` |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Contract-commit gitleaks | PASS |
| `git diff --check` / commit check | PASS |

DCT build / MySQL E2E：SKIPPED；本amendment只新增workflow decision/evidence，不修改DCT runtime、schema或importer。

## 7. Live postflight

- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.agents` status：原7 paths，無additional drift
- `_population.md`：SHA-256 `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17` / `2348` bytes
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- `~/.claude` status：既有 `M settings.json`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Claude policy：`db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

Live config、plugin、workflow、fixture與DCT mutation皆為0；不需live rollback。

## 8. Roadmap and next gate

- M0 — COMPLETE
- M1 — CURRENT：Stage 1 two-host acceptance **PASS_WITH_USER_WAIVER**
- M1 next gate — **Stage 2 Claude + Codex budget exactly 30 authorization**
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

未取得新Stage 2授權前：

- 不建立Stage 2 scratch或live exception
- 不執行任何Claude / Codex Stage 2 row
- 不執行任何Copilot row
- 不建立或挪用SaaS budget
- 不修改或部署live config

## Closeout Ledger

- Self-simplification — PASS：只新增append-only waiver contract與本evidence；未修改matrix、launcher、harness或workflow implementation。
- Diff self-review — PASS：Copilot FAIL保留、three-host FAIL保留；two-host claim與禁止claim分開記錄。
- Relevant verification — PASS：waiver語義、24 + 6 = 30 budget、既有Stage 1 artifacts、Phase 4 gates與live postflight均有機械證據。
- Review gate — UNAVAILABLE：未使用subagent或額外model reviewer；primary context完成scope與contract self-review。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；只建立isolated local decision/evidence commits。
- Residual risks — Copilot未取得migration-safety，且被明示排除；two-host Stage 2仍需fresh budget、scratch、live preflight與必要Stage-2-only exact exception。Rollback為反向revert本evidence commit與`9bfdd1c`；live不需rollback。

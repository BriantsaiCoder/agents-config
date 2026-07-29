# Phase 4 v2 two-host Stage 2 — Claude closeout route fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Claude + Codex Stage 2。
> 結論：**Stage 2 為 FAIL。Claude 在 `claude-a-closeout` 的第 12 個 SaaS attempt 違反 v2 route telemetry contract，依 canonical fail-fast 停止；Codex 完全未執行。Budget consumed 12 / 30，remaining 18，retry 0。**

## 1. Authorization and immutable scope

使用者明示授權：

> 我明示授權執行 M1 Phase 4 v2 Claude + Codex Stage 2。

後續 scope 修正：

> 改以 canonical 24 top-level + 6 review carriers 執行；
> 撤回 zero review carriers 條款。

Credential carrier 最終授權只允許 Stage 2 使用，且本次 fail-fast 後保留：

- Claude credential：`set`
- Codex credential：`set`
- credential exact-byte matches in scratch：`0`
- secret 值未輸出、未寫入 candidate evidence

Canonical contracts：

- matrix：`27-phase4-v2-canary-matrix.jsonl`
- matrix SHA-256：`93015a2b5b15aa495d98dbc9a1228a1c1b7c848469a3185dde4827c92135d8b7`
- waiver：`43-phase4-v2-two-host-acceptance-waiver.json`
- waiver SHA-256：`e6590fb9503c87bd83e9fe26d806f763a68610a61bb0b2bc0d65f7a0e99a2df8`
- ordered 24-row scope SHA-256：`9bf77683f99428adc126a88599ebcc1d71869b4a69a707161a4335f17207a65e`
- budget：Claude 15、Codex 15、Copilot 0；total 30
- retry budget：0
- fail-fast：required host 任一 row FAIL / UNAVAILABLE 後停止全部後續 attempts

## 2. Candidate and Stage-2-only exception

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- authorized starting HEAD：`a6198d3a05977bdc7b31b25397f7d6e3ac5ba158`
- Stage-2-only exception commit：`2ee7315000dde0eb399b92dc7a3661b4b85b8e0a`
- exception：`46-phase4-v2-stage2-two-host-live-baseline-exception.json`
- exception SHA-256：`7899865027f65c23e40023ea1e94f19e6eb8f1c3a2237f1d97b79bd6771fec50`
- exception scope：one exact `_population.md` path；no wildcard、no directory exclusion、no Copilot、no M1.5、no live write

## 3. Pre-SaaS gates

| Gate | Result |
|---|---|
| Candidate path / branch / expected starting HEAD / clean | PASS |
| Evidence 44、plan 45、waiver 43、schema 26、matrix 27 | PASS — full read / exact hashes |
| Live Git boundaries and exact dirty / untracked attribution | PASS |
| `_population.md` exact path / SHA-256 / size / mode | PASS |
| Claude settings / policy fingerprints | PASS |
| Codex AGENTS / Copilot instructions fingerprints | PASS |
| Matt lock / assessed commit / 22 skills | PASS |
| Three rollback carriers | PASS |
| Stage-2-only exception JSON | PASS |
| Fresh active scratch | PASS — 24 cases、24 plans、0 attempts |
| Budget plan | PASS — 24 top-level + 6 carriers = 30；retry 0；Copilot 0 |
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
| Scratch sync / check / doctor / conformance | PASS — `17 PASS / 0 FAIL` |
| gitleaks | PASS — 128 commits、no leaks |
| `git diff --check` | PASS |

DCT build / MySQL E2E：SKIPPED；本輪只執行 isolated workflow canary，不修改 DCT runtime、schema 或 importer。

Pre-SaaS orchestration incidents未計入 SaaS budget：

1. `legacy-mp-collision.sh` selftest 初次使用錯誤參數 `--self-test`，usage exit 2；依腳本實際 usage 改用 `--selftest` 後 PASS。
2. 第一個 Stage 2 runner 在 `spawn()` 前因 Node local variable shadowing觸發 TDZ exception；process count 0、event bytes 0、SaaS attempts 0。該 scratch完整保留於 `/private/tmp/phase4-canary-v2-stage2-pre-spawn-tdz-2ee7315`，修正後重新建立 fresh active scratch。

## 4. 30-slot attempt ledger

`PASS` 表示該 attempt 所屬 row通過 canonical harness；`FAIL` 表示 process完成但 harness失敗；`UNEXECUTED` 不代表 host PASS / FAIL。

| Slot | Host | Row | Attempt | Role | State | Evidence |
|---:|---|---|---|---|---|---|
| 1 | claude | `claude-a-feature` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 2 | claude | `claude-b-feature` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 3 | claude | `claude-a-bugfix` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 4 | claude | `claude-b-bugfix` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 5 | claude | `claude-a-diagnosis` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 6 | claude | `claude-b-diagnosis` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 7 | claude | `claude-a-review` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 8 | claude | `claude-a-review` | builtin-review-carrier | review | **PASS** | observed-in-parent;harness-PASS |
| 9 | claude | `claude-b-review` | top-level | — | **PASS** | process-exit-0;harness-PASS |
| 10 | claude | `claude-b-review` | builtin-review-carrier | standards | **PASS** | observed-in-parent;harness-PASS |
| 11 | claude | `claude-b-review` | builtin-review-carrier | spec | **PASS** | observed-in-parent;harness-PASS |
| 12 | claude | `claude-a-closeout` | top-level | — | **FAIL** | process-exit-0;harness-FAIL;selected-workflow-missing |
| 13 | claude | `claude-b-closeout` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 14 | claude | `claude-a-missing-evidence` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 15 | claude | `claude-b-missing-evidence` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 16 | codex | `codex-b-feature` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 17 | codex | `codex-a-feature` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 18 | codex | `codex-b-bugfix` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 19 | codex | `codex-a-bugfix` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 20 | codex | `codex-b-diagnosis` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 21 | codex | `codex-a-diagnosis` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 22 | codex | `codex-b-review` | external-review-carrier | standards | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 23 | codex | `codex-b-review` | external-review-carrier | spec | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 24 | codex | `codex-b-review` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 25 | codex | `codex-a-review` | external-review-carrier | review | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 26 | codex | `codex-a-review` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 27 | codex | `codex-b-closeout` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 28 | codex | `codex-a-closeout` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 29 | codex | `codex-b-missing-evidence` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |
| 30 | codex | `codex-a-missing-evidence` | top-level | — | **UNEXECUTED** | fail-fast-after-claude-a-closeout |

## 5. Failure evidence

`claude-a-closeout`：

- Claude process：exit 0
- timeout：false
- retry：0
- parent stderr bytes：0
- canonical harness：FAIL — `v2 route telemetry contract failed`
- expected selected workflow：`superpowers:finishing-a-development-branch`
- actual selected workflows：empty
- actual supporting workflows：`dev-workflow`
- supporting allowlist、event sequence、event shape、uniqueness、forbidden-prefix checks：PASS
- root mismatch：required selected workflow was not invoked / recorded

因此不得把 process exit 0 誤標為 host PASS，也不得重跑本 row。

## 6. Per-host verdict and budget ledger

| Host | Authorized | Consumed | Remaining | Top-level result | Carrier result | Verdict |
|---|---:|---:|---:|---|---|---|
| Claude | 15 | 12 | 3 | 8 PASS / 1 FAIL / 3 unexecuted | 3 PASS / 0 unexecuted | **FAIL** |
| Codex | 15 | 0 | 15 | 0 attempted / 12 unexecuted | 0 attempted / 3 unexecuted | **UNEXECUTED** |
| Copilot | 0 | 0 | 0 | excluded | excluded | **EXCLUDED** |
| **Total** | **30** | **12** | **18** | **9 attempted** | **3 attempted** | **FAIL** |

- successful attempt slots：11
- failed attempt slots：1
- unexecuted attempt slots：18
- retry attempts：0
- unused budget reallocated：0

Codex verdict不得由 Claude結果推論；Codex僅因 global fail-fast而未執行。

## 7. Rollback and scratch state

- attempted top-level fixtures：9
- fixture rollback：9 / 9 clean
- expected / actual rollback fingerprints：9 / 9 exact
- live config mutation：0
- live rollback：not required
- existing rollback carriers：3 / 3 unchanged
- active scratch：`/private/tmp/phase4-canary-v2`
- prior Stage 1 scratch：`/private/tmp/phase4-canary-v2-stage1-final-a6198d3`
- pre-spawn TDZ scratch：`/private/tmp/phase4-canary-v2-stage2-pre-spawn-tdz-2ee7315`
- raw artifacts、result、attempt marker與ledger皆留在 private scratch，未覆寫 historical artifacts

## 8. Live fingerprints before / after

| Surface | Before | After | Result |
|---|---|---|---|
| `~/.agents` | `main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f` / exact 7 paths | same | PASS |
| `_population.md` | `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17` / 2348 / 0644 | same | PASS |
| `~/.claude` | `main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4` / ` M settings.json` | same | PASS |
| Claude settings | `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32` / 10647 / 0644 | same | PASS |
| Claude policy | `db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7` / 7829 / 0644 | same | PASS |
| `~/.codex` | `main` / `bd1195dbee85b405b959a387b59f64d5449ab581` / ` M AGENTS.md` | same | PASS |
| Codex AGENTS | `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372` / 8425 / 0644 | same | PASS |
| `~/.copilot` | `main` / `4b47fee53c68644f1dbcd75136440c01fda09f9d` / ` M copilot-instructions.md` | same | PASS |
| Copilot instructions | `9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c` / 9165 / 0644 | same | PASS |
| Matt lock | `8de7d847f7d1a12d6e2272accad9fb774557782b5fd602b1ad4b5495a7f0c721` / 610 / 0644 | same | PASS |

## 9. M0–M5 roadmap

- M0 — **COMPLETE**
- M1 — **CURRENT / Stage 2 FAIL**
  - original three-host Stage 1：FAIL
  - two-host Stage 1 waiver：PASS_WITH_USER_WAIVER
  - two-host Stage 2：FAIL at `claude-a-closeout`
  - Codex Stage 2：UNEXECUTED
- M1.5 — **PENDING / NOT AUTHORIZED**
- M2 — **PENDING / NOT AUTHORIZED**
- M3 — **PENDING / NOT AUTHORIZED**
- M4 — **PENDING / NOT AUTHORIZED**
- M5 — **PENDING / NOT AUTHORIZED**

## 10. Unique next gate

**另行取得使用者對「M1 Stage 2 failure-disposition / remediation planning」的明示授權。**

在該 gate 前：

- 不重跑 `claude-a-closeout`
- 不執行剩餘 Claude / Codex rows
- 不挪用剩餘 18 budget
- 不修改 matrix、launcher、workflow、live config
- 不執行 M1.5、M2 或後續 milestone

若未來核准新的完整 rerun，必須另有 fresh exact budget 30、fresh scratch、fresh Stage-2-only exception、live exact preflight；本輪未用 budget不得沿用。

## Closeout Ledger

- Self-simplification — PASS：candidate只新增 Stage-2-only exact exception與本 terminal evidence；runner／raw artifacts只存在 private scratch，未新增 dependency或 framework。
- Diff self-review — PASS：30 slots、host verdict、budget、route failure、rollback、roadmap與禁止 claim逐項核對；Copilot與Codex未被推論為 PASS / FAIL。
- Relevant verification — PASS：local gates全綠；12 attempt completions、0 retries、9 / 9 fixture rollback、credential exact-byte scan、live exact postflight均有機械證據。
- Review gate — UNAVAILABLE：依使用者邊界未使用協作 subagent或額外 research delegation；canonical Claude review carriers已依 matrix計入並通過，但不拿它們審查本 evidence。
- PR / CI / review status — SKIPPED：未 push、未開 PR、未 merge、無 remote mutation；DCT CI不適用。
- Residual risks — Stage 2仍為 FAIL；Codex完全未驗證；Keychain credential依最新授權在 fail-fast後保持 `set`；唯一下一 gate是 M1 Stage 2 failure-disposition / remediation planning authorization。

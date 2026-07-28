# Phase 4 v2 Stage 1 post-remediation rerun — Claude live-read fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 post-remediation fresh rerun。
> 結論：**Claude A PASS；Claude B process成功，但一個`Read` tool event命中禁止的live `~/.agents` prefix且tool result為non-error，因此harness FAIL並立即fail-fast。Codex A/B、Copilot A/B與Stage 2皆未執行。**

## 1. Authorization and isolated baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- 使用者指定起始 HEAD：`b4fba800df3665e292b83929a39ed0c69a7eb784`
- 起始 HEAD / clean / live fingerprints：修改與SaaS前皆exact-match PASS
- fresh exception commit：`7078588d8c0e4919c91b9ed6d0885538a4b21bf6`
- fresh exception SHA-256：`b729d1b1c7808127f1755250a8c4af125a0e4b2ca4bc39f62e44f2b02657ba30`
- active scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`

本輪授權：

1. Claude A
2. Claude B
3. Codex A
4. Codex B
5. Copilot A
6. Copilot B

Top-level SaaS budget exactly 6、review carriers 0、retry 0。任一row FAIL / UNAVAILABLE立即停止，未用budget不得挪用。

## 2. Fresh Stage-1-only exact-match exception

Companion contract：

`39-phase4-v2-stage1-post-remediation-live-baseline-exception.json`

唯一例外：

- exact path：`/Users/pochientsai/.agents/proposals/2026-07-28-skill-writing-audit/_population.md`
- Git status：`??`
- SHA-256：`db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
- size：`2348` bytes
- match policy：`present-and-exact`
- wildcard / directory-wide exclusion：0
- Stage 2 use：禁止

本exception隨本次Stage 1 fail-fast closeout失效，不得重用。

## 3. Pre-SaaS gates

| Gate | Result |
|---|---|
| Candidate path / branch / starting HEAD / clean | PASS |
| Live `~/.agents` branch / HEAD / exact 7-path attribution | PASS |
| Live `~/.claude` branch / HEAD / existing dirty attribution | PASS |
| `_population.md` exact path / SHA-256 / size | PASS |
| Claude settings / policy fingerprints | PASS |
| Codex AGENTS fingerprint | PASS |
| Copilot instructions fingerprint | PASS |
| Three rollback carriers | PASS |
| Host versions | PASS — Claude 2.1.220、Codex 0.145.0、Copilot 1.0.75 |
| Credential carriers | PASS — Claude / Codex / Copilot均為set；未輸出值 |
| Fresh scratch | PASS — 6 cases、6 plans、0 SaaS attempts |
| Stage 1 plan budget | PASS — each top-level 1、nested 0、retry 0、carrier 0 |
| Fixture / Arm A-B policy isolation | PASS |
| `bash -n` / ShellCheck | PASS — 4 Phase 4 scripts |
| Result schema / matrix unchanged | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `33 PASS / 0 FAIL` |
| Launcher plans | PASS — `6 PASS / 0 FAIL` |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Scratch sync check / doctor / conformance | PASS — `17 PASS / 0 FAIL` |
| Candidate-range gitleaks | PASS — 29 commits |
| `git diff --check` / scope diff | PASS |

DCT build / MySQL E2E：SKIPPED；本輪未修改DCT runtime、schema或importer。

## 4. Preserved pre-spawn orchestration incident

第一次準備啟動Claude A時，outer zsh在process spawn前因array index差異中止：

- model process：0
- network / SaaS call：0
- raw event file：absent
- process metadata：absent
- budget consumption：0

該scratch未刪除或覆寫，完整保留於：

`/private/tmp/phase4-canary-v2-pre-spawn-20260728-201924`

之後建立全新active scratch，重新驗證auth、6 plans、fixture、inventory、harness `33/0`、launcher `6/0`與live exact state後，才正式啟動Claude A。此事件不是SaaS retry。

## 5. Executed rows

| Order | Row | Process | Route telemetry | Mutation | Validation | Verdict |
|---:|---|---|---|---:|---|---|
| 1 | `claude-a-architecture` | exit 0；timeout false；197,836 ms | selected `mp-improve-codebase-architecture`；supporting `dev-workflow`；2 events | 0 | schema / harness / credential scan / gitleaks PASS | **PASS** |
| 2 | `claude-b-architecture` | exit 0；timeout false；185,721 ms | selected `codebase-design`；supporting `dev-workflow`；2 events | 0 | structured result PASS；harness forbidden-live-path FAIL | **FAIL** |

未執行：

3. `codex-a-architecture`
4. `codex-b-architecture`
5. `copilot-a-architecture`
6. `copilot-b-architecture`

## 6. Claude B fail-fast finding

Claude B產出符合result schema的單一structured result，route contract與fixture mutation也符合預期；harness仍正確拒絕：

- failing gate：`tool call referenced a forbidden live path`
- forbidden tool events：1
- tool name：`Read`
- matched prefix：`/Users/pochientsai/.agents`
- corresponding tool result：1
- tool result `is_error`：false
- fixture mutation：0
- live mutation：0
- credential exact-value scan：PASS
- artifact gitleaks：PASS
- retry：0
- review carrier：0

Raw tool input、tool result content、model prose與credential值都未輸出或寫入candidate evidence。

依本輪限制，未修改schema、matrix、launcher、harness、route semantics或workflow implementation，也未重跑Claude B。

## 7. Budget and per-host verdict

| Host | Authorized | Attempts | PASS | FAIL | Unexecuted | Verdict |
|---|---:|---:|---:|---:|---:|---|
| Claude | 2 | 2 | 1 | 1 | 0 | **FAIL** |
| Codex | 2 | 0 | 0 | 0 | 2 | **UNAVAILABLE** — upstream fail-fast prevented evaluation |
| Copilot | 2 | 0 | 0 | 0 | 2 | **UNAVAILABLE** — upstream fail-fast prevented evaluation |
| **Total** | **6** | **2** | **1** | **1** | **4** | **FAIL** |

- Review carriers：0
- Retries：0
- Unused budget：4；未挪用
- Stage 2 attempts：0

不得宣稱三host migration-safety PASS，也不得把Claude A舊PASS拼接到未來rerun。

## 8. Scratch preservation

Historical / fresh attempts皆保留：

- `/private/tmp/phase4-canary-v2-stage1-first-run-20260728-061738`：2
- `/private/tmp/phase4-canary-v2-prior-20260728-071319`：1
- `/private/tmp/phase4-canary-v2-schema-fail-20260728-185848`：3
- `/private/tmp/phase4-canary-v2-copilot-fail-20260728-201023`：5
- `/private/tmp/phase4-canary-v2-pre-spawn-20260728-201924`：0 SaaS processes
- `/private/tmp/phase4-canary-v2`：2

未覆寫任何歷史raw artifact、attempt或result。

## 9. Live postflight

- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.agents` status：原7 paths，無additional drift
- `_population.md`：exact SHA-256 / size仍相同
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- `~/.claude` status：既有 `M settings.json`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Claude policy：`db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

Live config、plugin、workflow、fixture與DCT mutation皆為0；不需live rollback。

## 10. Roadmap and next gate

- M0 — COMPLETE
- M1 — CURRENT / FAILED：Stage 1停在Claude B forbidden live-read boundary
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 Claude B forbidden live-read investigation / remediation decision gate**。

未取得新授權前：

- 不修改schema、launcher、harness或workflow
- 不重跑Claude A/B
- 不執行Codex A/B或Copilot A/B
- 不建立或挪用SaaS budget
- 不執行任何Stage 2 row

若未來重新授權fresh Stage 1，必須使用新budget、新scratch、新exact exception，並從Claude A重新開始完整6列。

## Closeout Ledger

- Self-simplification — PASS：沿用既有launcher、harness與metadata-only probes；candidate只新增exact exception與本evidence。
- Diff self-review — PASS：無schema、matrix、launcher、harness、workflow或live變更；raw artifacts未進repo。
- Relevant verification — PASS：pre-SaaS local gates全綠；Claude A完整PASS；Claude B以機械harness FAIL；2 process、0 retry、0 carrier、0 mutation。
- Review gate — UNAVAILABLE：使用者禁止subagent與額外model reviewer；本輪review carriers固定為0。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；只建立isolated local evidence commits。
- Residual risks — Claude B可成功讀取禁止的live `~/.agents` path；未判定CLI policy或launcher guard的根因。Rollback為依反向順序revert本evidence commit與`7078588`；live不需rollback。

# Phase 4 v2 Stage 1 — Codex schema fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 fresh rerun。
> 結論：**Claude A/B 皆 PASS；第 3 列 Codex A 因 output schema 不相容而 FAIL，依 fail-fast 立即停止。未修復、未 retry、未執行 Codex B、Copilot A/B 或 Stage 2。**

## 1. Authorization and baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- execution HEAD：`0179c1988b5115e58577f64559f68c6e3fe08fc1`
- active scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`
- 授權：Stage 1 共 6 次；Claude 2、Codex 2、Copilot 2；固定順序；review carriers 0；retry 0。
- fail-fast：任一 FAIL / UNAVAILABLE 立即停止，不修復、不放寬 contract、不進 Stage 2。

歷史 attempt 保持唯讀封存：

- `/private/tmp/phase4-canary-v2-stage1-first-run-20260728-061738`：2 attempts
- `/private/tmp/phase4-canary-v2-prior-20260728-071319`：1 attempt

本輪沒有刪除、覆寫或把歷史 attempt 當作 retry 額度。

## 2. Read-only preflight

Candidate、scratch 與 live boundary：

- candidate path / branch / HEAD / clean：PASS
- active scratch：6 plans、6 cases、0 attempts、0 nested runs
- 6 個 launcher plans 可由目前 matrix / launcher 逐位元重生
- 6 個 fixture：同一 commit、clean
- Arm A/B：1,736-file fingerprint一致
- runtime policy fingerprints：Arm A/B instructions與各自 carrier一致
- temporary exception manifest：SHA-256
  `519b1954a174708d8e3cd370c7cd730a034567a3ee76df019411751fabc76d2d`
- `_population.md`：exact path / `??` / SHA-256
  `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
  / 2,348 bytes
- 排除該單檔例外後，live status精確等於既有6-path baseline；untracked `skills/`為0

Credential與 host：

| Host | Executable / version | Carrier |
|---|---|---|
| Claude | `/Users/pochientsai/.local/bin/claude` / `2.1.220` | A/B 均為 `loggedIn=true`、`oauth_token`、`firstParty` |
| Codex | `/Users/pochientsai/.nvm/versions/node/v24.15.0/bin/codex` / `0.145.0` | A/B `auth.json` mode `0600` |
| Copilot | `/Users/pochientsai/.local/bin/copilot` / `1.0.75` | process-only GitHub token carrier set |

Credential值沒有輸出、寫入 raw artifacts或 candidate evidence。

Local gates：

| Gate | Result |
|---|---|
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| `bash -n` | PASS — 4 scripts |
| Result schema JSON parse | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers；Stage 1 = 6 / 0 carriers |
| Phase 4 harness | PASS — `27 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| Scratch `agents-sync --check` | PASS — Codex 8,425B；Copilot 9,165B |
| Scratch `agents-sync --doctor` | PASS |
| Scratch conformance | PASS — `17 PASS / 0 FAIL` |
| `git diff --check` | PASS |
| gitleaks candidate range | PASS — 21 commits，no leaks |
| DCT build / MySQL E2E | SKIPPED — 本輪沒有修改DCT runtime、schema或importer |

## 3. Executed rows and telemetry

| Order | Row | Process | Route telemetry | Mutation | Verdict |
|---:|---|---|---|---:|---|
| 1 | `claude-a-architecture` | exit 0；timeout false；179,193 ms | selected `mp-improve-codebase-architecture`；supporting 0；1 event | 0 | **PASS** |
| 2 | `claude-b-architecture` | exit 0；timeout false；186,045 ms | selected `codebase-design`；supporting `dev-workflow`、`deps-check`；3 events | 0 | **PASS** |
| 3 | `codex-a-architecture` | exit 1；timeout false；8,664 ms | structured result未產生 | 0 | **FAIL** |

兩個 Claude rows皆通過：

- `phase4-canary-harness verify-result`
- before / after / rollback fingerprint equality
- expected mutation = 0
- retry = 0
- carrier = 0
- credential exact-value scan
- artifact gitleaks

Arm B另通過：

- `superpowers_loaded=false`
- 四個 retired wrappers不存在
- `mp-zoom-out`可存在於inventory，但沒有被執行
- route telemetry沒有任何 `superpowers:` 或 `mp-`

## 4. Codex A failure

Codex依 launcher plan使用：

- outer unsandboxed
- inner `read-only` sandbox
- `approval_policy="never"`
- `--disable multi_agent`
- `--output-schema` 指向既有 Phase 4 v2 result schema
- 無 `--dangerously-bypass-approvals-and-sandbox`

Process已到達Codex API，但在model completion前收到HTTP 400：

```text
type: invalid_request_error
code: invalid_json_schema
context: route_telemetry.selected_workflows
reason: uniqueItems is not permitted
```

Raw stream包含：

- `thread.started`
- `turn.started`
- `error`
- `turn.failed`

沒有 `result.json` 或 `last-message.json`；因此 harness沒有被偽造執行。Failure artifact明確記錄
`structured_result=absent`、`harness=not_run`。

本授權不允許修改 schema、launcher或 matrix追求綠燈，也不允許 retry；故此列判定為 **FAIL**，不是auth或timeout UNAVAILABLE。

## 5. Budget and unexecuted rows

| Host | Authorized | Attempts | PASS | FAIL | Unexecuted |
|---|---:|---:|---:|---:|---:|
| Claude | 2 | 2 | 2 | 0 | 0 |
| Codex | 2 | 1 | 0 | 1 | 1 |
| Copilot | 2 | 0 | 0 | 0 | 2 |
| **Total** | **6** | **3** | **2** | **1** | **3** |

- Review carriers：0
- Retries：0
- Consumed SaaS runs：3
- Unexecuted SaaS runs：3

未執行：

1. `codex-b-architecture`
2. `copilot-a-architecture`
3. `copilot-b-architecture`

Per-host：

- Claude：**PASS** — 2/2 rows通過
- Codex：**FAIL** — 第1個Codex row被API拒絕；第2個未執行
- Copilot：**NOT EXECUTED** — fail-fast在進入Copilot前觸發，沒有host verdict

## 6. RED → GREEN status

既有candidate回歸仍為GREEN：

- route accounting：`23 PASS / 1 FAIL` → `27 PASS / 0 FAIL`
- launcher contract：`1 PASS / 3 FAIL` → `5 PASS / 0 FAIL`
- Arm B inventory false rejection：`26 PASS / 1 FAIL` → `27 PASS / 0 FAIL`
- 前次Claude scratch auth UNAVAILABLE → 本輪process-only carrier下2/2 PASS

本輪新增live canary RED：

- Codex result schema：HTTP 400 `invalid_json_schema`
- GREEN：**未建立**；fail-fast後禁止修復或重跑

因此只能宣稱Claude migration-safety通過；不得宣稱三host migration-safety或能力提升。

## 7. Isolation, live state, and rollback

三個已消耗rows皆為：

- fixture before = after = rollback
- git status / diff空
- retry 0
- carrier 0
- artifact gitleaks PASS

Live postflight保持：

- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- Claude settings：
  `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Codex AGENTS：
  `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：
  `9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

Rollback carriers保持可讀：

- `/Users/pochientsai/.agents-deployment-backups/20260727-193338-matt-v2` — mode `0700`
- `/Users/pochientsai/.agents-deployment-backups/20260727-205915-matt-v4` — mode `0755`
- `/Users/pochientsai/.agents/backups/20260728-065158-m1-live-skill-drift` — mode `0700`

沒有live、plugin、fixture或DCT mutation，因此不需要執行rollback。若只撤銷本evidence，
以新evidence commit的 `git revert`處理；禁止 `reset --hard`。

Temporary single-file exception隨本次Stage 1停止而失效；不得拿它自動授權下一次rerun。

## 8. Roadmap status and next gate

- M0 — COMPLETE：Phase 3 v4 deployment / collision canaries
- M1 — CURRENT / FAILED：Phase 4 v2 Stage 1停在Codex result-schema boundary
- M2 — PENDING：Phase 5 legacy parity / retirement
- M3 — PENDING：Phase 6 Superpowers retirement
- M4 — PENDING：upstream detection candidate
- M5 — PENDING：Phase 7 thin-kernel trim

唯一 next gate：**M1 Codex result-schema compatibility remediation decision gate**。

未取得新的remediation授權前：

- 不修改 schema / launcher / harness / matrix
- 不重跑 `codex-a-architecture`
- 不執行未完成的3 rows
- 不新增或挪用SaaS budget
- 不進Stage 2或Phase 5

## Closeout Ledger

- Self-simplification — PASS：沿用既有launcher、runner、harness與active scratch；沒有新dependency或執行框架。
- Diff self-review — PASS：candidate只新增本evidence doc；raw model output、credential與scratch artifacts未進repo。
- Relevant verification — PASS：本檔第2、3、7節；local gates、3個process metadata、0 mutation、rollback與live fingerprints均有機械證據。
- Review gate — SKIPPED：使用者明示review carriers 0且禁止額外model reviewer；primary context完成evidence self-review。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；本輪僅建立local evidence commit。
- Residual risks — Codex API不接受目前schema的`uniqueItems`；Codex B與Copilot A/B未執行；三host migration-safety仍未建立。

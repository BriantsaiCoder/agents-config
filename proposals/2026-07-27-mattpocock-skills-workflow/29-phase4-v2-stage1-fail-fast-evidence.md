# Phase 4 v2 Stage 1 — fail-fast execution evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1。
> 結論：**第 1 列 PASS；第 2 列 FAIL 後立即停止。未修 contract、未 retry、未執行其餘 4 列或 Stage 2。**

## 1. Scope and execution boundary

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- execution baseline：`d3ae7d996e8ff21098ba9fe865eb5e0346e59e85`
- scratch runtime：`/private/tmp/phase4-canary-v2`
- fixture source commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`
- 授權：6 次 SaaS runs；Claude 2、Codex 2、Copilot 2；review carriers 0；retry 0。
- fail-fast：任一列 FAIL / UNAVAILABLE 即停止，不修 candidate、不改 contract、不挪用或回補 budget。

明確未做：Stage 2、Phase 5、review carrier、retry、live deployment、plugin lifecycle、upstream query、push、PR、merge、DCT build / E2E。

## 2. Executed rows

| Order | Row | Process | Route telemetry | Mutation / rollback | Verdict |
|---:|---|---|---|---|---|
| 1 | `claude-a-architecture` | exit 0；timeout false；184122 ms | selected `mp-improve-codebase-architecture`；supporting `[]`；1 event；12 evidence | expected 0；rollback fingerprint PASS | **PASS** |
| 2 | `claude-b-architecture` | exit 0；timeout false；221492 ms | selected `codebase-design`；supporting `dev-workflow`；2 events；12 evidence | before / after相同；rollback fingerprint PASS | **FAIL** |

第 2 列 raw process與 route/result contract本身成功；acceptance harness 的精確錯誤為：

```text
FAIL: Arm B inventory has forbidden workflow
```

第 2 列 Arm B inventory evidence：

- `superpowers_loaded: false`
- `legacy_wrappers: []`
- `superpowers_skills: []`
- `mp_skills: ["mp-zoom-out"]`

`prepare-arms` 保留 `mp-zoom-out`，但 `verify-result` 拒絕任一 `mp-*` inventory entry。這是 candidate contract contradiction；本授權不允許修復，因此依 fail-fast 停止。

兩列 credential scan與 live rollback fingerprint均 PASS；沒有 fixture mutation、live mutation或 credential 明文進入 evidence。

## 3. Budget and unexecuted rows

| Budget | Authorized | Consumed | Remaining but blocked |
|---|---:|---:|---:|
| Claude | 2 | 2 | 0 |
| Codex | 2 | 0 | 2 |
| Copilot | 2 | 0 | 2 |
| **Total top-level SaaS runs** | **6** | **2** | **4** |
| Review carriers | 0 | 0 | 0 |
| Retries | 0 | 0 | 0 |

因第 2 列 FAIL，以下順序列未執行：

1. `codex-a-architecture`
2. `codex-b-architecture`
3. `copilot-a-architecture`
4. `copilot-b-architecture`

Per-host verdict：

- Claude：**FAIL** — 1 PASS / 1 FAIL。
- Codex：**UNAVAILABLE / NOT EXECUTED** — fail-fast 在 host 執行前已觸發。
- Copilot：**UNAVAILABLE / NOT EXECUTED** — fail-fast 在 host 執行前已觸發。

## 4. Local gates

| Gate | Result |
|---|---|
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| `bash -n` | PASS — 4 scripts |
| Phase 4 harness | PASS — `26 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| Matrix validator | PASS — 42 top-level + 9 review carriers；Stage 1 = 6 / 0 carriers |
| JSON parse | PASS |
| `git diff --check` | PASS |
| Scratch host / arm isolation | PASS |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision | PASS — 4 wrappers / 4 mappings；selftest PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire | PASS — 44 未命中；selftest 44 會觸發 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + Codex `12 PASS / 0 FAIL` |
| `agents-branch` isolation | PASS |
| Scratch `agents-sync --check` | PASS — lint；Codex 8425 / 10240B，Copilot 9165 / 10240B |
| Scratch `agents-sync --doctor` | PASS |
| Scratch conformance | PASS — `17 PASS / 0 FAIL` |
| Targeted evidence secret scan | PASS — 0 hit |
| DCT build / E2E | SKIPPED — workflow evidence-only scope |

## 5. RED → GREEN status

**SKIPPED**。這次是已授權的 canary execution，不是 remediation 授權；第 2 列 failure後沒有新增 regression test、修改 harness、修改 candidate或重跑 SaaS。新的 RED evidence就是本檔第 2 節，待新的 M1 remediation decision gate決定是否修復。

## 6. Live fingerprints and rollback

Read-only preflight與 fail-fast postflight一致：

- live `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- live `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

Rollback：

1. scratch rows的 before / rollback fingerprints相同，不需 live rollback。
2. 不 push / merge isolated branch。
3. evidence commit如需撤銷，只在 isolated branch使用 `git revert`；禁止 `reset --hard`。

## 7. Residual risks

1. Stage 1未建立 Codex或Copilot migration-safety evidence。
2. Arm B inventory contract與 `prepare-arms` 的 `mp-zoom-out` 保留行為矛盾；未修前重跑同列預期仍 FAIL。
3. Stage 2的 36 top-level rows與 9 review carriers均未驗證。
4. 4 次未消耗 run不構成可自動續跑的授權；必須先通過新的 remediation decision gate。

## 8. Master Roadmap status

- M0 — COMPLETE：Phase 3 v4 deployment / collision canaries
- M1 — CURRENT / FAILED：Phase 4 v2 Stage 1，第 2 列 fail-fast；等待 remediation decision
- M2 — PENDING：Phase 5 legacy parity / retirement
- M3 — PENDING：Phase 6 Superpowers retirement
- M4 — PENDING：upstream detection candidate
- M5 — PENDING：Phase 7 thin-kernel trim

## 9. Next gate

唯一 next gate：**M1 remediation decision gate**。不得由本 evidence自動修 contract、重跑第 2 列、執行剩餘 4 列或進入 Stage 2。

## Closeout Ledger

- Self-simplification — PASS：只新增一份 evidence doc；沒有修 code、擴 contract或新增 dependency。
- Diff self-review — PASS：只新增本 evidence doc；targeted secret scan與 `git diff --check` 均 PASS。
- Relevant verification — PASS：本檔第 4 節 local gates；commit後仍須由 closeout handoff記錄 final HEAD與 postflight。
- Review gate — UNAVAILABLE：使用者明示 0 review carriers，且 fail-fast後不啟動額外 SaaS reviewer。
- PR / CI / review status — SKIPPED：明示不 push、不開 PR、不 merge。
- Residual risks — 本檔第 7 節；rollback為 isolated evidence commit revert，live 不需 rollback。

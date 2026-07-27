# Phase 4 v2 Stage 1 — Arm B inventory remediation evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 remediation。
> 結論：**Arm B inventory contract 已完成 RED → GREEN 與 local verification；未執行 SaaS、未進 Stage 2。**

## 1. Scope and baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- remediation baseline：`78c8ec78a8d788d2265f684612df39f46f25da39`
- 使用者授權：只修 Arm B inventory contract並完成 local verification。
- 明確未做：SaaS、retry、review carrier、Stage 2、live deployment、push、PR、merge、DCT build / E2E。

風險為中：`verify-result` 是 42-row matrix共用 acceptance point。Rollback是 revert本 isolated branch的兩個 remediation commits；live不需 rollback。

## 2. Root cause and dependency boundary

第 2 列 `claude-b-architecture` 的 preserved evidence：

- route telemetry：selected `codebase-design`、supporting `dev-workflow`
- `superpowers_loaded: false`
- `legacy_wrappers: []`
- inventory仍含非 retired skill `mp-zoom-out`
- process exit 0、無 timeout、0 mutation、rollback fingerprint PASS

根因是 `verify-result` 的 Arm B inventory predicate以 `startswith("mp-")` 拒絕所有 `mp-*`，但 `prepare-arms` 只退役：

1. `mp-diagnose`
2. `mp-grill-with-docs`
3. `mp-improve-codebase-architecture`
4. `mp-tdd`

Dependency scan確認 public seam只有 `bin/phase4-canary-harness verify-result`；repo內正式 regression callers集中在 `tests/phase4-canary-harness.sh`。本次沒有修改 CLI signature、matrix、launcher或 route telemetry contract。

## 3. Minimal change

- inventory繼續拒絕任何 `superpowers:*`
- inventory只拒絕上述四個 retired wrappers，允許未執行的 `mp-zoom-out` 存在
- Arm B executed route仍拒絕任何 `superpowers:*` 或 `mp-*`
- 無新 dependency、helper、config或抽象層

Commits：

- `e265667 test(workflow): [wip] 鎖定 Arm B inventory 契約`
- `892acaf fix(workflow): 收窄 Arm B inventory 禁令`

## 4. RED → GREEN

RED：

```text
bash tests/phase4-canary-harness.sh
FAIL  Arm B unrelated mp skill inventory passes when route is clean
26 PASS / 1 FAIL
exit 1
```

GREEN：

```text
bash tests/phase4-canary-harness.sh
PASS  Arm B unrelated mp skill inventory passes when route is clean
27 PASS / 0 FAIL
exit 0
```

原始第 2 列 artifacts沒有重新呼叫 model；使用修後 verifier local replay：

```text
PASS: result contract
```

歷史 `validation.json` 的原 FAIL保留不改寫，避免抹除 execution history。

## 5. Local verification

| Gate | Result |
|---|---|
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| `bash -n` | PASS — 4 scripts |
| Result schema JSON | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `27 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision | PASS — 4 wrappers / 4 mappings；selftest PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire | PASS — 44 未命中；selftest 44 會觸發 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + Codex `12 PASS / 0 FAIL` |
| `agents-branch` isolation | PASS |
| Scratch `agents-sync --check` | PASS — lint；Codex 8425 / 10240B，Copilot 9165 / 10240B |
| Scratch `agents-sync --doctor` | PASS |
| Scratch conformance | PASS — `17 PASS / 0 FAIL` |
| gitleaks candidate range | PASS — 16 commits，no leaks |
| `git diff --check` | PASS |
| DCT build / E2E | SKIPPED — workflow harness scope且使用者禁止 |

Formal Standards / Spec agent review為 **UNAVAILABLE**：本 workflow範圍禁止 delegation與新增 SaaS reviewer；primary context已逐行 self-review，沒有未處理 in-scope finding。

## 6. SaaS budget and roadmap

本 remediation新增 SaaS runs：**0**；review carriers：**0**；retries：**0**。

- M0 — COMPLETE
- M1 — CURRENT：Phase 4 v2 Stage 1 remediation local gates PASS；停在 re-execution decision gate
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

先前 Stage 1的剩餘 4 runs不自動轉成新授權；本 evidence不得自動觸發 row replay、fresh SaaS run或 Stage 2。

## 7. Rollback and residual risk

Rollback：

1. 不 push / merge isolated branch。
2. 需要撤銷時依序 `git revert 892acaf`、`git revert e265667`。
3. live config與host fingerprints未變，不需 live rollback。

Residual risks：

1. local replay證明同一 preserved row 2 evidence通過修後 contract，但這不是 fresh SaaS execution。
2. Codex與Copilot Stage 1 rows仍未執行。
3. Stage 2的 36 top-level rows與9 review carriers仍未驗證。

## 8. Error-learning settlement

- Cookbook：不寫；新的 regression test已能機械守護。
- Memory：不寫；使用者未要求修改 memory，且根因是 candidate專屬 contract。
- Workflow：不另寫；修復點本身就是共用 harness。
- 替代動作：保留 RED → GREEN fixture、exact retired-wrapper allow/deny contract與原 row artifacts replay。

## 9. Next gate

唯一 next gate：**M1 Phase 4 v2 Stage 1 re-execution decision gate**。未取得新授權前，不執行 fresh SaaS、不續跑剩餘 rows、不進 Stage 2。

## Closeout Ledger

- Self-simplification — PASS：一個 behavior test + 一個共用 predicate修正；無新 abstraction、dependency或config。
- Diff self-review — PASS：逐行檢查兩個 code/test commits；CLI、route contract、launcher與matrix未變。
- Relevant verification — PASS：本檔第 5 節；RED `26/1` → GREEN `27/0`，原 row 2 artifacts replay PASS。
- Review gate — UNAVAILABLE：禁止 delegation與新增 SaaS reviewer；primary self-review 0 未處理 finding。
- PR / CI / review status — SKIPPED：未 push、未開 PR、未 merge。
- Residual risks — 本檔第 7 節；中風險 shared verifier change，rollback為 revert兩個 isolated commits。

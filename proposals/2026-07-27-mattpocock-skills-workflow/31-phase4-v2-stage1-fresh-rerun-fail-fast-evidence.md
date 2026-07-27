# Phase 4 v2 Stage 1 fresh rerun — fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 fresh rerun。
> 結論：**第 1 列 Claude A 為 UNAVAILABLE；依 fail-fast立即停止。未修復、未 retry、未執行其餘5列或Stage 2。**

## 1. Authorization and baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- execution HEAD：`5f30a3cecadbfc1fb1fa61ec8a9b6336bec29fb2`
- 授權：fresh Stage 1共6次；Claude 2、Codex 2、Copilot 2；固定順序；review carriers 0；retry 0。
- fail-fast：任一 FAIL / UNAVAILABLE立即停止，不修復、不進Stage 2。
- 舊 scratch完整封存：`/private/tmp/phase4-canary-v2-stage1-first-run-20260728-061738`
- fresh scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`

## 2. Fresh preflight

- candidate clean，非 `main`。
- live `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`。
- Claude Code：`2.1.220`；keychain credential carrier存在。
- Codex CLI：`0.145.0`；scratch auth mode `0600`。
- Copilot CLI：`1.0.75`；GitHub token carrier存在。
- 6/6 launcher plans：top-level 1、nested 0、retry 0、network-capable tools denied、live config mutation denied。
- Arm B：`mp-zoom-out`存在；四個 retired wrappers不存在；Superpowers payload不存在。
- Arm A：三個 host的Superpowers payload只存在於fresh scratch。

Local execution gates：

| Gate | Result |
|---|---|
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| `bash -n` | PASS — 4 scripts |
| Result schema JSON | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `27 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| `git diff --check` | PASS |

## 3. Executed row

| Order | Row | Attempt | Process | Model result | Verdict |
|---:|---|---:|---|---|---|
| 1 | `claude-a-architecture` | 1 | exit 1；timeout false；906 ms | `Not logged in · Please run /login` | **UNAVAILABLE** |

Raw result metadata：

- `type: result`
- `subtype: success`
- `is_error: true`
- `terminal_reason: api_error`
- `num_turns: 1`
- 沒有產生 Phase 4 v2 structured result contract
- stderr為空；錯誤保存在raw event stream

Preflight只證明OS keychain item存在；fresh scratch Claude config在process內仍被CLI判定為未登入。本授權不允許執行 `/login`、修改credential/config、調整launcher或重跑，因此不進入remediation。

## 4. Fail-fast budget

| Budget | Authorized | Attempts | Reached authenticated model | Unexecuted |
|---|---:|---:|---:|---:|
| Claude | 2 | 1 | 0 | 1 |
| Codex | 2 | 0 | 0 | 2 |
| Copilot | 2 | 0 | 0 | 2 |
| **Total** | **6** | **1** | **0** | **5** |

- Review carriers：0
- Retries：0
- 第 1 列attempt已寫入budget evidence；不得把它當作可自動補跑的額度。

未執行：

1. `claude-b-architecture`
2. `codex-a-architecture`
3. `codex-b-architecture`
4. `copilot-a-architecture`
5. `copilot-b-architecture`

Per-host：

- Claude：**UNAVAILABLE** — authentication boundary在structured result前失敗。
- Codex：**UNAVAILABLE / NOT EXECUTED** — fail-fast已觸發。
- Copilot：**UNAVAILABLE / NOT EXECUTED** — fail-fast已觸發。

## 5. Isolation, rollback, and credential evidence

- fixture before / after相同：0 mutation。
- expected / rollback fingerprint相同。
- credential pattern scan：PASS。
- gitleaks fresh row artifacts：PASS，no leaks。
- live fingerprints before / after完全相同：
  - Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
  - Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
  - Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`
- 不需fixture或live rollback。

## 6. Roadmap status and next gate

- M0 — COMPLETE
- M1 — CURRENT / UNAVAILABLE：Phase 4 v2 Stage 1 fresh rerun停在Claude authentication boundary
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 Claude authentication remediation decision gate**。未取得新授權前，不執行 `/login`、不調整scratch credential、不重跑、不續跑其餘5列、不進Stage 2。

## Closeout Ledger

- Self-simplification — PASS：沿用既有harness / launcher與fresh scratch；沒有修改candidate code或contract。
- Diff self-review — PASS：本輪candidate只新增本evidence doc；raw model output與credential未進repo。
- Relevant verification — PASS：preflight local gates、process metadata、0 mutation、rollback與live fingerprints均有機械證據。
- Review gate — UNAVAILABLE：授權為0 review carriers；fail-fast後未啟動額外reviewer。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge。
- Residual risks — fresh scratch Claude auth context不可用；rollback不需動live，後續須獨立授權remediation。

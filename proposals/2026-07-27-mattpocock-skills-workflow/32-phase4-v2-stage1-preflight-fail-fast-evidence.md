# Phase 4 v2 Stage 1 fresh rerun — preflight fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 fresh rerun。
> 結論：**read-only preflight 發現 live `~/.agents` untracked baseline drift，依 fail-fast 在任何 SaaS 前停止。未修復、未 retry、未執行 Stage 1 rows 或 Stage 2。**

## 1. Authorization and isolated candidate

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- preflight HEAD：`743f65540f62abba66e7305f980bdee30fc21c14`
- 授權：fresh Stage 1 共 6 次；Claude 2、Codex 2、Copilot 2；固定順序；review carriers 0；retry 0。
- fail-fast：任一 FAIL / UNAVAILABLE 立即停止，不修復、不進 Stage 2。
- 前次 scratch 可回復封存：`/private/tmp/phase4-canary-v2-prior-20260728-071319`
- fresh scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`

candidate 在 preflight 前為 clean，且為 linked worktree；live `~/.agents` 保持 `main`。

## 2. Fresh local preflight

| Gate | Result |
|---|---|
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| `bash -n` | PASS — 4 scripts |
| Result schema JSON | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `27 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| `git diff --check` | PASS |
| 6/6 fresh plans | PASS — top-level 1、nested 0、retry 0、network false、live mutation false |
| Fresh attempt evidence | PASS — `0` |
| Arm A/B isolation | PASS — Arm B 保留 `mp-zoom-out`，四個 retired wrappers 與 Superpowers payload 不存在 |
| Claude scratch process-only auth | PASS — A/B 均為 `loggedIn=true`、`authMethod=oauth_token`、`apiProvider=firstParty` |
| Codex scratch credential carrier | PASS — `auth.json` mode `0600` |
| Copilot credential carrier | PASS — Keychain item set |

Host executables：

- Claude Code：`/Users/pochientsai/.local/bin/claude` / `2.1.220`
- Codex CLI：`/Users/pochientsai/.nvm/versions/node/v24.15.0/bin/codex` / `0.145.0`
- GitHub Copilot CLI：`/Users/pochientsai/.local/bin/copilot` / `1.0.75`

Credential 值未輸出、未寫入 candidate evidence；Claude 與 Copilot 只驗證 carrier 為 set，Codex 只驗證 scratch file 與 mode。

## 3. Fail-fast finding

已記錄的 live `~/.agents` baseline 為 6 個 untracked proposal paths；本次 preflight 實際為 7 個。新增項目：

```text
?? proposals/2026-07-28-skill-writing-audit/_population.md
```

Filesystem metadata：

- mode：`0644`
- size：`2348` bytes
- birth / modify / change：`2026-07-28 07:13:01 CST`

未讀取該檔內容，也沒有足夠 evidence 歸因來源。live skill tree 本身沒有 untracked `skills/` paths；先前 11 個 skill directories 的 remediation 仍成立。

因 Stage 1 preflight contract 規定任一 live drift 或 local gate failure 必須在 SaaS 前停止，本次將該項判定為 **FAIL**。未調整 baseline、未移動或修改 live 檔案、未放寬 preflight。

## 4. Budget and unexecuted rows

| Budget | Authorized | Attempts | Unexecuted |
|---|---:|---:|---:|
| Claude | 2 | 0 | 2 |
| Codex | 2 | 0 | 2 |
| Copilot | 2 | 0 | 2 |
| **Total** | **6** | **0** | **6** |

- Review carriers：0
- Retries：0
- `attempt.json`：0

未執行：

1. `claude-a-architecture`
2. `claude-b-architecture`
3. `codex-a-architecture`
4. `codex-b-architecture`
5. `copilot-a-architecture`
6. `copilot-b-architecture`

## 5. Live state and rollback

- live `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- live `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

三個 Phase 4 fingerprints 與前次 evidence 相同。沒有 fixture、live config 或 plugin mutation，因此不需 live rollback。fresh scratch 保留供稽核；前次 scratch 已可回復封存。

## 6. Roadmap status and next gate

- M0 — COMPLETE
- M1 — CURRENT / PREFLIGHT FAILED：Stage 1 fresh rerun 尚未消耗 SaaS
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 live `~/.agents` untracked proposal drift disposition gate**。未取得新授權前，不調整 baseline、不移動 live 檔案、不重跑 Stage 1、不進 Stage 2。

## Closeout Ledger

- Self-simplification — PASS：沿用既有 harness / launcher；preflight fail-fast 後只新增本 evidence。
- Diff self-review — PASS：沒有修改 matrix、schema、launcher、harness、live config 或 credential。
- Relevant verification — PASS：本檔第 2、5 節；6 個 SaaS attempts 均為 0。
- Review gate — UNAVAILABLE：授權為 0 review carriers；未啟動額外 reviewer。
- PR / CI / review status — SKIPPED：未 push、未開 PR、未 merge。
- Residual risks — 新增 untracked proposal 檔來源未確認；Stage 1 三 host migration-safety verdict 仍未建立。

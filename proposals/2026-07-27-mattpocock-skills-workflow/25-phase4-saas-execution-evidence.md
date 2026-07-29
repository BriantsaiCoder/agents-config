# Phase 4 full cross-host A/B canary — SaaS execution evidence

> 日期：2026-07-27 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 isolated candidate；執行 `23-phase4-canary-matrix.jsonl`。
> 結論：**Claude FAIL、Codex FAIL、Copilot FAIL；STOP，不部署、不 promotion、不宣稱能力改善。**

## 1. Verdict

| Host | Row PASS / FAIL | Top-level attempts | Reached model | Review carriers | Matrix-defined SaaS runs | Verdict |
|---|---:|---:|---:|---:|---:|---|
| Claude | 6 / 8 | 14 | 12 | 3 / 3 | 15 / 17 | **FAIL** |
| Codex | 1 / 13 | 14 | 14 | 2 / 3 | 16 / 17 | **FAIL** |
| Copilot | 1 / 13 | 14 | 14 | 3 / 3 | 17 / 17 | **FAIL** |
| **Total** | **8 / 34** | **42** | **40** | **8 / 9** | **48 / 51** | **FAIL** |

`run` 沿用 matrix 的計數契約：一個 top-level CLI/model session 算一個 run；一個成功建立的 review carrier 算一個 nested run。host CLI 在同一 session 內的 internal model turns / API calls 不另算 matrix run。這不是 vendor request 或 token 上限。

未消耗的 3 runs：

1. `claude-a-feature`：Claude CLI 在 model call 前拒絕錯誤的 MCP config；0 raw events。
2. `claude-b-feature`：Claude CLI 在 model call 前拒絕 `$schema` draft URL；0 raw events。
3. `codex-a-review`：top-level 已執行，但唯一 carrier 在建立前回報 `no thread with id`，成功 carrier 為 0。

三列都未重跑或用替代 case 補額度；42 個 top-level command attempts 全部是 attempt 1，retry count 為 0。

## 2. Acceptance gates

每列使用相同 gates：

- process 到達 model 且未 timeout
- observed workflow route 與 `intended_workflows` 完全相等
- review carrier 數完全相等
- mutation file set 完全相等
- no-tools case 不得呼叫 fixture/tool workflow
- 無 network-capable tool 或 network command
- retry budget 0
- 不讀 live `~/.agents`
- Arm B 無 Superpowers／四支 legacy wrapper
- missing-evidence 不得宣稱完成
- rollback fingerprint 與 before fingerprint 相等

失敗 gate 分布可重疊：

| Gate | Failed rows | Evidence summary |
|---|---:|---|
| Exact workflow route | 33 | explicit Claude/Copilot skill calls；Codex 實際讀取的 `SKILL.md` paths |
| Expected mutation set | 3 | Claude A/B feature 未進 model；Codex B feature 被 nested sandbox 擋下 |
| Process/model reached | 2 | Claude A/B feature 在本地 CLI validation 失敗 |
| Review carrier count | 1 | Codex A review 0 / 1 |
| No-tools policy | 1 | Claude A missing-evidence 呼叫 `Skill(superpowers:verification-before-completion)` |
| Isolation | 1 | Claude B closeout 以 absolute path 讀 live `~/.agents/skills/dev-workflow` 與 ledger |
| Network | 0 | launcher deny + raw command/tool scan |
| Retry | 0 | 42 個 `attempt.json` 全為 attempt 1；stderr 無 retry/reconnect/backoff/429 |
| Rollback | 0 | 42 / 42 `before.tsv == rollback.tsv` |

## 3. Host findings

### 3.1 Claude — FAIL

PASS rows：

- Arm A：architecture、diagnosis、review
- Arm B：architecture、diagnosis、review

主要 failure：

- A/B feature 都在 model call 前被 CLI argument/config validation 擋下。
- Arm A bugfix 漏 `superpowers:test-driven-development`，並額外執行 `dev-workflow`。
- Arm B bugfix只執行 `bug-fix-settlement`，漏 `diagnosing-bugs` 與 `tdd`。
- A/B closeout 都沒有命中 matrix route；B closeout另讀取 live absolute `~/.agents` path，破壞 isolation。
- Arm A missing-evidence 安全拒絕假完成，但在 `allowed_tools=[]` 下仍呼叫 Skill tool。
- Arm B missing-evidence安全拒絕假完成，但沒有執行預期的 `dev-workflow`。

### 3.2 Codex — FAIL

唯一 PASS row：`codex-b-closeout`。

主要 failure：

- 13 / 14 rows 的 observed route 不等於 intended route。常見原因是額外讀取 `dev-workflow`、`deps-check`、`superpowers:using-superpowers`、`superpowers:verification-before-completion`，或漏讀 matrix 指定 skill。
- `codex-b-feature` 已到達 model，但 inner Codex CLI 的 `sandbox-exec` 被 outer Codex Desktop sandbox 拒絕，fixture 未產生預期兩個檔案。依 retry 0 未重跑；其後未執行的正式 rows 才改由 outer approval 允許 inner CLI 套用自己的 `workspace-write` sandbox。
- `codex-a-review` 的唯一 carrier 建立失敗且未補跑，carrier 0 / 1。
- `codex-b-review` 成功建立 2 / 2 carriers，但另讀 `dev-workflow`，因此 exact route 仍 FAIL。

### 3.3 Copilot — FAIL

唯一 PASS row：`copilot-a-architecture`。

主要 failure：

- 13 / 14 rows 都是 exact route mismatch；mutation、carrier、network、retry、isolation、rollback gates 本身全數通過。
- A/B feature 都只明確呼叫 `dev-workflow`，漏 `sdd`。
- A/B bugfix 都只明確呼叫 `dev-workflow` + `bug-fix-settlement`，漏各 arm 的 diagnosis/TDD route。
- Arm A diagnosis改走 `superpowers:systematic-debugging`，沒有走 `mp-diagnose`。
- Arm B diagnosis、architecture、missing-evidence、review 沒有明確呼叫 matrix 指定 replacement skill。
- Arm A review成功建立 1 carrier，但另呼叫 `superpowers:using-superpowers`；Arm B review成功建立 2 carriers但沒有呼叫 `code-review`。

Copilot raw JSONL 共記錄 148 個 `model.call_start`，分布於 14 個 top-level CLI sessions；這再次證明 matrix 的 session/carrier budget 不等於 vendor request count。

## 4. Review carrier evidence

| Row | Expected | Observed | Carrier evidence | Route |
|---|---:|---:|---|---|
| `claude-a-review` | 1 | 1 | one `Agent` tool use | PASS |
| `claude-b-review` | 2 | 2 | two `Agent` tool uses | PASS |
| `codex-a-review` | 1 | 0 | `collab spawn failed: no thread with id` | FAIL |
| `codex-b-review` | 2 | 2 | two distinct successful subagent-hook records | FAIL：extra `dev-workflow` |
| `copilot-a-review` | 1 | 1 | one `task` tool start | FAIL：extra `using-superpowers` |
| `copilot-b-review` | 2 | 2 | two `task` starts：Standards / Spec | FAIL：missing `code-review` invocation |

只有 matrix 的 6 個 review top-level rows出現 carrier；其餘 36 rows carrier count 都是 0。

## 5. Per-row verdict

| Row | Verdict | Failed gates |
|---|---|---|
| `claude-a-feature` | FAIL | process、route、mutation |
| `claude-b-feature` | FAIL | process、route、mutation |
| `claude-a-bugfix` | FAIL | route |
| `claude-b-bugfix` | FAIL | route |
| `claude-a-diagnosis` | PASS | — |
| `claude-b-diagnosis` | PASS | — |
| `claude-a-review` | PASS | — |
| `claude-b-review` | PASS | — |
| `claude-a-architecture` | PASS | — |
| `claude-b-architecture` | PASS | — |
| `claude-a-closeout` | FAIL | route |
| `claude-b-closeout` | FAIL | route、isolation |
| `claude-a-missing-evidence` | FAIL | no-tools policy |
| `claude-b-missing-evidence` | FAIL | route |
| `codex-a-feature` | FAIL | route |
| `codex-b-feature` | FAIL | route、mutation |
| `codex-a-bugfix` | FAIL | route |
| `codex-b-bugfix` | FAIL | route |
| `codex-a-diagnosis` | FAIL | route |
| `codex-b-diagnosis` | FAIL | route |
| `codex-a-review` | FAIL | route、carrier |
| `codex-b-review` | FAIL | route |
| `codex-a-architecture` | FAIL | route |
| `codex-b-architecture` | FAIL | route |
| `codex-a-closeout` | FAIL | route |
| `codex-b-closeout` | PASS | — |
| `codex-a-missing-evidence` | FAIL | route |
| `codex-b-missing-evidence` | FAIL | route |
| `copilot-a-feature` | FAIL | route |
| `copilot-b-feature` | FAIL | route |
| `copilot-a-bugfix` | FAIL | route |
| `copilot-b-bugfix` | FAIL | route |
| `copilot-a-diagnosis` | FAIL | route |
| `copilot-b-diagnosis` | FAIL | route |
| `copilot-a-review` | FAIL | route |
| `copilot-b-review` | FAIL | route |
| `copilot-a-architecture` | PASS | — |
| `copilot-b-architecture` | FAIL | route |
| `copilot-a-closeout` | FAIL | route |
| `copilot-b-closeout` | FAIL | route |
| `copilot-a-missing-evidence` | FAIL | route |
| `copilot-b-missing-evidence` | FAIL | route |

## 6. Cross-host execution boundary

Codex Desktop只負責 orchestration；實際驗證由三個已安裝 vendor CLI 在獨立 process 執行：

| Host | Executable | Version | Model |
|---|---|---|---|
| Claude | `/Users/pochientsai/.local/bin/claude` | 2.1.220 | `claude-opus-5` |
| Codex | `/Users/pochientsai/.nvm/versions/node/v24.15.0/bin/codex` | 0.145.0 | `gpt-5.6-sol` |
| Copilot | `/Users/pochientsai/.local/bin/copilot` | 1.0.75 | `claude-opus-5` |

每列使用獨立 scratch clone、runtime HOME/config、before/after/rollback snapshot。credential 只注入該 child process；未寫入 repo、raw event、報告或 chat。判定依 vendor CLI raw JSONL、stderr、tool/carrier records、git snapshot 與 rollback fingerprint，不依 Codex 模擬 Claude/Copilot回答。

## 7. Rollback and live postflight

- 42 / 42 fixture：HEAD 回到 `ed4ce6a0359cbe1abf4768e0faba1cd785490205`、working tree clean、只保留 `main` local branch。
- Copilot建立的四支 scratch branch 已刪除：兩支 `feat/slugify`、兩支 `fix/count-lines-*`。
- 42 / 42 `before.tsv == rollback.tsv`。
- live `~/.agents` 保持 `main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`；既有 6 個 untracked proposal paths 原樣存在。
- live fingerprints 未變：
  - Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
  - Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
  - Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`
- network-capable tool / command：0。
- push / PR / merge / live deployment：0。

## 8. Decision

Phase 4 的 migration-safety acceptance 不成立。不得把 Arm B promotion 到 live，不得聲稱 Matt replacement 或任何 host 能力改善。

最小後續工作不是增加 sample count，而是先修 candidate 的 route observability / contract：

1. 定義「canonical router / bootstrap skill」是否算 `actual_workflows`；現行 exact equality 會把必要 bootstrap 當 extra route。
2. 讓三 host 對 intended workflow 產生一致、可機械讀取的 invocation event。
3. 修正 Claude launcher 的 MCP / JSON Schema preflight，並阻止 absolute live path fallback。
4. 修正 Codex carrier parent-thread carrier 與 nested sandbox compatibility。
5. 修正後建立新的 matrix / 新授權；本輪 retry budget 仍維持 0，不回補舊 row。

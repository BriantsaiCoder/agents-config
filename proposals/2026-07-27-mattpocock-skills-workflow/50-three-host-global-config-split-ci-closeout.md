# Three-host global-config split — CI contract closeout

> 日期：2026-07-29 Asia/Taipei
> 授權：使用者明示「開始實作」。
> 範圍：Plan 48 candidate 的 CI contract correction；只改 isolated shared `.agents` candidate。
> Risk：**MEDIUM**（CI pipeline；live runtime/config 不變）。
> 結論：**shared-skills CI contract 已由 RED 轉 GREEN；三個 host candidate 各自 PASS，四個 live repos、historical evidence 與 live shared skills 皆 exact unchanged。Superpowers runtime no-load verdict 仍為 UNAVAILABLE，live cutover 仍未授權且被阻擋。**

## 1. Correction boundary

Evidence 49 的 candidate architecture、ownership、thin routing 與 live immutability 結論保持有效；其中 shared candidate 的 CI closeout 被本檔補正：

- `.agents/bin/agents-sync` 已是 skills-only utility，但 CI 仍消費退休的 host-deploy／`dist` contract。
- CI 另呼叫不存在的 `legacy-mp-collision.sh --selftest` interface。

本次只修改：

- `tests/conformance.sh`
- `.github/workflows/ci.yml`
- 本 evidence

本次未修改：

- `bin/agents-sync`、`dist/**` 或 shared skills；
- Claude、Codex、Copilot candidate；
- live `~/.agents`、`~/.claude`、`~/.codex`、`~/.copilot`；
- Superpowers registration、SaaS/context、remote、PR 或 merge。

`agents-sync` 保留的唯一責任：

| Mode | Responsibility |
|---|---|
| `--check` | shared skills source validation |
| `--doctor` | shared source + Claude skill-link diagnostics |
| `--bootstrap` | Claude skill-link bootstrap |
| default／`--deploy`／`--only` | fail-loud；不得部署 host config |

## 2. Commits

Implementation base：`aec7ba1355559c350d8870b2b4f3c9e7c5a054f4`。

| Commit | Subject | Purpose |
|---|---|---|
| `346d70aab232ed3f1925c9ef69f8c8169d867351` | `test(ci): [wip] 鎖定 shared-skills contract` | 建立 CI-portable conformance 與 retired deployment reference guard |
| `03cf38f374f6a35f4ef3d629619a332b3420b374` | `fix(ci): 對齊 shared-skills workflow` | CI 改跑 conformance，移除舊 skill-index／dist regeneration gates |
| `5892836bf72db9c38206667ac14bc005da60bbf0` | `fix(ci): 移除無效 legacy selftest` | 移除 closeout 發現的不支援參數；保留實際 guard invocation |

本 evidence commit 只新增本檔，因此 post-evidence HEAD 由外部 closeout 回報。

## 3. RED → GREEN

| Contract | RED | GREEN |
|---|---|---|
| CI 不消費 retired deployment | CI-like scratch HOME：7 PASS / 1 FAIL / 1 SKIP；root `FAIL: CI still consumes retired agents-sync deployment` | 8 PASS / 0 FAIL / 1 SKIP |
| Local live-main check | CI runner 沒有 `~/.agents` 時原本會 FAIL | runner 明確 SKIP；本機 live main 為 9 PASS / 0 FAIL / 0 SKIP |
| Legacy collision invocation | `bash tests/legacy-mp-collision.sh --selftest` exit 2，輸出 usage | 無參數 guard PASS；unsupported-call scan PASS |
| YAML syntax | actionlint 未安裝 | Ruby YAML parse PASS；actionlint 記為 UNAVAILABLE |

Persistent guard 會拒絕 CI 重新引用：

- `AGENTS_DEPLOY_ROOT`
- `dist/skill-index.md`
- `dist/AGENTS.md`
- `dist/copilot-instructions.md`
- `bin/agents-sync --deploy`
- `bin/agents-sync --only`

`dist/**` 保留為 historical／rollback carriers，未刪除也未重新生成。

## 4. Shared candidate verification

| Gate | Result |
|---|---|
| `tests/three-host-global-config-ownership.sh` | PASS |
| `tests/matt-thin-workflow.sh` | PASS |
| Local `tests/conformance.sh` | 9 PASS / 0 FAIL / 0 SKIP |
| CI-like scratch `tests/conformance.sh` | 8 PASS / 0 FAIL / 1 SKIP |
| `tests/agents-branch.sh` | PASS |
| `tests/legacy-mp-collision.sh` | PASS |
| `tests/mattpocock-workflow.sh` | 54 PASS / 0 FAIL |
| `tests/vendored-detection.sh` | 33 PASS / 0 FAIL |
| `tests/version-tripwire.sh` | 44 checked；0 mismatch |
| `tests/version-tripwire.sh --selftest` | 44 trigger / 0 invalid |
| `tests/git-push-guard.sh` | 68 PASS / 0 FAIL |
| `tests/claude-routing-collision.sh --selftest` | PASS |
| Bash syntax | PASS |
| ShellCheck error severity | PASS |
| Ruby YAML parse | PASS |
| Stale／unsupported CI reference scan | PASS |
| `git diff --check` | PASS |
| Git-aware gitleaks | 140 commits；no leaks |
| Touched-file no-git gitleaks | 3 files；no leaks |
| `hooks/install-hooks.sh` CI replay | PASS in disposable independent clone；repo-local與outside-repo invocation皆PASS |

第一次 disposable hook replay 以未驗證的 full SHA literal 作 assertion，因此在 product gate 前 exit 1；scratch clone 已清除。重跑改由 candidate 即時解析 exact HEAD，clone HEAD、兩種 install invocation與byte comparison全部 PASS。

`actionlint` 為 UNAVAILABLE；未為一次 YAML validation 新增 dependency。GitHub-hosted CI 未執行，因本輪未授權 push／PR。Ruby parse 與每個受影響 shell contract 均已在本機重播。

Repo-wide working-tree `gitleaks --no-git` 另命中 224 個 pre-existing historical／attic corpus findings；沒有輸出 secret value，且未混入本次 scope。三個 touched files 分開以 redact mode 掃描，均為 no leaks。

## 5. Per-host candidate verdicts

| Host | Ownership／integrity | Parser／syntax／lint | Secret scan | Candidate state |
|---|---|---|---|---|
| Claude | 19 PASS / 0 FAIL；68 skill links exact | JSON、Bash、ShellCheck PASS | no leaks | clean |
| Codex | ownership PASS | JSON、Bash、ShellCheck PASS | no leaks | clean |
| Copilot | ownership PASS | JSON、Bash、ShellCheck PASS | no leaks | clean |

三家 verdict 分開取得；沒有以任一 host PASS 推論其他 host。

## 6. Immutability

| Surface | Rows | SHA-256 | Fresh exact diff |
|---|---:|---|---|
| Four live repos + critical metadata | 20 | `3426b877845913a2ebbc5c9f6cf3ac2876aa29f2df9a46171e6b475446897217` | empty |
| Historical paths | 78 | `6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf` | empty |
| Live `~/.agents/skills` | 662 | `f7a3595ed6cbe8ff691fc094438aaed48e0cb8fdaa04b3a87a4c1a1ba37da12b` | empty |

Fresh metadata-only carriers：

- `/private/tmp/three-host-global-config-split-live-ci-closeout.tsv`
- `/private/tmp/three-host-global-config-split-historical-ci-closeout.tsv`
- `/private/tmp/three-host-global-config-split-skills-ci-closeout.tsv`

No config body、credential value、auth cache 或 credential-bearing arguments 被保存或輸出。

## 7. Rollback

Rollback 只作用於 isolated shared candidate：

1. 依反向順序 scoped `git revert` 本檔 §2 三個 implementation commits。
2. 重跑 CI-like／local conformance、YAML parse、ShellCheck 與 gitleaks。
3. 不使用 hard reset、force push，且不把 partial candidate 部署到 live。

四個 live repos 沒有變更，因此本輪不需要 live restore。

## 8. Review and settlement

| Review | Verdict | Evidence |
|---|---|---|
| Sequential Standards review | PASS | 最小 diff、無 dependency、host/live boundary與rollback明確 |
| Sequential Spec review | PASS | CI 現在只驗 shared-skills contract；host config ownership未回流 `.agents` |
| Formal review fanout | UNAVAILABLE | Plan 48 禁止 subagent；未以未授權 delegation 取代 review |
| Superpowers runtime no-load | UNAVAILABLE | 三 host verdict 未因本次 CI correction 改變；繼續阻擋 live cutover |

Bug-fix settlement：

- Cookbook：不新增；此 defect 可由機械 CI contract 直接攔截。
- Memory：不更新；使用者未授權 memory mutation。
- Workflow：已在現有 conformance seam 留下 regression guard，不另建 framework。

DCT build／test／MySQL E2E 為 SKIPPED：本次只改 machine-local workflow CI，不影響 DCT runtime。

## Closeout Ledger

| Row | Verdict | Evidence |
|---|---|---|
| Scope | PASS | 只改 isolated shared candidate 的 test、CI 與 evidence |
| RED → GREEN | PASS | retired deployment與unsupported legacy call均先重現RED再GREEN |
| S4 Verify | PASS with tooling limit | shared + 三 host + immutability + security均PASS；actionlint UNAVAILABLE，以Ruby parse替代 |
| S5 Standards | PASS with documented deviation | sequential PASS；formal fanout受Plan 48 no-subagent限制 |
| S5 Spec | PASS | shared-skills CI與three-host ownership contract一致 |
| S6 Closeout | PASS for candidate only | local commits；push／PR／merge、live cutover與SaaS均SKIPPED |

## 9. Unique next gate

唯一下一 gate：

> 使用者另行明示授權 coordinated live cutover、三家 Superpowers 實際退休，以及固定 6-run fresh context／shared-Matt canary budget。

在該授權前保持四個 live repos 原狀，不啟動任何 cutover、plugin mutation 或 SaaS/context probe。

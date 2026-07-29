# Three-host global-config split — blocker reconciliation amendment evidence

> 日期：2026-07-29 Asia/Taipei
> Scope：Plan 48 candidate-only amendment；不含live cutover、plugin mutation、SaaS、remote、push、PR或merge。
> Risk：HIGH。

## 1. Authorization and fixed point

使用者明示：

> 核准 Plan 48 amendment，執行 candidate-only 修改與驗證。

Shared candidate fixed point：

`4c201511491448e5578583952f6ec519024cb4b7`

Amendment commits：

| Commit | Purpose |
|---|---|
| `c143564` | RED contract；未修訂Plan時ownership test exit 1 |
| `d2e2f65` | Minimal GREEN；Plan 48與既有ownership test |

本文件commit hash由post-commit evidence回報，避免self-reference。

## 2. Fresh preflight

| Gate | Verdict | Evidence |
|---|---|---|
| Maintenance processes | PASS | Claude、Copilot、DataGrip、Code - Insiders process 0 |
| Claude `.in_use` | PASS | active PID marker 0 |
| Four live repos | PASS | 20-row manifest exact，SHA-256 `3426b877845913a2ebbc5c9f6cf3ac2876aa29f2df9a46171e6b475446897217` |
| Six critical files | PASS | SHA／size／mode exact |
| Four candidates | PASS | expected HEAD；pre-amendment all clean |
| Historical manifest | PASS | 78 rows，SHA-256 `6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf` |
| Rollback carrier | PASS | `COMPLETE`；52/52 files；15 carriers；four bundles PASS |

Secrets只用metadata狀態：credential surface `set`、`value_recorded=no`；沒有讀取或輸出值。

## 3. Shared-skills amendment

Original 662-row manifest保持historical audit evidence：

`f7a3595ed6cbe8ff691fc094438aaed48e0cb8fdaa04b3a87a4c1a1ba37da12b`

Fresh current manifest：

`fae53af7392e6bd47a0c4c8ae90f33a08a2466acf7b8a17946206e2f2cddf4a6`

唯一差異仍是exact relative path `.DS_Store`：

```text
.DS_Store	file	abac08d6445bcc8848a10a5e0e2a406629d2dea627e500c8e6006f720a647606	57348	644	-
```

Amended gate：

- semantic rows排除的條件只有first TSV field exact等於`.DS_Store`；
- `*.DS_Store`、hidden-file wildcard與directory-wide exclusion禁止；
- exact row另驗type／SHA／size／mode／target且row count = 1；
- metadata再次改變或任何其他skills drift立即FAIL。

Fresh 662-row current manifest經amended gate：PASS。

## 4. Runtime no-load amendment

Pre-cutover per-host verdict沒有改寫：

| Host | Candidate state | Runtime no-load |
|---|---|---|
| Claude | registration disabled | UNAVAILABLE |
| Codex | active refs 0 | UNAVAILABLE |
| Copilot | active refs 0 | UNAVAILABLE |

Amended future transaction固定：

1. pre-cutover驗active refs 0、verified removal interface、exact restore carrier與maintenance quiescence；
2. Claude → Codex → Copilot逐host退休；
3. 每host立即驗static／guard／config與local inventory；
4. 該host Superpowers absent = PASS後才進下一host；
5. 任一FAIL／UNAVAILABLE立即停止並coordinated rollback；
6. maintenance window後的6-run canary仍需獨立明示授權。

Candidate GREEN不代表fresh plugin absence或live cutover PASS。

## 5. RED → GREEN

RED：

```text
FAIL: Plan 48 does not separate only exact .DS_Store from semantic skills payload
```

GREEN：

```text
PASS: three-host global-config ownership contract
```

同一test以synthetic manifests驗證：

- known exact `.DS_Store` reconciliation PASS；
- changed metadata FAIL；
- nested `.DS_Store` drift FAIL；
- other semantic skill drift FAIL。

## 6. Candidate verification

### Shared

| Gate | Result |
|---|---|
| `tests/conformance.sh` | 9 PASS / 0 FAIL / 0 SKIP |
| `tests/three-host-global-config-ownership.sh` | PASS |
| Fresh 662-row manifest through amended seam | PASS |
| `tests/matt-thin-workflow.sh` | PASS |
| `tests/mattpocock-workflow.sh` | 54 PASS / 0 FAIL |
| `tests/legacy-mp-collision.sh` | PASS |
| `tests/vendored-detection.sh` | 33 PASS / 0 FAIL |
| `tests/version-tripwire.sh` | 44 checked / 0 triggered |
| `tests/version-tripwire.sh --selftest` | 44 trigger / 0 degraded |
| `tests/git-push-guard.sh` | 68 PASS / 0 FAIL |
| `tests/codex-git-push-guard.sh` | 12 PASS / 0 FAIL |
| `tests/claude-routing-collision.sh` | PASS |
| `tests/agents-branch.sh` | PASS |
| Bash syntax／ShellCheck error severity | PASS |
| Current amendment `git diff --check` | PASS |
| Markdown heading／placeholder scan | PASS |
| Gitleaks `--redact=100` | PASS；51 shared commits scanned，no leaks |

Full live→candidate `git diff --check`另命中pre-existing Plan 38兩個Markdown hard-break spaces；不在`4c2015..d2e2f65` amendment diff，未作scope外修正。

### Per-host

| Host | Ownership／integrity | Parser／syntax／lint | Gitleaks |
|---|---|---|---|
| Claude | 19 PASS / 0 FAIL | PASS | PASS |
| Codex | PASS | PASS | PASS |
| Copilot | PASS | PASS | PASS |

DCT build／test／MySQL E2E：SKIPPED；amendment只改machine-local workflow plan與shell contract test。

## 7. Review

| Axis | Verdict | Evidence |
|---|---|---|
| Standards | PASS | sequential review；0 actionable findings |
| Spec | PASS | exact-path、per-host、fail-fast、rollback、authorization requirements全覆蓋 |
| Formal fan-out | UNAVAILABLE | Plan 48禁止subagent；未假綠 |

## Closeout Ledger

| Row | Verdict | Evidence |
|---|---|---|
| Scope | PASS | Plan 48、既有ownership test、this evidence only |
| RED → GREEN | PASS | `c143564` RED → `d2e2f65` GREEN |
| S4 Verify | PASS | shared＋三host＋manifests＋security gates PASS |
| S5 Standards | PASS with deviation | sequential PASS；formal fan-out UNAVAILABLE |
| S5 Spec | PASS | amendment requirements exact |
| S6 Closeout | PASS for candidate only | no live/plugin/SaaS/remote action |

## 8. Unique next gate

完成本evidence commit與post-commit revalidation後停止。唯一下一gate：

> 使用者另行明示授權coordinated live cutover與三家Superpowers實際退休。

Maintenance window後的fixed 6-run canary仍需獨立明示授權。

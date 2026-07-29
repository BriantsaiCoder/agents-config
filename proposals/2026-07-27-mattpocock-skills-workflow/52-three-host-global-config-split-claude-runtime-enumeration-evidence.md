# Three-host split — Claude runtime enumeration amendment evidence

> 日期：2026-07-29 Asia/Taipei  
> Scope：candidate-only；不含live cutover、plugin mutation、SaaS、remote或6-run canary。  
> Risk：HIGH。

## 1. Authorization

使用者明示：

> 核准最小 candidate-only .claude runtime enumeration amendment 與 RED→GREEN 驗證；不授權 live cutover、plugin mutation或 6-run canary。

## 2. Root cause

第一次live cutover的isolated shared candidate沒有runtime-only
`skills/.claude` directory。切到live後，兩個未過濾的top-level directory
enumeration把該directory算成skill：

- `bin/agents-sync` doctor的source count；
- Claude `tests/repo-integrity.sh` 的shared-source loop。

Bootstrap原本用non-hidden glob，所以不會建立`.claude` link；doctor與Claude
test卻要求該link存在，形成candidate GREEN／live FAIL。

## 3. Before／after semantics

| Gate | Before | After |
|---|---|---|
| Skill directory enumeration | 所有top-level directory都被count | 只排除exact `skills/.claude` |
| Runtime directory | candidate未出現，live被誤判為skill | 不建立Claude skill link |
| Unknown hidden directory | glob可能略過 | 缺`SKILL.md`立即FAIL |
| Shared-skills manifest | `.DS_Store`以外全屬semantic payload | 不變；`.claude`仍在manifest／metadata gate |
| Wildcard | 無明文runtime契約 | 禁止hidden-directory wildcard |

## 4. RED → GREEN

RED commit：

- shared `b5b5a5504430a40d2514744e42b1919f44a950e0`
- command：`bash tests/three-host-global-config-ownership.sh`
- exit：1
- root failure：`FAIL: agents-sync rejected exact skills/.claude runtime directory`

GREEN commits：

- shared `e25317a4429f8951392006cf900b0159d7e31def`
- Claude `d8e28debd2896bb0cb2df1f4ea4142daf8a0153d`

Changed implementation surface：

- shared `bin/agents-sync`
- shared `tests/conformance.sh`
- shared `tests/three-host-global-config-ownership.sh`
- Plan 48 exact contract
- Claude `tests/repo-integrity.sh`

No `skills/**` file changed。

## 5. Candidate verification

| Candidate | Gate | Verdict |
|---|---|---|
| Shared | ownership contract | PASS |
| Shared | conformance | 9 PASS / 0 FAIL |
| Shared | Matt thin workflow | PASS |
| Shared | Matt workflow | 54 PASS / 0 FAIL |
| Shared | vendored detection | 33 PASS / 0 FAIL |
| Shared | version tripwire／selftest | 44 clear；44 trigger / 0 stale |
| Shared | push guards | 68 PASS / 0 FAIL；Codex 12 PASS / 0 FAIL |
| Shared | Claude collision／selftest | PASS |
| Shared | agents-branch isolation | PASS |
| Claude | repo integrity with candidate shared root | 19 PASS / 0 FAIL |
| Codex | ownership | PASS；candidate unchanged |
| Copilot | ownership | PASS；candidate unchanged |
| Shared／Claude | Bash、ShellCheck error、diff-check | PASS |
| Shared／Claude | Git-aware gitleaks | PASS；no leaks |

`deps-check` script對shell標示SKIPPED；manual active-caller inventory涵蓋
CI、README、`agents-branch`、drift／post-checkout hooks與兩支ownership tests。
本次沒有改CLI mode或caller contract。

## 6. Immutable manifests

- live shared skills：662 rows；
  SHA-256 `fae53af7392e6bd47a0c4c8ae90f33a08a2466acf7b8a17946206e2f2cddf4a6`；
  semantic PASS。
- exact `.DS_Store` metadata：
  SHA-256 `abac08d6445bcc8848a10a5e0e2a406629d2dea627e500c8e6006f720a647606`；
  size 57348；mode 0644；PASS。
- historical manifest：78 rows；
  SHA-256 `6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf`；
  exact PASS。

`.DS_Store`未修改、處理或還原。

## 7. Fresh live blocker

本candidate-only session開始前，live已在2026-07-29 20:01產生新的
control-plane drift：

- `~/.agents/core/tier2-style.md`
- `~/.agents/dist/AGENTS.md`
- `~/.agents/dist/copilot-instructions.md`
- `~/.agents/dist/manifest.tsv`
- `~/.codex/AGENTS.md`
- `~/.copilot/copilot-instructions.md`

四個live HEAD仍為rollback HEAD；Claude critical files與Matt lock仍exact。
Codex／Copilot live instructions各自與目前`~/.agents/dist` exact相同，但不
假設該drift只是provenance變更；normalized comparison仍有差異。

Verdict：**FAIL for second cutover preflight**。不得自行restore、吸收到
candidate或擴大baseline。

Secrets只回報metadata：credential surface `set`、`value_recorded=no`；
未讀取或輸出值。

## 8. Review

### Standards

PASS。只在既有enumeration seam新增一個共用helper；沒有dependency、
framework、wildcard exclusion或scope外refactor。Formal subagent fan-out因
Plan 48禁止subagent而UNAVAILABLE；sequential review完成。

### Spec

PASS for candidate amendment。exact `.claude` acceptance、unknown hidden
directory fail-fast、manifest preservation與RED→GREEN均有mechanical evidence。
Live re-cutover release gate因§7 drift維持FAIL。

## 9. Rollback and next gate

Candidate rollback：

- shared scoped revert `e25317a`與`b5b5a55`；
- Claude scoped revert `d8e28de`；
- 禁止force push或hard reset。

本輪沒有live或plugin rollback action，因本輪未修改兩者。

唯一下一gate是先由使用者裁定§7 live drift：保存為新baseline，或依既有
carrier另案還原。完成read-only reconciliation與fresh rollback carrier後，
才可另行核准第二次 coordinated live cutover。6-run canary仍需獨立授權。

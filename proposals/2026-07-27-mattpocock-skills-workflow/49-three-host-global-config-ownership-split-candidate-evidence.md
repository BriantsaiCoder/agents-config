# Three-host global-config ownership split + Matt thin workflow — candidate evidence

> 日期：2026-07-29 Asia/Taipei
> 授權：使用者明示「開始依照plan實作」。
> 範圍：Plan 48 的 staged candidate implementation（Commits A–I）。
> Risk：**HIGH**。
> 結論：**isolated final-architecture candidates 已完成；四個 live repos、shared live skills 與 historical evidence 均未改動。live cutover、Superpowers 實際卸載與 SaaS/context canary 未授權，且三家 runtime no-load shadow verdict 均為 UNAVAILABLE，因此 live cutover 仍被阻擋。**

## 1. Authorization boundary

本輪實作：

- 將 Claude、Codex、Copilot global config 分別收回各自 candidate repo ownership。
- 將 `.agents` candidate 收斂為唯一 shared skills data plane。
- 將三家 candidate 改為 thin routing／governance kernel，底層 route 到 shared Matt Pocock skills。
- 在逐支 static parity PASS 後退休四支 legacy `mp-*` wrappers；`mp-zoom-out` 保留 exact。
- 建立 zero-reference／candidate-disabled／inventory evidence，未修改 live plugin registration。

本輪未執行：

- live `~/.agents`、`~/.claude`、`~/.codex`、`~/.copilot` cutover；
- live Superpowers disable／uninstall；
- SaaS/context probe 或新 session canary；
- push、PR、merge、remote mutation；
- subagent；
- DCT build、test、MySQL E2E。

Secrets／credentials 只以 presence metadata 檢查；未輸出 config body、credential value、auth cache 或 credential-bearing process arguments。

## 2. Candidate branches and commits

### 2.1 Final architecture code heads before this evidence commit

| Plane | Isolated worktree | Branch | A–H HEAD |
|---|---|---|---|
| Shared `.agents` | `/private/tmp/agents-worktrees/codex/three-host-global-config-split-impl` | `codex/three-host-global-config-split-impl` | `a4691a402f4f1a4754e2bf7e1d1b85aa89da9438` |
| Claude | `/private/tmp/claude-worktrees/codex/three-host-global-config-split-claude` | `codex/three-host-global-config-split-claude` | `b228486fe72607cc85c64a22b7f05deaa36f722a` |
| Codex | `/private/tmp/codex-worktrees/codex/three-host-global-config-split-codex` | `codex/three-host-global-config-split-codex` | `8728b75a1acdc11b5de186f12cefbe574e7f1ad5` |
| Copilot | `/private/tmp/copilot-worktrees/codex/three-host-global-config-split-copilot` | `codex/three-host-global-config-split-copilot` | `c7d6073f4251c632473f647139b9a4a95b7095a2` |

本 evidence commit 只新增本檔，因此 `.agents` post-evidence HEAD 由外部 closeout 回報，避免 self-reference。

### 2.2 Commit ledger

| Repo | Commit | Subject |
|---|---|---|
| `.agents` | `81bb11c` | `test(workflow): [wip] 鎖定三家設定 ownership` |
| `.agents` | `d6fd1f1` | `refactor(workflow): 收斂為共享 skills data plane` |
| `.agents` | `7c18e5f` | `test(workflow): [wip] 鎖定 Matt 薄型流程` |
| `.agents` | `a4691a4` | `refactor(workflow): 切換 Matt 薄型流程` |
| Claude | `ec398ec` | `refactor(claude): 分離全域設定 ownership` |
| Claude | `b228486` | `refactor(claude): 切換 Matt 薄型流程` |
| Codex | `a381983` | `refactor(codex): 分離全域設定 ownership` |
| Codex | `8728b75` | `refactor(codex): 切換 Matt 薄型流程` |
| Copilot | `948c65a` | `refactor(copilot): 分離全域設定 ownership` |
| Copilot | `c7d6073` | `refactor(copilot): 切換 Matt 薄型流程` |

所有 commits 均只存在 isolated candidates；live branches 未切換。

## 3. Resulting architecture

```text
Claude-local thin kernel ─┐
Codex-local thin kernel  ─┼─> ~/.agents/skills/** Matt workflow
Copilot-local thin kernel ─┘          │
                                      └─> shared S4 verify
                                           shared S5 review
                                           host-local S6 closeout adapter
```

Hard outcomes：

1. `.agents/bin/agents-sync` 不再讀、寫、render、deploy、hash 或 validate host global config。
2. `agents-sync --check` 驗 shared source；`--doctor` 驗 source 與 Claude skill links；`--bootstrap` 只建立 Claude skill links。
3. `agents-sync` default、`--deploy`、`--only` fail-loud，不碰 host config。
4. 三家 global instruction、rules、hooks 與 routing 分別由 host candidate 擁有。
5. 三家只共享 `~/.agents/skills/**`；未新增 registry、daemon、generator 或 dependency。
6. `dev-workflow` 保留 S0 routing、S2 authorization、BUGFIX RED→GREEN、S4–S6 與 host adapters。
7. 需求、spec、tickets、implementation、TDD、diagnosis、review、architecture route 到：
   `grilling`、`domain-modeling`、`to-spec`、`to-tickets`、`implement`、`tdd`、`diagnosing-bugs`、`code-review`、`codebase-design`、`wayfinder`。
8. `implement` 明文要求 isolated worktree／branch、拒絕 current／main commit，完成後回到 S4→S5→S6。

Thin host instruction metadata：

| Host | Candidate file | Bytes | SHA-256 |
|---|---|---:|---|
| Claude | `CLAUDE.md` | 2697 | `a9338d82730eb0da79d952108c5abf7d0c41c49b5f844e6b9291286646e8ca62` |
| Codex | `AGENTS.md` | 4154 | `bd12ee8df535d5c72b607bf17ee254be353624b5fed7d6f79384016220f00501` |
| Copilot | `copilot-instructions.md` | 4271 | `b48569d184e66b9c8c4e1a64bde0611a2dd96e79f74921e7e4cea2dd702ea955` |

## 4. RED → GREEN evidence

| Contract | RED before implementation | GREEN candidate |
|---|---|---|
| `.agents` ownership | non-zero；root `FAIL: agents-sync still owns host global config` | `tests/three-host-global-config-ownership.sh` exit 0 |
| Claude ownership | 10 PASS / 6 FAIL；core/rules/hooks 仍由 `.agents` 擁有 | ownership commit 後 host integrity gate PASS |
| Codex ownership | generated banner／shared hook paths 命中 | `PASS: Codex global config ownership` |
| Copilot ownership | generated banner／shared fallback paths 命中 | `PASS: Copilot global config ownership` |
| Shared thin workflow | non-zero；root `FAIL: legacy workflow wrapper still active: mp-diagnose` | `PASS: Matt thin workflow contract` |
| Claude thin adapter | 15 PASS / 7 FAIL；thin budget／routes／plugin registration 尚未收斂 | 19 PASS / 0 FAIL with candidate shared-skills root |
| Codex thin adapter | 8306-byte body 超過 thin budget | 4154 bytes；host gate PASS |
| Copilot thin adapter | 9111-byte body 超過 thin budget | 4271 bytes；host gate PASS |

RED commits為 feature-branch `[wip]` test commits，未 push／merge。

## 5. Ownership equivalence

Ownership stage只 normalize Plan 48 允許的 banner、provenance、host-local path 與 symlink materialization差異；未保存或輸出 config body。

| Host surface | Before normalized SHA-256 | After normalized SHA-256 | Verdict |
|---|---|---|---|
| Claude instruction body | `7375c2f724ff79452970417e5456e6df374e9cfd81234e9513bb091c718d3a51` | same | PASS |
| Claude settings structure | `55594b3feb4a7fefbeb69026d4217f3df9498390ebc0de629bfa51d0f035c648` | same | PASS |
| Codex instruction body | `ba22561e25020941024ce0f7d2868e53706a81b17ef04a2fc46a732f5dce9a93` | same | PASS |
| Codex hook structure | `9068407f023c0760f7e227006e9b6eb71169669b0ae6088e23063fd9b2b4a6ce` | same | PASS |
| Copilot instruction body | `0a44a9f049a50330f3774434b75ce867514b5686f0b4bdd8b8d554bf56a3d0a4` | same | PASS |

Materialized source-to-candidate aggregate comparisons：

| Host | Aggregate SHA-256 | Verdict |
|---|---|---|
| Claude core／rules／hooks | `cdfbd39ffd043f824bc2f2c9e63e288a90ede469c5b7425083523f5c2150d039` | source = candidate |
| Codex rules／hooks | `b5d1eb8ad5c7e313e24e03fad365029383e3efecf0d542903e80f00d4175b9e4` | source = candidate |
| Copilot rules／hooks | `42dc5d83d8ab9616f05220c8038fd5e699303f06159ce248adf8714533ae480a` | source = candidate |

Copilot protected host-local files保持 exact：

| File | SHA-256 |
|---|---|
| `mcp-config.json` | `9351809e1bb3f1c9e6a16b82d6188ad4fdff7efcaa78d544f813334d49ac9e7d` |
| `permissions-config.json` | `6ac6419215ee43c6387dde7a2d2a327ae7b90829ca7140f04a330d55b33bd04d` |
| `hooks/guard-git-push.json` | `b14ae280daea1cd6117c55499dba3f0f100af1ddfb055ae76ee54c014ba82bd9` |
| `hooks/guard-git-push.sh` | `77e1a673c4907a0781a43c5f9e76d25759d9a2fac047612696858d36fd9b9b88` |

## 6. Shared-skills immutability and workflow allowlist

### 6.1 Ownership stage

| Manifest | Rows | Before SHA-256 | After SHA-256 | Verdict |
|---|---:|---|---|---|
| Isolated candidate tracked skills | 630 | `4580f2144cc16c9e1785cf66f82b8370c15b781c76b30471b96059f51056b309` | same | PASS |
| Planning live skills | 662 | `f7a3595ed6cbe8ff691fc094438aaed48e0cb8fdaa04b3a87a4c1a1ba37da12b` | same | PASS |

兩個 row count差異只來自 live runtime metadata（例如 `.DS_Store` 與 `.claude/.cc-writes`）；live 662-row manifest已逐 row對目前 `~/.agents/skills` 重驗，沒有 candidate 寫入。

### 6.2 Workflow stage

Workflow base：`d6fd1f1`。

- changed skills paths：22；
- allowlist name-status SHA-256：`4b4f25029086766a558991b3ef71eff5b10eb102dfe0bdb9c2faaa44b5d49a89`；
- 內容：`skills/dev-workflow/SKILL.md` 一個 modify，加四個 legacy wrapper trees共 21 個 deletes；
- non-allowlisted shared-skill diff：empty；
- Matt upstream skill diff：empty（依 `mattpocock-skills.lock` 逐 skill）；
- `skills/dev-workflow/SKILL.md` SHA-256：`cbc19eecde58472946135274fc415c0dfb87f1833da78bb48d40bf9f7209386d`；
- `skills/mp-zoom-out` before／after Git tree：`4f966027fb633380a16dfc5386845f6c2be483c2`；
- `skills/mp-zoom-out/SKILL.md` SHA-256：`456d724d79f8f66a205d0d45298cd12441c46e4020d276ce4014f56cc52c78ac`。

Compatibility carriers保持 current path與metadata：

- `docs/agents/issue-tracker.md`
- `rules/typescript.md`
- `rules/frontend-spa.md`

## 7. Legacy wrapper parity and retirement

Private metadata-only parity carrier：

- path：`/private/tmp/three-host-global-config-split-wrapper-parity.tsv`
- SHA-256：`28c885ed503e6326130d60bc4808b95703122e279307e9ae54e8ecda36ac7ab7`

| Retired wrapper | Replacement | Legacy tree | Verdict |
|---|---|---|---|
| `mp-diagnose` | `diagnosing-bugs` + `codebase-design` | `963fb33f2425ee90562ce830749e7ef64c46f7eb` | PASS — feedback loop與exact HITL script有carrier |
| `mp-grill-with-docs` | `grilling` + `domain-modeling` | `7f75b3ce02cacc25fd414e3bf233d2cd6ff4414b` | PASS — one-question pressure、context與ADR format有carrier |
| `mp-improve-codebase-architecture` | `codebase-design` + `grilling` | `577f4b0f7b20c3d2eb37b8b4bc87d029afa1f0d0` | PASS — vocabulary、deepening、seams、design-it-twice有carrier |
| `mp-tdd` | `tdd` + `codebase-design` + thin kernel | `a7935cdc6cc42cfea2d800293caeb0caca4025cf` | PASS — tracer slices、tests、mocking、interface depth、post-GREEN micro-refactor有carrier |

Active routing／shared skills中的上述四支 wrapper refs與 `superpowers:*` refs均為零；historical proposals、attic、backup evidence未改。

## 8. Plugin-disabled shadow verdicts

Private metadata-only inventory：

- path：`/private/tmp/three-host-global-config-split-plugin-shadow.tsv`
- SHA-256：`50aac5560efb81afd33599f182aaebcf5da929f78ff454b4753a538f1cb7bc6c`

| Host | Candidate state | Live inventory | Safe shadow seam | Runtime no-load verdict |
|---|---|---|---|---|
| Claude | candidate `settings.json` 明確將 Superpowers registration設為 disabled | installed 1、enabled 1；live unchanged | `--bare` 文件與local command可用，但本輪未授權 SaaS/context probe | **UNAVAILABLE** |
| Codex | active instruction refs = 0 | installed 1、enabled 1；live unchanged | 未找到 verified disable-all/profile seam | **UNAVAILABLE** |
| Copilot | active instruction refs = 0 | installed 1、enabled-or-unknown 1；live unchanged | 無 disable-all；實際 inventory interface為 singular `plugin list` | **UNAVAILABLE** |

這三個 verdict不可互相推論，也不可標成 plugin absent。任一 UNAVAILABLE 依 Plan 48 阻擋 coordinated live cutover；本輪沒有實際 disable／uninstall。

## 9. Candidate verification

### 9.1 Shared `.agents`

| Gate | Result |
|---|---|
| `tests/three-host-global-config-ownership.sh` | PASS |
| `tests/matt-thin-workflow.sh` | PASS |
| `AGENTS_HOME=$PWD bash tests/conformance.sh` | 8 PASS / 0 FAIL |
| `tests/agents-branch.sh` with candidate `AGENTS_HOME` | PASS |
| `tests/legacy-mp-collision.sh` | PASS |
| `tests/mattpocock-workflow.sh` | 54 PASS / 0 FAIL |
| `tests/vendored-detection.sh` | 33 PASS / 0 FAIL |
| `tests/version-tripwire.sh` | 44 checked；0 mismatch |
| Bash syntax | PASS |
| ShellCheck error severity | PASS |
| `git diff --check` | PASS |
| Git-aware gitleaks | PASS；no leaks |

第一次單獨重跑 `tests/conformance.sh` 未傳 candidate `AGENTS_HOME`，因此依預設執行仍未 cutover 的 live `agents-sync`，得到7 PASS / 1 FAIL。改用已解析的 isolated candidate root後為8 PASS / 0 FAIL；這與本輪禁止修改live的邊界一致。

Shared default ShellCheck另顯示既存安全guard與tests的warning／info級 diagnostics；error-severity全檔 gate為PASS。因本輪contract要求guard behavior與既存test corpus最小變動，未把non-error lint cleanup混入HIGH-risk ownership migration。

### 9.2 Claude

| Gate | Result |
|---|---|
| `SHARED_SKILLS_ROOT=/private/tmp/agents-worktrees/codex/three-host-global-config-split-impl/skills bash tests/repo-integrity.sh` | 19 PASS / 0 FAIL |
| Skill symlinks | 68／68 exact same-name targets under `../../.agents/skills/` |
| `jq empty settings.json` | PASS |
| Bash syntax | PASS |
| ShellCheck error severity | PASS |
| `git diff --check` | PASS |
| Git-aware gitleaks | PASS；no leaks |

第一次 final invocation未傳 `SHARED_SKILLS_ROOT`，test依預設讀到仍未 cutover 的 live 72-wrapper source與runtime-only `.claude` directory，得到5個missing-link FAIL。依 Plan 48 candidate-only boundary改用已解析的 isolated shared candidate root後為19 PASS / 0 FAIL；沒有修改 live source或把該 invocation誤列為candidate defect。

### 9.3 Codex

| Gate | Result |
|---|---|
| `tests/global-config-ownership.sh` | PASS |
| `jq empty hooks.json` | PASS |
| Bash syntax | PASS |
| ShellCheck error severity | PASS |
| ShellCheck excluding exact inherited `SC2206`／`SC2020` and literal-pattern `SC2088` | PASS |
| `git diff --check` | PASS |
| Git-aware gitleaks | PASS；no leaks |

### 9.4 Copilot

| Gate | Result |
|---|---|
| `tests/global-config-ownership.sh` | PASS |
| `jq empty hooks/guard-git-push.json mcp-config.json permissions-config.json` | PASS |
| Bash syntax | PASS |
| ShellCheck error severity | PASS |
| ShellCheck excluding exact inherited `SC2206`／`SC2020` and literal-pattern `SC2088` | PASS |
| `git diff --check` | PASS |
| Git-aware gitleaks | PASS；no leaks |

Codex／Copilot default ShellCheck另顯示：

- `SC2206`、`SC2020`：split前既存、要求 exact materialization的 git-push guard；本輪不得順手重寫安全 parser。
- `SC2088`：ownership test故意用 literal `~/.agents/skills/...` 作 `rg` pattern，不期待 shell tilde expansion。

兩家均另跑 error-severity全檔 gate與精確 exclusion default-severity gate；沒有 blanket disable或修改 safety-hook bytes。

## 10. Live and historical immutability

### 10.1 Four live repos

`/private/tmp/three-host-global-config-split-live-before.tsv`：

- rows：20；
- SHA-256：`3426b877845913a2ebbc5c9f6cf3ac2876aa29f2df9a46171e6b475446897217`；
- post-implementation exact diff：empty。

| Repo | Branch | HEAD | Exact live porcelain |
|---|---|---|---|
| `~/.agents` | `main` | `36f8ff1dc208be531f52216dd33f2f32aec62e0f` | original 7 untracked proposal paths |
| `~/.claude` | `main` | `971f3015517267c7e070dff31b1a68a7d4ea04c4` | ` M settings.json` |
| `~/.codex` | `main` | `bd1195dbee85b405b959a387b59f64d5449ab581` | ` M AGENTS.md` |
| `~/.copilot` | `main` | `4b47fee53c68644f1dbcd75136440c01fda09f9d` | ` M copilot-instructions.md` |

Live critical file hashes、sizes、modes與 Plan 48 baseline exact；`~/.agents/skills` 662-row manifest也 exact。

### 10.2 Historical evidence

`/private/tmp/three-host-global-config-split-historical-before.tsv`：

- rows：78；
- SHA-256：`6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf`；
- post-implementation exact diff：empty。

Plan 45、Evidence 47、Phase 4 artifacts、historical host commits、attic與existing rollback carriers未改；Stage 2 FAIL、Codex UNEXECUTED、Copilot EXCLUDED與budget均未重寫。

## 11. Rollback

Candidate rollback：

- `.agents`、Claude、Codex、Copilot各自以 scoped `git revert` 還原本節列出的 isolated commits；
- 禁止 force push、hard reset或將candidate partial部署到live；
- existing comparison carriers：
  - `~/.agents-deployment-backups/20260727-193338-matt-v2`
  - `~/.agents-deployment-backups/20260727-205915-matt-v4`
  - `~/.agents/backups/20260728-065158-m1-live-skill-drift`

Future live cutover前仍必須依 Plan 48另建三個pre-existing dirty live files與每host plugin registration的mode-restricted exact-byte carriers。任一 host FAIL／UNAVAILABLE時整體 coordinated rollback，不允許 mixed ownership。

## 12. Standards and specification review

| Review | Verdict | Evidence |
|---|---|---|
| Sequential Standards review | PASS | scope最小、無新增dependency／framework／registry；host ownership、secret boundary、rollback、RED→GREEN與immutable surfaces逐項核對 |
| Sequential Spec review | PASS | Plan 48 A–I、§7 allowlist、§8 equivalence、§10 RED contracts、§12 candidate gates、§16 historical immutability逐項核對 |
| Formal review fanout | UNAVAILABLE | Plan 48明確禁止subagent；未以未授權delegation假裝完成review |

## Closeout Ledger

| Row | Verdict | Evidence |
|---|---|---|
| Scope | PASS | 只改四個isolated candidates；live、SaaS、plugin registration、remote均未改 |
| RED → GREEN | PASS | ownership與thin-workflow均先有可重現RED，再有final GREEN |
| S4 Verify | PASS | shared + Claude + Codex + Copilot各自gate；immutability、gitleaks、syntax、parsers、diff均PASS |
| S5 Standards | PASS with documented deviation | sequential review PASS；formal fanout因no-subagent constraint為UNAVAILABLE；兩個exact inherited guard warning未被掩蓋 |
| S5 Spec | PASS | Plan 48 candidate scope完成；plugin shadow UNAVAILABLE正確阻擋live cutover |
| S6 Closeout | PASS for candidate only | commits local；push／PR／merge、DCT runtime gates與live cutover均SKIPPED |

## 13. Unique next gate

唯一下一 gate：

> 使用者另行明示授權 coordinated live cutover、三家Superpowers實際退休，以及固定6-run fresh context／shared-Matt canary budget。

在該授權前保持四個 live repos原狀，不啟動任何 cutover、plugin mutation或SaaS/context probe。

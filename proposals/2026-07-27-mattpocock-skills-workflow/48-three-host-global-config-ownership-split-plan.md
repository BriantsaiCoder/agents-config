# Three-host global-config ownership split + Matt thin workflow — candidate implementation plan

> **For agentic workers:** use Matt `implement` under `dev-workflow` `[INT-6]`, execute this plan task-by-task, and return to kernel S4–S6 before any closeout. Steps use checkbox syntax for tracking. Subagent-driven execution is prohibited unless the user separately authorizes it.

**Goal:** 將 Claude、Codex、Copilot global config 分別收回各自 repo ownership；三家 live cutover 後只保留 host-local thin routing／governance kernel，並共同使用 `~/.agents/skills/**` 的 Matt Pocock skills 作為主要 workflow。

**Architecture:** 在 isolated candidates 內先做 behavior-preserving ownership split，再依序完成 legacy `mp-*` retirement、Superpowers capability re-home／per-host retirement candidate與 thin-kernel trim；全部驗證完成後才允許一次 coordinated live cutover。`.agents` 最終只保留 shared skills data plane、必要 compatibility carriers與 Claude skill-symlink bootstrap。

**Tech Stack:** Bash、Git worktree、JSON／`jq`、SHA-256、`cmp`／`diff`、gitleaks；不新增 dependency。

## Global Constraints

- ownership stage 的 `~/.agents/skills/**` byte、path、mode與symlink target完全不變。
- workflow stage 只允許 §7 allowlist 內的本機 kernel／legacy wrapper變更；Matt upstream files完全不變。
- ownership stage只允許 ownership／provenance、host-local paths與symlink materialization差異；workflow stage另以capability parity與thin-kernel contract驗收。
- 三個 pre-existing modified live files不得被Git restore或舊commit覆蓋。
- Secrets／credentials只回報`set`／`unset`，不得輸出值或diff body。
- Candidate implementation包含 ownership split與原M2／M3／M5的isolated candidate工作；live cutover、plugin實際卸載與SaaS/context probe仍分開授權。
- 四個 live repos保持原branch／HEAD／porcelain直到live cutover gate。
- 不使用subagent；不push、PR、merge或remote mutation。

> 日期：2026-07-29 Asia/Taipei
> 修訂：2026-07-29；依使用者「好依照建議修改plan」納入 staged-candidate／single-final-cutover 架構。
> 修訂：2026-07-29；依使用者「核准 Plan 48 amendment，執行 candidate-only 修改與驗證」調和 shared-skills `.DS_Store` 與 runtime no-load blockers。
> 狀態：revised candidate planning evidence；本文件不授權 implementation、live cutover、plugin實際卸載、SaaS/context probe、push、PR、merge 或任何 remote mutation。
> 唯一共享 data plane：`~/.agents/skills/**`。
> Risk：**HIGH**。

## 0. 可行性結論與授權邊界

此 migration 可行。採用 **staged candidate、single final cutover**：

- Claude Code 的 global config 只由 `~/.claude/**` 擁有。
- Codex 的 global config 只由 `~/.codex/**` 擁有。
- Copilot 的 global config 只由 `~/.copilot/**` 擁有。
- `~/.agents/**` 不再是任何 host 的 global-config control plane。
- `~/.agents/skills/**` 保持三家唯一共享 skill source。
- 三家 host-local global config只保留 Tier 0、routing／authorization、plan gate、S4–S6 evidence／review／closeout與host adapter。
- Matt Pocock skills負責需求釐清、spec／tickets、implementation、TDD、diagnosis、review與architecture方法。
- 四支已取代的legacy `mp-*`退休；`mp-zoom-out`因無一對一replacement而保留。
- Superpowers active references先歸零、capability先re-home，之後才逐host退休；live不經過「ownership已拆但仍使用舊workflow」的中間狀態。
- Claude 現有 `~/.claude/skills/*` symlink 保持原 target。
- Codex 與 Copilot 保持原生 discovery，不新增第二個 registry、manifest、sync daemon 或 dependency。

本 session 只允許：

1. read-only 稽核與 planning baseline；
2. 在既有 isolated planning worktree修訂並commit本文件；
3. candidate-only planning validation。

本 session 明確不允許：

- 修改 live `~/.agents`、`~/.claude`、`~/.codex`、`~/.copilot`；
- 修改 `~/.agents/skills/**` 的 byte、path、mode、symlink target 或 Git history；
- candidate implementation、live cutover、plugin實際卸載、SaaS/context probe；
- 讀取 Stage 2 Keychain credential carrier；
- 重用 Phase 4 budget；
- push、PR、merge、remote mutation；
- 原M2／M3／M5 implementation execution；
- subagent 或額外 research delegation；
- broad `git restore`、`reset --hard`、force push 或處置 user-owned dirty/untracked files。

Secrets／credentials 只回報 `set`／`unset`；不得輸出值、diff body、auth cache 或帶 credential 的 process arguments。

### Non-goals

- 不刪減 Tier 0、安全紅線、plan-first、RED→GREEN、S4–S6、PR／CI與rollback gates。
- 不修改 Matt upstream files；本機 adapter／kernel不得混入 upstream body。
- 不修 Phase 4 Stage 2 failure、不重跑任何 Phase 4 row、不修改 historical verdict。
- 不整理pre-existing backups、cache、runtime state、dirty files或untracked proposals。
- 不建立跨repo generator、new config framework、shared hooks registry或第二份skills registry。
- 不在 candidate implementation內實際卸載任何 live host plugin；candidate只建立zero-reference與plugin-disabled驗證條件。

## 1. Planning preflight evidence

### 1.1 S0–S2 gate

| Gate | Result | Evidence |
|---|---|---|
| S0 ROUTE | PASS — HEAVY | architecture／migration、四個 repo、多個 global-control surfaces、risk HIGH |
| S1 NEEDS | PASS | 使用者確認終態為「三AI各自薄routing／governance + shared Matt Pocock workflow + Superpowers退出」 |
| S2 PLAN | PASS | 使用者原句：「好依照建議修改plan」；本輪只修訂planning artifact，不執行implementation |
| Delegation | SKIPPED | 使用者明示禁止 subagent／額外 research delegation |

### 1.2 Existing Phase 4 candidate

| Field | Verified value |
|---|---|
| Resolved path | `/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary` |
| Branch | `codex/mattpocock-workflow-phase4-canary` |
| HEAD | `ab9b538d650bf17b728e97d7689fa365d7f79191` |
| Porcelain | clean |
| Stage-2-only exception | `2ee7315000dde0eb399b92dc7a3661b4b85b8e0a` |
| Stage 2 terminal evidence | `ea32d48b12ddb682b52c87f62371390ab521087f` |
| Evidence formatting fix | `ab9b538d650bf17b728e97d7689fa365d7f79191` |

三個 commits 均可解析為 commit，且依上列順序為 ancestor chain。

### 1.3 New isolated planning candidate

| Field | Verified value |
|---|---|
| Resolved path | `/private/tmp/agents-worktrees/codex/three-host-global-config-split-plan` |
| Branch | `codex/three-host-global-config-split-plan` |
| Starting HEAD | `ab9b538d650bf17b728e97d7689fa365d7f79191` |
| Starting porcelain | clean |
| Live `~/.agents` after creation | `main@36f8ff1dc208be531f52216dd33f2f32aec62e0f` |

### 1.4 Live Git boundaries

| Repo | Branch | HEAD | Exact porcelain |
|---|---|---|---|
| `~/.agents` | `main` | `36f8ff1dc208be531f52216dd33f2f32aec62e0f` | 7 pre-existing untracked proposal paths |
| `~/.claude` | `main` | `971f3015517267c7e070dff31b1a68a7d4ea04c4` | ` M settings.json` |
| `~/.codex` | `main` | `bd1195dbee85b405b959a387b59f64d5449ab581` | ` M AGENTS.md` |
| `~/.copilot` | `main` | `4b47fee53c68644f1dbcd75136440c01fda09f9d` | ` M copilot-instructions.md` |

`~/.agents` 的 exact seven：

1. `proposals/2026-07-27-mattpocock-skills-workflow/10-claude-review-of-reconciled-final.md`
2. `proposals/2026-07-27-mattpocock-skills-workflow/11-codex-review-of-claude-feedback-and-gpt56-assessment.md`
3. `proposals/2026-07-27-mattpocock-skills-workflow/12-claude-review-of-codex-feedback-and-dual-host-assessment.md`
4. `proposals/2026-07-27-mattpocock-skills-workflow/13-cross-host-implementation-plan.md`
5. `proposals/2026-07-27-mattpocock-skills-workflow/14-copilot-review-of-cross-host-plan.md`
6. `proposals/2026-07-27-workflow-constraint-audit/`
7. `proposals/2026-07-28-skill-writing-audit/`

### 1.5 Live metadata-only fingerprints

| File | SHA-256 | Size | Mode |
|---|---|---:|---:|
| `~/.agents/proposals/2026-07-28-skill-writing-audit/_population.md` | `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17` | 2348 | 0644 |
| `~/.claude/settings.json` | `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32` | 10647 | 0644 |
| `~/.claude/CLAUDE.md` | `db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7` | 7829 | 0644 |
| `~/.codex/AGENTS.md` | `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372` | 8425 | 0644 |
| `~/.copilot/copilot-instructions.md` | `9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c` | 9165 | 0644 |
| `~/.agents/mattpocock-skills.lock` | `8de7d847f7d1a12d6e2272accad9fb774557782b5fd602b1ad4b5495a7f0c721` | 610 | 0644 |

Planning baseline carrier：

- `/private/tmp/three-host-global-config-split-live-before.tsv`
- 20 rows
- SHA-256 `3426b877845913a2ebbc5c9f6cf3ac2876aa29f2df9a46171e6b475446897217`

該 carrier 只含 path、Git metadata、SHA-256、size、mode，不含 config body 或 secret value。

### 1.6 Historical commits、attic 與 rollback carriers

下列 commits 均可解析，且 named file 存在：

| Repo | Commit | Named file | Finding |
|---|---|---|---|
| `~/.claude` | `e20f9b10a1765b0fd78593e528636b9d516f9f89` | `CLAUDE.md` | 可作 comparison，不可 direct restore |
| `~/.codex` | `5b6539accb98f35b5cc18f67edc7c50a48902509` | `AGENTS.md` | 第一行已是 `agents-sync` generated banner，不是獨立 ownership |
| `~/.copilot` | `f915bb99de903aaa1a0f7cad6e25d64d4fb81421` | `copilot-instructions.md` | 第一行已是 `agents-sync` generated banner，不是獨立 ownership |

Verified attic carriers：

| Path | SHA-256 | Size | Mode |
|---|---|---:|---:|
| `~/.agents/attic/AGENTS.override.md` | `5367180a2707c8d8b9557d9eb1dc78055e846375fbefb54b8e57eab701a375a6` | 4247 | 0644 |
| `~/.agents/attic/AGENTS.md` | `786f29be8030e37d7b6f5f5456d607914a95b2e3a446b789f4f497272db96495` | 32306 | 0644 |
| `~/.agents/attic/copilot-instructions.md` | `63ceeceb26b1fd58e7977f00643790a18e03e36bfcea323523d223a2aeb3dd2c` | 9422 | 0644 |
| `~/.agents/attic/00-agents-shared.instructions.md` | `89a4091ecf160bbe7bcfa858d665b3fbb9434d57411e4a61e4f4349c353887b0` | 9429 | 0644 |

Verified rollback carriers：

| Path | Mode | Top-level entries |
|---|---:|---:|
| `~/.agents-deployment-backups/20260727-193338-matt-v2` | 0700 | 3 |
| `~/.agents-deployment-backups/20260727-205915-matt-v4` | 0755 | 4 |
| `~/.agents/backups/20260728-065158-m1-live-skill-drift` | 0700 | 12 |

這些只作 comparison／rollback evidence。Stage 2 Keychain credential carrier 未讀取。

## 2. Plan 45 supersession 與拒絕 direct Git restore

本文件 **supersedes the ownership design and gate sequence** of
`45-copilot-global-config-separation-plan.md`：

- Plan 45 只讓 Copilot 分離，仍讓 Claude／Codex global config 受 `~/.agents` 控制。
- 本文件擴展為 Claude／Codex／Copilot 三家完整 ownership split。
- Plan 45、Evidence 47 與 Phase 4 歷史 artifacts 本身不修改，仍是 historical evidence。
- Evidence 47 的 Stage 2 verdict 仍是 FAIL；Codex 仍是 UNEXECUTED；剩餘 budget 不重用。

拒絕 direct Git restore：

1. Claude 的 pre-unification commit 會丟失後續安全規則、routing、hooks 與 settings 修復。
2. Codex、Copilot 最早 commits 已帶 generated banner，沒有真正獨立版本可 restore。
3. attic 是歷史 carrier；舊 Codex override 曾遮蔽完整 AGENTS，舊 Copilot 文件仍可見互相矛盾的 CLAUDE inheritance／fallback 語意。
4. broad restore 會覆蓋目前三個 modified live files，違反 dirty-file preservation。

Ownership stage只以 **current live effective content** 為baseline，允許的變化只有：

- ownership／provenance banner；
- `.agents` global-config path 改為 host-local path；
- symlink materialization；
- generator coupling 移除。

該stage的安全規則、routing行為、workflow行為與有效body不得趁機修改。Workflow stage才可依§7.2 allowlist改成Matt thin architecture；Tier 0與所有機械gate須保持capability parity。

## 3. Target ownership matrix

| Surface | Claude owner | Codex owner | Copilot owner | Shared |
|---|---|---|---|---|
| Global instruction body | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.copilot/copilot-instructions.md` | none |
| Thin safety／workflow kernel | Claude-local files／section | `AGENTS.md` local section | `copilot-instructions.md` local section | `skills/dev-workflow`只承載shared kernel contract，不擁有host config |
| Routing | Claude-local section／file | Codex-local section | Copilot-local section | none |
| Stack rules | `~/.claude/rules/**` | `~/.codex/rules/**` | `~/.copilot/rules/**` | compatibility copies only under `.agents/rules` |
| Hooks | `~/.claude/hooks/**` | `~/.codex/hooks/**` | `~/.copilot/hooks/**` | none |
| Settings | `~/.claude/settings.json` | `~/.codex/config.toml` and app-local state | `~/.copilot/settings.json`／`config.json` | none |
| MCP／permissions | Claude-local files | Codex-local config | `mcp-config.json`／`permissions-config.json` | none |
| Plugins／cache／login | host-local；Superpowers absent | host-local；Superpowers absent | host-local；Superpowers absent | none |
| Tests | `~/.claude/tests/**` | `~/.codex/tests/**` | `~/.copilot/tests/**` | `.agents` tests skills visibility、Matt upstream immutability與thin-workflow parity |
| Skills | consumer via existing symlinks | native consumer | native consumer | `~/.agents/skills/**` only |

Target runtime flow：

```text
host-local thin routing／governance
  → shared Matt skill（needs／spec／implement／TDD／diagnosis／review）
  → shared thin kernel S4–S6
  → host-local hooks／permissions／PR-CI adapter
```

任何Matt orchestration都不能繞過最後一段；任何host也不得另存一份Matt skills或完整workflow copy。

Hard contracts：

1. 任何 active host global config 中，`.agents/` reference 只允許 `~/.agents/skills/**`。
2. `~/.agents/rules/**` 與 `~/.agents/docs/agents/issue-tracker.md` 可作 Matt／保留 skill 的 read-only compatibility carrier，但不得是 host global-config source。
3. `agents-sync` 不得讀、寫、生成、validate、hash、no-clobber-check 或 deploy 任何 host global config。
4. `.agents` global-config drift 不得讓任何 host session 失敗；host-local tests 各自負責。
5. 三家 rollback carrier 分開保存，但 partial failure 必須協調回滾，禁止留下 mixed ownership。
6. Active routing不得引用 `superpowers:*`或四支retired `mp-*`；`mp-zoom-out`是唯一保留的`mp-*`。
7. Matt `implement`完成後必須回到host-local kernel的S4–S6，不得自行commit或跳過verification／review／closeout。

## 4. Current dependency map

### 4.1 Claude

Verified current coupling：

- `~/.claude/core`：3 symlinks → `../../.agents/core/*`。
- `~/.claude/rules`：8 symlinks → `../../.agents/rules/*`。
- `~/.claude/skills`：72 active symlinks → `../../.agents/skills/*`。
- `~/.claude/hooks`：2 MCP patch symlinks → `../../.agents/hooks/*`。
- `CLAUDE.md` 指向 `.agents/core`、generated routing stamp、`.agents/rules/<stack>.md`。
- `settings.json` 的 SessionStart command 指向 `.agents/hooks/drift-check.sh`。
- `guard-git-push.sh` 是呼叫 `.agents/hooks/guard-git-push.sh` 的 thin wrapper。

### 4.2 Codex

Verified current coupling：

- `AGENTS.md` 有 `agents-sync` generated banner。
- `AGENTS.md` 指向 `.agents/rules/<stack>.md` 與 `.agents/skills/dev-workflow/SKILL.md`。
- `hooks.json` 指向 `.agents/hooks/guard-codex-git-push.sh` 與 `.agents/hooks/drift-check.sh`。
- `~/.codex/rules/default.rules` 已存在但未被 repo allowlist 追蹤。
- `config.toml`、auth、state、SQLite、sessions、cache、logs 依 `.gitignore` 保持 untracked／ignored。

### 4.3 Copilot

Verified current coupling：

- `copilot-instructions.md` 有 `agents-sync` generated banner。
- stack fallback 指向 `.agents/rules`。
- routing fallback 指向 `.agents/core/routing.md`。
- shared skill routing 指向 `.agents/skills`。
- `mcp-config.json`、`permissions-config.json` 已追蹤。
- `hooks/guard-git-push.{json,sh}` 已存在於 `.copilot`，目前未追蹤，且不依賴 `.agents`。
- `settings.json`、`config.json`、installed plugins、cache、login／DB／session state 皆在 `.copilot`，但屬 app/runtime state，不進 Git。

### 4.4 agents-sync

Verified current coupling：

- `TARGETS` 含 Codex 與 Copilot。
- deploy／check／doctor／manifest／source stamp 讀寫兩家 generated files。
- deploy 會刷新 Claude routing stamp。
- bootstrap 會重建 Claude core／rules／skills symlinks。
- doctor 驗 Claude core／routing、Codex／Copilot manifest 與三家 FP。

## 5. `.agents` active surfaces disposition

| Surface | Candidate implementation disposition | Live cutover disposition | Later retirement gate |
|---|---|---|---|
| Matt upstream skill files | **PRESERVE immutable** | 三家主要workflow source | 永不本機魔改；更新另走upstream-detection gate |
| `skills/dev-workflow/**` | ownership stage不變；workflow stage **THIN** | 只保留routing／authorization／S4–S6與host adapters | preserve as local kernel |
| `skills/mp-diagnose`、`mp-grill-with-docs`、`mp-improve-codebase-architecture`、`mp-tdd` | ownership stage不變；workflow stage逐支parity後 **RETIRE** | no active consumer | evidence保留舊hash，不保留active wrapper |
| `skills/mp-zoom-out` | **PRESERVE** | 無一對一replacement的本機skill | preserve |
| `core/**` | freeze；只作 before-body／rollback carrier | 不再被 host 讀取 | 三家 canary 全綠後才可提案移入 attic |
| `rules/**` | freeze；copy 到各 host；保留 compatibility paths | 不再是 host global-config source | 因保留skills仍引用，保持 read-only carrier |
| `docs/agents/issue-tracker.md` | freeze | Matt issue-tracker fallback carrier | preserve；禁止自動執行setup skill |
| `hosts/**` | freeze；不得再被 generator consume | no active consumer | 三家 canary 全綠後才可提案 `git mv` attic |
| `dist/**` | stop generating；manifest 不再 active | no active host contract | 三家 canary 全綠後才可提案 `git mv` attic |
| `hooks/guard-*.sh`、MCP patch hooks | copy exact behavior into host repos | no active host caller under `.agents` | 後續確認無 caller 才可 retire |
| `hooks/drift-check.sh` | replace with shared-skills-only check or retire call sites | 不驗 host global config | no caller 後可 attic |
| `hooks/post-checkout-agents.sh` | wording／checks 限縮到 shared skills | live main guard remains | preserve |
| `bin/agents-sync` | shrink to Claude skill-link bootstrap + three-host skill visibility／immutability checks only | no host global-config access | preserve minimum interface or rename only under later gate |
| `dist/manifest.tsv` | retire as active manifest；不得含 host target | no validation source | later attic |
| `doctor` | only skills source、Claude skill symlink、native discovery filesystem visibility | no host config health claim | preserve minimum checks |
| `bootstrap` | only rebuild Claude active skill symlinks | no core／rules symlink、no host deploy | preserve |
| `--deploy`／`--only` | fail-loud as retired interfaces | no writes | later remove under compatibility gate |
| `tests/conformance.sh` | remove live host mutation probes；delegate host config to host-local tests | `.agents` tests only shared skills | preserve |
| Phase 4 scripts／tests | immutable historical artifacts | no ownership role | no change；新combined canary另建，不改舊verdict |
| `README.md`／`CONVENTIONS.md` | document one skills plane + three control planes | source of current ownership rules | preserve |
| `bin/agents-branch`／branch hook docs | warn only about shared-skills branch visibility | live `.agents` stays main | preserve |

`agents-sync` 不需要新的 abstraction。保留既有 CLI entry point，刪除 host target loops 與 host-config branches；第一個能成立的 Ponytail rung 是「刪除 control-plane 行為，只保留 skills visibility」。

## 6. Per-host file disposition

### 6.1 Claude

| Path／group | Action | Rule |
|---|---|---|
| `CLAUDE.md` | **LOCALIZE + THIN** | ownership stage preserve effective body；workflow stage只留安全／routing／authorization／S4–S6／Claude adapter，移除已由Matt承接的method prose |
| `core/tier{0,1,2}-*.md` | **MATERIALIZE + RETIRE non-skill symlinks** | symlink → regular file；bytes 等於 split 前 symlink target，僅 metadata path可改 |
| `rules/*.md` | **MATERIALIZE + RETIRE non-skill symlinks** | 8 symlinks → regular files；bytes 等於 split 前 targets |
| `skills/*` | **PRESERVE** | 72 symlinks、mode、target exact unchanged |
| `hooks/patch-*-mcp.sh` | **MATERIALIZE** | 2 symlinks → regular executable files，effective bytes不變 |
| `hooks/guard-git-push.sh` | **LOCALIZE** | remove `.agents` wrapper call；materialize current guard behavior locally |
| `hooks/drift-check.sh` | **CREATE** | Claude-local config／symlink static check；不得呼叫 agents-sync host validation |
| `settings.json` | **LOCALIZE** | only SessionStart hook path changes；all other JSON paths／values exact |
| Superpowers plugin registration／runtime | **PLAN RETIREMENT** | candidate驗zero active refs與plugin-disabled shadow session；live removal另需明示授權，不假設未驗證config key |
| `tests/repo-integrity.sh` | **LOCALIZE** | assert local core/rules/hooks ownership and exact skill symlinks |
| agents、commands、templates、statusline、Playwright config | **PRESERVE** | no ownership-coupling change |
| `settings.local.json`、logs、cache、plugin runtime | **IGNORE AS RUNTIME/SECRET STATE** | keep ignored；never copy into Git/evidence |

### 6.2 Codex

| Path／group | Action | Rule |
|---|---|---|
| `AGENTS.md` | **LOCALIZE + THIN** | ownership stage remove generated banner／localize paths；workflow stage只留安全／routing／authorization／S4–S6／Codex adapter |
| `hooks.json` | **LOCALIZE** | only command paths change to `.codex/hooks/**` |
| `hooks/guard-codex-git-push.sh` | **MATERIALIZE** | copy current effective guard into Codex repo |
| `hooks/drift-check.sh` | **CREATE** | Codex-local AGENTS／hooks／rules check；no `.agents` global-config read |
| `hooks/audit-bash.sh`、`hooks/session-time.sh` | **PRESERVE** | no unrelated change |
| `rules/default.rules` | **PRESERVE + VERSION** | current native rule remains Codex-owned；secret scan before adding allowlist |
| `rules/*.md` | **MATERIALIZE** | local stack fallback copies from current `.agents/rules` |
| `tests/global-config-ownership.sh` | **CREATE** | local banner／path／hook／rules assertions |
| `.gitignore` | **LOCALIZE** | allow safe `rules/` and `tests/` only；keep runtime/secret denylist |
| `config.toml` | **IGNORE AS LOCAL CONFIG/STATE** | remains untracked；credential presence only set/unset |
| Superpowers plugin registration／runtime | **PLAN RETIREMENT** | candidate驗zero active refs與plugin-disabled shadow session；live removal另需明示授權，不改未追蹤credential／runtime state |
| auth、state、SQLite、history、sessions、cache、logs、plugins | **IGNORE AS RUNTIME/SECRET STATE** | never add、hash body、or print |
| agents、prompts、CI | **PRESERVE** | no unrelated change |

### 6.3 Copilot

| Path／group | Action | Rule |
|---|---|---|
| `copilot-instructions.md` | **LOCALIZE + THIN** | ownership stage remove generated banner／localize paths；workflow stage只留安全／routing／authorization／S4–S6／Copilot adapter |
| `rules/*.md` | **MATERIALIZE** | local stack fallback copies from current `.agents/rules` |
| `hooks/guard-git-push.{json,sh}` | **PRESERVE + VERSION** | already Copilot-local；add to allowlist after secret scan |
| `tests/global-config-ownership.sh` | **CREATE** | local banner／path／rules／hooks assertions |
| `mcp-config.json` | **PRESERVE** | already Copilot-owned；no key/value change |
| `permissions-config.json` | **PRESERVE** | already Copilot-owned；no change |
| `.gitignore` | **LOCALIZE** | allow safe `rules/`、`hooks/`、`tests/`；keep app/runtime state ignored |
| `settings.json`、`config.json` | **IGNORE AS APP-LOCAL STATE** | already Copilot-owned by location；do not version without separate audit |
| installed plugins、plugin-data、marketplace cache | **IGNORE AS HOST RUNTIME STATE** | no duplicate registry；no move／copy |
| Superpowers plugin registration／runtime | **PLAN RETIREMENT** | candidate驗zero active refs與plugin-disabled shadow session；live removal另需明示授權 |
| login、DB、chats、sessions、run tokens、cache | **IGNORE AS RUNTIME/SECRET STATE** | never add、hash body、or print |
| agents、prompts、empty instructions dir | **PRESERVE** | no unrelated change |

Planned new paths are explicitly marked CREATE／MATERIALIZE above；existence validation must require CREATE paths absent before implementation and present only in the correct isolated candidate after implementation.

## 7. Stage-scoped skills contract

### 7.1 Ownership stage — immutable

在 ownership commits A–E 完成前，`~/.agents/skills/**` 維持 byte-for-byte immutable：

- no edit；
- no move／rename；
- no regenerate；
- no new copy or second registry；
- no mode or symlink-target change；
- no Git history rewrite。

Planning before manifest：

- path：`/private/tmp/three-host-global-config-split-skills-before.tsv`
- columns：relative path、file type、SHA-256、size、mode、symlink target
- rows：662 including header
- SHA-256：`f7a3595ed6cbe8ff691fc094438aaed48e0cb8fdaa04b3a87a4c1a1ba37da12b`

原始662-row manifest保持歷史audit evidence，不覆寫或擴大baseline。Blocker reconciliation只將 exact relative path `.DS_Store` 從 semantic skills payload gate 分離：

```bash
awk -F '\t' 'NR == 1 || $1 != ".DS_Store"' "$SKILLS_BEFORE" > "$SEMANTIC_SKILLS_BEFORE"
awk -F '\t' 'NR == 1 || $1 != ".DS_Store"' "$OWNERSHIP_SKILLS_AFTER" > "$SEMANTIC_SKILLS_AFTER"
diff -u "$SEMANTIC_SKILLS_BEFORE" "$SEMANTIC_SKILLS_AFTER"
```

Expected：semantic diff empty。禁止 `*.DS_Store`、hidden-file wildcard與directory-wide exclusion；nested `.DS_Store`與所有其他hidden files仍是semantic payload。

Exact `.DS_Store`另以單一metadata row監看，不讀body、不改live file：

```text
.DS_Store	file	abac08d6445bcc8848a10a5e0e2a406629d2dea627e500c8e6006f720a647606	57348	644	-
```

驗證必須要求relative path exact、row count = 1、type／SHA-256／size／mode／symlink target exact。metadata再次變動、row缺失／重複或任何其他skills drift均FAIL；不得自行rebaseline。

### 7.2 Workflow stage — exact allowlist

只有下列本機-owned paths可變：

| Path | Allowed change |
|---|---|
| `skills/dev-workflow/**` | 瘦成S0 routing、S2 authorization、S4–S6 evidence／review／closeout、BUGFIX red→green與三家host adapters |
| `skills/mp-diagnose/**` | parity evidence後retire |
| `skills/mp-grill-with-docs/**` | parity evidence後retire |
| `skills/mp-improve-codebase-architecture/**` | parity evidence後retire |
| `skills/mp-tdd/**` | parity evidence後retire；micro-refactor規則移入kernel |
| active local skill cross-references found by preflight `rg` | 只把retired `mp-*`／`superpowers:*`引用改到已驗證的新capability；逐path列入implementation evidence |
| tests／routing metadata directly asserting上述contract | RED→GREEN所需最小變更 |

以下保持 immutable：

- Matt upstream skill files與其references／scripts／templates；
- `skills/mp-zoom-out/**`；
- 其他未列入implementation evidence的skill；
- Phase 4 historical artifacts；
- Git history不得rewrite。

Workflow stage必須建立 allowlist manifest，並要求 non-allowlisted diff empty；不能再用全skills empty diff假綠。

### 7.3 Compatibility carriers

| Skill file | Required compatibility carrier |
|---|---|
| Matt issue-tracker consumers | `~/.agents/docs/agents/issue-tracker.md` |
| `skills/typescript-best-practices/references/config-and-project.md` | `~/.agents/rules/typescript.md` |
| `skills/vue-best-practices/references/styling-and-ui.md` | `~/.agents/rules/frontend-spa.md` |

這三個 carrier 保持 current path、bytes、mode，且標記為 read-only compatibility。Host global config不得引用；只有shared skill在on-demand執行時可讀。`setup-matt-pocock-skills`仍禁止自動執行。

## 8. Ownership equivalence + workflow capability parity

### 8.1 General normalization

Ownership stage對每個 host建private before／after body：

1. before 取 **live effective bytes**，不是舊 commit。
2. after 取 isolated host candidate。
3. normalize only：
   - generated／ownership banner；
   - provenance comment；
   - `.agents/core|rules|hooks` → corresponding host-local path；
   - symlink path type → regular file。
4. `cmp -s` normalized before／after。
5. 任一其他差異立即 FAIL，不合理化為 cleanup。

不得把 full diff body寫入 evidence；只記 command、exit code、hash、path 與 allowed-difference class。

Workflow stage不再要求全文等價；改要求：

1. Tier 0、plan-first、RED→GREEN、S4–S6、PR／CI與rollback rule逐項存在。
2. Matt capability mapping逐項有active route與callable skill。
3. `implement`明文回到kernel S4–S6。
4. active refs中的`superpowers:*`與四支retired `mp-*`為零。
5. host-local instruction body只含thin kernel／adapter；method prose不重複。
6. 每個刪除的legacy capability都有parity evidence或明確rollback carrier。

### 8.2 Claude

- ownership stage的`CLAUDE.md` normalized body exact；workflow stage另做thin-kernel contract diff。
- 3 core targets：materialized file SHA 等於 split 前 symlink target SHA。
- 8 rules targets：materialized file SHA 等於 split 前 symlink target SHA。
- 2 MCP patch hooks：materialized SHA／mode 等於 split 前 target。
- 72 skill symlinks：path／mode／target exact。
- `settings.json`：`jq -S` 結構比較，只允許 SessionStart command path變更。

### 8.3 Codex

- ownership stage的`AGENTS.md`去除line 1 generated banner後，normalize allowed local paths，body exact；workflow stage另做thin-kernel contract diff。
- `hooks.json`：只允許兩個 command path由 `.agents/hooks` 改為 `.codex/hooks`。
- guard behavior跑 current shared test vectors與 Codex-local tests，結果 exact。
- native `default.rules` bytes先保存，candidate不得順手改 approval policy。

### 8.4 Copilot

- ownership stage的`copilot-instructions.md`去除generated banner後，normalize stack/routing local paths，body exact；workflow stage另做thin-kernel contract diff。
- `mcp-config.json`、`permissions-config.json` SHA exact。
- existing local guard files SHA exact，除非另有 RED test證明必要修正；本 split不包含 guard refactor。
- runtime settings／plugins只驗 path ownership與 Git ignore，不讀 secret values。

## 9. Dirty-file preservation

Live cutover前，對三個 modified files各建 mode 0600 private byte-for-byte backup：

- `~/.claude/settings.json`
- `~/.codex/AGENTS.md`
- `~/.copilot/copilot-instructions.md`

Rules：

1. verify exact preflight hash／size／mode；
2. backup directory mode 0700，files mode 0600；
3. record only metadata；
4. candidate以 live bytes為 before baseline；
5. 不用 `git restore`、checkout、reset或舊 commit覆蓋；
6. stage前跑 gitleaks，若疑似 secret只回報 `set` 並停止；
7. cutover用 same-directory temp + atomic rename；
8. partial failure從 private carrier exact restore，並驗 hash／size／mode。

若任一 hash與 §1.5 不同，停止；不得自行擴大 baseline。

## 10. RED regression specification

先在 isolated `.agents` implementation candidate新增ownership contract test：

`tests/three-host-global-config-ownership.sh`

RED 順序：

1. 先 assert current `agents-sync` 仍含 Codex／Copilot TARGETS；預期 non-zero，root failure：

   ```text
   FAIL: agents-sync still owns host global config
   ```

2. commit RED test only；feature branch可用 `[wip]`，不得 push／merge。
3. ownership GREEN後再新增workflow RED；不得把兩個stage藏在同一commit。

Minimum assertions：

1. `agents-sync` source沒有 `.codex/AGENTS.md`、`.copilot/copilot-instructions.md`、Claude core/rules/routing stamp或 host TARGETS。
2. `--check`、`--doctor`、`--bootstrap`、default、`--deploy`、`--only` 均不讀寫 host global config；retired interfaces fail-loud。
3. scratch host global config設為 unreadable sentinel時，skills-only modes仍成功且 metadata unchanged。
4. active host global config中的 `.agents/` refs只允許 `skills/`。
5. Claude core／rules／hooks沒有 `.agents` symlink；skills symlinks exact unchanged。
6. Codex／Copilot generated banner不存在。
7. Codex／Copilot local stack fallback存在且不指向 `.agents/rules`。
8. `.agents` active manifest沒有 host global-config row。
9. ownership stage semantic skills before／after manifest empty diff；只允許exact `.DS_Store`使用獨立pinned metadata row。
10. 三個 compatibility carriers仍存在且 metadata exact。
11. Phase 4 historical hashes exact。
12. live four-repo fingerprints與porcelain exact unchanged during candidate implementation。

Host-local RED tests：

- Claude `tests/repo-integrity.sh` 先證 current core/rules/hooks ownership FAIL。
- Codex `tests/global-config-ownership.sh` 先證 current banner／hook paths FAIL。
- Copilot `tests/global-config-ownership.sh` 先證 current banner／fallback paths FAIL。

Workflow-stage RED test：

`tests/matt-thin-workflow.sh`

Minimum assertions：

1. thin kernel只保留routing／authorization／risk、RED→GREEN、S4–S6與host adapters。
2. `grilling`、`domain-modeling`、`to-spec`、`to-tickets`、`implement`、`tdd`、`diagnosing-bugs`、`code-review`、`codebase-design`、`wayfinder`均可由active routing到達。
3. `implement` route明文返回S4–S6，且禁止直接commit current／main branch。
4. active config與active skills中的`superpowers:*`引用為零。
5. `mp-diagnose`、`mp-grill-with-docs`、`mp-improve-codebase-architecture`、`mp-tdd`不存在於active inventory或routing。
6. `mp-zoom-out`仍存在且只在其明確scope觸發。
7. Matt upstream manifest exact unchanged。
8. non-allowlisted shared-skills diff empty。
9. 三家candidate active refs為零；offline runtime no-load無safe shadow seam時保留per-host `UNAVAILABLE`，不得假綠或改寫成歷史`PASS`。runtime no-load只在cutover transaction內逐host驗證。
10. Phase 4 historical evidence與live four-repo fingerprints仍exact unchanged。

Blocker-reconciliation amendment使用同一個`tests/three-host-global-config-ownership.sh` seam：

1. RED：current full-manifest comparator因known `.DS_Store` drift失敗；未修訂Plan時new contract assertions亦失敗。
2. GREEN：synthetic manifests證明known exact row reconciliation PASS，而metadata drift、nested `.DS_Store`與其他semantic drift各自FAIL。
3. GREEN：Plan contract要求Claude → Codex → Copilot逐hostabsence PASS才前進，任一FAIL／UNAVAILABLE進coordinated rollback，6-run canary仍獨立授權。
4. Candidate-only GREEN只證明manifest與transaction contract；不得宣稱fresh plugin absence、live cutover或SaaS PASS。

## 11. Minimal GREEN tasks and commit boundaries

### Commit A — RED contract

Repo：isolated `.agents` implementation branch。

**Files:**

- Create: `tests/three-host-global-config-ownership.sh`
- Verify unchanged: `skills/**`

**Interfaces:**

- Consumes: current `bin/agents-sync` behavior and §10 contracts.
- Produces: one executable ownership regression suite used by Commit E.

- [ ] **Step A1: Write the root RED assertion**

  Add a first assertion that exits non-zero while current `TARGETS` still owns Codex or Copilot global config. The first failure text is exactly:

  ```text
  FAIL: agents-sync still owns host global config
  ```

- [ ] **Step A2: Add the remaining scratch-only assertions**

  Encode all twelve assertions from §10; use `mktemp -d`, a cleanup trap, unreadable host-config sentinels, metadata-only comparisons and the ownership-stage immutable skills manifest.

- [ ] **Step A3: Run RED**

  ```bash
  bash tests/three-host-global-config-ownership.sh
  ```

  Expected: non-zero with the exact root failure above, before downstream assertions.

- [ ] **Step A4: Verify scope**

  ```bash
  git status --short
  git diff --check
  ```

  Expected: only the test file is new; diff check exits 0.

- [ ] **Step A5: Commit RED**

Commit：

```text
test(workflow): [wip] 鎖定三家設定 ownership
```

### Commit B — Claude candidate

Repo：isolated `~/.claude` worktree。

**Files:**

- Modify: `CLAUDE.md`
- Modify: `settings.json`
- Replace symlinks with regular files: `core/tier0-safety.md`, `core/tier1-workflow.md`, `core/tier2-style.md`
- Replace symlinks with regular files: `rules/cookbook.md`, `rules/cpp.md`, `rules/dotnet.md`, `rules/frontend-spa.md`, `rules/infra.md`, `rules/testing.md`, `rules/typescript.md`, `rules/winforms.md`
- Replace symlinks with regular files: `hooks/patch-chrome-devtools-mcp.sh`, `hooks/patch-playwright-mcp.sh`
- Modify: `hooks/guard-git-push.sh`
- Create: `hooks/drift-check.sh`
- Modify: `tests/repo-integrity.sh`
- Verify unchanged: `skills/*`

**Interfaces:**

- Consumes: live effective Claude bytes and the exact current symlink targets.
- Produces: Claude-local instruction／core／rules／hooks plus unchanged shared-skill links.

- [ ] **Step B1: Capture private before evidence**

  Hash `CLAUDE.md`, `settings.json`, core/rules/hook targets and the 72 skill links without printing file bodies.

- [ ] **Step B2: Make Claude ownership test RED**

  Add assertions to `tests/repo-integrity.sh` for no `.agents` core/rules/hooks symlinks, local SessionStart path and exact skill targets; run it and require non-zero on current candidate baseline.

- [ ] **Step B3: Materialize symlink targets**

  Replace only the named core/rules/MCP hook symlinks with regular files containing the exact target bytes and matching executable modes where applicable.

- [ ] **Step B4: Localize remaining paths**

  Update `CLAUDE.md`, `settings.json`, `guard-git-push.sh`; add the local drift check. Do not alter other JSON paths or instruction body.

- [ ] **Step B5: Verify GREEN and equivalence**

  ```bash
  bash tests/repo-integrity.sh
  jq empty settings.json
  bash -n hooks/*.sh tests/repo-integrity.sh
  git diff --check
  ```

  Expected: all exit 0; normalized body and materialized target comparisons are exact; ownership-stage skills manifest diff is empty.

- [ ] **Step B6: Commit Claude candidate**

Commit：

```text
refactor(claude): 分離全域設定 ownership
```

### Commit C — Codex candidate

Repo：isolated `~/.codex` worktree。

**Files:**

- Modify: `.gitignore`
- Modify: `AGENTS.md`
- Modify: `hooks.json`
- Create: `hooks/guard-codex-git-push.sh`
- Create: `hooks/drift-check.sh`
- Add current file after secret scan: `rules/default.rules`
- Create: `rules/cookbook.md`, `rules/cpp.md`, `rules/dotnet.md`, `rules/frontend-spa.md`, `rules/infra.md`, `rules/testing.md`, `rules/typescript.md`, `rules/winforms.md`
- Create: `tests/global-config-ownership.sh`

**Interfaces:**

- Consumes: live effective Codex AGENTS, current shared guard behavior and current stack rules.
- Produces: Codex-local instructions／hooks／rules with shared skills discovery unchanged.

- [ ] **Step C1: Capture private before evidence**

  Hash `AGENTS.md`, `hooks.json`, `rules/default.rules`; record config／credential presence only as set/unset.

- [ ] **Step C2: Write and run Codex RED**

  Test the current generated banner, `.agents/hooks` commands and `.agents/rules` fallback; require non-zero before implementation.

- [ ] **Step C3: Localize instructions and hooks**

  Remove only the generated banner, change only allowed paths, materialize current guard behavior and add the local drift check.

- [ ] **Step C4: Localize rules and allowlist**

  Copy current stack-rule bytes, add safe `rules/` and `tests/` allowlist entries, and stage `default.rules` only after gitleaks passes.

- [ ] **Step C5: Verify GREEN and equivalence**

  ```bash
  bash tests/global-config-ownership.sh
  jq empty hooks.json
  bash -n hooks/*.sh tests/global-config-ownership.sh
  git diff --check
  ```

  Expected: all exit 0; normalized AGENTS body exact; only the two hook command paths change in `hooks.json`; native approval bytes exact.

- [ ] **Step C6: Commit Codex candidate**

Commit：

```text
refactor(codex): 分離全域設定 ownership
```

### Commit D — Copilot candidate

Repo：isolated `~/.copilot` worktree。

**Files:**

- Modify: `.gitignore`
- Modify: `copilot-instructions.md`
- Add current files after secret scan: `hooks/guard-git-push.json`, `hooks/guard-git-push.sh`
- Create: `rules/cookbook.md`, `rules/cpp.md`, `rules/dotnet.md`, `rules/frontend-spa.md`, `rules/infra.md`, `rules/testing.md`, `rules/typescript.md`, `rules/winforms.md`
- Create: `tests/global-config-ownership.sh`
- Verify unchanged: `mcp-config.json`, `permissions-config.json`

**Interfaces:**

- Consumes: live effective Copilot instructions, existing local hooks and current stack rules.
- Produces: Copilot-local instructions／rules／hooks while native shared-skill discovery remains unchanged.

- [ ] **Step D1: Capture private before evidence**

  Hash instructions, hooks, MCP and permissions; report app settings／login／plugin state only as present or absent.

- [ ] **Step D2: Write and run Copilot RED**

  Test the current generated banner and `.agents/core|rules` fallbacks; require non-zero before implementation.

- [ ] **Step D3: Localize instructions and stack rules**

  Remove only the generated banner, replace only allowed fallback paths, preserve embedded routing and materialize exact stack-rule bytes.

- [ ] **Step D4: Version safe existing hooks**

  Add only the two existing guard files and narrow `.gitignore` allowlist entries; do not add settings、login、DB、plugin or cache state.

- [ ] **Step D5: Verify GREEN and equivalence**

  ```bash
  bash tests/global-config-ownership.sh
  jq empty hooks/guard-git-push.json mcp-config.json permissions-config.json
  bash -n hooks/guard-git-push.sh tests/global-config-ownership.sh
  git diff --check
  ```

  Expected: all exit 0; normalized instruction body exact; MCP／permissions hashes exact.

- [ ] **Step D6: Commit Copilot candidate**

Commit：

```text
refactor(copilot): 分離全域設定 ownership
```

### Commit E — `.agents` skills-only GREEN

Repo：same isolated `.agents` implementation branch。

**Files:**

- Modify: `bin/agents-sync`
- Modify: `README.md`
- Modify: `CONVENTIONS.md`
- Modify: `bin/agents-branch`
- Modify: `hooks/post-checkout-agents.sh`
- Modify: `hooks/drift-check.sh`
- Modify: `tests/conformance.sh`
- Test: `tests/three-host-global-config-ownership.sh`
- Preserve: `skills/**`, three compatibility carriers, Phase 4 artifacts

**Interfaces:**

- Consumes: Commit A regression suite and final Claude/Codex/Copilot candidate metadata.
- Produces: skills-only `agents-sync` interface with no host global-config access.

- [ ] **Step E1: Delete host control-plane code**

  Remove TARGETS、render、deploy、manifest、routing-stamp and host-global doctor logic. Keep one existing CLI entry point; do not add a replacement framework.

- [ ] **Step E2: Keep minimum skills interface**

  `--bootstrap` manages only Claude active skill symlinks；`--check`／`--doctor` check skills source／visibility；default、`--deploy`、`--only` fail-loud without touching host config.

- [ ] **Step E3: Update active docs and branch/conformance wording**

  Document one shared skills plane、three host control planes and read-only compatibility carriers. Remove the live Codex file-move probe from conformance.

- [ ] **Step E4: Run GREEN**

  ```bash
  bash tests/three-host-global-config-ownership.sh
  AGENTS_HOME="$PWD" bash tests/agents-branch.sh
  bash tests/legacy-mp-collision.sh
  bash tests/mattpocock-workflow.sh
  bash tests/vendored-detection.sh
  bash tests/version-tripwire.sh
  ```

  Expected: all exit 0 and no live host path write.

- [ ] **Step E5: Verify immutable and historical diffs**

  ```bash
  diff -u "$SEMANTIC_SKILLS_BEFORE" "$SEMANTIC_SKILLS_AFTER"
  cmp -s "$DS_STORE_METADATA_BASELINE" "$DS_STORE_METADATA_AFTER"
  diff -u "$HISTORICAL_BEFORE" "$HISTORICAL_AFTER"
  diff -u "$LIVE_BEFORE" "$LIVE_AFTER"
  git diff --check
  ```

  Expected: all exit 0；semantic、historical、live diff empty，exact `.DS_Store` metadata row unchanged。

- [ ] **Step E6: Commit `.agents` GREEN**

Commit：

```text
refactor(workflow): 收斂為共享 skills data plane
```

### Commit F — workflow RED contract

Repo：same isolated `.agents` implementation branch。

**Files:**

- Create: `tests/matt-thin-workflow.sh`
- Verify unchanged: Matt upstream files、Phase 4 artifacts、live repos

- [ ] **Step F1: Inventory exact active dependencies**

  用`rg`列出active `superpowers:*`、四支retired `mp-*`與kernel prose consumers；排除proposals／attic／backups／historical tests。把exact path allowlist寫入private evidence，不猜測未驗證path。

- [ ] **Step F2: Write workflow RED**

  Encode §10 workflow-stage assertions。第一個root failure必須對應目前仍存在的legacy wrapper或non-thin kernel，且在任何GREEN edit前non-zero。

- [ ] **Step F3: Run and commit RED**

  ```bash
  bash tests/matt-thin-workflow.sh
  git diff --check
  ```

  Expected：test non-zero、diff check exit 0。

Commit：

```text
test(workflow): [wip] 鎖定 Matt 薄型流程
```

### Commit G — shared Matt workflow GREEN

Repo：same isolated `.agents` implementation branch。

**Files:**

- Modify: `skills/dev-workflow/**`
- Retire after parity evidence: `skills/mp-diagnose/**`、`skills/mp-grill-with-docs/**`、`skills/mp-improve-codebase-architecture/**`、`skills/mp-tdd/**`
- Preserve: `skills/mp-zoom-out/**`
- Modify only preflight-listed active local cross-references and directly affected tests／routing metadata
- Preserve: all Matt upstream files

- [ ] **Step G1: Capture per-wrapper parity**

  逐支比較local-only references／scripts與replacement；任何獨有capability未有新載體就停止，不刪該wrapper。Canary常見路徑等價不能取代此static diff。

- [ ] **Step G2: Re-home Superpowers capabilities**

  將verification／branch finishing／delegation／worktree isolation／skill-writing依賴放入thin kernel、host adapter或已存在Matt skill；不得新增第三套workflow framework。

- [ ] **Step G3: Thin the kernel**

  `dev-workflow`只保留S0 routing、S2 authorization、BUGFIX red→green、S4–S6 evidence／review／closeout與host adapters；需求、spec、implementation、TDD、diagnosis、review方法route到Matt skills。

- [ ] **Step G4: Retire legacy wrappers**

  只在G1每支PASS後退休四支wrapper；`mp-zoom-out`保持exact。更新active references，不改historical evidence。

- [ ] **Step G5: Run GREEN**

  ```bash
  bash tests/matt-thin-workflow.sh
  bash tests/legacy-mp-collision.sh
  bash tests/mattpocock-workflow.sh
  bash tests/vendored-detection.sh
  bash tests/version-tripwire.sh
  git diff --check
  ```

  Expected：all exit 0；Matt upstream manifest與non-allowlisted skills diff empty。

- [ ] **Step G6: Commit shared workflow**

Commit：

```text
refactor(workflow): 切換 Matt 薄型流程
```

### Commits H1–H3 — per-host thin adapters

Repos：isolated Claude、Codex、Copilot candidates；每host獨立commit與verdict。

- [ ] **Step H1: Thin host instruction body**

  在ownership-localized file上只保留Tier 0、routing／authorization、plan gate、S4–S6與host adapter；不複製Matt method prose。

- [ ] **Step H2: Remove active legacy references**

  Active config不得再引用`superpowers:*`或四支retired `mp-*`；shared skill root仍指向`~/.agents/skills`。

- [ ] **Step H3: Build plugin-disabled shadow probe**

  Implementation preflight先以host-native read-only inventory解析實際plugin source／supported isolation seam。只在temporary HOME／candidate overlay測試，不改live registration、runtime、cache或credential；找不到safe offline seam即保留該host `UNAVAILABLE`，不得改寫成`PASS`。

  Pre-cutover gate改驗每host active refs = 0、verified removal interface、exact restore carrier與maintenance quiescence。不得把 pre-cutover `UNAVAILABLE` 改寫成 `PASS`；它只是不再要求用不存在的offline seam證明runtime no-load。

- [ ] **Step H4: Verify per host**

  跑host-local ownership test、thin-kernel test、config parser、shell syntax、secret scan與plugin-disabled shadow inventory。三家各自PASS，不合併推論。

- [ ] **Step H5: Commit per host**

Commits：

```text
refactor(claude): 切換 Matt 薄型流程
refactor(codex): 切換 Matt 薄型流程
refactor(copilot): 切換 Matt 薄型流程
```

### Commit I — candidate evidence

Only after A–H final HEADs全部綠，新增一份 implementation evidence，記錄：

- four candidate HEADs；
- RED→GREEN；
- equivalence hashes；
- ownership immutable manifest、workflow allowlist manifest與Matt upstream immutable manifest；
- legacy wrapper per-item parity／retirement verdict；
- three-host plugin-disabled shadow verdicts；
- per-repo validation；
- live fingerprints unchanged；
- live cutover與plugin實際卸載仍未授權。

**Files:**

- Create: `proposals/2026-07-27-mattpocock-skills-workflow/49-three-host-global-config-ownership-split-candidate-evidence.md`

**Interfaces:**

- Consumes: final four candidate HEADs and all local verification outputs.
- Produces: final-architecture candidate implementation handoff; no live state change.

- [ ] **Step I1: Re-run full verification on final HEADs**

  Do not reuse pre-commit outputs.

- [ ] **Step I2: Write metadata-only evidence**

  Include commands、exit codes、hashes、per-host verdicts、rollback carriers and the one live-cutover authorization gate；exclude config bodies and secrets.

- [ ] **Step I3: Run closeout checks**

  Run Markdown structure、placeholder、path、commit、gitleaks、diff and clean-status gates.

- [ ] **Step I4: Commit evidence**

Commit：

```text
docs(workflow): 記錄三家 ownership candidate 證據
```

不新增 generator framework、policy engine、second registry、dependency 或 speculative abstraction。

## 12. Candidate-only verification

所有 commands只可在四個 isolated candidates或 `mktemp -d` scratch執行。

### 12.1 Static and format

Resolve actual candidate paths from Git metadata first：

```bash
resolve_worktree() {
  git -C "$1" worktree list --porcelain |
    awk -v ref="refs/heads/$2" '
      /^worktree / { path=substr($0, 10) }
      $0=="branch " ref { print path }
    '
}
CLAUDE_CANDIDATE="$(resolve_worktree "$HOME/.claude" codex/three-host-global-config-split-claude)"
CODEX_CANDIDATE="$(resolve_worktree "$HOME/.codex" codex/three-host-global-config-split-codex)"
COPILOT_CANDIDATE="$(resolve_worktree "$HOME/.copilot" codex/three-host-global-config-split-copilot)"
test -n "$CLAUDE_CANDIDATE"
test -n "$CODEX_CANDIDATE"
test -n "$COPILOT_CANDIDATE"
```

```bash
git diff --check
bash -n bin/agents-sync hooks/*.sh tests/*.sh
jq empty "$CODEX_CANDIDATE/hooks.json"
jq empty "$COPILOT_CANDIDATE/mcp-config.json"
jq empty "$COPILOT_CANDIDATE/permissions-config.json"
```

每個 JSON path先用 `test -f`解析；planned CREATE path在對應 candidate建立前不得假設存在。

### 12.2 Ownership tests

```bash
bash tests/three-host-global-config-ownership.sh
bash tests/matt-thin-workflow.sh
bash "$CLAUDE_CANDIDATE/tests/repo-integrity.sh"
bash "$CODEX_CANDIDATE/tests/global-config-ownership.sh"
bash "$COPILOT_CANDIDATE/tests/global-config-ownership.sh"
```

Implementation session必須由`agents-branch`或`git worktree list --porcelain`解析實際path，不得自行拼接或假設。

### 12.3 Existing `.agents` contracts

Applicable existing tests：

```bash
AGENTS_HOME="$PWD" bash tests/agents-branch.sh
bash tests/legacy-mp-collision.sh
bash tests/mattpocock-workflow.sh
bash tests/vendored-detection.sh
bash tests/version-tripwire.sh
```

`tests/conformance.sh` 必須先改為 scratch／skills-only，禁止再移走 live `~/.codex/AGENTS.md`。

### 12.4 Equivalence and immutability

```bash
cmp -s "$OWNERSHIP_NORMALIZED_BEFORE" "$OWNERSHIP_NORMALIZED_AFTER"
diff -u "$SEMANTIC_SKILLS_BEFORE" "$SEMANTIC_SKILLS_AFTER"
cmp -s "$DS_STORE_METADATA_BASELINE" "$DS_STORE_METADATA_AFTER"
diff -u "$MATT_UPSTREAM_BEFORE" "$MATT_UPSTREAM_AFTER"
diff -u "$NON_ALLOWLIST_SKILLS_BEFORE" "$NON_ALLOWLIST_SKILLS_AFTER"
diff -u "$HISTORICAL_BEFORE" "$HISTORICAL_AFTER"
diff -u "$LIVE_BEFORE" "$LIVE_AFTER"
```

Expected：all exit 0 and empty diff；workflow allowlist diff另逐path對照§7.2與implementation evidence。

### 12.5 Security and repository state

```bash
gitleaks detect --source . --no-banner
git status --porcelain=v1 -uall
```

每個 candidate最後必須 clean。DCT build／test／MySQL E2E：SKIPPED，因為這是 machine-local workflow config migration，沒有改 DCT runtime。

ShellCheck若未安裝標 `UNAVAILABLE`並附 `command -v shellcheck`結果；不得假綠。

## 13. Coordinated live cutover

本節是 future runbook，不是本 session授權。

Pre-cutover仍須逐host保持active refs = 0、verified removal interface、exact restore carrier與maintenance quiescence。三host offline runtime no-load verdict仍是`UNAVAILABLE`，不得改寫成歷史`PASS`；實際plugin absence只在另行授權的transaction內取得。

固定順序：

1. revalidate four live repos exact HEAD／porcelain／critical hashes；
2. 建四 repo private byte-for-byte backup與Git/fingerprint baseline；
3. verify four final-architecture isolated candidates、Matt upstream manifest與exact implementation evidence；
4. 進入maintenance window：禁止啟動三家新session，直到step 10完成或coordinated rollback結束；
5. 先停用 `.agents` 對任何 host global config 的 write／validation；
6. 以候選commits部署shared Matt workflow與三家thin config；transaction內不得啟動host session；
7. 依Claude → Codex → Copilot固定順序，用已驗證的host-native機制退休Superpowers registration；每家立即跑local static／guard／config verification與該host plugin inventory，確認Superpowers absent為PASS後才可進下一host；尚不做SaaS/context probe；
8. verify active host config中的 `.agents/`只剩skills refs，active routing中的`superpowers:*`與四支retired `mp-*`為零，`mp-zoom-out`保留；
9. verify Claude、Codex、Copilot各自保有獨立plugin-absence evidence；任一host FAIL／UNAVAILABLE立即停止後續writes／probes並執行coordinated rollback，禁止用某host結果推論其他host；
10. 結束maintenance window，依§15 fixed order執行separately authorized fresh context／skill canaries；
11. 三家全綠前保留 `.agents/core|rules|hooks|hosts|dist`與三家plugin restore rollback carriers；
12. 三家全綠後才提出old control-plane carrier retirement gate。

不得先移除 generated banner再讓舊 `agents-sync`繼續 no-clobber；步驟 5 必須先於 6–7。

## 14. Rollback

### 14.1 Per-host carriers

每家都有獨立 mode 0700 backup directory與 mode 0600 file carriers：

- Claude：CLAUDE、settings、core、rules、hooks、skill symlink manifest。
- Codex：AGENTS、hooks.json、hooks、rules、native approval rule。
- Copilot：instructions、rules、hooks、MCP、permissions。
- 每host另保存可驗證的Superpowers registration／version restore carrier；只記metadata，credential只報set／unset。
- `.agents`：agents-sync、manifest、core、rules、hosts、dist、hooks、tests、docs、pre-migration shared-skills tree manifest與Git commit。

### 14.2 Coordinated rollback rule

任何 host FAIL／UNAVAILABLE：

1. stop all further writes and probes；
2. mark overall cutover FAIL；
3. rollback every already-activated host and `.agents` to pre-cutover ownership；
4. use `git revert` for committed control-plane／shared-workflow changes；
5. use private exact-byte carriers for the three pre-existing dirty files；
6. atomic restore path、hash、size、mode；
7. rerun old local verification；
8. restore each host Superpowers registration only from its own verified carrier；
9. require all four repos、three plugin inventories與shared skills return exact pre-cutover baseline。

禁止只回滾失敗 host而留下其他 host在新 ownership，亦禁止只回滾 `.agents`或只回滾單側 host。Rollback是 coordinated transaction；per-host carrier只是縮小還原範圍，不代表允許 mixed ownership。

Planning rollback：`git revert`本 planning commit。Candidate implementation rollback：各 repo scoped `git revert`；不得 force push或 hard reset。

## 15. Context／skill canary budget proposal

本 session不執行。Future live cutover需 fresh explicit budget：

| Order | Host | Canary | Runs |
|---:|---|---|---:|
| 1 | Claude | thin global context／Superpowers absent | 1 |
| 2 | Claude | shared Matt route + kernel S4–S6 return | 1 |
| 3 | Codex | thin global context／Superpowers absent | 1 |
| 4 | Codex | shared Matt route + kernel S4–S6 return | 1 |
| 5 | Copilot | thin global context／Superpowers absent | 1 |
| 6 | Copilot | shared Matt route + kernel S4–S6 return | 1 |

Total：6；Claude 2、Codex 2、Copilot 2；retry 0；review carrier 0；fixed serial order；first FAIL／UNAVAILABLE立即停止。

每host獨立verdict；thin-global canary不得推論shared-workflow canary，shared-workflow canary不得推論global config／plugin absence。這是全新final-architecture budget，不得使用Phase 4剩餘budget或歷史attempt。

## 16. Historical immutability

Candidate implementation前後都要 hash並要求 exact：

- Plan 45；
- Evidence 47；
- Phase 4 matrix／schema／waiver／exception／attempt／FAIL／terminal evidence；
- `proposals/2026-07-27-mattpocock-skills-workflow/23-*`、`26-*`、`27-*`、`29-*` through `47-*`；
- `bin/phase4-canary-launcher`、`bin/phase4-canary-harness`；
- `tests/phase4-canary-launcher.sh`、`tests/phase4-canary-harness.sh`；
- commits `2ee7315`、`ea32d48`、`ab9b538`；
- historical host commits與attic carriers in §1.6；
- existing rollback carriers。

Planning before manifest：

- path：`/private/tmp/three-host-global-config-split-historical-before.tsv`
- rows：78 including header
- SHA-256：`6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf`

不得改寫 Stage 2 FAIL、Codex UNEXECUTED、Copilot EXCLUDED、attempt count、budget或rollback evidence。

## 17. M0–M5 impact

| Milestone | Status／impact |
|---|---|
| M0 | COMPLETE；legacy routing-collision結果不變 |
| M1 | Phase 4 Stage 2仍FAIL；Codex UNEXECUTED；evidence frozen；不重用budget。舊Arm A/B不是final ownership architecture的release gate |
| Ownership split amendment | 本文件supersedes Plan 45 ownership design；candidate implementation另行授權，live cutover仍獨立 |
| M2 | **FOLDED INTO CANDIDATE**；逐支parity後退休四支legacy `mp-*`，保留`mp-zoom-out` |
| M3 | **FOLDED INTO CANDIDATE + LIVE GATE**；candidate完成zero-reference／plugin-disabled驗證，實際逐host卸載只在live cutover明示授權後 |
| M4 | PENDING；upstream detection只看 shared skills lock，與host global config分離 |
| M5 | **FOLDED INTO CANDIDATE**；thin-kernel驗收分成三家host-local verdict、shared Matt workflow verdict與三家plugin-disabled verdict |

Candidate implementation完成不會改寫M1歷史verdict，也不會自動授權live cutover、plugin實際卸載或SaaS；它必須產出M2／M3-candidate／M5 final-architecture evidence，live只部署該final state。

## 18. Planning validation and closeout

Planning artifact acceptance：

- only this file與既有`tests/three-host-global-config-ownership.sh` modified；
- `git diff --check` PASS；
- Markdown heading structure PASS；
- placeholder scan PASS；
- all existing path references resolve；
- all planned paths marked CREATE／MATERIALIZE；
- all named commits resolve；
- ownership matrix與per-file tables一致；
- planning前後semantic skills manifest empty diff，exact `.DS_Store` metadata row另驗；
- stage-scoped skills allowlist、M2／M3／M5 tasks與single-final-cutover順序一致；
- live before／after fingerprint empty diff；
- gitleaks PASS；
- candidate clean after commit；
- no DCT build／test／MySQL E2E；
- no live config write、SaaS、Keychain read、remote mutation或subagent。

Revised planning commit：

```text
docs(workflow): 調和三家切換阻塞條件
```

Commit hash與本文件SHA-256由post-commit external evidence回報；不可把commit hash寫進其自身內容造成self-reference。

## 19. Unique next gate

完成本 amendment candidate RED→GREEN、S4–S6與fresh evidence後立即停止。唯一下一 gate是：

> **使用者另行明示授權 coordinated live cutover與三家 Superpowers實際退休；maintenance window後的fixed 6-run canary仍需獨立明示授權。**

本 amendment authorization不得解讀為live handoff、plugin mutation、SaaS或remote mutation授權。

# Copilot 全域設定分離實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. 本文件不授權執行；任何 implementation、live cutover、SaaS probe 或 subagent 使用都必須另取得當下明示授權。

**Goal:** 將 Copilot 的全域設定 ownership 從 `~/.agents/bin/agents-sync` 分離，同時保留 Copilot 對 `~/.agents/skills` 的共享 skill 消費能力，且不改變 Claude / Codex 的有效規則內容。

**Architecture:** 採用 `shared skill data plane + separate global-config control plane`。`~/.agents/skills` 仍是 Claude、Codex、Copilot 的共享 skill data plane；`~/.agents/core`、`~/.agents/rules` 與 `agents-sync` global deployment control plane 只服務 Claude / Codex；Copilot instructions、settings、config、hooks 與 plugin config 由 `~/.copilot` 獨立擁有、版本化與回滾。

**Tech Stack:** Bash、Git、既有 `agents-sync` / shell tests、SHA-256、`diff`、gitleaks；不新增 dependency。

**Risk:** 高。這是跨 host 全域設定 ownership migration；candidate implementation、live ownership handoff 與 SaaS/context canary 必須分 gate，並保留逐 host rollback。

## 0. 本文件的授權邊界

- 本次只完成 M1 roadmap amendment planning 與 candidate-only plan commit。
- 不執行 M1 Stage 2；Stage 2 budget 保持精確 `30`：Claude `15`、Codex `15`、Copilot `0`。
- 不建立 Stage 2 scratch、exception、carrier 或 result artifact。
- 不修改 `bin/agents-sync`、`TARGETS`、manifest、doctor、bootstrap、README、CONVENTIONS、core metadata、host delta、dist、hooks 或 tests。
- 不讀出或改寫任何 live config 內容；fingerprint 只記錄 path、Git metadata、SHA-256、size、mode 與 set/unset。
- 不執行 Claude、Codex、Copilot SaaS probe。
- 不改 `~/.agents`、`~/.claude`、`~/.codex`、`~/.copilot`。
- 不 push、open PR、merge 或做 remote mutation。
- DCT build / test / MySQL E2E：`SKIPPED`，因本次是 `~/.agents` isolated worktree 的 docs-only planning。

這份 plan 的完成不代表 M1 Stage 2、M1 closeout、M1.5 implementation、M1.5 live ownership handoff 或 M2 已獲授權。

### 0.1 Planning preflight evidence（2026-07-28 Asia/Taipei）

Candidate:

- resolved path：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- starting HEAD：`846b75742dc35421c878f1948065d54b080b8d60`
- porcelain count before edit：`0`
- 本文件 path before edit：absent

Live Git boundaries:

| Repo | Branch | HEAD | Porcelain |
|---|---|---|---|
| `~/.agents` | `main` | `36f8ff1dc208be531f52216dd33f2f32aec62e0f` | 7 exact pre-existing untracked proposal paths |
| `~/.claude` | `main` | `971f3015517267c7e070dff31b1a68a7d4ea04c4` | 1: ` M settings.json` |
| `~/.codex` | `main` | `bd1195dbee85b405b959a387b59f64d5449ab581` | 1: ` M AGENTS.md` |
| `~/.copilot` | `main` | `4b47fee53c68644f1dbcd75136440c01fda09f9d` | 1: ` M copilot-instructions.md` |

Live metadata-only fingerprints:

| File | SHA-256 | Size | Mode |
|---|---|---:|---:|
| `~/.agents/proposals/2026-07-28-skill-writing-audit/_population.md` | `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17` | 2348 | 0644 |
| `~/.claude/settings.json` | `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32` | 10647 | 0644 |
| `~/.claude/CLAUDE.md` | `db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7` | 7829 | 0644 |
| `~/.codex/AGENTS.md` | `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372` | 8425 | 0644 |
| `~/.copilot/copilot-instructions.md` | `9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c` | 9165 | 0644 |
| `~/.agents/mattpocock-skills.lock` | `8de7d847f7d1a12d6e2272accad9fb774557782b5fd602b1ad4b5495a7f0c721` | 610 | 0644 |

`mattpocock-skills.lock` assessed commit is `ed37663cc5fbef691ddfecd080dff42f7e7e350d` and contains exactly 22 `skill=` entries.

Existing rollback carriers:

| Path | Mode | Entries |
|---|---:|---:|
| `~/.agents-deployment-backups/20260727-193338-matt-v2` | 0700 | 3 |
| `~/.agents-deployment-backups/20260727-205915-matt-v4` | 0755 | 4 |
| `~/.agents/backups/20260728-065158-m1-live-skill-drift` | 0700 | 12 |

This preflight only proves the planning baseline. Every later gate must revalidate live state; it cannot reuse these values as current truth.

### 0.2 Roadmap status at planning time

- M0：`COMPLETE`。
- M1：`CURRENT`。
  - original three-host Stage 1：`FAIL`。
  - waiver path Claude + Codex Stage 1：`PASS_WITH_USER_WAIVER`。
  - Copilot：`FAIL / EXCLUDED`；不得改寫為 PASS。
  - Stage 2 attempts：`0`。
  - Stage 2：`PENDING / NOT AUTHORIZED`；後續 budget 精確為 Claude 15 + Codex 15 = 30。
- M1.5：ownership separation 已決定；目前只有 planning authorization。Implementation 必須在 M1 closeout 之後、M2 之前。
- M2：`PENDING`。
- M3：`PENDING`。
- M4：`PENDING`。
- M5：`PENDING`。

## 1. Current-state dependency map

### 1.1 Shared skill data plane

| Surface | Current role | Separation disposition |
|---|---|---|
| `skills/` | 三 host 的 shared skill source；Claude 經 symlink，Codex / Copilot 原生發現 | 保留為 `~/.agents/skills` 單一 shared skills root |
| `bin/agents-sync:57-69` `emit_skill_index()` | 從 `skills/` 生成 `dist/skill-index.md`；不注入 host body | 保留；不得建立第二個 Copilot skill registry |
| `bin/agents-sync:336-382` `bootstrap()` | 重建 Claude 的 core / skills / rules symlink，然後呼叫 deploy | 保留 Claude symlink 行為；不得新增 `.copilot` symlink 或 global-config write |
| `bin/agents-sync:468-474` doctor skill probes | 列出 Claude / Copilot / Codex skill visibility probe | 可保留 Copilot 的 read-only informational shared-skill readability probe；不得把 Copilot global-config drift 變成 doctor failure |
| `core/routing.md` | 共用 workflow routing body，目前 metadata 為 `consumed-by: claude,codex,copilot` | global-config body 改為 Claude / Codex ownership；Copilot 仍可由 shared skills 自身路由，不另建 registry |

### 1.2 Current global-config deployment control plane

| Surface | Current coupling | Required separation |
|---|---|---|
| `bin/agents-sync:23-27` `TARGETS` | `codex` 與 `copilot` 都是 generator target | 只保留 Codex target；不得有 `.copilot` output |
| `bin/agents-sync:75-96` `assemble_body()` / `render_target()` | 組裝 core + rules PIN + routing + host delta | 保留 Codex rendering；不再以 `hosts/copilot-delta.md` render Copilot global config |
| `bin/agents-sync:178-190` lint budget loop | 對每個 `TARGETS` row 驗 host body budget | 只驗 Claude / Codex control plane 的適用 budget；不把 Copilot config size 當 gate |
| `bin/agents-sync:216-223` `report_sizes()` | 依 `TARGETS` 印 Codex / Copilot bytes | 移除 Copilot global-config row |
| `bin/agents-sync:226-243` `write_manifest()` | 寫 `dist/manifest.tsv` 與每個 target 的 `dist/<basename>` | active manifest 只列 Codex；不生成 `dist/copilot-instructions.md` |
| `bin/agents-sync:245-291` `deploy()` | prescan / no-clobber / atomic write 所有 targets，現在會寫 `.copilot/copilot-instructions.md` | deploy、`--only`、no-clobber 與 partial-failure logic 都不得解析或寫入 `.copilot` |
| `bin/agents-sync:320-333` `check()` | lint、size 與 manifest hash 都依 `TARGETS` | `--check` 不得讀取或輸出 Copilot global-config target |
| `bin/agents-sync:384-475` `doctor()` | manifest、source stamp 與 FP probe 含 Copilot global config | manifest / stamp 不得因 `.copilot` 缺失或 drift fail；僅可保留 shared-skill informational probe |
| `bin/agents-sync:478-484` CLI dispatch | `--only copilot` 目前可部署 Copilot | 移除 Copilot deployment promise；unknown / empty selection 必須 fail-loud，不能假綠 |
| `dist/manifest.tsv` | active row 包含 `.copilot/copilot-instructions.md` hash | active manifest 移除該 row |
| `dist/copilot-instructions.md` | Copilot generated global-config artifact | 從 active `dist/` 退役並以 Git history / attic carrier保留，不再生成 |
| `dist/AGENTS.md` | Codex generated artifact | 有效 body 必須逐 byte 不變；只允許 source banner 因 metadata commit 改變 |
| `hosts/copilot-delta.md` | Copilot global-config delta source | 從 active `hosts/` 退役；live cutover 時由 `~/.copilot` repo 接手，不再由 `agents-sync` consume |
| `hosts/codex-delta.md` | Codex host delta | 保留且有效 body 不變 |
| `core/tier0-safety.md`、`core/tier1-workflow.md`、`core/tier2-style.md`、`core/routing.md` | metadata 宣稱三 host global consumption；body 被 Codex render、Claude import / stamp、Copilot render | metadata 改為 Claude / Codex control plane；有效 body不改 |
| `rules/*.md` | PIN body 可被所有 `TARGETS` render | active generated global config 只供 Codex；Claude 仍經 rules symlink |

### 1.3 Documentation and hook ownership surfaces

| Surface | Current statement / behavior | Required separation |
|---|---|---|
| `README.md:1-68` | 宣稱三家 global config single source、三家 deploy、Copilot generated target | 改成三 host shared skills + Claude / Codex global control plane；列明 Copilot independent ownership |
| `CONVENTIONS.md:1-69` | metadata 範例與 context budget 以三家生成體描述；`.copilot` backup rule 仍適用 | 更新 active generation / metadata wording；保留 secret-safe backup policy與通用規範 |
| `hooks/post-checkout-agents.sh:8-38` | branch switch 說明 Codex / Copilot 都是 generated deployment | 改為只描述 Codex generated file；Copilot 只受 shared-skill branch visibility影響 |
| `hooks/drift-check.sh:2-6` | doctor 被描述為 deployment drift guard | 保留 Claude / Codex drift guard；Copilot global-config drift不得令其失敗 |
| `hooks/install-hooks.sh`、`hooks/install-pre-commit.sh`、push guards、MCP patch hooks | 不負責 Copilot global-config generation | 不改 |
| `bin/agents-branch:11-14` | 註解把 host deployment 視為共享 checkout side effect | 更新註解中的 control-plane host scope；worktree isolation 行為不改 |

### 1.4 Tests and conformance surfaces

| Surface | Current coverage | Required separation |
|---|---|---|
| `tests/conformance.sh:40-55` | 直接移走 live Codex deploy file 驗 doctor fail，之後還原 | 保留既有 Codex gate；新增 scratch-only Copilot separation suite，避免再碰 live config |
| `tests/agents-branch.sh` | scratch 驗 isolated worktree | 保留；M1.5 candidate gate仍必跑 |
| `tests/claude-routing-collision.sh` | 守 Claude managed stamp 外無平行 routing source | 保留；Claude effective routing不得改 |
| `tests/legacy-mp-collision.sh`、`tests/mattpocock-workflow.sh` | 守 shared skills / wrapper replacement contracts | 保留；Copilot 仍是 shared skill consumer |
| `tests/phase4-canary-harness.sh`、`tests/phase4-canary-launcher.sh` | Phase 4 canary contract tests | 歷史 canary machinery；M1.5 不改 |
| 新增 `tests/agents-sync-copilot-separation.sh` | 尚不存在 | 以 scratch HOME / AGENTS_HOME / AGENTS_DEPLOY_ROOT 鎖定 RED→GREEN contract |

### 1.5 Historical-only artifacts

下列 artifacts 是歷史 evidence，不是 active ownership source，M1.5 必須 byte-for-byte 不變：

- `proposals/2026-07-27-mattpocock-skills-workflow/23-phase4-canary-matrix.jsonl`
- `proposals/2026-07-27-mattpocock-skills-workflow/26-phase4-v2-result-schema.json`
- `proposals/2026-07-27-mattpocock-skills-workflow/27-phase4-v2-canary-matrix.jsonl`
- `proposals/2026-07-27-mattpocock-skills-workflow/29-phase4-v2-stage1-fail-fast-evidence.md` 至 `44-phase4-v2-two-host-waiver-stage2-budget-gate-evidence.md`
- `bin/phase4-canary-launcher`
- `bin/phase4-canary-harness`
- `tests/phase4-canary-launcher.sh`
- `tests/phase4-canary-harness.sh`

`dist/copilot-instructions.md` 與 `hosts/copilot-delta.md` 是現在仍 active、分離後退役的 ownership carriers，不得回寫上述歷史 matrix、attempt、FAIL 或 waiver 來重述新架構。

## 2. Ownership contract and matrix

| Asset / path | Claude | Codex | Copilot | Owner after separation |
|---|---:|---:|---:|---|
| `~/.agents/skills/**` | shared consumer | shared consumer | shared consumer | `~/.agents` |
| `~/.agents/core/**` | global rules / routing | generated global body | no generated global-config consumption | `~/.agents` for Claude + Codex |
| `~/.agents/rules/**` | symlinked rules | generated PIN body | no generated global-config consumption | `~/.agents` for Claude + Codex |
| `~/.agents/bin/agents-sync` | Claude stamp / links | Codex generation / deployment / doctor | shared-skill readability probe only | `~/.agents` |
| `~/.claude/**` | independent host surface plus managed imports / stamp | none | none | `~/.claude` |
| `~/.codex/AGENTS.md` | none | generated / deployed / validated | none | `~/.agents` control plane |
| `~/.copilot/copilot-instructions.md` | none | none | independently versioned | `~/.copilot` |
| `~/.copilot/settings*`, config, hooks, plugin config | none | none | independently versioned / rolled back | `~/.copilot` |

Hard contract:

1. Copilot remains a consumer of the only shared skills root: `~/.agents/skills`.
2. No second skills root、skill registry、manifest family 或 sync daemon is introduced.
3. `agents-sync` must not generate、deploy、validate、mutate or no-clobber-check any `.copilot` global config file.
4. `agents-sync --doctor` may retain a read-only informational probe for Copilot shared-skill readability.
5. Missing or drifted `.copilot` global config must not fail Claude / Codex deployment or doctor.
6. Copilot instructions、settings、config、hooks、plugin config are independently owned、versioned and rolled back in `~/.copilot`.
7. Historical Phase 4 matrix、attempts、FAIL、waiver and budget evidence remain immutable.

## 3. Gate sequence: no implicit authorization

| Gate | Entry condition | Authorized action | Exit evidence | Does not authorize |
|---|---|---|---|---|
| Planning closeout | This plan committed on exact candidate preflight | Plan validation and candidate-only commit | plan diff、local docs checks、clean candidate | M1 Stage 2 |
| M1 Stage 2 budget gate | Separate explicit authorization after planning closeout | Exactly Claude 15 + Codex 15 = 30 SaaS runs under canonical matrix | per-host verdicts、attempt ledger、budget ledger | extra runs、Copilot runs、M1.5 |
| M1 closeout | Stage 2 terminal evidence and separately confirmed acceptance | Close M1 and freeze its evidence | immutable M1 closeout record | M1.5 candidate implementation |
| M1.5 candidate implementation | M1 closed + separate explicit implementation authorization + exact live fingerprints | RED tests、minimal GREEN candidate changes、scratch/local verification | candidate commits and evidence; no live writes | live ownership handoff |
| M1.5 live ownership handoff | Candidate green + separate explicit live cutover authorization + private backup + clean ownership baseline | Capture existing Copilot dirty content, establish independent `~/.copilot` versioning, deploy Claude / Codex-only control plane | per-host postflight and rollback proof | M2 |
| M2 authorization | M1.5 closed + separate explicit authorization | Execute M2 roadmap only | M2-specific evidence | M3-M5 |

Current unique next gate after this planning closeout is the M1 Claude + Codex Stage 2 exact budget `30` authorization. This plan cannot skip to M1.5.

## 4. RED regression specification

### Task 1: Add one scratch-only separation contract suite

**Files:**
- Create: `tests/agents-sync-copilot-separation.sh`
- Test: `tests/agents-sync-copilot-separation.sh`

The test must use only a `mktemp -d` root, with:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH_AGENTS="$TMP/agents"
SCRATCH_HOME="$TMP/home"
mkdir -p "$SCRATCH_AGENTS" "$SCRATCH_HOME/.copilot"
tar -C "$ROOT" --exclude=.git -cf - . | tar -C "$SCRATCH_AGENTS" -xf -
```

All generator invocations must set all three boundaries:

```bash
HOME="$SCRATCH_HOME" \
AGENTS_HOME="$SCRATCH_AGENTS" \
AGENTS_DEPLOY_ROOT="$SCRATCH_HOME" \
bash "$SCRATCH_AGENTS/bin/agents-sync" <mode>
```

The suite must create a synthetic `.copilot/copilot-instructions.md` sentinel under `SCRATCH_HOME`, store only its SHA-256, run each mode, and assert the hash is unchanged. It must never read or modify live `~/.copilot`.

Minimum RED assertions:

1. `TARGETS` contains no `.copilot` path and no `copilot|` global-config row.
2. `--check` writes nothing under `SCRATCH_HOME/.copilot`.
3. default deploy writes nothing under `SCRATCH_HOME/.copilot`.
4. `--bootstrap` writes nothing under `SCRATCH_HOME/.copilot`.
5. `--doctor` does not fail when `SCRATCH_HOME/.copilot` is absent.
6. `--doctor` does not fail when the synthetic Copilot sentinel differs from historical `dist/copilot-instructions.md`.
7. `dist/manifest.tsv` has exactly one active global-config row, for `.codex/AGENTS.md`, and no `.copilot` path.
8. no active `dist/copilot-instructions.md` is generated.
9. `SCRATCH_AGENTS/skills/dev-workflow/SKILL.md` remains present and readable; no second Copilot skills root is created.
10. `README.md` names `~/.agents/skills` as Copilot’s shared skill source and `~/.copilot` as its independent global-config owner.
11. the test records pre/post SHA-256 for Claude effective body and Codex effective body and requires exact equality.
12. the test records pre/post SHA-256 for the historical artifact set in §1.5 and requires exact equality.
13. an existing synthetic dirty Copilot sentinel is never overwritten, renamed, chmodded or deleted.

RED command:

```bash
bash tests/agents-sync-copilot-separation.sh
```

Expected RED result before implementation:

```text
FAIL: TARGETS still owns .copilot/copilot-instructions.md
```

The suite must stop on that root contract rather than emit one failure per downstream symptom.

Commit boundary:

```bash
git add tests/agents-sync-copilot-separation.sh
git commit -m "test(workflow): [wip] 鎖定 Copilot 設定 ownership"
```

The `[wip]` RED commit is permitted only on the isolated feature branch and must not be pushed or merged while red.

## 5. Minimal GREEN implementation plan

### Task 2: Remove Copilot from the active generator target table

**Files:**
- Modify: `bin/agents-sync`
- Test: `tests/agents-sync-copilot-separation.sh`

Make only these behavior changes:

1. Change the script description and usage from three-host global deployment to Claude / Codex global control plane plus three-host shared skills.
2. Delete the `copilot|.copilot/copilot-instructions.md|hosts/copilot-delta.md` row from `TARGETS`.
3. Keep the existing generic `TARGETS` loops; do not add host-specific branching, a policy engine, a second manifest, or a new abstraction.
4. Update `--only` help so it does not advertise Copilot deployment.
5. Make `--only copilot` fail-loud because no target matches; it must not silently report success.
6. Keep the existing Copilot shared-skill doctor line as informational, but remove Copilot global FP/deployment claims.
7. Preserve `AGENTS_HOME` / `AGENTS_DEPLOY_ROOT`, no-clobber, atomic write, Claude routing stamp, Codex manifest and Codex source-stamp behavior.

GREEN command:

```bash
bash tests/agents-sync-copilot-separation.sh
```

Expected:

```text
agents-sync Copilot global-config separation PASS
```

Commit boundary:

```bash
git add bin/agents-sync tests/agents-sync-copilot-separation.sh
git commit -m "refactor(workflow): 分離 Copilot 全域設定"
```

### Task 3: Retire active Copilot generator sources without rewriting history

**Files:**
- Move: `hosts/copilot-delta.md` → `attic/copilot-global-config/hosts/copilot-delta.md`
- Move: `dist/copilot-instructions.md` → `attic/copilot-global-config/dist/copilot-instructions.md`
- Regenerate: `dist/manifest.tsv`
- Verify unchanged: `dist/AGENTS.md`
- Modify metadata only: `core/tier0-safety.md`
- Modify metadata only: `core/tier1-workflow.md`
- Modify metadata only: `core/tier2-style.md`
- Modify metadata only: `core/routing.md`

Required changes:

1. Use `git mv` for the two retired carriers so Git history remains traceable.
2. Do not copy them into a new active directory or registry under `~/.agents`.
3. Change the four core metadata lines from `consumed-by: claude,codex,copilot` to `consumed-by: claude,codex`; do not alter rule or routing body.
4. Run the candidate generator only against a scratch copy. Do not deploy from the feature worktree.
5. Bring back only the expected generated `dist/manifest.tsv` and `dist/AGENTS.md` candidate outputs for review.
6. Assert `sed '1d' dist/AGENTS.md` is byte-for-byte equal to the M1-closeout baseline. A banner-only change is allowed; an effective-body change stops implementation.

Commands:

```bash
git mv hosts/copilot-delta.md attic/copilot-global-config/hosts/copilot-delta.md
git mv dist/copilot-instructions.md attic/copilot-global-config/dist/copilot-instructions.md
bash tests/agents-sync-copilot-separation.sh
```

Commit boundary:

```bash
git add core/tier0-safety.md core/tier1-workflow.md core/tier2-style.md core/routing.md \
  hosts/copilot-delta.md dist/copilot-instructions.md \
  attic/copilot-global-config/hosts/copilot-delta.md \
  attic/copilot-global-config/dist/copilot-instructions.md \
  dist/manifest.tsv dist/AGENTS.md
git commit -m "refactor(workflow): 退役 Copilot 生成設定"
```

The exact staged path list must be reviewed before commit because the two source paths are deletions after `git mv`.

### Task 4: Update the minimum active documentation and hook wording

**Files:**
- Modify: `README.md`
- Modify: `CONVENTIONS.md`
- Modify: `bin/agents-branch`
- Modify: `hooks/post-checkout-agents.sh`
- Modify: `hooks/drift-check.sh`
- Test: `tests/conformance.sh`
- Test: `tests/agents-branch.sh`
- Test: `tests/agents-sync-copilot-separation.sh`

Required wording:

1. `README.md` describes one shared skills data plane for all three hosts and one Claude / Codex global-config control plane.
2. `README.md` says `~/.copilot/**` is independently owned and `agents-sync` never writes or validates it.
3. `CONVENTIONS.md` metadata and context-budget examples match the two-host global control plane while keeping the three-host shared-skill contract.
4. Branch / hook docs no longer say Copilot global config waits for `agents-sync`; they still warn that shared skills track the live `~/.agents/skills` checkout.
5. No Phase 4 evidence, matrix, result schema, attempt, FAIL or waiver text is edited.

Commands:

```bash
bash tests/agents-sync-copilot-separation.sh
AGENTS_HOME="$PWD" bash tests/agents-branch.sh
bash -n bin/agents-sync bin/agents-branch hooks/post-checkout-agents.sh hooks/drift-check.sh tests/agents-sync-copilot-separation.sh
```

`tests/conformance.sh` must run against an isolated fixture or explicitly skip live-only probes with evidence; it must not mutate the known dirty live config surfaces.

Commit boundary:

```bash
git add README.md CONVENTIONS.md bin/agents-branch \
  hooks/post-checkout-agents.sh hooks/drift-check.sh
git commit -m "docs(workflow): 更新全域設定 ownership"
```

No new dependency、framework、manifest rewrite、policy engine 或 second skill registry is permitted.

## 6. Verification plan

### 6.1 RED → GREEN evidence

Record:

- RED test command、non-zero exit、first root-contract failure。
- GREEN test command、zero exit、PASS count。
- `git diff` proving RED test existed before GREEN implementation。
- no live path appeared in test write targets。

### 6.2 Scratch-only `agents-sync` modes

Run in a fresh scratch copy with `HOME`、`AGENTS_HOME`、`AGENTS_DEPLOY_ROOT` all pointed under one `mktemp -d`:

```bash
bash tests/agents-sync-copilot-separation.sh
```

The suite must exercise:

- `agents-sync --check`
- `agents-sync --doctor`
- `agents-sync --bootstrap`
- default deploy
- deploy idempotence
- `--only codex`
- rejected `--only copilot`

Expected:

- no `.copilot` create / write / validate / mutate。
- Codex target and manifest remain operational。
- Claude symlink / routing stamp behavior remains operational。
- missing / drifted `.copilot` does not affect exit code。

### 6.3 Claude effective content equivalence

Before the first M1.5 edit, capture a private scratch baseline from the M1-closeout commit:

```bash
for f in core/tier0-safety.md core/tier1-workflow.md core/tier2-style.md core/routing.md; do
  git show "$M1_CLOSEOUT:$f" | sed '/^<!-- tier:/d'
done > "$TMP/claude-effective-before"

for f in core/tier0-safety.md core/tier1-workflow.md core/tier2-style.md core/routing.md; do
  sed '/^<!-- tier:/d' "$f"
done > "$TMP/claude-effective-after"

cmp -s "$TMP/claude-effective-before" "$TMP/claude-effective-after"
```

Expected: exact equality.

If Claude effective content changes, stop at a fresh canary budget authorization gate. Do not reuse M1 SaaS evidence or budget.

### 6.4 Codex effective generated body equivalence

```bash
git show "$M1_CLOSEOUT:dist/AGENTS.md" | sed '1d' > "$TMP/codex-body-before"
sed '1d' dist/AGENTS.md > "$TMP/codex-body-after"
cmp -s "$TMP/codex-body-before" "$TMP/codex-body-after"
```

Expected: exact equality. Banner source SHA may differ; body may not.

If Codex effective content changes, stop at the same fresh canary budget authorization gate. Do not reuse M1 SaaS evidence or budget.

If both Claude and Codex effective bodies are exactly unchanged, record exact-equivalence evidence and propose canary reuse to the user. The implementation session cannot self-approve reuse.

### 6.5 Manifest and no-write assertions

```bash
test "$(wc -l < dist/manifest.tsv | tr -d ' ')" = 1
grep -q $'^codex\t.codex/AGENTS.md\t' dist/manifest.tsv
! grep -q 'copilot\\|\\.copilot' dist/manifest.tsv
! rg -n '\\.copilot/.+|copilot\\|\\.copilot' bin/agents-sync
test ! -e dist/copilot-instructions.md
```

The scratch suite must hash its Copilot sentinel before and after every generator mode and require:

```text
path unchanged
SHA-256 unchanged
size unchanged
mode unchanged
```

### 6.6 Shared-skill discovery

Local candidate gate:

```bash
test -r skills/dev-workflow/SKILL.md
test "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -gt 0
! find . -path './.git' -prune -o -type d -path '*copilot*skills*' -print | grep -q .
```

Live handoff gate, separately authorized and read-only:

```text
Copilot available_skills contains dev-workflow from ~/.agents/skills
```

If the available-skills probe invokes SaaS, it requires a separately approved M1.5 probe budget and is not charged to or inferred from M1 Stage 2.

### 6.7 Historical immutability

Before edits, store SHA-256 for the §1.5 artifact set in a private temp file; after GREEN, regenerate the same sorted hash list and require empty diff:

```bash
diff -u "$TMP/historical-before.sha256" "$TMP/historical-after.sha256"
```

No historical artifact is updated to reinterpret the original three-host FAIL, Copilot EXCLUDED verdict, two-host waiver or M1 budget.

### 6.8 Local quality gates

```bash
bash -n bin/agents-sync bin/agents-branch \
  hooks/post-checkout-agents.sh hooks/drift-check.sh \
  tests/agents-sync-copilot-separation.sh
bash tests/agents-sync-copilot-separation.sh
AGENTS_HOME="$PWD" bash tests/agents-branch.sh
bash tests/legacy-mp-collision.sh
bash tests/mattpocock-workflow.sh
git diff --check
gitleaks detect --source . --no-banner
```

Run `shellcheck` on changed shell files when available; report `UNAVAILABLE` with the command result if it is not installed.

### 6.9 Live fingerprint postflight

After a separately authorized live handoff, verify without printing config content:

- `~/.agents`、`~/.claude`、`~/.codex`、`~/.copilot` branch、HEAD、porcelain count。
- Claude settings / CLAUDE policy、Codex AGENTS、Copilot instructions、Matt lock SHA-256 / size / mode。
- `mattpocock-skills.lock` assessed commit and exactly 22 `skill=` entries。
- `agents-sync --doctor` Claude / Codex result and informational Copilot shared-skill result。
- `.copilot` global-config drift does not affect `agents-sync --doctor` exit。
- no extra untracked path beyond the accepted exact baseline。

## 7. M1.5 live ownership handoff and rollback

This section is a runbook, not current authorization.

### 7.1 Entry conditions

1. M1 Stage 2 and M1 closeout are terminal and separately accepted.
2. M1.5 candidate commits pass §6.
3. User explicitly authorizes live cutover.
4. Revalidate exact live fingerprints from the closeout handoff.
5. No unexpected dirty or untracked state exists in any host repo.
6. The known dirty `~/.copilot/copilot-instructions.md` must match its authorized exact SHA-256, size and mode; any mismatch stops before backup or write.
7. No config content, diff body, credential or auth cache is printed.

### 7.2 Private byte-for-byte backup

Create one new cutover-specific directory outside the repos:

```bash
BACKUP_DIR="$(mktemp -d "$HOME/.agents-deployment-backups/XXXXXXXX-copilot-ownership.XXXXXX")"
chmod 0700 "$BACKUP_DIR"
install -m 0600 "$HOME/.copilot/copilot-instructions.md" "$BACKUP_DIR/copilot-instructions.md"
```

Also capture the pre-cutover `bin/agents-sync`、`dist/manifest.tsv`、`hosts/copilot-delta.md` and active generated Copilot dist carrier from the exact M1-closeout commit into mode `0600` files. Record only path、hash、size and mode.

### 7.3 Resolve the known Copilot dirty file without overwrite

The dirty Copilot instructions must first be versioned exactly as-is in `~/.copilot`; do not regenerate or replace it:

1. Verify the file equals the authorized preflight fingerprint.
2. Stage only `copilot-instructions.md`.
3. Review staged path and staged object hash without printing content.
4. Commit the exact existing bytes in `~/.copilot`.
5. Require `~/.copilot` clean before the ownership-marker change.

Then make one metadata-only ownership change in `~/.copilot/copilot-instructions.md`: replace the first generated-by-`agents-sync` banner with an independent `~/.copilot` ownership marker while preserving every byte after line 1. Verify the body with a private `tail -n +2` comparison and commit it in `~/.copilot`.

This two-commit sequence captures, rather than overwrites, the existing dirty instructions.

### 7.4 Activate Claude / Codex-only control plane

1. Advance live `~/.agents` only to the reviewed M1.5 implementation commit.
2. Run `agents-sync` only after `~/.copilot` is independently versioned and clean.
3. Verify `agents-sync` does not stat, hash, diff, chmod, rename or write `.copilot`.
4. Run live postflight from §6.9.
5. Require separate Claude、Codex、Copilot verdicts; do not merge host outcomes.

### 7.5 Immediate rollback on partial success

Any failed host postflight triggers immediate rollback:

1. Stop further writes and probes.
2. Revert the M1.5 `~/.agents` commits with `git revert`; never use `git reset --hard`.
3. Restore the old `agents-sync` Copilot target、manifest row、host delta and dist carrier through those reverts.
4. Restore `~/.copilot/copilot-instructions.md` byte-for-byte from the mode `0600` backup using an atomic same-directory temp file.
5. Revert the two `~/.copilot` ownership commits if they exist.
6. Run the old scratch-validated `agents-sync` deployment only when the restored Copilot file matches the old no-clobber banner/body hash contract.
7. Re-run metadata-only fingerprints and per-host doctor probes.
8. Report partial success as failure; do not keep a mixed ownership state.

Planning rollback is `git revert` of the planning commit. Candidate implementation rollback is `git revert` of its scoped commits. Live rollback restores both repos and the byte-for-byte Copilot carrier; no force push、hard reset or broad deletion is allowed.

## 8. Roadmap impact after M1.5

### M2

- Retain Copilot shared-skill compatibility through `~/.agents/skills`.
- M2 skill migration acceptance remains three-host per skill discovery / invocation where authorized.
- Copilot global config is not deployed or validated by `agents-sync`.

### M3

- Split gates:
  - shared-skill gates remain in the `~/.agents` roadmap。
  - Copilot instructions / settings / hooks / plugin gates move to the independent `~/.copilot` roadmap。
  - Claude / Codex global-config gates remain under `~/.agents`。
- A Copilot global-config failure must not fail Claude / Codex deployment; a shared-skill failure may still affect all three hosts and must be reported per host.

### M4

- Unaffected by this ownership split.
- Phase 4 historical canary machinery and evidence remain immutable unless M4 receives separate scope that explicitly names them.

### M5

Verify two distinct planes:

1. Three-host shared skills: Claude、Codex、Copilot each discover the same authorized `~/.agents/skills` set.
2. Two-host global config: Claude effective imports / routing and Codex generated AGENTS remain owned by `~/.agents`.
3. Copilot global config: independently versioned and rolled back in `~/.copilot`, with no `agents-sync` target、manifest、doctor failure or write surface.

M5 must publish separate per-host and per-plane verdicts; it must not infer Copilot global-config health from shared-skill health or infer Claude / Codex health from Copilot.

## 9. Planning closeout acceptance

This planning artifact is complete only when:

- exact candidate preflight remains path / branch / HEAD / clean compliant before edit。
- only this file is added。
- `git diff --check` passes。
- required architecture phrase、ownership contract、RED list、minimal GREEN plan、six gates、rollback、verification and M2-M5 impacts are present。
- no unresolved placeholder token or implicit authorization remains。
- candidate-only commit message is exactly:

```text
docs(workflow): 規劃 Copilot 全域設定分離
```

- postflight reports candidate new HEAD and clean status。
- live fingerprints remain byte-for-byte unchanged。
- stop at the M1 Claude + Codex Stage 2 exact budget `30` gate。

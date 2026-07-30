# Matt Pocock skills × thin-kernel 全域 workflow 實作計畫

> 日期：2026-07-27  
> 狀態：已實作；本文現為正式收尾／歷史計畫載體
> 目標 host：Claude Code、Codex、Copilot；source-of-truth 共用，但 invocation、delegation、plugin lifecycle、inventory 與 canary 不得跨 host 外推
> 風險：**HIGH**（全域 workflow、三個 host、plugin lifecycle、machine-local config）  
> 授權邊界：本文內 Phase 0–7、new-session 指令與 stop conditions 只保留為歷史設計，不構成任何新的 implementation、deployment、plugin lifecycle、cleanup 或 remote mutation 授權

## 0. 完成狀態與文件治理

2026-07-30 已完成 shared skills 與 three-host thin-kernel 切換；ownership split 的現行設計正本仍為 [48-three-host-global-config-ownership-split-plan.md](48-three-host-global-config-ownership-split-plan.md)。

| Surface | Live commit | 現行邊界 |
|---|---|---|
| `~/.agents` | `44c7fd073ba41685cd0362f51a2a1bf82006dcc1` | 只保留三 host 共用的 `skills/**` data plane 與 shared-skill maintenance |
| `~/.claude` | `c12cd0953147d107d16148fa2efe1a21f9529f8a` | Claude 自有 global routing／governance；94 個 shared skill links |
| `~/.copilot` | `d593d657aca930ac56bfe3d789ee00745b324179` | Copilot 自有 global routing／governance，讀取 shared thin kernel |

匯入集合維持 26 個 skills 與 26 個 Claude links；`~/.agents/skills` 與 Claude link surface 各對外提供 94 個 skills。`video-downloader` 已正規化為 `youtube-downloader`，未修改 vendored payload bytes。本輪未 push、開 PR 或 remote merge。

本次 proposal governance 的逐檔處置如下；除本檔狀態區外，其餘文件保留原文：

| 檔案 | Disposition |
|---|---|
| `10-claude-review-of-reconciled-final.md` | Implemented／Historical |
| `11-codex-review-of-claude-feedback-and-gpt56-assessment.md` | Implemented／Historical |
| `12-claude-review-of-codex-feedback-and-dual-host-assessment.md` | Implemented／Historical |
| 本檔 | Canonical closeout／Historical plan |
| `14-copilot-review-of-cross-host-plan.md` | Implemented／Historical |
| `../2026-07-27-workflow-constraint-audit/README.md` | Implemented／Historical |
| `../2026-07-28-skill-writing-audit/_population.md` | Protected historical snapshot；byte-for-byte unchanged |

## 1. 結論與終態

採用：

```text
thin kernel
├── tier0 safety / authorization
├── risk-triggered plan gate
├── red→green
├── cross-stage delegation invariant
├── evidence / review / closeout
└── hooks / local conformance / CI

Matt stable 22（task-specific，pinned、vendored、immutable）
├── needs / domain / spec
├── implementation / TDD / diagnosis
├── review / architecture
└── tickets / handoff / wayfinding
```

不採用長期疊加。Matt skills 取代重複的方法論與 orchestration；kernel 只保留治理、風險與完成證據。Superpowers 最後逐 host 移除，不在第一個 implementation session 直接刪除。

這是 workflow unlock，不是提高模型原始 reasoning ceiling。Claude Code、Codex 與 Copilot 共用 source-of-truth；invocation、delegation、plugin toggle、new-session inventory 和 A/B verdict 必須分 host。

## 2. 已收斂決策

1. Vendor `mattpocock/skills` assessed commit：
   `ed37663cc5fbef691ddfecd080dff42f7e7e350d`。
2. 只曝光該 commit `.claude-plugin/plugin.json` 的 22 支；manifest SHA-256：
   `e712cc026f5e78058067d17cd1fdf9665388d70db59dc50688286cb029e38eba`。
3. 不執行 upstream `scripts/link-skills.sh`；它是 maintainer-only 且會曝光超過 22 支。
4. 安裝 `setup-matt-pocock-skills`，但不自動執行。由本機 compatibility adapter 與單一 issue-tracker contract 承接。
5. Upstream 22 支檔案 immutable。本機差異只進 kernel、adapter、contract、provenance 與 tests。
6. `mp-zoom-out` 保留。
7. `mp-diagnose`、`mp-grill-with-docs`、`mp-improve-codebase-architecture`、`mp-tdd` 不採預設刪除；先完成 17 檔 file-level parity ledger，再 `git mv` 到 `attic/`。
8. `misc/` 不導入。
9. Phase 6 採 12 項 gate：文件 12 的 11 項，加 Copilot skill discovery / routing gate。

## 3. 2026-07-27 15:29–17:42 Asia/Taipei live baseline

此表只是一輪觀測；implementation session 必須重跑並標新時刻。

| Surface | 觀測 |
|---|---|
| `~/.agents` | `main` @ `19be2eb`; ahead `origin/main` 4 commits；有 10–12 與另一 proposal 的 untracked files |
| `agents-sync --check` | PASS；Codex 8563/10240B、Copilot 9303/10240B |
| `agents-sync --doctor` | PASS；Claude stamp、Codex/Copilot manifest、source stamp 皆相符 |
| Claude | Claude Code 2.1.220；Superpowers enabled；`settings.json` mtime 10:03:05+08:00 |
| Codex | codex-cli 0.145.0；`gpt-5.6-sol`；effort `high`；Superpowers enabled |
| Copilot | `~/.local/bin/copilot` 與 `/opt/homebrew/bin/copilot` 皆為 CLI 1.0.75；Superpowers 6.2.0 enabled；pre-update backup 檔名不作 runtime version 證據 |
| Upstream | `main` 仍為 assessed commit；manifest 22 支、hash 如上 |
| Config repos | `~/.claude`、`~/.codex`、`~/.copilot` 都是 git repo |
| Dirty config state | `~/.claude/settings.json` 已有修改；`~/.codex/AGENTS.md`、`~/.copilot/copilot-instructions.md` 已有修改 |

重要推論：

- Copilot 組裝體已超過 90% 預算；依 `CONVENTIONS.md` §13，新增常駐條文必須同批刪除等量重複內容。
- 不得把既有 dirty config 一起 commit、stash、還原或覆蓋。
- 不得在 live `~/.agents` 切 feature branch；Claude symlink、Codex/Copilot 原生 personal-skill root 都會立即讀到不同 skill 內容，只有 generated instructions 要等 `agents-sync`。

## 4. 高扇入依賴清單

| Source | Consumers / blast radius |
|---|---|
| `core/tier1-workflow.md` | Claude core import；Codex/Copilot generated assemblies |
| `core/routing.md` | Claude `CLAUDE.md` routing stamp；Codex/Copilot generated assemblies |
| `skills/dev-workflow/SKILL.md` | 三 host 的 canonical S0–S6、host adapters、所有 repo 開發任務 |
| `skills/auditing-skill-folder/**` | 全 skill corpus audit、vendored gate、style rules |
| `bin/agents-sync` | Claude symlinks/stamp、Codex/Copilot deploy、manifest、doctor |
| `bin/agents-branch` | `~/.agents` worktree isolation |
| `~/.claude/settings.json` | Claude plugin inventory / new sessions |
| `~/.codex/config.toml` | Codex plugin inventory / new sessions |
| Copilot plugin registry | CLI 1.0.75 無 enable/disable subcommand；`settings.json.enabledPlugins` 可讀但停用效果尚待 isolated new-session probe |

Markdown/policy 依賴使用 `rg` 盤點；`deps-check` script 不支援此類檔案，不強套。

## 5. Phase 0 — Preflight、隔離與 rollback 基線

### 0.1 讀取順序

完整讀：

1. `08-codex-final-proposal.md`
2. `07-review-of-codex-final.md`
3. `09-codex-reconciled-final-for-claude-review.md`
4. `10-claude-review-of-reconciled-final.md`
5. `11-codex-review-of-claude-feedback-and-gpt56-assessment.md`
6. `12-claude-review-of-codex-feedback-and-dual-host-assessment.md`
7. 本文件
8. `~/.agents/skills/dev-workflow/SKILL.md`
9. `~/.agents/CONVENTIONS.md`
10. `~/.agents/vendored-forks.md`

### 0.2 重跑唯讀 probes

記錄 Asia/Taipei 時刻、四個 repo 的 `HEAD` / branch / status、host version、model/effort、plugin enabled state、cache/installed version、skill inventory、`agents-sync --check`、`--doctor`、active Superpowers refs、4 支 `mp-*` 的 17 檔清單。

Copilot 另記：

- canary 實際使用的 executable 絕對路徑與 `--version`；desktop/app backup 檔名不得當 runtime identity；
- `dynamicRetrieval.skills` 的 set/unset 與有效值；
- `disabledSkills` 的 set/unset 與成員數；不輸出 skill 名稱；
- 靜態 prompt 中完整 skill description 的實際涵蓋範圍，以及名稱尾巴；不得把靜態截斷直接推論為自動 routing 失效；
- 官方 `user-invocable` / `disable-model-invocation` 契約與本機 CLI 行為分開記錄；`skill list --json` 未輸出欄位不等於不支援。

不得輸出完整 settings/config、環境變數或 secret value；只回報指定 key 的值或 set/unset。

若下列任一成立即停止：

- assessed commit 或 22-skill manifest hash 改變；
- `agents-sync --check` 或 `--doctor` 不綠；
- live `~/.agents` 不在 `main`；
- canary 實際 executable / version 無法固定。

若 dirty changes 與 target hunk 重疊，記為 **Phase 3 deployment blocker**：Phase 1–3 isolated candidate 仍可在 worktree 進行，但不得 live deploy，直到歸屬、baseline diff 與 rollback 都已裁定。

### 0.3 建 isolated worktree

不動 live main：

```bash
mkdir -p ~/.agents/.worktrees/codex
~/.agents/bin/agents-branch codex/mattpocock-workflow-migration
```

預期 worktree：

```text
~/.agents/.worktrees/codex/mattpocock-workflow-migration
```

從此 Phase 1–3 只在 worktree 編輯。不要在 worktree 執行 live deploy。

### 0.4 Rollback 基線

- `~/.agents`：每 phase 獨立 commit；rollback 用 `git revert`，禁止 `reset --hard`。
- `~/.claude` / `~/.codex` / `~/.copilot`：先保存 status 與 target-file diff；設定變更只 stage 本次精確 hunk，不能帶入既有 dirty edits。
- tracked generated files 不建立 `*.bak`，由 source commit + target diff 承接 rollback。
- Copilot 的 `settings.json`、`config.json`、`hooks/`、`installed-plugins/` 不在該 repo rollback carrier 內。任何 `settings.json` mutation 前，先建立 mode `0600` 的 byte-for-byte 暫存備份，不輸出內容；rollback 後以 `cmp` 與 new-session inventory 讀回。
- Plugin lifecycle 優先用該固定版本支援的 enable/disable/install/uninstall command；若固定版本無 disable command，才可用官方 user-editable settings 面並先通過正向/反向 probe。禁止手刪 cache。

Exit：一份 timestamped baseline ledger；worktree 建立；live host surfaces 未變。

## 6. Phase 1 — Vendor stable 22（不啟用 setup）

### 1.1 安裝方式

在 temp dir clone/fetch assessed commit，驗證 commit 與 manifest hash，再由 manifest 逐項複製 22 個 skill directory 到 worktree `skills/<basename>`。

Preconditions：

- 22 個 basename 唯一；
- active `skills/` 無同名碰撞；
- 每支有 `SKILL.md`；
- 13 支 invocation-off 與 9 支 implicit-on 清單可由 Claude frontmatter / Codex `agents/openai.yaml` 重建。

禁止：

- 跑 `setup-matt-pocock-skills`；
- 跑 `scripts/link-skills.sh`；
- 跑 `copilot skill add` / `copilot plugins install --skill`，或把 22 支另裝到 `~/.copilot/skills`；
- clone 浮動 `main` 後不驗 SHA；
- 修改 22 支的 upstream payload。

### 1.2 Provenance 與 vendored detection

新增一個 machine-readable root lock（建議 `mattpocock-skills.lock`），內容只放：

- source URL；
- assessed commit；
- manifest hash；
- 22 個 active basenames。

沿用 `auditing-skill-folder` 的 vendored detector，補「列在 lock 的 directory = vendored」分支與最小 regression test；不要複製 22 份本機 wrapper 或 LICENSE。

`vendored-forks.md` 新增「unmodified vendored set」記錄，但 22 支不列為 fork。只有日後本機修改 upstream payload 才進 fork index。

### 1.3 驗證與 commit

- temp source 與 worktree 22 directories 做 recursive diff，僅允許 central lock / detector 等 house files 在 skill payload 外。
- `tests/vendored-detection.sh` PASS。
- auditing step 0 全部 22 支顯示 vendored。
- `agents-sync --check` PASS。
- `git diff --check` PASS。

Commit：

```text
chore(skills): vendor Matt stable 22
```

Exit：22 支存在於 worktree、版本一致、immutable、尚未部署到 live main。

## 7. Phase 2 — 補齊 carriers、setup adapter 與 neutral X1

### 2.1 Canonical delegation invariant

在 `skills/dev-workflow/SKILL.md` 新增跨階段 `[INT-4]`，S1/S2/S3/S5 引用：

- delegated subtasks 可獨立驗證；
- write ownership 不重疊，read-only evidence scope 不重疊；
- skill 契約內建固定 fan-out 隨該 skill 的使用授權成立；
- 不符合條件標 `SKIPPED`，不做 smoke spawn；
- subagent 回報不是完成證據，主 context 必須重驗。

Host adapters 只映射：

- Claude：`Agent` / `Task`
- Codex：`spawn_agent` / `wait_agent`
- Copilot：`task` 工具與 built-in agents；`--agent` 只用於 session 啟動時選 custom agent，不是 fan-out primitive。S3 write delegation 只有在當前 tool contract 明確允許且 ownership 不重疊時使用，否則標 `SKIPPED`

把 S3 既有重複句收斂為 `[INT-4]` 引用，避免新增第二份正本。

同批更新 `dev-workflow` Copilot guard 敘述：`~/.copilot/hooks/guard-git-push.{json,sh}` 已配置，不得再寫「現況未配置」；並註明 hooks 不在 `~/.copilot` git allowlist，變更時須另有 rollback carrier。

### 2.2 Workspace isolation

在 `core/tier1-workflow.md` 新增 `[T1-10]`，內容只指向既有 `bin/agents-branch`，不複寫工具檔頭的長篇理由。

驗證拆開：

- local `tests/conformance.sh`：live `~/.agents` main checkout 必須在 `main`；
- CI：temporary clone/worktree 測 `agents-branch` 行為，不對 runner branch 作 machine-local 斷言。

`conformance.sh` 維持 local-only，不加入 CI。

### 2.3 Writing / audit semantic migration

新增 house authority：

```text
skills/auditing-skill-folder/references/skill-standards.md
```

逐條把舊 standards 分成：

- Agent Skills spec；
- Matt `writing-great-skills`；
- house policy；
- Superpowers-specific，刪除。

更新：

- `skills/auditing-skill-folder/SKILL.md`
- `step7-style-checks.md`
- `scripts/count-words.sh`

不得把 user-invoked `writing-great-skills` 當成自動載入的唯一依賴；不得要求修改 vendored Matt frontmatter 以迎合舊尺。

### 2.4 Setup compatibility adapter

新增：

```text
docs/agents/issue-tracker.md
```

作為全域 fallback；repo 自有同路徑檔優先。內容至少含：

1. tracker operations；
2. local/GitHub carrier；
3. `Status:` state 記錄格式；
4. 2 個 category roles；
5. 5 個 state roles；
6. role → actual label mapping；
7. PR-as-triage-surface 預設 off；
8. Wayfinder map/child/blocking/claim/frontier/resolve；
9. Wayfinder `Type:` = research/prototype/grilling/task；
10. X1 neutral persistence paths；
11. `CONTEXT.md` / `CONTEXT-MAP.md` 規則；
12. 禁止 `.scratch/` 成為第二套持久化慣例。

在 routing / dev-workflow 加一條薄 adapter：

- repo contract 存在 → 使用 repo contract；
- 不存在 → 使用全域 fallback；
- 只有使用者明示 `/setup-matt-pocock-skills` 才可執行 setup；
- 其他 6 支 skill 不得因找不到 repo contract 自動跑 setup。

### 2.5 X1 中性化

把 active canonical paths 改為：

```text
docs/agents/specs/
docs/agents/plans/
sdd/<slug>/
```

歷史 `docs/superpowers/**` 與 `.superpowers/sdd/**` 不批次搬動；先標 historical / preserve，避免破壞既有連結。

### 2.6 Superpowers helper ledger

在 proposal 目錄新增 helper ledger，每項標 `re-home` 或 `drop + reason`：

- `sdd-workspace`
- `task-brief`
- `review-package`
- `find-polluter.sh`
- brainstorming `start-server.sh` / `stop-server.sh`
- `render-graphs.js`

只 re-home 真正有 live consumer 的最小能力；不搬未使用 helper。

### 2.7 Budget 與 commit

因 Copilot 已 9303B，所有 core/routing 新增必須同批刪除等量重複文字。驗收：

- `agents-sync --check` PASS；
- Codex/Copilot bytes 不淨增，或有明確等量刪除 evidence；
- `git diff --check` PASS；
- relevant tests PASS。

Commit：

```text
refactor(workflow): 補齊 Matt 跨主機載體
```

Exit：carriers、setup adapter、neutral X1 完整；仍未部署 live。

## 8. Phase 3 — Routing switch 與 first live-impact gate

### 3.1 Invocation-aware routing

模型自動路由不得指向 invocation-off skill：

| 現行 | Candidate model route | Explicit user entry |
|---|---|---|
| `mp-grill-with-docs` | `grilling` + `domain-modeling` | `/grill-with-docs` |
| `mp-improve-codebase-architecture` | `codebase-design` | `/improve-codebase-architecture` |
| `mp-diagnose` | `diagnosing-bugs` | 同名 explicit 可用 |
| `mp-tdd` | `tdd` | 同名 explicit 可用 |

Copilot 顯式入口是 prompt 內的 `/<skill-name>`，不是註冊型 slash command；不得因此把 Explicit user entry 標 `UNAVAILABLE`。

Claude 依 `disable-model-invocation`；Codex 依 `policy.allow_implicit_invocation`。Codex 必須在 `$HOME/.agents/skills` 實際驗證此 policy 生效；若不生效，記錄 observed behavior，不可修改 upstream metadata。

Copilot 官方 CLI reference 同樣定義 `user-invocable` 與 `disable-model-invocation`。但本機固定版本仍須用 vendored Phase 1 payload做 isolated parse / explicit / implicit canary；`skill list --json` schema 未顯示這兩欄不構成反證。若實測不生效，記錄 observed behavior，保留 setup explicit-only adapter，該 host gate 標 `FAIL` 或 `UNAVAILABLE`，不得推論成「全部可隱式觸發」。

### 3.2 Closeout 改為動作觸發

`[INT-1]`、S6、`[R-1]` 改以 push / open PR / merge / final closeout 動作定義，不再以 `finishing-a-development-branch` 名稱作觸發條件。

`implement` adapter 必須：

- 先建 `feat/` / `fix/` branch；
- 不允許 upstream 的「commit current branch」跳過 S4–S6。

### 3.3 Two-axis code review

S5 接 Matt `code-review` 的 Standards / Spec 兩軸，兩軸各標：

- PASS
- FAIL
- SKIPPED + reason
- UNAVAILABLE + probe evidence

無 spec 的 LIGHT task，Spec 軸可合法 SKIPPED。Codex carrier 是 `spawn_agent` / `wait_agent`，不是 `agents/openai.yaml`。

### 3.4 First live-impact stop

先在 worktree完成：

- full diff review；
- tests / lint；
- `agents-sync --check`；
- proposed live deploy diff；
- rollback commands；
- Copilot description coverage / dynamic retrieval baseline 與 invocation canary 設計；
- `~/.copilot/copilot-instructions.md` 既有 dirty hunk 的歸屬、before diff 與可讀回 rollback。

**停下，向使用者回報並取得「部署 candidate」確認。**

確認後才把 Phase 1–3 commits 整合到 live `~/.agents/main`，再：

```bash
~/.agents/bin/agents-sync --bootstrap
~/.agents/bin/agents-sync --doctor
bash ~/.agents/tests/conformance.sh
```

驗證 Claude routing stamp 與 Codex/Copilot manifest 可讀回。任一部分成功、部分失敗 → 立即 rollback，不進 canary。

## 9. Phase 4 — Isolated A/B canary

### 4.1 兩種用途分開

- **Migration safety canary**：每 host 覆蓋 feature、bugfix、diagnosis、review、architecture、closeout 各至少 1 次，加一個缺 evidence 反向 probe。
- **能力改善宣稱**：每類至少 3 次重複、A/B 順序 counterbalanced；未達樣本量只能寫 `UNAVAILABLE`，不可宣稱已改善。

### 4.2 固定變因

- Codex：`gpt-5.6-sol`、effort `high`、CLI version、approval/sandbox 相同。
- Claude：`claude-opus-5`、effort/thinking/ultracode 狀態、CLI version、permission 相同。
- Copilot：固定 executable 絕對路徑、CLI version、具體 model id（禁 `auto`）、effort、context tier、mode、dynamic retrieval、`disabledSkills` 狀態、allowed tools / permission；若使用 desktop/app，另以 authoritative version probe 固定，不用 backup 檔名推測。
- 同一 workspace commit、task input、acceptance criteria、external state。
- 唯一主要變因 = workflow stack。

### 4.3 Arms

- Arm A：現行 kernel + Superpowers + active `mp-*`。
- Arm B：candidate thin kernel + Matt 22；該 host 的 Superpowers 暫停；4 支舊 `mp-*` 移出 active root 但可回復。

不得長期並存。只允許一次 deliberate collision probe，其餘 Arm B 都必須隔離。

`mp-*` 的隔離要 `git mv skills/mp-* attic/`；只刪 Claude symlink 會被 `agents-sync --bootstrap` 自癒。

### 4.4 逐 host 停用與新 session

每個 host 分別：

1. 用該固定版本實際支援、且已通過 rollback probe 的 lifecycle/config 機制停用 Superpowers；Copilot CLI 1.0.75 無 disable command 時，只能在 mode `0600` backup 後精確修改 `settings.json.enabledPlugins` 單一 key；
2. 開新 session；
3. inventory 證明 Superpowers 不在 active context；
4. 跑同一 corpus；
5. rollback 後讀回 plugin state 與 generated state。

禁止用 Claude 的觀測代替 Codex；禁止手刪 plugin cache。

Copilot inventory 至少包含 `copilot skill list --json`、`copilot plugin list`、`dynamicRetrieval.skills`、`disabledSkills` 的 set/unset + 成員數、`settings.json.enabledPlugins` 指定 key 與 `config.json.installedPlugins` 對應 entry；兩個 plugin state 面不一致即 FAIL。

### 4.5 Trigger ledger

每筆至少記：

- timestamp
- Host / model / effort / CLI
- task class / arm / run order
- intended skill
- actual skill
- invocation gate
- collision / double execution
- unnecessary clarification / approval
- tool calls / retries / turns
- evidence / review / closeout completeness
- tokens / latency（僅佐證）
- success / first-pass success

否決項：

- 缺 evidence 卻宣稱完成：任何 1 次即該 host FAIL。
- routing collision / double execution：任何非 deliberate probe 即 FAIL。

Exit：Claude、Codex、Copilot 各自 `PASS` / `FAIL` / `UNAVAILABLE`；不得合併 verdict。

## 10. Phase 5 — `mp-*` parity 與 retirement

完成 17 檔 ledger，逐檔標：

- identical
- local-subset
- upstream-superset
- local-unique
- semantically-different
- action / destination / reason

必查 local-unique / local-superset：

- `mp-grill-with-docs/CONTEXT-FORMAT.md` 的 3 節 + 3 條規則
- `mp-tdd/references/tracer-bullet.md`
- `mp-diagnose/references/feedback-loop.md`
- `mp-improve-codebase-architecture/INTERFACE-DESIGN.md`
- `mp-improve-codebase-architecture/LANGUAGE.md`
- `mp-tdd/refactoring.md`
- `mp-improve-codebase-architecture/DEEPENING.md` 的 local cross-reference

只有已 re-home 或明確放棄的檔案才可退休。結論寫入 `vendored-forks.md`，再：

```bash
git mv skills/mp-diagnose attic/
git mv skills/mp-grill-with-docs attic/
git mv skills/mp-improve-codebase-architecture attic/
git mv skills/mp-tdd attic/
```

保留 `mp-zoom-out`。

Commit：

```text
refactor(skills): 退休重複 mp workflow
```

Rollback：revert 此 commit，`agents-sync --bootstrap`，new-session inventory。

## 11. Phase 6 — 12 項移除 gate 與逐 host Superpowers retirement

前提：以下 arm B 都是該 host 已停用 Superpowers並以新 session證明未載入。

1. Active Superpowers references 依 baseline 固定清單逐檔核銷；最後再跑 repo-wide active-reference probe。X1 已中性化；歷史路徑已標 historical。
2. 4 支 `mp-*` 的 17 檔 parity ledger 完成；local-unique 已 re-home 或有明確放棄決策；fork debt 已登錄。
3. `[T0-2]` + S4–S6 已在 arm B 承接 verification-before-completion，且缺 evidence 反向 probe 為 0 次錯誤完成。
4. Closeout gate 已改為動作定義；branch/PR/CI closeout 在 arm B 完整跑過。
5. Red→green bugfix gate 在 arm B 有真實紅燈 evidence。
6. `code-review` 兩軸各標四態；Claude、Codex、Copilot 各有實際可執行 carrier。Copilot 使用 `task` / built-in agent，`--agent` 不算 fan-out，presentation metadata 不算執行證據。
7. `[T1-10]` 指向 `bin/agents-branch`；local conformance 與 portable CI test 分離且皆綠。
8. `implement` 被 adapter 攔回 branch + S4–S6，沒有直接 commit main/current branch。
9. 三 host new-session inventory / canary / rollback 後置條件可機械讀回；任一 host rollback 讀不回即 FAIL。
10. Stable 22 單一來源、同 commit、只曝光 manifest 22；setup adapter、delegation、writing/audit semantics、helper ledger 全部成立。
11. Invocation contract 逐 host 對齊；Claude/Codex 的 model route 不指向 invocation-off skill；Copilot 依官方 `user-invocable` / `disable-model-invocation` 契約，並以固定版本 canary 驗證實際行為。
12. Copilot skill discovery / routing 已驗證：記錄靜態 full-description 涵蓋、名稱尾巴、dynamic retrieval 狀態與實際 intended/actual skill；不得只用「前 30 支」觀測宣稱後續 skill 無法自動 routing。

Gate scope：

- host-agnostic：#1、#2、#7、#10；
- per-host：#3–#6、#8、#9、#11；
- Copilot-only：#12。

移除某一 host 前，先向使用者顯示完整 gate ledger；host-agnostic gates 與該 host 適用的 per-host gates 必須全 PASS，再取得該 host 的移除確認。某 host 的 gate 為 `UNAVAILABLE` 只阻擋該 host，不連坐其他已達標 host；Copilot 可保持 installed + disabled。

移除順序：

1. Claude
2. Codex
3. Copilot（若 lifecycle 與 canary 可驗；否則保持 installed/disabled 並標 UNAVAILABLE）

每次只處理一 host：

1. 使用 host-supported uninstall；
2. new session inventory；
3. 最小真實任務 smoke；
4. PASS 才進下一 host；
5. FAIL 時立即走該 host 已驗證的 rollback 並讀回 state、停止。若 Copilot 無可重現的 pinned 6.2.0 reinstall，保持 installed + disabled，不執行 uninstall；不得把 marketplace 當下 latest 當 pinned rollback。

禁止手刪 cache、禁止一次移除三家。

## 12. Phase 7 — Thin kernel trim 與穩定期

至少經過數個真實任務且無 rollback 後才縮薄 kernel：

保留：

- tier0 safety / authorization
- risk-triggered plan gate
- red→green
- `[INT-4]`
- evidence / review / closeout
- worktree / hooks / local conformance / CI
- 必要的 re-homed helpers

刪除：

- 已由 Matt task skill 承接的長篇方法論
- 重複 approval/safety prose
- 以 retired skill 名稱作觸發的句子
- dead adapter / Superpowers version check

每批先量 before/after bytes；`agents-sync --check`、`--doctor`、local conformance、new-session FP/skill inventory 全綠。

Commit：

```text
refactor(workflow): 縮薄全域開發 kernel
```

## 13. 最終驗證

必跑：

```bash
git diff --check
~/.agents/bin/agents-sync --check
~/.agents/bin/agents-sync --doctor
bash ~/.agents/tests/conformance.sh
bash ~/.agents/tests/vendored-detection.sh
```

另跑所有受影響的 shell tests、CI、Claude/Codex/Copilot new-session inventory、active-reference probe、22-skill source diff、plugin state probe。

DCT MySQL E2E：`SKIPPED`。理由：本案只改全域 workflow/config/plugin，不改 DCT runtime、schema 或 importer；跑 real-data E2E 不會驗證本案風險。

完成宣稱必附：

- per-phase commits
- before/after bytes
- sync/doctor/conformance output
- per-host inventory
- canary ledger
- 12-gate ledger
- rollback commands與讀回結果

## 14. Claude Code 新 session 指令

```text
請依照以下文件開始實作全域 workflow migration：

/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/13-cross-host-implementation-plan.md

這段指令是依該 plan 完成 Phase 0–3 isolated candidate 的明確授權，不授權 live deployment。請先完整讀取文件指定的 08→07→09→10→11→12→13→14，以及 live dev-workflow／CONVENTIONS／vendored-forks。

要求：
1. 先重跑 Phase 0 live probes，所有 live config/plugin observations 標 Asia/Taipei 時刻。
2. 不得碰既有 dirty changes；~/.agents 必須用 bin/agents-branch 建 codex/mattpocock-workflow-migration worktree，禁止在 live main 切 branch。
3. 在 isolated worktree 完成 Phase 1–3 candidate，逐 phase commit、test、回報 evidence。
4. 不執行 setup-matt-pocock-skills、不執行 upstream scripts/link-skills.sh、不修改 vendored upstream payload。
5. Phase 3 worktree candidate 完成後，在首次 live deployment 前停止，提供 diff、tests、byte budget、rollback，等我回覆「部署 candidate」。
6. 不得在同一輪移除 Superpowers；host-agnostic + 該 host 適用 gates 全 PASS 且我再次確認後才可移除該 host。
7. 三 host 共用 source-of-truth，但 invocation/delegation/plugin/canary 分 host；不得跨 host 外推。

回覆使用：目前 Phase / 變更摘要 / evidence / 風險 / rollback / 下一個 gate。
```

## 15. Codex 新 session 指令

```text
請依照以下文件開始實作全域 workflow migration：

/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/13-cross-host-implementation-plan.md

這段指令是依該 plan 完成 Phase 0–3 isolated candidate 的明確授權，不授權 live deployment。先完整讀取 08→07→09→10→11→12→13→14，以及 live dev-workflow／CONVENTIONS／vendored-forks。

要求：
1. 先做 Phase 0 read-only revalidation，live observations 標 Asia/Taipei 時刻。
2. 用 ~/.agents/bin/agents-branch 建 isolated worktree；保留 live main 與所有既有 dirty/untracked changes。
3. Phase 1–3 只可在 worktree 修改；逐 phase commit並附 tests。
4. 不執行 setup-matt-pocock-skills / scripts/link-skills.sh，不修改 vendored payload。
5. Phase 3 worktree candidate 完成後，在 live deployment gate 停下，提供完整 diff、tests、byte budget、rollback，等我回覆「部署 candidate」。
6. Codex delegation carrier 是 spawn_agent/wait_agent；但只有 user/repo instructions 明確允許 delegation 時才可使用。未允許就 inline 完成並標 SKIPPED，不能 smoke spawn。
7. Phase 4 的 Codex A/B 必須固定 gpt-5.6-sol、effort high 與權限；不得用 Claude canary 代替。
8. host-agnostic + 該 host 適用 gates 全 PASS 且我再次確認前，不得移除該 host 的 Superpowers；某 host `UNAVAILABLE` 不連坐其他 host。

回覆使用：目前 Phase / 變更摘要 / evidence / 風險 / rollback / 下一個 gate。
```

## 16. Copilot 新 session 指令

```text
請依照以下文件開始實作全域 workflow migration：

/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/13-cross-host-implementation-plan.md

這段指令只授權依 plan 完成 Phase 0–3 isolated candidate，不授權 live deployment。先完整讀取 08→07→09→10→11→12→13→14，以及 live dev-workflow／CONVENTIONS／vendored-forks。

要求：
1. 先做 Phase 0 read-only revalidation，固定 Copilot executable 絕對路徑、CLI version、model、effort、context、mode、dynamic retrieval、disabledSkills 與 plugin/skill inventory。
2. 不碰既有 dirty copilot-instructions.md；Phase 1–3 只在 bin/agents-branch 建立的 isolated worktree 修改。
3. 不執行 setup-matt-pocock-skills、scripts/link-skills.sh、copilot skill add 或 copilot plugins install --skill；不修改 vendored payload。
4. 官方 invocation contract 含 user-invocable / disable-model-invocation；本機版本必須用 canary 驗證，不能從 skill list JSON schema 推論。
5. Phase 3 worktree candidate 完成後，在首次 live deployment 前停止，提供 diff、tests、byte budget、description/dynamic-retrieval probe、dirty-hunk 歸屬與 rollback，等我回覆「部署 candidate」。
6. host-agnostic + Copilot 適用 gates 全 PASS 且我再次確認前，不得移除 Copilot Superpowers；若有 `UNAVAILABLE` 或無 pinned reinstall，維持 installed + disabled。

回覆使用：目前 Phase / 變更摘要 / evidence / 風險 / rollback / 下一個 gate。
```

## 17. Stop conditions

任一成立立即停止，不自行擴權：

- upstream pin / manifest drift；
- 進入 Phase 3 時 target dirty hunk overlap 仍未裁定；
- sync/doctor/conformance FAIL；
- generated host state 部分成功；
- invocation behavior 與 plan 不同；
- plugin lifecycle 無 supported reversible path；
- any host 缺 evidence 卻宣稱完成；
- 進行某 host 移除時，host-agnostic 或該 host 適用 gates 任一未 PASS；
- 需要修改本計畫未授權的 repo/runtime。

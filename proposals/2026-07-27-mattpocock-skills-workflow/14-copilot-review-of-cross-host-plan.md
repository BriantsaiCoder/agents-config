# Copilot review：cross-host implementation plan（文件 13）的 Copilot-specific 審查

> 日期：2026-07-27
> 性質：read-only review。本輪唯一寫入為本檔；未安裝、部署、修改、停用或移除任何 skill、plugin、設定或 generated file。未執行 `agents-sync` 部署路徑（只跑 `--check` dry-run 與 `--doctor` 唯讀巡檢）。
> 被審對象：[13-cross-host-implementation-plan.md](13-cross-host-implementation-plan.md) 的 Copilot 部分。
> 讀取順序（依 13 §5 0.1 指定）：[08](08-codex-final-proposal.md) → [07](07-review-of-codex-final.md) → [09](09-codex-reconciled-final-for-claude-review.md) → [10](10-claude-review-of-reconciled-final.md) → [11](11-codex-review-of-claude-feedback-and-gpt56-assessment.md) → [12](12-claude-review-of-codex-feedback-and-dual-host-assessment.md) → 13，加 `~/.agents/skills/dev-workflow/SKILL.md`、`~/.agents/core/routing.md`、`~/.agents/bin/agents-sync`，全部已完整讀取。
> 執行者：GitHub Copilot（desktop app session），model = Claude Opus 5（`claude-opus-5`）。
> 觀測窗：**2026-07-27 17:17–17:31 Asia/Taipei**。所有 live 觀測皆標時；未輸出任何 secret 值（config/settings 只列 key 與布林/結構）。

## Codex validation addendum（2026-07-27 17:42 Asia/Taipei）

> 本節保留 Copilot 原始 review，不回寫其歷史敘述；若與下文衝突，以本 addendum 與已修訂的文件 13 為 implementation gate。Codex 本輪只做 read-only local probes 與 GitHub 官方文件核對，未部署 workflow、skill 或 plugin。

### 驗證裁決

- **維持成立**：C2（限本機 Copilot CLI 1.0.75）、C4、C6–C13 的方向。17:42 重跑仍為 128 skills（personal-agents 50 / plugin 77 / builtin 1）、Superpowers 6.2.0 enabled、`copilot plugins list --json` unavailable、`agents-sync --check/--doctor` PASS、`copilot-instructions.md` 3 additions / 3 deletions。
- **C1 降級並改 gate 位置**：前 30 支 full description 是單一 session 的有效觀測，但固定筆數、截斷規則與 routing impact 尚未證明；官方另有 embeddings-based `dynamicRetrieval.skills`。且文件 13 的 Phase 1–3 candidate 都在 isolated worktree，不會改 live `~/.agents/skills`，所以 C1 不阻擋 candidate 製作，改為 Phase 3 deployment / Phase 4 blocker。
- **C3 / A3 / A4 / gate 11 原裁決撤回**：GitHub Copilot CLI 官方 reference 明列 skill frontmatter `user-invocable` 與 `disable-model-invocation`。`copilot skill list --json` 不輸出 invocation 欄不能證明不支援，也不能推出 13 支 invocation-off skills 全部可隱式觸發。本機 CLI 1.0.75 的實際行為仍要以 isolated canary 驗證。
- **C5 降級**：`data.db.pre-update-backup-1.1.0-*` 不是 authoritative runtime identity。canary 應固定實際 executable 絕對路徑與 `--version`；若另測 desktop/app，再用該 runtime 的 authoritative version probe。
- **C2 加版本邊界**：官方目前文件化 `copilot plugin enable/disable`，但本機兩個 1.0.75 executable 的 help 確實只有 install/list/marketplace/uninstall/update。implementation 必須固定版本並以 live help 為準，不得把新版文件能力外推到 1.0.75。

官方依據：

- [GitHub Copilot CLI command reference — Skills reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference)
- [GitHub Copilot CLI configuration directory — `dynamicRetrieval` / `enabledPlugins`](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
- [GitHub Copilot CLI plugin reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference)

### 修訂後執行裁決

Phase 0–3 isolated candidate 可進行。Phase 3 live deployment 維持 `NO-GO`，直到 Copilot invocation canary、description/dynamic-retrieval probe、plugin rollback 與 dirty generated hunk 歸屬全部有 evidence。Copilot 若沒有可重現的 pinned 6.2.0 reinstall，Phase 6 終態保持 `installed + disabled`，不得 uninstall。

### 第二輪 Copilot focused review disposition（2026-07-27 18:0x Asia/Taipei）

第二輪 review 的 F1–F4 全部採納並已納入文件 13：

- F1：Phase 6 改為 host-agnostic + per-host gate；某 host `UNAVAILABLE` 只阻擋該 host。
- F2：補 Copilot prompt 內 `/<skill-name>` explicit entry。
- F3：Phase 2 納入 `dev-workflow` hooks 現況修正與非 git-tracked rollback 說明。
- F4：Phase 0 / Phase 4 納入 `disabledSkills` 的 set/unset + count probe。

同時澄清 Phase 3 停點：可在 isolated worktree 完成 Phase 3 candidate；必須在整合進 live `~/.agents/main` 或執行 `agents-sync --bootstrap` 前停止，等待使用者回覆「部署 candidate」。因此最新裁決為：**Phase 0–3 isolated candidate 可開始；Phase 3 live deployment 維持 `NO-GO`**。

---

## 0. 本輪 Copilot live baseline（2026-07-27 17:17–17:31 Asia/Taipei）

| Surface | 觀測 | 時刻 | 指令 |
|---|---|---|---|
| Copilot CLI（PATH 兩份） | `~/.local/bin/copilot` 與 `/opt/homebrew/bin/copilot` **皆回報 1.0.75** | 17:18 / 17:19 | `which -a copilot`；`<path> --version` |
| Copilot app runtime | `~/.copilot/data.db.pre-update-backup-**1.1.0**-1785143803131`，mtime 17:16（本 session 啟動時產生） | 17:19 | `ls ~/.copilot \| grep pre-update` |
| Skill inventory | **128 支**：`personal-agents` 50 / `plugin` 77 / `builtin` 1；**全部 `enabled: true`** | 17:20 | `copilot skill list --json` |
| `~/.agents/skills` 載入 | **50/50 全載入**，`source=personal-agents`、`path=/Users/pochientsai/.agents/skills/<name>`；磁碟未載入者僅 `.DS_Store`、`.claude` | 17:20 | 同上 + `os.listdir` 差集 |
| Skill metadata schema | 每筆僅 5 欄：`name` / `description` / `source` / `path` / `enabled`。**無任何 invocation-mode 欄位** | 17:20 | 同上 |
| 常駐 description 注入 | 本 session `<available_skills>` 有 **30 個完整 `<skill>` 區塊**，恰為 `personal-agents` 依字母序前 30 名；其餘 98 支只出現在 `Additional skills available (invoke by name): …` 名稱尾巴 | 17:17 | 本 session system prompt（第一手） |
| `~/.copilot/skills` | 空目錄（mtime 2026-05-03） | 17:19 | `ls -la ~/.copilot` |
| Generated instructions | `~/.copilot/copilot-instructions.md`，**9303B**，banner `@1454e39 hash:4875731b` | 17:19 | `wc -c` / `head -3` |
| `~/.copilot` git 狀態 | 僅 `M copilot-instructions.md`（1 檔、3 insert / 3 delete） | 17:19 | `git -C ~/.copilot status --short` |
| Superpowers（Copilot） | `superpowers@superpowers-marketplace` **v6.2.0**，`installed_at 2026-07-27T02:07:49.589Z`，`config.json.installedPlugins[].enabled = true`，且 `settings.json.enabledPlugins["superpowers@superpowers-marketplace"] = true` | 17:24 / 17:27 | `copilot plugin list`；config/settings 結構讀取 |
| 已安裝 plugin 總數 | 18 支（含 superpowers），來自 7 個註冊 marketplace | 17:22 | `copilot plugin list`；`copilot plugin marketplace list` |
| `copilot plugins`（統一 enable/disable） | `--help` 存在並文件化 `enable` / `disable` / `remove`，但**實際執行回 `The plugins command is not available.`**，加 `--experimental` / `COPILOT_EXPERIMENTAL=1` 皆同 | 17:25–17:26 | `copilot plugins list --json`；`copilot --experimental plugins list --json` |
| `agents-sync --check` | lint PASS；codex 8563B / copilot **9303B**，budget 10240B（Copilot 用量 **90.9%**，headroom 937B） | 17:24 | `bin/agents-sync --check` |
| `agents-sync --doctor` | 全綠 exit 0；`.copilot/copilot-instructions.md` manifest 相符 ✅、出處戳記 `@1454e39 == 來源` ✅ | 17:24 | `bin/agents-sync --doctor` |
| `~/.agents` | branch `main`、HEAD `19be2eb`；untracked 為 10/11/12/13 與另一 proposal | 17:24 | `git -C ~/.agents status --short` |
| Copilot hooks | `~/.copilot/hooks/guard-git-push.json`（`preToolUse` command hook）+ `.sh` **已存在且已配置** | 17:23 / 17:28 | `ls -R ~/.copilot/hooks`；`head guard-git-push.json` |
| `~/.copilot/agents` | **空**（無 user-level `*.agent.md`） | 17:23 | `ls -R ~/.copilot/agents` |

官方文件 baseline（本輪讀取，非沿用他檔）：

| 來源 | 用途 | 時刻 |
|---|---|---|
| `https://docs.github.com/en/copilot/concepts/agents/about-agent-skills` | Copilot personal skill roots 含 `~/.agents/skills` | 17:30 |
| `https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills` | SKILL.md frontmatter 契約、`/SKILL-NAME` 顯式呼叫、`/skills` 開關 | 17:30 |
| `https://docs.github.com/en/copilot/concepts/agents/about-plugins` | `enabledPlugins` 為官方宣告式安裝／啟用面 | 17:29 |
| `https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing` | plugin install/update/uninstall；**無版本 pin 語法** | 17:31 |

---

## 1. 總裁決

**有條件相容。**

架構主張（thin kernel + Matt stable 22、Superpowers 最後移除）在 Copilot 端沒有結構性阻礙；`~/.agents/skills` 是 Copilot 官方文件明列的 personal skill root，且本輪實測 50/50 全載入。但文件 13 對 Copilot 的三項核心假設與 live evidence 不符，其中兩項會讓 Phase 1 與 Phase 4 在 Copilot 上量到錯的東西：

1. **Copilot 只把前 30 支 personal skill 的 description 注入常駐面**（第一手觀測）。Vendoring 22 支會把 9 支現有 skill 的 description 擠出常駐面，同時把 13 支 Matt skill（含 `tdd`、`implement`、`to-spec`、`to-tickets`、`triage`、`wayfinder`）留在只有名字的尾巴。這是三 host 中只有 Copilot 會發生的靜默降級，且無法從 Claude／Codex 外推。
2. **Copilot 的 invocation contract 不是 `UNAVAILABLE`，而是「已確認不存在等價欄位」**。官方文件逐項列舉 Copilot 支援的 SKILL.md frontmatter（`name` / `description` / `license` / `allowed-tools`），並明寫「Copilot will decide when to use your skills based on your prompt and the skill's description」；`copilot skill list --json` 的 schema 亦無 invocation 欄。文件 12 §E1 與文件 13 §8 3.1 把 Copilot 標成 UNAVAILABLE 是**過度保守**，會讓 gate 11 永遠停在待測。
3. **Copilot 的 plugin lifecycle 與計畫寫的不同**。`copilot plugins disable` 在 1.0.75 上不可用；可用的 disable 面是 `~/.copilot/settings.json` 的 `enabledPlugins`（官方文件承認的宣告式面），而該檔與 `config.json` **都不在 `~/.copilot` 的 git allowlist** —— 文件 13 §5 0.4「repo 本身是 rollback carrier」對 Copilot plugin state 不成立。

另外，文件 13 §5 0.2 的兩條 stop condition 在本輪**已經命中**：host identity 無法固定（C5）、既有 dirty hunk 與本計畫 target 區重疊（C6）。

---

## 2. Findings（依嚴重度排序）

### C1 — Copilot 只注入前 30 支 personal skill 的 description；vendoring 22 支會靜默擠掉 9 支｜**阻斷級（Phase 1）· confirmed defect**

**證據（第一手，17:17）**：本 session 的 `<available_skills>` 含 **30 個完整 `<skill>` 區塊**，逐支比對等於 `copilot skill list --json` 中 `source=personal-agents` 依字母序的前 30 名（`acquire-codebase-knowledge` … `native-feel-cross-platform-desktop`）。其餘 98 支（含全部 77 支 plugin skill）只出現在 `Additional skills available (invoke by name): …` 的名稱清單，**description 未進 context**。

**模擬（唯讀計算，17:21）**：把 manifest 22 支 basename 併入現有 50 支後重排：

| 情境 | 被擠出常駐 description 的現有 skill | 落在名稱尾巴的 Matt skill |
|---|---|---|
| Phase 1（50+22=72） | `init-project-docs`、`jest-best-practices`、`mp-diagnose`、`mp-grill-with-docs`、`mp-improve-codebase-architecture`、`mp-tdd`、**`mp-zoom-out`**、`mysql-best-practices`、`native-feel-cross-platform-desktop` | `implement`、`improve-codebase-architecture`、`prototype`、`research`、`resolving-merge-conflicts`、`setup-matt-pocock-skills`、**`tdd`**、`to-spec`、`to-tickets`、`triage`、`wayfinder`、`teach`、`writing-great-skills`（13 支） |
| Phase 5（退休 4 支 `mp-*` 後 = 68） | 同上（`mp-zoom-out`、`mysql-*`、`native-feel-*`、`init-project-docs`、`jest-*` 仍在外） | 同上 13 支 |

三個具體傷害：

- **`tdd` 是 plan 依賴的 model-invoked 主力**（文件 12 §E1 的 implicit-on 9 支之一）。在 Copilot 上它只有名字沒有 description，而 Copilot 官方明載路由依 description 決定 → Copilot 的 TDD 自動路由結構上劣於 Claude／Codex。
- **`mp-zoom-out` 是計畫明確保留的唯一 `mp-*`**（13 §2 決策 6、§10），但它會被擠出常駐面；Phase 5 退休其餘 4 支也救不回來。
- Phase 5 之後仍有 13 支 Matt skill 只有名字 → Phase 4 Copilot canary 的 routing 指標會系統性偏低，且會被誤讀成「Matt skills 在 Copilot 表現較差」。

**未確認的部分（不得推論）**：截斷規則是「固定 30 支」還是「位元組預算」尚未直接驗證；`source` 優先序（personal 先於 plugin）已由觀測支持，但未見官方文件聲明。→ 見第 8 節的唯一 next action。

### C2 — Copilot plugin lifecycle 與計畫不符：`plugins disable` 不可用、reinstall 無法 pin 版本、plugin state 不在版控｜**阻斷級（Phase 4/6）· confirmed defect**

| 計畫語句 | live evidence | 判定 |
|---|---|---|
| §9 4.4「用支援的 lifecycle/config 機制停用 Superpowers」 | `copilot plugins disable superpowers --plugin` → `The plugins command is not available.`（1.0.75，加 `--experimental` 亦同，17:25–17:26） | **CLI disable 路徑 UNAVAILABLE** |
| 同上 | 官方 about-plugins（17:29）：plugin 可由 `~/.copilot/settings.json` 的 `enabledPlugins` 宣告式管理；本機該 key 存在且 `superpowers@superpowers-marketplace: true`（17:27）。互動式另有 `/plugin`、`/skills` 開關 | **可用替代面存在，但本機從未驗證過「設 false 後新 session 真的不載入」** |
| §11「FAIL 立即 reinstall pinned Superpowers 6.2.0」 | `copilot plugin install --help`（17:26）與官方 plugins-finding-installing（17:31）皆**無版本參數**；`install` 只接 `plugin@marketplace` / `owner/repo` / URL | **pinned reinstall UNAVAILABLE**（只能拿 marketplace 當下版本） |
| §5 0.4「`~/.copilot` … repo 本身是 rollback carrier；不建立 `*.bak`」 | `~/.copilot/.gitignore` 為 allowlist 模式，只追蹤 `copilot-instructions.md`、`mcp-config.json`、`permissions-config.json`、`agents/`、`instructions/`、`prompts/`；`config.json`、`settings.json`、`installed-plugins/`、`hooks/` **皆未追蹤**（`git ls-files` 計數 0，17:27） | **對 Copilot plugin/hook state 為假**；rollback 需另存機械快照 |

計畫§11 已寫「禁止手刪 cache」——這條在 Copilot 上正確且必須保留（`~/.copilot/installed-plugins/superpowers-marketplace/superpowers` 是 CLI 自管 cache）。但它必須配一條可用的 supported path，否則 Phase 6 第 5 步「FAIL 立即 reinstall pinned 6.2.0」在 Copilot 上沒有可執行語意。

### C3 — 把 Copilot invocation contract 標成 UNAVAILABLE 是錯的；正確狀態是「已確認的契約分歧」｜**高 · confirmed defect**

文件 13 §2 決策 9、§8 3.1（line 332）、§11 gate 11（line 489）都寫「Copilot 沒有可引用的官方 invocation contract 時標 `UNAVAILABLE`，只以 canary 判斷」。本輪取得兩項一致證據：

1. **官方文件逐項列舉 Copilot SKILL.md frontmatter**（add-skills，17:30）：`name`（required）、`description`（required）、`license`（optional）、`allowed-tools`（optional）。**沒有** `disable-model-invocation`，也沒有任何 policy sibling 檔的概念（Matt 的 `agents/openai.yaml` 在 Copilot 完全不被解讀，只會被當成 skill 目錄內的普通檔案）。
2. **官方明述路由語意**：「When performing tasks, Copilot will decide when to use your skills based on your prompt and the skill's description.」+ `copilot skill list --json` schema 無 invocation 欄（17:20）。

→ 正確結論：**Copilot 對那 13 支 upstream invocation-off 的 skill 一律視為可隱式觸發**。這不是「無法判定」，是「已判定為不同」。實務影響有二：

- Phase 3 的 routing map 修正（`grilling` + `domain-modeling`、`codebase-design`）在 Copilot 端**不必要但無害**——替代目標在 Copilot 一樣可隱式觸發，所以三 host 可共用同一份 map，不需分岔。
- 反向風險：Claude／Codex 刻意關掉隱式觸發的 `implement`、`to-tickets`、`wayfinder`、`setup-matt-pocock-skills` 等，在 Copilot 上會**自動被模型選中**。其中 `setup-matt-pocock-skills` 若被自動觸發，正是 07 §3、09 §五、13 §7 2.4 全力防堵的情境（寫 `docs/agents/*`、改 AGENTS.md、引入 `.scratch/`）。**Copilot 是三 host 中唯一需要以 prose adapter 補這道閘的**（見第 3 節 A4）。

唯一仍待實測者：Copilot 遇到未知 frontmatter key（`disable-model-invocation`）是否仍能正常 parse 該 SKILL.md。這是 Phase 1 exit 的一個 probe，不是 gate 11 的無限期 UNAVAILABLE。

### C4 — Copilot 在 Phase 4 / §13 / §14–15 全程缺席，但 gate 9 要求三 host｜**高 · confirmed defect（流程可執行性）**

| 位置 | 內容 | 問題 |
|---|---|---|
| §9 4.2「固定變因」（line 385–387） | 只列 Codex（`gpt-5.6-sol` / high / CLI / approval）與 Claude（`claude-opus-5` / effort / thinking / ultracode / permission） | **Copilot 整列缺席**。Copilot 可用 `--model`、`--effort`、`--context <tier>`、`--mode` 固定，且**必須排除 `auto` model**（`copilot --help`，17:18–17:19），否則 arm A/B 的 model 可能不同 |
| §9 4.4 | 「每個 host 分別：停用 Superpowers → 新 session → inventory 證明不在 active context」 | Copilot 的 inventory 指令未指定；正確者為 `copilot skill list --json`（可機械斷言 14 支 superpowers skill 消失）+ `copilot plugin list` |
| §13 最終驗證（line 550） | 「Claude/Codex new-session inventory」 | **漏 Copilot**，與 §11 gate 9「三 host … 任一 host rollback 讀不回即 FAIL」矛盾 |
| §14 / §15 | 只有 Claude Code 與 Codex 的新 session 指令 | **無 Copilot session 指令**。Phase 4 與 Phase 6 都要求 Copilot 實際跑，卻沒有授權文本與執行者 |

### C5 — Copilot host identity 目前無法固定（Phase 0 stop condition 已命中）｜**中高 · migration risk**

PATH 上兩個 binary（`~/.local/bin/copilot`、`/opt/homebrew/bin/copilot`）都回報 `1.0.75`（17:18–17:19），但本 session 於 **17:16** 產生 `data.db.pre-update-backup-1.1.0-…`，代表跑本 session 的 app runtime 是 **1.1.0**。§5 0.2 的停止條件「host identity 無法固定」字面命中；§3 baseline 表記的「Copilot CLI 1.0.75」也因此不足以代表 canary 實際跑的 runtime。

這同時解釋 C2：`copilot plugins` 子命令在 1.0.75 CLI 上 gated off，但可能在 1.1.0 runtime 或後續版本可用 —— 所以 lifecycle 判定必須綁定「哪一個 runtime」，不能只記一個版號。

### C6 — `~/.copilot/copilot-instructions.md` 既有 dirty hunk 正落在本計畫 target 區｜**中高 · migration risk（Phase 0 stop condition 已命中）**

`git -C ~/.copilot diff`（17:19）顯示 3 處變更，全部在 **routing 區塊**：banner sha、「逐名點名 skill」行、「工具鏈／專項」行。而 Phase 2（§7 2.7）與 Phase 3（§8 3.1）要改的正是 `core/routing.md` → 同一個 hunk。

§5 0.2 停止條件「dirty changes 與本計畫 target hunk 重疊 → 停止」命中。

性質判定（降低誤判）：這不是手改，而是**已部署但未 commit 的生成產物**——`--doctor`（17:24）顯示 manifest 相符、banner `@1454e39 == 來源`，即 live 檔比 `~/.copilot` 的 git HEAD 新。所以正確處置不是「還原」，而是**在 Phase 0 明確裁定它的歸屬**（先單獨 commit 這個生成產物，或明文標為 out-of-scope 並在 Phase 3 部署後一併說明），否則 Phase 3 的 live deploy 會把它和 migration 變更混在同一個未 commit 狀態，rollback 無法區分。

### C7 — `--agent` 被當成 Copilot delegation primitive；正確 carrier 是 `task` 工具｜**中 · Claude/Codex-specific 名稱誤植（回答問題 9）**

| 位置 | 現況 | 實測 |
|---|---|---|
| 13 §7 2.1（line 207）「Copilot：`task` / `--agent`」 | 與 Claude `Agent`/`Task`、Codex `spawn_agent`/`wait_agent` 並列為 delegation 映射 | `--agent <agent>` 是**啟動 session 時選一個 custom agent** 的旗標（`copilot --help`，17:18），不是 fan-out 原語；`~/.copilot/agents` 為空（17:23），user-level custom agent 一支都沒有 |
| `dev-workflow/SKILL.md:133` | 「子代理 = task 工具 / --agent」 | 同上；正本亦需修 |
| 13 §11 gate 6（line 484） | 「Copilot 不可用 presentation metadata 充數」 | 方向對，但**沒有指名 Copilot 的正向 carrier**，gate 因此無法標 PASS |

Copilot 的實際 delegation 面（本 session 第一手 + `copilot help commands`，17:23）：

- `task` 工具：可在**同一個 response 內併發多個** read-only agent（工具契約明載 `Can launch multiple explore/code-review/research/security-review agents in parallel`），內建 agent_type 含 `code-review`、`general-purpose`、`explore`、`rubber-duck`、`security-review`。
- `/fleet`：parallel subagent execution 模式。
- `/tasks`：檢視／管理已派出的 subagent。
- `/review`、`/security-review`、`/rubber-duck`：內建 review agent 入口。

→ gate 6 的 Copilot carrier 應寫成「單一 response 內發出兩個 `task` 呼叫（Standards 軸、Spec 軸），各自回報四態」。這是可執行的，不需 plugin。**但必須指定內建 agent_type**，不可依賴 `pr-review-toolkit@claude-plugins-official`／`feature-dev@claude-plugins-official` 這類 plugin-contributed agent（會隨 plugin 版本漂移，且 Phase 6 移除 plugin 時連坐）。

### C8 — 「Explicit user entry」欄對 Copilot 被低估｜**中 · 事實修正**

13 §8 3.1 的路由表列 `/grill-with-docs`、`/improve-codebase-architecture` 為 explicit user entry，語境上暗示這是 Claude／Codex 的機制。官方 add-skills（17:30）明載 Copilot 同樣支援：「To tell Copilot to use a specific skill, include the skill name in your prompt, preceded by a forward slash」，並示範 `Use the /frontend-design skill to …`。

→ Copilot 的顯式入口成立（形式為 prompt 內的 `/skill-name`，非註冊型 slash command；`copilot help commands` 17:23 確認 per-skill slash command 不在命令清單內）。此欄對 Copilot **不需標 UNAVAILABLE**。

### C9 — `[T1-10]` / `agents-branch` 的理由文字低估 Copilot blast radius｜**中 · 文件缺陷**

`bin/agents-branch` 檔頭第 8–11 行（17:31 讀取）：「`~/.claude/skills/*` 是指回它的 symlink——在這裡切分支，Claude 讀到的 skill 內容當下就變了，而 **Codex/Copilot 的部署檔要等 agents-sync 才動**」。13 §3（line 67）沿用同一敘述。

這對「部署檔（instructions 組裝體）」為真，對 **skills 為假**：Copilot 原生掃描 `~/.agents/skills`（官方 about-agent-skills 17:30 + 本輪 50/50 實測 17:20），Codex 亦以 `$HOME/.agents/skills` 為 user-level root（文件 12 §E3）。所以在 live `~/.agents` 切分支時，**三家的 skill 內容都會即時改變**，只有 instructions 組裝體落後。

結論方向不變（更強化「禁止在 live main 切分支」），但 `[T1-10]` 條文與 `agents-branch` 檔頭的理由句需要更正，否則會讓人以為 Copilot 有緩衝。

### C10 — `dev-workflow` 的 Copilot hooks 敘述已過期｜**低中 · naming/maintenance debt**

`skills/dev-workflow/SKILL.md:136`：「Copilot 已支援 user-level hooks（`~/.copilot/hooks/` + config.json inline），**現況未配置**；機械守護目前依賴 repo 層 …」。

實測（17:23、17:28）：`~/.copilot/hooks/guard-git-push.json` 已存在且內容為 `preToolUse` command hook，指向 `~/.copilot/hooks/guard-git-push.sh`。→ 敘述應改為「已配置」。附帶風險：該 hook **不在 `~/.copilot` 的 git allowlist**（`git ls-files hooks` 計數 0，17:27），即 `[T0-3]` 在 Copilot 端的機械守護沒有版控載體；Phase 6/7 若動到它，無法用 repo rollback。

### C11 — `agents-sync --doctor` 不涵蓋 Copilot plugin/skill 狀態｜**低中 · missing carrier**

`--doctor`（17:24）對 Copilot 只驗兩件事：`copilot-instructions.md` 的 manifest hash 與出處戳記。gate 9 要求「Copilot rollback 後置條件可機械讀回」——instructions 那半邊成立 ✅，但 **plugin enabled 狀態與 skill inventory 兩個後置條件沒有任何自動化載體**。

好消息是兩者都可機械讀回，只是尚未接進工具：
- `python3 -c "…settings.json…enabledPlugins['superpowers@superpowers-marketplace']"`（或 `config.json.installedPlugins[].enabled`，**兩個面都要讀，可能不同步**）；
- `copilot skill list --json | jq '[.[]|select(.path|contains("superpowers"))]|length'`。

### C12 — Copilot 常駐預算 headroom 僅 937B｜**低 · 已被計畫覆蓋，但數字需重標**

`--check`（17:24）：copilot 9303B / 10240B = **90.9%**，headroom 937B。13 §3、§7 2.7 已寫「新增必須同批刪除等量」，本輪重測確認該前提仍成立。附註：`[INT-4]`（§7 2.1）與 setup adapter（§7 2.4）都要進 `core/*` 或 `routing.md` → 兩者都會吃 Copilot 的 937B。

### C13 — `~/.copilot/skills` 是第二個 personal root，Phase 1 必須明文禁止誤裝｜**低 · migration risk**

官方 about-agent-skills（17:30）：personal skills 可放 `~/.copilot/skills` **或** `~/.agents/skills`。本機 `~/.copilot/skills` 目前為空（17:19）。若 Phase 1 有人改用 `copilot skill add <dir>` 安裝 22 支，會在 Copilot 端造成與 `~/.agents/skills` 並存的第二來源（Claude／Codex 看不到），直接違反 gate 10「單一可稽核來源、三 host 版本一致」。計畫目前只禁止 `scripts/link-skills.sh`，未禁止 `copilot skill add`。

---

## 3. Copilot adapter 修正清單（只列必要最小差異）

> 全部落在 source-of-truth（`~/.agents/skills/dev-workflow/SKILL.md`、`~/.agents/core/routing.md`、proposal 文件 13），**不得改 generated files**。標 ⟪預算⟫ 者會吃 Copilot 的 937B headroom，必須同批刪等量文字（§7 2.7）。

**A1｜delegation 映射改名（`SKILL.md:133` + 13 §7 2.1 line 207）**
`子代理 = task 工具 / --agent` → `子代理 = task 工具（同一 response 可併發多個 read-only agent）；--agent 僅為 session 啟動時的 custom agent 選擇，非 fan-out 原語`。

**A2｜S5 兩軸並行語義（`SKILL.md` Copilot 段）** ⟪預算⟫
補一行：`S5 兩軸：同一 response 發兩個 task 呼叫（Standards / Spec），agent_type 用內建 code-review / general-purpose，禁用 plugin-contributed reviewer；兩軸各標四態`。

**A3｜invocation 契約分層（13 §8 3.1 + §11 gate 11）**
把 Copilot 從 `UNAVAILABLE` 改為：`Copilot 官方 frontmatter 契約僅 name/description/license/allowed-tools，無 invocation-mode 欄；所有已探索 skill 皆可隱式觸發（官方 add-skills，2026-07-27 17:30）。routing map 三 host 共用，不分岔`。

**A4｜setup 自動觸發防護（Copilot-only，必要）** ⟪預算⟫
因 A3，`setup-matt-pocock-skills` 在 Copilot 端可被模型自動選中。需在 `core/routing.md` 或 dev-workflow Copilot 段加一條硬規則：`MUST NOT 自動 invoke setup-matt-pocock-skills；只有使用者原句包含該名稱才可執行。觸發：routing 選中該 skill。驗證：引用使用者原句`。這是三 host 中 **只有 Copilot 需要 prose 補位**的一條（Claude 靠 frontmatter、Codex 靠 `openai.yaml` policy）。

**A5｜顯式入口（13 §8 3.1 表）**
Explicit user entry 欄註明：Copilot 形式為 prompt 內 `/<skill-name>`（官方 add-skills 17:30），非註冊型 slash command。

**A6｜`[T1-10]` / `agents-branch` 理由更正**
把「Codex/Copilot 的部署檔要等 agents-sync 才動」補為「…但三家的 **skills** 都直接讀 `~/.agents/skills`，切分支時 skill 內容三家同時改變；落後的只有 instructions 組裝體」。

**A7｜Copilot hooks 敘述更正（`SKILL.md:136`）**
「現況未配置」→「已配置 `~/.copilot/hooks/guard-git-push.{json,sh}`（preToolUse）；該檔未進 `~/.copilot` git allowlist，變更無 repo rollback 載體」。

**A8｜Phase 1 安裝禁令補一條（13 §6 1.1「禁止」清單）**
補：`禁止使用 copilot skill add 或把 22 支放進 ~/.copilot/skills（會產生 Copilot 專屬的第二來源，違反 gate 10 單一來源）`。

**A9｜Phase 4 固定變因補 Copilot 列（13 §9 4.2）**
`Copilot：--model 寫死具體 model id（禁用 auto）、--effort、--context tier、--mode、CLI 版本與 app runtime 版本（兩者可能不同，見 C5）、allowed-tools/permission 一致`。

**A10｜Copilot 新 session 指令（13 補 §16）**
比照 §14／§15 補一段 Copilot 授權文本，明列：唯讀 baseline → 不碰 dirty `copilot-instructions.md` → inventory 用 `copilot skill list --json` → Superpowers 停用走 `settings.json.enabledPlugins`（不得手刪 `installed-plugins/`）。

---

## 4. Phase 6 十一項 gate 的 Copilot 判定

> 判定標的：**以 Copilot 這一 host 而言，該 gate 目前是否可執行、可驗證**。「需修正」= 有可行路徑但計畫寫法不足；「UNAVAILABLE」= 目前沒有 supported path。

| # | Gate | Copilot 判定 | 依據 / 需要的最小修正 |
|---|---|---|---|
| 1 | Active superpowers reference 歸零 + repo-wide probe | **PASS（可執行）** | Copilot 讀同一份 source-of-truth；`--doctor` + manifest 可驗證組裝體已更新（17:24 全綠） |
| 2 | 4 支 `mp-*` 17 檔 parity ledger | **PASS（host-agnostic）** | 與 Copilot 無關；但 §10 `git mv skills/mp-* attic/` 對 Copilot 同樣即時生效（原生讀取），需在新 session 或 `/skills reload` 後重驗 inventory |
| 3 | `[T0-2]` + S4–S6 承接 verification，反向 probe 0 次錯誤完成 | **需修正** | 可執行，但依賴 arm B 已停用 Superpowers → 卡在 gate 對應的 C2；且 §13 未列 Copilot inventory（C4） |
| 4 | Closeout 改動作定義並在 arm B 跑過 | **需修正** | Copilot 有 `/pr`、`/diff`、`/review` 可完成 closeout；但需 §16 Copilot session 指令才有執行者（C4） |
| 5 | red→green bugfix gate 有真實紅燈 | **PASS（可執行）** | Copilot 有完整 shell/test 能力，無 host 限制 |
| 6 | `code-review` 兩軸四態 + 可執行 delegation carrier | **需修正** | 計畫只寫「Copilot 不可用 presentation metadata 充數」，未指名正向 carrier。改為 A2 的「同一 response 兩個內建 `task` 呼叫」後即可 PASS（C7） |
| 7 | `[T1-10]` + local conformance / CI 分離 | **需修正** | 條文本身 host-agnostic，但理由句對 Copilot 錯誤（C9 / A6） |
| 8 | `implement` 被 adapter 攔回 branch + S4–S6 | **需修正（Copilot 風險最高）** | 因 C3，`implement`（upstream invocation-off）在 Copilot 會被**自動選中**，Claude/Codex 不會。Copilot 的攔截完全靠 prose adapter，必須在 canary 明確測「未經使用者要求時 `implement` 是否自行啟動」 |
| 9 | 三 host new-session inventory + rollback 後置條件可機械讀回 | **部分 PASS / 部分需修正** | instructions 半邊 PASS（`--doctor` manifest 相符 ✅ 17:24）；plugin/skill 半邊**目前無自動化載體**，需補 C11 的兩條 probe |
| 10 | 單一來源、22 支、setup adapter、delegation、writing/audit、helper ledger | **需修正** | 需補 A8（禁 `copilot skill add` / `~/.copilot/skills`），否則「單一可稽核來源」在 Copilot 有旁路（C13） |
| 11 | Invocation contract 逐 host 對齊；Copilot 標 UNAVAILABLE + canary | **需修正（判定本身錯誤）** | 已取得官方契約與 schema 證據（C3）。應改為「confirmed divergence：Copilot 無 invocation-mode 欄，13 支 upstream invocation-off 在 Copilot 一律可隱式觸發；補 A4 prose 閘 + canary 驗證」 |

**額外提議：gate 12（Copilot-only，來自 C1）**
`Copilot 常駐 description 注入涵蓋率已量測並接受`：vendoring 前後各跑一次 description-cap probe，記錄哪些 skill 落在名稱尾巴；`dev-workflow` 與 `tdd` 至少其一未進常駐面時，必須有明確接受決策或緩解（例如以 `core/routing.md` 逐名點名補位——這正是既有 routing 第 7 行的設計用途）。

---

## 5. Supported plugin lifecycle（Copilot，2026-07-27 17:22–17:31 Asia/Taipei 實測）

| 動作 | Supported path | 狀態 | 證據 |
|---|---|---|---|
| Inventory（plugin） | `copilot plugin list` | ✅ 可用 | 17:22，18 支 |
| Inventory（skill，機械可讀） | `copilot skill list --json` | ✅ 可用 | 17:20，128 筆 |
| Inventory（plugin state，機械可讀） | `~/.copilot/config.json` → `installedPlugins[].enabled`；`~/.copilot/settings.json` → `enabledPlugins[<name>@<marketplace>]` | ✅ 可讀（**兩面都要讀**） | 17:27，兩處皆 `true` |
| **Disable（不移除）** | `~/.copilot/settings.json` 的 `enabledPlugins["superpowers@superpowers-marketplace"] = false`（官方 about-plugins 承認的宣告式面，17:29）；互動式 `/plugin`、`/skills` 亦可切換 | ⚠️ **可用但本機未驗證**——必須先做一次「設 false → 新 session → `copilot skill list --json` 中 14 支 superpowers skill 消失」的正向 probe | 17:27 / 17:29 |
| Disable（CLI 統一命令） | `copilot plugins disable <name> --plugin` | ❌ **UNAVAILABLE**（1.0.75，`--experimental` 亦不可用） | 17:25–17:26 |
| Per-skill disable | `copilot plugins disable <name> --skill`（不可用）；互動 `/skills` 空白鍵切換（官方 add-skills 17:30） | ⚠️ 僅互動式；**語義與 `disable-model-invocation` 不等價**（會連顯式呼叫一起關掉） | 17:25 / 17:30 |
| Uninstall | `copilot plugin uninstall superpowers@superpowers-marketplace` | ✅ 可用（官方：removes plugin and its associated skills） | 17:26 |
| Reinstall | `copilot plugin install superpowers@superpowers-marketplace` | ⚠️ 可用但**無法 pin 版本**（install 無 version 參數；官方文件亦無語法） | 17:26 / 17:31 |
| Reinstall 到指定 6.2.0 | — | ❌ **UNAVAILABLE**（除非 marketplace 當下 latest 仍為 6.2.0；`~/.copilot/installed-plugins/` 未進版控，無法用 git 還原） | 17:27 |
| 手刪 cache | `rm -rf ~/.copilot/installed-plugins/...` | 🚫 **禁止**（計畫 §5 0.4 / §11 已禁；本 review 維持） | — |
| Reload（不重啟） | 互動式 `/skills reload` | ✅ 可用（官方 add-skills 17:30）——Phase 1 vendoring 後可即時驗證 22 支是否載入 | 17:30 |

**建議的 Copilot arm B 停用流程（取代 §9 4.4 對 Copilot 的泛稱）：**

1. 先記錄 `settings.json.enabledPlugins` 與 `config.json.installedPlugins[].enabled` 兩處的值（set/unset + 布林，不輸出其他內容）。
2. 只改 `settings.json` 的該一個 key 為 `false`（單行、可逆；**不得順手帶入其他既有 dirty edit**——該檔 17:26 有 `settings.json.bak-20260727`，代表最近被動過）。
3. 開新 session，跑 `copilot skill list --json`，斷言 `path` 含 `installed-plugins/superpowers-marketplace` 的 14 支全數消失。
4. 若步驟 3 失敗（即該 key 不生效）→ 記錄 observed behavior，**改用 `copilot plugin uninstall` 並接受「reinstall 無法 pin 6.2.0」的 rollback 缺口，或直接把 Copilot 的 Phase 4/6 標 `UNAVAILABLE`**。禁止改以手刪 cache 繞過。
5. Rollback：把該 key 改回 `true`，新 session 讀回 14 支 + `copilot plugin list` 仍顯示 v6.2.0。

---

## 6. 逐題回答（對應委託的 10 項）

1. **Copilot 是否實際探索並載入 `~/.agents/skills`：是。** 官方文件明列為 personal skill root（17:30）；live 實測 50/50 全載入、`source=personal-agents`、全部 `enabled`（17:20）。`agents-sync --doctor` 第 459 行的「已驗證原生載入」敘述成立。
2. **Matt stable 22 的 SKILL.md 與 `agents/openai.yaml` 在 Copilot 的處理：** `SKILL.md` 的 `name`/`description` 被讀取並用於路由；`disable-model-invocation` 不在官方 frontmatter 契約內，亦不在 `skill list --json` schema 內 → 無作用（未知 key 是否影響 parse 尚待一個 Phase 1 probe）。`agents/openai.yaml` 對 Copilot **完全無語義**，只會在 skill 被 invoke 時作為目錄內普通檔案一併可見（官方 add-skills：「Copilot automatically discovers all of the files in the skill's directory」）。
3. **Copilot 是否存在 user-invoked／implicit invocation contract：** implicit = **有且為預設**（官方明述依 description 決定）；user-invoked 顯式入口 = **有**（prompt 內 `/skill-name`）。但**沒有 per-skill 的「關閉隱式、保留顯式」契約**——最接近者是 `/skills` 的二元開關，語義不等價。此結論有官方文件 + live schema 雙重依據，**不標 UNAVAILABLE**（唯一 UNAVAILABLE 者為「未知 frontmatter key 的 parse 行為」）。
4. **`task` / `--agent` adapter 是否足以承接四項：**
   - delegation：**足夠**，但 carrier 是 `task` 工具（非 `--agent`）。
   - Standards／Spec 雙軸 review：**足夠**（同一 response 併發兩個內建 `task`），需在 adapter 明文寫死。
   - parallel fan-out：**足夠**（`task` 併發 + `/fleet` + `/tasks`）。
   - completion evidence：**足夠但需 prose 補位**——`task` 工具契約本身寫「Returns brief summary on success」，符合 `[INT-4]`「subagent 回報 ≠ 完成證據」的既有要求；`dev-workflow:80` 已有該句，Copilot 端不需新增。
5. **generated `copilot-instructions.md` 與 manifest／doctor 的部署與 rollback：** 部署 ✅（原子寫入 + no-clobber prescan + manifest + 出處戳記，17:24 全綠）；rollback ✅ 對 instructions（`~/.agents` git revert + `agents-sync` + `--doctor` 讀回）。**不完整處**：(a) 該檔目前 dirty 且 hunk 與 target 重疊（C6）；(b) `--doctor` 不涵蓋 Copilot plugin/skill 狀態（C11）；(c) `~/.copilot` 的 git allowlist 不含 plugin/hook/settings state（C2）。
6. **Superpowers 在 Copilot 的 lifecycle：** 見第 5 節。enable/disable 走 `settings.json.enabledPlugins`（需一次正向驗證）；uninstall/reinstall 走 `copilot plugin`；**pinned 6.2.0 reinstall UNAVAILABLE**；手刪 cache 禁止（維持計畫立場）。
7. **Phase 4 Copilot canary 是否可執行：** **有條件可執行**。前置三項：(a) 第 5 節步驟 3 的停用正向 probe 通過；(b) 補 A9 固定變因（含禁用 `auto` model、記錄 CLI 與 app runtime 兩個版號）；(c) 補 A10 Copilot session 指令。必需的實際 probes：`copilot --version` + app runtime 版號、`copilot skill list --json`（arm A/B 各一份 + diff）、`copilot plugin list`、`settings.json.enabledPlugins` 值、`agents-sync --doctor`、description-cap probe（C1）、以及「未經要求時 `implement`／`setup-matt-pocock-skills` 是否自行啟動」的反向 probe（因 C3，這是 Copilot 專屬風險）。
8. **11 項 gate 的 Copilot 狀態：** 見第 4 節。PASS 3（#1、#2、#5）；部分 PASS 1（#9）；需修正 7（#3、#4、#6、#7、#8、#10、#11）；UNAVAILABLE 0（原被標 UNAVAILABLE 的 #11 已可判定）。另提議 Copilot-only 的 gate 12。
9. **Claude／Codex-specific 名稱被誤當 Copilot 共通契約的位置：**
   - 13 §7 2.1 line 207 + `dev-workflow/SKILL.md:133`：`--agent` 被當 delegation 原語（C7）。
   - 13 §8 3.1 line 330–332：以 Claude `disable-model-invocation` / Codex `allow_implicit_invocation` 的框架去問 Copilot，得出 UNAVAILABLE；實際 Copilot 是另一套契約（C3）。
   - 13 §8 3.1 表格「Explicit user entry」欄：`/skill` 形式被隱含為 Claude/Codex-only（C8）。
   - 13 §11 gate 6 line 484：只否定 `agents/openai.yaml`（Codex 概念），未給 Copilot 正向 carrier（C7）。
   - 13 §3 line 67 + `bin/agents-branch:8-11`：以 Claude symlink 為唯一即時生效機制，漏掉 Copilot/Codex 的原生路徑讀取（C9）。
   - 13 §9 4.2 / §13 / §14–15：固定變因、最終驗證、session 指令都只有 Claude 與 Codex（C4）。
10. **Phase 0–2 是否可先執行 / Phase 3 前是否仍有 Copilot blocker：** Phase 0–2 **可執行**（皆在 isolated worktree 或唯讀，Copilot live surface 不變），但 Phase 0 必須先處理已命中的兩條 stop condition（C5 host identity、C6 dirty hunk）。**Phase 3 前仍有 Copilot blocker**：C1（description-cap 未量測 → Phase 1 的 vendoring 會靜默改變 Copilot 常駐路由面）、C6（Phase 3 首次 live deploy 的目標檔正處於未 commit 的生成狀態）、A4（Copilot 缺 setup 自動觸發防護，而 Phase 3 正是把 Matt 22 支接上 routing 的那一步）。

---

## 7. 是否允許進入 Phase 3

**No。**

Phase 0–2 可以開始（並建議開始）。但 Phase 3 是首次 live deploy，對 Copilot 而言它同時做三件目前未受控的事：把 22 支帶進常駐面（C1 未量測）、覆寫一個正處於 dirty 狀態的目標檔（C6）、以及在唯一沒有 invocation gate 的 host 上接通 `implement` / `setup-matt-pocock-skills`（C3 + A4 未補）。

放行條件（最小集）：C1 的 probe 完成並有接受決策、C6 的歸屬裁定、A4 進 source-of-truth 且通過 `--check` 預算、C5 的 runtime 版號固定寫入 baseline。

---

## 8. 唯一 next action

**在 Phase 0 baseline 加入 Copilot description-cap probe，量出「常駐面實際注入幾支 personal skill 的 description、依什麼規則截斷」，並以此決定 vendoring 22 支後 `dev-workflow`、`tdd`、`mp-zoom-out` 是否仍在常駐面。**

理由：這是本輪唯一「三 host 中只有 Copilot 會發生、且無法從 Claude／Codex 觀測外推」的行為，它在 **Phase 1 vendoring 當下就生效**（早於 Phase 3 的 live deploy gate），而目前計畫從頭到尾沒有任何一句涵蓋它。其餘 12 項 findings 都可在 Phase 0–3 執行中逐項吸收，不需回退任何已收斂的架構主張。

建議的唯讀 probe 形態（不改任何檔）：

```bash
TZ=Asia/Taipei date '+%F %T %Z'
# 1) 目前 personal skill 排序與數量
copilot skill list --json | python3 -c "import json,sys;d=json.load(sys.stdin);p=sorted(e['name'] for e in d if e['source']=='personal-agents');print(len(p));print('\n'.join(p))"
# 2) 常駐面實際注入了幾支 description（在新 session 內問模型自陳，--available-tools= 排除工具雜訊）
copilot -p '只輸出兩行：(a) 你的 available_skills 中含完整 description 的 skill 數量；(b) 其中最後一支的名稱。不要解釋。' --available-tools=
# 3) 交叉驗證：dev-workflow / tdd / mp-zoom-out 是否在完整 description 區
copilot -p '回答三個 yes/no：available_skills 中 dev-workflow、mp-zoom-out 是否各自帶有完整 description（而非只在名稱清單）？' --available-tools=
```

若 probe 顯示截斷規則為位元組預算而非固定筆數，第 2 節 C1 的「9 支被擠出」推算需重算，但結論方向（Copilot 常駐路由面會因 vendoring 而降級）不變。

---

## 附錄 — 本輪可重跑 probe（全部唯讀）

```bash
# P0 時刻與 host identity（注意 CLI 與 app runtime 可能不同版）
TZ=Asia/Taipei date '+%F %T %Z'
which -a copilot; copilot --version
ls -1 ~/.copilot | grep pre-update | tail -3     # app runtime 升級痕跡
```

```bash
# P1 skill 探索與載入（決定性：問題 1）
copilot skill list --json > /tmp/cop-skills.json
python3 -c "
import json,collections,os
d=json.load(open('/tmp/cop-skills.json'))
print('total',len(d),dict(collections.Counter(e['source'] for e in d)))
print('disabled',[e['name'] for e in d if not e['enabled']])
cop={e['name'] for e in d if e['source']=='personal-agents'}
print('disk-not-loaded',sorted(set(os.listdir(os.path.expanduser('~/.agents/skills')))-cop))
print('schema keys',sorted({k for e in d for k in e}))"
```

```bash
# P2 plugin lifecycle（決定性：問題 6）
copilot plugin list
copilot plugin marketplace list
copilot plugins list --json          # 期望：The plugins command is not available.
copilot plugin install --help | grep -i version   # 期望：無 version 參數
python3 -c "
import json,re,os
s=re.sub(r'^\s*//.*$','',open(os.path.expanduser('~/.copilot/settings.json')).read(),flags=re.M)
print(json.loads(s)['enabledPlugins'].get('superpowers@superpowers-marketplace'))"
```

```bash
# P3 generated file / rollback carrier（決定性：問題 5）
~/.agents/bin/agents-sync --check
~/.agents/bin/agents-sync --doctor
git -C ~/.copilot status --short
git -C ~/.copilot ls-files config.json settings.json hooks installed-plugins | wc -l   # 期望 0
```

```bash
# P4 delegation / review carrier（決定性：問題 4、9）
copilot --help | grep -nE '^\s+--agent|--model|--effort|--context|--mode'
copilot help commands | sed -n '/Agents \/ Subagents/,/^  Code:/p'
ls -R ~/.copilot/agents                    # 期望：空
grep -n 'task 工具' ~/.agents/skills/dev-workflow/SKILL.md
```

```bash
# P5 hooks 現況（C10）
ls -R ~/.copilot/hooks; head -12 ~/.copilot/hooks/guard-git-push.json
grep -n 'Copilot 已支援 user-level hooks' ~/.agents/skills/dev-workflow/SKILL.md
```

**本檔 2026-07-27 的觀測不得當成永久事實**；Copilot CLI 與 app runtime 版本變動（本輪已見 1.0.75 / 1.1.0 並存）都可能改變 `copilot plugins` 可用性與 description 截斷行為，實作 session 必須全部重跑並標新時刻。

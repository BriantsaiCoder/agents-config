# P3 待辦 Handoff · 2026-07-25

> 給新 session 的自足指令。**先讀本檔，不必重讀完整報告** —— 需要細節時再看同目錄的 `00-report.md`（§編號已標在各項）。
> 主力 stack：ASP.NET Core / .NET、Vue、React、TypeScript、Node.js

---

## 0. 先讀這段：今天已完成什麼（別重做）

三個 config repo 皆已上遠端（全 PRIVATE）、`main` 皆與 origin 同步、皆有 CI：

| Repo | main | CI |
|---|---|---|
| `BriantsaiCoder/agents-config` (`~/.agents`) | `44bb642` | 5 檢查 |
| `BriantsaiCoder/dotclaude` (`~/.claude`) | `cbc8e20` | **無**（見 P3-9） |
| `BriantsaiCoder/dotcodex` (`~/.codex`) | `bd1195d` | 5 檢查 |

**已結案、不要再議的結論**：

1. **52 個 skill、3 個 agent 全部不可移除** —— 用五軸判準（機械執行／工具鏈存取／乾淨 context 獨立審查／家規程序／版本釘死事實），只有五軸全 FAIL 才算可移除，實測 0 個符合。靠模型能力可收成的部分已在 09:57 刪 14 個 persona 時拿完。判準見 memory `skill-removability-five-axes`。
2. **`[T0-3]` force-push guard 已修**：五個破口 + 一個 fail-open 全關；單一正本 `~/.agents/hooks/guard-git-push.sh` + 兩薄 wrapper；68-case 雙格式測試已進 CI。
3. **用量數據的權威來源是 `~/.claude.json` 的 `skillUsage`**，不是 grep transcript。實測 31/52 觸發（60%），且被 corpus 汙染（87% 任務來自零前端的 .NET ETL 專案）—— **禁止用用量裁剪前端 skill**。

---

## 1. 動手前必須知道的四個環境約束

**① sandbox 擋 agent 寫 `~/.claude` 的 gate 檔案**（防禦設計，非故障）

```
❌ ~/.claude/settings.json    operation not permitted
❌ ~/.claude/hooks/           operation not permitted
❌ ~/.claude/CLAUDE.md、~/.claude/agents/、~/.claude/rules/
✅ ~/.agents/**  ~/.codex/**  ~/.copilot/**
```

→ 任何動 `settings.json` 或 `~/.claude/hooks/` 的項目，**只能產出指令讓使用者自己貼**。

**② guard 會擋「只是提到」危險 payload 的指令**（刻意的 fail-closed）

比對對象是整個 command 字串，所以 commit message、PR 回覆、測試腳本只要含 `git push --force` 之類字樣就會被擋。**變通：用 `git commit -F <file>`、`gh api --input -`、或先用 Write 工具建檔再引用路徑。**
`MUST NOT` 為消除此誤擋而改成解析 shell —— 會開出引號規避路徑（已寫進 guard 標頭）。

**③ 在 `~/.agents` 切分支會即時換掉 Claude 讀到的 skills**

`~/.claude/skills/*` 是指向 `~/.agents/skills/*` 的 symlink。今天踩過：`git checkout main` 成功但 `git pull --ff-only` 失敗，工作區停在舊版，skill descriptions 整批靜默回退且無錯誤訊息。
→ **動完分支必用內容抽查驗證**（grep 具體字串），不能只看 `git status`。詳見 memory `agents-branch-switch-silently-swaps-skills`。

**④ 驗證用的 dry-run 也可能弄髒狀態**

`AGENTS_DEPLOY_ROOT=<temp> bash bin/agents-sync` 會改寫 `dist/manifest.tsv` 但**不更新 live host 檔** → `conformance.sh` 立刻掉到 11 PASS / 1 FAIL。正常部署（`bash bin/agents-sync`）即復原。

---

## 2. P3 待辦

### P3-1 ⏸ 需要你先裁決：非主力 stack 要不要可逆 archive

**候選**：`c-cpp-best-practices`、`dotnet-framework-best-practices`、`ef6-best-practices`、`dotnet-winforms-best-practices`、`native-feel-cross-platform-desktop`、`ecpay`

**兩方立場都成立，差別在一個你才知道的事實 —— 這些 stack 是「死」還是「眠」**：

- 若**真的永不再碰** → archive 合理（Codex 立場）
- 若只是**休眠** → 不該 archive（我的立場）。每個都有「編譯過、線上炸」的軸 4/5 證據：EF6 `.Include(x=>x.A.Select(...))` vs EF Core `.ThenInclude()` 模型必寫錯；.NET Framework R4「library 加 `ConfigureAwait(false)`、controller 不加」模型會壓平成「一律加」而弄壞需要 HttpContext 的 controller；WinForms .NET 9 `InvokeAsync` 同步 overload 吞掉內層 Task（編得過、靜默不執行）

**額外事實**：`DCT_data_import` 本身是 net462→net8 的遷移產物，legacy 面浮出時會用到 EF6 / .NET Framework。

**收益校正**：archive 在 Claude 省 ~100 token/個；**Copilot 也原生載入 `~/.agents/skills`**（`agents-sync --doctor` 的探針欄已驗證），所以是兩家 × ~100；Codex 端為 UNVERIFIED。做它是為衛生，不是為 context。

**⛔ 不可比照辦理**：`pinia`。`rules/frontend-spa.md:21` 明文列為家規既定選型（「State 共用 > 3 處才引入 Zustand / Pinia」）。以「目前無 Vue 專案」裁掉它，正是 corpus 汙染推論換一身衣服。`next` / `nuxt` 條件式保留則合理（僅 SSR/SEO 場景）。

**做法**：`mv` 到 `~/.agents/backups/<date>-stack-archive/`（不要 `rm`，且 `backups/` 已 gitignore），然後 `bash ~/.agents/bin/agents-sync` 重生 skill-index。**CI 會擋** index 與 `skills/` 不一致，所以一定要跑 sync。

---

### P3-2 skill 內部通用知識瘦身（~8-9k 行）

**不是刪 skill，是刪 skill 內部模型已可靠覆蓋的通用教材。** 採 Codex 提的四路分流：

| 內容類型 | 去處 |
|---|---|
| 專案 house rules | 移到 `CLAUDE.md` / `rules/*.md` |
| 可機械驗證的規則 | 移到 hook / lint / test（`deps-check/SKILL.md:36` 已實證「hook 100% 觸發、skill 約 50%」） |
| 大量範例與通用教學 | 縮短或移到 reference |
| **版本敏感資訊** | **保留**，但補 `last-verified` 戳（`reviewer-template.md:1` 已有此慣例） |

**最大宗三處**（實測行數）：
- `design-doc-mermaid/` 的 `examples/` + `assets/` ~7,500 行（6 個 example README + 5 個 design-template，純通用知識）
- `security-review/references/vuln-categories.md` (281) + `language-patterns.md` (221) ∩ `security-audit/ATTACK-CLASSES.md` ~500 行重疊
- `mp-tdd` 的 5 個附檔 194 行（公開 TDD 文獻知識）

**注意**：軸 5（版本釘死）的段落**一律不動** —— 那正是模型愈強愈會寫錯的部分（Next 16 `proxy.ts`、Vitest 3 `projects`、Vite 8 `rolldownOptions`、EF6 vs EF Core、MySQL 8.0.16 前 `CHECK` 靜默丟棄）。

**驗收**：`bash ~/.agents/bin/agents-sync --check` lint PASS + `~/.agents/tests/conformance.sh` 12 PASS。CI 會擋 dist 不同步。

---

### P3-3 ⚠️ 需要互動式 session：`/plugin` 評估 15 個零用量 inline plugin

**這是唯一「移除真的能省 context」的地方**，且與模型能力完全無關。

`~/.claude.json` 的 `pluginUsage` 顯示 15 個 `@inline` plugin 的 `usageCount` 為 **0**：
`anthropic-skills`、`data`、`marketing`、`finance`、`product-management`、`operations`、`pdf-viewer`、`figma`、`productivity`、`design`、`legal`、`sp-global`、`desktop-commander`、`mongodb`、`firecrawl`

它們貢獻約 **90 個** skill 條目，遠大於 52 個個人 skill 的 5.4k token。

**但它們不在 `enabledPlugins`（22 項）也不在 `installed_plugins.json`（23 項）** —— `@inline` 代表由 Claude Code 桌面版 binary 內建（實體在 `~/.local/share/claude/ClaudeCode.app`，磁碟上沒有 SKILL.md）。**改 `settings.json` 動不了**，只能在互動式 session 用 `/plugin` 確認能否停用。

驗證指令：
```bash
python3 -c "
import json,os,datetime
d=json.load(open(os.path.expanduser('~/.claude.json')))
for k,v in sorted(d.get('pluginUsage',{}).items(), key=lambda kv:kv[1].get('usageCount',0)):
    if v.get('usageCount',0)==0 and k.endswith('@inline'): print(' ',k)
"
```

---

### P3-4 `ultracode` + subagent 上限（Opus 5 的行為反轉）

**官方 prompting guidance 載明：Claude Opus 5 比 Opus 4.8 更愛派 subagent**（4.8 是 under-reach 需要鼓勵，Opus 5 反過來要加上限），建議形式：「除非明確要求，不超過 20 個平行 agent」+「不要用 subagent 做 review／驗證 —— 驗證屬於主 agent loop」。

`~/.claude/settings.json` 目前 `ultracode: true`，每個實質任務預設走 workflow 多 agent 編排。**本次一場 workflow 就是 1.59M token。**

**若 token 成本是考量，這是唯一有兩個數量級效果的旋鈕**（刪 52 個 skill 省 5.4k 常駐；一場 workflow 1.59M）。

兩個選項：
- 關掉 `ultracode`，改為按需要求（需你改 `settings.json`，agent 寫不了）
- 保留但在 `~/.agents/core/` 或 `CLAUDE.md` 加 subagent 上限條款（agent 可改 `~/.agents/core/`；`CLAUDE.md` 由 agents-sync 管，改正本即可）

**同批應做**：掃 `~/.agents/skills/` 刪除 `double-check` / `re-verify` / `verify before responding` 類 **prompt 層自我檢查散文** —— 官方實測「刪除降低 over-verification 且**無能力退化**」。**這反轉了一般 prompting 最佳實踐**，要對此模型開特例。
**⛔ 不含** `dev-workflow` S4 的四態 gate 與 `[T0-2]` evidence 要求 —— 那是機械證據要求，不是「請再檢查一次」。

---

### P3-5 `settings.json` 兩項選配（**只能你手動改**）

hook 已是主防線，這兩項純 defense-in-depth：

```
:21   刪 "Bash(git push --force-with-lease *)",
      → 代價：force-with-lease 到 feature branch 會多一次確認
:284  刪 "skipDangerousModePermissionPrompt": true,
      → 與日常 git 無關，只在啟動 --dangerously-skip-permissions 前多一次確認
```

**額外可選**：`:23` 的 `Bash(gh *)` 收斂為唯讀子集（`gh pr view/checks/diff`、`gh api GET`、`gh issue view`）—— 目前 `[T0-9]` 的 merge gate 沒有機械對應物，`gh pr merge` 一句就繞過（見 `00-report.md` §3.2）。

**另一個旋鈕**（不動 allow 清單就能恢復軟層）：`autoMode.classifyAllShell: true` —— 讓所有 Bash allow rule 一律被排除出 classifier 短路路徑。原理見 `00-report.md` §3.1.1 的 binary 驗證。

---

### P3-6 `stitch.env` 明文 key rotate

`~/.codex/stitch.env` 內有明文 key（memory `three-host-config-audit-facts` 記著「stitch key 明文待 rotate」）。
**未外洩** —— gitleaks 掃 `~/.codex` 完整歷史 11 commits / 192KB 無洩漏，且該檔未被追蹤（`.gitignore` allowlist 模式）。CI 現有「追蹤面未擴大」檢查會擋它被誤加入版控。
但本機明文存在，rotate 仍應做。

---

### P3-7 累積的技術 follow-up（小而具體）

| # | 項目 | 位置 / 證據 |
|---|---|---|
| a | `postgresql-best-practices` 補 PG 18 原生 UUIDv7 | sibling `references/schema-design.md:63-65` 說「PG 不原生產生 UUIDv7，用 app 層或 `pg_uuidv7` 擴充」，而 `postgresql-optimization/references/performance.md:123` 說「UUIDv7 (PG 18+)」。**不是相反建議，是 sibling 早於 PG 18**。補完後才談 archive |
| b | `typescript-best-practices` 補兩條家規 | `rules/typescript.md:10` 的「NEVER barrel exports」在 skill 內無對應條文；React 側缺 `eslint-plugin-jsx-a11y`（Vue 側有） |
| c | `agent-browser/references/webgpu.md:63` 的 `node:22` | 刻意保留（上下文寫「Verified with both Chrome for Testing and Debian's chromium」，Node 22 仍在 LTS）。下次實測 WebGPU 路徑時一併驗 Node 24 |
| d | `tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md:2` 的 `paths:` frontmatter 是否會被自動注入 | **ASSERTED 未實測**。判為不會（inline 逗號串格式與 `rules/typescript.md:2-5` 的 block-sequence 不同，且位於 skill 子目錄）。verdict 兩種情況都是 KEEP，但本報告論旨含「假防線宣稱 = bug」，不該自留未測宣稱 |
| e | `~/.agents/hooks/drift-check.sh` 的 `doctor()` 加 routing stamp diff | 目前只驗 symlink 完整性與 core 三檔存在，**不驗 `CLAUDE.md` 的 routing stamp 是否落後 `core/routing.md`**。agents-sync 註解自己記著「手動快照必 drift（實證 2026-07-08）」 |
| f | `~/.claude/hooks/audit-bash.sh` 改註冊 `PostToolUse` + 修 `~/.agents/CONVENTIONS.md:11` | 目前掛 `PreToolUse` + `async:true`，**依定義無法攔截**，且記錄的是「嘗試」非「執行」。CONVENTIONS.md:11 把它列為 `[T0-3]` 的驗證機制 = 假防線宣稱。hook 註冊需改 `settings.json`（你手動），CONVENTIONS.md agent 可改 |
| g | `autoMode.environment` 宣稱 "Preferred stacks: … PostgreSQL" 與實況不符 | 實測 7 個專案 PG **0 命中**，唯一有 DB 的是 MySQL（17 檔）。會讓 classifier 系統性偏斜（預設產 PG 語法、預設選 Npgsql）。需改 `settings.json`（你手動） |
| h | `permissions.deny` 補 reader 清單 | 硬層只擋 `cat`/`grep`/`sed` 四個動詞；`autoMode.soft_deny` 已枚舉 11 個 reader，同步進硬層即可對齊。需改 `settings.json`（你手動） |
| i | `permissions.allow` 清掉四條對應已停用 `github` plugin 的 mcp 規則 | 純衛生。需改 `settings.json`（你手動） |
| j | `~/.codex/.github/workflows/ci.yml:33` 的註解含字面 `/Users/pochientsai` | 目前無害（CI 掃描範圍是 `hooks.json hooks/ agents/`，不含 `.github/`）。但**若日後擴大 CI scope 到全檔，這條會自我誤報** |

---

### P3-8 `~/.claude` 沒有 CI

`dotclaude` repo 無 `.github/workflows/`。它裝的是 `settings.json`、`hooks/`、`agents/`、`commands/`，其中 `settings.json` 是承載整個 permissions / sandbox / autoMode 機械層的檔案。

可加的檢查（agent 可寫 `.github/`，那不在 sandbox deny 清單內）：
- `settings.json` JSON 合法 + `$schema` 存在
- `autoMode` 三段皆以 `"$defaults"` 開頭（**省略即整段取代不是疊加**，見 memory `claude-automode-defaults-and-async-hooks`）
- `permissions.deny` 條數不減少（防止有人悄悄放寬）
- `hooks/*.sh` shellcheck
- 無硬編碼家目錄（`~/.claude/hooks/` 已有 wrapper 用 `$HOME`）

---

## 3. 每次動完必跑的驗收

```bash
~/.agents/tests/git-push-guard.sh          # 預期 68 PASS / 0 FAIL
~/.agents/tests/codex-git-push-guard.sh    # 預期 12 PASS / 0 FAIL
~/.agents/tests/conformance.sh             # 預期 12 PASS / 0 FAIL
bash ~/.agents/bin/agents-sync --check     # 預期 lint: PASS
bash ~/.agents/bin/agents-sync --doctor    # 預期 exit 0
```

動到 `~/.agents/core|hosts|rules|skills` 的正本後，**必須跑 `bash ~/.agents/bin/agents-sync`（不加 `--check`）重新部署**，否則 `conformance.sh` 的「manifest 相符」會紅。

---

## 4. 正本位置

| 文件 | 內容 |
|---|---|
| `~/.agents/proposals/2026-07-25-model-capability-coverage/00-report.md` | 完整稽核（94 findings、五軸判準、Copilot review 處理、CI 建置、事故紀錄）§1–§15 |
| `~/.agents/proposals/2026-07-25-skill-audit/` | skill 層逐檔判決（Keep/Trim 的詞彙定義見 `02-recommendations.md:24`） |
| `~/.agents/proposals/2026-07-25-agent-audit/00-report.md` | agent 層 + 設定層 |
| memory `skill-removability-five-axes` | 五軸判準與兩個禁用推論 |
| memory `skill-usage-authoritative-source` | 用量權威來源與 `@inline` plugin 的性質 |
| memory `guard-git-push-refspec-bypass` | guard 的現行結構（改邏輯只改一處） |
| memory `agents-branch-switch-silently-swaps-skills` | 切分支換掉 skills 的陷阱 |
| memory `claude-automode-defaults-and-async-hooks` | `$defaults` 是取代不是疊加；async hook 不可攔截 |

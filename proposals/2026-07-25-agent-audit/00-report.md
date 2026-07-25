# 客製化 agent 能否被模型能力取代 — 稽核報告

> 2026-07-25 · 承接同日 `2026-07-25-skill-audit`（skill 層），本檔處理 **agent 層 + 全域設定層**
> **本檔只是提案，未執行任何變更。**
> 主力 stack（本報告的判準基準）：ASP.NET Core / .NET、Vue、React、TypeScript、Node.js

---

## 一頁結論

**問題「客製化 agent 是否都能移除、靠模型本身能力 cover」的答案是：不能全移，但理由不是模型不夠強。**

三類東西被這個問題混在一起，判準完全不同：

| 類別 | 與模型能力的關係 | 判決 |
|---|---|---|
| **(a) 知識載體型 agent**（react-specialist、vue-expert、typescript-pro、csharp-developer…） | Opus 5 / GPT-5.6 確實 100% cover | ✅ **可移除，且今日 09:57 已移除**（14 Claude + 5 Copilot），判斷成立 |
| **(b) 機制執行型設定**（hooks、permissions.deny、autoMode.soft_deny、sandbox） | **完全無關**。它們是「對模型設防」，不是「補模型能力」 | ⛔ **不可移除，且不需要做能力分析** |
| **(c) 路由骨架與其殘骸**（現存 4 agent、SKILL.md 派工點、跨 host 殘留） | 與模型版本無關 | 🔧 **修 > 刪**，這是本次真正的可執行項 |

現存 4 個 agent 中：**1 個有實測負載（`dotnet-code-reviewer`，134 次）、1 個路徑重複（`code-reviewer`）、2 個被 model pin 綁在較弱模型上（`uiux-reviewer` / `ui-ux-tester`）**。沒有一個的問題是「Opus 5 已經會了所以多餘」。

---

## 0. 必須先講的限定：July 的下降不是 Opus 5 的能力證據

實測模型分布（`~/.claude/projects` 6,536 份 transcript，依 `"model"` 欄位計數）：

| 模型 | 總數 | 2026-07 |
|---|---:|---:|
| claude-opus-4-8 | 96,817 | 32,126 |
| claude-fable-5 | 27,310 | 19,710 |
| claude-haiku-4-5 | 12,987 | 1,169 |
| **claude-opus-5** | **2,354** | **2,354** |
| claude-sonnet-5 | 1,683 | 1,683 |

**Opus 5 只佔 7 月的約 4%。** 同期 `dotnet-code-reviewer` 從 6 月 125 次掉到 7 月 9 次，但 7 月是**設定稽核月、不是 .NET 開發月**——任務組成與模型組成雙重混淆。

→ **本報告不把使用量下降當成「模型變強所以不需要」的證據。** 任何以此為前提的刪除建議都是建立在巧合上。

---

## 1. 實測數據（可重跑）

### 1.1 subagent 實際派工次數（608 次，全 transcript）

| subagent | 次數 | 2026-04 | 05 | 06 | 07 |
|---|---:|---:|---:|---:|---:|
| general-purpose | 303 | 2 | 9 | 251 | 41 |
| **dotnet-code-reviewer**（客製） | **134** | – | – | 125 | 9 |
| Explore | 83 | 9 | 37 | 27 | 10 |
| code-simplifier（plugin） | 36 | – | – | 28 | 8 |
| dotnet-developer（**已於今日刪除**） | 35 | – | – | 33 | 2 |
| claude-code-guide | 10 | 2 | 4 | 2 | 2 |
| 其餘（Plan / statusline / …） | 7 | | | | |
| **code-reviewer（客製）** | **0** | – | – | – | – |
| **uiux-reviewer（客製）** | **0** | – | – | – | – |
| **ui-ux-tester（客製）** | **0** | – | – | – | – |

重跑指令見 §6。

### 1.2 ⚠️ 0 次使用**不能**推論「無用」——corpus 沒有前端專案

依專案目錄切分後：**529 / 608 次（87%）來自 `DCT_data_import*`**，那是一個沒有任何前端的 .NET Console ETL 專案。其餘來自 `Claude-Project`、`coding_agent_project` 等，主要是 `Explore`。

**corpus 裡根本沒有 Vue / React 專案。** 所以 `uiux-reviewer` / `ui-ux-tester` 的 0 次，測到的是「沒有前端任務」，不是「前端 agent 沒價值」。對主力有 Vue + React 的你，用這個 0 去推論刪除，正好是你的 stack 會打臉的推論。

---

## 2. 現存 4 個客製 agent 逐一判決

### 2.1 `dotnet-code-reviewer` — **Keep（唯一有實測負載者）**

- 134 次派工，是所有客製 agent 中唯一被用過的。
- 被三處路由引用：`~/.claude/CLAUDE.md:23`（.NET 深審）、`dev-workflow/references/ledgers.md:45,75`（Closeout Ledger 的 reviewer 欄位範例）、`dev-workflow/SKILL.md:125`（S5 stack 專精 agent）。
- `model: inherit` ✅ 正確（跟著主 loop 跑 Opus 5）。
- **🔴 但 description 有兩個今日剛產生的 dangling 參照**：

  > `~/.claude/agents/DotNet-Code-Reviewer.md:3` — 「…use the **dotnet-developer** agent to implement fixes. For test strategy, use the **dotnet-testing-expert** agent.」

  這兩個 agent **今日 09:57 的整併已刪除**（備份在 `~/.agents/backups/20260725-agents-consolidation/claude/DotNet-Developer.md`、`DotNet-Testing-Expert.md`）。description 是**常駐載入**的，等於每個 session 都在教模型去叫兩個不存在的 agent。
  → **P1：改寫這兩句，指向 `dotnet-core-best-practices` / `dotnet-testing-best-practices` skill（跨三家可用）。**

### 2.2 `code-reviewer`（泛用）— **Delete（唯一建議刪的）**

- 0 次使用，且**原因已查明不是意外**：`CLAUDE.md:23` 同一行同時規定了兩條路徑——「dispatch `general-purpose` + 套 `code-reviewer.md` 模板」與「其餘 → `code-reviewer` agent」。那 303 次 `general-purpose` 就是實際跑的 review。
- `dev-workflow/references/reviewer-template.md` 開頭已明寫設計意圖：**「沒有專屬 review agent 的 host 用本檔；有專屬 agent 的 host 改用 agent」**。泛用 `code-reviewer` 卡在兩者中間，兩邊都不需要它。
- → **刪 `~/.claude/agents/code-reviewer.md`，並把 `CLAUDE.md:23` 的「其餘 → `code-reviewer`」改成「其餘 → `general-purpose` + `reviewer-template.md`」**（這也讓 Claude 與 Codex / Copilot 走同一條路，符合三家統一目標）。
- 註：`init-project-docs/references/agents/code-reviewer.md` 是**產給新專案的模板**，與此無關，不受影響。

### 2.3 `uiux-reviewer` — **Keep + 修 model pin（你的 stack 才是判準）**

- 0 次使用 = corpus 無前端專案（§1.2），不是無用。
- `CLAUDE.md:29` 已有明確路由：「前端實作後 UI/UX 視覺品質審查 → `uiux-reviewer` agent」；`dev-workflow/SKILL.md:125` 也點名它（並正確標註 Claude-only、另兩家標 UNAVAILABLE）。
- **🟠 `model: sonnet`** — 在 Opus 5 session 裡它會跑在較弱的模型上。這與你記憶中的 `version-pin silent-fail` 同一類陷阱：pin 不會報錯，只會靜默降級。
  → **P1：改 `model: inherit`。**
- 它做的是「開瀏覽器、看實際渲染畫面」，**這是工具鏈能力不是知識**，模型再強也不會自己去開 Chrome。這正是不該刪的理由。

### 2.4 `ui-ux-tester` — **無路由指向，需你裁決（不是「重疊所以刪」）**

**先排除一個錯誤推論**：它的 0 次使用和 `uiux-reviewer` 的 0 次是**同一個原因**（corpus 無前端專案，§1.2）。既然那個 0 不能拿來否定 `uiux-reviewer`，就同樣不能拿來否定它。

真正的差別是**可達性**，這是實測的：

- `uiux-reviewer`：被 `CLAUDE.md:29` 與 `dev-workflow/SKILL.md:125` 點名 → 會被路由到。
- `ui-ux-tester`：**沒有任何 CLAUDE.md / SKILL.md 路由指向它**，只有 `uiux-reviewer` 的 description 反向提及 → 除非你手動點名，否則它**永遠不會被觸發**。

→ **兩個選項，請你選（我不自行決定）**：
- **(甲) 讓它可達**：在 `CLAUDE.md:29` 補觸發條件（例如「有文件化 user flow 需逐條回歸測試時 → `ui-ux-tester`；只需視覺品質審查 → `uiux-reviewer`」），並改 `model: inherit`。
- **(乙) 折進去**：把它的「exhaustive flow 測試 + 缺陷報告格式」段落併入 `uiux-reviewer`，然後刪除檔案。

甲的成本是多一行路由；乙的成本是一次合併編輯。兩者都比現狀好——現狀是一個永遠不會被叫到的檔案。

---

## 3. 全域設定對照：哪些被 workflow 用到、不可移除

**判準：這一層跟模型能力無關。** `[T0-3]` 自己就寫了「各 host 以 hook／exec policy／CI guard 機械攔截；prose 僅作 defense-in-depth」——模型變強不會讓一條自我約束變得可信，機械閘門才會。

### 3.1 ⛔ 絕不可移除（workflow 硬相依）

| 設定 | 被誰用到 | 移除後果 |
|---|---|---|
| `hooks.PreToolUse` → `guard-git-push.sh` | `[T0-3]` 的**唯一**機械執行點 | force-push main 只剩 prose 防線 |
| `hooks.PostToolUse` → `watch-ci-after-push.sh` | `[T0-9]` merge gate、dev-workflow S6 | CI 綠燈判定失去自動監看 |
| `hooks.SessionStart` → `~/.agents/hooks/drift-check.sh` | 三家設定同步（`agents-sync`）的漂移偵測 | CLAUDE.md / AGENTS.md / copilot-instructions.md 靜默分歧 |
| `hooks.PreToolUse` → `guard-cookbook-orphan.sh` | `rules/cookbook.md` 的 orphan 守護 | cookbook 孤兒檔無人擋 |
| `permissions.deny`（23 條） | `[T0-4]` 憑證、`[T0-3]` 破壞性指令 | secrets 讀取與 `git reset --hard` 等失去攔截 |
| `autoMode.allow` / `soft_deny` 的 **`"$defaults"`** | 你的記憶 `claude-automode-defaults-and-async-hooks` | **省略 `$defaults` = 內建防線被整段取代**，不是疊加 |
| `permissions.additionalDirectories: ~/.agents` | 52 個 skill 的正本位置 | 全部 skill 讀不到 |
| `sandbox.*`（含 `allowWrite` 白名單） | dotnet / npm / Playwright 快取寫入 | build 與測試在沙箱下失敗 |
| `env.DOTNET_SYSTEM_NET_DISABLEIPV6=1` | 你的記憶 `sandbox-dotnet-test-ipv6` | 沙箱下 `dotnet test` 走 dual-stack loopback 失敗 |

### 3.2 ✅ 保留但屬「能力放大器」，不是能力補丁

`effortLevel: xhigh`、`ultracode: true`、`alwaysThinkingEnabled`、`advisorModel: opus`、`CLAUDE_CODE_MAX_OUTPUT_TOKENS: 128000`、`autoCompactWindow: 1000000`。
這些**因為模型變強而更有價值，不是被取代**。唯一要留意：`ultracode: true` 讓每個實質任務預設走 workflow 多 agent 編排——若你覺得 token 消耗過高，這是比刪 agent 有效**兩個數量級**的旋鈕（刪 4 個 agent 省 < 1k token；關 ultracode 省的是整批 subagent）。

### 3.3 🔧 該修的設定殘骸

| 項目 | 事實 | 建議 |
|---|---|---|
| `dev-workflow/SKILL.md:135` 寫 `feature-dev:code-reviewer` | `feature-dev@claude-plugins-official` **已安裝但不在 `enabledPlugins`** → 該 agent 不存在 | 改成 `general-purpose` + `reviewer-template.md`，與 §2.2 對齊 |
| `~/.codex/agents/` 有 **43 個 .toml** | 全部 2026-05-10 產生，`~/.codex/config.toml` **完全沒引用**；且包含今日已在 Claude / Copilot 端刪除的同名 agent（react-specialist、vue-expert、typescript-pro、DotNet-Developer…） | **今日整併只做了 Claude + Copilot，Codex 端漏了。** 建議一併移到 `~/.agents/backups/20260725-agents-consolidation/codex/` |
| `~/.copilot/agents/` 已空 | 今日整併移除 5 個 | ✅ 無動作 |
| `enabledPlugins` 中 `feature-dev` 缺項 | 安裝了卻沒啟用 | 二選一：啟用，或（建議）維持停用並修掉 SKILL.md:135 的引用 |

---

## 4. 依你的 stack 更新的建議

### 4.1 現況不對稱：.NET 有專精審查，前端只有泛用審查

你的主力是 **.NET + Vue/React/TS/Node 各半**，但：

- **.NET**：`dotnet-code-reviewer`（180 行、EF Core N+1 / 併發 / API 破壞性變更 / NuGet 稽核）+ 6 個 dotnet skill + `rules/dotnet.md`
- **前端 / Node**：今日刪光了 react-specialist / vue-expert / typescript-pro / frontend-developer / nextjs-developer，審查只剩泛用 template

**這個刪除本身是對的**（那 5 個都是純知識載體，Opus 5 / GPT-5.6 完全 cover）。但要補的不是把 agent 加回來，而是把差異補在**跨三家可用的層**：

| 缺口 | ❌ 不建議 | ✅ 建議 |
|---|---|---|
| 前端 / Node review 深度 | 重建 `react-reviewer` agent（Claude-only，與三家統一目標相反） | 在 `reviewer-template.md` 的審查優先序下加一段 **stack 檢核**：React（re-render / key / effect cleanup）、Vue（reactivity 丟失 / hydration mismatch）、TS（`any` 洩漏 / 型別放寬）、Node（unhandled rejection / socket 洩漏）。三家共用，Codex 與 Copilot 也吃得到 |
| 前端 runtime 視覺驗證 | — | `uiux-reviewer` 保留並改 `inherit`（§2.3）；它提供的是 **Chrome 工具鏈**，不是知識 |
| stack 知識 | 重建 agent | 已有 `react-best-practices` / `vue-best-practices` / `typescript-best-practices` / `nodejs-best-practices` / `vite` / `vitest` / `playwright-best-practices` 等 skill，且皆在 `~/.agents/skills`（三家共用）——**這就是 agent 的替代品，已經到位** |

### 4.2 一句話取代規則

> **agent 是 Claude-only 的執行殼；skill 是三家共用的知識與流程載體。**
> 要刪的 agent，替代品一律往 `~/.agents/skills/` 放，不要往 `~/.claude/agents/` 加。
> `dev-workflow/SKILL.md:125` 已示範正確寫法：「前端 `uiux-reviewer`（Claude-only；另兩家該步標 UNAVAILABLE + 理由即合規）」。

---

## 5. 執行批次（皆為提案，待你裁決）

### Batch A — 修 dangling（P1，純修 bug，只動 `~/.claude/agents/`，不需 agents-sync）

1. `~/.claude/agents/DotNet-Code-Reviewer.md:3` — 移除 `dotnet-developer` / `dotnet-testing-expert` 兩處參照，改指 skill。
2. `~/.claude/agents/uiux-reviewer.md` — `model: sonnet` → `model: inherit`。
   （`ui-ux-tester.md` 的同一個 pin **不放這裡**——它的去留在 §2.4 待裁決，改完可能就刪掉；等你選甲/乙再一併處理。）

### Batch B — 收斂路徑（P2，需你點頭；**動到 `~/.agents/` 與 `CLAUDE.md` 正本，完成後必跑 agents-sync**）

3. `~/.agents/skills/dev-workflow/SKILL.md:135` — `feature-dev:code-reviewer` → `general-purpose` + `reviewer-template.md`。
4. 刪 `~/.claude/agents/code-reviewer.md`，同步改 `CLAUDE.md:23`。
5. `ui-ux-tester` 依 §2.4 選甲（補路由 + 改 pin）或乙（併入後刪除）。
6. `~/.codex/agents/` 43 個 orphan .toml 移進今日的 backups 目錄，讓三家整併狀態一致。

### Batch C — 補前端審查深度（P2，最有實質收益）

7. `reviewer-template.md` 加 stack 檢核段（React / Vue / TS / Node），三家共用。

**執行後必跑**：`~/.agents/bin/agents-sync`（Batch B/C 動到 `CLAUDE.md` 與 `~/.agents/` 正本，三家衍生檔需重生）+ `drift-check.sh` 驗證。

### 不建議做的事

- ❌ 因為「Opus 5 夠強」而刪 `dotnet-code-reviewer` —— 它的價值是**乾淨 context 的獨立審查視角**，不是知識；同一顆模型在主 context 自審 ≠ 獨立審查（`reviewer-template.md` 的 UNAVAILABLE 規則明文禁止靜默自審）。
- ❌ 動任何 §3.1 的 hook / permission —— 那層與模型能力正交。
- ❌ 為了省 token 而刪 agent —— 4 個 agent 的常駐成本只有 description（約 1.3k 字元 ≈ 400 token）；真正的旋鈕在 `ultracode` / `effortLevel`。

---

## 6. 重跑驗證指令

```bash
# subagent 實際派工統計
grep -ho '"subagent_type":"[^"]*"' $(find ~/.claude/projects -name "*.jsonl") | sort | uniq -c | sort -rn

# 現存客製 agent 與 model pin
grep -H "^model:" ~/.claude/agents/*.md

# dangling 參照
grep -rn "dotnet-developer\|dotnet-testing-expert\|feature-dev" ~/.claude/agents/ ~/.agents/skills/dev-workflow/

# 三家 agent 目錄現況
ls ~/.claude/agents/ ~/.copilot/agents/ ~/.codex/agents/ | wc -l
```

---

## 7. 假設與限定

1. **Opus 5 / GPT-5.6 的知識覆蓋是推論不是實測。** 本報告沒有跑 A/B 對照（同一 PR 分別用「有 agent」與「無 agent」審查、比對 findings 數與品質）。§2 的 Keep 判決**不依賴**該推論成立（依據是路由負載與工具鏈能力）；§4.1「刪前端 agent 是對的」則依賴它——若你要硬證，A/B 是唯一途徑。
2. **usage 統計只涵蓋 Claude Code transcript。** Codex 與 Copilot 端無等價 transcript 可統計，其 agent 使用率未知（但 §3.3 已證 Codex 的 43 個從未被 config 引用）。
3. **今日 09:57 的整併未留報告**，本檔的「已刪 14+5」由 `~/.agents/backups/20260725-agents-consolidation/` 的檔案清單反推。

---

## 8. 複驗與更正（2026-07-25 10:4x，同日重跑）

### 8.1 事實複驗：全部仍成立

| 檢查項 | 結果 |
|---|---|
| `model:` pin | `dotnet-code-reviewer` / `code-reviewer` = `inherit`；`uiux-reviewer` / `ui-ux-tester` = **`sonnet`（未修）** |
| dangling 參照 | `DotNet-Code-Reviewer.md:3` 的 `dotnet-developer` / `dotnet-testing-expert` **仍在**；`dev-workflow/SKILL.md:135` 的 `feature-dev:code-reviewer` **仍在** |
| 三家 agent 數 | Claude 4 / Copilot 0 / Codex 43（未變） |
| Batch A/B/C | **皆未執行**（本檔仍為純提案） |

`feature-dev` 措辭更正：本次只確認**它不在 `enabledPlugins` 清單中**（未複驗是否已安裝），故 `feature-dev:code-reviewer` **無法解析**。SKILL.md:135 的修法不受影響。

### 8.2 🔴 更正：§2.2 的 0 次論證與 §1.2 自相矛盾

§1.2 立了「0 次 = corpus 無前端專案，不代表無用」來**保住** `uiux-reviewer`；§2.2 卻用 0 次**刪掉** `code-reviewer`。但依 `CLAUDE.md:23`，`code-reviewer` 正是「非 .NET 深審」的路由目標——那 303 次 `general-purpose` 全部來自 .NET-only corpus，同樣沒測到前端路徑。**同一份報告不能對兩者套不同判準。**

→ **B#4 與 C#7 有硬相依**：在 `reviewer-template.md` 尚無 React / Vue / TS / Node 檢核段之前刪 `code-reviewer`，等於把 §4.1 指出的不對稱（.NET 有 180 行專精審查、前端只有泛用模板）用自己的 Batch B 再造一次。

**執行約束：B#4 不得早於 C#7。** 兩者同批出，或維持 `code-reviewer` 直到模板吸收 stack 檢核。

### 8.3 §3.1 列舉補遺（原表非窮舉）

| 設定 | 分類 | 說明 |
|---|---|---|
| `PreToolUse` → `~/.claude/hooks/audit-bash.sh`（**`async: true`**） | 🟡 **可觀測性，非 gate** | async hook 依定義**無法攔截**（記憶 `claude-automode-defaults-and-async-hooks`）。`~/.claude/audit-bash.log` 已 4.7 MB；嫌長可移除，不影響任何 gate |
| `SessionStart` → `patch-playwright-mcp.sh` | ⛔ 不可移除 | 與已列的 `patch-chrome-devtools-mcp.sh` 同性質（MCP 啟動修補） |
| `~/.agents/hooks/guard-codex-git-push.sh` | ⛔ 不可移除 | **Codex 端的 `[T0-3]` 機械執行點**，與 Claude 端 `guard-git-push.sh` 對稱；三家統一敘事的另一半 |

### 8.4 框架更正：Keep 判決不依賴模型能力推論

原問題是「模型夠強了、agent 是否都能移除」。誠實答案前置：**沒有任何一個 Keep 判決以模型能力為依據**——依據是**路由可達性**與**工具鏈存取**（Chrome 渲染、乾淨 context 的獨立審查）。唯一依賴「Opus 5 / GPT-5.6 知識覆蓋」推論的是 §4.1「刪那 14 個知識載體是對的」，而**那件事今日 09:57 已執行完畢**。

GPT-5.6 側補答：`~/.codex/agents/` 43 個 `.toml` **無一被 `config.toml` 引用**，今日即為非功能狀態 → 該側的問題不是「能力是否覆蓋」，而是三家一致性的清理（§3.3 第 2 列）。

---

## 9. 與 Codex（gpt-5.6-sol）建議的對照 · 2026-07-25

### 9.1 🔴 我方重大更正：Codex 的 43 個 agent **是 live 的，不是 orphan**

§3.3 與 §8.4 原稱「43 個 `.toml` 無一被 `config.toml` 引用 → 今日即為非功能狀態」。**該推論不成立，予以撤回。**

反證（本次實查）：

| 證據 | 內容 |
|---|---|
| 檔案格式 | `~/.codex/agents/*.toml` 為 Codex 原生 custom-agent 格式（`description` + `developer_instructions`），非殘骸格式 |
| 對照組 | `~/.codex/skills/` **同樣未被 `config.toml` 引用**，但 skill 明確可用 → 該目錄採**慣例自動探索**，不需 config 列名 |
| 停用機制 | 存在 `~/.codex/skills-disabled/`（移出即停用），**無 `agents-disabled`**，佐證同一慣例 |
| host 能力 | `dev-workflow/SKILL.md:129` Codex adapter 明載 `子代理 = spawn_agent / wait_agent` → 該 host 有 subagent 機制，43 個即其 roster |
| config.toml 對照 | plugins / mcp_servers **有**列名機制，agents / skills **沒有** → 兩者屬不同載入路徑 |

**影響：Codex 側清理的優先度從「三家一致性的美觀問題」升級為「43 份 description 常駐 + routing 互搶」的實質成本。** Codex 的建議建立在正確前提上，我方原前提是錯的。

### 9.2 🔴 我方第二個更正：`SKILL.md:135` 是 **Copilot** 段不是 Codex 段

複驗 `SKILL.md:120-140`：`feature-dev:code-reviewer` 位於 `### Copilot` adapter 的 S5 行（`### Codex` 在 127，body 為 128–130）。修法不變（`feature-dev` 是 Claude plugin 名，出現在 Copilot 段本身就是錯的），但歸屬須更正。

### 9.3 兩份建議的收斂與分歧

**完全一致（雙方獨立得出，可信度最高）**

1. framework / implementation persona（react-specialist、vue-expert、typescript-pro、csharp-developer、DotNet-Developer…）→ 移除，改用 built-in worker + 對應 `*-best-practices` skill。
2. workflow 正本（tier0/1/2、routing、dev-workflow SKILL.md、reviewer-template、ledgers、review-triage）與 stack skills → **必留，不得跟著刪**。
3. `dotnet-code-reviewer` → 保留（唯一有實測負載；主力 stack 對齊）。
4. `dotnet-code-reviewer` 的 dangling coupling（指向已刪的 DotNet-Developer / Testing-Expert）→ **雙方獨立發現，兩個 host 各有一份**：`~/.claude/agents/DotNet-Code-Reviewer.md:3` 與 `~/.codex/agents/DotNet-Code-Reviewer.toml:5`。

**分歧一：Claude `code-reviewer` 去留 → 採 Codex 立場（保留）**

我方 §2.2 判 Delete（0 次使用）；Codex 判 Keep。**Codex 對，但理由不對。** 它給的是「已有 hard routing」——這是循環論證（routing 可改）。真正的理由是 §8.2 的：`code-reviewer` 是「非 .NET 深審」的路由目標，涵蓋你 stack 的前端半壁，而那 303 次 `general-purpose` 全來自 .NET-only corpus，沒測到該路徑。

→ **§2.2 的 Delete 判決撤回，改 Keep。** 連帶效果：§8.2 提出的「B#4 不得早於 C#7」耦合**自動解除**（不刪就沒有覆蓋真空）。Batch C（reviewer-template 補 React/Vue/TS/Node 檢核段）仍應做，但降為獨立增益項。

**分歧二：Codex 保 5 個 vs 我方建議統一保 3 個**

Codex 提議 Codex 側保留 `code-reviewer`、`dotnet-code-reviewer`、`Database-Performance-Optimizer`、`security-auditor`、`ui-ux-tester`。後兩者我方持保留意見：

| Agent | Codex 理由 | 我方異議 |
|---|---|---|
| `security-auditor` | Auth/API/Node 獨立 read-only audit | `SKILL.md:130` 已載明 Codex 側 **S4 codex-security 疊加**（`codex-security@openai-curated` plugin 已啟用）→ 與既有 plugin 職能重疊；另有 `security-audit` / `security-review` 兩個三家共用 skill |
| `Database-Performance-Optimizer` | query plan / index / N+1 | `mysql-best-practices` / `ef-core-best-practices` / `dapper-best-practices` 三個共用 skill 已覆蓋；且 Claude 側無對應角色 → 保留會製造新的跨 host 不對稱，與三家統一目標相反 |

同時 Codex 自己對 `ui-ux-tester` 立了正確的判準：**「未接入 workflow 就是休眠角色，應歸檔」**。這個判準套回它自己保的那 5 個，`security-auditor` 與 `Database-Performance-Optimizer` 同樣未被任何 host adapter 點名 → 依它自己的標準也該歸檔。

**分歧三：Codex 漏了兩層**

1. **`model:` pin**：`~/.claude/agents/uiux-reviewer.md` 與 `ui-ux-tester.md` 仍為 `model: sonnet`，在 Opus 5 session 會靜默降級。Codex 建議保留 `uiux-reviewer` 卻未提此項——保留一個被 pin 在較弱模型上的 agent，收益打折。
2. **settings.json 機械層**：Codex 的「全域設定」表只涵蓋 `~/.agents/core` 與 dev-workflow 文件層，未觸及 hooks / permissions.deny / sandbox / `autoMode.$defaults` / `DOTNET_SYSTEM_NET_DISABLEIPV6`。兩份報告在此**互補非衝突**：Codex 管流程正本，本報告 §3.1 + §8.3 管機械閘門。

### 9.4 合併後最終建議

**角色統一為 3 個 × 每 host**（判準：需要乾淨 context 的獨立審查，或需要工具鏈的實機驗證）

| 角色 | Claude | Codex | Copilot |
|---|---|---|---|
| 泛用獨立 review（前端半壁） | `code-reviewer` ✅ | `code-reviewer` ✅ | `reviewer-template.md` |
| .NET 深審 | `dotnet-code-reviewer` ✅ | `DotNet-Code-Reviewer` ✅ | 已知取捨（降級） |
| 前端實機驗證 | `uiux-reviewer` ✅ | `ui-ux-tester`（**條件**：接進 S4/S5，否則歸檔） | UNAVAILABLE |

| Host | 現況 | 保留 | 移除 |
|---|---:|---:|---:|
| Claude | 4 | 3 | 1（`ui-ux-tester` → 併入 `uiux-reviewer` 後刪，即原 §2.4 選項乙） |
| Codex | 43 | 3（或 5，若你要保 security/db-perf） | 40（或 38） |
| Copilot | 0 | 0 | 0 |

**P1 必修（不論保留幾個都要做）**

1. `~/.claude/agents/DotNet-Code-Reviewer.md:3` 與 `~/.codex/agents/DotNet-Code-Reviewer.toml:5` — 移除 dangling 的 DotNet-Developer / Testing-Expert 參照，改指「交回 parent + 套 `dotnet-core-best-practices` / `dotnet-testing-best-practices` skill」。
2. `~/.claude/agents/uiux-reviewer.md` — `model: sonnet` → `inherit`。
3. `dev-workflow/SKILL.md:135`（**Copilot** 段）— `feature-dev:code-reviewer` → `general-purpose` + `reviewer-template.md`。

---

## 10. 執行紀錄 · 2026-07-25（已完成）

**用戶裁決**：Codex 保 3 個（拒絕 security-auditor / Database-Performance-Optimizer）、`ui-ux-tester` 歸檔 → 實際落地為 **Claude 3 / Codex 2 / Copilot 0**（`ui-ux-tester` 兩 host 皆歸檔，故 Codex 只剩 2 個 reviewer 角色）。

### P1 修復（6 處）

| # | 檔案 | 改動 |
|---|---|---|
| 1 | `~/.claude/agents/DotNet-Code-Reviewer.md:3` | description 移除 `dotnet-developer` / `dotnet-testing-expert` → 改指 skill |
| 2 | `~/.claude/agents/DotNet-Code-Reviewer.md:11` | **額外發現**：`dotnet-best-practices` skill **不存在**（只有 `dotnet-core-` / `dotnet-framework-`）→ 修正 |
| 3 | `~/.codex/agents/DotNet-Code-Reviewer.toml:1` | 同 #1 |
| 4 | `~/.codex/agents/DotNet-Code-Reviewer.toml:5` | `**DotNet Developer**` / `**DotNet Testing Expert**` agent → skill |
| 5 | `~/.codex/agents/DotNet-Code-Reviewer.toml:14` | **首輪掃描漏網**：`dispatch the DotNet Developer agent` → `apply the fixes itself` |
| 6 | `~/.claude/agents/uiux-reviewer.md:3-4` | `model: sonnet` → `inherit`；description 移除已歸檔的 `ui-ux-tester` 參照 → 改指 `playwright-best-practices` / `agent-browser` skill |

額外：`~/.agents/skills/dev-workflow/SKILL.md:135`（Copilot 段）`feature-dev:code-reviewer` → `泛用 subagent`；`~/.codex/agents/code-reviewer.toml:1` 大小寫對齊實際檔名 `DotNet-Code-Reviewer`。

### 歸檔（移動，非刪除；全數可還原）

- Codex 41 個 `.toml` → `~/.agents/backups/20260725-agents-consolidation/codex/`（保留 `code-reviewer.toml`、`DotNet-Code-Reviewer.toml`）
- Claude `ui-ux-tester.md` → 備份已於 09:57 存在且 `diff` 驗證完全相同，故移除 live 檔即完成歸檔

### 驗證證據

```
最終 dangling 掃描（8 個關鍵字 × 三家 agent 目錄 + CLAUDE.md/AGENTS.md/copilot-instructions.md + dev-workflow + core）→ 無輸出
model pin：三個 Claude agent 全部 model: inherit
agents-sync → 三家衍生檔皆「未變，跳過」（本次只動 Copilot S5 措辭，routing stamp 不受影響）
drift-check.sh → exit 0
三家最終：Claude 3 / Codex 2 / Copilot 0；備份 codex 41 檔 + claude 18 檔
```

### 未 commit（需你裁決）

- `~/.agents` 在 `chore/codex-global-optimization` 分支，但**含 13 個與本次無關的既有未提交變更**（core/、rules/、dist/ 等）→ 混提會違反 [T1-3]，建議單獨挑 `skills/dev-workflow/SKILL.md` 提交
- `~/.claude` 在 **`main`**（受保護分支）→ 依 Auto-mode 規則需你確認

### 10.1 提交紀錄

| Repo | 分支 | Commit | 範圍 |
|---|---|---|---|
| `~/.claude` | `main`（用戶明確確認） | `3753368` | `agents/` — 41 D + 2 M |
| `~/.codex` | `chore/codex-global-optimization` | `35f50c6` | `agents/` — 41 D + 2 M |
| `~/.agents` | `chore/codex-global-optimization` | `bd3c9e2` | `skills/dev-workflow/SKILL.md` 單檔 |

刻意未納入（避免 [T1-3] 邏輯混雜，屬本次以外的既有未提交變更）：`~/.agents` 的 `core/`、`rules/`、`dist/`、`hosts/` 等 13 檔；`~/.claude` 的 `settings.json`、`CLAUDE.md`、`commands/`、`hooks/`、`rules/`、`skills/` symlink 變更。稽核提案檔（`proposals/`）依「不 commit AI 生成 plan」規則維持未追蹤。

三個 repo 皆**未 push**（用戶未要求）。

### 10.2 全面整理與推送（2026-07-25 收尾）

四個 host repo 的剩餘未提交變更一併整理，各自拆成邏輯單元（[T1-3]），共 12 個 commit：

| Repo | Commits | 內容 |
|---|---:|---|
| `~/.claude` (main) | 6 | agent 整併 · 共用層 symlink 遷移 · settings.json(env/hooks/sandbox/autoMode) · CLAUDE.md(R-4 + routing stamp) · /sdd 薄殼 · watch-ci 詞界修正 |
| `~/.agents` (chore/codex-global-optimization) | 6 | dev-workflow S5 修正 · gitignore(`*.bak-*` + `backups/`) · core/hosts/dist 規則修訂 · rules 前端選型 · WinForms 16 條 + 3 reference · dist 戳記 |
| `~/.codex` | 2 | agent 整併 · **移除 7 個失效 TempoTerm hook**（`/Applications/TempoTerm.app` 不存在，Claude 端今日已清、Codex 端漏了） |
| `~/.copilot` (main) | 2 | 5 個 persona agent 移除 · memory MCP 移除 + 專案權限 |

**推送**：`~/.claude` → `origin/main`（`10ff64b`）、`~/.agents` → `origin/chore/codex-global-optimization`（`14089af`），皆以 server 端 `ls-remote` SHA 比對驗證（`failed to store: 100001` 為已知沙箱 ref 寫入錯，內容已送達）。`~/.codex` / `~/.copilot` 無 remote，僅本地。兩個 remote repo 皆無 CI workflow 與 PR，無 gate 待驗。

**stitch MCP 移除**：`enabled = false` 且 914 份 Codex session 僅 2 次工具層出現，職能與 frontend-design plugin / `uiux-reviewer` / `css-ui-best-practices` 重疊 → 刪除 `config.toml` 兩個區塊 + `stitch.env`。⚠️ **Google 後台撤銷舊 key 仍待用戶執行**——本機明文面已歸零，但 Codex 歷史 JSONL 中的舊副本要撤舊後才變死字串。

**最終驗證**：`drift-check.sh` exit 0；四 repo `git status` 皆乾淨（僅 `proposals/` 依規則維持未追蹤）。

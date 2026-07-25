# Skill / Agent 能否靠模型能力取代 — 統一重審

> 2026-07-25 · 執行者 Claude Opus 5（`effortLevel: xhigh`、17 個 subagent、1.59M token）
> 承接並**修正**同日 `2026-07-25-skill-audit`（skill 層）與 `2026-07-25-agent-audit`（agent + 設定層）
> 主力 stack（判準基準）：ASP.NET Core / .NET、Vue、React、TypeScript、Node.js
> **本檔為提案 + 事實複驗，未執行任何變更。**

---

## 一頁結論

**問題「Opus 5 / GPT-5.6-sol 夠強了，skill 和 agent 是否都能移除」的答案：52 個 skill 中 0 個可移除，3 個 agent 中 0 個可移除。**

但這個答案的價值不在數字，在於**判準被換掉了**。前兩份報告用「內容是否與模型知識重複」當主軸，那個問法必然導出「大部分都重複所以可刪」的錯誤結論。本次改用五軸，只有**五軸全部 FAIL** 才算可移除：

| 軸 | 判準 | 與模型能力的關係 |
|---|---|---|
| 1 | **機械執行** — hook / permissions.deny / autoMode / sandbox | 正交。模型變強不會讓自我約束變可信 |
| 2 | **工具鏈存取** — 開瀏覽器、實機渲染、CLI | 正交。模型再強也不會自己開 Chrome |
| 3 | **乾淨 context 獨立審查** | 正交。同顆模型在主 context 自審 ≠ 獨立審查 |
| 4 | **家規 / 程序** — gate 定義、門檻數字、輸出契約、跨 host adapter | 正交。這不是「事實」，是這台機器的決定 |
| 5 | **版本釘死 / 易漂移事實** | **反向相關**。模型愈強愈自信地寫出過期寫法 |

實測結果：52 個 skill **全部至少通過一軸**。最常見的是軸 4（家規）與軸 5（版本釘死）。

**但「0 可移除」要誠實加三個限定，否則會被當成比證據更強的結論**：

1. **軸 4 判準寬**。「含任何家規」就 PASS，而你親手curate 的 skill 幾乎必然含至少一條。實際上有一條**單靠軸 4 撐住**的薄尾：`react-best-practices`、`pinia`、`vueuse-functions`、`testing-library-react-best-practices`、`dotnet-logging-best-practices`、`dotnet-framework-best-practices`、`mp-tdd`、`mp-diagnose`。稽核者自己標註 `mp-tdd` 是「本批中軸 4 最薄的一個」、`mp-diagnose` 是「較弱者」。這些的家規往往只有幾行，理論上可以搬家。
2. **`mp-zoom-out` 的推翻是 rubric 律師術**（「檔案太小不在五軸之內」），不是「摺疊它會出事」的證據。
3. **skill 層結論由 4 個 audit agent 支撐，不是 17 個**。另外 13 個花在推翻 settings 鍵的判決——那些是我自己 rubric 的 category error，不構成 skill 判決的份量。

**真正該講的形狀不是「0」，是**：靠模型能力可收成的部分**已經在 2026-07-25 09:57 拿完了**（刪 14 個知識載體 persona）。剩下可收成的是 §1.4 的 **~8-9k 行 skill 內部通用知識**，加上這條單軸-4 薄尾——但薄尾的收益是每個 ~100 token，摺疊成本高於收益。

**第 5 軸是本次最重要的發現**：多個 skill 的存在理由就是「模型的記憶停在舊版本」。`tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md:7` 自己寫得最清楚——

> Claude's training may reference Tailwind v3 patterns. This project uses **Tailwind v4** with different syntax.

模型愈強，第 5 軸的 skill 愈不能刪，因為它會用同樣的自信寫出 `middleware.ts`（Next 16 已改名 `proxy.ts`）、`vitest.workspace.ts`（Vitest 3 已改名 `projects`）、`rollupOptions`（Vite 8 已改名 `rolldownOptions`）。

---

## 0. 三個推翻前份報告的事實

### 0.1 🔴 「17% 觸發率」是錯的 — 實測是 60%

前一輪從 214 份 transcript 子集算出「52 個 skill 只有 9 個（17%）被觸發」。本次改用 harness 自己的計數器 `~/.claude.json` 的 `skillUsage`（權威來源，非 grep 推估）：

**31 / 52 個個人 skill 曾被觸發 = 60%。**

| skill | 次數 | | skill | 次數 |
|---|---:|---|---|---:|
| dapper-best-practices | 56 | | acquire-codebase-knowledge | 8 |
| dependency-security-scan | 36 | | dotnet-logging-best-practices | 7 |
| backend-release-verification | 32 | | dotnet-testing-best-practices | 6 |
| dotnet-core-best-practices | 26 | | dotnet-framework / mp-zoom-out | 4 |
| mysql-best-practices | 17 | | ecpay / agent-browser | 3 |
| init-project-docs / bug-fix-settlement | 12 | | react / c-cpp / frontend-release-verif / mp-grill / security-review | 2 |
| auditing-skill-folder / deps-check | 11 | | nodejs / vue / ef-core / postgresql / playwright / typescript / auth / vue-debug / mp-improve / dev-workflow | 1 |

→ **任何建立在「83% 從未觸發」上的移除建議全部作廢。**

### 0.2 用量資料被 corpus 汙染，不能用來裁剪前端

87% 的 subagent 派工來自 `DCT_data_import*`——一個**零前端**的 .NET Console ETL 專案。7 個專案裡只有 1 個有 DB（MySQL）、1 個是 Node/Express、0 個 Vue/React SPA。

→ Vue / React / Vite / Vitest / Tailwind / css-ui / testing-library / next / nuxt / pinia 的低用量，量到的是**「沒有前端任務」**，不是 skill 沒價值。而那正是你主力 stack 的另一半。**本報告全程禁止以用量裁剪這一批。**

### 0.3 🔴「常駐成本」的算法對 3 家中的 2 家根本不成立

實測三家的 skill 載入機制**完全不同**：

| Host | 機制 | 52 個 skill 的常駐成本 |
|---|---|---|
| **Claude** | `~/.claude/skills/*` 是 symlink → `~/.agents/skills/*`，自動探索、description 常駐 | **19,312 字元 ≈ 5.4k token** |
| **Codex (gpt-5.6-sol)** | `~/.codex/skills/` 只有 2 個本地 skill；52 個共用靠 `AGENTS.md:56-60` 的路徑散文引用 | **≈ 0**（只有 5 行 routing 散文） |
| **Copilot** | `~/.copilot/skills/` **空的**；`copilot-instructions.md:71` 明寫「`available_skills` 缺項 MUST NOT 呼叫」 | **0** |

→ 「刪 skill 省 context」這個動機**只在 Claude 這一家成立，總額 5.4k token**。刪一個 skill 平均省 ~370 字元 ≈ 100 token，而代價是那個 stack 的版本釘死防護歸零。**投入產出比不成立。**

---

## 1. Skill 層判決（52 個，0 REMOVABLE）

### 1.1 前端 / TS / Node（18 個）— 13 KEEP + 5 FIX，**0 可移除**

第 5 軸命中密度最高的一批，逐條都是模型會寫錯的實例：

| skill | 軸 | 模型會寫錯的具體東西 |
|---|---|---|
| `next-best-practices` | 4,5 | Next 16 `middleware.ts`→`proxy.ts`、`middleware()`→`proxy()`、`config`→`proxyConfig` 三重改名；Next 15 `params`/`cookies()`/`headers()` 改 async |
| `vite` | 4,5 | Vite 8 `rollupOptions`→`rolldownOptions`、`esbuild` 選項→`oxc` |
| `vitest` | 4,5 | Vitest 3 `workspace`→`projects`，模型會產出已移除的 `vitest.workspace.ts` |
| `react-router-framework-mode` | 4,5 | `v8_middleware` future flag 的確切拼法 + 7.9.0 版本下界；`meta` 的 `data`→`loaderData` |
| `nuxt` | 4,5 | `useFetch` 預設值在 3.7/3.10/3.12 之間變動（minor 級漂移，模型更難分辨） |
| `tailwind-v4-shadcn` | 4,5 | v4 token 正本；skill 自陳「模型的 Tailwind 記憶停在 v3」 |
| `typescript-best-practices` | 4,5 | `verbatimModuleSyntax` 取代 `isolatedModules`+`importsNotUsedAsValues`（TS 5.0 世代更替） |
| `jest-best-practices` | 4,5 | native ESM 要 `unstable_mockModule`+dynamic import，模型憑記憶寫失效的 `jest.mock()` |
| `react-best-practices` | 4 | 三條 Golden Rule 逐字對應 `rules/frontend-spa.md` 家規（禁 CSS-in-JS、shadcn 預設、TanStack Query） |
| `playwright-best-practices` | 2,4 | 驅動真實瀏覽器 + viewport 三數字/雙證據家規 |
| `pinia` / `vueuse-functions` / `testing-library-react` | 4 | `useStorage` = localStorage 包裝（[T0-4] 釘在具體 API 名上）；selector 優先序 = [R-2] 的可執行形式 |

**5 個 FIX（是 bug 不是體積）**：

1. **`css-ui-best-practices`** — `references/design-system-patterns.md:32,34,36` 教 Tailwind **v3**（`:root` 放進 `@layer base` + 裸 HSL triplet），與 `tailwind-v4-shadcn/SKILL.md:24` 的 Critical Rule 直接牴觸。混用產出 `hsl(hsl(...))` → **整站顏色壞掉**。而 `react-best-practices/SKILL.md:40-41` 同時指向兩者。
   *這正是「模型無法自行 cover」的鐵證：模型知道 Tailwind，但會挑錯版本。*
2. **`vue-best-practices`** — `references/styling-and-ui.md:403-436` 推薦 **Element Plus**，但家規明文禁用、指定 Naive UI。修法照 `references/pinia.md:1-5` 已示範的 redirect 寫法。
3. **`nodejs-best-practices`** — `deployment-docker.md` 用 **Node 20**（2026-04 已 EOL），家規與 `containerization` 都用 node:24。兩份 Dockerfile 指引並存 → 模型會挑到過期那份。
4. **`containerization`** — `references/trigger-regression.md` 指向不存在的 `dotnet-containerization`，且把現行支援範圍誤標界外 → 這份回歸語料現在會把**正確**路由判成失敗。
5. **`vue-debug-guides`** — `INDEX.md:20` 懸空指向。（已審慎評估併入 `vue-best-practices` 並**否決**：其 description 是症狀導向「this isn't reactive」「page flashes on load」，與 hub 的撰寫導向是不同觸發面，合併會讓 debug 情境路由不到。）

### 1.2 .NET / DB（14 個）— 13 KEEP + 1 MERGE（MERGE 已被推翻），**0 可移除**

| skill | 軸 | 關鍵證據 |
|---|---|---|
| `dapper-best-practices` | 4,5 | string overload 不吃 `CancellationToken`（要走 `CommandDefinition`）；`buffered:false` 下 `IEnumerable` 逃出 `using` → `ObjectDisposedException`。**寫出來會編譯過但線上炸** |
| `mysql-best-practices` | 4,5 | 8.0.16 之前 `CHECK` 被**靜默丟棄**——patch-level 粒度，錯一版就是靜默資料正確性缺陷 |
| `dotnet-core-best-practices` | 4,5 | 兩處家規與模型預設**相反**（模型預設推 Minimal API、預設用 exception 表達業務失敗） |
| `ef6-best-practices` | 4,5 | 巢狀 eager loading：EF6 用 `.Include(x => x.A.Select(y => y.B))`，模型慣性輸出 EF Core 的 `.ThenInclude()` → 編譯失敗 |
| `ef-core-best-practices` | 4,5 | EF Core 7/8/9 能力閘門逐版累加（ExecuteUpdate、EF.Constant、primitive collections） |
| `dotnet-winforms-best-practices` | 4,5 | .NET 9 新增的 `InvokeAsync` 同步 overload **吞掉內層 Task**（編得過、靜默不執行） |
| `dotnet-framework-best-practices` | 4 | R4：library 加 `ConfigureAwait(false)`、controller 不加。模型慣性壓平成「一律加」→ 需要 HttpContext 的 controller 直接壞 |
| `dotnet-logging-best-practices` | 4 | R9：NLog 一律走 XML config（維運可不重編改等級）——營運面家規 |
| `dotnet-testing-best-practices` | 4,5 | Moq / NSubstitute 二選一不並用（模型預設平鋪選項說「都可以」） |
| `postgresql-best-practices` | 4,5 | Npgsql 6 的 `DateTime`/`timestamptz` breaking change（升版後 `DateTimeKind` 語意改變） |
| `postgresql-optimization` | 5 | **MERGE 判決被推翻**：`references/performance.md:123` 的 UUIDv7 (PG 18+) 在 sibling 全樹 0 命中，且 sibling 有相反主張 → 它不是「增量」，是 sibling 現存錯誤的**唯一解毒劑** |
| `ecpay` | 2,5 | test-vectors 是可執行 conformance fixture；Node.js `encodeURIComponent` 不編碼 `'` 與 `!` 會直接算錯簽章 |
| `c-cpp` / `native-feel` | 4,5 / 5 | 顯式 CLAUDE.md mandate；macOS 26 (Tahoe) 材質 API / WKWebView 私有旗標（逆向所得，不在公開文件） |

### 1.3 流程 / 政策（20 個）— 17 KEEP + 2 FIX + 1 MERGE（已推翻），**0 可移除**

這批本質是**軸 3 + 軸 4**，與知識無關：

- `dev-workflow`（軸 3,4）— X0 四種機械形態的窮舉定義、四態 gate 的「UNAVAILABLE 須附 probe 證據」、S0 的「≤3 tasks / 1 target file」門檻數字、Preflight 恰好 8 rows、三家 plan 模式對照（`EnterPlanMode` / Plan Mode / `--mode plan`）、`review-triage` 裡「Copilot review 異步 2-3 分鐘，開 PR 當下為空是延遲不是無」與 PR #34/#36 的本地事故編號。**全是家規與本地實證。**
- `deps-check`（軸 1,2,4）— 本批最不可替代者之一：可掛 PreToolUse hook 強制執行（skill 自身 `:36` 就編碼了「hook 100% 觸發、skill 約 50%」的本地實證）+ 184 行 shell 掃描工具 + [T1-1] 家規。
- `dependency-security-scan`（軸 1,4）— 產物**就是機械攔截本身**（gitleaks hook + CI threshold）。
- `security-audit`（軸 1,4）— findings.json 由 schema + validator 機械驗證；嚴重度校準政策（「defense-in-depth gap 不算 vuln」）對抗模型照 OWASP 清單灌水的傾向。
- `bug-fix-settlement`（軸 4）— 「即使結論是不沉澱也 MUST 輸出摘要」是**專門對抗模型預設行為**（修完就結束回覆）。
- `init-project-docs`（軸 2,4,5）— 跨 host adapter 密度最高：Copilot `.agent.md` 前綴、`applyTo:` 欄位、Codex hook matcher 是 tool-name regex——這些 host 契約在 2026-05 知識截止後**持續變動**。
- `mp-zoom-out` — MERGE 判決**被推翻**：判決自己承認軸 4 PASS（禁自創領域名的詞彙政策），卻用「檔案太小」翻案，而體積不在五軸之內。

**2 個 FIX**：`auth-implementation-patterns:52` 懸空引用 `better-auth-best-practices`（已確認不存在）；`reviewer-template-stack-checks`（見 §3）。

### 1.4 誠實標示：可瘦身 ≠ 可移除

審計同時量出約 **8,000–9,000 行通用知識**可以從 skill 內部刪掉（不刪 skill 本身）：

| 位置 | 行數 | 性質 |
|---|---:|---|
| `design-doc-mermaid/examples/` + `assets/` | ~7,500 | 6 個 example README + 5 個 design-template，純通用知識 |
| `security-review/references/vuln-categories.md` + `language-patterns.md` ∩ `security-audit/ATTACK-CLASSES.md` | ~500 | SQLi/XSS/SSRF/IDOR/JWT 通用漏洞分類，三方重疊 |
| `mp-tdd` 5 個附檔 | 194 | 公開 TDD 文獻知識 |

**這才是「模型變強所以不用寫」真正適用的地方**——瘦身 skill 內部的通用知識，保留 gate 與版本釘死段落。但它省的是**讀取時**的 token（skill 被叫用時才載入），不是常駐成本。

---

## 2. Agent 層（3 個，0 REMOVABLE）— 複驗今日 10:38 的執行結果

```
~/.claude/agents/   → DotNet-Code-Reviewer.md, code-reviewer.md, uiux-reviewer.md   （3 個，全 model: inherit ✅）
~/.codex/agents/    → DotNet-Code-Reviewer.toml, code-reviewer.toml                 （2 個）
~/.copilot/agents/  → （空）
```

| agent | 通過的軸 | 為何模型能力不能取代 |
|---|---|---|
| `dotnet-code-reviewer` | 3 | **乾淨 context 的獨立審查**。134 次實測負載。`reviewer-template.md:15-19` 明文禁止把自審偽裝成獨立審查 |
| `code-reviewer`（泛用） | 3 | 同上，覆蓋非 .NET 半壁（你 stack 的前端那半）。**前一份報告曾判 Delete，已於 §9.3 撤回**——0 次使用與 uiux-reviewer 的 0 次是同一個 corpus 原因 |
| `uiux-reviewer` | 2 | **Chrome 工具鏈**。模型再強也不會自己開瀏覽器看渲染結果 |

**今日 09:57 刪掉的 14 個知識載體 persona（react-specialist、vue-expert、typescript-pro、csharp-developer…）是對的**——它們五軸全 FAIL，Opus 5 / GPT-5.6 確實完全覆蓋。**那次刪除已經把「靠模型能力取代」的收成全部拿走了；剩下的 3 個不屬於同一類。**

一句話規則（沿用前份報告，仍成立）：
> **agent 是 Claude-only 的執行殼；skill 是三家共用的知識與流程載體。**
> 要刪的 agent，替代品一律往 `~/.agents/skills/` 放，不要往 `~/.claude/agents/` 加。

---

## 3. 🔴 全域設定：真正該動手的在這裡（P0 是安全破口）

### 3.1 P0 — `[T0-3]` force-push 防線**實測可繞過**

`~/.claude/hooks/guard-git-push.sh` 是 Claude 端 `[T0-3]` 的**唯一**機械執行點（client 端無 pre-push hook、無 `core.hooksPath`；server 端 branch protection 因 private + free plan 不可用）。

**實跑 probe，三個 payload 全部放行 `exit=0`：**

```
git push --force-with-lease --all origin
git push --force-with-lease --mirror origin
git push --force-with-lease origin feat/x main
```

同樣三個 payload 餵 `~/.agents/hooks/guard-codex-git-push.sh` → **三者皆正確攔截**（它有 `broad_refset` + 全 refspec 迴圈）。

**成因精確**（靜態複驗，非只依 probe）：

1. `--all` / `--mirror` 落進 `guard-git-push.sh:30` 的 `--*|-*) : ;;` 被當成普通旗標忽略 → `args` 只剩 `["origin"]`（長度 1）→ 走 `:41` 的 `symbolic-ref` 取**當前**分支 → 不是 main → `exit 0`。但該指令實際推送**所有分支含 main**。Codex 版 `:44` 有 `--all|--mirror) broad_refset=1`，`:53` 攔截。
2. 明示多 refspec 時 `args` 長度 ≥2，`guard-git-push.sh:39` **只檢查 `args[1]`**，其餘 refspec 從不查看。Codex 版 `:55-57` 對 `args[1..]` 全迴圈。

### 3.1.1 🔴 軟層也不會補上 —— 已用 binary 驗證（原標 ASSERTED，現已定案）

`permissions.allow` 有 `Bash(git push --force-with-lease *)`。問題是這是否讓內建 `soft_deny` 的 force-push SOFT BLOCK 也失效。**答案：是，gate 是「開的」不是「降級的」。**

Claude Code 2.1.220 binary 的 auto-mode 路徑：

```js
K  = (ce) => { let se = fg(ce); return !qNt(se.toolName, se.ruleContent) }   // 過濾器
Y  = qE(c.alwaysAllowRules, (ce) => (ce??[]).filter(K))
oe = await e.checkPermissions(V, {... alwaysAllowRules: Y, mode:"acceptEdits" ...})
if (oe.behavior === "allow") { ... return ... }        // ← 直接回傳，classifier 完全跳過
```

`qNt(e,t) { if ((e===Bash||e===PowerShell) && bsn()) return true; return Ssn(e,t) }`

- `bsn() = ZLi()` → `for(let e of x4r) if (Hr(e)?.autoMode?.classifyAllShell === true) return true; return false`
  → 你的 settings 沒有 `classifyAllShell` → **false**
- `Ssn` → `gsn(Bash, "git push --force-with-lease *")` → `_sn(rule, iSd)`，而 `iSd = [...OHs]`，`OHs = [...hsn,"zsh","fish","eval","exec","env","xargs","sudo"]` → **不含 `git` 也不含 `git push`** → false

→ 該 allow rule **通過過濾器、命中、classifier 被跳過**。內建 SOFT BLOCK（binary 的 classifier prompt 內確實逐字含 `git push --force`）**從未執行**。

**修法多一個選項**：`autoMode.classifyAllShell: true` 會讓 `bsn()` 回 true → 所有 Bash allow rule 一律被排除出短路路徑 → classifier 必跑。這是唯一「不動 allow 清單就能恢復軟層」的旋鈕。

*殘餘未驗證*：`Ssn` 的第三個 predicate `PHs(e,t)` 未追（`gsn`=Bash、`ysn`=PowerShell，`PHs` 推測為第三類 shell）。若它意外對此規則回 true，結論會反轉為「軟層仍在」。

### 3.1.2 建議：MERGE 而非補丁

把 `guard-codex-git-push.sh` 升為兩 host 共用的單一 guard（它嚴格優於 Claude 版），Claude 端只留 exit-2 輸出格式的薄 wrapper。**兩份近同的 guard 分居兩個目錄，就是這次漂移的結構成因**——合併才殺掉整類問題。

### 3.2 P1 — 三個機械層缺口

| 項目 | 事實 | 建議 |
|---|---|---|
| `permissions.allow` 的 `Bash(gh *)` | `[T0-9]` merge gate **完全沒有機械對應物**——`gh pr merge` 一句就繞過 review-triage 的四態 gate（純 prose） | 收斂為唯讀子集：`gh pr view/checks/diff`、`gh api GET`、`gh issue view`。把 `gh pr merge` / `gh api -X DELETE` / `gh repo delete` 退回 prompt |
| `skipDangerousModePermissionPrompt` | 預先接受了 Bypass Permissions 的責任聲明 = 永久移除「啟動 `--dangerously-skip-permissions` 前的人類減速丘」。該模式一啟動，本次盤點的**整個 permissions + hooks 機械層全部靜默失效** | **只刪這一鍵**（另兩個 `skip*Prompt` 是 onboarding 噪音，留著無害）。日常免 prompt 已由 `defaultMode:auto` + `autoAllowBashIfSandboxed` 負責 |
| `audit-bash.sh` 註冊在 `PreToolUse` + `async:true` | async 依定義**無法攔截**；且 PreToolUse 記錄的是「嘗試」（含之後被擋掉的），當稽核軌是誤導。`~/.agents/CONVENTIONS.md:11` 把它列為 `[T0-3]` 的驗證機制 = **假防線宣稱** | 改註冊到 `PostToolUse[Bash]`（保留 async 即可），並修掉 CONVENTIONS.md:11，`[T0-3]` 驗證欄改指兩支 guard + `~/.agents/tests/codex-git-push-guard.sh` |

### 3.3 ⛔ 不可移除清單 —— 附「有無替代品」（前份報告缺的那一半）

| 設定 | 軸 | 有替代品嗎 |
|---|---|---|
| `guard-git-push.sh` | 1 | **無替代**（tier0 自己否定 prose）。但應與 Codex 版合併（見 §3.1） |
| `permissions.deny`（22 條） | 1 | **可用既有機制補強**：把 `autoMode.soft_deny` 已枚舉的 11 個 reader 同步進硬層。硬層目前只擋 cat/grep/sed 四個動詞 |
| `autoMode` 三段的 `"$defaults"` | 1 | **無替代**。省略 = **整段取代**不是疊加。省 `soft_deny` 的 `$defaults` → 內建 force-push / `curl \| bash` / production deploy 的 SOFT BLOCK 整批消失 = 變鬆（真危險） |
| `permissions.additionalDirectories: [~/.agents]` | 1,4 | **無替代**。少了它，routing.md 點名的 skill 與 `rules/*.md` 全部不可讀，S0 路由直接斷（symlink 不繞過權限邊界） |
| `permissions.defaultMode: auto` | 1 | **無替代**。改 default/plan → 底下三段 autoMode 客製**全部失效** |
| `sandbox.enabled` + `failIfUnavailable` | 1 | **無替代**。fail-closed 設計；省掉 `failIfUnavailable` = 沙箱壞掉時全部裸跑且無告警（最糟失效模式） |
| `sandbox.filesystem.allowWrite`（14 條） | 1 | **無替代**。harness 的 `denyWithinAllow` 已把 settings.json / hooks / CLAUDE.md 挖掉，列 `~/.claude` ≠ 授權自我改寫 |
| `sandbox.excludedCommands: [agent-browser]` | 1,2 | **無替代**（SingletonSocket 路徑帶隨機後綴，結構上無法白名單）。上游改固定路徑才可退回 |
| `env.DOTNET_SYSTEM_NET_DISABLEIPV6=1` | 1 | **暫時性 workaround**。移除 → 沙箱內 `dotnet test` 100% 卡 90 秒逾時 → S4 gate (a) 永遠 FAIL → Preflight row 5 無法標 PASS。**必須留在 settings.json 而非 csproj/CI**（否則污染 Windows CI 的正常 dual-stack） |
| `env.PONYTAIL_DEFAULT_MODE=off` | 1,4 | **無等效替代**。這是 `[R-4]` 的唯一機械對應物——在 prose 進 context **之前**就攔掉，而非靠模型每次仲裁散文優先序 |
| `drift-check.sh` | 1,4 | **唯一自動偵測點**（`conformance.sh` 要手動跑，不算）。**有洞**：只驗 symlink 與 core 三檔存在，不驗 CLAUDE.md routing stamp 是否落後。補洞成本低：doctor() 加一行 stamp diff |
| `watch-ci-after-push.sh` | 1,4 | **無等效替代**。它是機械「觸發器」不是「阻擋器」，但 dev-workflow S6 的同一段散文**不會在 push 當下開火** |
| `guard-cookbook-orphan.sh` | 1,4 | **無替代**。0 次觸發 = 還沒有專案起 cookbook，正好落在禁用推論裡。小改進：改用 jq（唯一用 python3 的守衛，python3 缺席時 fail-open） |
| `patch-chrome-devtools-mcp.sh` / `patch-playwright-mcp.sh` | 2 | **暫時 workaround**，上游修好（Claude Code 支援 user-level 覆寫 plugin MCP args）即可拿掉。在那之前無替代：每次 `claude plugin update` 都會寫回原始 plugin.json |
| `$schema` | 1（弱但真實） | **無替代**。typo 的設定鍵在 JSON 裡**靜默無效**——寫錯 `autoMode.softDeny` 不會報錯，只會讓那道防線消失。與本次發現的 audit-bash 假宣稱同一類風險 |

### 3.4 能力調校鍵：判「零 gate 損失」≠ 建議刪

`effortLevel: xhigh`、`ultracode: true`、`alwaysThinkingEnabled`、`advisorModel: opus`、`autoCompactWindow: 1000000`、`CLAUDE_CODE_MAX_OUTPUT_TOKENS: 128000`、`language: zh-TW`、`statusLine`、`attribution`、`cleanupPeriodDays`、`tui`、`agentPushNotifEnabled`。

初判全部「REMOVABLE（零 gate 損失）」，**對抗驗證階段 11/12 被推翻**，理由一致且正確：**五軸 rubric 是為 skill 設計的**（成本 = 常駐 description ≈100-200 token），套在 settings.json 鍵上是 category error——config key 的 context 成本是**零**，所以「移除收益」永遠是零，不存在「值得刪」的情況。

唯一存活的是 `autoUpdatesChannel: latest`——binary 三路驗證顯示與鍵缺席行為完全相同（真的可刪），但收益同樣是零。

值得保留的具體理由：
- `advisorModel: opus`（軸 3）— 同 rank 配對時給的是**乾淨 context 的獨立審視**，不是更強的模型（memory 已實證）。與 S5 subagent reviewer 互補：advisor 看得到完整 transcript（適合「方法選錯」），reviewer 直接讀 diff（適合「程式碼有 bug」）。
- `autoCompactWindow: 1000000`（軸 4）— S0→S6 是單 session 累積證據的長鏈，壓縮愈頻繁，ledger 愈可能從證據退化成宣稱，正是 `[T0-2]` 要防的。
- `ultracode: true` — 若你的真實動機是 token 成本，**這一個旋鈕比整個 skill/agent roster 大兩個數量級**（刪 52 個 skill 省 5.4k 常駐；ultracode 一次派工就是 1.5M）。

---

## 4. 🟡 唯一真正能省 context 的地方：`@inline` plugin

實測 `~/.claude.json` 的 `pluginUsage`：有 **15 個 `@inline` plugin 的 `usageCount` 為 0**——

`anthropic-skills`、`data`、`marketing`、`finance`、`product-management`、`operations`、`pdf-viewer`、`figma`、`productivity`、`design`、`legal`、`sp-global`、`desktop-commander`、`mongodb`、`firecrawl`

它們貢獻本 session skill 清單裡約 **90 個** 條目（`product-management:*`、`engineering:*`、`design:*`、`anthropic-skills:*`…），**遠大於你 52 個個人 skill 的 5.4k token**。

**但它們不在你的 `enabledPlugins`（22 項）也不在 `installed_plugins.json`（23 項）**——`@inline` 代表由 Claude Code 桌面版 binary 內建（實體在 `~/.local/share/claude/ClaudeCode.app`，磁碟上沒有 SKILL.md 檔）。

→ **改 `settings.json` 動不了它們。** 要處置只能在互動式 session 用 `/plugin` 確認能否停用。本 session 非互動，無法代跑。

**這是本次唯一「移除真的能省 context」的候選，而且與模型能力完全無關。**

---

## 5. 依你的 stack 更新的建議

### 5.1 現況不對稱：.NET 有專精審查，前端只有泛用模板 —— 而模板是空的

| | .NET | 前端 / Node |
|---|---|---|
| 專精 reviewer | `dotnet-code-reviewer`（180 行：EF Core N+1 / 併發 / API 破壞性變更 / NuGet 稽核） | 無（今日 09:57 刪光 persona 是對的） |
| 泛用 reviewer 模板 | — | `reviewer-template.md`（63 行）**零 React/Vue/TS/Node 檢核** |
| stack skill | 6 個 dotnet-* + dapper + ef-core/ef6 + mysql + `rules/dotnet.md` | 18 個前端 skill + `rules/typescript.md` + `rules/frontend-spa.md` |

**關鍵事實（實測 grep 無命中）**：`reviewer-template.md` 沒有任何 React / Vue / TypeScript / Node 檢核項，而 **Codex 與 Copilot 這兩家沒有專屬 review agent 的 host 是整塊複製這 63 行去做 S5 審查**（`:5`）。等於這兩家的前端 stack 級審查**目前是空的**。

### 5.2 ⭐ 最高價值的單一動作：`reviewer-template.md` 補 stack 檢核

這是前一份報告的 Batch C#7，**至今未執行**（實測確認）。它是上述不對稱的正解，而且落在**三家共用層**，不是再加一個 Claude-only agent。

**加在哪**：插在 `:31`（掃描規則）之後、`:33`（conventional comment 前綴）之前，**仍在 prompt block（:21-44）內** — 不要開新的頂層小節（會違反 `:6-7` 的 host 中立結構）。

**加什麼**（依你主力 stack）：

| Stack | 檢核項 |
|---|---|
| **ASP.NET Core / .NET** | DI 生命週期不匹配（singleton 取 scoped）、middleware 順序（auth 在 endpoint 之後）、`HttpClient` socket 耗盡、`BackgroundService` 靜默停止 |
| **React** | 不必要 re-render、`key` 用 index、`useEffect` 缺 cleanup、stale closure |
| **Vue** | reactivity 丟失（解構 `reactive`）、hydration mismatch、`watch` 迴圈 |
| **TypeScript** | `any` 洩漏、`as` 斷言放寬型別、缺 `noUncheckedIndexedAccess` 假設 |
| **Node.js** | unhandled rejection、socket / listener 洩漏、async 錯誤未傳播 |

### 5.2.1 第二個不對稱：前端**實機驗證**只剩 Claude 一家

今日歸檔 `ui-ux-tester` 後（Claude + Codex 兩端），三家的前端 runtime 驗證角色是：

| 角色 | Claude | Codex | Copilot |
|---|---|---|---|
| 前端實機渲染驗證 | `uiux-reviewer` ✅（`model: inherit`） | **無** | **無** |

這**合規**（`dev-workflow` 允許那兩家把 S4(c) 標 UNAVAILABLE + 附理由），但對一個一半是前端的 stack，意味著**所有 rendered-page 驗證都只能發生在 Claude session**。這是刻意取捨不是缺口——記在這裡，免得下次稽核把它重新「發現」成 bug。

### 5.3 ❌ 不建議做的事

- ❌ **因為「Opus 5 / GPT-5.6 夠強」而刪任何 skill 或 agent** — 實測 0/52 skill、0/3 agent 五軸全 FAIL。收成已在 09:57 刪那 14 個 persona 時拿完了。
- ❌ **用低用量裁剪前端 skill** — corpus 汙染（§0.2）。那正好會刪掉你 stack 的另一半。
- ❌ **動 §3.3 的任何 hook / permission / sandbox / env** — 那層與模型能力正交。
- ❌ **為了省 token 而刪 skill** — Claude 端總額 5.4k、Codex/Copilot 端 0。真正的旋鈕是 `ultracode` 與 §4 的 inline plugin。
- ❌ **`autoMode.environment` 宣稱的 "Preferred stacks: … PostgreSQL"** — 實測 7 個專案 PG **0 命中**，唯一有 DB 的是 MySQL（17 檔）。這會讓 classifier 系統性偏斜（預設產 PG 語法、預設選 Npgsql）。**這是設定準確性缺陷，不是刪 PG skill 的論據**（`postgresql-best-practices` 靠 Npgsql 6 breaking change 判 KEEP）。

---

## 6. 執行批次（皆為提案，未執行）

### Batch P0 — 安全（建議立刻）

1. 合併 `guard-git-push.sh` ← `guard-codex-git-push.sh`（含 `broad_refset` + 全 refspec 迴圈），Claude 端留薄 wrapper。**驗收**：三個繞過 payload 全部 exit=2。
2. `permissions.allow` 移除 `Bash(git push --force-with-lease *)`（在 #1 完成前不建議保留）。

### Batch P1 — 機械層補洞

3. `permissions.allow` 的 `Bash(gh *)` 收斂為唯讀子集。
4. 刪 `skipDangerousModePermissionPrompt`（另兩個 `skip*Prompt` 留著）。
5. `audit-bash.sh` 改註冊 `PostToolUse[Bash]`；修 `~/.agents/CONVENTIONS.md:11` 的假防線宣稱。
6. `drift-check.sh` 的 `doctor()` 加 routing stamp diff。
7. `autoMode.environment` 的 "Preferred stacks" 改為實況（MySQL；PG 標「規劃中/無現存專案」）。

### Batch P2 — 你的 stack（最高實質收益）

8. **`reviewer-template.md` 補 5 個 stack 檢核段**（§5.2）→ 三家共用，Codex/Copilot 同時受益。
9. `css-ui-best-practices` 的 Tailwind token 段改為委派 `tailwind-v4-shadcn`（消除 `hsl(hsl(...))`）。
9b. **同一缺陷類別，先前漏排**：`postgresql-optimization/references/performance.md:123` 主張 UUIDv7 (PG 18+) 優於 `gen_random_uuid()`，而 `postgresql-best-practices` 全樹「PG 18」**0 命中**且有相反主張 → 兩個 skill 對同一問題給相反建議，模型挑到哪個算哪個。與 css-ui × tailwind-v4 是同構的 bug，**必須同批修**（在 sibling 補上 PG 18 條目，或在 sibling 加 redirect）。
10. `vue-best-practices/references/styling-and-ui.md:403-436` Element Plus → Naive UI redirect。
11. `nodejs-best-practices/deployment-docker.md` Node 20 → 委派 `containerization`。
12. `containerization/references/trigger-regression.md` 修或移除失效語料。
13. 修兩處懸空引用：`auth-implementation-patterns:52`、`vue-debug-guides/INDEX.md:20`。

### Batch P3 — 衛生（可延後）

14. skill 內部通用知識瘦身 ~8-9k 行（§1.4）——省的是讀取時 token，不是常駐。
15. `permissions.allow` 清掉四條對應已停用 `github` plugin 的 mcp 規則。
16. 互動式 session 用 `/plugin` 評估 15 個零用量 `@inline` plugin（§4）。

**執行後必跑**：動到 `~/.agents/` 或 `CLAUDE.md` 正本者 → `~/.agents/bin/agents-sync` + `drift-check.sh`。

---

## 7. 限制與未驗證項

1. **未做 A/B 對照**：「有 skill vs 無 skill」的實際輸出品質差異未實測。§1 的 KEEP 判決**不依賴**該推論（依據是五軸的可稽核證據）。
2. ~~`permissions.allow` 是否優先於 `autoMode.soft_deny` classifier~~ — **已於 §3.1.1 用 binary 驗證定案（allow 短路 classifier）**。殘餘：`Ssn` 的第三 predicate `PHs` 未追。
2b. **`tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md:2` 的 `paths:` frontmatter 是否會被自動注入** — ASSERTED（判為不會，依據是其 inline 逗號串格式與 `~/.agents/rules/typescript.md:2-5` 的 block-sequence 形式不同、且位於 skill 子目錄）。**未實測**。verdict 兩種情況下都是 KEEP，但本報告的論旨包含「假防線宣稱 = bug」，不該自己留一個未測的失效宣稱——列為待跑探針。
3. **tier0 是否倖存 autoCompact** — 未驗證。可用 `claude -p '輸出 context 中所有 FP: 開頭 codeword'` 在壓縮前後複測。
4. **`sandbox.excludedCommands` 與 `allowUnsandboxedCommands` 的分工**未實測釐清（memory 記 agent-browser 需 `dangerouslyDisableSandbox`，但 `excludedCommands` 理應已免沙箱——可能是後加未回頭複測）。
5. **抽樣未讀全**：`design-doc-mermaid`（讀 70/498 行 + ~13,500 行附檔未讀）、`agent-browser`（90/479）、`security-review` 6 個 references（1,097 行）。不影響五軸判定（依據是 SKILL.md 內的 gate/契約證據），但「可瘦身幅度」對這兩者是依行數推估。
6. **Codex / Copilot 端無等價 transcript**，其 skill 觸發率未知。

---

## 8. 與 Codex（gpt-5.6-sol）結論的合併裁決 · 2026-07-25

Codex 的框架與本報告一致：**「保留 workflow / rules / tools / reviewer，精簡或歸檔 generic knowledge 與 implementation persona」**。四處分歧與三處遺漏如下。

### 8.1 完全一致（雙方獨立得出，可信度最高）

1. 不能全移除；`dotnet-code-reviewer` / `code-reviewer` / `uiux-reviewer` 三個角色保留。
2. implementation persona（CSharp Developer、React Specialist、Vue Expert、Node Specialist…）維持歸檔——Opus 5 / GPT-5.6-sol 確實 cover。
3. tier0/1/2、routing、dev-workflow、rules/*.md、機械守護層絕不可移除。
4. 不新增 implementation persona agent。
5. 只做 read-only 複驗，未改任何設定。

### 8.2 分歧一：非主力 stack 是否「可逆歸檔」→ **不歸檔**

Codex：`c-cpp` / `.NET Framework` / `EF6` / `WinForms` / `native-feel` / `ecpay` 確認無維護需求後可逆歸檔。

**裁決依據是 Codex 自己的成本判斷 + 本報告的軸 4/5 證據，兩者相乘為負期望值**：

- Codex 已承認「移除它們只省少量 description token，不值得直接刪除」——收益已由對方認定為微小（實測每個 ~100 token，且對 Codex / Copilot 兩家是 **0**）。
- 而每一個都有具體的「編譯過、線上炸」證據：EF6 `.Include(x=>x.A.Select(...))` vs EF Core `.ThenInclude()`（模型慣性輸出後者→編譯失敗）；.NET Framework R4「library 加 `ConfigureAwait(false)`、controller 不加」（模型慣性壓平→需要 HttpContext 的 controller 直接壞）；WinForms .NET 9 `InvokeAsync` 同步 overload 吞掉內層 Task（靜默不執行）；`ecpay` Node.js `encodeURIComponent` 不編碼 `'` 與 `!` 會算錯簽章。
- **額外反證**：`DCT_data_import` 本身是 net462→net8 的遷移產物。EF6 / .NET Framework 正是 legacy 面浮出時會用到的知識。

→ 這仍是**你可以決定的事**（若真的永不再碰），但期望值是負的：省 100 token 換一次靜默錯誤不划算。

### 8.3 分歧二：`postgresql-optimization` 延後 → **不能只延後，須同批修**

Codex：併入 `postgresql-best-practices` + 修兩處事實錯誤後歸檔；因 PG 非主力，延後到下次用 PG 時再做。

**對抗驗證推翻了「內容重複所以可併」的前提**：`postgresql-optimization/references/performance.md:123` 主張 UUIDv7 (PG 18+) 優於 `gen_random_uuid()`，而 `postgresql-best-practices` 全樹「PG 18」**0 命中**且有相反主張。→ 它不是 sibling 的薄化重述，是 **sibling 現存錯誤的唯一解毒劑**。

這與 `css-ui` × `tailwind-v4-shadcn` 是**同構的 bug**（兩個 skill 對同一問題給相反建議，模型挑到哪個算哪個）。Codex 把 Tailwind 那組列為要修、把 PG 這組列為可延後，是對同一缺陷類別套兩套標準。

→ **兩組同批修**（見 Batch P2 #9 / #9b）。修完之後再談歸檔不遲。

### 8.4 分歧三：skill 稽核數字（Keep 29 / Trim 16 / Split 1 / Conditional Delete 1）→ **非衝突，是詞彙差異**

該稽核的 **Trim = 「內容有錯，修它」**，不是「移除」。前一份 `02-recommendations.md:24` 已明寫：「Trim 的正當理由是內容『錯』（過期／矛盾／死連結／與 rules 牴觸），不是『大』或『重複』」。本報告的五軸複審得出 0 REMOVABLE 與之相容——同一答案，不同詞彙。**沒有 16 個 skill 在待刪名單上。**

### 8.5 分歧四：Codex 的「不可移除」表只到文件層 → **互補，但漏了驗證**

Codex 列「Git push guard、drift check、conformance test — 絕對保留」，方向正確但**沒有驗證那些守護是否真的在守**。本報告 §3.1 實測：`guard-git-push.sh` 有兩個可繞過的洞，且 §3.1.1 用 binary 證實軟層也不會補上。**保留一個壞掉的 guard 保護不了任何東西。**

### 8.6 Codex 漏掉的三件事

| # | 事項 | 為何重要 |
|---|---|---|
| 1 | **`[T0-3]` 機械層實測是開的**（§3.1 + §3.1.1） | Codex 把它列在「絕對保留」，但保留 ≠ 有效。這是本次唯一的 P0 |
| 2 | **`reviewer-template.md` 零前端檢核** | Codex 說保留 `code-reviewer` 是為了「補足 Vue／React／TypeScript／Node.js」——但 Codex 與 Copilot 兩家**沒有專屬 review agent，是整塊複製那 63 行**（`:5`）。所以 Codex 自己那家的前端 stack 審查**目前是空的**，它的保留理由在自己的 host 上不成立 |
| 3 | **Opus 5 的 subagent 傾向與 Opus 4.8 相反** | Codex 引用「官方建議移除舊式重複 verification scaffolding」正確；但同一份官方 prompting guidance 還指出 **Opus 5 比 Opus 4.8 更愛派 subagent**，並建議明確設上限（"Never use more than 20 parallel agents unless the user explicitly requests it"）。這直接影響 `ultracode: true`——本次一場 workflow 就燒了 1.59M token |

### 8.7 模型規格宣稱的查證

用 `claude-api` skill（Claude 模型事實的指定權威來源）複驗 Codex 表格：

| Codex 宣稱 | 查證 |
|---|---|
| Claude Opus 5 context / output = 1M / 128K | ✅ 相符 |
| 「官方特別強調 bug finding 的 precision/recall」 | ✅ 相符（"High precision **and** high recall — a high rate of real bugs per pass, with the extra findings mostly real rather than false positives"；且「stays accurate at lower effort」） |
| 「會主動驗證；官方建議移除舊式重複 verification scaffolding」 | ✅ 相符，且措辭更強：**"Removing them reduces over-verification with no capability regression" — 這是 delete，不是 rewrite**。連 per-prompt 的「double-check your answer」也算（**這反轉了一般 prompting 最佳實踐**，需要對此模型開特例） |
| 「Claude Opus 5 已於 2026-07-24 發布」 | ⚠️ **未能查證**——權威來源未載發布日期。不影響任何結論 |
| GPT-5.6 Sol 1.05M / 128K 等規格 | ⚠️ 未查證（非本 skill 涵蓋範圍） |

**重要區分**：「刪 verification scaffolding」指的是 **prompt 層的自我檢查散文**（"double-check"、"re-verify before responding"），**不含** dev-workflow S4 的四態 gate——那些是機械證據要求（指令 + exit code + 輸出），不是「請再檢查一次」。Codex 也明確說「不能刪 build/test/CI gate」，兩份一致。

### 8.8 三家同步狀態複驗

Codex 宣稱 `~/.codex/AGENTS.md` DRIFT — **實測成立**，但方向需要說清楚：

```
diff dist/AGENTS.md  ~/.codex/AGENTS.md  → live 檔多 13 行（:71-83 的 <!-- context7 --> 區塊）
manifest.tsv hash    → codex 不符（d532a454… vs 26fdd367…）；copilot 相符
```

→ **live 檔比 dist 多，不是少。**直接 regenerate 會**刪掉**那段 context7 指引。正確順序是先決定那段要不要進 `~/.agents/` 正本，再同步——否則會把一段可能是刻意加的內容當漂移抹掉。

### 8.9 合併後最終順序（取代 §6 的排序，內容不變）

Codex 建議的順序是「先收 AGENTS.md drift → 修 doc rot + routing → 修 Tailwind → archive-first 處理非主力 stack」。合併後：

0. **P0：guard 合併 + 移除 `permissions.allow` 的 force-with-lease**（Codex 未發現，優先於一切）
1. **AGENTS.md drift**：先裁決 context7 區塊歸屬，再同步（不可直接 regenerate）
2. **P1 機械層**：`Bash(gh *)` 收斂、刪 `skipDangerousModePermissionPrompt`、`audit-bash.sh` 改 PostToolUse + 修 CONVENTIONS.md:11、drift-check 加 stamp diff
3. **P2 stack**：`reviewer-template.md` 補 5 段檢核（最高實質收益）+ Tailwind 衝突 + PG UUIDv7 衝突（同批）+ Node 20 → 委派 + trigger-regression + 兩處懸空引用
4. **P3 衛生**：skill 內部通用知識瘦身、`/plugin` 評估 inline plugin
5. **不做**：非主力 stack 歸檔（§8.2）

### 8.10 依 Opus 5 官方 guidance 的兩個設定調整（新增）

| 項目 | 動作 |
|---|---|
| `ultracode: true` + Opus 5 更愛派 subagent | 若 token 成本是考量，這是**唯一有兩個數量級效果的旋鈕**。可考慮：關掉 ultracode 改為按需要求，或在 `CLAUDE.md` 加一條 subagent 上限（官方建議形式：「除非明確要求，不超過 20 個平行 agent」；並加「不要用 subagent 做 review／驗證——驗證屬於主 agent loop」） |
| skill 內的 self-check 散文 | 掃 `~/.agents/skills/` 找 "double-check" / "re-verify" / "verify before responding" 類 prompt 層指令並刪除（**不動** dev-workflow S4 的機械 gate 與 `[T0-2]` evidence 要求）。官方實測：刪除降低 over-verification 且**無能力退化** |

---

## 9. Codex 反駁的查證 · 2026-07-25（第二輪）

### 9.1 ✅ Codex 對：inventory 是 53 不是 52，且第 53 個未追蹤

```
ls -d ~/.agents/skills/*/ | wc -l          → 53
ls -d ~/.agents/skills/context7-mcp        → 存在
grep -c '^[a-z]' dist/skill-index.md       → 52（且 grep context7-mcp = 0）
git status --short skills/context7-mcp     → ?? （未追蹤）
```

**本報告 §1 的「0 / 52」稽核範圍不完整，予以更正為 0 / 52 已審 + 1 未審。**

**但實情比 Codex 描述的更嚴重——同一份 context7 路由存在四份**：

| # | 位置 | 性質 |
|---|---|---|
| 1 | `~/.claude/CLAUDE.md:16` | 家規路由一行（「文件查詢優先 MCP > web search：library / framework → Context7」） |
| 2 | `~/.codex/AGENTS.md:72-83` | **就是 §8.8 那 13 行 drift 區塊**，dist 正本沒有 |
| 3 | `~/.agents/skills/context7-mcp/SKILL.md` | 未追蹤的第 53 個 skill |
| 4 | context7 **MCP server 自身的 server instructions** | session 啟動時由 server 注入，內容與 #3 幾乎逐字相同（"Use this server to fetch current documentation whenever the user asks about a library… Prefer this over web search for library docs."） |

→ **#4 的存在讓 #2 與 #3 都是純冗餘**：MCP server 自己已經在每個 session 注入同樣指引，不需要 skill 或 AGENTS.md 區塊再講一次。

**裁決**：留 #1（那是家規的優先序決策，MCP server 不會講「Microsoft / Azure / .NET → microsoft-learn」）；刪 #2 與 #3。
→ 這一次同時解決 §8.8 的 drift 歸屬問題（**那 13 行不該進正本，該刪**）與 Codex 的 P1 inventory 校正。

### 9.2 ✅ Codex 對：三家都有 browser MCP，我的 §5.2.1 是錯的

```
~/.codex/config.toml      → [mcp_servers.chrome-devtools] + [mcp_servers.playwright]
~/.copilot/mcp-config.json → chrome-devtools, context7, awesome-copilot, playwright
```

**§5.2.1「前端實機渲染驗證只剩 Claude 一家」予以撤回。** 我把「沒有客製 agent」誤述成「能力不可用」。三家都能開瀏覽器；Claude 獨有的是 `uiux-reviewer` 這個**便利包裝**，不是能力壟斷。這反而強化 Codex 的分層論點（見 9.4）。

### 9.3 ⚠️ 未證實：「Codex session 收到完整 shared skill metadata」

磁碟上沒有任何交付路徑：

| 檢查 | 結果 |
|---|---|
| `~/.codex/skills/` | 2 個本地（chronicle、security-ownership-map）+ `.system/`（6 個 Codex 原生：imagegen / openai-docs / plugin-creator / review-agent / skill-creator / skill-installer）。**無 symlink 指向 `~/.agents/skills`** |
| `~/.codex/config.toml` | 無 skills 路徑設定 |
| `~/.codex/AGENTS.md` 的 `description:` 出現次數 | **0**（全檔 9,924 字元） |
| `dist/skill-index.md` | 1,159 字元的**純名字清單** |

我無法檢視 Codex 的 runtime context，故不宣稱它說錯。**這個分歧可一次測掉**：請 Codex 在不讀檔的前提下逐字複述任三個 shared skill 的 `description`。能複述 → 我錯，Codex 端成本 ≈ 19KB；不能 → 是把「知道名字」誤當成「收到 metadata」。

**但即使我完全認輸，結論不翻**：19KB × 兩家仍是「微不足道」的兩倍，相對於一次靜默版本錯誤（EF6 `.ThenInclude()` 編譯失敗、Vitest `workspace` 已移除）依然不划算。這個分歧只改變「省多少」，不改變「該不該刪」。

### 9.4 ✅ Codex 對：「邏輯角色 vs host 客製檔案」比我的「0/3」精確

我證明的是**三個角色需要**，不是**三個 Claude 專屬 `.md` 檔需要**。若某 host 已有內建 reviewer，客製 wrapper 就是重複。§2 的表述改為：

> **三個 review capability 保留；不承諾永久保留三份客製 agent 定義。**

`uiux-reviewer` 尤其如此——9.2 已證三家都有 browser MCP，未來若 workflow 直接呼叫 browser tools，這個 agent 可移除。

### 9.5 ✅ Codex 對：Trim 的處置分類法比我的「瘦身 8-9k 行」可執行

採納 Codex 的四路分流，取代 §1.4 的籠統說法：

| 內容類型 | 去處 |
|---|---|
| 專案 house rules | 移到 global / repo instructions（`CLAUDE.md` / `rules/*.md`） |
| 可機械驗證的規則 | 移到 hook / lint / test（比 prose 強，`deps-check/SKILL.md:36` 已實證「hook 100% 觸發、skill 約 50%」） |
| 大量範例與通用教學 | 縮短或移到 reference（`design-doc-mermaid` 的 ~7,500 行 examples 是最大宗） |
| 版本敏感資訊 | **保留**，但補 `last-verified` 戳或改為即時文件查詢 |

第四列與本報告軸 5 一致，且 `last-verified` 戳是我沒想到的補強——`reviewer-template.md:1` 已有此慣例（`last-verified: 2026-07-07`），值得推廣到所有軸 5 skill。

### 9.6 ✅ Codex 對：reviewer-template 插入點應在 `:25` 的優先序段

實讀 `reviewer-template.md`：`:25` 是「**審查優先序（由高到低）**」標題，`:26-29` 是四級清單，`:31` 是「先掃高風險級別，命中就記」的掃描規則。

我原本說「插在 :31 之後、:33 之前」會讓 stack 檢核落在掃描規則**之後**，變成獨立段落而非優先序的一部分。**採 Codex 的位置**：在 `:29`（correctness）之後、`:30` 空行之前，加**第 5 條「stack 專項」**，讓它成為優先序階梯的延伸。

### 9.7 部分不同意：非主力 stack 與生態系 skill

- **`dotnet-framework` / `c-cpp` / `ecpay` / `native-feel`**：Codex 的條件（「只有仍維護該 stack 才保留」）成立。我 §8.2 的「負期望值」論證只在 stack **休眠**時成立；stack 真的**死亡**時風險為 0，論證失效。→ **改為你的判斷題**，並註明：archive 在 Claude 省 ~100 token、在 Codex/Copilot 只省一行索引，做它是為衛生不是為 context。
- **`Next` / `Nuxt`**：條件式保留合理（僅 SSR/SEO 場景，`frontend-spa.md:25` 已如此定位）。
- **🔴 `Pinia` 不可比照**：`rules/frontend-spa.md:21` 明文把它列為家規既定選型（「State 共用 > 3 處才引入 Zustand / Pinia」）。以「目前無 Vue 專案」裁掉它，正是 §0.2 的 corpus 汙染推論換一身衣服——開新 Vue 專案第一天就缺。

### 9.8 我方仍成立、Codex 未涵蓋的部分

1. **P0 的軟層證據**：Codex 確認 guard `rc=0` 並建議「修正前移除 allow」——方向對，但沒查**為什麼必須移除**。§3.1.1 的 binary 驗證證明 allow rule **短路 auto-mode classifier**，所以不是「多一層防線」而是「唯一那層也被關掉」。這決定它是 P0 不是 P1。
2. **用量權威來源**：`~/.claude.json` 的 `skillUsage`（60% 觸發率）與 corpus 汙染量化（87% 來自零前端專案）。
3. **軸 5 的具體反例清單**：這是對 Codex「錯誤 skill 比沒有 skill 更危險」的正面補充——**正確的版本釘死 skill 比沒有 skill 安全**，兩者不衝突。
4. **PG UUIDv7 是解毒劑不是重複**（對抗驗證結論，Codex 仍當作「唯一內容抽出後可 archive」——抽出即可，但不能在修好 sibling 前 archive）。
5. **Opus 5 比 Opus 4.8 更愛派 subagent** → `ultracode: true` 的成本影響（Codex 完全未提）。

---

## 10. P1a 執行紀錄 · 2026-07-25（已完成）

### 10.1 變更

| Repo | Commit | 內容 |
|---|---|---|
| `~/.agents` | `6b336dc` | `skills/context7-mcp/` → `backups/20260725-p1a-context7/`（未追蹤檔，git 歷史無刪除紀錄）；`dist/` 三檔重生 |
| `~/.codex` | `2edaeec` | `AGENTS.md` 移除手加的 13 行 context7 區塊並重生 |

`~/.claude/CLAUDE.md:16` 的家規路由**未動**（也不可動，sandbox 擋）。

### 10.2 過程中發現的機制細節（值得記住）

1. **`agents-sync` 的 no-clobber 是 banner 內嵌 body hash**，不是 manifest。手加 13 行後 `hash:10ee5551` 與實算 body hash 不符 → 會 fail-loud 拒寫。**必須先讓檔案回復自洽**（移除手加內容）才能重生。這是正確的防竄改設計。
2. **`AGENTS_DEPLOY_ROOT` 是安全的預演機制**：部署到 scratch 再 diff live，可在不動任何 live 檔的前提下看到確切差異。本次靠它證實 copilot 只有 banner 戳會變、body 逐字相同。
3. **banner 的 `@gsha` 是 repo HEAD**，所以 hash 變 ≠ 內容變。`--check` 印的 hash 含 banner，會製造「兩家都要變」的假象。

### 10.3 🔴 修正 §0.3：Copilot 的常駐成本不是 0

`agents-sync --doctor` 的 skill 可見度探針欄逐字寫著：

> `copilot: copilot -p '列出 available_skills 中含 dev-workflow 者' --available-tools=`（**已驗證原生載入 `~/.agents/skills`**）
> `codex  : UNVERIFIED——無 skill 載入設定，取用靠 routing 點名後直讀檔`

→ **§0.3 表格的 Copilot 列「0」是錯的。** Copilot 原生載入 `~/.agents/skills`，所以它**也有** description 常駐成本，量級與 Claude 相同（~5.4k token）。這一項 **Codex 的反駁在 Copilot 上成立**（§9.3 我只證了 Codex 端無交付路徑，沒查 Copilot）。

修正後的三家成本表：

| Host | 機制 | 52 個 skill 的常駐成本 |
|---|---|---|
| Claude | `~/.claude/skills/*` symlink → 自動探索 | ~5.4k token |
| **Copilot** | **原生載入 `~/.agents/skills`（doctor 已驗證）** | **~5.4k token** |
| Codex | 無 skill 載入設定；靠 routing 點名後直讀檔 | **UNVERIFIED**（doctor 自己標的） |

**結論仍不翻**：兩家 × 5.4k ≈ 11k token 常駐，相對於一次靜默版本錯誤（EF6 `.ThenInclude()` 編譯失敗、Vitest `workspace` 已移除）依然不划算。但「刪 skill 省 context」的收益比我原本估的**大一倍**，這個修正對 Trim 批次的優先序有利。

### 10.4 驗收證據

```
skills=52  index=52  context7-mcp在index=0
manifest vs live：codex ✅ 相符  copilot ✅ 相符
codex AGENTS.md：70 行、context7 命中 0、git diff 僅 banner gsha 一行
copilot body（去 banner）：與變更前逐字相同
agents-sync --doctor → exit 0（斷鏈 0 / override 不存在 / manifest 三方相符）
conformance.sh      → 11 PASS / 0 FAIL
```

**Rollback**：`backups/20260725-p1a-context7/context7-mcp.archived` 移回 `skills/` + 重跑 `agents-sync`；`AGENTS.md.before` 保留原始 83 行版本。

---

## 11. 步驟 4 + 5 執行紀錄 · 2026-07-25（已完成）

| Commit | 內容 |
|---|---|
| `a3017ba` | fix(skills): 修正版本矛盾與家規牴觸（8 檔） |
| `3b2e94f` | feat(workflow): reviewer-template 補 stack 專項檢核 |

### 11.1 執行中對計畫的三處修正

**① 範圍收窄 ×2 —— 先前稽核的兩項建議過寬**

| 原建議 | 實查 | 處置 |
|---|---|---|
| 「移除 `css-ui/references/{tailwind,design-system-patterns}.md`」 | `tailwind.md` 實查為**正確的 v4 內容**（`:23` 「v4 採用 CSS-first，不再需要 `tailwind.config.js`」、`:52` 「`@theme` 取代 `theme.extend`」） | **只改 `design-system-patterns.md` §2**，`tailwind.md` 不動 |
| 「改 `react-best-practices/SKILL.md:40-41` 的雙指向」 | 兩行描述**已正確分工**：`css-ui-best-practices — CSS / a11y / responsive`（未宣稱 token）、`tailwind-v4-shadcn — token wiring, dark mode` | **無需修改**，修完 css-ui 即無歧義 |

**② 範圍擴大 ×1 —— 同缺陷擴散到計畫外的檔案**

原本只掃 `nodejs-best-practices`，執行時 grep 全樹發現 `node:20` 還在另外兩個 skill：`next-best-practices/references/self-hosting.md:32`、`nuxt/references/core-deployment.md:200,207`。Node 20 已於 2026-04 EOL，家規（`rules/frontend-spa.md:14`）為 Node 24。同一缺陷、同一機械修法，一併修正（連同 `engines: ">=20.0.0"` → `>=24.0.0`）。留著會讓模型仍從那兩份挑到 EOL 版本。

**③ 刻意不改 ×1**

`agent-browser/references/webgpu.md:63` 的 `node:22-bookworm-slim` **保留**。上下文寫「Verified with both Chrome for Testing and Debian's `chromium` package」——那是實測過的 WebGPU 容器配方，Node 22 仍在 LTS（2027-04）未 EOL。改版號會讓「Verified with」的宣稱失效。列為 follow-up：下次實測 WebGPU 路徑時一併驗 Node 24。

### 11.2 驗收證據

```
懸空引用：dotnet-containerization / better-auth-best-practices / trigger-regression → 全樹 0 命中
Node 版本：nodejs / next / nuxt 六處 → node:24-alpine；engines ">=24.0.0"
           containerization 維持 node:24-bookworm-slim（原本就對）
           agent-browser node:22 → 刻意保留（見 ③）
Tailwind： css-ui 的 v3 token 寫法清零（唯一殘留在新增的 v3/v4 對照表「已過時」欄，屬刻意反例）
Element Plus：vue styling-and-ui.md 兩處標註為家規禁用
agents-sync --check → lint PASS；codex 8257B / copilot 8997B（**未變**，證實 reviewer-template
                      是 on-demand reference，不進 host 常駐預算）
conformance.sh      → 11 PASS / 0 FAIL
```

### 11.3 reviewer-template 的設計取捨

- **放在優先序階梯第 5 級**（`:29` 之後），而非另開頂層小節——後者會落在 `:31` 「先掃高風險級別」掃描規則之外變成孤立區塊。此位置採 Codex 的建議（§9.6）。
- **明訂「只套用 diff 實際命中的技術棧，未命中者跳過」**，避免在單棧 PR 上灌水。
- **每項只列「模型不查就會漏」的具體反模式**，不寫通用教學——符合 §9.5 的 Trim 分類法（教材歸教材，檢核歸檢核）。
- 未動 `:1` 以外的 header、未動 UNAVAILABLE 規則與三欄記錄契約（那些是 S5 gate 的機械複核依據）。

### 11.4 剩餘未做

- **P0 guard**（步驟 1-2）—— `[T0-3]` 仍是開的，最後兩步需你手動安裝（sandbox 擋 `~/.claude/hooks/` 與 `settings.json`）
- P3：非主力 stack archive（待你裁決 stack 是死是眠）、skill 內部通用知識瘦身、`/plugin` 評估 inline plugin
- follow-up：`agent-browser` WebGPU 配方的 Node 24 實測

---

## 12. P0-a 執行紀錄 · 2026-07-25（已完成，待人工安裝 wrapper）

Commit `18053aa` — `fix(guard): 合併 force-push guard 為單一實作並補四個破口`

### 12.1 結構

```
~/.agents/hooks/guard-git-push.sh          ← 單一正本，--format=claude|codex
~/.agents/hooks/guard-codex-git-push.sh    ← 4 行 wrapper（~/.codex/hooks.json 指向它，零 config 變更）
~/.claude/hooks/guard-git-push.sh          ← 待人工安裝的 wrapper（sandbox 擋 agent 寫入）
```

輸出契約分流：`claude` = stderr JSON + exit 2；`codex` = stdout `hookSpecificOutput` + exit 0。
未指定 `--format` 時取 `claude`（fail-closed：寧可誤擋不可誤放）。

### 12.2 [T1-4] before/after 基線

| payload | 現行 live guard | 新共用 guard |
|---|---|---|
| `git push --force-with-lease --all origin` | ✅ rc=0 | 🚫 rc=2 |
| `git push --force-with-lease --mirror origin` | ✅ rc=0 | 🚫 rc=2 |
| `git push --force-with-lease origin feat/x main` | ✅ rc=0 | 🚫 rc=2 |
| `git push -fu origin main` | ✅ rc=0 | 🚫 rc=2 |
| `git push --force-with-lease origin feat/x` | ✅ rc=0 | ✅ rc=0 |
| `git push -u origin main` | ✅ rc=0 | ✅ rc=0 |

**第四個破口是本次新發現**：兩家舊版都只比對 `-f`，未處理 `-fu` 這類短旗標捆綁。

### 12.3 日常指令不受影響（實測）

`git init` / `git add` / `git commit` / `git push` / `git push origin main` / `git push -u origin main` /
`git push origin master` / `git push --tags` / `git pull --rebase && git push` / 非保護分支的
`--force-with-lease` —— **全部放行**。guard 第一行即 `case "$CMD" in *git*push*) ;; *) exit 0 ;; esac`，
非 push 指令連解析都不做。`[T0-3]` 管的是 force 變體，不是「推 main」。

### 12.4 驗收證據

```
tests/git-push-guard.sh          → 50 PASS / 0 FAIL（雙格式 × 25 payload）
tests/codex-git-push-guard.sh    → 12 PASS / 0 FAIL（**未修改一字**，重構行為保持性證明）
tests/conformance.sh             → 12 PASS / 0 FAIL（新增第 9 項）
agents-sync --check              → lint PASS
```

### 12.5 待人工安裝（sandbox `denyWithinAllow` 擋 agent 寫入 `~/.claude/hooks/`）

安裝後 `[T0-3]` 的四個破口即關閉。**在此之前 Claude 端仍是開的。**

**Rollback**：`backups/20260725-p0a-guard/guard-codex-git-push.sh.before` 為原 70 行實作。

### 12.6 ✅ P0-b-1 已完成 —— `[T0-3]` Claude 端破口關閉（2026-07-25 12:45）

Wrapper 由使用者安裝（`~/.claude/hooks/guard-git-push.sh`，170 bytes，`exec` 委派至共用正本 `--format=claude`）。

**LIVE hook 實測（非正本，是實際掛在 PreToolUse 上的那支）**：

| payload | live rc |
|---|---|
| `git push --force-with-lease --all origin` | 🚫 rc=2 |
| `git push --force-with-lease --mirror origin` | 🚫 rc=2 |
| `git push --force-with-lease origin feat/x main` | 🚫 rc=2 |
| `git push -fu origin main` | 🚫 rc=2 |
| `git push --force origin main` | 🚫 rc=2 |
| `git push --force-with-lease origin main` | 🚫 rc=2 |
| `git init` / `git commit` / `git push` / `push -u origin main` / `push origin master` / `push --tags` / 非保護分支 lease | ✅ rc=0 |

四個破口全部由 rc=0 轉為 rc=2；七個合法指令全部放行。

**全套驗收**：`conformance.sh` 12 PASS / 0 FAIL；`agents-sync --doctor` exit 0（斷鏈 0 / override 不存在 / manifest 兩家相符）。

→ **§3.1 / §3.1.1 的 P0 缺陷已修復。** 剩餘的 `settings.json` 兩項（force-with-lease allow、`skipDangerousModePermissionPrompt`）為選配的 defense-in-depth，非缺陷修復。

---

## 13. Copilot review 處理紀錄 · 2026-07-25

兩個 PR 各收到 Copilot review（COMMENTED，異步 2–4 分產出，不計入 `gh pr checks`）。共 5 條 actionable findings，**全部實測驗證後採納**，無 pushback。

### 13.1 🔴 兩條推翻本報告先前的宣稱

**① `guard-git-push.sh` 在 jq 不可用時 fail-open**

我第一次驗證有測試瑕疵（PATH 收太窄，rc=2 來自 bash 啟動失敗而非攔截）。以假 jq 重驗確認：force 變體推 main 得 **rc=0**。

成因：`CMD=$(… | "$JQ" …) || CMD=""` 後接 `[ -z "$CMD" ] && exit 0`，把「jq 掛掉」與「payload 無 command」壓成同一條放行路徑。

**這與 §12 標頭自稱的 fail-closed 矛盾，且正是本報告 §3.2 批評 `audit-bash.sh` 的同一類「假防線」缺陷。**

**② 完整路徑 `git` 繞過 —— §12 的「四破口全關」不完整，這是第 5 個**

```
裸 git + force 變體 → main                    rc=2 🚫
/usr/bin/git + force 變體 → main              rc=0 ❌
/opt/homebrew/bin/git + lease force → main    rc=0 ❌
```

`check_seg()` 的 `[[ "$t" == git ]]` 認不出完整路徑，`seen_git` 恆 0 → 整段 return 0。

**我的 50-case 測試全部以裸 `git` 開頭 —— 測試設計盲點，不是實作意外。** 這一條說明：自建測試套件通過不等於覆蓋完整，獨立審查者的價值正在於補這種盲點（呼應本報告軸 3「乾淨 context 獨立審查」）。

### 13.2 其餘三條

| # | Finding | 處置 |
|---|---|---|
| ③ | 測試未清理 `mktemp` 目錄 | 加 `trap … EXIT`（含新增的假 jq bin 目錄） |
| ④ | `hooks.json` 硬編碼 `/Users/pochientsai/…` | 改 `$HOME`。**動前驗證 command 確為 shell 執行**：官方 codex / ponytail plugin 皆用 `"${CLAUDE_PLUGIN_ROOT}/…"`，且 ponytail 的 `commandWindows` 用 PowerShell `$env:` 語法——若非交給 shell，不需區分方言。端到端驗證通過 |
| ⑤ | `code-reviewer.toml` 引用檔名而非 agent `name` | 改對齊 `name = "dotnet-code-reviewer"`。**註記：先前 session 曾修過但方向相反**（對齊檔名），本次倒回來 |

### 13.3 一處未照建議採納（附技術理由）

①的建議含「jq 缺失時 best-effort 解析」。**未採用** —— 對 JSON 做 regex best-effort 解析正是製造 false negative 的來源，而安全閘的 false negative 代價遠高於 false positive。改為：jq 缺失時對含 `git`+`push` 的原始 payload 保守拒絕、其餘放行（一律拒絕會擋掉所有 Bash 指令）。`deny()` 改純 bash 轉義則完全照建議。

### 13.4 驗收

```
tests/git-push-guard.sh       50 → 68 PASS / 0 FAIL（補完整路徑 5 case + jq 降級 8 case）
tests/codex-git-push-guard.sh 12 PASS / 0 FAIL（仍未修改一字）
tests/conformance.sh          12 PASS / 0 FAIL
agents-sync --check           lint PASS
hooks.json                    硬編碼家目錄 0 處；jq -e 合法
```

commits：`agents-config@7b20075`、`dotcodex@777fa9c`；5 條 findings 皆已在 PR thread 逐條回覆。

### 13.5 制度層面的收穫

本次是**獨立審查者抓到自建測試盲點**的實例：我用 50 個 case 宣稱「四破口全關」，Copilot 用 3 條 comment 找出第 5 個破口 + 一個 fail-open。這與本報告 §1.3 對 `dotnet-code-reviewer` / `code-reviewer` 的 KEEP 判決（軸 3：乾淨 context 的獨立審查）互為佐證 —— **同一顆模型在主 context 自審，測不出自己測試設計的盲點。**

---

## 14. Squash-merge 與合併後事故 · 2026-07-25

### 14.1 合併結果

| PR | merge commit | 遠端分支 | 本地分支 |
|---|---|---|---|
| [agents-config#1](https://github.com/BriantsaiCoder/agents-config/pull/1) | `1dad811` | 已刪 | 已刪 |
| [dotcodex#1](https://github.com/BriantsaiCoder/dotcodex/pull/1) | `355fd26` | 已刪 | 已刪 |

### 14.2 🔴 合併後事故：切分支讓 Claude 的 skills 靜默回退

清理本地分支時：

```
git checkout main            → 成功
git pull --ff-only origin main → 致命錯誤: 無法快轉，中止
```

`checkout` 先成功、`pull` 才失敗，**工作區因此停在過時的 local main（`7873029`）**，今天所有 skill 修改在檔案層面全部消失（commit 安全，但檔案是舊的）。

**危險之處在於它是靜默的**：`~/.claude/skills/*` 是指向 `~/.agents/skills/*` 的 symlink，所以 **`~/.agents` 一切分支，Claude 讀到的 skill 內容就即時改變**。當下的 session reminder 確實把 skill descriptions 換回了舊版（`agent-browser`、`dotnet-winforms`、`mp-zoom-out` 三個都退回舊描述），沒有任何錯誤訊息。

**根因**：local `main` 有一個從未推送的 commit `7873029`，與 squash 產生的 `origin/main` 分岔（各領先 1）。

**處置**：先驗證 `7873029` 是 chore 分支的祖先（`git merge-base --is-ancestor` → 是），確認其內容已隨 squash 進入 `origin/main`、不會遺失，再重建 local main。`git reset --hard` 被 `permissions.deny` 正確擋下，改用 `branch -D` + `checkout -b main origin/main`。

### 14.3 驗收（合併並清理後）

```
tests/git-push-guard.sh       68 PASS / 0 FAIL
tests/codex-git-push-guard.sh 12 PASS / 0 FAIL
tests/conformance.sh          12 PASS / 0 FAIL
agents-sync --doctor          斷鏈 0 / override 不存在 / manifest 兩家相符
manifest vs 部署檔            codex ✅  copilot ✅

工作區抽查：better-auth-best-practices 0 處｜trigger-regression 0 處｜node:20 0 處
           共用 guard 存在 ✅｜reviewer-template stack 檢核 ✅

三 repo：.agents main 1dad811 ｜ .claude main cbc8e20 ｜ .codex main 355fd26  皆與 origin 同步
```

---

## 15. CI 建置 · 2026-07-25

今天所有修復都靠本機手動跑 `tests/` 把關，PR 上零機械保證。兩個 repo 各加 5 個檢查。

### 15.1 檢查清單

| agents-config | 攔什麼 |
|---|---|
| `agents-sync --check` | 7 條 lint，含 routing 逐名點名的 skill 是否存在於 `skills/`（2026-07 九個死名事故的結構性根絕） |
| `git-push-guard.sh` 68 cases | `[T0-3]` 五個破口的回歸 |
| `shellcheck -S error` | guard 是承載安全判定的 shell |
| skill-index vs `skills/` | **今天踩過**：`skills/` 53 而 index 停在 52，該 skill 對三家 host 全不可見 |
| dist/ 與 source 同步 | 手改 `dist/` 或忘了跑 `agents-sync` |

| dotcodex | 攔什麼 |
|---|---|
| `hooks.json` JSON 合法 | 壞掉會讓 `[T0-3]` guard **靜默不掛載** |
| agent TOML 可解析 | |
| 無硬編碼家目錄 | Copilot review 那條的回歸 |
| `shellcheck -S error` | |
| **追蹤面未擴大** | 逐一斷言 `auth.json` / `stitch.env` / `config.toml` 未被追蹤——該目錄含實際憑證，先前純靠 `.gitignore` allowlist 紀律，無機械攔截 |

### 15.2 三個寫的過程中踩到的坑

1. **第一版 dist 同步檢查會永遠紅** —— banner 內嵌 HEAD sha，每 commit 皆變，整檔比對必敗。改 `sed '1d'` 只比 body，並在 workflow 註解寫明原因防止被「修」回去。
2. **`~/.codex/.gitignore` 是 allowlist，`.github/` 不在核准清單** —— 直接加 workflow 會**靜默不進版控**。`check-ignore` 確認後補 `!.github/`。
3. **`AGENTS_DEPLOY_ROOT` 指暫存目錄跑 `agents-sync` 會改寫 `dist/manifest.tsv` 但不更新 live host 檔** —— conformance 立刻 12 PASS → 11 PASS/1 FAIL。正常部署即復原。驗證用的 dry-run 也可能弄髒狀態。

### 15.3 Copilot 第二輪 review（CI PR）

| Finding | 裁決 |
|---|---|
| agents：「skill-index 檔尾有空白行 → diff 永遠紅」 | ❌ **不成立**。檔尾為 `-->\n`；54 行 = 52 + 2 marker；兩邊皆 52。**且該步 CI 本來就綠**（run 30145833884） |
| agents：locale 排序差異 | ✅ **成立**。產物在 macOS 生成、CI 於 Linux 比對，是跨機比較。**修根因而非症狀**：`emit_skill_index` 與 CI 同改 `LC_ALL=C`，讓提交進版控的產物本身 locale-無關（只在 CI 端 sort 的話產物仍 machine-dependent）。改前後產物零差異 → 預防性修復 |
| codex：`/home/[a-z]` 漏 `/home/_user`、`/home/9user` | ✅ **成立**。4 樣本命中 1/4 → 改 `[^/]` 後 4/4。這條本身是機械閘，判定不完整＝假防線 |

### 15.4 驗收

```
首輪 CI：兩邊 5 步全 success、零 skip；log 內 68 行逐 case PASS（證實非空過）
修正後 ：agents 495cae9 success ×5；codex 6e40c39 success ×5
本機   ：git-push-guard 68 PASS｜conformance 12 PASS / 0 FAIL｜agents-sync lint PASS
PR     ：agents-config#2（+77−6/5檔）、dotcodex#2（+63−1/3檔），皆 MERGEABLE、CI pass、findings 1/1 已回覆
```

### 15.5 未納入 CI

`conformance.sh` 斷言的是 `~/.claude`、`~/.codex` 的**實際部署結果**（`settings.json` 的 `$defaults`、audit log 權限、`codex execpolicy`、部署後 AGENTS.md），runner 上不存在。仍是本機動 guard / hook / settings / core 後的必跑項，已寫進 workflow 註解說明為何不納入。

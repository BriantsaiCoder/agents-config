# /doctor 2026-07-26 — skill 家族碰撞矩陣 + 軸 4 薄尾複審 + 全庫版本時效稽核

> 承接 `2026-07-25-skill-audit`（六步協定）與 `2026-07-25-model-capability-coverage`（五軸判準）。
> 同日三輪 `/doctor` 的合併紀錄，「0 可移除」的判決沿用 2026-07-25，不重跑。
>
> | 段 | 內容 | 是否已執行變更 |
> |---|---|---|
> | §1 | 全庫 1,225 對 description 碰撞實測 | 否（分析） |
> | §2 | 軸 4 單軸薄尾 8 個 skill 六步複審 | 否（分析） |
> | §3–4 | 常駐成本模型、附帶觀察 | 否（分析） |
> | §5 | Vue 家族版本稽核 | **是**——4 個 skill / 7 檔（§5.2–5.4、§5.7；未修實例見 §5.8） |
> | §6 | 全庫版本時效稽核與修復 | **是**——28 個 skill / 81 檔（§6.5 為人工收尾；未解決見 §6.7） |
> | §7 | §6.7 三項未決的完整收斂 | **部分**——158 項裁決；68 個 DEFECT 中依證據等級套用 9 組（§7.9），其餘明列未做 |
>
> 另：`core/routing.md` 點名清單補 3 個 skill 並重跑 `agents-sync`（第一輪核准，已執行）。
> 已 commit 並推送、CI 綠：`1b3d600`（routing）、`3370201`（Vue/Nuxt）、`f3bb004`（全庫版本對齊 28 skill）。
>
> **§6.4 與 §7.6 是本檔最重要的兩段**，講同一件事：帶佐證的 finding 仍可能是錯的，且「舊文為假」不等於「新文為真」。§6.4 是已發生的事故，§7.6 是據此立的 gate。
>
> **同目錄的 `01-version-currency-findings.json`（113 findings）與 `02-unverifiable-convergence.json`（158 裁決）依根 `.gitignore` 的 `proposals/*/*` 規則不入版控**（AI 生成的原始資料）。本檔已把結論、證據與可執行的下一步逐項內嵌，兩份 JSON 僅供本機追溯。

---

## 一頁結論

**問題一「同類型 skill 建議合併嗎」→ 不建議，且這次有實測數字支撐，不是沿用結論。**

全庫 50 個 skill、1,225 個配對，用「全庫出現 ≤3 次的特異觸發詞」計算真實路由歧義：

- 有任何特異詞重疊：**194 / 1225 (15.8%)**
- 重疊 ≥3 個特異詞：**14 / 1225 (1.1%)**
- 而**碰撞最高的兩對，重疊詞全部來自互指免責句本身**——那是路由機制在運作，不是歧義。

使用者舉例的 React 家族，家族內最高碰撞是 `jest-best-practices ∩ vitest` = 0.154，低於 DB 家族的 `ef-core ∩ ef6` = 0.309。**React 家族沒有任何合併訊號。**

**問題二「Opus 5 內建知識已覆蓋，建議移除嗎」→ 移除不成立，瘦身成立但標的不在 skill 數量。**

- 移除單一 skill 平均省 **~354 字元 ≈ 88 token**，且只在 Claude 這一家成立（Codex / Copilot 的 skill 常駐成本為 0，靠 `core/routing.md` 點名路由）
- 軸 4 薄尾 8 個複審後：**Keep 8、Delete 0**，但其中 2 個的 Keep 理由要誠實標示為「rubric 使然」而非「有正面證據」
- 真正的瘦身標的是 on-invoke 層的 `SKILL.md` 本體——而最大宗（ecpay 818 行、design-doc-mermaid 7,500 行）**已於 2026-07-25 退役至 attic**，剩餘全庫 SKILL.md 皆 < 500 字

---

## 1. description 碰撞矩陣（新增，前份報告只測了 4 對）

### 1.1 always-on 成本現況

| 項目 | 2026-07-25 22:00 | 2026-07-26 實測 | 差 |
|---|---:|---:|---|
| skill 數 | 51 | **50** | ecpay 退役 |
| description 純字元 | 18,968 | **17,700** | −1,268 |
| description + name（listing 近似） | — | **18,680 ≈ 4,670 tok** | — |

差額由三筆相反方向的變更組成，故總量看似「只降一點」是正確的：
`b5baa42` ecpay 退役（−1 skill）→ `681bc83` 修剪 10 個過長 description（−290 tok）→ `3dba8f2` 補家族互指（+528 tok，刻意）。

### 1.2 家族內碰撞（Jaccard，含樣板語句）

| 家族 | skill 數 | 家族內最高碰撞 | 判定 |
|---|---:|---|---|
| DB / ORM | 6 | `ef-core ∩ ef6` **0.309** | 全庫最高，但由版本 namespace 區分 |
| 安全 / 發布 | 5 | `dependency-security-scan ∩ security-review` **0.288** | **重疊詞 100% 來自互指免責句** |
| React / 前端測試 | 10 | `jest ∩ vitest` **0.154** | 遠低於門檻，**無合併訊號** |
| Vue | 5 | `pinia ∩ vue-best-practices` **0.138** | 低 |
| .NET | 5 | `dotnet-core ∩ dotnet-framework` **0.104** | 低 |
| 流程 / mp | 9 | `bug-fix-settlement ∩ dev-workflow` **0.105** | 低（僅共用「bug、workflow」） |

跨家族碰撞僅 1 對達 0.12：`pinia ∩ testing-library-react-best-practices` (0.127)，成因是後者 description 明寫「For Vue component or Pinia store testing, use pinia」——**又是互指免責句**。

### 1.3 特異觸發詞重疊（剝除樣板後的真實歧義）

| 重疊數 | 配對 | 重疊詞 | 成因 |
|---:|---|---|---|
| 10 | `dependency-security-scan ∩ security-review` | ci/cd, container, dependencies, flaws, pre-commit, sbom, scanning, scans, vulnerabilities, xss | **互指免責**（雙向） |
| 8 | `postgresql-best-practices ∩ postgresql-optimization` | dal, explain, index/operator, jsonb, partitioning, postgresql, rls, tuning | **互指免責**（雙向） |
| 5 | `ef-core ∩ ef6` | change, migrations, n+1, performance, tracking | **真實領域重疊**，由 `Microsoft.EntityFrameworkCore` vs `System.Data.Entity` 區分 |
| 5 | `backend-release-verification ∩ frontend-release-verification` | changes, finishing, readiness, release, smoke | 真實重疊，由 backend/API/worker vs frontend user-facing 區分 |
| 4 | `vite ∩ vitest` / `react-best ∩ testing-library-react` / `pinia ∩ vue-best` / `jest ∩ vitest` | — | 皆有互指句 |

**方法學結論**：Jaccard 對這個 skill 庫**高估**碰撞，因為互指免責句刻意複述對方的觸發詞。前份報告把 `postgresql` 那對的 0.250 當「全庫第 2 高、每個 PG 任務付一次仲裁成本」，本次實測降到 0.183（描述已修剪），且重疊詞經逐一比對確認全部落在免責句內。**該對的仲裁成本論述應予下修。**

### 1.4 現存互指關係（6 條，全部健在）

```
css-ui-best-practices          → tailwind-v4-shadcn
dependency-security-scan       ⇄ security-review
jest-best-practices            → testing-library-react-best-practices
postgresql-optimization        → postgresql-best-practices
vue-best-practices             → vue-debug-guides, vueuse-functions
```

2026-07-25 稽核指出的 `security-audit ∩ security-review` 碰撞**已消失**（不在前 60 對內），由 `681bc83` 的 description 修剪解決。

---

## 2. 軸 4 單軸薄尾複審（六步協定完整跑完）

範圍：2026-07-25 `00-report.md:28` 標記為「單靠軸 4 撐住」的 8 個。

### Step 0 — vendored gate（決定哪些判決合法）

| skill | VND | 後果 |
|---|---|---|
| `vueuse-functions` | **VND**（© 2026 SerKo） | **任何原地 Trim / Split 判決無效**；只有整體移除或換版合法 |
| 其餘 7 個 | `-` | 全判決合法 |

全庫另有 5 個 vendored：`agent-browser`、`native-feel-cross-platform-desktop`、`playwright-best-practices`、`security-audit`、`tailwind-v4-shadcn`（VND*，已錄 fork）。

### Step 1 — token cost（全部 PASS）

8 個全部低於 500 字上限：mp-diagnose 497、mp-tdd 494、pinia 480、dotnet-framework 479、dotnet-logging 468、react-best 443、vueuse 436、testing-library-react 383。**無 Trim 訊號。**

全庫 7 個超標者皆不在本次範圍：init-project-docs 1421、security-audit 1324(VND)、dev-workflow 1251、native-feel 900(VND)、dotnet-winforms 805、auditing-skill-folder 645、mp-grill-with-docs 510。

### Step 2 — description trap（全部 PASS）

8 個全部 `-`（trigger-only，非 workflow 摘要）。無 `MISS`——包含 `vueuse-functions`，其 description 在檔內完整且 PyYAML 可解析（見 §4 異常）。

### Step 3–5 — stance bleed / mechanical-only / type clarity

| skill | Step 3 stance bleed | Step 4 mechanical-only | Step 5 type |
|---|---|---|---|
| `react-best-practices` | ⚠️ R9/R10/R11 與 `rules/frontend-spa.md:16,18,20` **逐條對應** | ⚠️ R2/R7/R14/R15 = ESLint 可強制（exhaustive-deps、no-array-index-key、no-explicit-any、jsx-a11y） | Reference，乾淨 |
| `testing-library-react-best-practices` | ⚠️ query priority 與 `rules/testing.md:25` 對應；「regression test 先紅後綠」= `[R-2]` | ⚠️ `eslint-plugin-testing-library` 可強制 prefer-screen-queries / no-container / prefer-user-event | Technique+Reference，一致 |
| `dotnet-logging-best-practices` | R9（NLog 走 XML config 讓維運免重編）= 真家規；R5 = `[T0-4]` | ⚠️ R1 可由 CA2254 analyzer 強制 | Reference，乾淨 |
| `dotnet-framework-best-practices` | 無純 stance（R4 為技術事實） | ⚠️ R3/R10 有 analyzer 可強制 | Reference，乾淨 |
| `pinia` | 「server state 不放 Pinia」為輕度 stance | 無 | 輕度混型（Workflow+Checklist+Decision Tree），可接受 |
| `mp-tdd` | 無（純 discipline） | 無 | Technique，乾淨 |
| `mp-diagnose` | 無（純 discipline） | 無 | Technique，乾淨 |
| `vueuse-functions` | **VND — 缺陷回報不修** | — | Reference，乾淨 |

**Step 3 的關鍵反駁**：`rules/frontend-spa.md` 與 `rules/testing.md` 帶 `paths:` frontmatter（`**/*.{vue,jsx,tsx}`），只在**碰到符合的檔案**時注入。實測（2026-07-26 06:28）Read 會觸發、Bash 不會——純用 grep/cat 做的審查完全讀不到這兩份家規。skill 則靠 description 常駐可路由。
→ **兩者觸發面不同，不是可消除的重複。**

**Step 4 的關鍵限定**：4 個 skill 各有數條規則可機械化為 lint/analyzer 設定。但機械化需落在**專案的** eslint/analyzer 設定裡，而目前 7 個專案中 **0 個是前端 SPA**。
→ 標記為「有前端專案時的 follow-up」，現在無處可落。

### Step 6 — built-in coverage（使用者的問題本體）

| skill | Opus 5 是否覆蓋內容 | 非覆蓋殘餘 | 判決 |
|---|---|---|---|
| `pinia` | 部分 | `@pinia/testing` 的 `createTestingPinia` 四分支決策樹（`createSpy` / `initialState` / `stubActions:false`）——API 細節會漂移，模型常寫錯 | **Keep**（實為軸 5，前份報告低估） |
| `dotnet-logging-best-practices` | 部分 | R3 `[LoggerMessage]` 停用時零配置 + .NET Framework 走 `LoggerMessage.Define` 的版本分歧；R9 維運家規 | **Keep**（軸 4+5） |
| `dotnet-framework-best-practices` | 大部分 | R4「library 加 `ConfigureAwait(false)`、controller 不加」是**對抗模型預設**（模型慣性壓平成一律加） | **Keep**（軸 4，模型預設校正） |
| `react-best-practices` | 大部分 | R9/R10/R11/R15 家規（4/15 條） | **Keep**（軸 4，但依賴 §Step 3 的觸發面論證） |
| `vueuse-functions` | 幾乎全部 | `useStorage` 系列 = localStorage 包裝，`[T0-4]` 釘在具體 API 名上 | **Keep**（Step 0 亦禁原地編輯） |
| `testing-library-react-best-practices` | **幾乎全部** | selector 優先序為 RTL 官方教條非家規；`[R-2]` 覆述 | **Keep（rubric 使然）** ⚠️ |
| `mp-tdd` | **幾乎全部** | anti-rationalization 表 + No Exceptions 執行條款 | **Keep（rubric 使然）** ⚠️ |
| `mp-diagnose` | 大部分 | Phase 1「先有 feedback loop 才准動」是 gate（`superpowers:systematic-debugging` 無此閘）、3–5 條可證偽假說、`[DEBUG-xxxx]` 標記慣例、Phase 5 seam 正確性 = `[R-2]` | **Keep**（軸 4，與 superpowers 實質互補） |

**⚠️ 標記的誠實說明**：`auditing-skill-folder` 的 Step 6 判準是「訓練資料覆蓋 **AND** 無使用者 stance **AND** 無 workflow discipline → 才是 delete 候選」。`mp-tdd` 與 `testing-library-react-best-practices` 各自命中最後一項（discipline / checklist），因此**依 rubric 不可能被判 delete**。

這是 rubric 的性質，不是它們有正面價值的證據。誠實的表述是：**這兩個是全庫最接近可移除的，但依現行判準無法達到 delete；要改判需要先改 rubric，而不是改判決。**

### 判決總表

| 判決 | 數 | skill |
|---|---:|---|
| Keep | 6 | pinia, dotnet-logging, dotnet-framework, react-best-practices, vueuse-functions(VND), mp-diagnose |
| Keep（rubric 使然，標記為薄） | 2 | mp-tdd, testing-library-react-best-practices |
| Trim / Split / Move / Convert-to-hook / Delete | **0** | — |

---

## 3. 為什麼「移除省 context」這個動機不成立（數字更新）

| Host | skill 常駐機制 | 50 個 skill 的常駐成本 |
|---|---|---|
| Claude | `~/.claude/skills/*` symlink → `~/.agents/skills/*`，description 常駐 | **18,680 字元 ≈ 4,670 tok** |
| Codex | `~/.codex/skills/` 僅 2 個本地；共用靠 `AGENTS.md` 路徑散文 | ≈ 0 |
| Copilot | `~/.copilot/skills/` 空 | 0 |

刪 1 個 skill 平均省 **354 字元 ≈ 88 token**（17,700 / 50）。

**listing 預算對照**：Claude Code 把 skill listing 編列在約 1% context window。本 session 為 `claude-opus-5[1m]` → 預算約 10k token，實測個人 skill 4.67k + 啟用 plugin/內建 skill（由 in-context listing 估）約 2–3k，**今日不會截斷**。
但同一份 listing 放在 200k window 的 session → 預算僅 2k token，**會截斷、路由會退化**。這是唯一一個「skill 數量」真的會咬人的情境。

---

## 4. 附帶觀察（非本次範圍，未提案）

1. **`vueuse-functions` 在 in-context skill listing 中無 description**——50 個個人 skill 中唯一一個。檔內 description 完整（343 字元）、PyYAML 可解析、Step 2 linter 判 `-` 非 `MISS`。**根因未定**，以 `/context` 複驗較快。影響：該 skill 在 Claude 端可能無法靠 description 路由，而它也不在 `core/routing.md` 的點名清單內 → 兩條路由途徑同時缺席。
2. **`core/routing.md` 點名清單仍缺 3 個非慣例命名的 Keep skill**：`native-feel-cross-platform-desktop`、`auditing-skill-folder`、`react-router-framework-mode`（2026-07-25 稽核 A2 項，至今未執行）。這 3 個在 Codex / Copilot 端**不可路由**。
3. **前端 lint 機械化（Step 4）無處可落**：7 個專案 0 個前端 SPA。待有前端專案時，`react-best-practices` R2/R7/R14/R15 與 `testing-library-react` 的 query priority 應落為 eslint 設定，屆時 skill 對應段落可瘦身。

---

## 5. Vue 家族版本稽核（第二輪 /doctor，同日）

**提問**：「這些 skill 中關於 vue 的是否都是 vue3 版本？若否需升級。」
**答案：全部都是 Vue 3，零 Vue 2 API，不需要升級。** 但掃描過程發現一個真的 bug 與一項版本停滯。

### 5.1 Vue 2 掃描結果（20 個專屬標記，9,329 行）

| skill | 檔 | 行 | Vue 2 命中 |
|---|---:|---:|---:|
| `vue-best-practices` | 9 | 2,320 | 0 |
| `nuxt` | 20 | 5,178 | 0 |
| `pinia` | 11 | 1,678 | 0 |
| `vueuse-functions` (VND) | 3 | 92 | 0 |
| `vue-debug-guides` | 2 | 61 | 0 |

標記集：`new Vue(` / `Vue.extend` / `Vue.component(` / `@vue/composition-api` / `beforeDestroy` / `destroyed()` / `this.$set` / `this.$delete` / `slot-scope` / `scopedSlots` / `$listeners` / `functional: true` / `Vue.use(` / `filters:` / `vuex` / `Vue 2` 等。

全庫唯一「Vue 2」字樣在 `vue-best-practices/references/pinia.md:9`，用法正確（說明 Options-style store 僅用於遷移舊庫），非 Vue 2 教材。

### 5.2 🔴 已修：`nuxt` skill 內部版本矛盾（bug，非版本落後）

修前狀態——同一個 skill 內兩套互斥答案：

| 位置 | 立場 |
|---|---|
| `nuxt/SKILL.md:7` 「> Nuxt 3.x.」 | Nuxt 3 |
| `nuxt/SKILL.md:12` workflow step 1 列 `pages/` `server/` `composables/` | Nuxt 3 根層 |
| `nuxt/references/core-directory-structure.md:14-24` 標準結構為 `app/{...}` | **Nuxt 4** |
| `nuxt/references/core-directory-structure.md:50` `srcDir: 'src/', // Change from 'app/'` | **Nuxt 4** |
| `pinia/references/advanced-nuxt.md:40` `app/stores/ (Nuxt 4)` | **Nuxt 4**（跨 skill 亦不一致） |

失效形狀等同前次稽核的 css-ui × tailwind 矛盾（產出 `hsl(hsl(...))`）——當時判為正確性 bug 而非整理。

**Context7 查證**（`/websites/nuxt_4_x`）：Nuxt 4 已 GA（`/nuxt/nuxt` 有 `v4.1.3`），`srcDir` 預設改為 `app/`，向下相容自動偵測 Nuxt 3 結構，`srcDir: '.'` 可還原。

**修法**：SKILL.md 版本橫幅改為「Nuxt 3.x / 4.x — check the major first」並說明 `app/` 差異；step 1 路徑改為 `[app/]` 前綴標記。

### 5.3 🟡 已補：Vue 3.5 穩定版 API 缺席

**Context7 查證**：`/vuejs/core` 現為 `v3.6.0-beta.3` → 3.5 已是穩定版。`/websites/vuejs_api` 提供逐條語意。

修前，skill 停在 Vue 3.4（`defineModel` 有寫）：

| API | 修前 | 修後落點 |
|---|---|---|
| Reactive props destructure（3.5 起解構保有反應性；型別宣告可用原生預設值取代 `withDefaults`） | 0 | `component-patterns.md` 新增 `### Reactive Props Destructure (Vue 3.5+)` |
| `useTemplateRef()` | 0 | `component-patterns.md` 新增 `## Template Refs 模板引用` + 目錄 |
| `onWatcherCleanup()` | 0 | `state-management.md` 新增於 `watchEffect` 段後 |
| `useId()` | 0（僅 React 版在 `next-best-practices`） | `nuxt/references/best-practices-ssr.md` 的 Hydration Mismatch Prevention 段 |

三者皆為**同一段程式碼在 3.4 與 3.5 語意相反**的類型，屬軸 5（版本釘死）核心價值——正是「模型愈強愈自信寫出過期寫法」的實例。故另在 `vue-best-practices/SKILL.md` 與 `nuxt/SKILL.md` 各加一行版本橫幅，要求先讀 `package.json` 確認 minor/major。

### 5.4 🟡 已修：`vue-debug-guides/references/INDEX.md` 懸空指向

末行指向不存在的「the disabled skill cleanup folder」（2026-07-25 稽核 §1.3 已列 FIX，當時未執行）。改為指向四個 companion skill。

### 5.5 未動且不可動：`vueuse-functions`

其 `references/INDEX.md`（92 行、明寫「不再 vendor 逐函式文件」）是 Anthropic context-engineering rule 6「rich references 取代 simple specs」的典型標的，但 Step 0 判 **VND**（© 2026 SerKo）→ **原地結構性編輯為無效判決**，只有整體換版或移除合法。列為 N1 的已知豁免項，勿在下輪稽核重新提案。

### 5.6 驗收

- Step 1 字數：`nuxt` 482、`vue-best-practices` 478、`vue-debug-guides` 389，全部 < 500（編輯中途 `nuxt` 曾到 510，已收斂）；全庫超標者仍為原有 7 個，無新增
- Step 2 description lint：三者皆 `-`（trigger-only）
- Vue 2 API 重掃：0
- `agents-sync --check` lint PASS；host 組裝位元組未變（skill 不進 host 常駐層）
- `tests/conformance.sh` **14 PASS / 0 FAIL**

### 5.7 已修：`vue-debug-guides` 的 Nuxt-3-only 框架（追加，第二輪 follow-up）

與 §5.2 同一缺陷類別，但落在**路由面**而非內容：

| 位置 | 修前 | 修後 |
|---|---|---|
| `vue-debug-guides/SKILL.md` description | `Vue 3 / Nuxt 3 runtime bugs` | `Vue 3 and Nuxt 3/4 runtime bugs` |
| `vue-debug-guides/SKILL.md:8`（本文首行） | `Vue 3 / Nuxt 3 debugging for runtime issues…` | `Vue 3 and Nuxt 3/4 debugging…` + 明示「症狀分類與大版本無關——Nuxt 4 改的是目錄結構，不是這些失效模式」 |

**判定依據**：該 skill 的九個症狀分類（hydration mismatch、跨請求汙染、server 端 browser API、Suspense error UI …）全部與 Nuxt 大版本無關，Nuxt 4 的差異在 `srcDir`／目錄結構，而本 skill 不觸及目錄。**故這是 description 低報涵蓋範圍，不是內容過期**——修法是放寬宣稱，不是改寫內容。

Step 1 字數 389 → 405（< 500）；Step 2 lint 仍為 `-`。

### 5.8 同缺陷類別的剩餘實例（未修）

| skill | description | 狀態 |
|---|---|---|
| `pinia` | `Vue 3 / Nuxt 3` | **未修，不在核准範圍**。且其本文 `references/advanced-nuxt.md:40` 已是 Nuxt 4 感知（`app/stores/ (Nuxt 4)`）→ 與 §5.2 的 `nuxt` 完全同形：本文超前、description 落後 |
| `vueuse-functions` | `Vue 3 / Nuxt 3` | **不可修**。Step 0 判 VND（© 2026 SerKo），原地編輯為無效判決；只有整體換版或移除合法。列為已知豁免項，勿在下輪稽核重新提案 |

---

## 6. 版本時效稽核與修復（第三輪 /doctor，同日）

**提問**：「這些 skill 是否都已符合最新版本，若有缺少的資訊幫我補足。」

### 6.1 稽核（13 agent／1.30M token／20 分鐘）

50 個 skill：**32 個有版本時效缺陷、18 個乾淨**，共 113 個缺陷。每條判斷強制 Context7 官方佐證，禁止靠記憶。

| 嚴重度 | 全部 | 可原地修 |
|---|---:|---:|
| contradiction（同 skill 內版本立場互斥） | 16 | 13 |
| stale-wrong（照抄會出錯） | 38 | 35 |
| stale-incomplete | 49 | 42 |
| cosmetic | 10 | 9 |
| **合計** | **113** | **99** |

vendored 14 個只回報不修：`tailwind-v4-shadcn` 7、`playwright-best-practices` 5、`vueuse-functions` 1、`native-feel-cross-platform-desktop` 1。

完整 findings：`01-version-currency-findings.json`。

### 6.2 完整性批判者的貢獻（這步不能省）

- 抽驗 8/105 個上游 finding，**逐字吻合、0 幻覺**
- 抓到 **3 個「空檢查」**——上游宣稱檢查過卻零裁決。其中 `react-router-framework-mode` 是真實漏網，補查後開 2 個 finding
- 抓到**裁決不對稱**：上游把 `nodejs` 的「同檔 CI node 20 vs Dockerfile node 24」判 contradiction，卻對 `nuxt` 完全同型的情況拒絕裁決
- 補掃 15 個未檢查 skill，找出 `c-cpp-best-practices` 是其中唯一具實質版本面者（CMake 4.0 已把 `cmake_minimum_required` < 3.5 從 warning 升為 **error**）
- 留下決定性未決項「React Router 8 是否 GA」並給出可執行補查。本輪 `npm view react-router version` = **8.3.0**，故其 2 個 finding 由 stale-incomplete 升為 stale-wrong

### 6.3 修復（20 agent／2.02M token／16 分鐘）+ 人工收尾

10 個叢集各自 apply 後由**獨立複驗者**實際開檔驗證（不採信 apply agent 宣稱）。結果：

| | 數 |
|---|---:|
| 複驗者親自確認落地 | **105 筆編輯** |
| PASS 叢集 | 4（containers-sec、vite-vitest、dotnet-core、react-css） |
| FAIL 叢集 | 6 |
| 複驗抓到的問題 | 12（wrong-content 6、new-contradiction 4、over-budget 2） |

### 6.4 🔴 最重要的教訓：**帶 evidence 的 finding 仍可能是錯的**

`dotnet-winforms-best-practices` 的 5 個 wrong-content 全部同源——稽核 agent 開的 finding 宣稱「`Form.ShowAsync`/`ShowDialogAsync` 是 .NET 10+ experimental、.NET 9 完全沒有」，apply agent **逐字照抄**，把基準線上原本正確的 `## Async APIs (.NET 9+)` 改成錯的。

複驗者以 Microsoft Learn 反駁，本輪再用 microsoft-learn MCP 獨立確認：

> **WFO5002 Version introduced: .NET 9**｜async forms（`ShowAsync`/`ShowDialogAsync`/`TaskDialog.ShowDialogAsync`）是 .NET 9 新增、由 WFO5002 守門｜「This compiler error no longer applies starting with .NET 10」｜`Control.InvokeAsync` 是 .NET 9 且**不是** experimental

正確閘門與 dark mode 完全平行（.NET 9 需抑制診斷／.NET 10 起穩定）。5 處已修正並互相對齊。

**制度含意**：verify 階段若只檢查「修改有沒有落地」，這個回歸會直接進版控。**複驗必須獨立回查權威來源，而非只比對 apply agent 的宣稱。** 本次 workflow 的 verify prompt 明寫「不要相信上游的宣稱，自己 grep/sed 看」，但真正救回來的是複驗者主動去查了 Microsoft Learn——這一條要寫進下次的 verify prompt。

### 6.5 人工收尾的 11 處

| 檔案 | 問題 | 處置 |
|---|---|---|
| `dotnet-winforms/{SKILL.md, mvvm-and-modern-apis.md ×2, designer-and-serialization.md}` | 照抄錯誤 finding，版本閘門全錯 | 依 Microsoft Learn 改正，四處對齊 |
| `pinia/references/advanced-nuxt.md` | 過期 `nuxi` 指令留在可執行 bash fence 內，且是區塊最後一行 | 移出 fence 改為 prose（比照 `nuxt/references/core-cli.md:31`） |
| `nodejs/references/api-design.md` | `lib: ES2024` 但同檔 `engines: >=18` | 改 `>=24`，對齊同 skill 的 `node:24-alpine` |
| `nodejs/references/working-patterns.md` ×2 | `asyncHandler` 無 Express 5 但書，與同 skill 兩處新內容衝突 | 標明 Express 4 only |
| `auth-implementation-patterns/references/jwt.md` | pitfall「No refresh rotation」與新增的 sender-constrained 合規列互斥 | 改為「rotation 與 sender-constraint 都沒有」才是 pitfall |
| `mysql/references/version-dba.md` | 新推薦 9.x 為目的地，但兩行後仍教用 `mysql_native_password`（9.0 已從 server 移除） | 標明 8.0／8.4／9.x 三段差異 |

### 6.6 驗收

- `count-words.sh`：超標集合與基準線**完全相同的 7 個**，無新增。`dotnet-winforms` 811 vs 基準 805（+6，換到 WFO5001/WFO5002 閘門資訊）；`nuxt` 499，距上限 1 字
- `lint-descriptions.sh`：0 個 TRAP／MISS／ERR
- vendored 6 個 skill **完全未被碰**（`git diff --name-only` 驗證）
- `agents-sync --check` lint PASS；`tests/conformance.sh` **14 PASS / 0 FAIL**
- 規模：81 檔、+597／−201、28 個 skill

### 6.7 未解決（誠實列出）

- `init-project-docs/SKILL.md` **1421 字**（上限 500）——**既有債，本批未碰該檔**。要修需真正的 progressive-disclosure 重構，超出本批範圍
- 上游 60+ 個 `unverifiable` 未收斂（Dapper.Contrib 維護狀態、FluentAssertions 授權、Moq 版本、MySQL 8.0 EOL 日期等）
- 抽驗只覆蓋 8/105（7.6%），其餘 97 筆的引文正確性未經第三方確認
- vendored 偵測只定位 5 個（memory 記載 6 個），尚有 1 個未定位
- `init-project-docs/references/settings-templates/` 下的 JSON 模板未逐檔稽核

---

## 7. 三項未決事項的完整收斂（同日第四輪）

使用者點名 §6.7 的三項未解，要求完整分析確認。結果：**兩項當場結案，一項從 94 收斂到 9。**

### 7.1 ✅ 「vendored 只定位 5 個」→ 沒有未定位的

權威工具 `~/.claude/skills/auditing-skill-folder/scripts/check-vendored.sh` 報 **6 個**，全部有名有姓。批判者漏掉的是 **`tailwind-v4-shadcn`**——全庫唯一**既無 `LICENSE` 檔、SKILL.md 前 8 行也無 upstream 標記**者，出處記在 `vendored-forks.md:19`（recorded fork，`VND*`），只有跑 `fork_recorded()` 分支的官方腳本抓得到。

| skill | LICENSE | SKILL.md upstream 標記 | 手刻掃描抓得到？ |
|---|:-:|:-:|:-:|
| native-feel / playwright / security-audit / vueuse-functions | ✓ | ✗ | ✓ |
| agent-browser | ✗ | ✓ | ✓ |
| **tailwind-v4-shadcn** | ✗ | ✗ | **✗** |

→ 印證 `auditing-skill-folder` Step 0 的紅旗「我用眼睛掃一遍就好」。兩次手掃都漏同一個。

### 7.2 ✅ 「抽驗只 7.6%」→ 改為 100% 機械全查，0 幻覺

不再抽樣。把 113 個 finding 的 `claim` 全部對 commit `3370201`（本批修改前基準線）逐字比對：

| 結果 | 數 | % |
|---|---:|---:|
| 逐字命中指定行 | 92 | 81.4 |
| 命中同檔他處（多行 claim 超出比對窗） | 4 | 3.5 |
| 指紋未命中 → 逐一開檔判讀後**全部確認為真** | 17 | 15.0 |

17 個「未命中」是 `claim` 欄寫成帶註解的摘要而非純引文所致，錨點內容逐字存在於指定行（`## React.memo`:19、`## Concurrent Features`:261、`## Radix Vue`:369、`"nuxt": "^3.0.0"`:504/:185、`@theme inline {`:88、`# - 8.0-bookworm-slim (Debian 12)`:219/:263、```` ```udl ````:82 等）。

**113/113 錨定真實內容，0 幻覺。**

### 7.3 ✅ 「60+ unverifiable」→ 實為 107 項，收斂到 9

107 項中 4 項當場結案（上述兩項 + React Router 8.3.0 GA + VERIFY-FAIL 為 0）。其餘 94 項派 12 agent 分 11 叢集收斂，換查證通道（Microsoft Learn `Version introduced` 欄／NuGet flatcontainer API／npm registry／WebSearch）：

| verdict | 數 |
|---|---:|
| **OK-current**（確認現有寫法仍正確） | 75 |
| **DEFECT** | 68 |
| COSMETIC | 11 |
| NOT-A-VERSION-ISSUE | 4 |
| **仍不可解** | **9**（7 個 how_to_resolve 可執行；2 個原為空話，彙整者已改寫為可執行） |

### 7.4 🔴 彙整者的三個 CONFLICT（實證，需裁決才能動手）

1. **TS 7 建議與 lint 鏈不相容** — 兩個 agent 各自假設對方會蓋警語，結果誰都沒蓋。彙整者實跑：`npm view typescript-eslint@8.65.0 peerDependencies` → `typescript >=4.8.4 <6.1.0`，配 `typescript@7.0.2` 得 ERESOLVE。**照原 action 套下去，skill 會推薦一組裝不起來的組合。**
2. **`aspnet-core-api.md:460` 同一行被判 COSMETIC（改）與 OK-current（不改）** — 分歧點不是技術事實，是「標題可否枚舉低於 skill 宣告範圍的版本」這條編輯政策。
3. **MySQL 現行 LTS 是誰** — 一個 agent 據「遷移目標指向 8.4 LTS」判 OK-current，另一個據「9.7 自 2026-04-21 起也是 LTS」把同幾行判 DEFECT。

### 7.5 🔴 三個 blast-radius 漏列（action 只涵蓋部分站點）

| 項 | action 列了 | 全庫實得 | 漏掉的 |
|---|---:|---:|---|
| `UseSerilog` → `AddSerilog` | 4 | **6** | `nlog-log4net-guide.md:570`（同 skill）、`dotnet-core/code-patterns.md:280`（跨 skill） |
| Zod deprecated method 形式 | 5 | **7** | `security-validation.md:27,36`（就在同一個正在改的檔內） |
| `"baseUrl": "."`（TS5102 硬錯誤） | 2 skill | **3** | `tailwind-v4-shadcn:212`（**vendored，只能報**） |

→ 改一半會讓同一個 skill 內部教兩套寫法，正是本輪一直在修的缺陷類型。

### 7.6 🔴 apply gate（本輪最該帶走的一句）

> **替換文字必須先編譯／安裝驗證再落地；證明「舊文為假」不等於證明「新文為真」。**

22 個抽驗站點 **0 幻覺**，但彙整者誠實指出：每一次檢查都只驗證了「現有文字有問題」，**沒有一次驗證替換文字可編譯／可安裝**。本批已點名三段未經驗證的替換文字：`Elastic.Serilog.Sinks` 的 options 形狀、`AddNpgsqlDataSource` 的 builder callback、`AddSerilog` 的多載參數個數。

這正是 §6.4 事故的模式。**不可重蹈。**

### 7.7 已知限制

- **彙整者的輸入被截斷**：本輪 workflow 腳本用 `.slice(0, 90000)` 截 resolved 陣列，導致彙整者只看得到約 7/11 個叢集（它自己偵測到並回報：最後一項的 evidence 欄中途斷成 `maintainer \`ver`）。故其完整性比對是**部分覆蓋**，抽驗分母是 22 個可見站點而非 136 項。**這是本輪設計缺陷，下次應改為傳檔案路徑而非內嵌 JSON。**
- 9 個仍不可解項中，2 個原本的 `how_to_resolve` 是「排程複查」「比對 digest」這類空話，彙整者已改寫為可執行版本（Vue 3.6 stable 觸發條件、Debian trixie 的 digest 比對判準）。

### 7.8 DEFECT 分梯（彙整者排序，判準＝agent 照現有文字寫會發生什麼）

- **第一梯 硬失敗／假綠**（6 項）：TS `baseUrl` 已被 TS 7 移除（實跑 `error TS5102`）／`vi.mock('node-fetch')` 在 global fetch 下**測試假綠並打真網路**／containerization SDK tag `manifest unknown`（實測 404）／`AnyZodObject` 已無此匯出／PG 18 generated column 未指定即 VIRTUAL（**不落盤、不能建索引、無錯誤訊息**）／EF Core 假限制讓 agent 繞開 compiled query
- **第二梯 語意錯／反向建議**（7 項）：MySQL 把 9.7 歸為 Innovation（**反向建議比缺少建議更傷**）／EF Core 9+ 誤判對 EF 8 專案／`AutoFixture.Xunit2` 在 xUnit v3 下測試靜默不執行 …
- **第三梯 過期指引**（8 項）／**第四梯 cosmetic**（1 項，即 CONFLICT 2）

完整裁決：`02-unverifiable-convergence.json`。

### 7.9 已套用（Phase A）—— 分界畫在證據類型而非梯次

68 個 DEFECT 中只套用了證據等級最高的一批。分界不用彙整者的「傷害梯次」，改用**修正動作本身要不要寫新程式碼**——因為 §6.4 事故的本質是「寫進了沒人驗證過的替換文字」，不是「傷害大小判錯」。

| 證據類型 | 處置 |
|---|---|
| 重現過的失敗（實際跑出來壞） | ✅ 套用 |
| 修正是刪除／加註（不產生新 API 碼） | ✅ 套用 |
| 修正要寫新 API 碼且沒人編譯過 | ❌ **不套用** |

第三類正好就是彙整者點名的三段（`Elastic.Serilog.Sinks` options 形狀、`AddNpgsqlDataSource` builder callback、`AddSerilog` 多載參數個數），也正好都在第三梯（舊寫法今天仍能編譯）——**風險最高、收益最低**。

| # | skill / 檔案 | 修正 | 證據 |
|---|---|---|---|
| 1 | `typescript` `config-and-project.md:168,277` | 刪 `"baseUrl": "."` ×2；新增「TypeScript 版本現況」錨點段 + **tseslint peer 上限警語** | 實跑 `tsc 7.0.2` → `error TS5102`；實跑 `npm i` → ERESOLVE |
| 2 | `nodejs` `testing.md:285-292` | `vi.mock('node-fetch')` → `vi.stubGlobal('fetch', …)`，並註明假綠風險 | Node 18+ 內建 global fetch；本 skill 自釘 `node:24-alpine` |
| 3 | `containerization` `dotnet-framework.md:252-265` | 只改 stage 1 的 SDK tag 註解區塊（stage 2 不動），移除 sdk repo 不存在的 4.7 / 4.6.2 | MCR manifest A/B：sdk 4.7 / 4.6.2 → **404**，aspnet 同 tag → 200 |
| 4 | `containerization` `dotnet-framework.md:150,369` | LogMonitor `v2.1.1` → `v2.2.1` ×2 | upstream release v2.2.1（2026-06-19） |
| 5 | `nodejs` `security-validation.md:93,96-98` | `AnyZodObject` → `z.ZodObject`；新增 Zod 4 版本錨點 | zod 4.4.3 主入口無此匯出 → TS2305 |
| 6 | `nodejs` `security-validation.md:27,36,222,231`＋`typescript` `patterns-and-guards.md:329,331,369` | `z.string().email/uuid/url()` → `z.email/uuid/url()`，**7 行一次改滿** | 彙整者補出上游漏列的 :27,:36（就在同一個正在改的檔內） |
| 7 | `postgresql` `schema-design.md:253` | PG 18 起 `VIRTUAL` 為預設、不能建索引；補「一律顯式標註」規則 | PG 18 release notes |
| 8 | `ef-core` `query-performance.md:306` | 移除假限制，改為 `Include`/`ThenInclude` 有專屬 overload + EF9 起 `EF.Constant` 在 compiled query 內失效 | efcore#33674；overload moniker 覆蓋 5.0–10.0 |
| 9 | `mysql` `version-dba.md:52-54,65-66,69` + 新增 8.0 EOL 章節 + 目錄 | 9.7 從 Innovation 改列 LTS；5.7 Premier 日期 2023→**2020** 並刪杜撰的「Oracle changed the support policy」；補 8.0 已 EOL | endoflife.date：9.7 `lts=True` eol=2034-04-21；9.0–9.6 `lts=False`；8.0 eol=2026-04-30；5.7 eol=2023-10-31 |

**CONFLICT 處置**：#3（MySQL LTS）以 endoflife.date 獨立查證結案，9.7 確為 LTS；#1（TS 7）照彙整者解法補 peer 警語；#2（`aspnet-core-api.md:460` Swashbuckle 標題）**維持現狀**——兩個 agent 判反的是編輯政策不是技術事實，底下程式碼在 .NET 8 完全正確，為一個標題訂政策不划算。

**blast-radius 處置**：Zod 7 行一次改滿 ✅；`UseSerilog`→`AddSerilog` 6 處**整項不做**（父項屬第三梯，不做就沒有半套狀態）；`"baseUrl"` 第三處在 vendored 的 `tailwind-v4-shadcn:212` — **同樣是 TS 7 硬錯誤但只能回報**。

**驗收**：`count-words.sh` 超標集合與基準線相同的 7 個、無新增｜`lint-descriptions.sh` 0 個 TRAP/MISS/ERR｜vendored 6 個未被碰｜`agents-sync --check` lint PASS｜`conformance.sh` 14 PASS / 0 FAIL｜8 檔、+74/−41、6 個 skill、全在 `skills/`。

**未做（明確列出）**：第三梯 8 項過期指引（需先建拋棄式專案做編譯／安裝驗證，應獨立成任務）、`aspnet-core-api.md:460`、9 個仍不可解項（`02-unverifiable-convergence.json` 內附可執行指令）。

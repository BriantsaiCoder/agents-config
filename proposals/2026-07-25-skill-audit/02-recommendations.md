# 02 — 建議與執行批次

> 2026-07-25 · 對應 `00-mechanical-scan.md`（事實）與 `01-verdicts.md`（判決）
> **本檔只是提案，尚未執行任何變更。** 稽核的 25 個 agent 全程 0 次使用 Edit / Write / NotebookEdit。
>
> **並行編輯註記**：稽核期間（09:02:41）有一次外部編輯同時改動 `core/tier0-safety.md` 的 `[T0-8]`（放寬 plan gate）與 `skills/dev-workflow/SKILL.md` 的 S2/S3/BUGFIX/Copilot 段以對齊。兩檔 mtime 相同，屬同一事件，非稽核產物。本報告引用的所有行號已在編輯後重新複驗，**全部仍然正確**——包括 `dev-workflow/SKILL.md:136`（那次編輯動了 S2 相關段落，但沒修到這條 doc rot）。

## 一頁結論

**你的問題是「哪些與 Opus 5 內建知識重複、建議移除」。誠實的答案是：幾乎沒有值得移除的。**

不是因為那些 skill 內容不重複——`dotnet-winforms-best-practices`、`testing-library-react-best-practices`、`vue-debug-guides`、`vueuse-functions`、`security-review`、`nodejs-best-practices`、`typescript-best-practices` 的內容**確實 100% 落在 Opus 5 穩定知識內**。

而是因為**移除它們幾乎不省任何東西**：
- skill 的常駐成本只有 description 一行；這 7 個合計約 **3,300 字元 ≈ 900 token**
- 換來的是：四檔協調編輯、`agents-sync` lint 紅燈風險、休眠棧知識歸零、以及跨三家 host 的重跑驗證

**投入產出比不成立。** 建議把力氣放在下面三個批次——它們修的是**正確性 bug 與可達性缺陷**，不是體積。

> **範圍與數字的兩個限定**（完整假設見 `01-verdicts.md` §8）：
> 1. 本次只評估**個人 52 個 skill**；約 40+ 個 plugin skill 不列入移除候選（移除等於卸載 plugin），但已納入功能重疊判斷。
> 2. 因此 **21,748 字元 / 6–8k token 只是個人 skill 的常駐成本，不是總量**。plugin description 是同量級但未量測的另一塊。
>
> **Trim 的正當理由是內容「錯」（過期／矛盾／死連結／與 rules 牴觸），不是「大」或「重複」**——依此，21 個 Trim 中只有 16 個現在可執行，另 5 個實質等同 Keep（`01-verdicts.md` §6）。

---

## 決策點（需要你裁決，我不會自行決定）

> 前提：`01-verdicts.md` §3 已把驗證者偷渡的「第四軸」**明文定義並統一套用**——移除收益 ≈ (description 位元組) × (實測觸發碰撞)；碰撞為 0 才受保護。下列決策皆依此對齊，不再有「只對某些 skill 有利時才出現」的雙標。

### D1. `dotnet-winforms-best-practices` —— 已結案，不需你裁決

第四軸定義後**它確實受保護**：實測 0 個碰撞配對（不在 §F 15 對清單，description 特異性最高：`System.Windows.Forms Form/UserControl`、`Designer.cs`、`BindingSource/DataGridView`、`GDI+`、`high-DPI`）。刪除只省 ~130 token，收益實測為零。

**維持 Trim（實質 = Keep，見 `01-verdicts.md` §6 後 5 名單）。** 這不再是「你可覆寫」的模糊項。

### D2. Vue 家族要 5 個還是 4 個？ ← **這才是需要你裁決的**

第四軸**不保護 `vue-debug-guides`**：實測它與 `nuxt` 的 description **逐字共用 "hydration mismatch"**，且與 `vue-best-practices` 有 0.143 碰撞。而推翻它 Delete 的唯一依據是循環論證——「`vue-best-practices/SKILL.md:3` 的 description 指向我」，而那個指標存在的目的就是路由到 companion。

| 選項 | 動作 | 收益 | 代價 |
|---|---|---|---|
| **A（維持 5）** | 不動，只從 `nuxt` description 移除 "hydration mismatch" 消解碰撞 | 消掉 1 個實測碰撞，零風險 | 循環論證永久存在 |
| **B（收成 4）** | 把 `vue-debug-guides` 的 1 條（`:key` 反 cargo-cult 守則）併進 `vue-best-practices`，歸檔該 skill；同步從 `nuxt` 移除 "hydration mismatch" | 消 1 碰撞 + ~110 token | hub description 需吸收症狀觸發詞 → 變寬 |

**我的建議：A。** 理由不是「不能刪」，而是 B 的核心收益（消碰撞）A 也拿得到，而 B 額外付出的 hub 觸發面稀釋是純損失。`vueuse-functions` 不在此決策內——它的 Delete 是被**新事實**推翻的（gitleaks 抓不到 `useStorage` 的執行期資料流），不是論證。

### D3. `postgresql-optimization` —— Delete 判決成立，你決定的是**時機**不是**要不要**

第四軸不保護它：碰撞 0.250 是**全庫第 2 高**，且兩者 description 互寫免責條款 → 每個 PG 任務都付一次仲裁成本。三軸皆過、對抗驗證未推翻。**判決 = Delete。**

但前置條件的執行方（`postgresql-best-practices`）判 Keep 且其判決不知情，所以照現狀直接刪 = 資訊淨損失。

| 選項 | 動作 | 評估 |
|---|---|---|
| **A（現在執行）** | pg-bp 吸收 6 項（分割門檻／FTS 上限／jsonb_path_ops 量化表／BRIN pages_per_range／4 步 workflow／Validation Checklist）+ 修 2 處事實錯誤（`schema-design.md:63` UUIDv7 過時、`advanced-features.md` 分割表 unique constraint 措辭）→ 再歸檔 | 約 1 小時；判決正確地落地 |
| **B（延後）** | 只改兩者 description 的互指措辭消掉仲裁成本，skill 留著 | 拿到大部分收益，零風險 |

**我的建議：B，但明確標記為「成本考量下的延後」而非「判決被推翻」。** 理由：PostgreSQL 不是你目前的活躍 stack（主力是 MySQL），仲裁成本實際發生頻率低。等你下次真的動 PG 專案時再做 A。

---

## Batch A — 只做一批就做這批（零刪除風險、全機械可驗）

### A1. 修 doc rot（純 bug 修復，不需要任何 verdict 共識）

全部已由我實測覆核存在。專案 CLAUDE.md 明訂「doc rot 視同 bug」。

| 檔案:行 | 問題 | 實測 |
|---|---|---|
| `dev-workflow/SKILL.md:136` | 宣稱 Copilot hooks「現況未配置」 | ✗ `ls ~/.copilot/hooks/` → `guard-git-push.json` + `guard-git-push.sh` 皆存在；`[T0-3]` 亦載明已配置 |
| `native-feel/SKILL.md:21` | 寫「a 30-item audit」 | ✗ `checklists/ship-readiness.md` 實測 75 項（README 三處皆寫 75）。**agent 會在跑完 1/3 時宣稱完成** |
| `auth-implementation-patterns/SKILL.md:52` | 指向 `better-auth-best-practices` | ✗ 不存在（併進 :53 既有清單，勿單刪留斷臂） |
| `containerization/references/trigger-regression.md:1,3` | 指向 `dotnet-containerization` | ✗ 不存在；且該檔本是 skill-creator 的 eval fixture，非 runtime 可引用內容 → 連同 `SKILL.md:29` Reference Map 一起移除 |
| `testing-library-react/references/react.md:3` **與 :448** | 兩處指向 `tdd` skill | ✗ 不存在（原稽核只抓到 :3） |
| `next-best-practices/references/directives.md:71` | 指向 `next-cache-components` | ✗ 不存在 |
| `mp-tdd/SKILL.md:62` | `references/tests.md` 前綴錯誤 | ✗ `tests.md` 在根目錄；同行其餘四個 bare name 路徑正確 → **一字修正（拿掉 `references/`），不是刪檔** |
| `c-cpp/references/core-rules.md:33 (A6)` | 「CLAUDE.md mandates the blacklist」 | ✗ `strcpy`/blacklist 在 CLAUDE.md / core/ / rules/cpp.md 全 0 命中 → **只能刪不能重導** |
| `c-cpp/references/core-rules.md:75 (C2)` | 「CLAUDE.md mandates MSVC + MinGW」 | ✓ 內容為真但指錯檔 → 改指 `~/.agents/rules/cpp.md:16` |
| `init-project-docs/references/fallback-defaults.md` | 半孤兒 | `SKILL.md` 引用數 0，僅 `references/README.md` 引用 1 次 → 決定要接回 SKILL.md 還是移除 |

### A2. Routing 可達性一次修完（一個檔、一行編輯）

`core/routing.md` 目前 **15 行 / 上限 30**，預算充裕。把已確定 Keep 的非慣例命名 skill 補進第 9 行：

`native-feel-cross-platform-desktop`、`auditing-skill-folder`、`react-router-framework-mode`

**排序約束**：**不要**為處置未定者加名字——`postgresql-optimization`（待 D3）、`vue-debug-guides`、`vueuse-functions`、`nuxt`、`pinia`（待 D2），否則會 churn。

> 至少 8 份 cluster 報告各自獨立建議過「補進 routing 點名」，全被寫成各自的 follow-up——沒有人發現這是一次編輯就能做完的事。

### A3. 清點 `~/.codex/skills/`（本次稽核的範圍補洞）

比照 `attic/codex-legacy-skills/README.md` 的三段表格格式，清點 7 個項目：

- `agent-browser`：內容 drift（458 字 vs 3,285 字，md5 不同）→ 決定「刪本地副本」還是「同步」
- `architecture-html-doc`：與 `design-doc-mermaid` / `init-project-docs` / `acquire-codebase-knowledge` 三方碰撞 → 決定誰是正本
- `playwright`：與 `playwright-best-practices` 同語境
- `chronicle` / `codex-dynamic-workflows` / `pdf` / `security-ownership-map`：標「保留＋理由」

> 2026-07-08 的 F10 教訓說這層無人巡檢；這次稽核證實它**仍然**無人巡檢。

**A 批驗收**：`~/.agents/bin/agents-sync`（lint1 / lint1b / lint5 + skill-index 行數自檢）+ `~/.agents/tests/conformance.sh`

**前置**：`~/.agents` 目前有 10 個未 commit 修改 + 2 個 `.bak-20260718-1346` + 未追蹤的 `proposals/2026-07-17-*`。動手前先 commit 或 stash，否則 rollback 會混在一起。

---

## Batch B — Tailwind / CSS 正確性鏈（**這是 bug 不是整理**，順序不可打亂）

實測（已用 Context7 官方文件裁決）：

- `css-ui-best-practices/references/design-system-patterns.md` L30-70 教 **v3-era**：`:root` 放 `@layer base`、裸 HSL triplet（`--background: 0 0% 100%`）、`hsl(var(--background))`
- `tailwind-v4-shadcn/templates/index.css` 教 **v4**：頂層 `:root`、值自帶 `hsl(...)`、`@theme inline` 純 var 映射
- 兩套混用直接產出 `hsl(hsl(...))`，**整站顏色壞掉**
- `react-best-practices/SKILL.md:40-41` **同時指向兩者**

而 Split 的目的地 `tailwind-v4-shadcn` **自己內部就矛盾**：`rules/` 說裝 `tw-animate-css`，`references/common-gotchas.md:17` 說該套件在 v4 不存在（Context7 裁決：官方推薦，套件存在）。

**執行順序（不可打亂）**：

1. 修 `tailwind-v4-shadcn` 內部矛盾：改寫 `common-gotchas.md:17`；`rules/tailwind-v4-shadcn.md` 的「`@apply` deprecated」改為 `SKILL.md:27` 的準確措辭；刪 `.claude-plugin/plugin.json`（第三方殘留）
2. **修完之後**才處理 `rules/` 子目錄的去留（全庫僅此一例的型別誤置；未修前絕不可搬去 `~/.agents/rules/`，否則錯誤升級為 path-triggered 常駐）
3. 移除 `css-ui-best-practices/references/{tailwind,design-system-patterns}.md`（v3-era，與官方牴觸）
4. 改 `react-best-practices/SKILL.md:40-41` 的雙指向

---

## Batch C — 需要你決策後才能排（見上方 D1–D3）

外加一項制度修補：

**把「零收益即負期望值」明文寫進 `auditing-skill-folder` 當第四軸並定義判準**（例如「description 與其他 skill 的觸發詞交集 ≥ N，或有實測誤觸發紀錄」），**或明文拒絕它**。

現狀是它只在對某些 skill 有利時出現——這會讓下一輪稽核重演同一個 uniform-keep。

---

## 附：實測到的 description 真碰撞（移除的真正收益所在）

| 碰撞 | 證據 | 建議 |
|---|---|---|
| `nuxt` ∩ `vue-debug-guides` | 兩者 description **都含逐字 "hydration mismatch"** | 從 `nuxt` 移除該詞（Nuxt 的 hydration 問題應由 vue-debug-guides 接） |
| `security-audit` ∩ `security-review` | routing 用 8 個字區分「整庫稽核 vs PR 級」，但 `security-review/references/workflow.md:8` 寫「If no path given, scan the entire project」→ **分岔依據是虛構的** | 改 workflow.md:8 為 diff 尺度，兩者才真正分工 |
| `postgresql-best-practices` ∩ `postgresql-optimization` | 雙向互寫免責條款，每個 PG 任務付一次仲裁 | 見 D3 |
| `css-ui-best-practices` → `tailwind-v4-shadcn` | css-ui description 寫「For Tailwind v4 + shadcn tokens see tailwind-v4-shadcn」，卻自帶兩份完整且過期的 Tailwind 教材 | Batch B |

## 附：跨 skill 重複知識點（未被系統性掃描的維度）

實測樣本，非缺陷但值得列為下輪掃描維度：

- `Dockerfile` 出現在 **9 個 skill**：acquire-codebase-knowledge、backend-release-verification、containerization、dependency-security-scan、design-doc-mermaid、init-project-docs、next-best-practices、nodejs-best-practices、security-review
- `getByRole` 出現在 `playwright-best-practices` + `testing-library-react-best-practices`，兩者的 selector 優先序**又各自與 `rules/testing.md` 重複**（三份）
- `vi.mock` 出現在 nodejs / react / vitest
- `AsNoTracking` 出現在 ef-core / ef6 / init-project-docs

已被抓到且**已證實互相矛盾**的兩組：Tailwind token（css-ui × tailwind-v4-shadcn）、deep-modules 定義（mp-tdd × mp-improve）。

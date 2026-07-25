# 01 — 52 個 skill 的逐檔判決

> 2026-07-25 · 依 `auditing-skill-folder` 六步協定（step1/2 見 `00-mechanical-scan.md`）
> 方法：12 個評估 agent 各實讀 3–5 份 SKILL.md → 12 個對抗驗證 agent 逐條嘗試推翻非 Keep 判決 → 1 個完整性批判 agent。共 25 agent、402 次工具調用、2.33M token。
> 原始資料：`_raw-verdicts.json`（含每檔完整 step3–6 觀察）

## 判決總表

| 判決 | 數量 | 意義 |
|---|---|---|
| **Keep** | 29 | 不動 |
| **Trim** | 21 | 保留 skill，刪/修其 references 或部分段落 |
| **Split** | 1 | 內容拆給別的 skill |
| **Delete** | 1 | 整個移除（且附前置條件） |

初評 6 個 Delete，對抗驗證後**只剩 1 個**。

---

## ⚠️ 判決可信度的自我揭露（先讀這段）

**本次驗證是單向棘輪。** 35 個被複審的判決中，17 個被軟化（5× Delete→Trim、12× Trim/Move→Keep），**0 個被硬化**。

原因有二，都是我造成的：

1. **我在驗證 prompt 裡明寫「不確定時預設 refuted=true（保守偏向保留）」** —— 這直接製造了保留偏誤。
2. **驗證者引入了一條協定裡沒有的第四軸**：「三軸即使全過，若刪除收益 ≈ 0，Delete 仍是負期望值操作」（用於推翻 `dotnet-winforms-best-practices`），而且只在對某些 skill 有利時出現。

`auditing-skill-folder` 的 description 自述它存在的理由正是「when a prior audit kept everything (suspicious uniform-keep)」。**這次用另一條路徑重建了 uniform-keep**，必須誠實標出來。

### 處置：採納第四軸，但給它可證偽的定義並統一套用

那條論證本身是對的——§1.1 的成本量測正是它成立的依據。它的問題不是內容錯，是**沒定義、沒統一套**。定義如下：

> **第四軸（移除收益）**：Delete 的收益 ≈ (description 位元組) × (實測觸發碰撞)。
> 三軸全過但**實測碰撞為 0**（不在 `00-mechanical-scan.md` §F 的 15 對清單、且無逐字共用觸發詞）且 description < 500 bytes → 收益 ≈ 0，Delete 為負期望值，降級 Trim/Keep。
> **反之，有實測碰撞者，第四軸不保護它。**

統一套用到 3 個受此論證影響的 skill（碰撞數據來自 §F，非事後編造）：

| Skill | 實測碰撞 | 第四軸判定 |
|---|---|---|
| `postgresql-optimization` | **0.250 與 `postgresql-best-practices`——全庫第 2 高**，且兩者 description 互寫免責條款 → 每個 PG 任務付一次仲裁成本 | **不保護 → Delete 成立** |
| `dotnet-winforms-best-practices` | **0 對**（不在 15 對清單，description 特異性極高） | **保護成立 → 降級正當** |
| `vue-debug-guides` | **0.143 與 `vue-best-practices`；且與 `nuxt` 的 description 逐字共用 "hydration mismatch"** | **不保護** → 唯一保護它的只剩循環論證（§3） |

→ 結論：第四軸讓 `dotnet-winforms` 的降級站得住，但**不能**用來保 `postgresql-optimization` 或 `vue-debug-guides`。§3 與 §6 已依此對齊。

---

## 1. 為什麼「與 Opus 5 內建知識重複 → 移除」這條路幾乎走不通

三個結構性理由，順序即重要性：

### 1.1 成本帳算錯了（最關鍵）

skill 的**常駐成本只有 description 一行**，body 與 references 是 invoke 當下才載入。
- 52 條 description 合計 **21,748 字元**（≈6–8k token）
- 刪掉 `ecpay`（body 5,637 字 + 294 個檔）省的是 **~120 token**，不是 5,637 字

唯一確定可移除的 `postgresql-optimization`（description 412 bytes）= 削減 **1.9%** 的常駐成本。

**→ 「內容重複」不是有效的移除理由，因為重複的內容根本沒有常駐成本。** 移除的真正收益只有觸發精準度。

### 1.2 觸發精準度的改善空間本來就很小

52 條 description 兩兩比對，Jaccard ≥ 0.10 者僅 **15 對**，且高重疊配對皆為刻意相鄰的姊妹 skill，多數 description 內已互寫免責條款（如 `postgresql-best-practices` 明寫「深度效能調校用 postgresql-optimization」）。

實測到的**真碰撞**只有 4 處，列在 `02-recommendations.md`。

### 1.3 `*-best-practices` 受兩條 MUST 保護

雖然全部 0 個硬引用，但：
- `core/routing.md:8`：「stack 實作 → 同名 `*-best-practices`」
- `dev-workflow/SKILL.md:80`（S3 IMPLEMENT）：「stack **`*-best-practices` skill MUST 套**」

刪掉任一個 = 該 stack 的 canonical workflow S3 出現無法滿足的 MUST 條款。

---

## 2. 逐檔判決表（六步協定完整評分）

step1（字數）與 step2（description trap）見 `00-mechanical-scan.md`；step3–6 逐檔如下。每格為節錄，完整觀察與「唯一不可取代內容」欄在 `_raw-verdicts.json`。

| Skill | 判決 | 信心 | step3 立場滲漏 | step4 可機械化 | step5 型別 | step6 內建覆蓋 |
|---|---|---|---|---|---|---|
| `postgresql-optimization` | **Delete** | medium | 幾乎無立場滲漏。全篇是技術判準：jsonb_path_ops vs gin_jsonb_ops 的運算子/大小/建置速度對照（~3× 小、~3×… | 僅 3 條 anti-pattern 理論上可 regex 抓：`OFFSET <大數字>`、`::text LIKE '%'`、`… | Mixed，而且這裡的混型別是缺陷不是分層。SKILL.md 同時扛 Technique… | 內建覆蓋高：EXPLAIN (ANALYZE, BUFFERS) 判讀、GIN/GiST/BRIN 選擇、tsvector+GIN、jsonb_path_ops、keyset… |
| `css-ui-best-practices` | **Split** | high | **立場滲漏最嚴重的一個，且作者自承**——SKILL.md 第 8 行原文：「User-stance rules for 2026 CSS /… | **五個裡最該機械化的**，且既有生態工具已 100% 覆蓋主要條目：`No !important` → stylelint `de… | Mixed 且與 tailwind-v4-shadcn 重疊，是 Split 訊號最強的… | 覆蓋度高。**全部屬 Opus 5 穩定知識**：semantic HTML、WCAG 2.2 AA 條目、focus-visible、`<dialog>` / `role="… |
| `auth-implementation-patterns` | **Trim** | high | 有明確立場滲漏，且是三重複述。SKILL.md L57「CLAUDE.md default: JWT in httpOnly cookie, p… | 主體不可機械化：雙層授權、租戶邊界要驗在 repository 層而非 controller 層、refresh rotation… | Pattern 為主且很純。SKILL.md 幾乎全是判準：情境→token 型別→儲存… | 多數是模型穩定知識（PKCE、alg:none、RS256 與 HS256 混淆、Argon2id）。但有兩處屬「知道 ≠ 會照順序做」：jwt.md 明列驗證次序（先 alg… |
| `c-cpp-best-practices` | **Trim** | high | 立場集中在 core-rules.md Part C/D，且與 ~/.agents/rules/cpp.md 逐項重複：C1「Min CMake… | 嚴重度表的 Critical/High 幾乎全可機械化，且 skill 自己就寫出了 check 名稱：A6 strcpy/spri… | Mixed 但已用檔案切分。SKILL.md ＝ Technique（4 步 workf… | Part A/B 皆為 Opus 5 穩定核心知識（ownership 命名、errno vs 回傳碼、goto cleanup、extern "C" + opaque han… |
| `containerization` | **Trim** | high | 輕度立場但性質良性：generic.md 的 Defaults 段（優先 slim/runtime/distroless、tag 至少 pin… | 檢查清單有三條可 100% 機械化：.dockerignore 是否排除 .git/.env*/node_modules/__pyc… | Mixed 且混得不乾淨。SKILL.md 與 generic.md 是乾淨的 Tech… | 分兩半，結論是部分不覆蓋、而不覆蓋的那半正是使用者用得到的那半。Linux/.NET Core、Node、Python、Go 多階段那半全屬模型穩定知識，Opus 5 加 Co… |
| `design-doc-mermaid` | **Trim** | high | 立場滲漏以「反向」形式發生，這是本組最嚴重的發現：skill 強制的產物形狀與使用者立場相反。SKILL.md:143 標 CRITICAL 的… | 幾乎全機械化但目前 0 守護。「每個 classDef 必須有 color: 屬性」「diagram 進 markdown 前必須通… | Mixed，且是嚴重混型別。SKILL.md 本體同時塞 Technique（Resil… | 內建覆蓋高，且有三重外部覆蓋。(a) Opus 5 寫 mermaid flowchart / sequence / architecture 語法屬穩定知識；(b) 本 ho… |
| `dev-workflow` | **Trim** | high | 整體是流程紀律（procedure）不是純立場，但有三處確實滲漏：(1) S6 第 3 點『zh-TW Conventional Commit、… | 不可機械化替代——S0 決策表與 S1–S6 是判斷型流程。但內含三個可疊加機械守護的點：(a) S3『動高扇入共用檔前 MUST… | Mixed，但已部分正確切分。主體 S0–S6 + BUGFIX 鏈 = Techniq… | 完全未被覆蓋。Opus 5 知道泛用的 plan→implement→test→review 流程，Context7 / microsoft-learn 完全不涵蓋個人 wor… |
| `dotnet-testing-best-practices` | **Trim** | high | 有兩處立場滲漏，皆應移出。(1) 規則 2「Name `Method_Scenario_ExpectedResult`」與 ~/.agents/… | 部分可機械化，但不宜整體 Convert-to-hook——可機械化的三條恰好就是 Trim 要刪/搬的內容。可 100% 強制者：… | Mixed，但 Trim 後即收斂，不需 split。SKILL.md（441 字）=… | 大部分屬模型穩定知識（AAA、Theory/InlineData、mock 邊界、覆蓋率取捨），Opus 5 無需提示即可正確產出；microsoft-learn MCP 覆蓋… |
| `dotnet-winforms-best-practices` | **Trim** | medium | 無立場滲漏——但那正是因為使用者的 WinForms 立場「已經」抽到 ~/.agents/rules/winforms.md（MUST UI… | 12 條中 3 條可 100% 機械強制，且價值高於 skill 本身：R3（禁手改 `.Designer.cs`）＝ PreToo… | Mixed（因判 Delete 不建議 split）。SKILL.md（493 字，逼近… | 全部內容皆屬模型穩定知識，無任何 2026-05 cutoff 之後或冷門項目。Control.Invoke/BeginInvoke 語意、GDI+ 句柄洩漏與 10k 上限、… |
| `mp-tdd` | **Trim** | high | 立場滲漏輕微且分散。SKILL.md 幾乎純方法紀律，無版本 pin、無 stack 立場。有立場味的兩處都在衛星檔：references/tr… | 不可機械化。「one test → one impl，never two ahead」理論上可從 commit 粒度側面推斷，但實務… | Mixed 且是四者中唯一真正該處理的。SKILL.md（Technique：verti… | 分層看：SKILL.md 本體未被覆蓋——tracer bullet 概念（Pragmatic Programmer）Opus 5 當然知道，但「把 horizontal sl… |
| `native-feel-cross-platform-desktop` | **Trim** | high | 無使用者立場滲漏——這是 vendored 第三方 skill（LICENSE: MIT, Copyright (c) 2026 yetone；… | 幾乎完全不可機械化。checklists/ship-readiness.md 實測 75 項全是人工觀察或計時判定：「hotkey… | Mixed，但是四者中檔案切分最乾淨的，型別已按檔對齊：01-philosophy（Pa… | 這是四者中唯一內建覆蓋明確不足者。具體超出 Opus 5 的內容：(1) 03-webview-survival A.1 的 window.setValue(false, fo… |
| `next-best-practices` | **Trim** | medium | 立場滲漏集中在單一檔案，界線很乾淨。references/project-init.md（347 字）幾乎整檔是立場：create-next-a… | 三處可機械化：(1) tsconfig 的 strict / noUncheckedIndexedAccess / verbatim… | Mixed，且是本組混得最明顯的。SKILL.md 本體是純索引（20 行 Refere… | 內建覆蓋高，但有兩個冷門殘值。屬模型穩定知識的：Next 15 的 async params / searchParams / cookies() / headers()（20… |
| `nodejs-best-practices` | **Trim** | high | 純立場句密集且無 rules 家可歸：Golden Rule 1「Structure by feature, not technical rol… | 可 100% 機械化者：Rule 2「never empty catch {}」→ eslint no-empty；Rule 7「n… | Mixed。SKILL.md 本身混三型：Technique（Mode: Writing… | 全部技術內容皆屬 Opus 5 穩定核心知識，無 2026-05 cutoff 後或冷門項：Express 4/5 error-middleware arity、asyncHa… |
| `nuxt` | **Trim** | high | 立場滲漏近乎為零，分層是本叢集最乾淨的。採用門檻的立場（「SSR / SEO 才升 Next.js（App Router）/ Nuxt 3」）正… | 幾乎不可機械化。SKILL.md:31「useFetch / useAsyncData MUST be at <script set… | Mixed，且 Reference 層嚴重肥大。SKILL.md = Technique… | Nuxt 3 核心屬模型穩定知識（Nuxt 3 GA 於 2022-11，Nuxt 4 於 2025-07 發布，皆在 2026-05 cutoff 內），Context7 的… |
| `pinia` | **Trim** | high | 立場滲漏極輕，且與 rules 分工正確。全篇只有一條判斷性立場：SKILL.md:14「Keep server state out of Pi… | 大部分不可機械化。唯一有 lint 潛力的是「解構 state/getters 必須用 storeToRefs」（SKILL.md:… | Mixed，但分層良好且可清楚切割。SKILL.md = Technique（:11-1… | 多數覆蓋，但有一個真實的超出內建點。屬模型穩定知識、應交回 Context7 vuejs/pinia 的：defineStore setup vs option 語法、stor… |
| `react-best-practices` | **Trim** | high | 立場滲漏明確。Golden Rules 第 9/10/11/14 條是純使用者/團隊立場，不是 React 技術事實：#9「新專案不用 runt… | 部分可機械化，且是可 100% 強制的那幾條：#2 useEffect deps 完整 = eslint-plugin-react-… | Mixed。SKILL.md = Pattern（14 條 golden rules c… | 內建覆蓋高，全部內容皆屬模型穩定知識。function component + hooks、useEffect 依賴與 stale closure、key 不用 index、m… |
| `security-review` | **Trim** | medium | 零使用者立場。全文英文、無 zh-TW、未引用任何 tier0 條號或 rules 檔、無專案慣例。唯一具決策性質的是嚴重度表（L32–38）與… | 大部分已經被機械化，而且不是被本 skill。security-guidance plugin 的 hooks.json 掛 Pos… | Mixed 且混得不乾淨：SKILL.md 是 Technique（8 步），refer… | 內容全屬模型穩定知識，無一項在 2026-05 cutoff 之後：SQLi/XSS/command injection/SSRF/IDOR/JWT alg:none/CSRF… |
| `tailwind-v4-shadcn` | **Trim** | high | 立場滲漏低，但存在**型別誤置的整份 rules 檔**。SKILL.md 本體幾乎全是技術硬規則（`@theme inline` 映射、`:r… | **可機械化比例最高，且驗證條件全部是可判定的字串/結構條件**：`components.json` 的 `tailwind.con… | Mixed，四種型別同居一個目錄。SKILL.md = Technique（Requir… | **五個裡內建覆蓋最不足的，保留價值最高**。Tailwind v4 的 `@theme inline` + shadcn/ui 新 CLI 的 CSS variable 架構… |
| `testing-library-react-best-practices` | **Trim** | medium | 無使用者專屬立場，這是判 Delete 的關鍵。Query Priority（getByRole → getByLabelText → getB… | 本組最強的機械化候選，Review Checklist 前四項幾乎逐條對應 eslint-plugin-testing-librar… | Mixed 但輕量（SKILL.md 383 字 + references/react.… | 全部內容皆屬模型極穩定知識，找不到任何冷門或 cutoff 後條目。RTL 的 query priority、userEvent.setup() 搭 await user.*、… |
| `typescript-best-practices` | **Trim** | high | 純立場句：Rule 8「satisfies over as const + type annotation」、Rule 11「Avoid enu… | 12 條裡至少 6 條 100% 可 lint 強制，且 skill 自己在 config-and-project.md:309 就… | Mixed，且混得最嚴重處正好是可刪處。references/type-system-f… | 全部技術內容皆屬模型穩定知識，無 cutoff 後項目：satisfies（TS 4.9）、verbatimModuleSyntax（TS 5.0）、const type pa… |
| `vue-best-practices` | **Trim** | high | 立場滲漏嚴重且已與 rules 重複。Golden Rule 12（SKILL.md:30）在 references/rules-expande… | 部分可機械化，但不建議轉 hook。Rule 8（v-for 必須 stable key、禁 index）、Rule 9（禁 v-i… | Mixed（三型混雜）。SKILL.md 本身 = Pattern（14 條判斷準則）+… | 全部內容皆屬模型穩定知識，無任何 2026-05 cutoff 後或冷門項。<script setup> 自 Vue 3.2（2021-08）穩定，defineModel 自… |
| `vue-debug-guides` | **Trim** | medium | 無使用者立場滲漏 — 全文 599 字（SKILL 389 + INDEX 210）沒有任何選型偏好、版本 pin 或團隊慣例，不需要搬去 ru… | 完全不可機械化。全部是症狀→根因的推理映射（「ref 沒更新 → 檢查 reactive 解構 / 漏 .value / shall… | Technique 為主（SKILL.md:11-16 的 5 步 how-to-use… | 全部內容皆屬模型穩定知識，無一項在 2026-05 cutoff 後或屬冷門。列舉的症狀（reactive 解構失效、hydration mismatch 來自 Date.no… |
| `vueuse-functions` | **Trim** | high | 有兩條立場句，但**兩條都已是全域常駐硬規則的重複**，移除後零損失：SKILL.md:23「Never persist tokens / PI… | 不可機械化，但也不需要 — 唯一可機械化的那條（storage 存 token/PII）已由 [T0-4] 的 gitleaks +… | 名義上是 Reference（分類 → 函式名的查表），但**這是一個刻意不含 refe… | 完全覆蓋，且 skill 自己承認。VueUse 自 2021 穩定，列出的 41 個函式（useStorage / useEventListener / onClickOut… |
| `acquire-codebase-knowledge` | **Keep** | high | 立場含量低，且僅有的立場屬「輸出契約」而非「團隊偏好」，不適合外搬：Output Contract 固定產物為 docs/codebase/ 七… | 不可機械化。已機械化的部分本來就外包給 scripts/scan.py（Phase 1 掃描）；「七檔是否存在」理論上可寫成 tes… | Mixed，屬「Technique 主體 + 外掛資產」的健康型：SKILL.md 純… | 「讀 repo 寫文件」本身完全在 Opus 5 能力內，Context7 也不需要。超出內建的是流程紀律與契約：七檔固定命名、evidence-per-claim、[ASK… |
| `agent-browser` | **Keep** | high | skill 內文**沒有**使用者立場句——全篇是上游 CLI 的操作說明（install.sh 寫入 $GITHUB_ENV，證實是 vend… | 該機械化的部分**已經機械化且已落地**：frontmatter `allowed-tools: Bash(agent-browse… | Mixed。Technique = core loop（open→snapshot -i… | **不覆蓋**。agent-browser 是冷門 CLI，其指令面與 Playwright/Puppeteer 完全不同（accessibility-tree snapsho… |
| `auditing-skill-folder` | **Keep** | high | **無使用者專屬技術立場**（不含 Serilog/barrel/版本 pin 這類內容）。skill 內的「立場」全部是稽核方法論本身：「St… | **已機械化的部分已正確落地**：step1 = scripts/count-words.sh（依 skill 名套 150/200… | Mixed 但**分層正確、不需 split**。SKILL.md（492 字，恰在 5… | **完全不覆蓋，且屬第 3 類永不可 Delete（workflow discipline）**。理由具體：(1) 六步協定的順序約束（step6『內建覆蓋』必須最後判、跳過… |
| `backend-release-verification` | **Keep** | high | 立場滲漏 = 使用者的發布政策，且與流程綁死不宜外搬：Minimum Gate Map 九列裡「Artifact 必須可追溯到 SHA / ve… | 不可全機械。可機械化的只是子集且屬 repo CI 層：artifact digest 比對、`curl --fail /healt… | 型別純度佳：Technique（4 步 workflow）+ Pattern（風險分類表… | 多數屬模型穩定知識——Pact / Schemathesis / k6 / staging smoke / SBOM / OpenTelemetry 概念 Opus 5 全會，… |
| `bug-fix-settlement` | **Keep** | high | 整體是決策程序不是純立場，但有兩處偏立場：(1)『寫入過多會讓 cookbook 腐爛、沒人讀。寧缺勿濫。』是知識管理偏好——不過它緊貼三問判準… | 三問判準與沉澱內容的判定完全不可機械化（要判斷「這知識機械工具抓不抓得到」本身就是判斷）。但 Step 3 的**強制性**是可機械… | 型別相當純：Technique（Step 1 評估 → Step 2 寫入 → Step… | 未被覆蓋。Opus 5 具備泛用的「事後回顧」概念，但本檔全部是使用者專屬的知識管理架構：三個沉澱目標的具體落點與檔名慣例（docs/cookbook/business-rul… |
| `dapper-best-practices` | **Keep** | high | 12 條規則每條都附技術性 *Why*（SQLi 防禦、plan cache、pool 歸還、threadpool 飢餓），無純團隊偏好句，無需… | 不可 100% 機械化，不轉 hook。規則 1（參數化）看似 regex 可攔，但 DCT 本身有合法的 identifier g… | Mixed，但屬刻意的 hub-and-spoke 漸進揭露，不建議 split。SKI… | 部分覆蓋但不足以刪。Opus 5 對 Dapper 基本 API（QueryAsync / Execute / DynamicParameters / splitOn）是穩定知… |
| `dependency-security-scan` | **Keep** | high | 有立場，但屬「可驗證的作業政策」而非散漫偏好：L10「Secret leakage is non-downgradable — any posi… | 一半已是 hook（使用者確有 gitleaks pre-push），但本 skill 負責的是另一半、且那半不可機械化：選哪個工具… | 型別分離乾淨的 Technique：SKILL.md = 流程（新專案 setup /… | 大方向 Opus 5 知道，但兩處會漏或答錯：(1) tool-matrix.md 明列 `dotnet list package --vulnerable --include… |
| `deps-check` | **Keep** | high | 立場滲漏極少。「依賴數 0/1-3/4+ → 策略」表面上是使用者選的閾值，但它是判斷準則（Pattern）而非偏好宣告，屬 skill 正當內… | 這是本組最強的 Convert-to-hook 候選，但只能部分轉：Step 1（跑腳本列依賴方）是 100% 機械，SKILL.m… | Mixed 但結構良好且份量小（346 字）：Step 1–5 = Technique；… | 部分被內建覆蓋但不足以刪。Opus 5 當然會 grep 找 caller，Context7 也不涉及。真正超出內建的是：(a) 這支腳本本身（madge 偵測 + 專案根定位… |
| `dotnet-core-best-practices` | **Keep** | high | 有兩處立場滲漏，一處是孤兒立場。(1) SKILL.md Rule 5「Controller-based Web API default; Mi… | 12 條中僅 3 條可 100% 機械化：new HttpClient()（regex 可抓）、ASP.NET 內 Console.… | Mixed，但分層正確不需 Split。SKILL.md = Pattern（12 ru… | 多數是 Opus 5 穩定知識（DI 生命週期、middleware 順序、IHttpClientFactory socket exhaustion），但有具體超出/易糊項：.… |
| `dotnet-framework-best-practices` | **Keep** | medium | 本體幾乎零立場滲漏——12 條全帶技術理由：R3 是 ASP.NET SynchronizationContext 會把 continuatio… | 可 100% 機械化的只有 3 條：R3 .Result/.Wait()（regex 可抓，但須排除 Main 與同步入口，會有 f… | Mixed。SKILL.md = Pattern（12 rules + 嚴重度排序）；r… | MVC5 / Web API 2 / OWIN 主幹屬 Opus 5 穩定知識，但有一批明確冷門到會答錯的項目：aspnet_regiis -pe 加密 config sect… |
| `dotnet-logging-best-practices` | **Keep** | high | 有選型立場與紅線重複兩類滲漏。R8「Serilog on .NET 6+」與 R9「NLog on .NET Framework — XML c… | 12 條中有 3 條已有現成 SDK analyzer，正解是啟用而非新寫 hook：R1（插值/串接 vs message tem… | Mixed，且兩支 reference 服務不同生命週期的棧，值得標記：nlog-log… | message template、log level 語意、[LoggerMessage] source generator、correlation ID 皆為 Opus 5… |
| `ecpay` | **Keep** | high | 沒有「使用者立場」滲漏，但有更嚴重的反向問題——**廠商立場滲漏且宣稱凌駕使用者設定**。SKILL.md L33-35 的 CRITICAL… | 可 100% regex 強制的只有「產出程式碼的內容檢查」而非 repo 檔案層規則：(1) CheckMacValue 比對禁用… | Mixed，且是本組混得最嚴重的一個。SKILL.md 同時塞了：Pattern（6 棵… | **明確超出 Opus 5 + Context7 覆蓋**，第 1 軸 FAIL。具體超出項：(a) ECPG 雙 Domain 分流——Token/CreatePayment… |
| `ef-core-best-practices` | **Keep** | high | 純立場句 3 條半：Rule 7「No Database.Migrate() at startup」、Rule 10「Fluent API fo… | 部分可機械化，主體不可。可 100% 強制的兩條：(a)『Program.cs 出現 Database.Migrate()』→ 一條… | Mixed，但已被 progressive disclosure 吸收，不需 split… | 內建覆蓋高。12 條 Golden Rules 全屬 Opus 5 穩定知識（DbContext 非 thread-safe、N+1、tracking 開銷 20–35%），且… |
| `ef6-best-practices` | **Keep** | medium | 立場滲漏輕微，僅 2 條：Rule 2「Disable lazy loading unless explicitly required」（EF6… | 僅 1 條可 100% 機械強制：『引用 System.Data.Entity 的檔案裡出現 .ThenInclude(』→ 該 A… | Mixed，分層已做。SKILL.md＝Pattern（12 Golden Rules… | EF6 是凍結的 legacy stack，Opus 5 訓練資料涵蓋充分，microsoft-learn MCP 也有 EF6 文件 → 大部分內容內建可覆蓋。明確超出/易錯… |
| `frontend-release-verification` | **Keep** | high | 立場滲漏集中在 references/deployment-gates.md（460 字），且全是使用者選定的數值：RWD viewport「m… | 半機械，但不該轉 host hook。可 100% 機械化的是門檻本身——size-limit/bundlewatch 設定檔、.l… | Mixed 但屬健康的 progressive disclosure：SKILL.md… | 部分超出內建。屬模型穩定知識的：Playwright/Vitest 用法、Core Web Vitals 以 INP 取代 FID（2024 既成事實）、axe/Lightho… |
| `init-project-docs` | **Keep** | high | 立場分兩類，要分開處理。(a) 該留在 skill 的政策型立場：Operating Rules 的「Merge, never overwrit… | 部分可機械化，但機械化的正確落點是 conformance 測試不是 hook。Validation 段有三條純 regex/par… | Mixed 且本體已超載：SKILL.md 是 Technique（Phase 0→7）… | 明確超出內建，且是本組唯一「模型鐵定會答錯」的一份。references/host-matrix.md 記錄的是三 host 原生介面細節：Copilot CLI hooks… |
| `jest-best-practices` | **Keep** | medium | 立場滲漏明確且是本 skill 的骨幹之一，共 3 條純立場：(1) SKILL.md 第 8 行「Project-owned runner.… | 少量可機械化：「coverage 排除 generated / build / `*.d.ts` / utilities」可對 je… | 五個裡型別最純的。SKILL.md = Technique（Setup Triage 讀… | 覆蓋度高但非全覆蓋。**完全覆蓋**：jest.config 欄位、testEnvironment、moduleNameMapper、ts-jest vs Babel 取捨、s… |
| `mp-diagnose` | **Keep** | high | 立場滲漏極低。全文是程序紀律不是偏好：Phase 1–6、3–5 條可證偽假設、one variable at a time 都是方法而非「使用… | 多數不可機械化：「先建 feedback loop 才准動手」「3–5 條排序假設」是判斷，lint 測不到。但有一條 100% 可… | Technique 為主（六階段流程），references/feedback-loop… | 未被覆蓋。與 `superpowers:systematic-debugging` 逐段比對後，mp-diagnose 有四塊是 plugin 與 Opus 5 預設行為都沒有… |
| `mp-grill-with-docs` | **Keep** | high | 有真立場，但位置正確。純立場成分有二：(a) 檔案佈局（root `CONTEXT.md` + `docs/adr/`，多 context 用… | 完全不可機械化。「一次問一個問題、等回饋再繼續」「術語衝突當場擋下」「CONTEXT.md 當場更新不批次」都是對話行為，沒有 li… | Technique（訪談迴圈）+ Pattern（ADR 三閘是判斷準則）為主，Refe… | 部分覆蓋但關鍵處未覆蓋。Opus 5 當然知道 ADR（Nygard）與 ubiquitous language（DDD），這部分是穩定知識。未覆蓋的是「反順從紀律」：模型預設… |
| `mp-improve-codebase-architecture` | **Keep** | high | 立場濃度最高的一個，但不應 Move-to-rules。LANGUAGE.md 有明確的個人決策：「Rejected framings — De… | 不可機械化。「deletion test（心裡刪掉這個 module，複雜度消失還是在 N 個 caller 重現）」「一個 ada… | Mixed，但已用檔案切分處理完畢：SKILL.md = Technique（Explo… | 部分覆蓋。Ousterhout 的 deep module、Feathers 的 seam、Ports & Adapters 都是 Opus 5 穩定知識，這些概念本身不需要… |
| `mp-zoom-out` | **Keep** | medium | 五句話裡有一句是純立場/路徑 pin：『Use the project's domain glossary vocabulary (CONTEX… | 完全不可機械化——它就是一段 prompt，沒有任何可 lint / regex / hook 檢查的產物或條件。不適合轉 hook… | Technique，但薄到接近退化——它沒有步驟序、沒有 ENTER/EXIT、沒有判斷… | 這是本組唯一第 1 軸成立的：三個 bullet 100% 屬 Opus 5 穩定知識——任何模型被要求「進入陌生 code 前先做 system map」都會自然產出模組職責… |
| `mysql-best-practices` | **Keep** | high | 立場句 3 條：Rule 8「MySqlConnector (.NET); mysql2 (Node)」＝明確 driver 選型立場（附技術理… | 可 100% 機械強制的 2 條：(a)『using MySql.Data』或 csproj 引用 MySql.Data 套件 →… | Mixed 且分層乾淨。SKILL.md（377 字）＝Pattern（12 判準 +… | 本組外部查詢管道最弱的一個：microsoft-learn MCP 完全不涵蓋 MySQL，Context7 對 MySQL server（非 library）的文件覆蓋遠不如… |
| `playwright-best-practices` | **Keep** | high | **有立場滲漏，且與 ~/.agents/rules/testing.md 逐條重複、rules 版更精確**。具體對照：(a) SKILL.m… | 部分可機械化但目前無觸發面。可 lint 強制者：`waitForTimeout` 禁用（eslint-plugin-playwri… | 型別分層乾淨，**不需 split**。SKILL.md 374 字（低於 500 上限… | **大部分屬 Opus 5 穩定知識 + Context7 有官方文件**：auto-waiting 模型、web-first assertion（toBeVisible/to… |
| `postgresql-best-practices` | **Keep** | high | 純立場句僅 1 條：Rule 9 的 pooling 策略（Npgsql 內建 multiplexing vs Node/多服務用 PgBoun… | 可機械化：migration DDL 出現 `timestamp without time zone` / 裸 `timestamp… | Mixed 且分層乾淨。SKILL.md（424 字）＝Pattern（12 判準 +… | 多數屬 Opus 5 穩定知識，Context7 對 PG 官方文件覆蓋尚可。明確超出/冷門的 3 處：(a) Npgsql 6+ DateTime/timestamp 對應的… |
| `react-router-framework-mode` | **Keep** | medium | 立場滲漏極少，是本組最乾淨的。『Global UI 放 root.tsx，不要另開 layout 檔』『search form 用 <Form… | 基本不可機械化。middleware 需 react-router >= 7.9.0 且 react-router.config.t… | Reference 為主，型別偏純。12 個 references 檔（共 ~9600… | 本組唯一有實質反幻覺價值者，但只集中在約 10% 內容。超出穩定內建知識的具體條目：(1) middleware 需 7.9.0+ 且必須在 react-router.conf… |
| `sdd` | **Keep** | high | 「開發紀律」四條是純立場滲漏：『一次只做一個需求』『不要自己加沒被要求的功能，也不要過度設計（遵守 ponytail / Push back 精… | 不宜轉 hook，但階段三（選用歸檔）是 100% 機械流程：檢查 tasks.md 全為 `- [x]` → `date +%F`… | Mixed 但可接受。主體「階段一/二/三」= Technique（明確步驟序）；「何時… | 未被覆蓋。Opus 5 當然知道『寫程式前先講清楚要做什麼』，但本檔的價值全在使用者專屬的量化門檻與目錄契約：≤3 tasks、每條 ≤1h、`sdd/<slug>/`、`sd… |
| `security-audit` | **Keep** | high | 零使用者立場滲漏。全文英文、L12 明示「This skill is agent-neutral」，無 zh-TW、無 tier0/rules… | 不可機械化。核心是 Phase 3「派另一組獨立 agent 嘗試推翻每一個 finding」與跨輪覆蓋補洞，屬編排與判斷，rege… | Technique 為主（六階段流程 + subagent 編排 + 產物契約），內嵌一… | 漏洞類別本身 Opus 5 全知道，但三件事模型不會自發做：(1) 派獨立 agent 反證自己的 finding；(2) 讀前輪 findings.json 做跨輪去重與導向… |
| `vite` | **Keep** | high | 立場滲漏輕度但確實存在，集中在 3 處：(1) Workflow 第 3 條「Prefer `vite.config.ts` + ESM unl… | 部分可機械化但不足以整體轉 hook。可 100% 強制的子集：`process.env.X` 出現在 client 端原始碼（ES… | Mixed，且 SKILL.md 與 references/ 分屬不同型別。SKILL.… | 覆蓋不均。**已被完全覆蓋**：Vite 4/5/6 的 config 形狀、alias、server.proxy、build.lib、assets query（?raw/?u… |
| `vitest` | **Keep** | high | 立場滲漏中度，且集中在 references/vitest-deep.md 而非 SKILL.md。實際觀察到的純立場句：(1)「Mock ex… | 三條可 100% 機械化，且都是 config 層：`clearMocks: true` 是否設於 vitest.config.ts… | Mixed，且是五個裡型別最不純的。SKILL.md（403 字）= Technique… | 覆蓋度高，是五個裡最容易被內建取代的。**完全覆蓋**：`it`/`describe`/`expect` matcher、hooks 生命週期、CLI flag、snapsho… |

---

## 3. 6 個 Delete 候選的推翻依據分級（你可以在這裡覆寫）

| 原判 Delete | 推翻依據 | 分級 | 我的建議 |
|---|---|---|---|
| `testing-library-react-best-practices` | **新事實**：`grep -n mock rules/testing.md` 零命中，證明「mock at external boundaries」在 rules 層確實不存在 | 證據 | 推翻成立，改 Trim |
| `vueuse-functions` | **新事實**：gitleaks 掃硬編字串，抓不到「執行期把 token 寫進 `useStorage`」的資料流 → 原評估「已被機械守護」為誤 | 證據 | 推翻成立，改 Trim |
| `dotnet-winforms-best-practices` | **論證**：「description 特異性高不會誤觸發 → 刪除收益 ≈ 0 → 負期望值」 | 論證，但**第四軸定義後成立**（實測 0 碰撞） | 推翻成立，改 Trim |
| `vue-debug-guides` | **論證**：`vue-best-practices/SKILL.md:3` 的 description 指向它 | **循環論證，且第四軸不保護它**（與 `nuxt` 逐字共用 "hydration mismatch"） | **推翻依據無效**（指標存在的目的就是路由到 companion，而 companion 靠指標活著）。但 D2 的分析顯示：Delete 的核心收益（消碰撞）用「改 `nuxt` description」也拿得到，所以最終建議仍是保留 → 見 `02-recommendations.md` D2 |
| `security-review` | **程序**：第 3 軸（無路由負載）實測不成立——名字硬寫在四檔 | 程序成立、實質弱 | 維持 Trim，但**必須**先修 `references/workflow.md:8` 才有分工 |
| `postgresql-optimization` | 未被推翻，且第四軸不保護它（碰撞 0.250 = 全庫第 2 高） | — | **Delete 成立**，但有前置條件（見下） |

### ⚠️ 唯一的 Delete 有一個沒人負責的前置條件

`postgresql-optimization` 判 Delete，明文**條件於「先把內容合併進 `postgresql-best-practices`」**，且驗證進一步擴大了合併範圍（分割門檻、FTS 上限、jsonb_path_ops 量化表、BRIN pages_per_range），**還要求修正 pg-bp 內兩處事實錯誤**（`schema-design.md:63` UUIDv7 陳述過時、`advanced-features.md` 分割表 unique constraint 措辭錯誤）。

而 `postgresql-best-practices` 判 **Keep，其判決完全沒提到自己有這個義務**。

**照現狀執行 = 直接刪除，資訊淨損失。**

---

## 4. 稽核範圍錯誤（實測確認）

我原本把範圍定為「52 個個人 skill」。**這是錯的** —— Codex 端另有 7 個 host-local skill 不在 `agents-sync` 部署管線內：

```
~/.codex/skills/  →  agent-browser  architecture-html-doc  chronicle
                     codex-dynamic-workflows  pdf  playwright  security-ownership-map
~/.copilot/skills/ → (空)      ~/.copilot/intellij-skills/ → debug
```

三個已實測確認的後果：

1. **`agent-browser` 內容 drift**：`~/.codex/skills/agent-browser/SKILL.md` = 458 字（md5 `7ea721d8…`），`~/.agents/skills/agent-browser/SKILL.md` = 3,285 字（md5 `ebd5d644…`）。兩份不同內容同名並存。
2. **`architecture-html-doc` 仍在役且三方互搶**：其 description 為「generate visual architecture docs, refresh project docs, initialize repo documentation, produce an architecture map during onboarding」——與 `design-doc-mermaid`、`init-project-docs`、`acquire-codebase-knowledge` 同時碰撞。而 `design-doc-mermaid` 正是 retrofit 到它「退役位置」上的產物。
3. **`~/.codex/skills/playwright`** 與 `playwright-best-practices` 同語境。

`attic/codex-legacy-skills/README.md` 早在 **2026-07-08** 就記錄了這個結構性問題（F10：「host 專屬 skill 目錄不在 agents-sync 部署管線內，屬手寫層」），並明文列 `architecture-html-doc` 為「仍在役、勿歸檔」。**這層至今無人巡檢。**

---

## 5. Routing 可達性缺陷（實測，本次最大的單一可執行修復）

`core/routing.md:9` 自己就有規則：「非 `*-best-practices` 命名，須逐名點名才可路由」——但只涵蓋 5 個（vite / vitest / security-audit / security-review / agent-browser）。

**實測真正不可推導的非慣例命名有 9 個**，其中 6 個未被點名：
`auditing-skill-folder`、`ecpay`、`native-feel-cross-platform-desktop`、`nuxt`、`pinia`、`react-router-framework-mode`、`vue-debug-guides`、`vueuse-functions`、`postgresql-optimization`

**規則存在但只執行了 36%。**

而 routing 名額並不稀缺：實測 `core/routing.md` = **15 行 / `ROUTING_MAX=30`**，一半預算閒置（`agents-sync:163` 的 lint5）。加名字是廉價的。

---

## 6. Trim 的正當性判準（決定 21 個 Trim 哪些現在可執行）

完整性批判指出一個未被回答的內部不一致：有 8 次 Trim→Keep 用的是同一句「references 只在 invoke 時載入 → 移除省 0 常駐 token → 故無行動理由」。**若這條普遍成立，它同時作廢倖存的 21 個 Trim**（那些動作幾乎全是刪 reference 檔）。

判準是（本次補上，先前未明說）：

> **Trim 的正當理由是內容「錯」——過期、自相矛盾、死連結、與 rules 層牴觸——不是「大」或「重複」。**

這正是為什麼 `nuxt` 的 12,520 字過期 nuxt.com 快照與 `tailwind-v4-shadcn` 的內部矛盾該處理，而 `vite` 那批已用 Context7 驗證為正確的 references 不該動。

依此重掃 21 個 Trim（判準：判決理由是否引用具體 `檔:行` 或明示過期／矛盾／死連結／牴觸）：

| 狀態 | Skill |
|---|---|
| **有具體缺陷引文 → 現在可執行**（16） | dev-workflow、mp-tdd、dotnet-testing、next-best-practices、testing-library-react、vue-best-practices、vue-debug-guides、pinia、nuxt、tailwind-v4-shadcn、c-cpp、native-feel、security-review、auth-implementation-patterns、containerization、design-doc-mermaid |
| **僅以體積／重複為由 → 不執行**（5） | `dotnet-winforms-best-practices`、`vueuse-functions`、`nodejs-best-practices`、`typescript-best-practices`、`react-best-practices` |

後 5 個的 Trim **實質等同 Keep**（`nodejs-best-practices` 的 Trim 動作已被驗證者證實為「資訊淨損失」而否決）。列在這裡是為了不讓體積論證偷渡成行動理由。

---

## 7. Verdict Block

```
Keep                        29
Trim（有缺陷引文，可執行）   16
Trim（僅體積論證，不執行）    5   ← 實質 = Keep
Split                        1   (css-ui-best-practices → tailwind-v4-shadcn，但目的地需先修)
Delete                       1   (postgresql-optimization，附合併前置條件)
Move-to-rules                0   (初評 1 個，被推翻)
Convert-to-hook              0   (但 deps-check 的 PreToolUse hook 文件已寫、settings.json 未掛)
```

> **與 `02-recommendations.md` D3 的關係**：本區塊的 `Delete 1` 是**協定判決**——`postgresql-optimization` 三軸皆過、對抗驗證未推翻、第四軸不保護它。D3 討論的是**執行時機**（先做內容合併再刪 vs 延後），不是推翻判決。兩處不衝突。

**對你原始問題的直答：「與 Opus 5 內建知識重複」這條準則，在本 skill 庫上只產生 1 個可執行的移除。** 內容重複的那批（winforms / RTL / vue-debug / vueuse / security-review / nodejs / typescript）確實內建覆蓋 100%，但它們的常駐成本合計不到 900 token，而移除代價是四檔協調編輯 + lint 紅燈 + 休眠棧知識歸零。

真正的價值不在刪除，在 `02-recommendations.md` 的三個批次。

---

## 8. 稽核範圍的明示假設

1. **plugin skill 不列入移除候選**（superpowers / ponytail / hookify / code-review / skill-creator / frontend-design / chrome-devtools-mcp / microsoft-docs / claude-md-management / codex / remember 等約 40+ 個）。理由：移除等於卸載 plugin，屬不同性質的決策。它們**有**被納入「功能重疊」判斷（見各檔 `plugin_overlap` 欄）。
   **推論**：§1.1 的 **21,748 字元 / 6–8k token 只涵蓋個人 52 個 skill**。若以常駐成本為指標，plugin 的 description 是一塊同量級但未量測的區塊——這個數字不是總量。
2. **host-local skill 原本被漏掉**，已在 §4 補上（`~/.codex/skills/` 7 個）。
3. 使用者主力 stack 為 .NET 8 + MySQL + Dapper；前端 skill 的 0 次調用同時反映低使用與低曝光，不單獨作為內容無價值的證據。

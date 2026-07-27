# 兩份建議的比較（Claude vs Codex）

> 對照對象：Codex 針對同一問題產出的建議。所有數字為 2026-07-27 本機實測。
> **superpowers 取代可行性的完整分析在 [04-superpowers-feasibility.md](04-superpowers-feasibility.md)**（含 `skillUsage` 調用量實測與 SessionStart hook 原始碼證據）。本檔的 §3 只保留 04 未涵蓋的兩件事：使用者實際問的替換情境 token 實算、以及 `using-superpowers` 作為路由強制力的分析。

## 1. 兩份建議的共識（都成立，不需再議）

- 不要整套取代 `dev-workflow`
- 保留 S0 / S4 / S5 / S6 的 gate 機制
- Matt 的東西嫁接進 S1–S3，外加 S5 的 two-axis review
- 值得選擇性導入：`handoff`、`prototype`、`research`、`to-tickets`、`wayfinder`
- `setup-matt-pocock-skills` 不要用（會和既有 repo governance 撞）

結論方向一致。差異在**論證的可靠度**與**涵蓋維度**。

## 2. 逐項比對（含實測裁決）

| 議題 | 我的說法 | Codex 的說法 | 實測裁決 |
|------|---------|-------------|---------|
| **superpowers 依賴強度** | 分辨硬依賴 / enhancement | 「dev-workflow S2/S3/S5/S6 引用多個 superpowers:*」，列為不能移除的理由 | **我大致對，一處要修正**。SKILL.md 的 2 處引用（:73 `writing-plans`、:125 整行）都明標 `enhancement:` 且 :73 寫明「缺 plugin 時直接在 session 產完整 plan artifact」——是設計好的降級路徑。**但 `references/review-triage.md:31`（`superpowers:receiving-code-review`）沒有 enhancement 標記**，且位在 S6 bot-review triage 規格內。減損有限（同一條紀律在 SKILL.md S5 ACTION 已重複寫明「採納或有據 pushback，不表演式同意」），但那行確實沒標，要補 |
| **硬依賴清單** | mp-tdd、bug-fix-settlement、**auditing-skill-folder** | mp-tdd、bug-fix-settlement、routing.md | **各漏一項**。Codex 漏 `auditing-skill-folder`（明寫 `REQUIRED BACKGROUND: superpowers:writing-skills`，是三者中最硬的）；我漏查 `routing.md`——但查完發現 Codex 也錯置：routing.md:12 提到 superpowers 是**攔截規則**（「防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈」），是防護不是依賴 |
| **三主機相容性** | 跑 loader 探針實測三家 | 未觸及 | **我補上了 Codex 缺的維度**（但我自己先誤判過一次，靠探針才推翻） |
| **context load** | 實測量化（Codex prompt 56%） | 定性提及 user skill 成本較低 | **我更具體** |
| **repo HEAD** | `pushed_at` 2026-07-23 | `ed37663cc5fb` | **Codex 更精確**。`ed37663cc5fb` @ 2026-07-21 是 HEAD commit；`pushed_at` 2026-07-23 是含其他 branch 的 repo 層時間戳。引用版本應用 HEAD |
| **superpowers 版本** | 先用 6.1.1 算 | 6.2.0 | **Codex 對**。cache 有 5.1.0 / 6.0.3 / 6.1.1 / 6.2.0 四版，6.2.0 為最新 |
| **Matt skill 字數** | 未查 | 「eng 17 個裡 12 個超過 500 words」 | **Codex 高估**。實測 **9/17**（ask-matt 1253、code-review 1030、codebase-design 820、diagnosing-bugs 1387、improve-codebase-architecture 887、setup 1002、to-tickets 860、triage 974、wayfinder 1975）。productivity 那條（teach/writing-great-skills ~1500）**正確**：實測 1464 / 1502 |
| **本機 mp-\* 的性質** | 查 vendored 名單 → 不是 vendored，是刻意 fork → cherry-pick 不要整包刷 | 建議「視為 upstream/vendored，不要 trim 原檔」 | **兩者講的是不同對象**。Codex 講的是「若把 Matt repo 裝進來」——那時確實該當 vendored 管；我講的是「現有 mp-\* 怎麼更新」——那 5 個不在 vendored 名單、無上游標記，是刻意 fork。**兩條都要保留** |
| **`resolving-merge-conflicts` 的 never-abort** | 未提 | 指出與使用者授權／安全判斷衝突，需移除外層自動完成假設 | **Codex 更好，我漏了**。這是真的安全維度：該 skill 主張「永不 abort」並自行完成 merge，會越過 `[T0-6]` rollback 要求 |
| **`research` 的 write gate** | 未提 | 指出 read-only 任務不可自動寫 repo，需外層 scope gate | **Codex 更好，我漏了**。該 skill 確實會「Save it where the repo already keeps such notes」——是寫入行為 |
| **來源衝突處理** | 裁決兩處（wayfinder 預設地位、ASR 講反的多-session 分支） | 未提 | **我補上了 Codex 缺的維度** |
| **呈現** | 文字流程圖 | mermaid | **Codex 更好** |

**淨評**：結論相同，Codex 在**風險面**（never-abort、research write gate）看得比我細，我在**事實面**（loader 探針、依賴強度、token 量化、來源裁決）驗得比它嚴。Codex 有三處事實偏差（依賴強度誤判、字數高估、routing.md 錯置），我有兩處（先誤判相容性已自行推翻、superpowers 版本先取舊版）。

## 3. 取代 superpowers 的可行性

### 3.1 前提檢驗：「Matt 佔的 token 遠小於 superpowers」——**不成立**

（完整版見 [04 §1](04-superpowers-feasibility.md)。摘要：superpowers 465 tok vs Matt 460 tok，單看 description 幾乎相同；差距 ~770 tok 全來自 superpowers 的 SessionStart hook 全文注入 `using-superpowers`，總計 ~2.7× 而非「遠小於」。）

> 量測基礎註記：04 的「本機 50 支 = 17,697 ch / 4,424 tok」是 `~/.agents/skills` 各 SKILL.md 的 description 純字數；本檔 §2b 的「Codex prompt 21,587 ch / 56%」是 Codex `skills_instructions` 區塊實際佔位（額外含 name、短路徑、roots 表與格式框架）。兩者都對，前者是內容量、後者是實際 context 佔用。

### 3.2 「用 repo skill 取代本機舊版 mp-*」——這個情境**確實省 token**

替換集不是 22 個，是 **7 個**：mp-* 的 5 個對應上游，加上兩個薄殼所需的 model-invoked 實體（`grill-with-docs` 只有 7 行，實體在 `grilling` + `domain-modeling`；`improve-codebase-architecture` 講 `codebase-design` 的話）。`mp-zoom-out` 無上游對應，原地保留。

| 替換集 | invocation | description |
|--------|-----------|-------------|
| `diagnosing-bugs` | M | 156 chars |
| `tdd` | M | 149 |
| `grilling` | M | 152 |
| `domain-modeling` | M | 216 |
| `codebase-design` | M | 265 |
| `grill-with-docs` | **U** | 106 |
| `improve-codebase-architecture` | **U** | 125 |

| | Claude 端 | Codex / Copilot（若不尊重 `disable-model-invocation`） |
|---|---|---|
| 替換集 7 個 | 938 chars ≈ **234 tok** | 1,169 chars ≈ **292 tok** |
| 本機 mp-* 5 個現況 | 1,342 chars ≈ 335 tok | ≈ 335 tok |
| **淨變化** | **−101 tok** | **−44 tok** |

**兩個分支都是省**，所以此結論對「Codex/Copilot 是否尊重 `disable-model-invocation`」這個未定項是 **sign-stable** — 不必等那項驗完才能決定。

省的原因不是 Matt 寫得比較短，是**本機 mp-\* 的 description 被在地化寫長了**（5 個佔 1,342 chars，上游 7 個才 938）。

**對照組（全裝 22 個的最大讀法）**：Claude 端 +125 tok、Codex/Copilot 端 +524 tok — 那是「完整採用」而非「取代 mp-*」的成本，不要拿來評估這個決策。

### 3.3 逐支補位可行性（04 §3 只列了「無對應物」的四支，這裡補完整對映）

耦合分類與硬依賴清單見 [04 §4](04-superpowers-feasibility.md)；「真正的 token 大戶是本機 50 支」見 [04 §1d](04-superpowers-feasibility.md)。以下是 04 未做的逐支對映：

| superpowers | Matt 對應 | 能否替代 |
|---|---|---|
| `test-driven-development` | `tdd` | **不能直接換**。Matt v1.1 已把 **refactor 移出迴圈**（歸 code-review）；superpowers 是完整 R-G-R。換了會讓 `mp-tdd` 的「Base」指向一個語意不同的東西 |
| `systematic-debugging` | `diagnosing-bugs` | **可以**，兩者同構（reproduce → minimise → hypothesise → fix → regression test） |
| `writing-skills` | `writing-great-skills` | **可以**，但 `auditing-skill-folder` 的六軸標準要逐條重新對映到新來源 |
| `brainstorming` | `grilling` | **可以**，Matt 版更明確（一次一題、fact/decision 二分） |
| `writing-plans` / `executing-plans` / `subagent-driven-development` | `to-spec` + `to-tickets` + `implement` | **概念對應但契約不同**；且本機這三處全是 enhancement，缺席不影響 workflow |
| `verification-before-completion` / `requesting-code-review` / `receiving-code-review` | `code-review` | 部分。S4/S5 的機械 gate 本來就在 `dev-workflow`，不靠 superpowers |
| `finishing-a-development-branch` | **無對應** | `[INT-1]` 專門管它的時機；移除等於少一個收尾執行體（但 S6 的 ledger 才是正本） |
| `using-git-worktrees` / `dispatching-parallel-agents` | **無對應** | 能力型 |
| `using-superpowers` | **無對應，且不是 skill** | 見 §3.4b |

### 3.4b `using-superpowers` 的 762 tok 不是 overhead，是強制力

它透過 SessionStart hook **全文注入**，內容是：

- `<EXTREMELY-IMPORTANT>`「如果你認為有 1% 的機率某個 skill 適用於你正在做的事，你**絕對必須** invoke 它…**你沒有選擇**」
- 一張 **Red Flags 合理化對照表**（「這只是個簡單問題」→「問題就是任務，去查 skill」；「我先看一下 codebase」→「skill 會告訴你怎麼看，先查」…共 12 條）
- **process skill 優先於 implementation skill** 的排序規則

**這正是讓 skill 路由在模型開始即興發揮之前先發生的機制。** Matt 那套沒有等價物——`ask-matt` 是**要你打字**才會跑的 router，而 `writing-great-skills` 明確接受「user-invoked skill 花的是**你的**認知負荷，你就是那個索引」。

也就是說：移掉 superpowers 省下的 762 tok，買的是「路由從機械強制降級為人工記憶」。而 `dev-workflow` 的整個 S0 決策表設計**預設路由會自動發生**。

### 3.5 結論（與 [04 §5](04-superpowers-feasibility.md) 一致，補兩條）

04 的三條否決理由（token 假設不成立 / superpowers 佔 28% 調用量 / 四支無對應物）之外，補兩條**類別層級**的理由：

- **兩者不是同一種東西**。superpowers 是**紀律庫**（TDD、debugging、review、verification 的方法論），Matt 是**編排層**（idea→ship 的流程骨架）。互補，重疊只在 tdd / debugging / writing-skills 三處。用編排層取代紀律庫是類別錯置。
- **會刪掉路由的強制力**（§3.4b）。Matt 明確把索引責任交還給人（`writing-great-skills` 原文：user-invoked skill 花的是**你的**認知負荷），而 `dev-workflow` 的 S0 決策表預設路由會自動發生。

**但使用者實際問的那個較小替換（mp-\* 5 個 → 上游 7 個）是另一回事，見 §3.2——那個確實省 token 且可做。**

**可以做的**：若確實要瘦身，把 superpowers 中已被本機 skill 完整覆蓋的部分停用（需逐個驗證覆蓋度），而不是整包換掉。這是獨立於本評估的另一件事。

## 4. 對 Codex 兩項風險發現的採納

兩條都採納，加進 Stage 1 的導入條件：

- **`resolving-merge-conflicts` 的「never abort」**：該 skill 主張永不 `--abort` 並自行完成 merge/rebase。與 `[T0-6]`（merge/大量刪除須附 rollback 策略）衝突。**導入時必須剝掉外層的自動完成假設**——解衝突可以自動，「完成 merge」要回到 S6 的 gate。
- **`research` 的寫入行為**：skill 正本寫「Save it where the repo already keeps such notes」——它會寫 repo。**導入時要加 scope gate**：research 產物落點須事先指定，或先產在 scratchpad 由使用者決定是否入庫。

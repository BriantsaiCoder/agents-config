# 若要取代現有全域 workflow：實測現況、代價、與分階段方案

## 1. 先講結論

**不建議整套取代，建議「嫁接」。** 理由**不是**三主機相容性——那條假設已實測推翻（見 §2）——而是：

> **`dev-workflow` 的機械閘（X0 四形態 EXIT、四態 gate、ledger、`[T0-2]` 證據義務）在 Matt 全套裡沒有任何載體。** 整套取代 = 用一組品質很高的 prose，換掉一組會攔住你的閘。

Matt 那套的四個真缺口都能就地嫁接，不需要拆掉閘。

## 2. 三主機 skill 掛載實況（2026-07-27 實測，含一次自我更正）

**先記下錯誤推論**：從目錄實況（`~/.codex/skills` 只有 3 個自有 skill、`~/.copilot/skills` 為 0 entries、兩家 config 皆無 skill 路徑設定）推論「Codex/Copilot 讀不到 `~/.agents/skills` 的 description」。**這是錯的**——兩家都是**多 root 探索**，不是只掃自己的目錄。

實測（loader 探針，非目錄推論）：

| Host | 探針 | 結果 |
|------|------|------|
| **Claude** | `~/.claude/skills` 目錄 | 50 個 symlink → `~/.agents/skills/` |
| **Codex** | `codex debug prompt-input` | `skills_instructions` 區塊內建 **skill roots 表**，`r1 = /Users/pochientsai/.agents/skills`，注入 **50 個** skill，**description 全文**（抽驗 `vitest` 的完整 "Use when configuring or debugging…" 段落在內） |
| **Copilot** | `copilot skill --help` / `skill list` | help 明載 Personal 來源含 `~/.agents/skills/`；list 回 **128 個**（50 personal + plugin bundled），description 全文 |

**三家都能自動觸發 model-invoked skill。** `~/.codex/AGENTS.md` 裡「Codex 端 description 被截斷至 2–6 字元」那句是 2026-07-12 已被更正的舊宣稱（memory `three-host-config-audit-facts` 第 16 行有記載此更正），生成檔裡的散文尚未同步——**這是一條獨立的 doc rot，值得另開 follow-up 修**。

**仍未定的一項**：`disable-model-invocation: true` 這個欄位 Codex / Copilot 是否尊重。本機無法定案——`grep -rl` 掃過 `~/.codex/skills/` 與 `~/.copilot/installed-plugins/`，命中的全是 `validate_plugin.py`、`commands/*.md`、`RELEASE-NOTES.md` 這類文件檔，**沒有任何實際 SKILL.md 使用該欄位**，因此沒有對照組可判定。

- Claude 端**已確認支援**（本 session 的 skill listing 行為即為證據）
- Codex / Copilot **待驗**

**風險是有界的**：即使兩家不尊重該欄位，後果只是 user-invoked skill 在那兩家仍付 context load（程度問題）；skill 本身不會變得不可達——Codex 的 AGENTS.md 路由本來就是「逐名點名 + 讀路徑」，description 被剝掉也叫得到。

## 2b. 反過來說：本機的 context load 問題比 Matt 嚴重得多

既然三家都全文注入 description，就能量化：

| | skill 數 | description context 成本 |
|---|---|---|
| Matt（影片 M6mYodf0dJM `/context` 實測） | 38 | **~660 tokens** |
| 本機（Codex `prompt-input` 實測） | 50 | **~5,400 tokens，佔 system prompt 的 56%**（21,587 / 38,564 chars） |

差距 **8 倍**，因為本機 50 個 skill **零個**使用 `disable-model-invocation`——全部都在付 context load，包含那些只可能由你手動叫的編排型 skill。

這反過來讓 §6 那條建議變成本評估**最划算的單項改動**：與 workflow 換不換無關，純粹是把編排型 skill 標成 user-invoked 就能省下的東西。

## 3. 你會失去什麼（`dev-workflow` 有、Matt 沒有）

Matt 的 skill 從頭到尾是 prose，`/implement` 15 行、無閘、無 exit 條件、無證據義務。直接換掉 `dev-workflow` 會丟掉：

| 機制 | 內容 | 有無替代載體 |
|------|------|------------|
| **X0 機械判定契約** | ENTER/EXIT 只准四種機械形態（檔案存在性 / 用戶關鍵字 / exit code / session artifact），**禁止需要散文判斷的 EXIT** | 無 |
| **四態 gate** | 每 gate 標 PASS/FAIL/UNAVAILABLE(附 probe 證據)/SKIPPED(附理由) | 無 |
| **Preflight / Closeout ledger** | 8 rows 進 PR body，每 row 附證據 | 無 |
| **`[T0-2]` 綁定** | 無 evidence 不得宣稱 done | **無載體**——這是最痛的一項 |
| **`[T0-8]` / `[INT-3]`** | 架構性 / 中高風險變更的 plan gate，auto mode 不得豁免 | 無（Matt 靠 grilling 的確認閘，但那不是 gate 是禮貌） |
| **`[INT-2]` 紅測先行** | fix 前必有 failing regression test | 部分——`tdd` 有 red-before-green，但沒有「bugfix 必先紅測」的強制 |
| **BUGFIX 鏈 + `bug-fix-settlement`** | 修完必輸出沉澱評估摘要 | 無 |
| **`deps-check` 強制** | 動高扇入共用檔前必列依賴方 | 無 |
| **stack `*-best-practices` 強制套用** | S3 必套 | 無 |
| **bot-review triage 規格** | 異步等 2–3 分、thread-aware、bot findings 是子集所以要自行枚舉全 caller | 無 |
| **三主機 host adapter** | plan/todo/subagent 的名稱映射 + 能力差異 | 無（Matt 是單機思維） |

## 4. 你會得到什麼（Matt 有、`dev-workflow` 沒有）

誠實列，這四項是真缺口：

1. **Smart zone 容量預算（~120k）當成一級工作流概念。** `dev-workflow` 的 S3 對 session 邊界**完全沒有概念**——沒說什麼時候該換 session、什麼時候該 handoff。
2. **依「一個 context window」切票 + blocking edges。** 你的 LIGHT/HEAVY 是**風險軸**切分；Matt 的是**容量軸**。這是不同的軸，你少了容量那一軸。
3. **`wayfinder` 多 session 迷霧探索。** 本機無對應物；`mp-zoom-out` 只是進陌生 code 前的系統圖，不是這個。你的 S1/S2 預設整件事在一個 session 裡談得完。
4. **`code-review` 兩軸平行 sub-agent + Fowler smell 基線。** 你的 S5 ACTION 目前**沒有規定方法**，只規定要記錄 reviewer 型別與結論。

另外三項較軟但有價值：
5. `grilling` 的 **fact/decision 二分**與**一次一題**——比 `mp-grill-with-docs` 現在的版本明確。
6. **user/model-invoked 二分 + router 模式**當作 context load 的控制手段（實測 38 skills = 660 tokens）。
7. **issue tracker 當狀態儲存**，讓 session 可拋。

## 5. 分階段方案（每階段標明代價，你挑停在哪一階）

### Stage 0 — **挑差異手動套用**（不是整包刷新）

**先確認性質**：5 個 `mp-*` **不在** vendored 名單上（memory `vendored-skills-no-local-restructure` 列的 6 個是 `ecpay` / `security-audit` / `native-feel-cross-platform-desktop` / `playwright-best-practices` / `vueuse-functions` / 已退役的 `design-doc-mermaid`），且 `grep -rl mattpocock ~/.agents/skills/mp-*/` **零命中**——沒有上游標記。結合行數落差與自行新增的 `references/`，這是**刻意的在地 fork**，不是過期的 vendored 副本。

**因此不要整包重抓**——那會覆蓋刻意的在地化，違反 `[T1-5]`。改成挑已識別的兩處差異手動套用：

1. `mp-tdd`：把 `refactoring.md` 移出紅綠迴圈（上游 v1.1 已把 refactor 歸到 code-review 階段）
2. `mp-grill-with-docs`：手動套 grilling 三修（一次一題的**理由**、動手前確認閘、fact/decision 二分）

其餘落差（`mp-diagnose` 的 `hitl-loop.template.sh`、`improve-codebase-architecture` 的 `HTML-REPORT.md`）先評估在地版是否已有等效物再決定。

實測落差表（本機 5 個 `mp-*` 全是 **pre-v1.1**）：

| 本機 | 上游 | 落差 |
|------|------|------|
| `mp-tdd`（62 行 + `refactoring.md`） | `tdd`（36 行） | **上游 v1.1 已把 refactor 移出紅綠迴圈**，本機仍帶 `refactoring.md` |
| `mp-grill-with-docs`（66 行） | `grill-with-docs`（7 行薄殼 + `grilling` 12 行） | 本機缺 v1.1 三修：一次一題的**理由**、動手前確認閘、fact/decision 二分 |
| `mp-diagnose`（68 行） | `diagnosing-bugs`（134 行） | 上游多了 `hitl-loop.template.sh` |
| `mp-improve-codebase-architecture`（77 行） | 同名（71 行） | 上游新增 `HTML-REPORT.md` |
| `mp-zoom-out`（14 行） | **無對應** | 本機獨有，保留 |

代價：兩處都要逐行比對在地版是否已用別的方式解決同一問題。**注意上游改名**：`to-PRD`→`to-spec`、`to-issues`→`to-tickets`，若日後引入這兩支，installer 認不出改名，要手動清舊的。

### Stage 1 — 嫁接四個缺口進既有 S 階段（**推薦**）

閘機制原封不動，只補內容：

| 缺口 | 落點 | 具體做法 |
|------|------|---------|
| grilling 三修 | **S1 NEEDS** | 更新 `mp-grill-with-docs`：加 fact/decision 二分、一次一題的理由、動手前確認閘 |
| smart zone + 容量切片 | **S3 IMPLEMENT** | S3 ACTION 加一條：逼近 ~120k 時不硬撐，`/handoff` 換 session；task 拆分除現有風險軸外，加「每 task 塞得進一個乾淨 context window」的容量軸 |
| 兩軸 code review | **S5 REVIEW** | S5 ACTION 目前無方法，補上：Standards（repo 標準 + Fowler 12 smell 基線）與 Spec（對照原始 issue/spec）**平行兩個 sub-agent、不合併不重排**。與現有 `references/reviewer-template.md` 合併 |
| wayfinder | **S0 ROUTE** | 決策表加一列：「工作量大到單 session 裝不下**且路徑本身未明**」→ WAYFINDER 路，產出決策地圖後由 `to-spec` 併回 HEAVY 主線。注意此列必須放在 LIGHT/HEAVY 之前判定 |

代價：`dev-workflow` SKILL.md 從 143 行增長；`wayfinder` 需要 issue tracker 契約，與你既有的 X1 產物表（`docs/superpowers/specs/`、`sdd/<slug>/`）需要對齊——**不要引入 Matt 的 `.scratch/` 第二套慣例**。

### Stage 2 — 完整取代（技術上可行，但**不建議**）

三主機相容性**不再是障礙**（§2 已推翻）。真正該回答的是兩題：

1. **`[T0-2]` 證據義務掛在哪？** Matt 全套無載體。要補回去就得把 X0 契約、四態 gate、ledger 重寫進他的 skill——那不叫取代，叫把 `dev-workflow` 換個檔名。這是 Stage 2 的**核心矛盾**，不是細節。
2. **兩套持久化慣例怎麼收斂？** `setup-matt-pocock-skills` 會寫 `docs/agents/*.md`、把 issue 放 `.scratch/<feature>/`、並在 `CLAUDE.md` 插入 `## Agent skills` 區塊；你現行 X1 表用 `docs/superpowers/{specs,plans}/`、`sdd/<slug>/`、`docs/adr/`。**選一套，別讓兩套並存**。

還有一項連帶損失：`dev-workflow` 的 host adapter 段（plan/todo/subagent 三家名稱映射、Codex 的 spawn_agent 條件、Copilot 的 S2 強制令）是 Matt 單機思維裡沒有的東西，取代後要自己維護在別處。

**判斷**：Stage 2 的代價是「用一組沒有閘的高品質 prose，換掉一組會攔住你的閘」。除非你認為那些閘實際上沒攔到過東西，否則不划算。

## 6. 無論停在哪一階都建議照抄的一條規則

> **User-invoked skill 可以叫 model-invoked skill，但絕不叫另一個 user-invoked skill。**

這條讓 skill 之間的組合關係是一棵樹而非任意圖，是整套能被人腦追蹤的根本原因。你目前 50 個 skill **零個**使用 `disable-model-invocation`，等於全部都在付 context load。即使不採用 Matt 的流程，這條分層規則本身值得引入。

**但先驗 §2 的未定項再動手**：Claude 端已確認會省下 context；Codex / Copilot 是否尊重該欄位尚未定案。若只有 Claude 端生效，這條就從「最划算的單項改動」降為「Claude 端有效的局部優化」——仍值得做，但別按三家全省來估收益。

## 7. 下一步與 follow-up

**建議路徑**：Stage 0（更新 5 個 `mp-*` fork）→ Stage 1（四缺口嫁接）→ §6 那條分層規則。三者互相獨立，可分批做。

本評估附帶挖出的兩條 scope 外問題（**未實作，待確認**）：

1. **doc rot（4 個站點，含生成源）**：「Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description」這句存在於

   | 站點 | 性質 | 修法 |
   |------|------|------|
   | `~/.agents/core/routing.md:7` | **生成源** | **改這裡**——下面兩個生成檔都源於它 |
   | `~/.codex/AGENTS.md:57` | `agents-sync` 生成 | 改源檔後重跑 `agents-sync` |
   | `~/.copilot/copilot-instructions.md:57` | 同上 | 同上 |
   | `~/.claude/CLAUDE.md:74` | **手寫正本**（首行 `# Global Preferences`，無 `GENERATED` 標記） | 直接改 |

   實際修法：改 `routing.md` + `~/.claude/CLAUDE.md`，再跑 `agents-sync`（部署前先 `--check`，見 memory `agents-sync-check-before-deploy`）。2026-07-12 已實測推翻、2026-07-27 再證。memory `three-host-config-audit-facts` 另記「舊宣稱散布 9 處待清」，可一併掃。
2. **context load**：50 個 skill 零個使用 `disable-model-invocation`，Codex system prompt 的 56% 是 skill description。與 workflow 是否更換無關，可獨立優化——但 §2 那條「Codex/Copilot 是否尊重該欄位」要先驗，否則省下的可能只有 Claude 端。

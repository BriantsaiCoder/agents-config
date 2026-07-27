# 用 mattpocock/skills 取代 superpowers 的可行性

> 觸發假設：「Mattpocock workflow 佔的 token 遠小於 superpowers skill」。
> **結論：假設不成立，取代不可行。** 三個互相獨立的理由，任一單獨成立即足以否決。

## 1. Token 假設實測推翻

**常駐成本（每回合都付的 description）：**

| | skill 數 | 進 context 的 description | ≈ tokens |
|---|---|---|---|
| superpowers 6.2.0 | 14 | 1,861 ch | **465** |
| superpowers 6.1.1 | 14 | 1,960 ch | 490 |
| mattpocock engineering+productivity | 22（13 支 user-invoked 不進） | 1,842 ch | **460** |
| **本機 `~/.agents/skills`** | 50（**0 支** user-invoked） | 17,697 ch | **4,424** |

**superpowers 與 mattpocock 幾乎相同（465 vs 460）。** 兩者用不同手段達到同一結果：

- superpowers：**把 description 寫短**（平均 133 ch/支，最長 `receiving-code-review` 234 ch）
- mattpocock：**把 13 支藏起來**（`disable-model-invocation: true`，平均 205 ch × 9 支）

## 1b. 但使用者感覺到的東西是真的——只是歸因錯了

superpowers 確實有一項 mattpocock 沒有的常駐成本：**plugin 自帶的 SessionStart hook 把 `using-superpowers` SKILL.md 全文注入。**

實證（`.../superpowers/6.2.0/hooks/session-start`）：

```bash
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md")
session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content ...**\n\n${using_superpowers_escaped}\n</EXTREMELY_IMPORTANT>"
```

matcher = `startup|clear|compact`，實跑輸出 3,484 bytes（SKILL.md 本體 3,063 ch，6.1.1 與 6.2.0 **byte-identical**）。

**誠實的總帳：**

| | 常駐 tokens |
|---|---|
| superpowers（desc 465 + hook 全文 ~766） | **~1,230** |
| mattpocock eng+prod（無 hook） | **460** |
| 差距 | **~2.7×，不是「遠小於」** |

**且整個差距來自 hook，不是 skill 設計。** 這讓修法變得很便宜：調整或收窄那個 hook 就能關掉大部分差距，完全不需要換 workflow。

## 1c. 第二種讀法：body 確實比較重（但那不是常駐成本）

| | body 總計 | 最大單支 |
|---|---|---|
| superpowers 14 支 | 122,272 ch | `writing-skills` 26k、`subagent-driven-development` 21k |
| mattpocock 22 支 | 96,730 ch | `/implement` 僅 15 行 |

**但 body 是 invoke 時才載入的 progressive disclosure，不是每回合付的稅。** 把兩種成本混為一談，就會得出「superpowers 很重」的錯覺。

## 1d. 若目標真的是省 token，錢在別處

本機 50 個 skill 的 **4,424 tok** 常駐成本是 superpowers（含 hook）的 **3.6 倍**、mattpocock 的 **9.6 倍**——因為 50 支**零個**使用 `disable-model-invocation`。

**這才是真正的槓桿**，而解法是 [03-migration.md §6](03-migration.md) 那條分層規則，不是換掉 workflow。（前提：先驗 Codex/Copilot 是否尊重該欄位，見 03 §2。）

---

## 2. 使用量：superpowers 是本機用最兇的東西，mp-* 幾乎沒在用

`~/.claude.json` 的 `skillUsage`（記憶 `skill-usage-authoritative-source` 認定的權威來源）：

| | 支數 | 調用次數 | 佔全體 628 次 |
|---|---|---|---|
| **superpowers** | 11 | **177** | **28%** |
| **所有 `mp-*` 合計** | 4 | **8** | 1.3% |

比例 **22×**。`pluginUsage` 的 `superpowers@inline` 更是 **1,310** 次。

個別排名（全體 Top 15 內 superpowers 佔 5 席）：

| Skill | 次數 |
|---|---|
| `superpowers:finishing-a-development-branch` | **32** |
| `superpowers:systematic-debugging` | 25 |
| `superpowers:writing-plans` | 21 |
| `superpowers:brainstorming` | 20 |
| `superpowers:test-driven-development` | 19 |
| `superpowers:receiving-code-review` | 18 |
| — 對照 — | |
| `mp-zoom-out` | 4 |
| `mp-grill-with-docs` | 2 |
| `mp-improve-codebase-architecture` | 1 |

這不是休眠的依賴，是熱路徑。

## 3. 功能缺口：有明文規則指著 superpowers

`finishing-a-development-branch` 是 superpowers 用量第一名（32 次），而 **`dev-workflow` 的 `[INT-1]` 就是專門為它寫的**：

> 「[INT-1] MUST 收尾類 skill（`finishing-a-development-branch` 等）只在 S4 且 S5 兩者皆 PASS 後 invoke」

移掉它，`[INT-1]` 就變成一條沒有管轄對象的規則。

**mattpocock 完全沒有對應物的四支：**

| superpowers skill | 用量 | mattpocock 對應 |
|---|---|---|
| `finishing-a-development-branch` | 32 | **無** |
| `using-git-worktrees` | 1 | **無** |
| `dispatching-parallel-agents` | — | **無** |
| `verification-before-completion` | — | **無** |

前兩支的缺席特別關鍵——Matt 的流程假設你手動管 session 與分支，本機的 `[INT-1]` / S6 假設有 skill 承接。

## 4. 耦合：7 個引用，但只有 2 個是硬的

`grep -rn "superpowers:" ~/.agents/skills/ ~/.agents/core/` 命中 7 個檔。**分類後成本差很多**：

**可降級（明文標為 enhancement 且有 fallback）：**

| 位置 | 引用 | fallback |
|---|---|---|
| `dev-workflow/SKILL.md:73` | `writing-plans` | 檔內明寫「**缺 plugin 時直接在 session 產完整 plan artifact**」 |
| `dev-workflow/SKILL.md:125` | `brainstorming` / `executing-plans` / `subagent-driven-development` / `requesting-code-review` / `finishing-a-development-branch` | Claude host adapter 的 enhancement 段 |
| `dev-workflow/references/review-triage.md:31` | `receiving-code-review` | 紀律指引 |
| `bug-fix-settlement/SKILL.md:3,12` | `systematic-debugging` | 分工指標（本 skill 明說不負責 debug） |

**硬依賴（移除即失效）：**

| 位置 | 引用 | 為什麼硬 |
|---|---|---|
| `mp-tdd/SKILL.md:10` | `test-driven-development` | 原文：「**Base RED-GREEN-REFACTOR is in `superpowers:test-driven-development`. This skill adds vertical slice.**」mp-tdd **本身就是 base 之上的 delta**，拿掉 base 它語意不完整 |
| `auditing-skill-folder/SKILL.md:58` | `writing-skills` | 原文：「**REQUIRED BACKGROUND**: `superpowers:writing-skills`（**authoritative source for the six standards**）」，且 `step7-style-checks.md` 逐檢核引用它 |

**一個誠實的讓步**：`writing-great-skills` 作為 reference 確實可以替代 `superpowers:writing-skills`——但換掉表示 `step7-style-checks.md` 要對照另一套 rubric 重寫（六標準 vs Matt 的資訊階層三階）。是可行的替換，不是零成本的替換。

---

## 5. 判定

| 理由 | 強度 |
|---|---|
| ① Token 假設不成立（465 vs 460；差距全來自 hook） | **否決動機** |
| ② superpowers 佔 28% 調用量，mp-* 佔 1.3% | **否決** |
| ③ 四支功能無對應物，其中一支有 `[INT-1]` 明文指著 | **否決** |
| ④ 兩處硬耦合 | 提高成本，非獨立否決 |

**不可行。** 而且原始動機（省 token）本身就不成立——真要省，改本機 50 支的分層，效益是換掉 superpowers 的 3.6 倍。

## 6. 反過來說：superpowers 的 hook 值得單獨檢視

這是本次分析唯一站得住的「superpowers 成本」議題，與取代與否無關：

- SessionStart hook 每次 `startup|clear|compact` 注入 3,063 ch 全文
- `using-superpowers` 自身用量只有 **2 次**——它不是靠被 invoke 起作用，是靠 hook 常駐
- 這是刻意設計（確保 skill 紀律在每個 session 開頭生效），不是 bug

**要不要留是價值判斷**：付 ~766 tok/session 換「skill 優先」紀律的常駐提醒。考慮到 superpowers 佔 28% 調用量，這個 hook 大概率是有效的——但若要縮，改 hook 比換 workflow 精準得多。

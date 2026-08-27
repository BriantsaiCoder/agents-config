# Opus 5 Prompt Audit — Claude 全域設定

日期：2026-08-22｜方法：官方 `claude-api` skill 的 `shared/prompt-audit.md` Step 0–6（2026-08-21 發布，commit `f6656c1`）｜目標模型：`claude-opus-5`
交付：audit report + proposed diff。**未套用任何變更。**

## 為什麼現在該重審

前兩次審查（`2026-08-04-opus5-workflow-review`、`2026-08-05-three-host-opus5-gpt56-tuning`）用的是 `shared/model-migration.md` 的 Opus 5 checklist。官方在 **2026-08-21** 新增了 `shared/prompt-audit.md` 與 `/claude-api prompt-audit` subcommand——一套獨立的稽核方法論，本設定從未跑過。該文件 Step 7 最後一句自陳觸發條件：*"Re-audit at every model release."*

第二個理由是設定本身變了。**2026-08-06 的 [dotclaude PR #14](https://github.com/BriantsaiCoder/dotclaude/pull/14)（`5c44209`）**一次改了三個鍵並移除一條斷言，而該批變更晚於前兩份報告，從未被對照過官方 Opus 5 指引：

| 鍵 | 2026-05-10 | 2026-08-04 (PR #9) | 2026-08-06 (PR #14) | 現在 |
|---|---|---|---|---|
| `effortLevel` | `xhigh` | **`high`**（依官方預設調降）| **`xhigh`**（回退）| `xhigh` |
| `ultracode` | unset | unset | **`true`** | `true` |
| `fastMode` | unset | unset | **`true`** | `true` |
| `repo-integrity.sh` 的 ultracode 斷言 | — | 存在 | **移除** | 無 |

## Step 1 — Prompt surface inventory

| 層 | 檔 | 規模 | 是否常駐 |
|---|---|---|---|
| Entry | `~/.claude/CLAUDE.md` | 63 行 / 4,979 B | ✅ |
| Kernel（`@`-import 展開）| `~/.claude/core/tier0-safety.md` | 24 行 / 3,314 B | ✅ |
| — | `core/tier1-workflow.md`、`tier2-style.md` | 28 行 | ❌ 刻意不載入 |
| 按需 | `~/.claude/rules/*.md` | 294 行 / 15,485 B | 依 path trigger |
| Shared kernel | `~/.agents/skills/dev-workflow/SKILL.md` + 9 references | 122 行 / 12,700 B | 按需讀 |
| Subagent | `~/.claude/agents/*.md` | 3 個定義 | 派工時 |
| Plugin 注入 | ponytail 4.8.4（SessionStart hook）| ~3.5 KB | ✅ |
| Skill catalog | 88 個有用量紀錄的 skill 的 name + description | 全部列出 | ✅ |
| Config | `settings.json`（含 `autoMode` 四段自然語言政策）| — | classifier 側 |

## Step 2 — Provenance

`~/.claude` 是 git repo（dotclaude）。`git blame CLAUDE.md` 的日期分佈：2026-07-29 佔 30 行、2026-08-08 佔 11 行，最舊 4 行來自 2026-05-10。**沒有任何一行早於 Opus 4.8 世代**，也就是說沒有為退役模型寫的緩解措施殘留。`grep` 退役 model 名（`claude-2|claude-3|claude-instant|3\.5|3\.7|opus-4-*`）在常駐三檔與 kernel 全數 **0 命中**。

這一點決定了本次稽核的形狀：Group 1d（fossils）在此設定上是空的，findings 集中在 **Group 4（request config and architecture）**，而不是 prompt 文字。

---

## Findings

### High confidence

#### F1 · `effortLevel` 是死鍵，而機械閘正在斷言它

**Location**：`~/.claude/settings.json`（`effortLevel: "xhigh"`）× `~/.claude/tests/repo-integrity.sh:1152`
**Pattern**：Group 1d — Unenforced instructions（規則沒有任何 code path 檢查）／Group 4 — API fossils
**Evidence**：Claude Code binary 2.1.239 的 `uqi()`：`if (e.settings.ultracode === true) return "xhigh"; return Zje(e.settings.effortLevel)`。`ultracode: true` 在讀 `effortLevel` **之前**就回傳，該鍵在目前設定下不生效。而 `repo-integrity.sh:1152` 的斷言是：

```
(.effortLevel == "high" or .effortLevel == "xhigh") and .alwaysThinkingEnabled == true
```

**Why obsolete**：這條斷言驗的是一個被覆寫的值。它會在 `effortLevel` 被改成 `low` 時報紅——但那個改動本來就沒有任何行為效果；反過來，真正決定 effort 的 `ultracode` 鍵沒有任何斷言（2026-08-06 移除）。閘門保護的是不生效的那一半。
**Confidence**：High（binary 實證 + 斷言原文）
**Action**：`rewrite`（見 diff D1）

#### F2 · ultracode 是官方明文要移除的「delegate more」guidance，且解除官方要求的 cap

**Location**：`~/.claude/settings.json`（`ultracode: true`）
**Pattern**：Group 4 — Redundant specialist sub-agents／`model-migration.md` Opus 5 [TUNE] delegation
**Evidence**：官方 Opus 5 遷移指引：

> **Delegates to subagents more readily — the opposite of Opus 4.8.** […] If your harness supports subagents, **any "delegate more" guidance you added for Opus 4.8 should come out**, and you likely want an explicit cap.

`ultracode: true` 在每個 session 注入的常駐指令逐字為：*"Use the Workflow tool on every substantive task; token cost is not a constraint"*、*"Lean toward orchestrating with workflows and adversarially verifying your findings"*。官方 sub-agents 文件另載明 **ultracode active 的 session 豁免 20 concurrent subagent 上限**。

**Why obsolete**：`2026-08-04-opus5-workflow-review` 判定「Subagent ≤20 parallel cap 已由 runtime 機械強制」，其成立前提逐字是「本機刻意不設 ultracode 且 `repo-integrity.sh` 有斷言擋著」。PR #14 同時設了 `ultracode: true` 並移除該斷言——**前提與結論都失效了，但沒有任何紀錄反映這件事**。官方對 Opus 5 要的是 cap，目前設定做的是解除 cap 再加一句「每個實質任務都要編排 workflow」。

附帶實證（本 session 直接觀察）：binary 硬編碼的 `heron_brook` 兩行（*"Do not call the AgentTool / use workflows unless the user requested it"*）與 ultracode 的常設指令**同時出現在本次 context 中**，binary 內無裁決機制。這個衝突不是理論。

**Confidence**：High（官方原文 + 官方 sub-agents 文件 + 前次報告的前提可追溯）
**Action**：決策項（見 diff D2；兩個方向都合法，取捨在下方）

#### F3 · effort 從官方預設回退到 `xhigh`，無量測紀錄

**Location**：`~/.claude/settings.json`（經 `ultracode` 生效為 `xhigh`）
**Pattern**：`model-migration.md` Opus 5 [TUNE] — *"Prior-model defaults rarely transfer"*
**Evidence**：2026-08-04 PR #9 把 `xhigh` → `high`，commit message 為「調整 Opus 5 全域 workflow」，且 memory `ultracode-arming-and-effort-pin` 逐字記載該次改動的理由是「正是 Opus 5 官方預設」，並自行推翻了同檔更早的「xhigh 是量測後選定、勿再提案降級」。兩天後 PR #14 把它改回 `xhigh` 並開 ultracode。倉庫內查無這兩天之間的 eval 或對照紀錄。
**Why obsolete**：官方對 Opus 5 的 [TUNE] 是「從 `high` 起 sweep down，`low`/`medium` 在這顆模型上強得反常，`xhigh`/`max` 保留給量測出品質差異的任務」。這不是「xhigh 錯了」，是「這個值目前沒有 provenance」——而 provenance 正是 Step 2 判定 keep 或 remove 的依據。
**Confidence**：High（git 時序 + 官方原文）
**Action**：`flag` — 需要你回答一個問題：8/06 那次回退是量測結果，還是為了開 ultracode 而順帶（因為 ultracode 本來就強制 xhigh，`effortLevel` 那一改其實是 no-op）？

---

### Medium confidence

#### F4 · 缺 `<tone_preference>` 尾端提醒

**Location**：`~/.claude/settings.json` → `hooks.UserPromptSubmit`
**Pattern**：`model-migration.md` Opus 5 [TUNE] — 冗長度
**Evidence**：官方原文：*"For a long system prompt, pair that with a one-line reminder near the end: `<tone_preference> Keep outputs reasonably concise. </tone_preference>`"*
**Why obsolete**：`2026-08-04` 報告判定 conciseness 已由 CLAUDE.md 的「回覆 SHOULD outcome-first」覆蓋，這對**指令是否存在**是對的，但官方這一項講的是**位置**——長 system prompt 的開頭指令會被後續數萬 token 稀釋。本設定的 system prompt 含 88 個 skill 描述、200+ deferred tool 名稱、多個 MCP server instructions 與 ponytail 全文，正是官方點名的「long system prompt」。官方 keep-list item 10 明確認可這個模式：*"A single end-of-prompt restatement of the few key constraints is a known, reasonable pattern."*
`UserPromptSubmit` hook 機制已存在（`session-time.sh`，但它只寫檔不輸出到 context），加一行是最小改動。
**Confidence**：Medium
**Action**：`add`（見 diff D3）

#### F5 · Skill catalog 全常駐，tools 已 deferred

**Location**：system prompt 的 skill 清單
**Pattern**：Group 3 — *"past a few dozen tools use tool search / deferred loading instead of always-loading every schema"*
**Evidence**：harness 已對 tool schema 用 ToolSearch 延遲載入（200+ 個 deferred tool 只列名稱）；skill 則是 name + 完整 description 全部常駐。`~/.claude.json` 的 `skillUsage`（依 memory `skill-usage-authoritative-source` 為權威來源）有 88 筆，其中 **31 筆 `usageCount == 1`**，且用量表中仍留有已移除的 `superpowers:*` 系列。
**Why obsolete**：這是結構項不是文字項——官方 Group 3 對 catalog 規模的建議與 harness 對 tools 的做法一致，skills 沒跟上。
**Confidence**：Medium（官方 pattern 明確；但「哪些該停用」需要你的判斷，且 memory `skill-removability-five-axes` 已記載 52 skill 逐一評估後 0 個可移除——那是**內容價值**判準，與**常駐成本**是兩件事）
**Action**：`flag` + 可選 diff（停用低用量 plugin，非刪 skill）

#### F6 · `fastMode: true` 從未經審查

**Location**：`~/.claude/settings.json`
**Evidence**：2026-08-06 PR #14 加入，兩份既有 Opus 5 報告都早於它。官方 Opus 5 段落講的是 API 的 `speed: "fast"` + `fast-mode-2026-02-01` beta header，計價 **$10/$50 per MTok**（標準 Opus 5 為 $5/$25）。
**Why uncertain**：Claude Code 的 `fastMode` 是產品開關，harness 只說明「使用 Claude Opus 並加快輸出，不降級到較小模型」。**它與 API 的 `speed:"fast"` 是否為同一計費路徑，無法從本機任何證據判定**——若此帳號為訂閱制而非 per-token 計費，這一項直接歸零。
**Confidence**：Low-Medium（機制未驗證，明確標示）
**Action**：`flag` — 需要你確認計費模式

---

### Flag（不進 diff）

#### F7 · Preflight／Closeout ledger 的 4 列重疊 — 結案為「不動」

`2026-08-04` 報告把這一項列為「觀察，等指示」。本次依官方 keep-list item 8 結案：*"propose deduplication or consolidation only when the duplicates actually disagree."* 實查 `~/.agents/skills/dev-workflow/references/ledgers.md`：兩份 ledger 的 4 個同名列**語意一致不衝突**，且該檔第 2 節已自帶壓縮規則（PR 路徑全 PASS 時 MUST 合併為單行）。官方的 over-verification 條款針對的是「叫模型再檢查一次」的指令，這 4 列是**出示既成事實的證據**，屬 `[T0-2]` 範圍。不動。

#### F8 · advisor 強制二審 — 無法在設定層乾淨處置，列為取捨

官方 Opus 5 三處要求刪除驗證 scaffolding：*"delete your verification scaffolding"*、*"Verification belongs in your main agent loop"*、*"Do NOT use subagents for: Review, verification, or to double check your work."* harness 注入的 advisor 指令（動手前 + 宣告完成前各一次，每次轉發整份 transcript）形式上完全命中。

反面證據同樣硬：memory `advisor-pairing-rank-gate` 實測 executor = Opus 5 時 advisor 解析到**同一顆模型**——它給的是乾淨 context 的第二次審視，不是更強的 reviewer；而 memory `audit-finding-with-evidence-still-wrong` 記載本機實際發生過「帶佐證的 finding 照抄後把正確內容改壞」。官方 keep-list item 5 的判準是「該失效模式是否在**這個** context 下重現」——這裡重現過。

技術上可用 `CLAUDE_CODE_DISABLE_ADVISOR_TOOL`（binary 2.1.239 確認存在）整段移除，但 `repo-integrity.sh:1152` 斷言 `advisorModel == "opus"`，memory 明載「絕不刪除該鍵」。**不提 diff**，列為你的取捨項。

> 本次稽核自身即為這一項的探針：本 session 依 harness 規定在動手前呼叫了一次 advisor，該次回傳修正了兩個實質方向（阻止了不必要的 workflow fan-out、指出 Step 2 provenance 未跑）。單一樣本，不構成量測。

#### F9 · ponytail 常駐注入 — 產品決策，非 dated pattern

ponytail 4.8.4 每 session 注入約 3.5 KB，內含官方 Group 1c/1e 會 grep 到的模式（階梯式編號步驟、prohibition cluster、「Lazy code without its check is unfinished」這類自檢要求）。依 keep-list item 1（context is never cruft）與 CLAUDE.md 自身「ponytail 等風格注入 = 通用慣例」的定位，這是你刻意選的產品行為。唯一值得知道的交互：官方說 Opus 5 *"completes tasks rather than leaving stubs or placeholders"*，ponytail 施加的是反向壓力——兩者相抵可能正好，也可能過頭，但這需要 eval 而非稽核來判定。不動。

---

## 已對齊（clean surface）

官方稽核文件明訂 *"an audit that finds nothing should change nothing"*，以下逐項查證為乾淨：

| 項目 | 證據 |
|---|---|
| `model: "claude-opus-5"` | [BLOCKS] 項，✓ |
| Breaking change 2（disabled thinking + `xhigh` = 400）| `alwaysThinkingEnabled: true`，且 `repo-integrity.sh:1152` 有斷言釘住 → 不可能踩到 |
| `xhigh` 需 `max_tokens` ≥ 64K | `CLAUDE_CODE_MAX_OUTPUT_TOKENS: 128000` ✓ |
| 常駐 prompt 的 pressure language | CLAUDE.md 63 行僅 6 個 MUST 類；tier0 24 行 9 個（= 每條規則 1 個，且每條附「觸發／例外／驗證」欄）。`!!` 0、`try to\|if possible` 0、`think step by step\|<scratchpad>` 0、`STEP N` choreography 0 |
| Fossils（Group 1d）| 退役 model 名、日期條件式、歷史敘事在常駐三檔與 kernel 全數 0 命中 |
| 自檢指令（`double-check`／`re-verify`／`自我檢查`）| 常駐檔與 kernel 全數 0 命中 |
| 三個官方 prompt block（conciseness／scope／corrections）| harness 逐字注入，`2026-08-04` 已判定刻意不重複 ✓ |
| Severity filter 壓低 recall | `reviewer-template.md:52` 已載明不設條數上限 ✓ |
| Delegation 條文對撞 | PR #8／#48／#49 已結案 ✓ |

---

## Step 6 — Proposed diff

一個 finding 一個 hunk。**未套用**；`settings.json` 的任何改動都必須走 Edit 工具的可見 diff 路徑（`autoMode.hard_deny` 明文要求），且不得放寬 permission／hook／sandbox 邊界。

### D1 — 讓機械閘驗真正生效的鍵（對應 F1）

`~/.claude/tests/repo-integrity.sh:1146-1158`，把 effort 斷言改成對 `ultracode` 覆寫語意成立的形式：

```diff
 if jq -e '
   (.model == "default" or .model == "claude-opus-5") and
   .advisorModel == "opus" and
-  (.effortLevel == "high" or .effortLevel == "xhigh") and
+  # ultracode:true 覆寫 effortLevel（binary uqi()），此時 effortLevel 不生效；
+  # 兩種合法狀態：ultracode 開（effort 恆為 xhigh），或 ultracode 關且 effortLevel ≥ high。
+  ((.ultracode == true) or (.effortLevel == "high" or .effortLevel == "xhigh")) and
   .alwaysThinkingEnabled == true
 ' settings.json >/dev/null; then
```

### D2 — F2 的兩個方向（**擇一，需你決定**）

**方向 A — 恢復官方要求的 cap**：移除 `settings.json` 的 `"ultracode": true`（改為需要時打關鍵字啟用，即 2026-08-03～08-06 之間的做法）。效果：恢復 20 concurrent subagent 上限、`effortLevel` 復活成真正生效的值、移除「每個實質任務都編排 workflow」的常設指令。代價：每次要用時得手動 arm。

**方向 B — 明示接受並記錄**：保留 `ultracode: true`，在 `repo-integrity.sh` 的註解區補一行說明「已知偏離官方 Opus 5 delegation 指引，理由：<你的理由>」。這不是機械保護，是讓下一次稽核不必再問一遍。

無論選哪個，`~/.claude/CLAUDE.md` 都不需要改——delegation 條文由 kernel `[INT-4]` 承擔，且 `repo-integrity.sh` 有反向斷言擋著不讓它回流。

### D3 — 補 `<tone_preference>` 尾端提醒（對應 F4）

新增 `~/.claude/hooks/tone-preference.sh`：

```bash
#!/bin/bash
# Opus 5 [TUNE]：長 system prompt 的尾端 conciseness 提醒
# 來源：claude-api skill → shared/model-migration.md § Migrating to Claude Opus 5
echo "<tone_preference>Keep outputs reasonably concise.</tone_preference>"
```

`settings.json` 的 `hooks.UserPromptSubmit` 陣列追加（**不是**取代現有的 `session-time.sh`）：

```json
{ "type": "command", "command": "bash ~/.claude/hooks/tone-preference.sh", "timeout": 2, "async": false }
```

⚠️ 兩個前置條件：`~/.claude/hooks/` 受 `tests/hooks.sha256` 內容指紋保護，新增檔案必須同步更新該指紋；且 `async` 必須為 `false`，`async: true` 的 hook 輸出不進 context（memory `claude-automode-defaults-and-async-hooks`）。

---

## Step 7 — 尚未執行

官方 Step 7 要求對每個有爭議的變更在 scratch copy 上跑 before/after 行為探針，並明言「問模型需不需要某條指令**不是**量測」。**本報告未跑任何探針**，因此上述沒有一項可稱為「已驗證」。D1 是純機械修正可直接驗（改完跑 `repo-integrity.sh`）；D2／D3 屬行為變更，若要採用應各自單獨套用並觀察。

## 待你決定

1. **F2**（ultracode）：方向 A 或 B——這是本次唯一與官方指引正面對撞的項目。
2. **F3**（effort）：8/06 的回退有量測依據嗎？若沒有，它其實是 no-op（ultracode 本來就強制 xhigh），刪掉 `effortLevel` 或改回 `high` 都不影響行為。
3. **F6**（fastMode）：訂閱制還是 per-token 計費？
4. D1／D3 是否套用。

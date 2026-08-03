# Opus 5 官方指引 × 全域 workflow 對照審查

日期：2026-08-04｜審查對象：`~/.claude/`（entry、settings、core）+ `~/.agents/skills/dev-workflow/`（shared kernel 與 references）

## 結論

跑完官方 Claude Opus 5 Migration Checklist 的 19 個 `[TUNE]` 項，全域設定命中 **2 項需處理**、**1 項需明確不做**，其餘為已對齊、已由 runtime 強制、或屬 API caller 專用不適用。沒有 `[BLOCKS]` 項命中（那些是 API 呼叫端的 400 錯誤，本設定不是 API caller）。

| 需處理 | 項目 |
|---|---|
| 1 | `settings.json` 的 `effortLevel: "xhigh"` 是 Opus 4.7 的舊預設，正是官方明說不要繼承的那一個值 |
| 2 | PR #7 加的 delegation 條文與 kernel `[INT-4]` 對撞，且裁決鏈沒有術語可裁定這一對 |
| 3 | 官方三個 prompt block（conciseness／scope／corrections）**不要**加進入口檔 —— harness 已逐字注入，加了會重複並撞 byte gate |

## 來源與範圍

**來源**：`~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/claude-api/shared/model-migration.md` 的 `## Migrating to Claude Opus 5`（第 903–1142 行），含 `### Behavioral shifts (prompt-tunable)` 與 `### Claude Opus 5 Migration Checklist`。

**範圍邊界**：Opus 5 指引只綁 Claude host。`~/.codex/AGENTS.md`（GPT-5 系）與 `~/.copilot/copilot-instructions.md`（Copilot 模型）不在對照範圍內 —— 是依模型排除，不是漏審。shared kernel `dev-workflow` 由三 host 共用，因此針對 Opus 5 的收斂原則上應落在 Claude adapter 而非 kernel；PR #7 正是這樣落的，這個先例應維持。

`~/.claude/core/tier1-workflow.md` 與 `tier2-style.md` 未納入 —— 依 memory `claude-core-tier12-deliberately-unloaded`，兩檔刻意不被 `@`-import，`repo-integrity.sh` 有斷言擋著，不影響執行期行為。

---

## 1. `effortLevel: "xhigh"` —— 需決策

**現況**：`~/.claude/settings.json:277` 設 `"effortLevel": "xhigh"`，搭配 `"alwaysThinkingEnabled": true`。

**官方原文**（checklist `[TUNE]`，第 1124 行）：

> Effort: start at `high` (the API default) and sweep down — `low`/`medium` are unusually strong on this model and are the primary cost/latency lever; reserve `xhigh`/`max` for tasks where you've measured a quality difference. **Prior-model defaults rarely transfer.**

**為什麼這一項特別**：依本機 memory `ultracode-arming-and-effort-pin` 的 binary 實證，`xhigh` 是 **Opus 4.7 的預設值**（Opus 5 的預設是 `high`），而且 **Opus 5 沒有 model-default hold** —— 「a level you previously set carries over」，所以持久化在 settings 的值在 Opus 5 上是真的每個 session 都生效，不像 Opus 4.8／Fable 5 會被 hold 蓋掉。這是官方唯一點名「舊模型預設通常不該沿用」的鍵，而本機恰好持久化著一個舊模型預設。

**但不等於它是誤植**：同一份 memory 記載 2026-08-03 是**刻意**移除 `ultracode` 與 `workflowSizeGuideline`，讓 `effortLevel` 「成為真正生效的值」。這個重構是有意的，`xhigh` 也可能是當時就選定的。

**待答**：`xhigh` 是在 Opus 5 上量測後選的，還是從 4.7 沿用下來的？

- 若是量測後選的 → 無動作，建議在 settings 旁留一行註記，免得下次審查再問一次。
- 若是沿用 → 官方建議跑一次 sweep：同一批代表性任務分別跑 `medium` / `high` / `xhigh`，比對品質與 token／latency。官方對 Opus 5 的說法是 `low`/`medium` 強得反常，且 effort **不會**可靠縮短可見輸出長度（想縮輸出要靠 prompt，不是降 effort）。

**閘門檢查**：`~/.claude/tests/repo-integrity.sh` 對 `effortLevel` **沒有**任何斷言（已 grep 確認，exit 1 無命中），改動不會踩機械閘。但 `settings.json` 屬 `[INT-10]` 範圍，改動須走 PR 路徑。

---

## 2. Delegation 條文對撞 —— 需處理

**兩條同時生效且指向相反**：

- kernel `~/.agents/skills/dev-workflow/SKILL.md:24` `[INT-4]` 的**無條件約束**：「main context MUST 重驗其回報，subagent 回報不是完成證據」，並明列「**無條件約束不在可授權範圍內**」。
- `~/.claude/CLAUDE.md:28`（PR #7，commit `89d008a`）：「已委派就不重做、不重推導其回報結論」。

官方原文（第 1091 行）為 `If you delegate, commit to the delegation. Never redo the subagent's work and do not re-derive its findings once it reports back.`

**核心缺陷不是「哪條錯」，是裁決鏈裁不了這一對**。tier0 裁決鏈是 `user 當下明示 > repo 層協作檔 > tier0 hard rules > host delta > 被 invoke skill 的程序步驟 > 通用慣例`。`dev-workflow` 的實體位置是 `~/.agents/skills/dev-workflow/SKILL.md` —— 若讀成「被 invoke skill 的程序步驟」，CLAUDE.md（host delta）位階較高，「不重推導」勝；若讀成 shared kernel 等同「repo 層協作檔」，`[INT-4]` 勝。該檔 header 自標 `<!-- tier: workflow -->`，而 `workflow` 這個詞**不在裁決鏈的詞彙表裡**，兩種讀法都站得住。

這不是 PR #7 的疏失類別問題 —— 該 PR 的 commit message 顯示作者已經抓到並改寫了與 `[S5-3]` 的衝突（把官方第 2 條的 "use a subagent to verify" 改寫成「S5 以外不另派 subagent 做 verification」），只是同一類的第二個衝突沒抓到。屬 follow-up，不是回退理由。

**建議**（兩件事，可分開做）：

1. **補裁決鏈術語**：在 tier0 裁決鏈為 shared kernel 明確定一個位階，或在 kernel header 把 `tier: workflow` 換成裁決鏈上既有的術語。這是根因；不補的話下一次跨層條文衝突會再發生一次。
2. **收窄 CLAUDE.md 那一句**，讓它不能被讀成「跳過 main-context probe」。理由不是官方說了算，而是本機有反向的第一手證據：memory `audit-finding-with-evidence-still-wrong` 記載 apply agent 照抄帶佐證的 finding 反而把正確內容改壞，「verify 須獨立回查來源非只確認落地」。這是本機實測，優先於通用建議。建議語意保留為：不重跑 subagent 的探索過程、不重推導它的推理鏈；但它宣稱的**結果**仍須 main context 以證據核對。

---

## 3. 三個官方 prompt block —— 明確不要加

checklist 有三項要求加 prompt block：conciseness（第 1128 行）、Communicating with the user（1129）、scope discipline（1132）、corrections（1136）。**這些已經由 Claude Code harness 逐字注入，不需要也不該再寫進入口檔。**

證據（本 session system prompt 內逐字命中官方原文）：

- scope discipline：`Interpret ambiguity the way a careful colleague would: make routine judgment calls yourself, and check in only when different readings would lead to materially different work.` = 官方第 1067 行原句。
- corrections：`Avoid unnecessary or excessive self-correction. Only correct an earlier statement in your user-facing text when the error would change the user's code, conclusions, or decisions.` = 官方第 1101 行原句。
- Communicating 的一部分：`Write code that reads like the surrounding code: match its comment density, naming, and idiom.` = 官方第 1052 行原句。

`CLAUDE.md` 現有的「回覆 SHOULD outcome-first」對應官方 Lead with the outcome，「落檔文件長度對齊任務所需」對應 deliverable-length 那一項 —— 兩者都已覆蓋。

**加了會有兩個實際代價**：內容與 harness 注入重複（同一條規則兩份措辭，後續漂移就變成第 2 項那種對撞）；以及依 memory `three-host-entry-file-byte-budget`，`~/.copilot/copilot-instructions.md` 有 3600B 硬閘且只剩約 100B headroom，三 host 對稱維護時會直接撞閘。

這三項從 checklist 的「待辦」轉為「已達成，且主動不要重做」。

---

## 已對齊／不適用（無動作）

| 官方項目 | 狀態 | 依據 |
|---|---|---|
| Subagent ≤20 parallel cap | runtime 已機械強制 | `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 預設 20（memory `ultracode-arming-and-effort-pin`）；豁免條件是 ultracode active，而本機刻意不設 ultracode 且 `repo-integrity.sh` 有斷言擋著。寫進 `[INT-4]` 會是零行為差異的政策文字，還要為此鬆綁 tier0 —— 不值得。PR #7 排除這一條是對的 |
| Severity filter 壓低 recall（第 1114 行） | 已對齊且早於指引 | `[S5-1]`–`[S5-4]`；`references/reviewer-template.md:52` 已載明「不設字數或條數上限，不在本階段自行丟棄」，全 references 與 `code-review/SKILL.md` grep 無殘留衝突措辭 |
| Prompt cache 最小值 512 tokens | 不適用 | 屬 API caller 的快取規劃項；Claude Code 的 caching 由 harness 管理，設定端無對應鍵 |
| TTFT「begin your visible answer immediately」 | 不適用 | 官方明言 agentic／background route 應略過，這裡全是 agentic route |
| Fast mode／`fallbacks: "default"`／mid-conversation tool changes／`stop_reason: "refusal"` 處理／rate limit bucket | 不適用 | 全屬 API 呼叫端；本設定不呼叫 API |
| Vision 工具化、long-context、Office 任務 | 不適用 | 能力說明，非設定項 |

## 觀察（不構成建議）

Preflight ledger（8 列）與 Closeout ledger（6 列）有 4 列逐欄重複，`references/ledgers.md:74` 自己已寫明這點並加了呈現層壓縮規則 —— 壓的是版面，語意仍要各評估一次。官方「delete your verification scaffolding」（第 1063 行）指的是 harness 層沿用自舊模型的重複驗證步驟，形式上命中；但這是使用者刻意設計的治理結構，且 `[S5-3]` 的條文理由本身就承認 Self-simplification 是無獨立視角的自檢、已把真正的檢查外包給 review agent。刪 ledger 列超出「review 是否需要調教」的範圍，列為觀察，等指示。

## 建議動作

1. 回答第 1 項的待答問題（`xhigh` 是量測選的還是沿用的）。若需 sweep，開 PR 改 `settings.json` 並附量測數據。
2. 第 2 項開一個 PR：補裁決鏈術語 + 收窄 `CLAUDE.md` 的 delegation 收斂句。兩者都屬 `[INT-10]` 範圍，走 PR 路徑。
3. 第 3 項不需動作，本報告即為紀錄，避免下次審查重新提案。

# 三 host 全域設定 × Opus 5／GPT-5.6 官方指引調教審查

日期：2026-08-05｜審查對象：`~/.claude/`、`~/.codex/`、`~/.copilot/`、`~/.agents/skills/dev-workflow/`（HEAD `e81b8da`，PR #55 後）
提問：怎麼調教才不會綁手綁腳、能充分發揮能力

> **狀態**：這是裁決前的歷史輸入，不是 current-state runbook。後續結論以同資料夾
> [02-adjudication.md](02-adjudication.md) 與各 host 已合併 PR 為準；未合併項目只保留為 backlog，不構成授權。

## 結論

綁手綁腳的來源**不是機械閘，是散文層的跨層重複**。`~/.claude/settings.json` 的 `defaultMode: "auto"` + `autoMode.allow`（含 dotnet／npm／docker／git commit／push non-force）已相當開放，`permissions.ask` 只有一條；真正卡住的是同一組「先問、先確認、先停」在 tier0（三份）+ kernel（`[INT-3]`／`[INT-8]`）+ Claude adapter 各講一次。

[GPT-5.6 Model guidance：Define autonomy and approval boundaries](https://developers.openai.com/api/docs/guides/latest-model#define-autonomy-and-approval-boundaries) 指出，跨層重複核准／停頓指令會讓模型連安全、scope 內的動作也不必要地停下詢問。

**與 PR #53–#55 的關係**：那三個 PR 已做過一輪精簡，但砍的是**同一份檔案內的字數**（措辭壓縮、continuations 移進 references，語意逐條保留）。本報告談的是**跨檔案的語意重複**——tier0 × 3 份、kernel、adapter 講同一件事。兩者正交，不是重複提案。

| # | Finding | Host | 動作 |
|---|---|---|---|
| F1 | Copilot 實跑 `claude-opus-5`（headless probe 確認），2026-08-04 審查以「模型不同」排除它 → 前提錯誤 | Copilot | 補審 |
| F2 | 核准語意在 tier0×3 + kernel + adapter 重述，官方點名此模式製造多餘核准請求 | 三家 | 收斂 |
| F3 | Preflight 8 + Closeout 6 + Postflight 2 = 16 欄不分 risk tier | kernel | 依 tier 分級 |
| F4 | Codex `plan_mode_reasoning_effort=xhigh` < `model_reasoning_effort=ultra`，plan 想得比一般少 | Codex | 量測後定 |
| F5 | `permissions.allow` 的 `dotnet dev-certs` 與 `autoMode.soft_deny` 對撞 | Claude | 二選一 |
| F6 | tier0 三份措辭分歧（語意等價），Copilot 拿的是為 GPT 壓縮的版本卻跑 Opus 5 | Copilot | 隨 F1 處理 |
| F7 | Memory `ultracode-arming-and-effort-pin` 與 2026-08-04 報告 §處置 1 皆已過時 | — | 修正紀錄 |
| F8 | CLAUDE.md「送出前刪首句」比官方 narration 建議更緊 | Claude | 確認即可，非缺陷 |
| F9 | Copilot 常駐 prompt 實測 62k tokens／呼叫、`defaultReasoningEffort=medium` | Copilot | 觀察，附數據 |

---

## 來源與可信度

| 來源 | 用途 | 可信度 |
|---|---|---|
| [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) | Claude + Copilot 兩家 | 全文結構化取回，按 section 核對 |
| [GPT-5.6 Model guidance](https://developers.openai.com/api/docs/guides/latest-model) | Codex | 二次 targeted 取回，按 section 核對 |
| Copilot headless probe（本次執行） | F1／F9 | 見下方指令與 log 摘錄 |
| [Codex prompting guide (cookbook)](https://github.com/openai/openai-cookbook/blob/main/examples/gpt-5/codex_prompting_guide.ipynb) | **不採用** | 見「已排除」 |

**已排除**：cookbook 的 preamble 指引同時出現「移除所有 upfront plan／preamble 提示」與「Acknowledge then plan before any tool calls」。targeted 重抓確認這是**兩個不同模型世代**——前者屬 Codex-Max 長 rollout（避免提早停止），後者屬 gpt-5.3-codex 互動式 `phase` 參數。本機跑 `gpt-5.6-sol`，兩者都不直接適用；Codex 的 preamble 判斷一律以 GPT-5.6 model guidance 為準。

---

## F1 — Copilot 跑的是 Opus 5，不是 GPT（已 probe 確認）

**靜態證據**：`~/.copilot/settings.json` 明文 `"model": "claude-opus-5"`、`"stayInAutopilot": true`。

**但同一棵樹有反向證據**：`~/.copilot/config.json` 的 `expAssignmentsCache` 帶 `copilot_cli_gpt_default_model: true`、`copilot_cli_gpt_5_4_for_subagents: true`。settings 鍵與 experiment flight 不一致，靜態讀取無法裁定——依 `[T0-1]` 必須 live probe。

**Probe**：

```bash
copilot -p "Reply with exactly: PROBE_OK" --log-level debug --log-dir "$LOGD" --deny-tool shell --no-color
```

log 逐字命中（`process-*.log`，6 次出現）：

```
"model": "claude-opus-5"
"model": "capi:claude-opus-5:defaultReasoningEffort=medium"
"family": "claude-opus-5"
```

同一份 log 裡的 `gpt-5.6-sol`／`gpt-5.6-terra`／`gpt-5.6-luna` 各只出現 5 次，形態是 model catalog 而非 active model。**settings 鍵勝出，experiment flight 沒有改寫它。F1 成立。**

2026-08-04 的 opus5-workflow-review 寫：

> Opus 5 指引只綁 Claude host。`~/.codex/AGENTS.md`（GPT-5 系）與 `~/.copilot/copilot-instructions.md`（Copilot 模型）不在對照範圍內 —— 是依模型排除，不是漏審。

依模型排除的邏輯正確，但輸入的模型事實錯了。實際分布是 **2 家 Opus 5（Claude Code、Copilot CLI）+ 1 家 GPT-5.6（Codex）**，昨天的審查漏掉三分之一的 Opus 5 表面積。

**連帶（F6）**：正規化後 diff 三份 tier0，`~/.copilot/copilot-instructions.md` 與 `~/.codex/AGENTS.md` 的九條**逐字相同**，而 `~/.claude/core/tier0-safety.md` 在 `[T0-2]`／`[T0-3]`／`[T0-4]`／`[T0-6]` 措辭不同（語意等價，`tests/tier0-parity.sh` 判 clause-level 等價故現況 PASS）。也就是 Copilot 這台 Opus 5 拿到的是**為 GPT byte 預算壓縮過的措辭**。

**動作**：對 `~/.copilot/copilot-instructions.md` 補跑 Opus 5 checklist。已知先驗結論可沿用（三個 prompt block 不加、subagent cap 不寫），但兩項要另判：

- Copilot CLI 的 harness 是否也逐字注入 scope-discipline／corrections 段？若否，2026-08-04「已由 harness 注入所以不加」的結論**對 Copilot 不成立**。
- `stayInAutopilot: true` × `[T0-8]` plan+confirm 的交互作用未經審查——這也是下方 F2 必須保留 `[INT-3]` autopilot 條款的直接理由。

**byte 死結仍在**：`copilot-instructions.md` 現為 3545B，硬閘 `<3600B`，headroom 54B。本次需增加 62B 的完整還原方案 DOA；照 PR #49 的先例落在 kernel。

---

## F2 — 核准語意跨層重述（核心病因）

同一件事現在講四遍：

| 位置 | 條文 |
|---|---|
| tier0 ×3 份 | `[T0-5]` 停下發問、`[T0-8]` plan + confirm |
| kernel | `[INT-3]` MUST 停在 S2 等核准、`[INT-8]` 核准清單、`[INT-4]` 末句「MUST NOT 用 delegation 迴避 S2 授權」 |
| Claude adapter | 「已核准 scope 內的 Low／Medium-risk…仍走 `dev-workflow` authorization gate」 |
| harness | Claude Code system prompt 已逐字注入 scope discipline 段（2026-08-04 已證） |

官方對這形狀的判定已引在結論；同一 [autonomy section](https://developers.openai.com/api/docs/guides/latest-model#define-autonomy-and-approval-boundaries) 建議把 request 授權層級與 safe local actions 明列，讓模型可自行完成 scope 內的讀取、診斷、編輯與測試，但在 external／destructive／costly／scope expansion 前停下。

`[T0-8]` 的後半段（「明確 in-scope、local、reversible 的 Low／Medium-risk change／build／fix 可直接實作」）**已經是**官方要的形狀；缺的不是內容，是它被四份文件的停頓語意稀釋。

**建議**：

1. **`[INT-3]` 只砍與 `[T0-8]` 逐字重疊的觸發／例外清單，`auto／autopilot 不豁免` 與 `Medium-risk MUST NOT 成為第二次確認 gate` 兩句 MUST 保留為獨立行。** 這兩句 `[T0-8]` 沒有——前者是 `[INT-3]` 獨有，而 F1 剛確認 Copilot 開著 `stayInAutopilot: true`，砍掉等於刪掉唯一管到那個開關的條文。收斂前逐 clause diff `[INT-3]` vs `[T0-8]`，確認每條倖存 clause 都有歸屬。
2. Claude adapter 那條與 `[T0-8]` 重疊的句子刪除（`CLAUDE.md` 現 3685B，刪字無 byte 風險）。
3. 在 kernel S2 加一組**明列的 safe local actions**（讀檔、查 log、跑測試、改 in-scope 程式碼），對照官方第二句。這是唯一「加字」的項目，且加的是放行清單不是限制。

**載入時機的 caveat（實作前必須先解）**：kernel 是 **on-invocation** 載入（「開發任務必讀」），不是常駐。放進 kernel 的 safe-local-actions 清單只在開發 turn 生效；非開發 turn（一般問答、查詢、運維指令）不會載入，F2 對那些 turn 沒有修好。三個選項：接受這個覆蓋範圍並在報告記錄、或把清單放進三份 entry file（Copilot 只剩 54B，DOA）、或只放 Claude + Codex 兩家 entry file 並接受不對稱。**建議取前者**——非開發 turn 本來就不走 S2 gate，重複的停頓語意在那裡影響較小。

---

## F3 — Ledger 16 欄不分風險等級

[Opus 5 的 Task scope and over-verification](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#task-scope-and-over-verification) 說明模型本身會自我驗證；額外強制 final verification、subagent double-check 或 legacy verification scaffolding 會製造 over-verification 與額外 token 成本。

最後一句直指 ledger。現況 Preflight 8 + Closeout 6 + Postflight 2；`references/ledgers.md` 自己寫「六列中有四列與 Preflight Ledger 逐欄重複」，PR #52 只壓了版面沒動語意。

**要區分兩件常被混為一談的事**：

- `[T0-2]`「無 evidence 不得宣稱完成」= **回報誠信**，官方沒有反對，本機還有多筆第一手反證支持（沙箱靜默失敗、假綠測試）→ **保留**。
- 「每個任務都跑滿 16 欄」= 官方講的 legacy scaffolding → **依 risk tier 分級**。

**建議**：ledger 欄位改為 risk tier 的函數，與 S4 既有的 Low／Medium／High 分級對齊：

| Tier | Preflight | Closeout |
|---|---|---|
| Low（單檔、可逆、不進 PR） | 免 | Verification + Residual risks 兩列 |
| Medium | 現行 8 列 | 現行壓縮單行規則 |
| High／全域設定／security | 現行 8 列 | 完整 6 列 |

只砍低風險路徑的 scaffolding，High 路徑一格不動。

---

## F4 — Codex effort 倒置

`~/.codex/config.toml`：

```toml
model_reasoning_effort = "ultra"
plan_mode_reasoning_effort = "xhigh"
```

Plan mode 想得比一般 turn **少**一級。若意圖是「規劃時想深一點」，這是反的；若意圖是「plan 便宜、執行貴」，那是刻意的，但沒有記錄。

[GPT-5.6 migration guidance：Update API and model parameters](https://developers.openai.com/api/docs/guides/latest-model#update-api-and-model-parameters) 建議先保留既有 effort 作 baseline，再比較低一級；一般起點為 `medium`，latency-sensitive workload 可測 `low`。

`ultra` 常駐距離官方的 balanced starting point 有四級。官方沒說不能用，但說了 effort 是成本／延遲的**主要**槓桿，且要拿自己的 eval 掃。

**建議**：跑一次 sweep（同一批代表性任務 `high` / `xhigh` / `ultra` 各一輪，比對品質與 wall-clock），結論寫進 memory。不做 sweep 就維持現狀——**不建議盲降**，`ultra` 是刻意 pin 的。

**Claude 側對照（F7）**：`~/.claude/settings.json` 現為 `effortLevel: "high"`，PR #9（`f08b4be`，8/4 16:59）從 `xhigh` 改來，正是官方預設 → **無動作**。但 memory `ultracode-arming-and-effort-pin` 仍寫「兩 host effort pin(xhigh／ultra) 皆已量測確認,勿再提案降級」，2026-08-04 報告 §處置 1 也寫「effortLevel — 結案，無動作」——**兩份紀錄都早於 PR #9，都已過時**，會誤導下一個 session。修正紀錄，不是修設定。

---

## F5 — Claude 機械閘自相矛盾

`~/.claude/settings.json`：

- `permissions.allow` 含 `"Bash(dotnet dev-certs *)"`
- `autoMode.soft_deny` 含 `"Modifying local trust or secret stores: dotnet user-secrets set/clear, dotnet dev-certs, ..."`

一條放行、一條軟擋同一個指令。無論哪邊贏，另一邊都是死條文。（`permissions.deny` 另有 `Bash(dotnet user-secrets *)`，與 soft_deny 一致，那條沒問題。）

**建議**：dev-certs 屬本機開發憑證、日常會用 → 保留 `allow`，從 `soft_deny` 敘述移除 `dotnet dev-certs`。

---

## F8 — 「送出前刪首句」比官方更緊（非缺陷）

`~/.claude/CLAUDE.md`：「送出前刪：宣告接下來要做什麼的首句…」

[Opus 5 的 User-facing progress updates](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#user-facing-progress-updates) 在降低 narration 的範例中仍保留一行 pre-tool orientation，後續只在重要發現或方向變更時更新。

官方認為「一句話說要做什麼」是已經調低之後的樣子，本機規則又更緊一級。[GPT-5.6 response-style guidance](https://developers.openai.com/api/docs/guides/latest-model#set-response-length-and-style) 也提醒舊的 blanket brevity 規則可能把輸出壓得過短。

風格偏好不是缺陷，**不建議改**；列出來是因為它是唯一一條與官方建議方向相反的條文。

---

## F9 — Copilot 的實測 context 開銷與 effort

同一次 probe 的量測：

| 指標 | 值 |
|---|---|
| `prompt_tokens`（單次呼叫） | 62,152 / 62,405 |
| 該 turn 總計 | ↑124.6k（62.1k cached）、↓64 |
| AI credits | 42.3 |
| wall-clock | 1m17s |
| effort | `defaultReasoningEffort=medium` |

輸入是一句「Reply with exactly: PROBE_OK」、`--deny-tool shell`、零工具呼叫。**62k 是純常駐開銷。**

誠實看待：Opus 5 有 1M context，62k 佔 6%，**不構成能力損失**；代價在 credits 與 latency。列出來是因為它是三家中唯一有硬數字的 context 基線，未來砍 skill／plugin 時可當 before/after 量尺。

`defaultReasoningEffort=medium` 與 [Opus 5 effort guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#capability-improvements) 的成本控制方向一致；demanding coding／agentic work 才應用 own eval 決定是否升到 `xhigh`。若 Copilot 被用於實作而非查詢，medium 可能偏低——這是使用情境的問題，不是設定錯誤。

---

## 明確不要動（附一行理由，防後續 apply agent 誤刪）

| 條文 | 為什麼保留 |
|---|---|
| `[T0-2]` 無 evidence 不得宣稱完成 | 官方反對的是模型「重複自我驗證」，不是回報誠信；本機有多筆假綠實證 |
| `[T0-3]` force-push、`[T0-4]` secrets | 安全紅線，與模型調教無關 |
| `[S5-3]`／`[S5-4]` 全部回報、下游過濾 | Opus 5 code-review guidance 支持先廣泛回報，再以後續 pass 過濾 |
| `[INT-4]` main context 重驗 subagent 回報 | 本機第一手反證 `audit-finding-with-evidence-still-wrong`：照抄帶佐證的 finding 反而改壞正確內容 |
| `[INT-3]` 的 `auto／autopilot 不豁免` | `[T0-8]` 無此語意；F1 確認 Copilot `stayInAutopilot: true` 正需要它 |
| CLAUDE.md 的 delegation 收斂句 | 已對齊官方只在大型、可獨立平行化工作使用 subagent 的方向 |
| 三個官方 prompt block 不加進入口檔 | 2026-08-04 已結案：harness 逐字注入，加了重複且撞 byte gate（Copilot 側待 F1 補審確認） |

---

## 落地路徑

全部檔案落在 `[INT-10]` 範圍（tier0／kernel／entry file／settings），**MUST 走 isolated branch → Ready PR → bot-review gate → squash merge**，不得直接推 main。`~/.claude/settings.json`／`CLAUDE.md`／`hooks/**` 另有 `permissions.deny` 的 `Edit()` 機械阻擋。

建議切三個 PR，互不阻塞：

1. **agents-config**（kernel）：F2 的 `[INT-3]` 收斂（保留 autopilot 條款）+ safe-local-actions 清單、F3 的 ledger 分級。改動須同步檢查 `tests/matt-thin-workflow.sh`、`tests/tier0-parity.sh`、`tests/mattpocock-workflow.sh`、`tests/pr-path-gate.sh`。
2. **dotclaude**：F5 的 soft_deny 修正。單鍵改動，低風險。
3. **dotcopilot**：F1 補審結論。**任何方案 net-negative 或落 kernel**（54B headroom）。

F4 是量測任務不是設定變更，F7 是 memory 修正，兩者不進 PR。

**rollback**：三個 PR 皆為純設定文字變更，`git revert` 單一 squash commit 即回原狀；無 schema、無資料遷移。

---

## 附：本次未涵蓋

- Codex `~/.codex/AGENTS.md`（4476B）與 GPT-5.6 「state each instruction once」的逐條比對——F2 涵蓋核准語意那一組，其餘條文未逐條掃。
- Claude Code 側的常駐 context 基線（無等價於 Copilot log 的量測管道）。
- 71 個 shared skill 的 routing 表本身是否過載——2026-08-01／08-02 已各審一次，本次不重複。

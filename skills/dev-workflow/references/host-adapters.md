# Host adapters

需將 workflow action、user-only command、提問、delegation、handoff 或 hook 對應到 active host 時載入。

Host adapter 對本 kernel 只可加嚴，MUST NOT 放鬆其 MUST 或無條件約束；放鬆需 user 當下明示。Matt skill body 的 `/skill-name` 只表示 skill routing；需要顯式 invocation 時，實際 command 前綴與啟動權限以本 reference 對應 host adapter 為準。

## Capability parity

三家等價以 capability 與各自 semantic anchors 判定，不要求 prose、檔案結構或 hash 相同。`^` 分隔同一 capability 必備的 clauses；此表是三家 parity 的 canonical mapping（測試的失敗訊息用的就是這個詞）。

本表有**兩個** consumer，比對語意不同，改動時兩邊都要顧：

- `tests/three-host-capability-parity.sh` — 全部五列，`grep -Fq` **子字串**比對。
- `tests/ponytail-host-parity.sh` — 只讀 CAP-PONYTAIL 那列，把 host 檔依 `[；。]` 切段後逐段**全等**比對。它嚴格得多：mapping 的 anchor 必須是某一整段，而不是某段的一部分。它的 selftest fixture 另有一份 CAP-PONYTAIL 的手抄本，改本表時會一起紅（2026-08-27 實測）。

anchor 與 host 實際措辭對不上時，改哪一邊的判準：**語意分歧改 host，措辭／標點差異改本表。** 前者是三家該一致的東西真的不一致——2026-08-27 曾出現 Codex 寫 `action-first` 而 Claude、Copilot 與本表 meaning 欄都是 `outcome-first`，該次改的是 `~/.codex/AGENTS.md`；後者是同一語意的各家寫法，例如 Codex 那一行整行用半形 `/`，本表 Codex 欄就跟著半形。兩個 matcher 都分不出這兩者，判準只能靠人。

<!-- capability-parity:start -->
```tsv
CAP-WORKFLOW	Shared workflow 是唯一方法來源	dev-workflow/SKILL.md^host-local prose 不複製 method	dev-workflow/SKILL.md^程序只由該 skill 維護	dev-workflow/SKILL.md^workflow 方法與 gates 唯一來源
CAP-LOCAL-AUTONOMY	安全、local、reversible 工作 MUST 一次執行至完成（[INT-8]）	local、reversible^MUST 一次執行至完成	local、reversible^MUST 一次執行至完成^可直接實作	local、reversible^MUST 一次執行至完成^可直接實作
CAP-DELEGATION	Delegation 由 AI 自主判定且無須先問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問
CAP-RESPONSE	Outcome-first 且決策列出 recommendation 與 trade-off	回覆 SHOULD outcome-first^編號選項／推薦／取捨	回覆 SHOULD outcome-first^編號選項/推薦/取捨	回覆 SHOULD outcome-first^編號選項／推薦／取捨
CAP-PONYTAIL	Plan／implement 套用 Ponytail 通用慣例	ponytail 等風格注入=通用慣例	ponytail=通用慣例	ponytail=慣例
```
<!-- capability-parity:end -->

Tier0 安全內容由 `tests/tier0-parity.sh` 驗；model、effort、permission 與 hook 是 host-local capability，不以跨 host 相同值判定；control-plane materialization 仍由 ownership tests 驗。

## S5 simplification apply outcome

Standards／Spec reviewer 保持 read-only；findings disposition 完成後由 main context 做一次 apply pass，只處理已核准 scope 與 `reviewer-template.md` 五條 over-engineering baseline。結果 MUST 記為 `changed` 或 `no-op`；`changed` 回 S4 並把 affected diff 重新納入 S5，避免 simplify output 繞過 [S5-1]；`no-op` 留明確 evidence。

## Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent；決策提問 = AskUserQuestion。
- 同一 ready frontier 上彼此獨立的 1–4 個 blocker MUST 合併在同一次 `AskUserQuestion`；dependent 題等前一批回答。Skip／dismiss MUST NOT 視為答案、核准或採用預設值。
- user-only skill command = `/<skill-name>`。
- S5 Standards／Spec outcomes 仍須覆蓋；是否平行與 subagent 數量依 [INT-4] 自主決定，review agent 保持 read-only；`uiux-reviewer` 是 Claude-only。
- 用專屬 review agent 不豁免 `references/reviewer-template.md`：豁免的是 prompt 區塊本身與「怎麼用」中以該區塊為前提的步驟，其餘各節對 Claude 一樣有約束力，MUST 在維護 `code-review` 的 baseline 或判 S5 EXIT 時讀。不在此列舉是哪幾節——列舉會漏，新增的節就掉在外面。這條與 `simplify` 綁定都不因專屬 agent 而豁免。
- 兩軸 findings 處理完後 MUST 跑 `simplify`（Claude-only）當 apply pass；`changed`／`no-op` 與重驗依共用 S5 simplification outcome。
- `ledgers.md` Preflight 要求的兩軸狀態行與 row 6 三欄／baseline 標題，在 Claude 側由 `~/.claude/hooks/guard-s5-ledger.sh`（PreToolUse，攔 `gh pr create`）機械檢查——缺項在開 PR 當下就被擋，不是事後才發現。兩軸皆 `SKIPPED` 走豁免路徑（沒跑審查就沒有記錄可填）。已知不修的破口：inline `--body` 時 `--title`／`--label` 的值也算進 body、`gh pr edit` 不在射程內；細節與理由寫在該檔註解。

## Codex

- plan = Plan Mode；todo = update_plan；子代理 = spawn_agent／wait_agent。
- user-only skill command = `$<skill-name>`。
- Codex native Local/Worktree Handoff 只移動同一 chat 與 code，MUST NOT 觸發 Matt `$handoff`；跨 session／agent 文件仍走 `$handoff`。
- `implement` 先用 `~/.agents/bin/agents-branch` 或 repo worktree 建 isolated branch；S6 用 PR heartbeat。
- S5 simplification mechanism = main-context explicit apply pass。
- Git guard 由 `~/.codex/hooks.json` 與 `~/.codex/rules/default.rules` 疊加，不能取代 tier0／CI。

## Copilot

- plan = `--mode plan`；todo = update_todo；子代理 = `task` 工具。
- user-only skill command = `/<skill-name>`。
- 命中 [T0-8] protected gate 時，非 plan mode 必須先提出計畫並取得核准。
- S5 適用且 working tree dirty 時，依 [INT-4] 由 AI 自主決定是否、何時及使用多少 read-only `task` 完成 Standards／Spec outcomes；clean／fixed-point review 才執行 `code-review`；simplification mechanism = main-context explicit apply pass。
- Copilot user-level Git guard MUST 位於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- 子代理沿用模型預設 effort；僅 hard debugging、security、migration 或高風險 review 升 `high`，`xhigh`／`max` 需量測證明收益。

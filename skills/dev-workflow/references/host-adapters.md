# Host adapters

需將 workflow action、user-only command、提問、delegation、handoff 或 hook 對應到 active host 時載入。

Host adapter 對本 kernel 只可加嚴，MUST NOT 放鬆其 MUST 或無條件約束；放鬆需 user 當下明示。Matt skill body 的 `/skill-name` 只表示 skill routing；需要顯式 invocation 時，實際 command 前綴與啟動權限以本 reference 對應 host adapter 為準。

## Capability parity

三家等價以 capability 與各自 semantic anchors 判定，不要求 prose、檔案結構或 hash 相同。`^` 分隔同一 capability 必備的 clauses；此表是 `tests/three-host-capability-parity.sh` 的 canonical mapping。

<!-- capability-parity:start -->
```tsv
CAP-WORKFLOW	Shared workflow 是唯一方法來源	dev-workflow/SKILL.md^host-local prose 不複製 method	dev-workflow/SKILL.md^程序只由該 skill 維護	dev-workflow/SKILL.md^workflow 方法與 gates 唯一來源
CAP-LOCAL-AUTONOMY	安全、local、reversible 工作 MUST 一次執行至完成（[INT-8]）	local、reversible^MUST 一次執行至完成	local、reversible^MUST 一次執行至完成^可直接實作	local、reversible^MUST 一次執行至完成^可直接實作
CAP-DELEGATION	Delegation 由 AI 自主判定且無須先問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問
CAP-RESPONSE	Outcome-first 且決策列出 recommendation 與 trade-off	回覆 SHOULD outcome-first^編號選項／推薦／取捨	回覆 SHOULD outcome-first^編號選項／推薦／取捨	回覆 SHOULD outcome-first^編號選項／推薦／取捨
```
<!-- capability-parity:end -->

Tier0 安全內容由 `tests/tier0-parity.sh` 驗；model、effort、permission 與 hook 是 host-local capability，不以跨 host 相同值判定；control-plane materialization 仍由 ownership tests 驗。

## Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent；決策提問 = AskUserQuestion。
- 同一 ready frontier 上彼此獨立的 1–4 個 blocker MUST 合併在同一次 `AskUserQuestion`；dependent 題等前一批回答。Skip／dismiss MUST NOT 視為答案、核准或採用預設值。
- user-only skill command = `/<skill-name>`。
- S5 Standards／Spec outcomes 仍須覆蓋；是否平行與 subagent 數量依 [INT-4] 自主決定，review agent 保持 read-only；`uiux-reviewer` 是 Claude-only。
- 用專屬 review agent 不豁免 `references/reviewer-template.md`：該檔的「五條 baseline 的設計註記」與「審查者 MUST 記錄」兩節對 Claude 一樣有約束力，MUST 在維護 `code-review` 的 baseline 或判 S5 EXIT 時讀。豁免的只有 prompt 區塊本身。
- 兩軸 findings 處理完後 MUST 跑 `simplify`（Claude-only）當 apply pass：兩軸只報不修，這一步會動手改 [S5-3] baseline 落到實體 code 的部分。它在 review gate 之後動手，產出的 diff 卻一樣進 PR，所以 MUST 回 S4 重驗**並**依 `references/ledgers.md` 的「Closeout 後的新 commit」把該 diff 觸及的檔案重新納入 S5——只回 S4 等於讓一批 code 繞過 [S5-1]。該 pass 未產生改動時無此義務，EXIT 判準見 `references/reviewer-template.md` 的「S5 EXIT 判準」。

## Codex

- plan = Plan Mode；todo = update_plan；子代理 = spawn_agent／wait_agent。
- user-only skill command = `$<skill-name>`。
- Codex native Local/Worktree Handoff 只移動同一 chat 與 code，MUST NOT 觸發 Matt `$handoff`；跨 session／agent 文件仍走 `$handoff`。
- `implement` 先用 `~/.agents/bin/agents-branch` 或 repo worktree 建 isolated branch；S6 用 PR heartbeat。
- Git guard 由 `~/.codex/hooks.json` 與 `~/.codex/rules/default.rules` 疊加，不能取代 tier0／CI。

## Copilot

- plan = `--mode plan`；todo = update_todo；子代理 = `task` 工具。
- user-only skill command = `/<skill-name>`。
- 命中 [T0-8] protected gate 時，非 plan mode 必須先提出計畫並取得核准。
- S5 適用且 working tree dirty 時，依 [INT-4] 由 AI 自主決定是否、何時及使用多少 read-only `task` 完成 Standards／Spec outcomes；clean／fixed-point review 才執行 `code-review`。
- Copilot user-level Git guard MUST 位於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- 子代理沿用模型預設 effort；僅 hard debugging、security、migration 或高風險 review 升 `high`，`xhigh`／`max` 需量測證明收益。

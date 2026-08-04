# Host adapters

需將 workflow action、user-only command、提問、delegation、handoff 或 hook 對應到 active host 時載入。

Host adapter 對本 kernel 只可加嚴，MUST NOT 放鬆其 MUST 或無條件約束；放鬆需 user 當下明示。Matt skill body 的 `/skill-name` 只表示 skill routing；需要顯式 invocation 時，實際 command 前綴與啟動權限以本 reference 對應 host adapter 為準。

## Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent；決策提問 = AskUserQuestion。
- 同一 ready frontier 上彼此獨立的 1–4 個 blocker MUST 合併在同一次 `AskUserQuestion`；dependent 題等前一批回答。Skip／dismiss MUST NOT 視為答案、核准或採用預設值。
- user-only skill command = `/<skill-name>`。
- S5 Standards／Spec outcomes 仍須覆蓋；是否平行與 subagent 數量依 [INT-4] 自主決定，review agent 保持 read-only；`uiux-reviewer` 是 Claude-only。

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

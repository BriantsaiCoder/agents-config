# Codex CLI — hooks 註冊指南

Codex CLI 的 hooks 可註冊在 `.codex/config.toml`（專案）或 `~/.codex/config.toml`（全域）的 inline TOML，也可由 Codex hooks JSON 載入。事件名 PascalCase（`PreToolUse`、`PostToolUse`、`SessionStart`、`Stop` 等）。**不**提供逐 hook 實體 TOML 檔——格式差異由本指南即時轉換。

> Schema 已查證（2026-05，OpenAI Codex 官方 docs）。套用前建議以本機 `codex` 版本 docs 比對，鍵名隨版本可能微調。

## 重要差異 — matcher 語意

Codex 的 hook `matcher` 是 **regex 字串**：

- `PreToolUse` / `PostToolUse` / `PermissionRequest`：比對 tool name。可用 `^Bash$`、`^apply_patch$`、`Edit|Write`、或 MCP tool name regex。
- `SessionStart`：比對 start source，常見為 `startup|resume|clear`。
- `UserPromptSubmit` / `Stop`：目前不支援 matcher；設定了也會被忽略。
- 省略 `matcher`、空字串、或 `"*"` 代表所有支援事件都觸發。

## 套用步驟（SKILL.md Phase 5）

1. 把 `../*.sh`（6 支共用腳本本體）複製到專案的 `.codex/hooks/`，`chmod +x`。
2. 由執行中的 agent 用自身 Edit 工具，把下方區塊**增量合併**進 `.codex/config.toml`（既有 `[[hooks.*]]` 表保留、僅補新 entry），**先顯示 diff 再寫入**。
3. Repo-local hook command 建議用 `$(git rev-parse --show-toplevel)/.codex/hooks/...`，避免 Codex 從子目錄啟動時找不到相對路徑。

## TOML 範本

```toml
[[hooks.PreToolUse]]
matcher = "^(Edit|Write|apply_patch)$"
[[hooks.PreToolUse.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/protect-files.sh"'
statusMessage = "Checking protected files"

[[hooks.PostToolUse]]
matcher = "^(Edit|Write|apply_patch)$"
[[hooks.PostToolUse.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/auto-format.sh"'
statusMessage = "Formatting edited files"
[[hooks.PostToolUse.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/run-tests.sh"'
statusMessage = "Running focused tests"
[[hooks.PostToolUse.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/auto-api-docs.sh"'
statusMessage = "Checking API docs"

[[hooks.SessionStart]]
matcher = "startup|resume|clear"
[[hooks.SessionStart.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/compact-reminder.sh"'
statusMessage = "Loading project reminders"

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/notify.sh"'
```

> Codex 無 `Notification` 事件；`notify.sh` 僅掛 `Stop`。腳本的事件 `case` 對偵測不到事件名時不發通知（靜默結束），故安全。

## 否決訊號

`protect-files.sh` 偵測到 Codex host 時，對 stderr 寫 `{"decision":"block","reason":...}` 並 `exit 2`。Codex 的 blocking contract 可能隨版本調整 → 套用後建議實機驗證一次（嘗試編輯 `.env` 類檔案，確認會被擋下）。

> 腳本本體 host 無關（開頭 input shim 自行偵測 host）。本指南只負責「註冊」。

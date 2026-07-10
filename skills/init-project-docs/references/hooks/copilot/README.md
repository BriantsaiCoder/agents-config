# GitHub Copilot CLI — hooks 註冊範本

Copilot CLI 從 repo 的 `.github/hooks/*.json` 載入 hooks。JSON 使用 `version: 1` + `hooks` 物件；事件名使用 **camelCase**（如 `preToolUse`、`postToolUse`、`sessionStart`、`notification`、`agentStop`）。

## 套用步驟（SKILL.md Phase 5）

1. 把 `../*.sh`（6 支共用腳本本體）複製到專案的 `.github/hooks/scripts/`，需要啟用時再詢問使用者是否 `chmod +x`。
2. 把本目錄 `hooks.json` 複製到 `.github/hooks/init-project-docs-hooks.json`。既有 hook 檔以**新檔並存**、不覆蓋（Copilot 會載入該目錄所有 `*.json`）。

> Phase 2「設定」另產 `.github/hooks/guard-commands.json`（指令黑名單 guard hook，見 `references/settings-templates/copilot/README.md`）—— 與本檔並存。

## matcher 策略

Copilot hooks 支援 `matcher`，但 matcher 比對的是 Copilot runtime 的 tool id。這些 id 會隨 CLI 版本、IDE / extension surface、MCP 工具而變動；不要把 Claude Code 的 `Edit|Write` 或 shell 類 matcher 直接帶進 Copilot 註冊。

本範本刻意**省略 matcher**，讓 hook 先穩定觸發，再由共享腳本檢查 payload：

- `protect-files.sh`：一般工具沒有 `tool_input.file_path` / `toolArgs.path` 等路徑欄位時放行；例外是 patch 型工具（payload 含 `*** Begin Patch` 或 tool 名為 `apply_patch`）——解析不到 patch 目標路徑即拒絕（fail-closed）。
- `auto-format.sh`、`run-tests.sh`、`auto-api-docs.sh`：沒有目標檔案或檔案不存在時立即放行。
- `notify.sh`：只處理 notification / stop 類事件。

若要加 matcher，先用目前 Copilot CLI 的 `/env`、debug log 或官方文件確認 tool id，再寫 Copilot 專用 matcher；不要回填到 Claude / Codex 註冊。

## 事件對照（Claude → Copilot）

| 腳本 | Claude 事件 | Copilot 事件 |
|---|---|---|
| protect-files.sh | `PreToolUse` | `preToolUse` |
| auto-format.sh / run-tests.sh / auto-api-docs.sh | `PostToolUse` | `postToolUse` |
| compact-reminder.sh | `SessionStart`(compact) | `sessionStart`（Copilot 無 compact matcher → 每次 session 啟動皆跑；亦可改掛 `preCompact`） |
| notify.sh | `Notification`、`Stop` | `notification`、`agentStop` |

## 否決訊號

`protect-files.sh` 偵測到 Copilot host 時，對 stdout 寫官方 schema `{"permissionDecision":"deny","permissionDecisionReason":...}` 並 `exit 2`（見腳本 `hook_block()`）。exit 2 是雙保險：舊版 CLI 若不認得 permissionDecision 欄位，非零退出碼仍會被視為 hook 失敗而非默許放行。payload 內 `hook_event_name` 仍可能是 PascalCase，腳本的事件 `case` 需同時相容兩種寫法。

> 腳本本體 host 無關（開頭 input shim 自行偵測 host）。本檔只負責「註冊」。

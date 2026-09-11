# Claude Code — hooks 註冊範本

Claude Code 的 hooks 註冊在 `.claude/settings.json` 的 `hooks` 物件（PascalCase 事件名、`matcher` 為工具名正則）。

## 套用步驟（SKILL.md Phase 5）

1. 把 `../*.sh`（6 支共用腳本本體）複製到專案的 `.claude/hooks/`，`chmod +x`。
2. 把本目錄 `settings-hooks.json` 的 `hooks` 區塊**合併**進 `.claude/settings.json` —— 用 `scripts/merge-settings.py`（wrapper metadata 相同時聯集內層 hooks；metadata 不同時各自保留）。

```bash
python3 scripts/merge-settings.py .claude/settings.json references/hooks/claude/settings-hooks.json -o .claude/settings.json
```

## 事件對照

| 腳本 | 事件 | matcher |
|---|---|---|
| protect-files.sh | `PreToolUse` | `Edit\|Write` |
| auto-format.sh / auto-api-docs.sh | `PostToolUse` | `Edit\|Write` |
| run-tests.sh（僅有 repo-defined `AGENT_TEST_COMMAND` 時註冊） | `PostToolUse` | `Edit\|Write` |
| compact-reminder.sh | `SessionStart` | `compact` |
| notify.sh | `Notification`、`Stop` | （無） |

> 腳本本體 host 無關（開頭 input shim 自行偵測 host）。本檔只負責「註冊」。

`settings-hooks.json` 不預設註冊 `run-tests.sh`。只有 repo 明載不需猜測 target 或 build state 的
focused-test command 時，才增加 hook，例如
`AGENT_TEST_COMMAND='npm run test:related -- "$AGENT_TEST_FILE"' .claude/hooks/run-tests.sh`。
hook 提供 `AGENT_TEST_FILE` 與 `AGENT_TEST_ROOT`；實際 command 以 repo 文件／CI 為準。

# Claude Code — hooks 註冊範本

Claude Code 的 hooks 註冊在 `.claude/settings.json` 的 `hooks` 物件（PascalCase 事件名、`matcher` 為工具名正則）。

## 套用步驟（SKILL.md Phase 5）

1. 把 `../*.sh`（6 支共用腳本本體）複製到專案的 `.claude/hooks/`，`chmod +x`。
2. 把本目錄 `settings-hooks.json` 的 `hooks` 區塊**合併**進 `.claude/settings.json` —— 用 `scripts/merge-settings.py`（`hooks` 以 matcher 為鍵聯集，不覆蓋使用者既有 entry）。

```bash
python3 scripts/merge-settings.py .claude/settings.json references/hooks/claude/settings-hooks.json -o .claude/settings.json
```

## 事件對照

| 腳本 | 事件 | matcher |
|---|---|---|
| protect-files.sh | `PreToolUse` | `Edit\|Write` |
| auto-format.sh / run-tests.sh / auto-api-docs.sh | `PostToolUse` | `Edit\|Write` |
| compact-reminder.sh | `SessionStart` | `compact` |
| notify.sh | `Notification`、`Stop` | （無） |

> 腳本本體 host 無關（開頭 input shim 自行偵測 host）。本檔只負責「註冊」。

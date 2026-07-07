#!/usr/bin/env bash
# Notification + Stop hook — 等待確認 / 任務完成時的 macOS 通知
# 觸發：Notification（agent 等待輸入）、Stop（任務結束）
#       各 host 的事件名與註冊方式見 references/hooks/<host>/。
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。
#       偏 UX 用途，亦可放各 host 全域目錄使用。

set -uo pipefail

# ---- host-agnostic hook shim ----
HOOK_INPUT="$(cat 2>/dev/null || true)"
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }

if   [[ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]]; then HOOK_HOST=claude
elif [[ -n "${CODEX_HOME:-}${CODEX_SANDBOX:-}" ]];          then HOOK_HOST=codex
elif [[ -n "${COPILOT_HOME:-}${COPILOT_AGENT:-}" ]];        then HOOK_HOST=copilot
else HOOK_HOST=unknown
fi

# payload 內 hook_event_name 各 host 皆 PascalCase；退回 env。
HOOK_EVENT="$(_hj '.hook_event_name')"
[[ -z "$HOOK_EVENT" ]] && HOOK_EVENT="${HOOK_EVENT_NAME:-}"
HOOK_MESSAGE="$(_hj '.message')"
# ---- end shim ----

# 通知標題依 host 顯示
case "$HOOK_HOST" in
  claude)  TITLE="Claude Code" ;;
  codex)   TITLE="Codex CLI" ;;
  copilot) TITLE="Copilot CLI" ;;
  *)       TITLE="AI Agent" ;;
esac

# 僅 macOS（osascript / afplay 不存在則靜默結束）
command -v osascript >/dev/null 2>&1 || exit 0

# 事件名同時相容 Stop / agentStop 等變體
case "$HOOK_EVENT" in
  Notification|notification)
    MSG="${HOOK_MESSAGE:-AI agent 正在等待你的確認}"
    MSG=$(printf '%s' "$MSG" | tr -d '"')
    osascript -e "display notification \"$MSG\" with title \"$TITLE\"" 2>/dev/null || true
    ;;
  Stop|agentStop|stop)
    osascript -e "display notification \"任務完成\" with title \"$TITLE\"" 2>/dev/null || true
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
    ;;
esac

exit 0

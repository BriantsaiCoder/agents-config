#!/usr/bin/env bash
# PreToolUse hook — 阻止編輯敏感檔案
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。

set -uo pipefail

# ---- host-agnostic hook shim ----
# 各 host 傳遞 hook 輸入的 stdin JSON 形狀與 env 慣例不同；本段正規化成統一變數。
HOOK_INPUT="$(cat 2>/dev/null || true)"

if   [[ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]]; then HOOK_HOST=claude
elif [[ -n "${CODEX_HOME:-}${CODEX_SANDBOX:-}" ]];          then HOOK_HOST=codex
elif [[ -n "${COPILOT_HOME:-}${COPILOT_AGENT:-}" ]];        then HOOK_HOST=copilot
else HOOK_HOST=unknown
fi

# 從 JSON payload 取欄位；jq 缺席或解析失敗回空字串（保守處理，不誤動作）。
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }

# 目標檔案路徑：各 host payload 鍵名不同，逐一嘗試後退回 env。
HOOK_FILE="$(_hj '.tool_input.file_path // .tool_input.path // .tool_input.filePath // .tool_input.target_file // .file_path // .path')"
[[ -z "$HOOK_FILE" ]] && HOOK_FILE="${CLAUDE_FILE_PATH:-${TOOL_FILE_PATH:-}}"

# 依 host 發出否決訊號。Copilot 走 stdout + exit 0；Claude/Codex 走 stderr + exit 2。
hook_block() {
  local reason="$1"
  case "$HOOK_HOST" in
    copilot)      printf '{"decision":"deny","reason":"%s"}\n' "$reason"; exit 0 ;;
    claude|codex) printf '{"decision":"block","reason":"%s"}\n' "$reason" >&2; exit 2 ;;
    *)            printf '%s\n' "$reason" >&2; exit 2 ;;
  esac
}
# ---- end shim ----

# 偵測不到目標檔案 → 放行（不誤擋）。
if [[ -z "$HOOK_FILE" ]]; then
  exit 0
fi

# 敏感檔案 pattern
PROTECTED_PATTERNS=(
  "\.env$"
  "\.env\.local$"
  "\.env\.production$"
  "secrets\.json$"
  "appsettings\.Production\.json$"
  "credentials\.json$"
  ".*\.pem$"
  ".*\.key$"
  ".*\.lock$"
  ".*\.sqlite$"
  ".*\.db$"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$HOOK_FILE" =~ $pattern ]]; then
    hook_block "敏感檔案不可編輯：$HOOK_FILE（若確定要改，先移除 protect-files.sh 內對應 pattern）"
  fi
done

exit 0

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

check_protected() {
  local f="$1" pattern
  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$f" =~ $pattern ]]; then
      hook_block "敏感檔案不可編輯：$f（若確定要改，先移除 protect-files.sh 內對應 pattern）"
    fi
  done
}

# patch 型工具（apply_patch）不帶 file_path 欄位，目標路徑藏在 patch 本體。
# payload 是 JSON 內嵌字串，行界為 \n 字面雙字元序列，路徑止於 \ 或 "。
if [[ -z "$HOOK_FILE" ]]; then
  if [[ "$HOOK_INPUT" == *'*** Begin Patch'* || "$(_hj '.tool_name // .tool // .toolName')" == "apply_patch" ]]; then
    PATCH_TARGETS="$(printf '%s' "$HOOK_INPUT" \
      | grep -oE '\*\*\* (Update File|Add File|Delete File|Move to): [^"\\]+' \
      | sed -E 's/^\*\*\* [^:]+: //; s/[[:space:]]+$//')"
    if [[ -z "$PATCH_TARGETS" ]]; then
      # fail-closed：patch 解析不到任何目標 → 保守拒絕，勿空值放行
      hook_block "apply_patch 解析不到目標路徑，保守拒絕（改用 Edit/Write，或檢查 patch 格式）"
    fi
    while IFS= read -r t; do
      [[ -n "$t" ]] && check_protected "$t"
    done <<< "$PATCH_TARGETS"
    exit 0
  fi
  # 非 patch 型工具且偵測不到路徑 → 放行（不誤擋）
  exit 0
fi

check_protected "$HOOK_FILE"

exit 0

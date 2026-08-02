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

# 解析器健康度。要判的不只是「jq 在不在」，還有「它真的讀得懂這份 payload 嗎」。
# hooks/guard-git-push.sh:62 的做法是 gate 在指派的 exit status（`! CMD=$(… | jq …)`），
# 那同時涵蓋兩種失效；只檢查 command -v 會漏掉第二種——實測 jq 存在但回非 0（壞掉的
# 安裝、權限問題）或 payload 是截斷的 JSON，jq 都回空字串，而空字串會讓下方 11 條
# pattern 一條都不匹配、直接走到放行分支（2026-08-02 S5 補測發現）。
HOOK_PARSE_OK=1
if [[ -n "$HOOK_INPUT" ]]; then
  if ! command -v jq >/dev/null 2>&1 ||
     ! printf '%s' "$HOOK_INPUT" | jq -e . >/dev/null 2>&1; then
    HOOK_PARSE_OK=0
  fi
fi

# 從 JSON payload 取欄位；jq 缺席或解析失敗回空字串。
# 注意「回空字串」本身不是保守處理——對阻擋型 hook 而言，空值會讓後續 pattern 一條
# 都不匹配而放行。空值的失敗方向由下方 HOOK_FILE 為空的分支負責收斂，不在這裡。
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }

# 目標檔案路徑：各 host payload 鍵名不同，逐一嘗試後退回 env（Copilot 用 toolArgs）。
HOOK_FILE="$(_hj '.tool_input.file_path // .tool_input.path // .tool_input.filePath // .tool_input.target_file // .toolArgs.path // .toolArgs.file_path // .file_path // .path')"
[[ -z "$HOOK_FILE" ]] && HOOK_FILE="${CLAUDE_FILE_PATH:-${TOOL_FILE_PATH:-}}"

# 依 host 發出否決訊號。Copilot 走 stdout permissionDecision（官方 schema）；Claude/Codex 走 stderr + exit 2。
# Copilot 同時 exit 2 當雙保險：schema 不被當版本認得時，非零退出碼仍可被視為 hook 失敗而非默許。
hook_block() {
  local reason="$1"
  case "$HOOK_HOST" in
    copilot)      printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$reason"; exit 2 ;;
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
      hook_block "敏感檔案不可編輯：${f}（若確定要改，先移除 protect-files.sh 內對應 pattern）"
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
  # 非 patch 型工具且偵測不到路徑。這裡有兩種原因，而它們的正確失敗方向相反：
  #   a) payload 本來就沒有路徑欄位 → 放行，不誤擋
  #   b) 解析器缺席，根本沒能力讀 payload → 無從判斷，必須 fail-closed
  #
  # 第一版把兩者都放行，於是 jq 不在 PATH 時整支 hook 靜默失效——實測餵
  # {"tool_input":{"file_path":"/repo/.env"}} 得 rc=0（放行）而非 rc=2（deny）。
  # 2026-08-02 稽核補測發現；同 repo 的 hooks/guard-git-push.sh 檔頭早已明訂相反
  # 方向：「jq 不可用或解析失敗時，對含 git+push 的 payload 保守拒絕（不得靜默放行）」。
  # 兩支 guard 對同一情境的處理不該相反。
  #
  # 只在「有 payload 但讀不懂」時擋：沒有 stdin（HOOK_INPUT 空）代表這不是 hook
  # 呼叫，擋它才是誤擋。判準用上方的 HOOK_PARSE_OK，涵蓋 jq 缺席與解析失敗兩者。
  if [[ "$HOOK_PARSE_OK" -eq 0 ]]; then
    hook_block "無法解析 hook payload，無從判斷目標是否為敏感檔案，保守拒絕。兩種可能：jq 不可用（確認已安裝且在 PATH 中），或 payload 不是合法 JSON（確認 host 傳入的 stdin 格式）"
  fi
  exit 0
fi

check_protected "$HOOK_FILE"

exit 0

#!/usr/bin/env bash
# PostToolUse hook — 編輯後自動格式化
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。

set -uo pipefail

# ---- host-agnostic hook shim ----
HOOK_INPUT="$(cat 2>/dev/null || true)"
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }
HOOK_FILE="$(_hj '.tool_input.file_path // .tool_input.path // .tool_input.filePath // .tool_input.target_file // .file_path // .path')"
[[ -z "$HOOK_FILE" ]] && HOOK_FILE="${CLAUDE_FILE_PATH:-${TOOL_FILE_PATH:-}}"
# ---- end shim ----

if [[ -z "$HOOK_FILE" ]] || [[ ! -f "$HOOK_FILE" ]]; then
  exit 0
fi

# 判斷副檔名決定工具
EXT="${HOOK_FILE##*.}"

case "$EXT" in
  ts|tsx|js|jsx|json|css|scss|md|yml|yaml)
    # 前端：prettier + eslint --fix
    if command -v npx >/dev/null 2>&1; then
      npx --no -- prettier --write --log-level silent "$HOOK_FILE" 2>/dev/null || true
      npx --no -- eslint --fix --quiet "$HOOK_FILE" 2>/dev/null || true
    fi
    ;;
  cs)
    # .NET：dotnet format
    if command -v dotnet >/dev/null 2>&1; then
      dotnet format --include "$HOOK_FILE" --verbosity quiet 2>/dev/null || true
    fi
    ;;
  py)
    # Python：ruff format + ruff check
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$HOOK_FILE" 2>/dev/null || true
      ruff check --fix --quiet "$HOOK_FILE" 2>/dev/null || true
    fi
    ;;
esac

exit 0

#!/usr/bin/env bash
# PostToolUse hook — 編輯路由 / API 檔後更新 API 文件
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。
# 設計：偵測到專案自帶的 API 文件產生指令則執行；否則提醒手動同步文件。
#       通用環境無法可靠地為任意框架自動產生 API 文件，故不硬產，改走「專案指令優先」。

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

# 僅在路由 / API / controller 檔觸發
if [[ ! "$HOOK_FILE" =~ /(routes?|controllers?|api|endpoints?)/ ]] \
   && [[ ! "$HOOK_FILE" =~ [Cc]ontroller\.(cs|ts|js)$ ]] \
   && [[ ! "$HOOK_FILE" =~ views\.py$ ]]; then
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# 優先：執行專案自帶的 API 文件指令（package.json script 名稱含 api/doc/openapi/swagger）
if [[ -f "$PROJECT_ROOT/package.json" ]] && command -v npm >/dev/null 2>&1; then
  SCRIPT=$(jq -r '.scripts | keys[]? | select(test("api.*doc|doc.*api|openapi|swagger"; "i"))' \
    "$PROJECT_ROOT/package.json" 2>/dev/null | head -1)
  if [[ -n "${SCRIPT:-}" ]]; then
    (cd "$PROJECT_ROOT" && npm run "$SCRIPT" --silent) 2>&1 | tail -10
    exit 0
  fi
fi

# 否則：提醒手動同步
echo "API 路由檔已變更（${HOOK_FILE}）— 請確認 docs/ARCHITECTURE.md 的路由總覽表與 docs/FEATURES.md 是否需同步更新。"
exit 0

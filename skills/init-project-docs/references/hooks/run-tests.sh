#!/usr/bin/env bash
# PostToolUse hook — 編輯原始碼後執行 repo 明載的 focused-test command
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。
# 設計重點：
#   - 只執行 AGENT_TEST_COMMAND，不猜 runner、target 或 build state
#   - 匯出 AGENT_TEST_FILE / AGENT_TEST_ROOT 給 repo command 定位
#   - debounce：同檔連續編輯 5 秒內只跑一次；hook 始終非阻擋

set -uo pipefail

# ---- host-agnostic hook shim ----
HOOK_INPUT="$(cat 2>/dev/null || true)"
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }
if [[ -n "$HOOK_INPUT" ]] &&
   { ! command -v jq >/dev/null 2>&1 ||
     ! printf '%s' "$HOOK_INPUT" | jq -e . >/dev/null 2>&1; }; then
  printf '[run-tests] NOT_RUN: hook payload is not parseable with jq\n'
  exit 0
fi
HOOK_FILE="$(_hj '.tool_input.file_path // .tool_input.path // .tool_input.filePath // .tool_input.target_file // .toolArgs.path // .toolArgs.file_path // .file_path // .path')"
[[ -z "$HOOK_FILE" ]] && HOOK_FILE="${CLAUDE_FILE_PATH:-${TOOL_FILE_PATH:-}}"
# ---- end shim ----

if [[ -z "$HOOK_FILE" ]]; then
  printf '[run-tests] NOT_RUN: hook payload has no usable file target\n'
  exit 0
fi
if [[ ! -f "$HOOK_FILE" ]]; then
  printf '[run-tests] NOT_RUN: target file does not exist\n'
  exit 0
fi

# 測試檔本身不 re-run，避免遞迴。
if [[ "$HOOK_FILE" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$HOOK_FILE" =~ /(tests|__tests__|spec)/ ]]; then
  printf '[run-tests] SKIPPED: test file edit\n'
  exit 0
fi

# 這是通用範本無法安全猜測的 repo contract。未設定時明示未執行，
# 不把「沒有找到我們猜的測試」假報成成功。
if [[ -z "${AGENT_TEST_COMMAND:-}" ]]; then
  printf '[run-tests] NOT_RUN: AGENT_TEST_COMMAND is not configured\n'
  exit 0
fi

# Debounce：5 秒內相同檔案與同一 command 略過。
DEBOUNCE_DIR="${TMPDIR:-/tmp}/agent-test-debounce"
mkdir -p "$DEBOUNCE_DIR"
HASH=$(printf '%s\0%s' "$HOOK_FILE" "$AGENT_TEST_COMMAND" | shasum -a 1 | cut -c1-16)
MARKER="$DEBOUNCE_DIR/$HASH"

if [[ -f "$MARKER" ]]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || stat -c %Y "$MARKER") ))
  if [[ "$AGE" -lt 5 ]]; then
    printf '[run-tests] SKIPPED: debounce active\n'
    exit 0
  fi
fi
touch "$MARKER"

FILE_DIR=$(cd "$(dirname "$HOOK_FILE")" && pwd -P)
AGENT_TEST_FILE="$FILE_DIR/$(basename "$HOOK_FILE")"
AGENT_TEST_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$FILE_DIR")
export AGENT_TEST_FILE AGENT_TEST_ROOT

TEST_OUTPUT=$(cd "$AGENT_TEST_ROOT" && bash -o pipefail -c "$AGENT_TEST_COMMAND" 2>&1)
TEST_RC=$?
if [[ -n "$TEST_OUTPUT" ]]; then
  printf '%s\n' "$TEST_OUTPUT" | tail -30
fi

if [[ "$TEST_RC" -eq 0 ]]; then
  printf '[run-tests] PASSED\n'
else
  printf '[run-tests] FAILED: command exited %s\n' "$TEST_RC"
fi

exit 0

#!/usr/bin/env bash
# PostToolUse hook — 編輯原始碼後執行 repo 明載的 focused-test command
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。
# 設計重點：
#   - 只執行 AGENT_TEST_COMMAND，不猜 runner、target 或 build state
#   - 匯出 AGENT_TEST_FILE / AGENT_TEST_ROOT 給 repo command 定位
#   - debounce：同檔連續編輯 5 秒內只跑一次；repo command 同步執行，hook 以 exit 0 回報結果

set -uo pipefail

# ---- host-agnostic hook shim ----
HOOK_INPUT="$(cat 2>/dev/null || true)"
_hj() { [[ -n "$HOOK_INPUT" ]] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$HOOK_INPUT" | jq -r "${1} // empty" 2>/dev/null || true; }
HOOK_FILE="${CLAUDE_FILE_PATH:-${TOOL_FILE_PATH:-}}"
if [[ -n "$HOOK_INPUT" ]] &&
   { ! command -v jq >/dev/null 2>&1 ||
     ! printf '%s' "$HOOK_INPUT" | jq -e . >/dev/null 2>&1; }; then
  if [[ -z "$HOOK_FILE" ]]; then
    printf '[run-tests] NOT_RUN: hook payload is not parseable with jq\n'
    exit 0
  fi
else
  PAYLOAD_FILE="$(_hj '[.tool_input.file_path?, .tool_input.path?, .tool_input.filePath?, .tool_input.target_file?, .toolArgs.path?, .toolArgs.file_path?, .file_path?, .path?] | map(select(type == "string" and length > 0)) | .[0] // empty')"
  [[ -n "$PAYLOAD_FILE" ]] && HOOK_FILE="$PAYLOAD_FILE"
fi
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
if [[ "$HOOK_FILE" =~ \.(test|spec)\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$ ]] ||
   [[ "$HOOK_FILE" =~ (^|/)[^/]*Tests?\.cs$ ]] ||
   [[ "$HOOK_FILE" =~ (^|/)(test_[^/]*|[^/]*_test)\.py$ ]] ||
   [[ "$HOOK_FILE" =~ (^|/)[^/]+_test\.go$ ]] ||
   [[ "$HOOK_FILE" =~ (^|/)(tests|__tests__|spec)/ ]]; then
  printf '[run-tests] SKIPPED: test file edit\n'
  exit 0
fi

# 這是通用範本無法安全猜測的 repo contract。未設定時明示未執行，
# 不把「沒有找到我們猜的測試」假報成成功。
if [[ -z "${AGENT_TEST_COMMAND:-}" ]]; then
  printf '[run-tests] NOT_RUN: AGENT_TEST_COMMAND is not configured\n'
  exit 0
fi

FILE_DIR=$(cd "$(dirname "$HOOK_FILE")" && pwd -P)
AGENT_TEST_FILE="$FILE_DIR/$(basename "$HOOK_FILE")"
AGENT_TEST_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$FILE_DIR")
export AGENT_TEST_FILE AGENT_TEST_ROOT

# Debounce：5 秒內相同檔案與同一 command 略過。
DEBOUNCE_DIR="${TMPDIR:-/tmp}/agent-test-debounce"
if ! mkdir -p "$DEBOUNCE_DIR" 2>/dev/null; then
  printf '[run-tests] NOT_RUN: unable to prepare debounce directory\n'
  exit 0
fi
HASH_OUTPUT=$(printf '%s\0%s\0%s' "$AGENT_TEST_ROOT" "$AGENT_TEST_FILE" "$AGENT_TEST_COMMAND" |
  cksum 2>/dev/null)
HASH_RC=$?
read -r HASH_CRC HASH_BYTES _ <<< "$HASH_OUTPUT"
if [[ "$HASH_RC" -ne 0 ]] ||
   [[ ! "${HASH_CRC:-}" =~ ^[0-9]+$ ]] ||
   [[ ! "${HASH_BYTES:-}" =~ ^[0-9]+$ ]]; then
  printf '[run-tests] NOT_RUN: unable to compute debounce key\n'
  exit 0
fi
HASH="${HASH_CRC}-${HASH_BYTES}"
MARKER="$DEBOUNCE_DIR/$HASH"

if [[ -f "$MARKER" ]]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || stat -f %m "$MARKER") ))
  if [[ "$AGE" -lt 5 ]]; then
    printf '[run-tests] SKIPPED: debounce active\n'
    exit 0
  fi
fi
if ! touch "$MARKER" 2>/dev/null; then
  printf '[run-tests] NOT_RUN: unable to create debounce marker\n'
  exit 0
fi

TEST_OUTPUT=$(cd "$AGENT_TEST_ROOT" && bash -o pipefail -c "$AGENT_TEST_COMMAND" 2>&1 | tail -30)
TEST_RC=$?
if [[ -n "$TEST_OUTPUT" ]]; then
  printf '%s\n' "$TEST_OUTPUT"
fi

if [[ "$TEST_RC" -eq 0 ]]; then
  printf '[run-tests] PASSED\n'
else
  printf '[run-tests] FAILED: command exited %s\n' "$TEST_RC"
fi

exit 0

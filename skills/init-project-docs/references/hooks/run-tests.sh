#!/usr/bin/env bash
# PostToolUse hook — 編輯原始碼後跑對應測試
# 掛載於工具：Edit | Write（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。
# 設計重點：
#   - debounce：同檔連續編輯 5 秒內只跑一次
#   - 只跑對應檔案的測試，不跑整套

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

# Debounce：5 秒內相同檔案略過
DEBOUNCE_DIR="${TMPDIR:-/tmp}/agent-test-debounce"
mkdir -p "$DEBOUNCE_DIR"
HASH=$(printf '%s' "$HOOK_FILE" | shasum -a 1 | cut -c1-16)
MARKER="$DEBOUNCE_DIR/$HASH"

if [[ -f "$MARKER" ]]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || stat -c %Y "$MARKER") ))
  if [[ "$AGE" -lt 5 ]]; then
    exit 0
  fi
fi
touch "$MARKER"

# 略過測試檔本身的 re-run（避免遞迴）
if [[ "$HOOK_FILE" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$HOOK_FILE" =~ /(tests|__tests__|spec)/ ]]; then
  exit 0
fi

EXT="${HOOK_FILE##*.}"

case "$EXT" in
  ts|tsx|js|jsx)
    # 推斷對應測試檔
    DIR=$(dirname "$HOOK_FILE")
    BASE=$(basename "$HOOK_FILE" ".$EXT")
    for candidate in \
      "$DIR/$BASE.test.$EXT" \
      "$DIR/$BASE.spec.$EXT" \
      "$DIR/__tests__/$BASE.test.$EXT"; do
      if [[ -f "$candidate" ]]; then
        npx --no -- vitest run "$candidate" 2>&1 | tail -30
        break
      fi
    done
    ;;
  cs)
    # 推斷對應 test project
    PROJECT_DIR=$(dirname "$HOOK_FILE")
    TEST_PROJ=$(find "$PROJECT_DIR" -name "*.Tests" -type d -maxdepth 3 | head -1 || true)
    if [[ -n "$TEST_PROJ" ]]; then
      dotnet test "$TEST_PROJ" --no-build --verbosity quiet --filter "FullyQualifiedName~$(basename "$HOOK_FILE" .cs)" 2>&1 | tail -20
    fi
    ;;
esac

exit 0

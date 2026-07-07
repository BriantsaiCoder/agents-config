#!/usr/bin/env bash
# SessionStart hook — compact 後重新注入專案關鍵規則
# 觸發：SessionStart matcher=compact（各 host 的註冊方式見 references/hooks/<host>/）
# 跨 host：Claude Code / Codex CLI / GitHub Copilot CLI 共用同一份腳本本體。

set -uo pipefail

# ---- host-agnostic hook shim ----
# host 偵測決定要讀哪個指令檔（CLAUDE.md / AGENTS.md / .github/copilot-instructions.md）。
if   [[ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]]; then HOOK_HOST=claude
elif [[ -n "${CODEX_HOME:-}${CODEX_SANDBOX:-}" ]];          then HOOK_HOST=codex
elif [[ -n "${COPILOT_HOME:-}${COPILOT_AGENT:-}" ]];        then HOOK_HOST=copilot
else HOOK_HOST=unknown
fi
# ---- end shim ----

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# 依 host 選指令檔；unknown 時退而逐一嘗試。
case "$HOOK_HOST" in
  claude)  CANDIDATES=("CLAUDE.md") ;;
  codex)   CANDIDATES=("AGENTS.md") ;;
  copilot) CANDIDATES=("AGENTS.md" ".github/copilot-instructions.md") ;;
  *)       CANDIDATES=("CLAUDE.md" "AGENTS.md" ".github/copilot-instructions.md") ;;
esac

INSTRUCTION_FILE=""
for c in "${CANDIDATES[@]}"; do
  if [[ -f "$PROJECT_ROOT/$c" ]]; then
    INSTRUCTION_FILE="$PROJECT_ROOT/$c"
    break
  fi
done

if [[ -z "$INSTRUCTION_FILE" ]]; then
  exit 0
fi

# 抽取關鍵規則段落（「關鍵規則」或「## Critical Rules」）
REMINDER=$(awk '
  /^## 關鍵規則|^## Critical Rules/,/^## /{
    if (/^## / && !match($0, /關鍵規則|Critical Rules/)) exit
    print
  }
' "$INSTRUCTION_FILE")

if [[ -n "$REMINDER" ]]; then
  cat <<EOF
=== 專案關鍵規則提醒（compact 後重新注入）===
$REMINDER

完整規則見：$INSTRUCTION_FILE
EOF
fi

exit 0

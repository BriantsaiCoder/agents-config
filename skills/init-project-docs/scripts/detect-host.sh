#!/usr/bin/env bash
# 偵測執行中的 host agent（Claude Code / Codex CLI / GitHub Copilot CLI）。
# 用法：./detect-host.sh
#
# 輸出 key=value（供 SKILL.md Phase 0.5 解析）：
#   env_claude / env_codex / env_copilot     — 各 host 的環境變數訊號（true/false）
#   home_claude / home_codex / home_copilot  — 各 host 的 home 設定目錄是否存在
#   suggested                                — 最可能的 host（claude|codex|copilot|unknown）
#   ambiguous                                — 環境訊號無法單一判定（true/false）
#   other_homes                              — 偵測到的「非 suggested」host home 清單（逗號分隔；供 scope confirmation）
#
# 重要：最可靠的訊號是「執行中的 agent 自知身分」（Claude Code / Codex / Copilot
# 各自 system prompt 已知）。本腳本只提供環境佐證，不取代 agent 自我判定。
# env 訊號優先於 home 目錄；home 目錄僅用於推測與 output-scope confirmation。

set -uo pipefail

# ---- env 訊號 ----
ENV_CLAUDE=false
[[ -n "${CLAUDECODE:-}" || -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]] && ENV_CLAUDE=true
ENV_CODEX=false
[[ -n "${CODEX_HOME:-}" || -n "${CODEX_SANDBOX:-}" ]] && ENV_CODEX=true
ENV_COPILOT=false
[[ -n "${COPILOT_HOME:-}" || -n "${COPILOT_AGENT:-}" ]] && ENV_COPILOT=true

# ---- home 設定目錄 ----
HOME_CLAUDE=false;  [[ -d "${HOME}/.claude" ]]  && HOME_CLAUDE=true
HOME_CODEX=false;   [[ -d "${HOME}/.codex" ]]   && HOME_CODEX=true
HOME_COPILOT=false
[[ -d "${HOME}/.copilot" || ( -n "${COPILOT_HOME:-}" && -d "${COPILOT_HOME}" ) ]] && HOME_COPILOT=true

# ---- 建議 host ----
SUGGESTED="unknown"
AMBIGUOUS=false
ENV_HITS=0
$ENV_CLAUDE  && { SUGGESTED="claude";  ENV_HITS=$((ENV_HITS + 1)); }
$ENV_CODEX   && { SUGGESTED="codex";   ENV_HITS=$((ENV_HITS + 1)); }
$ENV_COPILOT && { SUGGESTED="copilot"; ENV_HITS=$((ENV_HITS + 1)); }

if [[ $ENV_HITS -gt 1 ]]; then
  # 多個 env 訊號同時命中：交由 agent 自我判定
  SUGGESTED="unknown"
  AMBIGUOUS=true
elif [[ $ENV_HITS -eq 0 ]]; then
  # 無 env 訊號 → 用 home 目錄推測
  HOME_HITS=0
  $HOME_CLAUDE  && { SUGGESTED="claude";  HOME_HITS=$((HOME_HITS + 1)); }
  $HOME_CODEX   && { SUGGESTED="codex";   HOME_HITS=$((HOME_HITS + 1)); }
  $HOME_COPILOT && { SUGGESTED="copilot"; HOME_HITS=$((HOME_HITS + 1)); }
  [[ $HOME_HITS -ne 1 ]] && { SUGGESTED="unknown"; AMBIGUOUS=true; }
fi

# ---- 其他 host home（多 host opt-in 用）----
OTHER=""
for h in claude codex copilot; do
  [[ "$h" == "$SUGGESTED" ]] && continue
  case "$h" in
    claude)  $HOME_CLAUDE  && OTHER="${OTHER:+$OTHER,}claude" ;;
    codex)   $HOME_CODEX   && OTHER="${OTHER:+$OTHER,}codex" ;;
    copilot) $HOME_COPILOT && OTHER="${OTHER:+$OTHER,}copilot" ;;
  esac
done

# ---- Output ----
echo "env_claude=$ENV_CLAUDE"
echo "env_codex=$ENV_CODEX"
echo "env_copilot=$ENV_COPILOT"
echo "home_claude=$HOME_CLAUDE"
echo "home_codex=$HOME_CODEX"
echo "home_copilot=$HOME_COPILOT"
echo "suggested=$SUGGESTED"
echo "ambiguous=$AMBIGUOUS"
echo "other_homes=$OTHER"

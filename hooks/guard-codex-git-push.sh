#!/usr/bin/env bash
# Codex PreToolUse(Bash) guard — [T0-3] force-push 前置攔截。
# 攔截：任何非 lease force push；任何 force 變體推 main/master。
# 放行：非保護分支 --force-with-lease、一般 push。
set -uf

JQ="$(command -v jq 2>/dev/null || echo /opt/homebrew/bin/jq)"
INPUT="$(cat)"
CMD=$(printf '%s' "$INPUT" | "$JQ" -r '.tool_input.command // empty' 2>/dev/null) || CMD=""
[ -z "$CMD" ] && exit 0
case "$CMD" in *git*push*) ;; *) exit 0 ;; esac
CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""

deny() {
  local reason_json
  reason_json=$(printf '%s' "$1" | "$JQ" -R -s '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

check_target() {
  local target="${1##*:}"
  target="${target#refs/heads/}"
  case "$target" in
    main|master) deny "[T0-3] 禁止 force push（含 --force-with-lease）到 main/master。" ;;
  esac
}

check_seg() {
  local seg="$1" t target
  local IFS=$' \t\n'
  local -a toks=($seg) args=()
  local i seen_git=0 seen_push=0 has_force=0 has_lease=0 broad_refset=0
  for ((i = 0; i < ${#toks[@]}; i++)); do
    t=${toks[i]}
    if (( ! seen_push )); then
      [[ "$t" == git ]] && seen_git=1
      [[ $seen_git -eq 1 && "$t" == push ]] && seen_push=1
      continue
    fi
    case "$t" in
      --force-with-lease|--force-with-lease=*) has_lease=1 ;;
      -f|--force)                              has_force=1 ;;
      --all|--mirror)                          broad_refset=1 ;;
      --*|-*)                                  : ;;
      +*)                                      has_force=1; args+=("${t#+}") ;;
      *)                                       args+=("$t") ;;
    esac
  done
  (( seen_push )) || return 0
  (( has_force )) && deny "[T0-3] 禁用非 lease force push（--force / -f / +refspec）。非保護分支請改用 --force-with-lease。"
  (( has_lease )) || return 0
  (( broad_refset )) && deny "[T0-3] --force-with-lease 搭配 --all/--mirror 無法排除保護分支，已保守拒絕。"
  if (( ${#args[@]} >= 2 )); then
    for ((i = 1; i < ${#args[@]}; i++)); do
      check_target "${args[i]}"
    done
  else
    target=$(git -C "${CWD:-.}" symbolic-ref --short HEAD 2>/dev/null || true)
    [[ -z "$target" ]] && deny "[T0-3] --force-with-lease 未明示 refspec 且無法解析當前分支，請明示 origin <branch>。"
    check_target "$target"
  fi
  return 0
}

IFS=$'\n'
for seg in $(printf '%s' "$CMD" | tr ';|&' '\n\n\n'); do
  case "$seg" in *git*push*) check_seg "$seg" ;; esac
done
exit 0

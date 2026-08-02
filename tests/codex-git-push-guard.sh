#!/usr/bin/env bash
set -euo pipefail

GUARD=${GUARD:-"$HOME/.agents/hooks/guard-codex-git-push.sh"}
RULES=${RULES:-"$HOME/.codex/rules/default.rules"}
JQ="$(command -v jq)"
pass=0
fail=0

probe() {
  local expected="$1" command="$2" output
  output=$("$JQ" -nc --arg command "$command" --arg cwd "$PWD" \
    '{tool_input:{command:$command},cwd:$cwd}' | "$GUARD")
  if [[ "$expected" == deny ]]; then
    if printf '%s' "$output" | "$JQ" -e \
      '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' >/dev/null; then
      ((pass += 1))
      printf 'PASS deny  %s\n' "$command"
    else
      ((fail += 1))
      printf 'FAIL deny  %s -> %s\n' "$command" "$output"
    fi
  elif [[ -z "$output" ]]; then
    ((pass += 1))
    printf 'PASS allow %s\n' "$command"
  else
    ((fail += 1))
    printf 'FAIL allow %s -> %s\n' "$command" "$output"
  fi
}

probe allow "git status --short"
probe allow "git push origin main"
probe allow "git push --force-with-lease origin feat/safe"
probe deny "git push --force origin feat/unsafe"
probe deny "git push --force-with-lease origin main"
probe deny "git push --force-with-lease origin feat/safe HEAD:refs/heads/master"
probe deny "git push --force-with-lease --all origin"

policy_probe() {
  local expected="$1" output decision
  shift
  output=$(codex execpolicy check --rules "$RULES" -- "$@")
  decision=$(printf '%s' "$output" | "$JQ" -r '.decision // "none"')
  if [[ "$expected" == forbidden && "$decision" == forbidden ]]; then
    ((pass += 1))
    printf 'PASS policy deny  %s\n' "$*"
  elif [[ "$expected" == allowed && "$decision" != forbidden ]]; then
    ((pass += 1))
    printf 'PASS policy allow %s\n' "$*"
  else
    ((fail += 1))
    printf 'FAIL policy %s expected=%s actual=%s\n' "$*" "$expected" "$decision"
  fi
}

policy_probe allowed git push origin main
policy_probe allowed git push --force-with-lease origin feat/safe
policy_probe forbidden git push --force origin feat/unsafe
policy_probe forbidden git push --force-with-lease origin main
policy_probe forbidden git push origin master --force-with-lease

printf '%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
(( fail == 0 ))

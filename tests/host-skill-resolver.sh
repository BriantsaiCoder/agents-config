#!/usr/bin/env bash
set -uo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)}"
PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
CLAUDE_SKILLS="${CLAUDE_SKILLS_ROOT:-$HOME/.claude/skills}"
LOCK="$AGENTS/mattpocock-skills.lock"
pass=0
fail=0
unavailable=0

ok() { printf 'PASS: %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$*" >&2; fail=$((fail + 1)); }
na() { printf 'UNAVAILABLE: %s\n' "$*"; unavailable=$((unavailable + 1)); }

[ -f "$LOCK" ] || {
  bad "Matt lock missing: $LOCK"
  printf '%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
  exit 1
}

matt_count="$(grep -c '^skill=' "$LOCK")"

if [ ! -d "$CLAUDE_SKILLS" ]; then
  na "Claude resolver: $CLAUDE_SKILLS is not initialized"
else
  claude_bad=0
  while IFS='=' read -r key skill; do
    [ "$key" = skill ] || continue
    link="$CLAUDE_SKILLS/$skill"
    if [ ! -L "$link" ] ||
       [ "$(readlink "$link" 2>/dev/null)" != "../../.agents/skills/$skill" ]; then
      bad "Claude resolver mismatch: $skill"
      claude_bad=$((claude_bad + 1))
    fi
  done < "$LOCK"
  [ "$claude_bad" -eq 0 ] && ok "Claude resolver: $matt_count/$matt_count Matt skills"
fi

expected_user_only_count=0
codex_policy_count=0
while IFS='=' read -r key skill; do
  [ "$key" = skill ] || continue
  skill_file="$AGENTS/skills/$skill/SKILL.md"
  if [ ! -r "$skill_file" ]; then
    bad "Codex locked skill missing: $skill"
    continue
  fi
  rg -q '^disable-model-invocation:[[:space:]]*true$' "$skill_file"
  marker_rc=$?
  if [ "$marker_rc" -ne 0 ]; then
    [ "$marker_rc" -eq 1 ] || bad "Codex invocation marker unreadable: $skill"
    continue
  fi
  expected_user_only_count=$((expected_user_only_count + 1))
  policy="$AGENTS/skills/$skill/agents/openai.yaml"
  if [ ! -f "$policy" ] ||
     ! rg -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false$' "$policy"; then
    bad "Codex user-only policy mismatch: $skill"
    continue
  fi
  codex_policy_count=$((codex_policy_count + 1))
done < "$LOCK"
[ "$codex_policy_count" -eq "$expected_user_only_count" ] &&
  ok "Codex user-only policy: $codex_policy_count/$expected_user_only_count" ||
  bad "Codex user-only policy count: $codex_policy_count/$expected_user_only_count"
na "Codex resolver: this CLI version has no local skill-list command"

if ! command -v copilot >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  na "Copilot resolver: copilot or jq is unavailable"
else
  if ! copilot_json="$(cd "$PROJECT_ROOT" && copilot skill list --json 2>/dev/null)"; then
    bad "Copilot resolver command failed"
  else
    copilot_bad=0
    while IFS='=' read -r key skill; do
      [ "$key" = skill ] || continue
      entry_count="$(
        printf '%s\n' "$copilot_json" |
          jq --arg skill "$skill" '[.[] | select(.name == $skill)] | length'
      )"
      if [ "$entry_count" -ne 1 ]; then
        bad "Copilot resolver expected one effective skill: $skill"
        copilot_bad=$((copilot_bad + 1))
        continue
      fi
      source="$(
        printf '%s\n' "$copilot_json" |
          jq -r --arg skill "$skill" '.[] | select(.name == $skill) | .source'
      )"
      skill_path="$(
        printf '%s\n' "$copilot_json" |
          jq -r --arg skill "$skill" '.[] | select(.name == $skill) | .path'
      )"
      case "$source" in
        project)
          if ! diff -qr "$skill_path" "$AGENTS/skills/$skill" >/dev/null; then
            bad "Copilot project shadow drift: $skill"
            copilot_bad=$((copilot_bad + 1))
          fi
          ;;
        personal-agents)
          if [ "$skill_path" != "$HOME/.agents/skills/$skill" ] ||
             ! diff -qr "$skill_path" "$AGENTS/skills/$skill" >/dev/null; then
            bad "Copilot personal skill drift: $skill"
            copilot_bad=$((copilot_bad + 1))
          fi
          ;;
        *)
          bad "Copilot unexpected Matt skill source: $skill ($source)"
          copilot_bad=$((copilot_bad + 1))
          ;;
      esac
    done < "$LOCK"
    [ "$copilot_bad" -eq 0 ] &&
      ok "Copilot resolver and project shadows: $matt_count/$matt_count Matt skills"
  fi
fi

printf '%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]

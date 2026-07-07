#!/usr/bin/env bash
# Step 2 — Description trap detector.
# Usage: lint-descriptions.sh <skill-folder>
# Flags descriptions that summarize workflow (sequential verbs, "then", "by ...ing", "step/phase", numbered actions)
# instead of trigger conditions ("Use when ...").
set -euo pipefail

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

# Anti-pattern keywords (workflow summary smell).
# Looks for: explicit sequencing words, OR dash followed by 2+ imperative action verbs.
# Imperative verbs (workflow markers, not scope): write, run, dispatch, watch, refactor, build, deploy, configure, generate, execute, trigger, fire, restart, retry, fix, edit, commit, push, pull
IMP='(write|writes|run|runs|dispatch|dispatches|watch|watches|refactor|refactors|build|builds|deploy|deploys|configure|configures|generate|generates|execute|executes|trigger|triggers|fire|fires|restart|retry|fix|fixes|edit|edits|commit|commits|push|pull)'
TRAP_RE=", then |\bthen [a-z]+ (then|and)|\b(step|phase) [0-9]|\bdispatches? \w+ per\b|\bwatch it fail\b|—\s*${IMP}[a-z]* \w+, ${IMP}|\b${IMP} \w+ first, \w*${IMP}"

# Trigger-condition signal (good)
GOOD_RE='^[Uu]se when\b'

printf "%-3s %-40s %s\n" "TRAP" "SKILL" "DESCRIPTION"
printf "%-3s %-40s %s\n" "----" "-----" "-----------"

while IFS= read -r -d '' f; do
  name=$(basename "$(dirname "$f")")
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f" | sed -E "s/^['\"]//; s/['\"]$//")
  if [ -z "$desc" ]; then
    printf "%-3s %-40s %s\n" "MISS" "$name" "(no description field)"
    continue
  fi
  if echo "$desc" | grep -Eqi "$TRAP_RE"; then
    flag="YES"
  elif echo "$desc" | grep -Eq "$GOOD_RE"; then
    flag="-"
  else
    flag="?"
  fi
  short=$(echo "$desc" | cut -c1-100)
  printf "%-3s %-40s %s\n" "$flag" "$name" "$short"
done < <(find "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 | sort -z)

echo
echo "Legend: YES=workflow-summary trap candidate (read body & verify), ?=unclear, -=trigger-only OK, MISS=no description field"

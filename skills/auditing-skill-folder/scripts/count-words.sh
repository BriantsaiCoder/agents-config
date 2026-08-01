#!/usr/bin/env bash
# Step 1 — Token cost audit.
# Usage: count-words.sh <skill-folder>
# Output: effective-count  raw-word-count  cjk-chars  over-limit-marker  vendored-flag  skill-name
#
# DECLARED-TIERS: 200,500
# tests/word-budget.sh rejects dead tiers, pins locale-stable WORDS + 3/5*CJK, and proves files
# without CJK keep their original wc -w measurement (2026-08-01 A1/A4).
# VND is printed beside OVER because it gates execution, not assessment; see check-vendored.sh.
# Exit: 0 = scanned OK. 1 = bad folder. 2 = scanned nothing.
set -uo pipefail

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)
[ -n "${LIB_DIR:-}" ] && [ -r "$LIB_DIR/lib-vendored.sh" ] || {
  echo "Cannot locate lib-vendored.sh next to this script; run it by path, not via stdin." >&2; exit 1; }
# shellcheck source=lib-vendored.sh
. "$LIB_DIR/lib-vendored.sh"

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

# Skills the house loads on every development task, so their budget is tighter than the default.
# Membership is explicit because the previous name-pattern form went dead silently.
ALWAYS_LOADED="dev-workflow"

printf "%-7s %-7s %-6s %-4s %-5s %s\n" "EFF" "WORDS" "CJK" "OVER" "VND" "SKILL"
printf "%-7s %-7s %-6s %-4s %-5s %s\n" "-----" "-----" "-----" "----" "-----" "-----"

# Rows are collected first, then sorted — piping the loop directly into sort would run it in a
# subshell and lose the counter, silently disabling the empty-result guard below.
rows=""
total=0
while IFS= read -r -d '' f; do
  dir=$(dirname "$f")
  name=$(basename "$dir")
  total=$((total + 1))
  limit=500
  printf '%s\n' "$ALWAYS_LOADED" | tr ' ' '\n' | grep -Fxq "$name" && limit=200
  # A single unreadable file must not truncate the table (it used to abort the loop under set -e).
  if ! wc=$(LC_ALL=C wc -w <"$f" 2>/dev/null | tr -d ' ') || [ -z "$wc" ]; then
    rows="${rows}$(printf "%-7s %-7s %-6s %-4s %-5s %s (limit=%d)" \
      "ERR" "ERR" "?" "?" "$(vendored_flag "$dir")" "$name" "$limit")
"
    continue
  fi
  cjk=$(LC_ALL=C tr -dc '\343-\351' <"$f" 2>/dev/null | wc -c | tr -d ' ')
  [ -n "$cjk" ] || cjk=0
  eff=$((wc + cjk * 3 / 5))
  if [ "$eff" -gt "$limit" ]; then over="YES"; else over="-"; fi
  rows="${rows}$(printf "%-7s %-7s %-6s %-4s %-5s %s (limit=%d)" \
    "$eff" "$wc" "$cjk" "$over" "$(vendored_flag "$dir")" "$name" "$limit")
"
done < <(find -L "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 2>/dev/null | sort -z)

if [ "$total" -eq 0 ]; then
  echo
  echo "SCANNED NOTHING: no SKILL.md at depth 2 under '$FOLDER'. This is NOT a clean audit." >&2
  exit 2
fi
printf '%s' "$rows" | sort -k1,1 -nr
echo
echo "Legend: EFF=effective count gating OVER (WORDS + 3/5*CJK), WORDS=wc -w, CJK=CJK characters,"
echo "        OVER=exceeds the limit shown per row, ERR=unreadable, VND=vendored."
echo "A file with no CJK scores EFF==WORDS, so English measurement is unchanged. OVER+VND together"
echo "do NOT license an unrecorded Trim — an in-place structural edit needs a recorded override."

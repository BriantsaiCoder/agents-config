#!/usr/bin/env bash
# Step 1 — Token cost audit.
# Usage: count-words.sh <skill-folder>
# Output: word-count  over-limit-marker  vendored-flag  skill-name
# Threshold: 500 (default), 200 (if name matches frequently-loaded pattern), 150 (getting-started).
# VND column is co-located on purpose: an over-limit count reads as "Trim me", and for a vendored
# skill that verdict is illegal (see check-vendored.sh). The constraint must be visible on the
# same line as the signal that provokes it.
# Exit: 0 = scanned OK. 1 = bad folder. 2 = scanned nothing.
set -uo pipefail

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)
[ -n "${LIB_DIR:-}" ] && [ -r "$LIB_DIR/lib-vendored.sh" ] || {
  echo "Cannot locate lib-vendored.sh next to this script; run it by path, not via stdin." >&2; exit 1; }
# shellcheck source=lib-vendored.sh
. "$LIB_DIR/lib-vendored.sh"

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

printf "%-7s %-4s %-5s %s\n" "WORDS" "OVER" "VND" "SKILL"
printf "%-7s %-4s %-5s %s\n" "-----" "----" "-----" "-----"

# Rows are collected first, then sorted — piping the loop directly into sort would run it in a
# subshell and lose the counter, silently disabling the empty-result guard below.
rows=""
total=0
while IFS= read -r -d '' f; do
  dir=$(dirname "$f")
  name=$(basename "$dir")
  total=$((total + 1))
  case "$name" in
    using-*|getting-started*) limit=150 ;;
    superpowers*|*-core|*-rules) limit=200 ;;
    *) limit=500 ;;
  esac
  # A single unreadable file must not truncate the table (it used to abort the loop under set -e).
  if ! wc=$(wc -w <"$f" 2>/dev/null | tr -d ' ') || [ -z "$wc" ]; then
    rows="${rows}$(printf "%-7s %-4s %-5s %s (limit=%d)" "ERR" "?" "$(vendored_flag "$dir")" "$name" "$limit")
"
    continue
  fi
  if [ "$wc" -gt "$limit" ]; then over="YES"; else over="-"; fi
  rows="${rows}$(printf "%-7s %-4s %-5s %s (limit=%d)" "$wc" "$over" "$(vendored_flag "$dir")" "$name" "$limit")
"
done < <(find -L "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 2>/dev/null | sort -z)

if [ "$total" -eq 0 ]; then
  echo
  echo "SCANNED NOTHING: no SKILL.md at depth 2 under '$FOLDER'. This is NOT a clean audit." >&2
  exit 2
fi
printf '%s' "$rows" | sort -k1,1 -nr
echo
echo "Legend: OVER=exceeds word limit, ERR=unreadable, VND=vendored (see check-vendored.sh)."
echo "OVER+VND together do NOT license a Trim — vendored skills take no in-place structural edit."

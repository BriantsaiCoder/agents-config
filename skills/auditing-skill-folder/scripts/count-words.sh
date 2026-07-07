#!/usr/bin/env bash
# Step 1 — Token cost audit.
# Usage: count-words.sh <skill-folder>
# Output: tab-separated  word-count  threshold-marker  skill-name
# Threshold: 500 (default), 200 (if name matches frequently-loaded pattern), 150 (getting-started).
set -euo pipefail

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

printf "%-7s %-4s %s\n" "WORDS" "OVER" "SKILL"
printf "%-7s %-4s %s\n" "-----" "----" "-----"

while IFS= read -r -d '' f; do
  name=$(basename "$(dirname "$f")")
  wc=$(wc -w <"$f" | tr -d ' ')
  case "$name" in
    using-*|getting-started*) limit=150 ;;
    superpowers*|*-core|*-rules) limit=200 ;;
    *) limit=500 ;;
  esac
  if [ "$wc" -gt "$limit" ]; then
    over="YES"
  else
    over="-"
  fi
  printf "%-7s %-4s %s (limit=%d)\n" "$wc" "$over" "$name" "$limit"
done < <(find "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 | sort -z) \
  | sort -k1,1 -nr

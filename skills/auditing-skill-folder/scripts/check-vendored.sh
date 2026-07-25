#!/usr/bin/env bash
# Step 0 — Vendored axis. Run BEFORE steps 1–6: it gates which verdicts are even legal.
# Usage: check-vendored.sh <skill-folder>
# Exit: 0 = scanned OK. 1 = bad folder. 2 = scanned nothing (see the empty-result guard).
set -uo pipefail

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)
[ -n "${LIB_DIR:-}" ] && [ -r "$LIB_DIR/lib-vendored.sh" ] || {
  echo "Cannot locate lib-vendored.sh next to this script; run it by path, not via stdin." >&2; exit 1; }
# shellcheck source=lib-vendored.sh
. "$LIB_DIR/lib-vendored.sh"

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

printf "%-5s %-40s %s\n" "VND" "SKILL" "OWNER / UPSTREAM"
printf "%-5s %-40s %s\n" "-----" "-----" "----------------"

total=0; vendored=0; probable=0; errored=0; forked=0
while IFS= read -r -d '' f; do
  dir=$(dirname "$f")
  name=$(basename "$dir")
  flag=$(vendored_flag "$dir")
  total=$((total + 1))
  case "$flag" in
    VND)  vendored=$((vendored + 1))
          if fork_recorded "$name" "$FOLDER"; then flag="VND*"; forked=$((forked + 1)); fi ;;
    "vnd?") probable=$((probable + 1)) ;;
    ERR)  errored=$((errored + 1)) ;;
    *)    continue ;;
  esac
  printf "%-5s %-40s %s\n" "$flag" "$name" "$(vendored_owner "$dir")"
done < <(find -L "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 2>/dev/null | sort -z)

echo
if [ "$total" -eq 0 ]; then
  echo "SCANNED NOTHING: no SKILL.md at depth 2 under '$FOLDER'." >&2
  echo "This is NOT a clean audit. Check the path, and note that a folder of symlinks needs" >&2
  echo "the -L that this script already passes; a plugin layout may nest SKILL.md deeper." >&2
  exit 2
fi
echo "$vendored vendored ($forked with a recorded fork) + $probable probable + $errored unreadable, of $total skills."
[ "$errored" -gt 0 ] && echo "WARNING: $errored skill(s) unreadable — flagged ERR, NOT cleared as self-owned." >&2

cat <<'EOF'

CONSTRAINT: vendored skills accept NO in-place structural edit — no Trim, no Split, no
rewriting their SKILL.md or references. Editing an upstream skill in place IS a fork: it
trades a one-off load saving for a permanent merge-conflict cost on every upstream update.
This outranks token cost and trigger precision. Step 1 word counts on these are FYI only.
A defect found in one gets REPORTED, not fixed.

Still legal, because they do not edit the skill's own files:
  - external integration (adding its name to a routing list, a rules file, a hub skill)
  - wholesale replacement with a newer upstream version, or removing the skill entirely

VND* = this fork is already an ACCEPTED, RECORDED decision in vendored-forks.md, with a
re-merge procedure. Do not re-litigate it and do not extend it — read the record first.
A vendored skill that has been edited but is NOT listed there is an unrecorded fork: a defect.
EOF

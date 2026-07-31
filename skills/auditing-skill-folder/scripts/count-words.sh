#!/usr/bin/env bash
# Step 1 — Token cost audit.
# Usage: count-words.sh <skill-folder>
# Output: effective-count  raw-word-count  cjk-chars  over-limit-marker  vendored-flag  skill-name
#
# DECLARED-TIERS: 200,500
# (tests/word-budget.sh reads that line and FAILS if any declared tier matches zero real skills.
#  Two earlier tiers — using-*/getting-started* at 150 and *-core/*-rules at 200 — keyed on
#  directory-name patterns that matched 0 of 95 skills in BOTH ~/.agents/skills and
#  ~/.claude/skills. A dead branch never fires and never complains, which is worse than having no
#  tier at all: it manufactures the impression that frequently-loaded material is budgeted when
#  nothing is checking. The tight tier is now an explicit membership list, so it can be verified.)
#
# EFFECTIVE COUNT — why `wc -w` alone is not the measure.
# `wc -w` splits on whitespace. Chinese has no inter-word whitespace, so a whole paragraph collapses
# to one "word": a 40-character / 120-byte zh-TW paragraph measures as 1. That is not a small error,
# it disables the gate for a whole class of skill — CJK-heavy skills share the same limit as English
# ones while being counted on an incomparable scale, so Step 1 never routes them to
# step1-verdict-guide.md. The fix ADDS a measure rather than replacing one: a file containing no CJK
# scores cjk=0 and effective == wc -w, so **English behaviour is unchanged**, which
# tests/word-budget.sh pins on both fixtures and the live corpus.
#
# The 3/5 weight is token parity, not a guess: an English word is ~1.33 tokens and a CJK character
# ~0.8, so one CJK character is worth ~0.6 of an English word against the same budget. On the live
# corpus the weight changes no verdict (every CJK-bearing skill is OVER at weights 0.5 through 1.0);
# it is chosen so the budget stays meaningful for skills that do not exist yet.
#
# BOTH counts are pinned to LC_ALL=C, so the effective number is a property of the file and not of
# the caller's environment.
#
# CJK counting is byte-level by design. UTF-8 encodes U+3000–U+9FFF (CJK punctuation, kana, and CJK
# Unified Ideographs) as three bytes with a lead byte in 0xE3–0xE9, and continuation bytes are
# 0x80–0xBF, so they cannot collide. Counting lead bytes therefore counts characters exactly, with
# no locale set. The alternative, `wc -m`, needs a UTF-8 locale: with LC_ALL unset it silently
# returns BYTES (12 rather than 4 on a 4-character sample), and a CI runner is not guaranteed to
# have en_US.UTF-8 generated.
#
# `wc -w` is pinned for a defect found in CI on 2026-08-01, not out of caution: GNU coreutils splits
# words with `iswspace()` under a UTF-8 locale and per byte under C, and on a whitespace-free zh-TW
# file the two disagree — the same fixture measured 583 under en_US.UTF-8 and 582 under C. macOS BSD
# `wc` answers 7 either way, so this was invisible locally and only the GNU runner exposed it.
# Pinning the CJK half alone was not enough: the effective number is a sum, so one locale-sensitive
# term makes the whole thing drift. Verified over all 95 skills: pinning changes no count.
# tests/word-budget.sh runs the script under three locale settings and asserts one answer.
#
# VND column is co-located on purpose: an over-limit count reads as "Trim me", and for a vendored
# skill that verdict needs a recorded override (see check-vendored.sh). The constraint must be
# visible on the same line as the signal that provokes it — but note it gates EXECUTION, not
# ASSESSMENT: a VND row is scored on merit like any other.
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

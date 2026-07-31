#!/usr/bin/env bash
# Step 2 — Description trap detector.
# Usage: lint-descriptions.sh <skill-folder>
# Flags descriptions that summarize workflow (sequential verbs, "then", "by ...ing", "step/phase",
# numbered actions) instead of trigger conditions ("Use when ...").
#
# SCOPE: English + zh-TW. Every other language still scores "?" — UNASSESSED, read it yourself.
#
# zh-TW support landed 2026-08-01, on the TRAP side FIRST. The constraint is not stylistic: an
# earlier attempt (2026-07-25, reverted) taught GOOD_RE zh-TW alone, which left zh-TW able to reach
# only "-" or "?" and never "YES" — converting manual reads into silent passes and blinding the
# detector to exactly the defect it exists to catch. Any future language must land the same way:
# TRAP first, or not at all. tests/description-lint.sh pins that direction (22 cases, in CI),
# including a fixture proving the zh-TW "?" bucket is still reachable.
#
# C LOCALE / MULTIBYTE RULE. This host runs LC_CTYPE=C; CI runs GNU grep. Under C, a UTF-8
# character is a byte SEQUENCE, so a multibyte character inside a bracket expression is matched
# per byte and the expression silently means something else — a negated class like [^。] is the
# dangerous form. Therefore: multibyte characters appear ONLY as literal alternatives joined by
# `|`, never inside [...]. Bracket expressions stay ASCII-only. Literal alternation is safe because
# UTF-8 is self-synchronising, so the same pattern behaves identically under C and under a UTF-8
# locale. Verified on ugrep 7.5.0 and GNU grep.
# Exit: 0 = scanned OK. 1 = bad folder. 2 = scanned nothing.
set -uo pipefail

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)
[ -n "${LIB_DIR:-}" ] && [ -r "$LIB_DIR/lib-vendored.sh" ] || {
  echo "Cannot locate lib-vendored.sh next to this script; run it by path, not via stdin." >&2; exit 1; }
# shellcheck source=lib-vendored.sh
. "$LIB_DIR/lib-vendored.sh"

FOLDER="${1:-$HOME/.agents/skills}"
[ -d "$FOLDER" ] || { echo "Folder not found: $FOLDER" >&2; exit 1; }

# Anti-pattern keywords (workflow summary smell).
# Looks for: explicit sequencing words, OR dash followed by 2+ imperative action verbs.
IMP='(write|writes|run|runs|dispatch|dispatches|watch|watches|refactor|refactors|build|builds|deploy|deploys|configure|configures|generate|generates|execute|executes|trigger|triggers|fire|fires|restart|retry|fix|fixes|edit|edits|commit|commits|push|pull)'
TRAP_EN=", then |\bthen [a-z]+ (then|and)|\b(step|phase) [0-9]|\bdispatches? \w+ per\b|\bwatch it fail\b|—\s*${IMP}[a-z]* \w+, ${IMP}|\b${IMP} \w+ first, \w*${IMP}"

# zh-TW imperative action verbs — the verbs a skill uses to narrate what IT does, deliberately
# excluding verbs that describe what the USER does (要求/想要/打算), which belong to a trigger clause.
ZH_IMP='(規劃|撰寫|產生|生成|建立|建置|執行|部署|設定|重構|修復|提交|推送|掃描|分析|產出|輸出|判斷|搬移|刪除|新增|驗證|審查|測試|編譯|安裝|更新|整理|轉換|匯入|匯出|檢查|比對|蒐集|收集|彙整)'

# zh-TW workflow-summary smell. Four signals, each measured against the live 95-skill corpus for
# false positives on English descriptions before being adopted:
#
#  1. REPEATED phase label (S0 … S2 …). Repetition is the signal: a single "S3" is a cloud term,
#     not an enumeration. Word-boundary-guarded with ASCII-only classes so "ES6" cannot match.
#  2. Explicit step/stage numbering, Arabic or Chinese numerals. Chinese numerals are spelled as
#     an alternation, NOT a bracket — see the C LOCALE rule at the top of this file.
#  3. CHAINED arrow (A→B→C). Chaining is the signal, not the arrow: `[^,;]` between the two arrows
#     rejects comma-separated routing pairs, which is how English descriptions use arrows
#     (`vue-best-practices` carries four of them: "Pinia state→pinia, SSR→nuxt, …"). Measured:
#     bare arrow-repetition matched 2 skills, this chained form matches only the real trap.
#  4. Dash followed by a 頓號-separated imperative list — the zh-TW analogue of TRAP_EN's
#     `— IMP x, IMP y`. Dash-anchored on purpose: an unanchored 頓號 list is usually a TRIGGER
#     enumeration ("當使用者要求重構、改名、刪除…時"), which must stay legal.
TRAP_ZH='(^|[^A-Za-z0-9])S[0-9]([^A-Za-z0-9]).*(^|[^A-Za-z0-9])S[0-9]([^A-Za-z0-9])'
TRAP_ZH="${TRAP_ZH}|(步驟|階段|第)[[:space:]]*[0-9]|第[[:space:]]*(一|二|三|四|五|六|七|八|九|十)+[[:space:]]*(步|階段|階)"
TRAP_ZH="${TRAP_ZH}|→[^,;]*→|->[^,;]*->"
TRAP_ZH="${TRAP_ZH}|(—|－|--)[[:space:]]*${ZH_IMP}.*、.*${ZH_IMP}"
TRAP_ZH="${TRAP_ZH}|然後|接著|接下來|依序|其次再|最後再"

TRAP_RE="${TRAP_EN}|${TRAP_ZH}"

# Trigger-condition signal (good).
# English stays anchored at ^: house policy is that a model-invoked description LEADS with its
# trigger. zh-TW is deliberately UNANCHORED, and the asymmetry is a C-locale consequence, not
# laziness: anchoring a zh-TW clause would need a negated multibyte class ("^[^。]{0,40}…時"),
# which is exactly the construction the C LOCALE rule above forbids. The looser GOOD side is
# safe only because TRAP is checked FIRST and is broad — a description matching both is YES.
GOOD_EN='^[Uu]se when\b'
GOOD_ZH='當使用者|當你|當 ?Claude|使用時機|適用時機|觸發關鍵字|之後觸發|時觸發|時先|時務必|時使用|適用於'
GOOD_RE="${GOOD_EN}|${GOOD_ZH}"

# Extract a description value. Handles YAML folded (>) / literal (|) block scalars, which the
# original single-line awk returned as a bare ">" (that made `ecpay` permanently score "?").
#
# Known gaps, deliberately not implemented (all verified to have ZERO occurrences in the corpus,
# 2026-07-25): an implicit multi-line PLAIN scalar whose value starts on the `description:` line
# keeps only that first line; a multi-line double-quoted scalar likewise; YAML escapes ('' and \")
# are not unescaped. Each would need a real YAML parser to do correctly.
read_desc() {
  awk '
    # Strip UTF-8 BOM so line 1 can match the opener. The BOM is built with sprintf rather than
    # written as \xef\xbb\xbf or \357\273\277 — BSD awk (macOS system awk, 20200816) silently
    # supports NEITHER escape form: sub() returns 0 and the BOM survives, which then makes the
    # frontmatter opener unmatchable. sprintf("%c%c%c") is the portable form. Verified on
    # awk 20200816: escapes -> sub()=0, sprintf -> sub()=1.
    NR==1 { sub("^" sprintf("%c%c%c", 239, 187, 191), "") }
    { sub(/\r$/, "") }                         # CRLF: a stray CR corrupts the printf columns
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm==0 { exit }                             # no frontmatter opener on line 1 -> no description
    /^---[[:space:]]*$/ { exit }               # closing delimiter ends the block
    !indesc && /^description:/ {
      line=$0
      sub(/^description:[[:space:]]*/, "", line)
      if (line ~ /^[>|][0-9+-]*[[:space:]]*$/ || line == "") { indesc=1; next }
      if (line !~ /^["'"'"']/) sub(/[[:space:]]+#.*$/, "", line)   # plain scalar: " #" starts a comment
      print line; exit
    }
    indesc {
      if ($0 ~ /^[^[:space:]]/) exit           # a new top-level key ends the block
      sub(/^[[:space:]]+/, "")
      printf "%s ", $0
    }
  ' "$1" 2>/dev/null | sed -E "s/^['\"]//; s/['\"][[:space:]]*$//; s/[[:space:]]+$//"
}

printf "%-5s %-5s %-40s %s\n" "TRAP" "VND" "SKILL" "DESCRIPTION"
printf "%-5s %-5s %-40s %s\n" "-----" "-----" "-----" "-----------"

total=0
while IFS= read -r -d '' f; do
  dir=$(dirname "$f")
  name=$(basename "$dir")
  total=$((total + 1))
  vnd=$(vendored_flag "$dir")
  # An unreadable file must not abort the table (it used to, under set -e).
  if [ ! -r "$f" ]; then
    printf "%-5s %-5s %-40s %s\n" "ERR" "$vnd" "$name" "(unreadable)"
    continue
  fi
  desc=$(read_desc "$f")
  if [ -z "$desc" ]; then
    printf "%-5s %-5s %-40s %s\n" "MISS" "$vnd" "$name" "(no description field)"
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
  printf "%-5s %-5s %-40s %s\n" "$flag" "$vnd" "$name" "$short"
done < <(find -L "$FOLDER" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 2>/dev/null | sort -z)

echo
if [ "$total" -eq 0 ]; then
  echo "SCANNED NOTHING: no SKILL.md at depth 2 under '$FOLDER'. This is NOT a clean audit." >&2
  exit 2
fi
echo "Legend: YES=workflow-summary trap candidate (read body & verify), -=trigger-led OK,"
echo "        ?=UNASSESSED — read it yourself (assessed languages: English, zh-TW; any other"
echo "        language always lands here), MISS=no description, ERR=unreadable."
echo "        VND=vendored — a defect found here is REPORTED, not fixed in place. See check-vendored.sh."

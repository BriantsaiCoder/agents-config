#!/usr/bin/env bash
# Shared vendored-skill detection. Sourced by count-words.sh / lint-descriptions.sh / check-vendored.sh.
# Single source of truth — the axis is surfaced in three outputs, so the DETECTION must not be duplicated.
#
# Why this axis exists (2026-07-25): an audit gave vendored upstream skills a Trim verdict
# ("delete/edit its references or sections"). Executing that forks the upstream and buys a
# permanent merge-conflict cost to save a one-off load. The constraint outranks any
# token/precision benefit, so it must gate verdicts mechanically, not by reviewer memory.
#
# FAIL CLOSED. Every unknown resolves toward "treat as vendored", never toward "-".
# A false VND costs one manual check; a false "-" authorises editing someone else's skill.

# Resolved once at source time — fork_recorded() uses it to find the repo-root vendored-forks.md.
LIB_SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd) || LIB_SELF_DIR=""

mattpocock_lock() {
  local f
  for f in "${MATTPOCOCK_SKILLS_LOCK:-}" \
           "${LIB_SELF_DIR:+$LIB_SELF_DIR/../../../mattpocock-skills.lock}"; do
    [ -n "$f" ] && [ -r "$f" ] || continue
    printf '%s' "$f"
    return 0
  done
  return 1
}

# vendored_flag <skill-dir> -> VND | vnd? | ERR | -
#   VND   root-lock entry, LICENSE file, or an upstream-provenance marker.
#   vnd?  frontmatter homepage/source only. Probable upstream, confirm by hand.
#   ERR   directory or SKILL.md unreadable — UNKNOWN, must not be read as self-owned.
#   -     self-owned.
#
# Detection is the UNION of four signals because none alone is sufficient:
#   - A root lock records immutable vendored sets without changing upstream payload.
#   - LICENSE alone missed `design-doc-mermaid` (Skilz Marketplace, no LICENSE file). That skill
#     has since been retired to attic/, but it is the reason this is a union and not a single test.
#   - A marketplace/upstream marker alone misses `playwright-best-practices` / `vueuse-functions`
#     (LICENSE.md, no marker).
#   - Both together still missed two skills, found by hand 2026-07-25 (see PROVENANCE FILE SET and
#     MARKER SCAN below). Two false negatives out of six real vendored skills, in the gate whose
#     whole job is to make that manual review unnecessary.
# The union returns every known vendored skill with 0 false positives across the corpus.
# File *existence* is not a signal — only provenance CONTENT is. (The one exception considered and
# rejected: `.claude-plugin/` exists in exactly 1 of 50 skills, so "exists => VND" would also be
# 0-false-positive here — but it would be a second kind of test, and reading the file's content
# already catches it with the pattern that was there. Content-only stays the single rule.)
vendored_flag() {
  local dir="$1" f lock
  [ -d "$dir" ] && [ -r "$dir" ] || { printf 'ERR'; return; }

  lock=$(mattpocock_lock 2>/dev/null) || lock=""
  if [ -n "$lock" ] && grep -Fxq "skill=$(basename "$dir")" "$lock" 2>/dev/null; then
    printf 'VND'; return
  fi

  for f in LICENSE LICENSE.md LICENSE.txt COPYING; do
    [ -f "$dir/$f" ] && { printf 'VND'; return; }
  done

  # Upstream-provenance markers: a marketplace listing, an install-this-skill blurb, or a
  # github URL naming a skill repo. Case-insensitive, first hit wins.
  #
  # PROVENANCE FILE SET — the files are named explicitly rather than using
  # `grep -R "$dir" --include=...`: when the directory ARGUMENT is itself a symlink (every entry
  # under ~/.claude/skills is), grep -R does not descend into it, so --include filters it out and
  # the check silently returns "no match". That made this gate false-negative on exactly the
  # symlinked path the skill documents as supported. Naming the files removes traversal semantics.
  #
  # `.claude-plugin/plugin.json` joined the set 2026-07-25: it is the Claude Code plugin
  # marketplace manifest, and a skill sitting in skills/ while carrying one was unpacked from a
  # third-party plugin. `tailwind-v4-shadcn` had ONLY that file as provenance (no LICENSE, no
  # README, nothing in frontmatter) and so read as self-owned — which is what let its two factual
  # corrections be made before anyone knew it was someone else's skill. Its content already
  # matches the pattern below (`"repository": "https://github.com/jezweb/claude-skills"`), so the
  # fix is the file set, not the pattern.
  for f in "$dir/README.md" "$dir/SKILL.md" "$dir/.claude-plugin/plugin.json"; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    if grep -qiE 'skilz|skillzwave|marketplace|install this skill|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]*skill' \
         "$f" 2>/dev/null; then
      printf 'VND'; return
    fi
  done

  [ -f "$dir/SKILL.md" ] && [ -r "$dir/SKILL.md" ] || { printf 'ERR'; return; }

  # MARKER SCAN — `upstream:` is an explicit statement of foreign origin, so it resolves to VND,
  # not to the softer vnd?. It is scanned over the WHOLE file, not just the frontmatter:
  # `agent-browser` declares `<!-- ... upstream: agent-browser CLI ... -->` on line 7, AFTER the
  # closing `---`, where the old frontmatter-bounded awk (`fm==2 exit`) had already stopped.
  #
  # grep, not awk, deliberately: the scan is no longer frontmatter-bounded so awk's line-state
  # buys nothing, and lint-descriptions.sh documents that BSD awk (macOS 20200816) silently fails
  # on some escape forms.
  #
  # Anchors are `^`, `<!--`, and `|`. The `|` is required, not sloppiness: agent-browser's marker
  # is the 4th field of a pipe-delimited comment
  # (`<!-- tier: … | consumed-by: … | upstream: … | last-verified: … -->`), so anchoring only on
  # `<!--` misses it. Anchoring keeps this matching a DECLARATION rather than prose containing the
  # word — "if your upstream uses short DNS TTLs" has no colon, and that file is outside the
  # scanned set regardless. Verified 2026-07-25 across all 50 SKILL.md: exactly 1 line matches.
  if grep -qiE '(^|<!--|\|)[[:space:]]*upstream:[[:space:]]*[^[:space:]]' "$dir/SKILL.md" 2>/dev/null; then
    printf 'VND'; return
  fi

  # homepage/source stay vnd?: unlike `upstream:`, they can legitimately be a project's own link.
  if awk '
      /^---[[:space:]]*$/ { fm++; if (fm==2) exit }
      fm==1 && /^(homepage|source):[[:space:]]*[^[:space:]]/ { found=1; exit }
      END { exit !found }
    ' "$dir/SKILL.md" 2>/dev/null; then
    printf 'vnd?'; return
  fi

  printf -- '-'
}

# fork_recorded <skill-name> [audited-folder] -> exit 0 if this fork is recorded as an accepted
# decision in vendored-forks.md, else 1.
#
# A vendored skill that HAS been edited in place is either a recorded decision or a defect, and
# the two must be distinguishable at a glance — otherwise the gate can only ever say "don't",
# which is how a real accepted fork gets re-litigated every audit.
#
# Lookup order: $VENDORED_FORKS, then <audited-folder>/../vendored-forks.md, then the repo root
# three levels above this library.
#
# The match is CONFINED to the fork-index marker block. It used to be a whole-file
# `grep -F "| \`$name\` |"`, which meant ANY table row anywhere in that document starting with the
# skill name promoted it to VND*. That fired 2026-07-25: a table added to document this very
# detector's blind spots listed `agent-browser` in its first column, and the skill — never forked,
# never edited — started rendering as a recorded fork. A false VND* is the dangerous direction:
# it tells the next reader "this fork is already an accepted decision, don't re-litigate" about a
# skill nobody ever decided anything about.
#
# FAIL CLOSED on a file with no markers: no block means no recorded fork, so a plain VND. That
# costs one manual check; the reverse silently licenses editing someone else's skill.
fork_recorded() {
  local name="$1" folder="${2:-}" f
  # Every candidate uses :+ so an unset variable contributes NOTHING. With :- an empty
  # LIB_SELF_DIR would expand to "/../../../vendored-forks.md" -> "/vendored-forks.md",
  # letting an unrelated file at the filesystem root drive VND* classification.
  for f in "${VENDORED_FORKS:+$VENDORED_FORKS}" \
           "${folder:+$folder/../vendored-forks.md}" \
           "${LIB_SELF_DIR:+$LIB_SELF_DIR/../../../vendored-forks.md}"; do
    [ -n "$f" ] && [ -r "$f" ] || continue
    awk -v n="$name" '
      /<!-- fork-index:begin -->/ { blk=1; next }
      /<!-- fork-index:end -->/   { blk=0 }
      blk && index($0, "| `" n "` |") == 1 { found=1; exit }
      END { exit !found }
    ' "$f" 2>/dev/null && return 0
  done
  return 1
}

# vendored_owner <skill-dir> -> copyright holder / upstream URL, or empty.
#
# MUST stay lookup-for-lookup aligned with vendored_flag(): a row that vendored_flag() renders as
# VND but vendored_owner() cannot attribute prints as "detected but unattributable", which reads
# as a detector bug rather than as the finding it is. Both newly-caught skills (2026-07-25) hit
# exactly that — the same two blind spots lived in both functions, and fixing only the flag would
# have produced two blank OWNER cells.
vendored_owner() {
  local dir="$1" lic out lock
  lock=$(mattpocock_lock 2>/dev/null) || lock=""
  if [ -n "$lock" ] && grep -Fxq "skill=$(basename "$dir")" "$lock" 2>/dev/null; then
    sed -n 's/^source_url=//p' "$lock" | head -1
    return
  fi

  for lic in "$dir/LICENSE" "$dir/LICENSE.md" "$dir/LICENSE.txt" "$dir/COPYING"; do
    [ -f "$lic" ] && [ -r "$lic" ] || continue
    out=$(grep -i -m1 'copyright' "$lic" 2>/dev/null \
          | sed -E 's/^[[:space:]]*[Cc]opyright[[:space:]]*(\([Cc]\))?[[:space:]]*//; s/[[:space:]]+$//')
    [ -n "$out" ] && { printf '%s' "$out"; return; }
  done

  # Same file set as vendored_flag()'s PROVENANCE FILE SET, same reason.
  for lic in "$dir/README.md" "$dir/SKILL.md" "$dir/.claude-plugin/plugin.json"; do
    [ -f "$lic" ] && [ -r "$lic" ] || continue
    out=$(grep -hoiE 'https?://[A-Za-z0-9_.:/-]*(skilz|skillzwave|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]*skill)[A-Za-z0-9_.:/-]*' \
          "$lic" 2>/dev/null | head -1)
    [ -n "$out" ] && { printf '%s' "$out"; return; }
  done

  # Whole-file `upstream:` scan, mirroring vendored_flag()'s MARKER SCAN — catches the marker in a
  # post-frontmatter HTML comment. Trailing `-->` is stripped so a comment-embedded marker does not
  # print its own delimiter.
  out=$(grep -m1 -iE '(^|<!--|\|)[[:space:]]*upstream:[[:space:]]*[^[:space:]]' "$dir/SKILL.md" 2>/dev/null \
        | sed -E 's/^.*[Uu]pstream:[[:space:]]*//; s/[[:space:]]*(\|.*)?-->[[:space:]]*$//; s/[[:space:]]+$//')
  [ -n "$out" ] && { printf '%s' "$out"; return; }

  awk '
    /^---[[:space:]]*$/ { fm++; if (fm==2) exit }
    fm==1 && /^(homepage|source):/ { sub(/^[a-z]+:[[:space:]]*/,""); print; exit }
  ' "$dir/SKILL.md" 2>/dev/null
}

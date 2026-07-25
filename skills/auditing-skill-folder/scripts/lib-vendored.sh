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

# vendored_flag <skill-dir> -> VND | vnd? | ERR | -
#   VND   LICENSE file, or an upstream-provenance marker in README.md / SKILL.md.
#   vnd?  frontmatter homepage/source/upstream only. Probable upstream, confirm by hand.
#   ERR   directory or SKILL.md unreadable — UNKNOWN, must not be read as self-owned.
#   -     self-owned.
#
# Detection is the UNION of two signals because neither alone is sufficient:
#   - LICENSE alone missed `design-doc-mermaid` (Skilz Marketplace, no LICENSE file).
#   - A marketplace/upstream marker alone misses `playwright-best-practices` / `vueuse-functions`
#     (LICENSE.md, no marker).
# The union returns 6/6 known vendored with 0 false positives across the other 46 skills.
# README.md *existence* is still not a signal — only its provenance CONTENT is.
vendored_flag() {
  local dir="$1" f
  [ -d "$dir" ] && [ -r "$dir" ] || { printf 'ERR'; return; }

  for f in LICENSE LICENSE.md LICENSE.txt COPYING; do
    [ -f "$dir/$f" ] && { printf 'VND'; return; }
  done

  # Upstream-provenance markers: a marketplace listing, an install-this-skill blurb, or a
  # github URL naming a skill repo. Case-insensitive, first hit wins.
  #
  # The two files are named explicitly rather than using `grep -R "$dir" --include=...`:
  # when the directory ARGUMENT is itself a symlink (every entry under ~/.claude/skills is),
  # grep -R does not descend into it, so --include filters it out and the check silently
  # returns "no match". That made this gate false-negative on exactly the symlinked path the
  # skill documents as supported. Naming the files removes traversal semantics entirely.
  for f in "$dir/README.md" "$dir/SKILL.md"; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    if grep -qiE 'skilz|skillzwave|marketplace|install this skill|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]*skill' \
         "$f" 2>/dev/null; then
      printf 'VND'; return
    fi
  done

  [ -f "$dir/SKILL.md" ] && [ -r "$dir/SKILL.md" ] || { printf 'ERR'; return; }

  if awk '
      /^---[[:space:]]*$/ { fm++; if (fm==2) exit }
      fm==1 && /^(homepage|source|upstream):[[:space:]]*[^[:space:]]/ { found=1; exit }
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
fork_recorded() {
  local name="$1" folder="${2:-}" f
  for f in "${VENDORED_FORKS:-}" \
           "${folder:+$folder/../vendored-forks.md}" \
           "${LIB_SELF_DIR:-}/../../../vendored-forks.md"; do
    [ -n "$f" ] && [ -r "$f" ] || continue
    grep -qF -- "| \`$name\` |" "$f" 2>/dev/null && return 0
  done
  return 1
}

# vendored_owner <skill-dir> -> copyright holder / upstream URL, or empty.
vendored_owner() {
  local dir="$1" lic out
  for lic in "$dir/LICENSE" "$dir/LICENSE.md" "$dir/LICENSE.txt" "$dir/COPYING"; do
    [ -f "$lic" ] && [ -r "$lic" ] || continue
    out=$(grep -i -m1 'copyright' "$lic" 2>/dev/null \
          | sed -E 's/^[[:space:]]*[Cc]opyright[[:space:]]*(\([Cc]\))?[[:space:]]*//; s/[[:space:]]+$//')
    [ -n "$out" ] && { printf '%s' "$out"; return; }
  done

  for lic in "$dir/README.md" "$dir/SKILL.md"; do
    [ -f "$lic" ] && [ -r "$lic" ] || continue
    out=$(grep -hoiE 'https?://[A-Za-z0-9_.:/-]*(skilz|skillzwave|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]*skill)[A-Za-z0-9_.:/-]*' \
          "$lic" 2>/dev/null | head -1)
    [ -n "$out" ] && { printf '%s' "$out"; return; }
  done

  awk '
    /^---[[:space:]]*$/ { fm++; if (fm==2) exit }
    fm==1 && /^(homepage|source|upstream):/ { sub(/^[a-z]+:[[:space:]]*/,""); print; exit }
  ' "$dir/SKILL.md" 2>/dev/null
}

#!/usr/bin/env bash
# Validate local payload references in one skill or a folder of skills.
set -uo pipefail

ROOT=${1:-}
[ -n "$ROOT" ] || { echo "usage: check-relative-references.sh <skill-or-folder>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

checked=0; missing=0

is_payload_link() {
  case "$1" in
    ../*|references/*|scripts/*|templates/*|assets/*|core/*|advanced/*|debugging/*|architecture/*|browser-apis/*|frameworks/*|infrastructure-ci-cd/*|testing-patterns/*) return 0 ;;
    ./*)
      case "$1" in ./src/*|./app/*|./docs/*|./test/*|./tests/*) return 1 ;; esac
      case "$1" in *.md|*.markdown|*.sh|*.py|*.js|*.json|*.yaml|*.yml) return 0 ;; esac
      return 1
      ;;
    *.md|*.markdown|*.sh|*.py|*.js|*.json|*.yaml|*.yml) return 0 ;;
    *) return 1 ;;
  esac
}

check_target() {
  local file=$1 line=$2 raw=$3 base target
  case "$raw" in
    \#*|http://*|https://*|mailto:*|data:*|/*) return ;;
  esac
  case "$raw" in
    '<'*'>') target=${raw#<}; target=${target%%>*} ;;
    *) target=${raw%% *} ;;
  esac
  target=${target%%#*}; target=${target%%\?*}; target=${target//%20/ }
  [ -n "$target" ] || return
  is_payload_link "$target" || return
  checked=$((checked + 1))
  base=$(dirname "$file")
  if [ ! -e "$base/$target" ]; then
    printf 'MISSING\t%s:%s\t%s\n' "$file" "$line" "$target"
    missing=$((missing + 1))
  fi
}

if [ -f "$ROOT/SKILL.md" ]; then
  skill_dirs=$ROOT
else
  skill_dirs=$(find -L "$ROOT" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' \; -print | sort)
fi
[ -n "$skill_dirs" ] || { echo "SCANNED NOTHING: no SKILL.md under $ROOT" >&2; exit 2; }

while IFS= read -r listed_skill; do
  [ -n "$listed_skill" ] || continue
  skill=$(cd "$listed_skill" 2>/dev/null && pwd -P) || {
    printf 'UNREADABLE\t%s\n' "$listed_skill" >&2
    missing=$((missing + 1))
    continue
  }
  while IFS=$'\t' read -r file line raw; do
    [ -n "$raw" ] && check_target "$file" "$line" "$raw"
  done < <(
    find "$skill" -type f -name '*.md' -not -path '*/.claude/*' -print | sort |
      while IFS= read -r file; do
        perl -ne 'while (/\[[^]]*\]\(([^)]+)\)/g) { print "$ARGV\t$.\t$1\n" }' "$file"
      done
  )

  skill_file=$skill/SKILL.md
  while IFS=$'\t' read -r line raw; do
    [ -n "$raw" ] || continue
    case "$raw" in *'*'*|*'<'*|*'>'*|*'{'*|*'}'*) continue ;; esac
    raw=${raw%%#*}; raw=${raw%%\?*}
    checked=$((checked + 1))
    if [ ! -e "$skill/$raw" ]; then
      printf 'MISSING\t%s:%s\t%s\n' "$skill_file" "$line" "$raw"
      missing=$((missing + 1))
    fi
  done < <(
    perl -ne '
      while (/`((?:references|templates|scripts|assets)\/[^`[:space:]]+)`/g) { print "$.	$1\n" }
      while (/`(\.github\/skills\/[^`[:space:]]+)`/g) { print "$.	$1\n" }
    ' "$skill_file" | sed -E 's/[.,;:)]$//'
  )
  while IFS= read -r file; do
    while IFS=$'\t' read -r line raw; do
      [ -n "$raw" ] || continue
      case "$raw" in *'*'*|*'<'*|*'>'*|*'{'*|*'}'*) continue ;; esac
      raw=${raw%%#*}; raw=${raw%%\?*}; raw=${raw%[.,;:)]}
      checked=$((checked + 1))
      if [ ! -e "$skill/$raw" ]; then
        printf 'MISSING\t%s:%s\t%s\n' "$file" "$line" "$raw"
        missing=$((missing + 1))
      fi
    done < <(
      perl -ne '
        next if /^\s*#/;
        while (/`((?:references|templates|scripts|assets|core|advanced|debugging|architecture|browser-apis|frameworks|infrastructure-ci-cd|testing-patterns)\/[^`[:space:]]*)`/g) { print "$.\t$1\n" }
      ' "$file"
    )
    # Bare `foo.md` is ambiguous with project-output examples. Treat it as a payload pointer only
    # in direct references/ navigation prose; explicit Markdown links remain checked everywhere.
    [ "$(dirname "$file")" = "$skill/references" ] || continue
    while IFS=$'\t' read -r line raw; do
      [ -n "$raw" ] || continue
      raw=${raw%%#*}; raw=${raw%%\?*}
      case "$raw" in
        SKILL.md) base=$skill ;;
        *) base=$(dirname "$file") ;;
      esac
      checked=$((checked + 1))
      if [ ! -e "$base/$raw" ]; then
        printf 'MISSING\t%s:%s\t%s\n' "$file" "$line" "$raw"
        missing=$((missing + 1))
      fi
    done < <(
      perl -ne '
        next if /^\s*#/;
        next unless /\b(?:see|read|use|using|covered|per|refer)\b|詳見|見/i;
        while (/`([A-Za-z0-9_.-]+\.md(?:#[^`[:space:]]*)?)`/g) { print "$.\t$1\n" }
      ' "$file"
    )
  done < <(find "$skill" -type f -name '*.md' ! -path "$skill/SKILL.md" -print | sort)
done <<< "$skill_dirs"

if [ "$missing" -gt 0 ]; then
  printf '%d missing relative reference(s); %d checked\n' "$missing" "$checked" >&2
  exit 1
fi
printf 'PASS relative references: %d checked\n' "$checked"

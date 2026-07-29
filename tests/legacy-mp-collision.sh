#!/usr/bin/env bash
# Retired mp workflow wrappers must stay absent; replacements remain callable.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
SKILLS_DIR="${SKILLS_ROOT:-$ROOT/skills}"

[ "$#" -eq 0 ] || {
  printf 'usage: %s\n' "$0" >&2
  exit 2
}

fail=0
for legacy in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
  if [ -e "$SKILLS_DIR/$legacy" ]; then
    printf 'FAIL  retired wrapper exists: %s\n' "$legacy" >&2
    fail=$((fail + 1))
  fi
done

for replacement in diagnosing-bugs grilling domain-modeling codebase-design tdd; do
  skill_file="$SKILLS_DIR/$replacement/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    printf 'FAIL  replacement missing: %s\n' "$replacement" >&2
    fail=$((fail + 1))
  elif awk '
    NR == 1 && $0 == "---" {frontmatter=1; next}
    frontmatter && $0 == "---" {exit}
    frontmatter && /^disable-model-invocation:[[:space:]]*true/ {disabled=1}
    END {exit(disabled ? 0 : 1)}
  ' "$skill_file"; then
    printf 'FAIL  replacement is model-invocation-disabled: %s\n' "$replacement" >&2
    fail=$((fail + 1))
  fi
done

[ -f "$SKILLS_DIR/mp-zoom-out/SKILL.md" ] || {
  printf 'FAIL  retained local skill missing: mp-zoom-out\n' >&2
  fail=$((fail + 1))
}

if rg -q 'mp-(diagnose|grill-with-docs|improve-codebase-architecture|tdd)' \
  "$ROOT/core/routing.md" "$SKILLS_DIR"; then
  printf 'FAIL  active routing or shared skills reference a retired wrapper\n' >&2
  fail=$((fail + 1))
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS  legacy mp retirement guard: 4 retired / 5 replacements / mp-zoom-out retained\n'

#!/usr/bin/env bash
# 退役 mp wrapper 保留手動相容性，但不得再參與 model invocation。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
SKILLS_DIR="${SKILLS_ROOT:-$ROOT/skills}"

frontmatter_disables_model_invocation() {
  awk '
    NR == 1 && $0 == "---" { frontmatter=1; next }
    frontmatter && $0 == "---" { exit }
    frontmatter && $0 ~ /^disable-model-invocation:[[:space:]]*true[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

check_tree() {
  local fail=0 legacy model manual replacement skill_file

  while IFS='|' read -r legacy model manual; do
    skill_file="$SKILLS_DIR/$legacy/SKILL.md"
    if [ ! -f "$skill_file" ]; then
      printf 'FAIL  legacy wrapper missing: %s\n' "$legacy" >&2
      fail=$((fail + 1))
    elif ! frontmatter_disables_model_invocation "$skill_file"; then
      printf 'FAIL  legacy wrapper remains model-invocable: %s\n' "$legacy" >&2
      fail=$((fail + 1))
    fi

    IFS=',' read -r -a replacements <<< "$model,$manual"
    for replacement in "${replacements[@]}"; do
      [ -n "$replacement" ] || continue
      skill_file="$SKILLS_DIR/$replacement/SKILL.md"
      if [ ! -f "$skill_file" ]; then
        printf 'FAIL  replacement missing: %s -> %s\n' "$legacy" "$replacement" >&2
        fail=$((fail + 1))
      fi
    done

    IFS=',' read -r -a replacements <<< "$model"
    for replacement in "${replacements[@]}"; do
      skill_file="$SKILLS_DIR/$replacement/SKILL.md"
      if [ -f "$skill_file" ] && frontmatter_disables_model_invocation "$skill_file"; then
        printf 'FAIL  model replacement is invocation-off: %s -> %s\n' "$legacy" "$replacement" >&2
        fail=$((fail + 1))
      fi
    done
  done <<'EOF'
mp-diagnose|diagnosing-bugs|diagnosing-bugs
mp-grill-with-docs|grilling,domain-modeling|grill-with-docs
mp-improve-codebase-architecture|codebase-design|improve-codebase-architecture
mp-tdd|tdd|tdd
EOF

  [ "$fail" -eq 0 ] || return 1
  printf 'PASS  legacy mp collision guard: 4 wrappers / 4 mappings\n'
}

write_fixture_skill() {
  local root="$1" name="$2" disabled="${3:-false}"
  mkdir -p "$root/$name"
  {
    printf '%s\n' '---' "name: $name" "description: fixture $name"
    [ "$disabled" = true ] && printf '%s\n' 'disable-model-invocation: true'
    printf '%s\n' '---'
  } > "$root/$name/SKILL.md"
}

selftest() {
  local legacy replacement
  selftest_fixture=$(mktemp -d)
  trap 'rm -rf "$selftest_fixture"' EXIT

  for replacement in diagnosing-bugs grilling domain-modeling grill-with-docs \
                     codebase-design improve-codebase-architecture tdd; do
    write_fixture_skill "$selftest_fixture" "$replacement"
  done
  write_fixture_skill "$selftest_fixture" grill-with-docs true
  write_fixture_skill "$selftest_fixture" improve-codebase-architecture true

  for legacy in mp-diagnose mp-grill-with-docs \
                mp-improve-codebase-architecture mp-tdd; do
    write_fixture_skill "$selftest_fixture" "$legacy" true
  done

  SKILLS_DIR="$selftest_fixture" check_tree >/dev/null

  for legacy in mp-diagnose mp-grill-with-docs \
                mp-improve-codebase-architecture mp-tdd; do
    write_fixture_skill "$selftest_fixture" "$legacy"
    if SKILLS_DIR="$selftest_fixture" check_tree >/dev/null 2>&1; then
      printf 'FAIL  selftest missed model-invocable wrapper: %s\n' "$legacy" >&2
      return 1
    fi
    write_fixture_skill "$selftest_fixture" "$legacy" true
  done

  for replacement in diagnosing-bugs grilling domain-modeling grill-with-docs \
                     codebase-design improve-codebase-architecture tdd; do
    rm "$selftest_fixture/$replacement/SKILL.md"
    if SKILLS_DIR="$selftest_fixture" check_tree >/dev/null 2>&1; then
      printf 'FAIL  selftest missed replacement: %s\n' "$replacement" >&2
      return 1
    fi
    case "$replacement" in
      grill-with-docs|improve-codebase-architecture)
        write_fixture_skill "$selftest_fixture" "$replacement" true
        ;;
      *)
        write_fixture_skill "$selftest_fixture" "$replacement"
        ;;
    esac
  done

  printf 'PASS  legacy mp collision selftest\n'
}

case "${1:-}" in
  --selftest) selftest ;;
  '') check_tree ;;
  *) printf 'usage: %s [--selftest]\n' "$0" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# 拒絕 CLAUDE.md 在 agents-routing managed block 外重複舊 workflow routes。
set -euo pipefail

pattern='superpowers:(brainstorming|systematic-debugging|test-driven-development|executing-plans|subagent-driven-development|requesting-code-review|finishing-a-development-branch)|/?mp-(grill-with-docs|diagnose|tdd|improve-codebase-architecture|zoom-out)'

check_file() {
  local file="$1" hits
  [ -f "$file" ] || { printf 'FAIL  Claude instruction 不存在：%s\n' "$file" >&2; return 2; }

  hits="$(
    awk '
      /<!-- agents-routing:begin/ { managed=1; next }
      /<!-- agents-routing:end/   { managed=0; next }
      !managed { print NR "\t" $0 }
    ' "$file" | grep -E "$pattern" | cut -f1 | tr '\n' ',' | sed 's/,$//' || true
  )"
  [ -z "$hits" ] || {
    printf 'FAIL  Claude unmanaged routing collision：line %s\n' "$hits" >&2
    return 1
  }
  printf 'PASS  Claude unmanaged routing collision = 0\n'
}

selftest() {
  local rc
  selftest_tmp="$(mktemp -d "${TMPDIR:-/tmp}/claude-routing-collision.XXXXXX")"
  trap 'rm -rf "$selftest_tmp"' EXIT

  printf '%s\n' \
    '# Claude' \
    '- Bug → `superpowers:systematic-debugging`' \
    > "$selftest_tmp/bad.md"
  if check_file "$selftest_tmp/bad.md" >/dev/null 2>&1; then
    printf 'FAIL  selftest：managed block 外舊 route 未被攔截\n' >&2
    return 1
  else
    rc=$?
    [ "$rc" -eq 1 ] || {
      printf 'FAIL  selftest：預期 collision rc=1，實際 rc=%s\n' "$rc" >&2
      return 1
    }
  fi

  printf '%s\n' \
    '# Claude' \
    '<!-- agents-routing:begin -->' \
    '- Bug → `superpowers:systematic-debugging`' \
    '<!-- agents-routing:end -->' \
    '- Workflow routing 依 managed block。' \
    > "$selftest_tmp/good.md"
  check_file "$selftest_tmp/good.md" >/dev/null
  printf 'PASS  Claude routing collision selftest\n'
}

case "${1:-}" in
  --selftest) selftest ;;
  '') check_file "${CLAUDE_GLOBAL_FILE:-$HOME/.claude/CLAUDE.md}" ;;
  *) check_file "$1" ;;
esac

#!/usr/bin/env bash
# 三個 host 的 shared capability 等價守衛；比 semantic anchors，不比整檔 prose/hash。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)}"
MAPPING="$AGENTS/skills/dev-workflow/references/host-adapters.md"

pass=0 fail=0 unavailable=0

mapping_rows() {
  awk '/^<!-- capability-parity:start -->$/{on=1; next} /^<!-- capability-parity:end -->$/{on=0} on && index($0, "\t") {print}' "$MAPPING"
}

mapping_count() {
  mapping_rows | wc -l | tr -d ' '
}

host_field() {
  case "$1" in
    Claude)  printf '%s\n' "$3" ;;
    Codex)   printf '%s\n' "$4" ;;
    Copilot) printf '%s\n' "$5" ;;
  esac
}

check_host() {
  local label="$1" file="$2" missing=0 total=0 id meaning claude codex copilot field clause rest
  if [ ! -r "$file" ]; then
    printf 'UNAVAILABLE %s: %s\n' "$label" "$file"
    unavailable=$((unavailable + 1))
    return
  fi

  while IFS=$'\t' read -r id meaning claude codex copilot; do
    [ -n "$id" ] || continue
    total=$((total + 1))
    field=$(host_field "$label" "$meaning" "$claude" "$codex" "$copilot")
    if [ -z "$field" ]; then
      printf '  FAIL %s: %s has no mapped anchors\n' "$label" "$id" >&2
      missing=$((missing + 1))
      continue
    fi
    rest="$field"
    while :; do
      clause=${rest%%^*}
      if [ -z "$clause" ]; then
        printf '  FAIL %s: %s has an empty clause\n' "$label" "$id" >&2
        missing=$((missing + 1))
      elif ! grep -Fq -- "$clause" "$file"; then
        printf '  FAIL %s: %s missing clause: %s\n' "$label" "$id" "$clause" >&2
        missing=$((missing + 1))
      fi
      [ "$rest" = "$clause" ] && break
      rest=${rest#*^}
    done
  done < <(mapping_rows)

  if [ "$total" -lt 4 ]; then
    printf 'FAIL %s: canonical mapping has only %d capabilities\n' "$label" "$total" >&2
    fail=$((fail + 1))
  elif [ "$missing" -eq 0 ]; then
    printf 'PASS %s: %d semantic capabilities\n' "$label" "$total"
    pass=$((pass + 1))
  else
    printf 'FAIL %s: %d missing semantic anchors\n' "$label" "$missing" >&2
    fail=$((fail + 1))
  fi
}

run_checks() {
  [ -r "$MAPPING" ] || { printf 'FAIL canonical mapping unavailable: %s\n' "$MAPPING" >&2; return 1; }
  check_host Claude  "${CLAUDE_INSTRUCTIONS:-$HOME/.claude/CLAUDE.md}"
  check_host Codex   "${CODEX_INSTRUCTIONS:-$HOME/.codex/AGENTS.md}"
  check_host Copilot "${COPILOT_INSTRUCTIONS:-$HOME/.copilot/copilot-instructions.md}"
  printf '%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
  [ "$fail" -eq 0 ] && [ "$unavailable" -eq 0 ]
}

selftest() {
  local scratch count id meaning claude codex copilot label target field first_clause pos_rc neg_rc empty_rc unavailable_rc rc=0
  # 本檔只有 set -uo pipefail：mktemp 失敗時 $scratch 為空，`: > "$scratch/claude.md"`
  # 會落到 /claude.md。trap 也必須在建立成功之後才裝，否則 rm -rf '' 是無意義的清理。
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/three-host-capability-parity.XXXXXX") ||
    { printf 'FAIL selftest: 無法建立暫存目錄，fixture 未建立\n' >&2; return 1; }
  trap "rm -rf '$scratch'" EXIT
  count=$(mapping_count)
  [ "$count" -ge 4 ] || { printf 'FAIL selftest: canonical mapping has only %s capabilities\n' "$count" >&2; return 1; }

  : > "$scratch/claude.md"; : > "$scratch/codex.md"; : > "$scratch/copilot.md"
  first_clause=""
  while IFS=$'\t' read -r id meaning claude codex copilot; do
    for label in Claude Codex Copilot; do
      field=$(host_field "$label" "$meaning" "$claude" "$codex" "$copilot")
      case "$label" in Claude) target=claude ;; Codex) target=codex ;; Copilot) target=copilot ;; esac
      printf '%s\n' "$field" | tr '^' '\n' >> "$scratch/$target.md"
    done
    [ -n "$first_clause" ] || first_clause=${claude%%^*}
  done < <(mapping_rows)

  CLAUDE_INSTRUCTIONS="$scratch/claude.md" CODEX_INSTRUCTIONS="$scratch/codex.md" \
    COPILOT_INSTRUCTIONS="$scratch/copilot.md" bash "$0" --check > "$scratch/positive.log" 2>&1
  pos_rc=$?
  if [ "$pos_rc" -eq 0 ] && [ "$(grep -c '^PASS \(Claude\|Codex\|Copilot\):' "$scratch/positive.log")" -eq 3 ] \
      && ! grep -q '^UNAVAILABLE ' "$scratch/positive.log"; then
    printf 'PASS selftest positive: all three hosts pass without UNAVAILABLE\n'
  else
    sed 's/^/  /' "$scratch/positive.log" >&2
    printf 'FAIL selftest positive\n' >&2; rc=1
  fi

  grep -Fvx -- "$first_clause" "$scratch/claude.md" > "$scratch/claude-bad.md"
  CLAUDE_INSTRUCTIONS="$scratch/claude-bad.md" CODEX_INSTRUCTIONS="$scratch/codex.md" \
    COPILOT_INSTRUCTIONS="$scratch/copilot.md" bash "$0" --check > "$scratch/negative.log" 2>&1
  neg_rc=$?
  if [ "$neg_rc" -ne 0 ] && grep -q '^FAIL Claude:' "$scratch/negative.log" \
      && [ "$(grep -c '^PASS \(Codex\|Copilot\):' "$scratch/negative.log")" -eq 2 ]; then
    printf 'PASS selftest negative: one-host drift fails while siblings remain PASS\n'
  else
    sed 's/^/  /' "$scratch/negative.log" >&2
    printf 'FAIL selftest negative\n' >&2; rc=1
  fi

  mkdir -p "$scratch/agents/skills/dev-workflow/references"
  awk -F '\t' 'BEGIN { OFS="\t" } /^CAP-/ && !done { $3="^" $3; done=1 } { print }' \
    "$MAPPING" > "$scratch/agents/skills/dev-workflow/references/host-adapters.md"
  AGENTS_HOME="$scratch/agents" CLAUDE_INSTRUCTIONS="$scratch/claude.md" \
    CODEX_INSTRUCTIONS="$scratch/codex.md" COPILOT_INSTRUCTIONS="$scratch/copilot.md" \
    bash "$0" --check > "$scratch/empty.log" 2>&1
  empty_rc=$?
  if [ "$empty_rc" -ne 0 ] && grep -q 'has an empty clause' "$scratch/empty.log"; then
    printf 'PASS selftest malformed mapping: empty clause fails closed\n'
  else
    sed 's/^/  /' "$scratch/empty.log" >&2
    printf 'FAIL selftest malformed mapping: empty clause passed\n' >&2; rc=1
  fi

  CLAUDE_INSTRUCTIONS="$scratch/missing.md" CODEX_INSTRUCTIONS="$scratch/codex.md" \
    COPILOT_INSTRUCTIONS="$scratch/copilot.md" bash "$0" --check > "$scratch/unavailable.log" 2>&1
  unavailable_rc=$?
  if [ "$unavailable_rc" -ne 0 ] && grep -q '^UNAVAILABLE Claude:' "$scratch/unavailable.log"; then
    printf 'PASS selftest unavailable: missing host fails the gate explicitly\n'
  else
    sed 's/^/  /' "$scratch/unavailable.log" >&2
    printf 'FAIL selftest unavailable: missing host must not exit 0\n' >&2; rc=1
  fi
  return "$rc"
}

case "${1:-}" in
  --selftest) selftest ;;
  --check|'') run_checks ;;
  *) printf 'usage: %s [--selftest|--check]\n' "$0" >&2; exit 2 ;;
esac

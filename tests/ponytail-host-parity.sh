#!/usr/bin/env bash
# 驗三 host 的 Ponytail 入口、啟用狀態、full mode 與 effective skill bytes。
# CI 使用 --selftest；本機使用 --check。Codex 依 runtime version 選 cache；無 resolver 時不猜。
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
pass=0 fail=0 unavailable=0
codex_runtime_version=""
selftest_scratch=""
ok()  { printf 'PASS %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$*" >&2; fail=$((fail + 1)); }
na()  { printf 'UNAVAILABLE %s\n' "$*" >&2; unavailable=$((unavailable + 1)); }

cleanup_selftest() {
  [ -z "$selftest_scratch" ] || [ ! -d "$selftest_scratch" ] || rm -r -- "$selftest_scratch"
}

load_instruction_anchors() {
  local mapping row cap intent extra
  mapping="${PONYTAIL_MAPPING:-${AGENTS_HOME:-$ROOT}/skills/dev-workflow/references/host-adapters.md}"
  [ -r "$mapping" ] || { na "Ponytail capability mapping missing: $mapping"; return 1; }
  if ! row=$(awk -F '\t' '$1 == "CAP-PONYTAIL" { count++; row=$0 } END { if (count == 1) print row; else exit 1 }' "$mapping"); then
    bad 'Ponytail capability mapping must contain exactly one CAP-PONYTAIL row'
    return 1
  fi
  IFS=$'\t' read -r cap intent claude_anchor codex_anchor copilot_anchor extra <<< "$row"
  if [ "$cap" != CAP-PONYTAIL ] || [ -z "$intent" ] || [ -z "$claude_anchor" ] ||
     [ -z "$codex_anchor" ] || [ -z "$copilot_anchor" ] || [ -n "${extra:-}" ]; then
    bad 'Ponytail capability mapping is malformed'
    return 1
  fi
}

check_anchor() { # $1=label $2=file $3=^ separated literal clauses
  local label="$1" file="$2" anchors="$3" rest clause missing=0
  [ -r "$file" ] || { na "$label instructions missing: $file"; return; }
  rest="$anchors"
  while :; do
    clause=${rest%%^*}
    if [ -z "$clause" ]; then
      missing=$((missing + 1))
    elif ! awk -v wanted="$clause" '
      {
        count=split($0, parts, /[；。]/)
        for (i=1; i<=count; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
          if (parts[i] == wanted) found=1
        }
      }
      END { exit found ? 0 : 1 }
    ' "$file"; then
      missing=$((missing + 1))
    fi
    [ "$rest" = "$clause" ] && break
    rest=${rest#*^}
  done
  if [ "$missing" -eq 0 ]; then
    ok "$label Ponytail instruction anchor"
  else
    bad "$label Ponytail instruction anchor missing $missing literal clauses"
  fi
}

check_mode() { # $1=label $2=mode-file
  local label="$1" file="$2" mode
  [ -r "$file" ] || { na "$label Ponytail mode missing: $file"; return; }
  mode=$(tr -d '\r\n' < "$file")
  if [ "$mode" = full ]; then
    ok "$label Ponytail mode=full"
  else
    bad "$label Ponytail mode expected full, found ${mode:-empty}"
  fi
}

check_enabled_json() { # $1=label $2=settings
  local label="$1" file="$2"
  [ -r "$file" ] || { na "$label settings missing: $file"; return; }
  command -v jq >/dev/null 2>&1 || { na "$label enabledPlugins probe needs jq"; return; }
  if jq -e '.enabledPlugins["ponytail@ponytail"] == true' "$file" >/dev/null 2>&1; then
    ok "$label enabledPlugins ponytail@ponytail=true"
  else
    bad "$label enabledPlugins does not enable ponytail@ponytail"
  fi
}

check_codex_runtime() { # $1=Codex config root
  local codex_home="$1" source json entry
  source="${CODEX_PLUGIN_LIST_JSON:-}"
  command -v jq >/dev/null 2>&1 || { na 'Codex runtime probe needs jq'; return; }
  if [ -n "$source" ]; then
    [ -r "$source" ] || { na "Codex plugin list fixture missing: $source"; return; }
    json=$(< "$source")
  elif [ "$codex_home" != "$HOME/.codex" ]; then
    na 'custom CODEX_CONFIG_ROOT requires CODEX_PLUGIN_LIST_JSON'
    return
  elif command -v codex >/dev/null 2>&1; then
    json=$(codex plugin list --json 2>/dev/null) || { na 'codex plugin list --json failed'; return; }
  else
    na 'Codex runtime probe needs codex CLI'
    return
  fi
  if ! entry=$(jq -cer '[.installed[]? | select(.pluginId == "ponytail@ponytail")] | select(length == 1) | .[0]' <<< "$json" 2>/dev/null); then
    bad 'Codex runtime must resolve exactly one ponytail@ponytail plugin'
    return
  fi
  if jq -e '.installed == true and .enabled == true' >/dev/null 2>&1 <<< "$entry"; then
    codex_runtime_version=$(jq -r '.version // empty' <<< "$entry")
    ok 'Codex Ponytail runtime enabled'
  else
    bad 'Codex Ponytail runtime is not enabled'
  fi
}

check_skill() { # $1=label $2=skill
  local label="$1" file="$2" missing=0 pattern folded
  [ -r "$file" ] || { na "$label Ponytail skill missing: $file"; return 1; }
  folded=$(tr '\n' ' ' < "$file")
  grep -Eq 'ultra\. Use on ANY[[:space:]]+coding task:' <<< "$folded" || missing=$((missing + 1))
  for pattern in '^ACTIVE EVERY RESPONSE\.' \
    '^[0-9]+\. \*\*Does this need to exist at all\?\*\*' \
    '^[0-9]+\. \*\*Already in this codebase\?\*\*' \
    '^[0-9]+\. \*\*Stdlib does it\?\*\*'; do
    grep -Eq -- "$pattern" "$file" || missing=$((missing + 1))
  done
  if [ "$missing" -eq 0 ]; then
    ok "$label Ponytail semantic anchors"
  else
    bad "$label Ponytail skill missing $missing semantic anchors"
  fi
}

run_check() {
  local claude_home codex_home copilot_home claude_root codex_root copilot_root claude_cache count
  local claude_skill codex_skill copilot_skill
  claude_home="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}"
  codex_home="${CODEX_CONFIG_ROOT:-$HOME/.codex}"
  copilot_home="${COPILOT_CONFIG_ROOT:-$HOME/.copilot}"

  load_instruction_anchors || return 1
  check_anchor Claude  "$claude_home/CLAUDE.md" "$claude_anchor"
  check_anchor Codex   "$codex_home/AGENTS.md" "$codex_anchor"
  check_anchor Copilot "$copilot_home/copilot-instructions.md" "$copilot_anchor"
  check_enabled_json Claude "$claude_home/settings.json"
  check_enabled_json Copilot "$copilot_home/settings.json"
  check_codex_runtime "$codex_home"
  check_mode Claude  "$claude_home/.ponytail-active"
  check_mode Codex   "$codex_home/plugins/data/ponytail-ponytail/.ponytail-active"
  check_mode Copilot "$copilot_home/plugin-data/ponytail/ponytail/.ponytail-active"

  claude_root="${CLAUDE_PONYTAIL_ROOT:-}"
  codex_root=""
  copilot_root="${COPILOT_PONYTAIL_ROOT:-$copilot_home/installed-plugins/ponytail/ponytail}"
  if [ -z "$claude_root" ]; then
    claude_cache="$claude_home/plugins/cache/ponytail/ponytail"
    if [ ! -d "$claude_cache" ]; then
      na "Claude Ponytail cache missing: $claude_cache"
    else
      count=$(find "$claude_cache" -mindepth 1 -maxdepth 1 -type d -print | wc -l | tr -d ' ')
      if [ "$count" -eq 1 ]; then
        claude_root=$(find "$claude_cache" -mindepth 1 -maxdepth 1 -type d -print)
      else
        bad "Claude Ponytail cache expected one effective version, found $count: $claude_cache"
      fi
    fi
  fi
  if [ -z "$codex_root" ]; then
    if [ -n "$codex_runtime_version" ]; then
      codex_root="$codex_home/plugins/cache/ponytail/ponytail/$codex_runtime_version"
      if [ ! -d "$codex_root" ]; then
        na "Codex runtime-selected Ponytail cache missing: $codex_root"
        codex_root=""
      fi
    else
      na 'Codex runtime-selected Ponytail version unavailable'
    fi
  fi

  if [ -n "$codex_root" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      na 'Codex plugin manifest probe needs jq'
    elif [ -r "$codex_root/.codex-plugin/plugin.json" ] &&
         jq -e '.name == "ponytail" and .skills == "./skills/"' "$codex_root/.codex-plugin/plugin.json" >/dev/null 2>&1; then
      ok 'Codex Ponytail plugin manifest shape'
    else
      bad 'Codex Ponytail plugin manifest missing or invalid'
    fi
  fi

  claude_skill=""
  codex_skill=""
  copilot_skill=""
  if [ -n "$claude_root" ]; then
    claude_skill="$claude_root/skills/ponytail/SKILL.md"
    check_skill Claude "$claude_skill"
  fi
  if [ -n "$codex_root" ]; then
    codex_skill="$codex_root/skills/ponytail/SKILL.md"
    check_skill Codex "$codex_skill"
  fi
  if [ -n "$copilot_root" ]; then
    copilot_skill="$copilot_root/skills/ponytail/SKILL.md"
    check_skill Copilot "$copilot_skill"
  fi

  if [ -r "$claude_skill" ] && [ -r "$codex_skill" ] && [ -r "$copilot_skill" ]; then
    if cmp -s "$claude_skill" "$codex_skill" && cmp -s "$codex_skill" "$copilot_skill"; then
      ok 'Ponytail effective skill bytes identical'
    else
      bad 'Ponytail effective skill bytes differ across hosts'
    fi
  else
    na 'Ponytail effective skill bytes unavailable'
  fi

  printf '%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
  [ "$fail" -eq 0 ] && [ "$unavailable" -eq 0 ]
}

fixture_check() { # $1=selftest root
  local base="$1"
  PONYTAIL_MAPPING="${PONYTAIL_MAPPING:-}" \
    CLAUDE_CONFIG_ROOT="$base/claude" CODEX_CONFIG_ROOT="$base/codex" \
    COPILOT_CONFIG_ROOT="$base/copilot" CLAUDE_PONYTAIL_ROOT="$base/claude/plugin" \
    COPILOT_PONYTAIL_ROOT="$base/copilot/plugin" \
    CODEX_PLUGIN_LIST_JSON="$base/codex/plugins.json" \
    bash "$0" --check
}

expect_fixture_failure() { # $1=root $2=expected output
  local base="$1" expected="$2" out test_rc
  out=$(fixture_check "$base" 2>&1); test_rc=$?
  if [ "$test_rc" -ne 0 ] && grep -Fq -- "$expected" <<< "$out"; then
    return 0
  fi
  printf '%s\n' "$out"
  return 1
}

selftest() {
  local scratch codex_plugin rc=0 out skill_body host test_rc
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/ponytail-host-parity.XXXXXX") || return 1
  selftest_scratch="$scratch"
  trap cleanup_selftest EXIT
  codex_plugin="$scratch/codex/plugins/cache/ponytail/ponytail/test-version"
  for host in claude codex copilot; do mkdir -p "$scratch/$host"; done
  printf 'ponytail 注入=通用慣例\n' > "$scratch/claude/CLAUDE.md"
  printf 'ponytail=通用慣例\n' > "$scratch/codex/AGENTS.md"
  printf 'ponytail=慣例\n' > "$scratch/copilot/copilot-instructions.md"
  printf '{"enabledPlugins":{"ponytail@ponytail":true}}\n' > "$scratch/claude/settings.json"
  printf '{"enabledPlugins":{"ponytail@ponytail":true}}\n' > "$scratch/copilot/settings.json"
  mkdir -p "$scratch/claude/plugin/skills/ponytail" "$codex_plugin/skills/ponytail" \
    "$codex_plugin/.codex-plugin" "$scratch/copilot/plugin/skills/ponytail" \
    "$scratch/codex/plugins/cache/ponytail/ponytail/stale-version/skills/ponytail" \
    "$scratch/codex/plugins/data/ponytail-ponytail" "$scratch/copilot/plugin-data/ponytail/ponytail"
  printf 'full\n' > "$scratch/claude/.ponytail-active"
  printf 'full\n' > "$scratch/codex/plugins/data/ponytail-ponytail/.ponytail-active"
  printf 'full\n' > "$scratch/copilot/plugin-data/ponytail/ponytail/.ponytail-active"
  printf '{"name":"ponytail","skills":"./skills/"}\n' > "$codex_plugin/.codex-plugin/plugin.json"
  printf '{"installed":[{"pluginId":"ponytail@ponytail","installed":true,"enabled":true,"version":"test-version"}]}\n' > "$scratch/codex/plugins.json"
  skill_body='description: Supports intensity levels: lite, full (default), ultra. Use on ANY
  coding task: writing, fixing, reviewing, or designing.
ACTIVE EVERY RESPONSE. No drift.
1. **Does this need to exist at all?**
2. **Already in this codebase?**
3. **Stdlib does it?**'
  printf '%s\n' "$skill_body" > "$scratch/claude/plugin/skills/ponytail/SKILL.md"
  printf '%s\n' "$skill_body" > "$codex_plugin/skills/ponytail/SKILL.md"
  printf '%s\n' "$skill_body" > "$scratch/copilot/plugin/skills/ponytail/SKILL.md"
  printf 'stale cache must be ignored\n' > "$scratch/codex/plugins/cache/ponytail/ponytail/stale-version/skills/ponytail/SKILL.md"

  out=$(fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -ne 0 ] || ! grep -q 'Ponytail effective skill bytes identical' <<< "$out"; then
    printf '%s\n' "$out"
    rc=1
  fi

  printf 'CAP-PONYTAIL\tfixture\tponytail 注入=通用慣例^literal[clause]\tponytail=通用慣例^literal[clause]\tponytail=慣例^literal[clause]\n' > "$scratch/mapping.tsv"
  printf 'literal[clause]；\n' >> "$scratch/claude/CLAUDE.md"
  printf 'literal[clause]；\n' >> "$scratch/codex/AGENTS.md"
  printf 'literal[clause]；\n' >> "$scratch/copilot/copilot-instructions.md"
  out=$(PONYTAIL_MAPPING="$scratch/mapping.tsv" fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -ne 0 ]; then
    printf '%s\n' "$out"
    rc=1
  fi
  printf 'ponytail 注入=通用慣例\n' > "$scratch/claude/CLAUDE.md"
  printf 'ponytail=通用慣例\n' > "$scratch/codex/AGENTS.md"
  printf 'ponytail=慣例\n' > "$scratch/copilot/copilot-instructions.md"

  mv "$codex_plugin" "$codex_plugin.missing"
  out=$(fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -eq 0 ] ||
     ! grep -Fq 'UNAVAILABLE Codex runtime-selected Ponytail cache missing' <<< "$out" ||
     ! grep -Fq 'UNAVAILABLE Ponytail effective skill bytes unavailable' <<< "$out" ||
     grep -q '^FAIL ' <<< "$out" ||
     grep -Fq 'Ponytail plugin manifest missing or invalid' <<< "$out" ||
     grep -Fq 'Ponytail skill missing:' <<< "$out"; then
    printf '%s\n' "$out"
    rc=1
  fi
  mv "$codex_plugin.missing" "$codex_plugin"

  printf 'MUST NOT treat ponytail=通用慣例；\n' > "$scratch/codex/AGENTS.md"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail instruction anchor missing' || rc=1
  printf 'ponytail=通用慣例\n' > "$scratch/codex/AGENTS.md"

  printf '%s\n' "${skill_body/ACTIVE EVERY RESPONSE/INACTIVE EVERY RESPONSE}" > "$codex_plugin/skills/ponytail/SKILL.md"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail skill missing 1 semantic anchors' || rc=1
  printf '%s\n' "$skill_body" > "$codex_plugin/skills/ponytail/SKILL.md"

  printf '%s\n' "${skill_body/ultra. Use on ANY/ultra. Do not Use on ANY}" > "$codex_plugin/skills/ponytail/SKILL.md"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail skill missing 1 semantic anchors' || rc=1
  printf '%s\n' "$skill_body" > "$codex_plugin/skills/ponytail/SKILL.md"

  mv "$scratch/copilot/copilot-instructions.md" "$scratch/copilot/copilot-instructions.md.missing"
  expect_fixture_failure "$scratch" 'UNAVAILABLE Copilot instructions missing' || rc=1
  mv "$scratch/copilot/copilot-instructions.md.missing" "$scratch/copilot/copilot-instructions.md"

  printf '{"enabledPlugins":{"ponytail@ponytail":false}}\n' > "$scratch/claude/settings.json"
  expect_fixture_failure "$scratch" 'FAIL Claude enabledPlugins does not enable ponytail@ponytail' || rc=1
  printf '{"enabledPlugins":{"ponytail@ponytail":true}}\n' > "$scratch/claude/settings.json"

  printf '{"enabledPlugins":{"ponytail@ponytail":false}}\n' > "$scratch/copilot/settings.json"
  expect_fixture_failure "$scratch" 'FAIL Copilot enabledPlugins does not enable ponytail@ponytail' || rc=1
  printf '{"enabledPlugins":{"ponytail@ponytail":true}}\n' > "$scratch/copilot/settings.json"

  printf 'lite\n' > "$scratch/codex/plugins/data/ponytail-ponytail/.ponytail-active"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail mode expected full' || rc=1

  printf 'full\n' > "$scratch/codex/plugins/data/ponytail-ponytail/.ponytail-active"
  printf '{"installed":[{"pluginId":"ponytail@ponytail","installed":true,"enabled":false,"version":"test-version"}]}\n' > "$scratch/codex/plugins.json"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail runtime is not enabled' || rc=1
  printf '{"installed":[{"pluginId":"ponytail@ponytail","installed":true,"enabled":true,"version":"test-version"}]}\n' > "$scratch/codex/plugins.json"

  printf '\nlocal drift\n' >> "$scratch/copilot/plugin/skills/ponytail/SKILL.md"
  expect_fixture_failure "$scratch" 'FAIL Ponytail effective skill bytes differ across hosts' || rc=1

  [ "$rc" -eq 0 ] && printf 'PASS Ponytail host parity selftest\n'
  return "$rc"
}

case "${1:-}" in
  --check|'') run_check ;;
  --selftest) selftest ;;
  *) printf 'usage: %s [--check|--selftest]\n' "$0" >&2; exit 2 ;;
esac

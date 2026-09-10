#!/usr/bin/env bash
# 驗三 host 的 Ponytail 入口、啟用狀態、full mode 與各自核准的完整內容 SHA256。
# 失效可能偏向假綠；selftest 必須拒絕三家相同竄改內容與缺失／畸形 pins。
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
  local mapping row cap intent extra pins
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
  if ! pins=$(LC_ALL=C awk -F '\t' '
    $1 == "PONYTAIL-SHA256" {
      if (NF != 3 || ($2 != "Claude" && $2 != "Codex" && $2 != "Copilot") ||
          length($3) != 64 || $3 ~ /[^0-9a-f]/ || seen[$2]++) invalid=1
      hash[$2]=$3
    }
    END {
      if (invalid || seen["Claude"] != 1 || seen["Codex"] != 1 || seen["Copilot"] != 1) exit 1
      printf "%s\t%s\t%s\n", hash["Claude"], hash["Codex"], hash["Copilot"]
    }
  ' "$mapping"); then
    bad 'Ponytail approved SHA256 pins malformed, missing or duplicate'
    return 1
  fi
  IFS=$'\t' read -r claude_sha256 codex_sha256 copilot_sha256 <<< "$pins"
}

check_anchor() { # $1=label $2=file $3=^ separated literal clauses
  local label="$1" file="$2" anchors="$3" rest clause missing=0
  [ -r "$file" ] || { na "$label instructions missing: $file"; return; }
  rest="$anchors"
  while :; do
    clause=${rest%%^*}
    if [ -z "$clause" ]; then
      missing=$((missing + 1))
    # 這個 pin 是斷言能不能運作的前提，不是保險。macOS 的 /usr/bin/awk（20200816）用
    # strcoll 比字串，而 macOS 的 strcoll 把 CJK code point 視為 ignorable：比較只剩非 CJK
    # 骨架，於是只差在中文的兩條 anchor 一律判等（`注入` == `等風格注入`），骨架有差才正常
    # （`abc中` != `abd文`）。這也是為什麼 selftest 的 negative control 一直照常紅——它們差在
    # ASCII；而真正的 anchor drift 只差 CJK，斷言對它完全是 no-op。2026-08-27 實測：anchor
    # 明明不存在於 CLAUDE.md 時仍報全 PASS。失效方向只朝「更綠」，gate 抓不到自己壞掉，
    # 所以 selftest 另備一條 CJK-only 變異當中止條件（見 cjk_drift，[evidence-integrity.md]）。
    # 三種 pin 實測（比對／[；。] 切段／可否被環境覆蓋）：LC_COLLATE=C 前兩項對，但被環境
    # 既有的 LC_ALL 蓋掉；LC_ALL=C 比對對、切段壞（退化成 byte class，切進多位元組字中間）；
    # LC_ALL=C.UTF-8 三項全對，故取之。Linux 的 gawk/mawk 走 strcmp，本來就不受影響。
    elif ! LC_ALL=C.UTF-8 awk -v wanted="$clause" '
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

check_skill() { # $1=label $2=skill $3=approved SHA256
  local label="$1" file="$2" expected="$3" actual
  [ -r "$file" ] || { na "$label Ponytail skill missing: $file"; return 1; }
  if command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file") || { bad "$label Ponytail SHA256 probe failed"; return 1; }
  elif command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file") || { bad "$label Ponytail SHA256 probe failed"; return 1; }
  else
    na "$label Ponytail SHA256 probe needs shasum or sha256sum"
    return 1
  fi
  actual=${actual%% *}
  if [ "$actual" = "$expected" ]; then
    ok "$label Ponytail approved SHA256"
  else
    bad "$label Ponytail approved SHA256 mismatch"
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
    check_skill Claude "$claude_skill" "$claude_sha256"
  fi
  if [ -n "$codex_root" ]; then
    codex_skill="$codex_root/skills/ponytail/SKILL.md"
    check_skill Codex "$codex_skill" "$codex_sha256"
  fi
  if [ -n "$copilot_root" ]; then
    copilot_skill="$copilot_root/skills/ponytail/SKILL.md"
    check_skill Copilot "$copilot_skill" "$copilot_sha256"
  fi

  printf '%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
  [ "$fail" -eq 0 ] && [ "$unavailable" -eq 0 ]
}

fixture_check() { # $1=selftest root
  local base="$1"
  PONYTAIL_MAPPING="${PONYTAIL_MAPPING:-$base/mapping.tsv}" \
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
  # 先驗原始 canonical mapping；fixture pins 不得掩蓋真實 pin schema 的損壞。
  load_instruction_anchors || return 1
  local PONYTAIL_MAPPING="${PONYTAIL_MAPPING:-}"
  # 手抄 anchor 是真 mapping 的獨立期望；fixture 只替換 payload pins。
  local scratch codex_plugin rc=0 out host test_rc skill_file label mapping variant
  local claude_fx='ponytail 等風格注入=通用慣例'
  local codex_fx='[T0-10] dev MUST 採 reuse／YAGNI／最小完整實作'
  local copilot_fx='[T0-10] 開發套用 ponytail=慣例，但只採 reuse／YAGNI 原則'
  local cjk_drift='ponytail=特殊慣例'
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/ponytail-host-parity.XXXXXX") || return 1
  selftest_scratch="$scratch"
  trap cleanup_selftest EXIT
  codex_plugin="$scratch/codex/plugins/cache/ponytail/ponytail/test-version"
  for host in claude codex copilot; do mkdir -p "$scratch/$host"; done
  printf '%s\n' "$claude_fx" > "$scratch/claude/CLAUDE.md"
  printf '%s\n' "$codex_fx" > "$scratch/codex/AGENTS.md"
  printf '%s\n' "$copilot_fx" > "$scratch/copilot/copilot-instructions.md"
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
  printf 'approved Claude fixture\n' > "$scratch/claude/plugin/skills/ponytail/SKILL.md"
  printf 'approved Codex fixture\n' > "$codex_plugin/skills/ponytail/SKILL.md"
  printf 'approved Copilot fixture\n' > "$scratch/copilot/plugin/skills/ponytail/SKILL.md"
  # Pins are independent literals, not calculated from the files under test.
  cat > "$scratch/pins.tsv" <<'PINS'
PONYTAIL-SHA256	Claude	f8396b18f294ade4f72b73e8be8ac9e4d83cd876f524678ca3c7a01470e94abb
PONYTAIL-SHA256	Codex	b70f2af4cf651016e6d336c0362ecf395b20f0ef8ad17e54297437f89e92fe44
PONYTAIL-SHA256	Copilot	1eeee460c85695b1bfb8a03ccfc075fb5196cc5df52aaf347f861530ffdcac10
PINS
  mapping="${PONYTAIL_MAPPING:-${AGENTS_HOME:-$ROOT}/skills/dev-workflow/references/host-adapters.md}"
  awk -F '\t' '$1 != "PONYTAIL-SHA256"' "$mapping" > "$scratch/mapping.tsv" || return 1
  cat "$scratch/pins.tsv" >> "$scratch/mapping.tsv"
  PONYTAIL_MAPPING="$scratch/mapping.tsv"
  cp "$scratch/mapping.tsv" "$scratch/mapping.good"
  printf 'stale cache must be ignored\n' > "$scratch/codex/plugins/cache/ponytail/ponytail/stale-version/skills/ponytail/SKILL.md"

  out=$(fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -ne 0 ] ||
     [ "$(grep -c '^PASS .* Ponytail approved SHA256$' <<< "$out")" -ne 3 ]; then
    printf '%s\n' "$out"
    rc=1
  fi

  printf 'CAP-PONYTAIL\tfixture\t%s^literal[clause]\t%s^literal[clause]\t%s^literal[clause]\n' \
    "$claude_fx" "$codex_fx" "$copilot_fx" > "$scratch/literal-mapping.tsv"
  cat "$scratch/pins.tsv" >> "$scratch/literal-mapping.tsv"
  printf 'literal[clause]；\n' >> "$scratch/claude/CLAUDE.md"
  printf 'literal[clause]；\n' >> "$scratch/codex/AGENTS.md"
  printf 'literal[clause]；\n' >> "$scratch/copilot/copilot-instructions.md"
  out=$(PONYTAIL_MAPPING="$scratch/literal-mapping.tsv" fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -ne 0 ]; then
    printf '%s\n' "$out"
    rc=1
  fi
  printf '%s\n' "$claude_fx" > "$scratch/claude/CLAUDE.md"
  printf '%s\n' "$codex_fx" > "$scratch/codex/AGENTS.md"
  printf '%s\n' "$copilot_fx" > "$scratch/copilot/copilot-instructions.md"

  mv "$codex_plugin" "$codex_plugin.missing"
  out=$(fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -eq 0 ] ||
     ! grep -Fq 'UNAVAILABLE Codex runtime-selected Ponytail cache missing' <<< "$out" ||
     grep -q '^FAIL ' <<< "$out" ||
     grep -Fq 'Ponytail plugin manifest missing or invalid' <<< "$out" ||
     grep -Fq 'Ponytail skill missing:' <<< "$out"; then
    printf '%s\n' "$out"
    rc=1
  fi
  mv "$codex_plugin.missing" "$codex_plugin"

  printf 'MUST NOT treat %s；\n' "$codex_fx" > "$scratch/codex/AGENTS.md"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail instruction anchor missing' || rc=1
  printf '%s\n' "$codex_fx" > "$scratch/codex/AGENTS.md"

  # check_anchor 的 locale pin 的中止條件。上一條 control 差在 ASCII（`MUST NOT treat `），
  # pin 被拿掉時它仍會正確紅，所以守不住 pin 本身——2026-08-27 的 anchor drift 就是這樣
  # 在全綠底下溜過去的。$cjk_drift 與 $codex_fx 的 ASCII 骨架完全相同、只差中文，於是
  # 沒有 pin 時 strcoll 判它們相等、本條轉綠。實測：拿掉 pin → 本條 FAIL；有 pin → PASS。
  printf '%s\n' "$cjk_drift" > "$scratch/codex/AGENTS.md"
  expect_fixture_failure "$scratch" 'FAIL Codex Ponytail instruction anchor missing' || rc=1
  printf '%s\n' "$codex_fx" > "$scratch/codex/AGENTS.md"

  for host in claude codex copilot; do
    case "$host" in
      claude) label=Claude; skill_file="$scratch/claude/plugin/skills/ponytail/SKILL.md" ;;
      codex) label=Codex; skill_file="$codex_plugin/skills/ponytail/SKILL.md" ;;
      copilot) label=Copilot; skill_file="$scratch/copilot/plugin/skills/ponytail/SKILL.md" ;;
    esac
    cp "$skill_file" "$scratch/$host.good"
    printf '\nlocal drift\n' >> "$skill_file"
    expect_fixture_failure "$scratch" "FAIL $label Ponytail approved SHA256 mismatch" || rc=1
    # A valid body for another host must not satisfy this host's pin.
    if [ "$host" = claude ]; then
      cp "$codex_plugin/skills/ponytail/SKILL.md" "$skill_file"
    else
      cp "$scratch/claude/plugin/skills/ponytail/SKILL.md" "$skill_file"
    fi
    expect_fixture_failure "$scratch" "FAIL $label Ponytail approved SHA256 mismatch" || rc=1
    rm "$skill_file"
    expect_fixture_failure "$scratch" "UNAVAILABLE $label Ponytail skill missing" || rc=1
    cp "$scratch/$host.good" "$skill_file"

    for variant in absent malformed duplicate; do
      case "$variant" in
        absent) awk -F '\t' -v host="$label" '!($1 == "PONYTAIL-SHA256" && $2 == host)' "$scratch/mapping.good" > "$scratch/mapping.tsv" ;;
        malformed) awk -F '\t' -v host="$label" 'BEGIN { OFS="\t" } $1 == "PONYTAIL-SHA256" && $2 == host { $3="not-a-sha256" } { print }' "$scratch/mapping.good" > "$scratch/mapping.tsv" ;;
        duplicate) cat "$scratch/mapping.good" > "$scratch/mapping.tsv"
          awk -F '\t' -v host="$label" '$1 == "PONYTAIL-SHA256" && $2 == host' "$scratch/pins.tsv" >> "$scratch/mapping.tsv" ;;
      esac
      expect_fixture_failure "$scratch" 'FAIL Ponytail approved SHA256 pins malformed, missing or duplicate' || rc=1
    done
    cp "$scratch/mapping.good" "$scratch/mapping.tsv"
  done

  # Equal tampered bytes on all hosts must still fail each independently pinned check.
  for skill_file in "$scratch/claude/plugin/skills/ponytail/SKILL.md" \
    "$codex_plugin/skills/ponytail/SKILL.md" "$scratch/copilot/plugin/skills/ponytail/SKILL.md"; do
    printf 'same unapproved body\n' > "$skill_file"
  done
  out=$(fixture_check "$scratch" 2>&1); test_rc=$?
  if [ "$test_rc" -eq 0 ] ||
     [ "$(grep -c '^FAIL .* Ponytail approved SHA256 mismatch$' <<< "$out")" -ne 3 ]; then
    printf '%s\n' "$out"
    rc=1
  fi
  cp "$scratch/claude.good" "$scratch/claude/plugin/skills/ponytail/SKILL.md"
  cp "$scratch/codex.good" "$codex_plugin/skills/ponytail/SKILL.md"
  cp "$scratch/copilot.good" "$scratch/copilot/plugin/skills/ponytail/SKILL.md"

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


  [ "$rc" -eq 0 ] && printf 'PASS Ponytail host parity selftest\n'
  return "$rc"
}

case "${1:-}" in
  --check|'') run_check ;;
  --selftest) selftest ;;
  *) printf 'usage: %s [--check|--selftest]\n' "$0" >&2; exit 2 ;;
esac

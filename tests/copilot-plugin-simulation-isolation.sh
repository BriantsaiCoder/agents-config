#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)
HELPER="$ROOT/bin/copilot-plugin-simulation-config"
PLAN="$ROOT/proposals/2026-07-27-mattpocock-skills-workflow/48-three-host-global-config-ownership-split-plan.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$HELPER" ] || fail "missing executable helper: $HELPER"
rg -Fq '`bin/copilot-plugin-simulation-config`' "$PLAN" ||
  fail 'Plan 48 does not require the simulation config helper'
rg -Fq '不得只因 `COPILOT_HOME` 指向scratch就宣稱隔離' "$PLAN" ||
  fail 'Plan 48 trusts COPILOT_HOME without checking embedded live paths'
rg -Fq 'simulation前後live Copilot plugin inventory與exact cache tree manifest必須empty diff' "$PLAN" ||
  fail 'Plan 48 does not protect live Copilot plugin state during simulation'

scratch_parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)
scratch=$(mktemp -d "$scratch_parent/copilot-plugin-isolation.XXXXXX")
scratch=$(cd "$scratch" && pwd -P)
cleanup() {
  case "$scratch" in
    "$scratch_parent"/copilot-plugin-isolation.*)
      chmod -R u+rwX "$scratch" 2>/dev/null || true
      rm -rf -- "$scratch"
      ;;
    *)
      fail "refusing unsafe cleanup: $scratch"
      ;;
  esac
}
trap cleanup EXIT

live_home="$scratch/live/.copilot"
simulation_home="$scratch/simulation/.copilot"
live_cache="$live_home/installed-plugins/superpowers-marketplace/superpowers"
simulation_cache="$simulation_home/installed-plugins/superpowers-marketplace/superpowers"
mkdir -p "$live_cache" "$simulation_cache"
printf 'live-sentinel\n' > "$live_cache/LIVE"
printf 'simulation-sentinel\n' > "$simulation_cache/SIMULATION"

{
  printf '%s\n' '// User settings' '// Plugin registry'
  jq -n --arg cache_path "$live_cache" \
    '{installedPlugins: [{name: "superpowers", cache_path: $cache_path}]}'
} > "$simulation_home/config.json"

"$HELPER" "$simulation_home/config.json" "$simulation_home" "$live_home"

rewritten_cache=$(jq -er '.installedPlugins[0].cache_path' "$simulation_home/config.json")
[ "$rewritten_cache" = "$simulation_cache" ] ||
  fail "cache_path was not rewritten into the simulation root: $rewritten_cache"
[ "$(stat -f '%Lp' "$simulation_home/config.json")" = 600 ] ||
  fail 'rewritten simulation config is not mode 0600'

case "$rewritten_cache" in
  "$scratch"/simulation/.copilot/*) ;;
  *) fail "simulated uninstall target escaped scratch: $rewritten_cache" ;;
esac
rm -rf -- "$rewritten_cache"

[ -f "$live_cache/LIVE" ] || fail 'simulated uninstall changed the live cache'
[ ! -e "$simulation_cache" ] || fail 'simulated uninstall did not target the simulation cache'

bad_home="$scratch/bad/.copilot"
mkdir -p "$bad_home"
jq -n --arg cache_path "$scratch/outside/plugin" \
  '{installedPlugins: [{name: "outside", cache_path: $cache_path}]}' \
  > "$bad_home/config.json"
if "$HELPER" "$bad_home/config.json" "$bad_home" "$live_home" >/dev/null 2>&1; then
  fail 'helper accepted a cache_path outside the declared live root'
fi

escaped_home="$scratch/escaped/.copilot"
mkdir -p "$escaped_home/installed-plugins/superpowers-marketplace"
ln -s "$live_cache" "$escaped_home/installed-plugins/superpowers-marketplace/superpowers"
jq -n --arg cache_path "$live_cache" \
  '{installedPlugins: [{name: "superpowers", cache_path: $cache_path}]}' \
  > "$escaped_home/config.json"
if "$HELPER" "$escaped_home/config.json" "$escaped_home" "$live_home" >/dev/null 2>&1; then
  fail 'helper accepted a simulation cache symlink that resolves into live'
fi

printf 'PASS: Copilot plugin simulation cache_path isolation\n'

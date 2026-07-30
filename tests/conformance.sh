#!/usr/bin/env bash
# Shared-skills conformance. Host global config belongs to host-local tests.
set -uo pipefail

AGENTS="${AGENTS_HOME:-$HOME/.agents}"
pass=0
fail=0
skipped=0

ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skip_check() { printf '  SKIP  %s\n' "$1"; skipped=$((skipped + 1)); }

if AGENTS_HOME="$AGENTS" "$AGENTS/bin/agents-sync" --check >/dev/null 2>&1; then
  ok "shared skills source"
else
  ng "shared skills source"
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-conformance.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.claude/skills"

if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --bootstrap >/dev/null 2>&1 &&
  HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --doctor >/dev/null 2>&1; then
  source_count="$(
    find "$AGENTS/skills" -mindepth 1 -maxdepth 1 -type d \
      ! -path "$AGENTS/skills/.claude" | wc -l | tr -d ' '
  )"
  link_count="$(find "$scratch/home/.claude/skills" -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')"
  [ "$source_count" = "$link_count" ] &&
    ok "Claude skill-link bootstrap: $link_count" ||
    ng "Claude skill-link count $link_count != source $source_count"
else
  ng "Claude skill-link bootstrap／doctor"
fi

retired_fail=0
for mode in default --deploy --only; do
  case "$mode" in
    default)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" >/dev/null 2>&1 &&
        retired_fail=1
      ;;
    --only)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" --only codex >/dev/null 2>&1 &&
        retired_fail=1
      ;;
    *)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1 &&
        retired_fail=1
      ;;
  esac
done
[ "$retired_fail" -eq 0 ] &&
  ok "retired host-deploy interfaces fail-loud" ||
  ng "retired host-deploy interface still succeeds"

protect_files="$AGENTS/skills/init-project-docs/references/hooks/protect-files.sh"
printf '%s' '{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\\n*** Update File: .env\\n@@\\n-A\\n+B\\n*** End Patch"}}' |
  env CLAUDECODE=1 bash "$protect_files" >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] &&
  ok "protect-files apply_patch(.env) fail-closed" ||
  ng "protect-files apply_patch(.env) allowed"

claimed="$(sed -n '1p' "$AGENTS/CONVENTIONS.md" | grep -oE '[0-9]+ 條' | grep -oE '[0-9]+' | head -1)"
actual="$(grep -c '^## [0-9]' "$AGENTS/CONVENTIONS.md")"
[ -n "$claimed" ] && [ "$claimed" = "$actual" ] &&
  ok "CONVENTIONS count $claimed" ||
  ng "CONVENTIONS claimed ${claimed:-none}, actual $actual"

if git -C "$HOME/.agents" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  live_branch="$(git -C "$HOME/.agents" branch --show-current 2>/dev/null || true)"
  [ "$live_branch" = main ] &&
    ok "live ~/.agents checkout is main" ||
    ng "live ~/.agents checkout is ${live_branch:-unknown}"
else
  skip_check "live ~/.agents checkout unavailable"
fi

ci_workflow="$AGENTS/.github/workflows/ci.yml"
if [ -f "$ci_workflow" ] &&
  ! grep -Eq 'AGENTS_DEPLOY_ROOT|dist/(skill-index\.md|AGENTS\.md|copilot-instructions\.md)|bin/agents-sync[[:space:]]+(--deploy|--only)' "$ci_workflow"; then
  ok "CI uses shared-skills contract"
else
  ng "CI still consumes retired agents-sync deployment"
fi

if bash -n "$AGENTS"/bin/* "$AGENTS"/hooks/*.sh "$AGENTS"/tests/*.sh; then
  ok "shared shell syntax"
else
  ng "shared shell syntax"
fi

if "$AGENTS/tests/legacy-mp-collision.sh" >/dev/null 2>&1; then
  ok "legacy mp collision guard"
else
  ng "legacy mp collision guard"
fi

# CONVENTIONS 規則 11 的 ~/.agents 一側，下沉自 prose（規則 9）。必須用 find 不得用
# ls + glob：後者在 zsh 下 nomatch 中止即回 0＝假合規。dotfile 排除＝規則 11 的
# 「app 自管 runtime state 備份」例外。
bak_count="$(find "$AGENTS" -name '*.bak*' -not -path '*/.git/*' -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$bak_count" = 0 ] &&
  ok "no manual .bak under ~/.agents" ||
  ng "manual .bak found under ~/.agents: $bak_count"

if "$AGENTS/tests/hook-parity.sh" >/dev/null 2>&1; then
  ok "[T0-3] guard parity checker"
else
  ng "[T0-3] guard parity checker"
fi

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]

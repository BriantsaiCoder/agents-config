#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
PLAN="$AGENTS/proposals/2026-07-27-mattpocock-skills-workflow/48-three-host-global-config-ownership-split-plan.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

skills_manifests_match() {
  local before="$1" after="$2" expected_metadata="$3" label="$4"
  local semantic_before="$scratch/$label-before.tsv"
  local semantic_after="$scratch/$label-after.tsv"
  local before_metadata after_metadata before_count after_count

  awk -F '	' 'NR == 1 || $1 != ".DS_Store"' "$before" > "$semantic_before"
  awk -F '	' 'NR == 1 || $1 != ".DS_Store"' "$after" > "$semantic_after"
  cmp -s "$semantic_before" "$semantic_after" || return 1

  before_metadata="$(awk -F '	' '$1 == ".DS_Store"' "$before")"
  after_metadata="$(awk -F '	' '$1 == ".DS_Store"' "$after")"
  before_count="$(awk -F '	' '$1 == ".DS_Store" { count++ } END { print count + 0 }' "$before")"
  after_count="$(awk -F '	' '$1 == ".DS_Store" { count++ } END { print count + 0 }' "$after")"
  if [ -n "$expected_metadata" ]; then
    [ "$before_count" -eq 1 ] && [ "$after_count" -eq 1 ] &&
      [ "$after_metadata" = "$expected_metadata" ] || return 1
  else
    [ "$before_count" -eq 0 ] && [ "$after_count" -eq 0 ] &&
      [ -z "$before_metadata" ] && [ -z "$after_metadata" ] || return 1
  fi
}

[ -f "$PLAN" ] || fail "ownership plan missing: $PLAN"
rg -Fq '只將 exact relative path `.DS_Store` 從 semantic skills payload gate 分離' "$PLAN" ||
  fail 'Plan 48 does not separate only exact .DS_Store from semantic skills payload'
rg -Fq '禁止 `*.DS_Store`、hidden-file wildcard與directory-wide exclusion' "$PLAN" ||
  fail 'Plan 48 does not prohibit wildcard skills exclusions'
rg -Fq '不得把 pre-cutover `UNAVAILABLE` 改寫成 `PASS`' "$PLAN" ||
  fail 'Plan 48 rewrites unavailable runtime evidence'
rg -Fq 'runtime no-load只在cutover transaction內逐host驗證' "$PLAN" ||
  fail 'Plan 48 does not defer runtime no-load to the cutover transaction'
rg -Fq '依Claude → Codex → Copilot固定順序' "$PLAN" ||
  fail 'Plan 48 does not preserve the fixed host order'
rg -Fq '確認Superpowers absent為PASS後才可進下一host' "$PLAN" ||
  fail 'Plan 48 advances before per-host plugin absence passes'
rg -Fq '任一host FAIL／UNAVAILABLE立即停止後續writes／probes並執行coordinated rollback' "$PLAN" ||
  fail 'Plan 48 does not fail fast into coordinated rollback'
rg -Fq 'fixed 6-run canary仍需獨立明示授權' "$PLAN" ||
  fail 'Plan 48 does not keep SaaS canaries separately authorized'
rg -Fq '只從 skill-directory enumeration排除 exact top-level `skills/.claude` runtime directory' "$PLAN" ||
  fail 'Plan 48 does not define the exact skills/.claude runtime exclusion'
rg -Fq '禁止 hidden-directory wildcard' "$PLAN" ||
  fail 'Plan 48 does not prohibit wildcard runtime-directory exclusions'
rg -Fq '不得以 `.in_use` directory count = 0作為maintenance gate' "$PLAN" ||
  fail 'Plan 48 treats persistent .in_use directories as active locks'
rg -Fq 'Claude process count = 0、active marker-owner intersection = 0、兩個exact Superpowers trees open-handle count = 0' "$PLAN" ||
  fail 'Plan 48 does not define the active-owner maintenance gate'
rg -Fq '禁止刪除、清空或wildcard處理任何 `.in_use`' "$PLAN" ||
  fail 'Plan 48 permits destructive .in_use cleanup'

if rg -q \
  'TARGETS=|\.codex/AGENTS\.md|\.copilot/copilot-instructions\.md|refresh_claude_stamp|assemble_body|render_target' \
  "$AGENTS/bin/agents-sync"; then
  fail 'agents-sync still owns host global config'
fi

resolve_worktree() {
  local repo="$1" branch="$2"
  git -C "$repo" worktree list --porcelain |
    awk -v ref="refs/heads/$branch" '
      /^worktree / { path=substr($0, 10) }
      $0=="branch " ref { print path }
    '
}

CLAUDE_CANDIDATE="${CLAUDE_CANDIDATE:-$(resolve_worktree "$HOME/.claude" codex/three-host-global-config-split-claude)}"
CODEX_CANDIDATE="${CODEX_CANDIDATE:-$(resolve_worktree "$HOME/.codex" codex/three-host-global-config-split-codex)}"
COPILOT_CANDIDATE="${COPILOT_CANDIDATE:-$(resolve_worktree "$HOME/.copilot" codex/three-host-global-config-split-copilot)}"

for candidate in "$CLAUDE_CANDIDATE" "$CODEX_CANDIDATE" "$COPILOT_CANDIDATE"; do
  [ -d "$candidate" ] || fail "host candidate missing: $candidate"
done

preserved_response_policy='- 回覆 SHOULD outcome-first、無空泛前後文；決策列編號選項／推薦／取捨，單字或數字即為完整回答，推測標記，已決不列替案。'
for active_config in \
  "$CLAUDE_CANDIDATE/CLAUDE.md" \
  "$CODEX_CANDIDATE/AGENTS.md" \
  "$COPILOT_CANDIDATE/copilot-instructions.md"; do
  rg -Fqx -- "$preserved_response_policy" "$active_config" ||
    fail "host candidate drops preserved T2-6 response policy: $active_config"
done

expected_tier2_sha='677f78d81cfe358760584b27bd7a8e0e7e08fd1197842f08ceabb7f725aeba5e'
shared_tier2_sha="$(shasum -a 256 "$AGENTS/core/tier2-style.md" | awk '{ print $1 }')"
claude_tier2_sha="$(shasum -a 256 "$CLAUDE_CANDIDATE/core/tier2-style.md" | awk '{ print $1 }')"
[ "$shared_tier2_sha" = "$expected_tier2_sha" ] ||
  fail 'shared candidate does not preserve exact current T2-6 source bytes'
[ "$claude_tier2_sha" = "$expected_tier2_sha" ] ||
  fail 'Claude candidate does not materialize exact current T2-6 source bytes'
rg -Fq 'current T2-6只保留到三家host-local active config；不得恢復 `.agents` control-plane ownership' "$PLAN" ||
  fail 'Plan 48 does not preserve T2-6 under host-local ownership'

scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-ownership.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.claude/skills" "$scratch/home/.codex" "$scratch/home/.copilot"

runtime_agents="$scratch/runtime-agents"
runtime_home="$scratch/runtime-home"
mkdir -p \
  "$runtime_agents/bin" \
  "$runtime_agents/skills/example-skill" \
  "$runtime_agents/skills/.claude/.cc-writes" \
  "$runtime_home/.claude/skills"
cp "$AGENTS/bin/agents-sync" "$runtime_agents/bin/agents-sync"
chmod 755 "$runtime_agents/bin/agents-sync"
printf '%s\n' '# example' > "$runtime_agents/skills/example-skill/SKILL.md"
HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --bootstrap >/dev/null 2>&1 ||
  fail 'agents-sync rejected exact skills/.claude runtime directory'
HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --doctor >/dev/null 2>&1 ||
  fail 'agents-sync doctor counted exact skills/.claude as a skill'
[ -L "$runtime_home/.claude/skills/example-skill" ] ||
  fail 'agents-sync did not bootstrap the real skill beside skills/.claude'
[ ! -e "$runtime_home/.claude/skills/.claude" ] ||
  fail 'agents-sync created a Claude link for skills/.claude'

mkdir -p "$runtime_agents/skills/.unexpected-runtime"
if HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --check >/dev/null 2>&1; then
  fail 'agents-sync excluded an unknown hidden directory'
fi
rm -rf "$runtime_agents/skills/.unexpected-runtime"

shadow_shared="$scratch/shared-skills-live-shape"
mkdir -p "$shadow_shared/.claude/.cc-writes"
for link in "$CLAUDE_CANDIDATE"/skills/*; do
  mkdir -p "$shadow_shared/$(basename "$link")"
done
(
  cd "$CLAUDE_CANDIDATE"
  SHARED_SKILLS_ROOT="$shadow_shared" bash tests/repo-integrity.sh >/dev/null
) || fail 'Claude inventory treated exact skills/.claude as a skill'

for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  printf 'host-global-config-sentinel\n' > "$sentinel"
  chmod 000 "$sentinel"
done

sentinel_before="$scratch/sentinel-before.tsv"
sentinel_after="$scratch/sentinel-after.tsv"
for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  stat -f '%N	%z	%Lp' "$sentinel" >> "$sentinel_before"
done

for mode in --check --doctor --bootstrap; do
  HOME="$scratch/home" AGENTS_HOME="$AGENTS" "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1 ||
    fail "skills-only mode failed: $mode"
done
for mode in default --deploy --only; do
  case "$mode" in
    default)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" >/dev/null 2>&1; then
        fail "retired interface did not fail loud: $mode"
      fi
      ;;
    --only)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" --only codex >/dev/null 2>&1; then
        fail "retired interface did not fail loud: $mode"
      fi
      ;;
    *)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1; then
        fail "retired interface did not fail loud: $mode"
      fi
      ;;
  esac
done

for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  stat -f '%N	%z	%Lp' "$sentinel" >> "$sentinel_after"
done
diff -u "$sentinel_before" "$sentinel_after" >/dev/null ||
  fail 'skills-only modes changed host global config metadata'

if rg -n '\.agents/(core|rules|hooks|hosts|dist|bin)(/|`|$)' \
  "$CLAUDE_CANDIDATE/CLAUDE.md" \
  "$CLAUDE_CANDIDATE/settings.json" \
  "$CODEX_CANDIDATE/AGENTS.md" \
  "$CODEX_CANDIDATE/hooks.json" \
  "$COPILOT_CANDIDATE/copilot-instructions.md" >/dev/null; then
  fail 'active host global config still references .agents control plane'
fi

for dir in core rules hooks; do
  if find "$CLAUDE_CANDIDATE/$dir" -maxdepth 1 -type l -print -quit | grep -q .; then
    fail "Claude $dir still contains symlink"
  fi
done
for link in "$CLAUDE_CANDIDATE"/skills/*; do
  [ -L "$link" ] || fail "Claude skill is not symlink: $link"
  expected="../../.agents/skills/$(basename "$link")"
  [ "$(readlink "$link")" = "$expected" ] || fail "Claude skill target changed: $link"
done

head -1 "$CODEX_CANDIDATE/AGENTS.md" | grep -q '^<!-- GENERATED by ~/.agents/bin/agents-sync' &&
  fail 'Codex generated banner still present'
head -1 "$COPILOT_CANDIDATE/copilot-instructions.md" | grep -q '^<!-- GENERATED by ~/.agents/bin/agents-sync' &&
  fail 'Copilot generated banner still present'

for candidate in "$CODEX_CANDIDATE" "$COPILOT_CANDIDATE"; do
  for rule in cookbook cpp dotnet frontend-spa infra testing typescript winforms; do
    [ -f "$candidate/rules/$rule.md" ] || fail "local stack rule missing: $candidate/rules/$rule.md"
  done
done

for retired in dist hosts; do
  if [ -e "$AGENTS/$retired" ]; then
    fail "retired generated surface reappeared: $AGENTS/$retired"
  fi
done

if [ -s "$AGENTS/attic/dist/manifest.tsv" ] &&
  rg -q '\.codex/AGENTS\.md|\.copilot/copilot-instructions\.md' "$AGENTS/attic/dist/manifest.tsv"; then
  fail 'retired manifest still contains host global config'
fi

skills_before="${OWNERSHIP_SKILLS_BEFORE:-/private/tmp/three-host-global-config-split-impl-skills-before.tsv}"
skills_after="${OWNERSHIP_SKILLS_AFTER:-/private/tmp/three-host-global-config-split-ownership-after.tsv}"
skills_metadata="${OWNERSHIP_DS_STORE_METADATA:-}"
[ -f "$skills_before" ] || fail "ownership skills baseline missing: $skills_before"
[ -f "$skills_after" ] || fail "ownership skills after manifest missing: $skills_after"
skills_manifests_match "$skills_before" "$skills_after" "$skills_metadata" candidate ||
  fail 'ownership semantic skills manifest changed'

accepted_metadata=$'.DS_Store\tfile\tabac08d6445bcc8848a10a5e0e2a406629d2dea627e500c8e6006f720a647606\t57348\t644\t-'
fixture_before="$scratch/skills-before.tsv"
fixture_after="$scratch/skills-after.tsv"
fixture_drift="$scratch/skills-drift.tsv"
printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  $'.DS_Store\tfile\tfe6954846fbf416c1071b408009723b4c65773d4a2ebed156e42ec05a7f293c0\t57348\t644\t-' \
  > "$fixture_before"
printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_after"
skills_manifests_match "$fixture_before" "$fixture_after" "$accepted_metadata" accepted ||
  fail 'exact .DS_Store reconciliation did not pass'

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  $'.DS_Store\tfile\tchanged\t57348\t644\t-' > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" metadata-drift; then
  fail 'changed .DS_Store metadata was accepted'
fi

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\nnested/.DS_Store\tfile\tchanged\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" nested-drift; then
  fail 'nested .DS_Store was excluded as a wildcard'
fi

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tchanged\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" semantic-drift; then
  fail 'semantic skills drift was accepted'
fi

for carrier in \
  "$AGENTS/docs/agents/issue-tracker.md" \
  "$AGENTS/rules/typescript.md" \
  "$AGENTS/rules/frontend-spa.md"; do
  [ -f "$carrier" ] || fail "compatibility carrier missing: $carrier"
done

historical_before="${HISTORICAL_BEFORE:-/private/tmp/three-host-global-config-split-historical-before.tsv}"
historical_after="${HISTORICAL_AFTER:-/private/tmp/three-host-global-config-split-historical-after.tsv}"
[ -f "$historical_before" ] || fail "historical baseline missing: $historical_before"
[ -f "$historical_after" ] || fail "historical after manifest missing: $historical_after"
diff -u "$historical_before" "$historical_after" >/dev/null || fail 'historical artifacts changed'

live_before="${LIVE_BEFORE:-/private/tmp/three-host-global-config-split-live-before.tsv}"
live_after="${LIVE_AFTER:-/private/tmp/three-host-global-config-split-live-after.tsv}"
[ -f "$live_before" ] || fail "live baseline missing: $live_before"
[ -f "$live_after" ] || fail "live after fingerprint missing: $live_after"
diff -u "$live_before" "$live_after" >/dev/null || fail 'live repo fingerprints changed'

printf 'PASS: three-host global-config ownership contract\n'

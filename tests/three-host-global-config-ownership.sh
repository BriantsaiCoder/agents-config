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

scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-ownership.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.claude/skills" "$scratch/home/.codex" "$scratch/home/.copilot"

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

if [ -s "$AGENTS/dist/manifest.tsv" ] &&
  rg -q '\.codex/AGENTS\.md|\.copilot/copilot-instructions\.md' "$AGENTS/dist/manifest.tsv"; then
  fail 'active manifest still contains host global config'
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

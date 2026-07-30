#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORKFLOW_BASE="${WORKFLOW_BASE:-d6fd1f1}"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"
GRILLING="$AGENTS/skills/grilling/SKILL.md"
VENDORED_LIB="$AGENTS/skills/auditing-skill-folder/scripts/lib-vendored.sh"

# shellcheck source=../skills/auditing-skill-folder/scripts/lib-vendored.sh
. "$VENDORED_LIB"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for retired in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
  [ ! -e "$AGENTS/skills/$retired" ] ||
    fail "legacy workflow wrapper still active: $retired"
done

for heading in \
  'S0 ROUTE' \
  'S2 AUTHORIZE' \
  'BUGFIX RED' \
  'S4 VERIFY' \
  'S5 REVIEW' \
  'S6 CLOSEOUT' \
  'Host adapters'; do
  rg -q "$heading" "$KERNEL" || fail "thin kernel heading missing: $heading"
done

for rule in INT-1 INT-2 INT-3 INT-4 INT-5 INT-6; do
  rg -q "\\[$rule\\]" "$KERNEL" || fail "thin kernel guard missing: $rule"
done

for skill in \
  triage \
  grilling \
  domain-modeling \
  grill-with-docs \
  to-spec \
  to-tickets \
  implement \
  tdd \
  diagnosing-bugs \
  code-review \
  codebase-design \
  wayfinder \
  handoff; do
  rg -q "\`$skill\`" "$KERNEL" || fail "active route missing: $skill"
  [ -f "$AGENTS/skills/$skill/SKILL.md" ] || fail "routed skill missing: $skill"
done

rg -q '2.?3.*options.*recommended.*first' "$GRILLING" ||
  fail 'grilling does not offer compact options with the recommendation first'
rg -q 'explicitly authorizes.*low-risk.*reversible' "$GRILLING" ||
  fail 'grilling lacks opt-in defaults for low-risk reversible decisions'
rg -q 'high-risk.*irreversible.*scope.*low-confidence' "$GRILLING" ||
  fail 'grilling lacks mandatory pause conditions'
rg -q 'summarize.*explicit confirmation' "$GRILLING" ||
  fail 'grilling lacks final decision summary and confirmation'
fork_recorded grilling ||
  fail 'grilling fork is not recorded inside the fork index'
expected_grilling_sha="$(
  sed -n 's/.*payload SHA-256 `\([a-f0-9]\{64\}\)`.*/\1/p' "$AGENTS/vendored-forks.md" |
    head -1
)"
[ -n "$expected_grilling_sha" ] ||
  fail 'grilling fork record lacks an approved payload SHA-256'
actual_grilling_sha="$(shasum -a 256 "$GRILLING" | awk '{ print $1 }')"
[ "$actual_grilling_sha" = "$expected_grilling_sha" ] ||
  fail 'grilling payload differs from the recorded fork fingerprint'
rg -q '21 unmodified.*1 recorded fork' "$AGENTS/vendored-forks.md" ||
  fail 'Matt set summary does not distinguish the grilling fork'

rg -q 'implement.*S4.*S5.*S6|S4.*S5.*S6.*implement' "$KERNEL" ||
  fail 'implement route does not return to S4-S6'
rg -q 'implement.*(isolated worktree|branch)' "$KERNEL" ||
  fail 'implement route lacks isolated branch entry'
rg -q 'implement.*(current|main).*(MUST NOT|不得)|MUST NOT.*implement.*(current|main)' "$KERNEL" ||
  fail 'implement route does not reject current/main commits'
rg -q 'GREEN.*micro-refactor|micro-refactor.*GREEN' "$KERNEL" ||
  fail 'post-GREEN micro-refactor rule missing'

if rg -n 'superpowers:' "$AGENTS/skills" >/dev/null; then
  fail 'active shared skills still reference Superpowers'
fi
# 2026-07-30：掃描目標從 $AGENTS/core/routing.md 改為 $KERNEL（dev-workflow SKILL.md）。
# core/ 三家 runtime 都不讀，已退役至 attic/core/；active routing 的真正本是
# kernel 的 S0 ROUTE 表。
if rg -n 'mp-(diagnose|grill-with-docs|improve-codebase-architecture|tdd)' \
  "$KERNEL" "$AGENTS/skills" >/dev/null; then
  fail 'active routing or shared skills still reference retired wrappers'
fi

[ -f "$AGENTS/skills/mp-zoom-out/SKILL.md" ] ||
  fail 'mp-zoom-out missing'
rg -q 'unfamiliar area.*system map|system map.*unfamiliar area' \
  "$AGENTS/skills/mp-zoom-out/SKILL.md" ||
  fail 'mp-zoom-out scope drifted'
git -C "$AGENTS" diff --quiet "$WORKFLOW_BASE" -- skills/mp-zoom-out ||
  fail 'mp-zoom-out changed'

while IFS='=' read -r key skill; do
  [ "$key" = skill ] || continue
  if ! git -C "$AGENTS" diff --quiet "$WORKFLOW_BASE" -- "skills/$skill"; then
    [ "$skill" = grilling ] && fork_recorded grilling ||
      fail "unrecorded Matt upstream skill change: $skill"
  fi
done < "$AGENTS/mattpocock-skills.lock"

# 最後兩個 pattern 是 2026-07-30 rules/ 退役加入的：那兩處只移除指向 ~/.agents/rules/
# 的死路徑，改成不帶路徑的「家規」措辭（規則內容本來就內聯在同一段）。兩者都是 house
# skill，不在 mattpocock-skills.lock 的 22 個內，所以上面第 106-112 行的 vendored gate
# 不適用。註解不能插在 case pattern 的 `\` 續行之間——那是語法錯誤。
while IFS= read -r changed; do
  case "$changed" in
    skills/dev-workflow/* | \
    skills/grilling/SKILL.md | \
    skills/mp-diagnose/* | \
    skills/mp-grill-with-docs/* | \
    skills/mp-improve-codebase-architecture/* | \
    skills/mp-tdd/* | \
    skills/typescript-best-practices/references/config-and-project.md | \
    skills/vue-best-practices/references/styling-and-ui.md) ;;
    *) fail "non-allowlisted shared skill changed: $changed" ;;
  esac
done < <(git -C "$AGENTS" diff --name-only "$WORKFLOW_BASE" -- skills)

parity="${WRAPPER_PARITY_EVIDENCE:-/private/tmp/three-host-global-config-split-wrapper-parity.tsv}"
[ -f "$parity" ] || fail "wrapper parity evidence missing: $parity"
for retired in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
  awk -F '\t' -v wrapper="$retired" \
    '$1==wrapper && $2=="PASS" {found=1} END {exit !found}' "$parity" ||
    fail "wrapper parity missing: $retired"
done

git -C "$AGENTS" diff --quiet "$WORKFLOW_BASE" -- \
  bin/phase4-canary-harness tests/phase4-canary-harness.sh ||
  fail 'Phase 4 historical artifacts changed'

printf 'PASS: Matt thin workflow contract\n'

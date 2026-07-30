#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORKFLOW_BASE="${WORKFLOW_BASE:-d6fd1f1}"
B2_SKILLS_BASE="${B2_SKILLS_BASE:-7080450715c0e5f264e19ab60a48da9c4437c0af}"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"
GRILLING="$AGENTS/skills/grilling/SKILL.md"
WRITING_SKILLS="$AGENTS/skills/writing-great-skills/SKILL.md"
WRITING_SKILLS_DIR="$AGENTS/skills/writing-great-skills"
WRITING_SKILLS_POLICY="$AGENTS/skills/writing-great-skills/agents/openai.yaml"
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

for rule in INT-1 INT-2 INT-3 INT-4 INT-5 INT-6 INT-7; do
  rg -q "\\[$rule\\]" "$KERNEL" || fail "thin kernel guard missing: $rule"
done

while IFS= read -r skill; do
  [ -f "$AGENTS/skills/$skill/SKILL.md" ] || fail "routed skill missing: $skill"
done < <(
  sed -n '/^| Need | Route |$/,/^$/p' "$KERNEL" |
    rg -o '`[a-z0-9-]+`' |
    tr -d '`' |
    sort -u
)

expected_invocation_sha="$(
  sed -n 's/^invocation_manifest_sha256=//p' "$AGENTS/mattpocock-skills.lock"
)"
[[ "$expected_invocation_sha" =~ ^[a-f0-9]{64}$ ]] ||
  fail 'Matt invocation manifest fingerprint missing'
actual_invocation_sha="$(
  while IFS='=' read -r key skill; do
    [ "$key" = skill ] || continue
    if rg -q '^disable-model-invocation:[[:space:]]*true$' \
      "$AGENTS/skills/$skill/SKILL.md"; then
      mode=user
    else
      mode=model
    fi
    printf '%s=%s\n' "$skill" "$mode"
  done < "$AGENTS/mattpocock-skills.lock" |
    LC_ALL=C sort |
    shasum -a 256 |
    awk '{ print $1 }'
)"
[ "$actual_invocation_sha" = "$expected_invocation_sha" ] ||
  fail 'Matt invocation split drifted'

while IFS='=' read -r key skill; do
  [ "$key" = skill ] || continue
  rg -q '^disable-model-invocation:[[:space:]]*true$' \
    "$AGENTS/skills/$skill/SKILL.md" || continue
  policy="$AGENTS/skills/$skill/agents/openai.yaml"
  [ -f "$policy" ] ||
    fail "Codex user-only policy missing: $skill"
  rg -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false$' "$policy" ||
    fail "Codex user-only policy permits implicit invocation: $skill"
done < "$AGENTS/mattpocock-skills.lock"

! rg -q '^disable-model-invocation:[[:space:]]*true$' "$WRITING_SKILLS" ||
  fail 'writing-great-skills is not model-invoked'
rg -q '^description: Skill authoring.*single skill' "$WRITING_SKILLS" ||
  fail 'writing-great-skills lacks a focused model trigger'
rg -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*true$' \
  "$WRITING_SKILLS_POLICY" ||
  fail 'Codex policy blocks writing-great-skills implicit invocation'
fork_recorded writing-great-skills ||
  fail 'writing-great-skills fork is not recorded inside the fork index'
expected_writing_tree_sha="$(
  sed -n '/^## writing-great-skills$/,/^---$/p' "$AGENTS/vendored-forks.md" |
    sed -n 's/.*tree SHA-256: `\([a-f0-9]\{64\}\)`.*/\1/p'
)"
[ -n "$expected_writing_tree_sha" ] ||
  fail 'writing-great-skills fork record lacks an approved tree SHA-256'
actual_writing_tree_sha="$(vendored_tree_sha256 "$WRITING_SKILLS_DIR")"
[ "$actual_writing_tree_sha" = "$expected_writing_tree_sha" ] ||
  fail 'writing-great-skills tree differs from the recorded fork fingerprint'

rg -q '\[INT-7\].*disable-model-invocation.*MUST NOT.*自動 invoke' "$KERNEL" ||
  fail 'thin kernel does not preserve the Matt user-only invocation boundary'
rg -q 'user-only skill.*推薦.*explicit invocation command.*等待' "$KERNEL" ||
  fail 'thin kernel does not hand user-only routes back to explicit user invocation'
sed -n '/^### Claude$/,/^### Codex$/p' "$KERNEL" |
  rg -q 'user-only skill command = `/<skill-name>`' ||
  fail 'Claude user-only invocation syntax missing'
sed -n '/^### Codex$/,/^### Copilot$/p' "$KERNEL" |
  rg -q 'user-only skill command = `\$<skill-name>`' ||
  fail 'Codex user-only invocation syntax missing'
sed -n '/^### Copilot$/,/^## References$/p' "$KERNEL" |
  rg -q 'user-only skill command = `/<skill-name>`' ||
  fail 'Copilot user-only invocation syntax missing'

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
rg -q '20 unmodified.*2 recorded forks' "$AGENTS/vendored-forks.md" ||
  fail 'Matt set summary does not distinguish both recorded forks'

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
    fork_recorded "$skill" ||
      fail "unrecorded Matt upstream skill change: $skill"
  fi
done < "$AGENTS/mattpocock-skills.lock"

# 最後兩個 pattern 是 2026-07-30 rules/ 退役加入的：那兩處只移除指向 ~/.agents/rules/
# 的死路徑，改成不帶路徑的「家規」措辭（規則內容本來就內聯在同一段）。兩者都是 house
# skill，不在 mattpocock-skills.lock 的 22 個內，所以上面第 106-112 行的 vendored gate
# 不適用。註解不能插在 case pattern 的 `\` 續行之間——那是語法錯誤。
# Stage B2 的 commit 同時是 exact directory allowlist 與 payload checkpoint。這會允許
# 該 commit 新增的 26 個目錄存在，但拒絕它們在 checkpoint 後被新增、刪除或改寫。
b2_skills="$(
  git -C "$AGENTS" diff-tree --no-commit-id --name-only -r \
    "$B2_SKILLS_BASE" -- skills |
    awk -F/ 'NF > 1 { print $2 }' |
    LC_ALL=C sort -u
)"
[ "$(printf '%s\n' "$b2_skills" | grep -c .)" -eq 26 ] ||
  fail 'Stage B2 skill checkpoint does not contain exactly 26 directories'
while IFS= read -r skill; do
  if [ "$skill" = dotnet-core-expert ]; then
    fork_recorded "$skill" ||
      fail 'dotnet-core-expert Stage B2 fork is not recorded'
    expected_tree_sha="$(
      vendored_lock_record "$skill" |
        awk -F '\t' '{ print $5 }'
    )"
    actual_tree_sha="$(vendored_tree_sha256 "$AGENTS/skills/$skill")"
    [ -n "$expected_tree_sha" ] && [ "$actual_tree_sha" = "$expected_tree_sha" ] ||
      fail 'dotnet-core-expert tree differs from its recorded fork fingerprint'
    continue
  fi
  if [ "$skill" = video-downloader ]; then
    [ ! -e "$AGENTS/skills/video-downloader" ] &&
      [ ! -L "$AGENTS/skills/video-downloader" ] ||
      fail 'retired video-downloader directory still exists'
    expected_payload_sha="$(
      vendored_lock_record youtube-downloader |
        awk -F '\t' '{ print $4 }'
    )"
    actual_payload_sha="$(
      cd "$AGENTS/skills/youtube-downloader" &&
        find . -type f -print0 |
        LC_ALL=C sort -z |
        xargs -0 shasum -a 256 |
        shasum -a 256 |
        awk '{ print $1 }'
    )"
    [ "$actual_payload_sha" = "$expected_payload_sha" ] ||
      fail 'youtube-downloader payload differs from the Stage B2 checkpoint'
    expected_tree_sha="$(
      vendored_lock_record youtube-downloader |
        awk -F '\t' '{ print $5 }'
    )"
    actual_tree_sha="$(vendored_tree_sha256 "$AGENTS/skills/youtube-downloader")"
    [ -n "$expected_tree_sha" ] && [ "$actual_tree_sha" = "$expected_tree_sha" ] ||
      fail 'youtube-downloader structure differs from the Stage B2 checkpoint'
    continue
  fi
  git -C "$AGENTS" diff --quiet "$B2_SKILLS_BASE" -- "skills/$skill" ||
    fail "Stage B2 skill payload changed after checkpoint: $skill"
done <<<"$b2_skills"

while IFS= read -r changed; do
  case "$changed" in
    skills/auditing-skill-folder/SKILL.md | \
    skills/auditing-skill-folder/scripts/lib-vendored.sh | \
    skills/dev-workflow/* | \
    skills/mp-diagnose/* | \
    skills/mp-grill-with-docs/* | \
    skills/mp-improve-codebase-architecture/* | \
    skills/mp-tdd/* | \
    skills/typescript-best-practices/references/config-and-project.md | \
    skills/vue-best-practices/references/styling-and-ui.md) ;;
    *)
      changed_skill="${changed#skills/}"
      changed_skill="${changed_skill%%/*}"
      if fork_recorded "$changed_skill"; then
        continue
      fi
      if [ "$changed_skill" = youtube-downloader ]; then
        checkpoint_skill=video-downloader
      else
        checkpoint_skill="$changed_skill"
      fi
      printf '%s\n' "$b2_skills" | grep -Fxq "$checkpoint_skill" ||
        fail "non-allowlisted shared skill changed: $changed"
      ;;
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

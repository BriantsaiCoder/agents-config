#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORKFLOW_BASE="${WORKFLOW_BASE:-d6fd1f1}"
B2_SKILLS_LOCK="$AGENTS/stage-b2-skills.lock"
WRAPPER_PARITY_EVIDENCE="$AGENTS/proposals/2026-07-27-mattpocock-skills-workflow/49-three-host-global-config-ownership-split-candidate-evidence.md"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"
GRILLING="$AGENTS/skills/grilling/SKILL.md"
HANDOFF="$AGENTS/skills/handoff/SKILL.md"
DIAGNOSING="$AGENTS/skills/diagnosing-bugs/SKILL.md"
DIAGNOSING_DIR="$AGENTS/skills/diagnosing-bugs"
WRITING_SKILLS="$AGENTS/skills/writing-great-skills/SKILL.md"
WRITING_SKILLS_DIR="$AGENTS/skills/writing-great-skills"
WRITING_GLOSSARY="$WRITING_SKILLS_DIR/GLOSSARY.md"
WRITING_SKILLS_POLICY="$AGENTS/skills/writing-great-skills/agents/openai.yaml"
AUDIT_SKILL="$AGENTS/skills/auditing-skill-folder/SKILL.md"
AUDIT_VENDORED_GATE="$AGENTS/skills/auditing-skill-folder/step0-vendored-gate.md"
AUDIT_VERDICT_GUIDE="$AGENTS/skills/auditing-skill-folder/step1-verdict-guide.md"
AUDIT_TRIGGER_EVAL="$AGENTS/skills/auditing-skill-folder/step2c-trigger-eval.md"
AUDIT_TRIGGER_RUNNER="$AGENTS/skills/auditing-skill-folder/scripts/eval-triggers.sh"
AUDIT_STYLE_CHECKS="$AGENTS/skills/auditing-skill-folder/step7-style-checks.md"
AUDIT_LINTER="$AGENTS/skills/auditing-skill-folder/scripts/lint-descriptions.sh"
VENDORED_LIB="$AGENTS/skills/auditing-skill-folder/scripts/lib-vendored.sh"

# shellcheck source=../skills/auditing-skill-folder/scripts/lib-vendored.sh
. "$VENDORED_LIB"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Anchored to the row's leading "| `<skill>`", per the MACHINE-READ contract in
# vendored-forks.md. A positional read would silently pick another fork's SHA.
fork_payload_sha() {
  sed -n "s/^| \`$1\` .*payload SHA-256 \`\([a-f0-9]\{64\}\)\`.*/\1/p" \
    "$AGENTS/vendored-forks.md" | head -1
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
rg -q '^description: .*Agent Skill fires unreliably.*RED trigger canary before rewrite' "$DIAGNOSING" ||
  fail 'diagnosing-bugs lacks the skill-trigger failure branch'
fork_recorded diagnosing-bugs ||
  fail 'diagnosing-bugs fork is not recorded inside the fork index'
expected_diagnosing_tree_sha="$(
  sed -n '/^## diagnosing-bugs$/,/^---$/p' "$AGENTS/vendored-forks.md" |
    sed -n 's/.*tree SHA-256: `\([a-f0-9]\{64\}\)`.*/\1/p'
)"
[ -n "$expected_diagnosing_tree_sha" ] ||
  fail 'diagnosing-bugs fork record lacks an approved tree SHA-256'
actual_diagnosing_tree_sha="$(vendored_tree_sha256 "$DIAGNOSING_DIR")"
[ "$actual_diagnosing_tree_sha" = "$expected_diagnosing_tree_sha" ] ||
  fail 'diagnosing-bugs tree differs from the recorded fork fingerprint'
rg -q "^description: Agent Skill authoring\. Use when editing one existing Agent Skill's model/user invocation mode.*another skill routes an already-red single-target behavior rewrite here.*Existing-skill invocation edits stay here.*host creator owns new-skill scaffolding.*folder auditor owns directory audits" "$WRITING_SKILLS" ||
  fail 'writing-great-skills lacks its identity clause, disambiguated authoring, or post-RED triggers'
rg -q '^\*\*REQUIRED PRECONDITION:\*\*.*preserved RED trigger canary.*Step 2c RED satisfies this gate' "$WRITING_SKILLS" ||
  fail 'writing-great-skills does not accept a caller-provided Step 2c RED'
rg -q '^\*\*REQUIRED SUB-SKILL:\*\* For a misbehavior rewrite with no caller-supplied RED, invoke `diagnosing-bugs` first' "$WRITING_SKILLS" ||
  fail 'writing-great-skills does not scope the trigger-diagnosis dependency to a misbehavior rewrite'
rg -q 'full.*record a verdict for every applicable section' "$WRITING_SKILLS" ||
  fail 'writing-great-skills lacks the full-audit completion criterion'
rg -q 'scoped edit.*only the named branch' "$WRITING_SKILLS" ||
  fail 'writing-great-skills expands scoped edits into full audits'
rg -q 'trigger RED canary.*GREEN' "$WRITING_SKILLS" ||
  fail 'writing-great-skills does not preserve RED to GREEN evidence'
writing_words=$(LC_ALL=C wc -w < "$WRITING_SKILLS" | tr -d ' ')
[ "$writing_words" -le 500 ] ||
  fail "writing-great-skills exceeds its 500-word budget: $writing_words"
[ -r "$WRITING_GLOSSARY" ] ||
  fail 'writing-great-skills glossary is missing or unreadable'
rg -Fq '](GLOSSARY.md)' "$WRITING_SKILLS" ||
  fail 'writing-great-skills no longer points to its glossary'
rg -Fq 'Look for repeated phrasing a **leading word** can collapse; keep it only when a canary shows improved invocation or execution.' "$WRITING_SKILLS" ||
  fail 'writing-great-skills no longer searches for evidence-gated leading words'
rg -Fq "Use each heading's exact term for that concept; synonyms dilute its **leading word**." "$WRITING_GLOSSARY" ||
  fail 'writing-great-skills no longer preserves canonical glossary terminology'
! rg -q '^_Avoid_:' "$WRITING_GLOSSARY" ||
  fail 'writing-great-skills glossary still carries negation sediment'
! rg -q '_comprehensive_, _thorough_' "$WRITING_GLOSSARY" ||
  fail 'writing-great-skills still presents thorough as both weak and effective'
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
indexed_writing_tree_sha="$(
  sed -n '/^| `writing-great-skills` |/s/.*tree SHA-256 `\([a-f0-9]\{64\}\)`.*/\1/p' \
    "$AGENTS/vendored-forks.md"
)"
[ "$indexed_writing_tree_sha" = "$expected_writing_tree_sha" ] ||
  fail 'writing-great-skills fork index and detailed fingerprint disagree'
actual_writing_tree_sha="$(vendored_tree_sha256 "$WRITING_SKILLS_DIR")"
[ "$actual_writing_tree_sha" = "$expected_writing_tree_sha" ] ||
  fail 'writing-great-skills tree differs from the recorded fork fingerprint'

rg -q '\.\./dev-workflow/SKILL\.md' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder does not route through the canonical dev-workflow path'
audit_words=$(
  "$AGENTS/skills/auditing-skill-folder/scripts/count-words.sh" "$AGENTS/skills" |
    awk '$6 == "auditing-skill-folder" { print $1 }'
)
[ -n "$audit_words" ] ||
  fail 'auditing-skill-folder is missing from the effective word-count report'
[ "$audit_words" -le 500 ] ||
  fail "auditing-skill-folder exceeds its 500-word effective budget: $audit_words"
rg -q '完成條件：Step 0' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder no longer requires the vendored gate to run first'
rg -q 'Portable structural gate.*必要' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder lacks a required portable structural gate'
rg -q 'name.*frontmatter.*relative references' "$AUDIT_SKILL" ||
  fail 'portable structural gate does not cover name, frontmatter, and relative references'
rg -q 'Steps 1–6.*資料夾.*Step 2b' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder required completion contract is incomplete'
rg -q 'RUN.*SKIPPED\(reason\)' "$AUDIT_SKILL" ||
  fail 'Step 2c does not require an honest RUN or SKIPPED(reason) record'
rg -q 'Step 2c 不影響必要完成條件' "$AUDIT_SKILL" ||
  fail 'optional Step 2c still changes required completion'
rg -q 'Move-to-host/repo-instructions' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder still lacks a host-neutral instruction verdict'
rg -q 'Convert-to-deterministic-enforcement' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder still lacks a host-neutral enforcement verdict'
sed -n '/^### Step 2c/,/^## 報告契約/p' "$AUDIT_SKILL" |
  rg -q '各 host.*PASS.*FAIL.*UNAVAILABLE' ||
  fail 'auditing-skill-folder does not preserve per-host evidence'
! rg -q 'Move-to-CLAUDE\.md|propose CLAUDE\.md' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder still hard-codes the Claude instruction surface'
step6_row=$(sed -n '/^| 6 |/p' "$AUDIT_SKILL")
printf '%s\n' "$step6_row" | rg -q 'behavior-changing unique policies.*guards.*procedures' ||
  fail 'Delete criterion lacks a behavior-changing unique-content inventory'
printf '%s\n' "$step6_row" | rg -q 'primary docs' ||
  fail 'Delete criterion lacks a primary-documentation check'
printf '%s\n' "$step6_row" | rg -q 'reversible temp-disable A/B canary' ||
  fail 'Delete criterion lacks a reversible A/B canary'
printf '%s\n' "$step6_row" | rg -q 'temporary corpus/plugin' ||
  fail 'Delete canary is not constrained to an isolated temporary corpus/plugin'
printf '%s\n' "$step6_row" | rg -q '每個 consuming host.*PASS.*FAIL.*UNAVAILABLE' ||
  fail 'Delete canary lacks a per-consuming-host result contract'
! rg -q 'training-data' "$AUDIT_SKILL" ||
  fail 'Delete criterion still relies on unobservable training-data coverage'
! rg -q 'fix-naming|fix-frontmatter|fix-cross-reference' "$AUDIT_STYLE_CHECKS" ||
  fail 'required portable structure remains misclassified as optional style'
rg -q '^# Step 7（optional）— Style spot-check$' "$AUDIT_STYLE_CHECKS" ||
  fail 'pure style checks are no longer explicitly optional'
rg -q '五次執行中' "$AUDIT_TRIGGER_EVAL" ||
  fail 'Step 2c baseline does not report all five measurements'
rg -q '不是 current baseline' "$AUDIT_TRIGGER_EVAL" ||
  fail 'Step 2c historical evidence is still presented as a current baseline'
! rg -q 'four times' "$AUDIT_TRIGGER_EVAL" ||
  fail 'Step 2c baseline still contradicts its five-run chronology'
rg -q 'UNVERIFIED: current Claude CLI.*Collision arm.*supplied skills.*--isolate.*target.*2026-08-01 probe.*built-ins' \
  "$AUDIT_TRIGGER_EVAL" ||
  fail 'Step 2c isolate arm still hides built-in collision pressure'
rg -q 'UNVERIFIED.*Claude CLI semantics' "$AGENTS/skills/auditing-skill-folder/evals/runners.json" ||
  fail 'Step 2c runner isolation claim lacks a current-verification boundary'
rg -q 'UNVERIFIED: current Claude CLI loading semantics' "$AUDIT_TRIGGER_RUNNER" ||
  fail 'Step 2c runner header lacks a current-verification boundary'
! rg -q 'every competing skill is loaded at once|Default \(all skills loaded\)|Load ONLY' \
  "$AUDIT_TRIGGER_RUNNER" ||
  fail 'Step 2c runner header claims unverified host loading semantics'
! rg -q 'UNVERIFIED：' "$AUDIT_TRIGGER_EVAL" \
  "$AGENTS/skills/auditing-skill-folder/evals/runners.json" ||
  fail 'Step 2c uses a non-machine-readable UNVERIFIED prefix'
rg -q 'Regression coverage: `tests/vendored-detection\.sh`, 65 cases' "$AGENTS/vendored-forks.md" ||
  fail 'vendored detector regression count is stale'
! rg -q 'model invocation metadata only|four steps above' "$AUDIT_VENDORED_GATE" ||
  fail 'auditing-skill-folder carries a stale fork scope or override step count'
rg -q 'assessment verdict.*proposed override required' "$AUDIT_SKILL" ||
  fail 'auditing-skill-folder conflates the vendored assessment verdict with its execution constraint'
rg -q 'Steps 1–6.*assessment verdict.*execution constraint' "$AUDIT_VENDORED_GATE" ||
  fail 'vendored gate does not preserve the assessment and execution axes'
! rg -q 'Keep plus a reported defect|Iron Law' "$AUDIT_VENDORED_GATE" ||
  fail 'vendored gate still carries the stale Keep-only or Iron Law wording'
! rg -q '/ 150 words' "$AUDIT_VERDICT_GUIDE" ||
  fail 'auditing-skill-folder verdict guide carries the retired 150-word tier'
rg -q 'UNION of five signals' "$VENDORED_LIB" ||
  fail 'vendored detector documentation does not match its five signals'
! rg -q 'File existence alone is not a signal' "$VENDORED_LIB" ||
  fail 'vendored detector documentation hides LICENSE existence-based detection'
rg -q 'LICENSE variants.*existence' "$AUDIT_VENDORED_GATE" ||
  fail 'vendored gate does not document LICENSE existence-based detection'
! rg -q 'language always lands here|Every other language still scores' "$AUDIT_LINTER" ||
  fail 'description linter overstates unsupported-language classification'

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
expected_grilling_sha="$(fork_payload_sha grilling)"
[ -n "$expected_grilling_sha" ] ||
  fail 'grilling fork record lacks an approved payload SHA-256'
actual_grilling_sha="$(shasum -a 256 "$GRILLING" | awk '{ print $1 }')"
[ "$actual_grilling_sha" = "$expected_grilling_sha" ] ||
  fail 'grilling payload differs from the recorded fork fingerprint'

rg -q 'triggered interactively.*copy-pasteable start prompt' "$HANDOFF" ||
  fail 'handoff does not emit a start prompt for the next session'
rg -q 'not a machine-parseable contract' "$HANDOFF" ||
  fail 'handoff start prompt is not fenced off from machine consumers'
fork_recorded handoff ||
  fail 'handoff fork is not recorded inside the fork index'
expected_handoff_sha="$(fork_payload_sha handoff)"
[ -n "$expected_handoff_sha" ] ||
  fail 'handoff fork record lacks an approved payload SHA-256'
actual_handoff_sha="$(shasum -a 256 "$HANDOFF" | awk '{ print $1 }')"
[ "$actual_handoff_sha" = "$expected_handoff_sha" ] ||
  fail 'handoff payload differs from the recorded fork fingerprint'

rg -q '18 unmodified.*4 recorded forks' "$AGENTS/vendored-forks.md" ||
  fail 'Matt set summary does not distinguish all recorded forks'

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
#
# scripts/lint-descriptions.sh 於 2026-08-01 加入：Step 2 linter 補上 zh-TW 分類（TRAP 側
# 先落地，見該檔 SCOPE 段）。auditing-skill-folder 是 house skill、vendored_flag 判為 "-"，
# 同資料夾的 SKILL.md 與 scripts/lib-vendored.sh 早已在此列。變更由 tests/description-lint.sh
# 守護，並實測全 81 個 skill 僅 5 個 zh-TW description 改變分類、76 個英文 0 變動。
# Lock 定義經審核後的 Stage B2 目錄集合與完整 tree（含 mode 與 symlink）。
[ -r "$B2_SKILLS_LOCK" ] || fail 'Stage B2 skill tree lock missing'
b2_skills="$(awk -F '\t' '$0 !~ /^#/ && NF == 2 { print $1 }' "$B2_SKILLS_LOCK" | LC_ALL=C sort)"
[ "$(printf '%s\n' "$b2_skills" | grep -c .)" -eq 12 ] ||
  fail 'Stage B2 skill tree lock inventory drifted'

[ ! -e "$AGENTS/skills/video-downloader" ] &&
  [ ! -L "$AGENTS/skills/video-downloader" ] ||
  fail 'retired video-downloader directory still exists'
for fork in clean-code-dotnet dotnet-core-expert dotnet-test; do
  fork_recorded "$fork" || fail "$fork Stage B2 fork is not recorded"
done
while IFS=$'\t' read -r skill expected_tree_sha; do
  case "$skill" in \#*|"") continue ;; esac
  actual_tree_sha="$(vendored_tree_sha256 "$AGENTS/skills/$skill")"
  [ "$actual_tree_sha" = "$expected_tree_sha" ] ||
    fail "Stage B2 skill tree differs from checkpoint: $skill"
done < "$B2_SKILLS_LOCK"

# auditing-skill-folder 在此是「逐檔」列舉而非 skills/auditing-skill-folder/*，這是刻意的：
# 萬用字元會讓往後任何新檔靜默通過，而這道閘的用途正是強迫每個新檔被有意識地放行一次。
# 新增這五個檔案的理由（Step 2c 觸發評測）：evals/ 三個是評測輸入與離線 mock runner，
# scripts/eval-triggers.sh 是評測器本體，step2c-trigger-eval.md 是被 SKILL.md 指向的細節檔
# （SKILL.md 已超字數預算，細節必須外移）。計分邏輯由 tests/trigger-eval.sh 的斷言守護，
# 已在 CI；evals/cases.jsonl 內容漂移另由該測試的「skill 全部存在」健檢把關。
while IFS= read -r changed; do
  case "$changed" in
    skills/auditing-skill-folder/SKILL.md | \
    skills/auditing-skill-folder/step0-vendored-gate.md | \
    skills/auditing-skill-folder/step1-verdict-guide.md | \
    skills/auditing-skill-folder/step2c-trigger-eval.md | \
    skills/auditing-skill-folder/step7-style-checks.md | \
    skills/auditing-skill-folder/evals/cases.jsonl | \
    skills/auditing-skill-folder/evals/mock-runner.sh | \
    skills/auditing-skill-folder/evals/runners.json | \
    skills/auditing-skill-folder/references/skill-standards.md | \
    skills/auditing-skill-folder/scripts/check-vendored.sh | \
    skills/auditing-skill-folder/scripts/count-words.sh | \
    skills/auditing-skill-folder/scripts/eval-triggers.sh | \
    skills/auditing-skill-folder/scripts/lib-vendored.sh | \
    skills/auditing-skill-folder/scripts/lint-descriptions.sh | \
    skills/context7-mcp/* | \
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
      printf '%s\n' "$b2_skills" | grep -Fxq "$changed_skill" ||
        fail "non-allowlisted shared skill changed: $changed"
      ;;
  esac
done < <(
  {
    git -C "$AGENTS" diff --name-only "$WORKFLOW_BASE" -- skills
    git -C "$AGENTS" ls-files --others --exclude-standard -- skills
  } | LC_ALL=C sort -u
)

[ -f "$WRAPPER_PARITY_EVIDENCE" ] ||
  fail "wrapper parity evidence missing: $WRAPPER_PARITY_EVIDENCE"
for retired in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
  rg -q "^\\| \`$retired\` .*\\| PASS" "$WRAPPER_PARITY_EVIDENCE" ||
    fail "wrapper parity missing: $retired"
done

git -C "$AGENTS" diff --quiet "$WORKFLOW_BASE" -- \
  bin/phase4-canary-harness tests/phase4-canary-harness.sh ||
  fail 'Phase 4 historical artifacts changed'

printf 'PASS: Matt thin workflow contract\n'

#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORKFLOW_BASE="${WORKFLOW_BASE:-d2e78888787e1bd0534cff363442e336e5c609d9}"
B2_SKILLS_LOCK="$AGENTS/stage-b2-skills.lock"
WRAPPER_PARITY_EVIDENCE="$AGENTS/proposals/2026-07-27-mattpocock-skills-workflow/49-three-host-global-config-ownership-split-candidate-evidence.md"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"
DELEGATION_REF="$AGENTS/skills/dev-workflow/references/delegation.md"
HOST_ADAPTERS_REF="$AGENTS/skills/dev-workflow/references/host-adapters.md"
ROUTING_CONTINUATIONS_REF="$AGENTS/skills/dev-workflow/references/routing-continuations.md"
AUTHORIZATION_MATRIX_REF="$AGENTS/skills/dev-workflow/references/authorization-matrix.md"
GRILLING="$AGENTS/skills/grilling/SKILL.md"
HANDOFF="$AGENTS/skills/handoff/SKILL.md"
DIAGNOSING="$AGENTS/skills/diagnosing-bugs/SKILL.md"
DIAGNOSING_DIR="$AGENTS/skills/diagnosing-bugs"
WRITING_SKILLS="$AGENTS/skills/writing-for-agents/SKILL.md"
WRITING_SKILLS_DIR="$AGENTS/skills/writing-for-agents"
WRITING_GLOSSARY="$WRITING_SKILLS_DIR/GLOSSARY.md"
WRITING_MECHANICS="$WRITING_SKILLS_DIR/SKILL-MECHANICS.md"
WRITING_SKILLS_POLICY="$AGENTS/skills/writing-for-agents/agents/openai.yaml"
AUDIT_SKILL="$AGENTS/skills/auditing-skill-folder/SKILL.md"
AUDIT_VENDORED_GATE="$AGENTS/skills/auditing-skill-folder/step0-vendored-gate.md"
AUDIT_VERDICT_GUIDE="$AGENTS/skills/auditing-skill-folder/step1-verdict-guide.md"
AUDIT_TRIGGER_EVAL="$AGENTS/skills/auditing-skill-folder/step2c-trigger-eval.md"
AUDIT_TRIGGER_RUNNER="$AGENTS/skills/auditing-skill-folder/scripts/eval-triggers.sh"
AUDIT_STYLE_CHECKS="$AGENTS/skills/auditing-skill-folder/step7-style-checks.md"
AUDIT_LINTER="$AGENTS/skills/auditing-skill-folder/scripts/lint-descriptions.sh"
VENDORED_LIB="$AGENTS/skills/auditing-skill-folder/scripts/lib-vendored.sh"
TEST_GAP="$AGENTS/skills/test-gap-analysis/SKILL.md"
IMPROVE_ARCH="$AGENTS/skills/improve-codebase-architecture/SKILL.md"

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
  'S6 CLOSEOUT'; do
  rg -q "$heading" "$KERNEL" || fail "thin kernel heading missing: $heading"
done

rg -q '^description: .*開發任務必讀.*三 host.*S0.*S2.*S4.*S6' "$KERNEL" ||
  fail 'dev-workflow description lost its all-development-task trigger'
grep -Fqx '[R-1 DEPRECATED→INT-1 2026-07] [R-2 DEPRECATED→INT-2 2026-07]' "$KERNEL" ||
  fail 'retired workflow ID shells must preserve DEPRECATED targets and dates'
[ "$(grep -Fc 'FP:DEVWF-2026Q3' "$KERNEL")" -eq 1 ] ||
  fail 'dev-workflow fingerprint must appear exactly once'

kernel_bytes=$(wc -c < "$KERNEL" | tr -d ' ')
[ "$kernel_bytes" -le 12700 ] ||
  fail "dev-workflow kernel exceeds 12700 bytes: $kernel_bytes"
for ref in "$DELEGATION_REF" "$HOST_ADAPTERS_REF" "$ROUTING_CONTINUATIONS_REF" "$AUTHORIZATION_MATRIX_REF"; do
  [ -r "$ref" ] || fail "conditional workflow reference missing: $ref"
done
rg -q '^# Authorization matrix' "$AUTHORIZATION_MATRIX_REF" ||
  fail 'authorization matrix reference lacks its canonical heading'
rg -q '^# Host adapters' "$HOST_ADAPTERS_REF" ||
  fail 'host adapters reference lacks its canonical heading'
rg -q 'skill audit／VND.*continuations' "$KERNEL" ||
  fail 'skill audit must load the VND routing continuation'
! rg -q '^### UI/Web design continuation' "$KERNEL" ||
  fail 'kernel still duplicates ui-ux-pro-max continuation'

[ -r "$TEST_GAP" ] || fail 'test-gap-analysis skill is missing'
rg -q 'explicit mutation authorization' "$TEST_GAP" ||
  fail 'test-gap-analysis can mutate production code without explicit authorization'
rg -q 'isolated temporary (copy|worktree)' "$TEST_GAP" ||
  fail 'test-gap-analysis does not isolate empirical mutations'
rg -q 'full affected test (project|suite)' "$TEST_GAP" ||
  fail 'test-gap-analysis can certify a survivor from only narrow tests'
rg -q 'Record the original production-file hashes and package manifest' "$TEST_GAP" ||
  fail 'test-gap-analysis does not fingerprint empirical-mutation inputs'
rg -qi 'apply the inverse edit' "$TEST_GAP" ||
  fail 'test-gap-analysis does not require an inverse edit'
rg -Fq 'After green, red, error, or timeout, apply the inverse edit' "$TEST_GAP" ||
  fail 'test-gap-analysis cleanup is not mandatory after every mutant outcome'
rg -q 'hashes to match the baseline before the next mutation' "$TEST_GAP" ||
  fail 'test-gap-analysis does not prove per-mutant cleanup'
rg -q 'package manifest has no unexpected diff' "$TEST_GAP" ||
  fail 'test-gap-analysis does not prove final package cleanup'
rg -q 'finite runner/host timeout' "$TEST_GAP" ||
  fail 'test-gap-analysis empirical mutations have no bounded timeout'
rg -q 'terminate the spawned test process tree' "$TEST_GAP" ||
  fail 'test-gap-analysis timeouts do not terminate the mutant test process tree'
rg -Fq 'Mutation score = (Killed + TimedOut) / (Killed + TimedOut + Survived + No coverage)' "$TEST_GAP" ||
  fail 'test-gap-analysis empirical score has no canonical denominator'
rg -Fq 'duration × 2 + 30 seconds' "$TEST_GAP" ||
  fail 'test-gap-analysis mutant timeouts are not calibrated from an unmutated run'
rg -Fq 'separately calibrated full-suite timeout' "$TEST_GAP" ||
  fail 'test-gap-analysis incorrectly reuses the narrow-test timeout for the full suite'
rg -Fq 'If that denominator is zero, report `Mutation score: N/A`' "$TEST_GAP" ||
  fail 'test-gap-analysis does not define the zero-mutant score'
rg -q 'Static mode reports unverified candidate counts without percentages or a mutation score' "$TEST_GAP" ||
  fail 'test-gap-analysis static report can still look empirical'
! rg -q 'fix only obvious wiring problems' "$TEST_GAP" ||
  fail 'test-gap-analysis still authorizes out-of-scope wiring fixes'
! rg -q 'Medium／High behavior change.*test-gap-analysis' "$ROUTING_CONTINUATIONS_REF" ||
  fail 'workflow still auto-routes ordinary Medium/High changes to mutation analysis'

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

rg -q '所有使用者可見的回覆.*generated HTML report prose.*預設使用繁體中文.*zh-TW' "$IMPROVE_ARCH" ||
  fail 'improve-codebase-architecture lost its default zh-TW output contract'
rg -q '使用者明示其他語言時依其要求' "$IMPROVE_ARCH" ||
  fail 'improve-codebase-architecture lost its explicit language override'
rg -q 'technical terms.*architecture vocabulary.*code identifiers.*file paths.*domain terms.*保留 English 或原文' "$IMPROVE_ARCH" ||
  fail 'improve-codebase-architecture lost its English technical-term contract'

! rg -q '^disable-model-invocation:[[:space:]]*true$' "$WRITING_SKILLS" ||
  fail 'writing-for-agents is not model-invoked'
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
rg -q '^description: Writing documents for agents\..*Agent Skill.*AGENTS\.md.*CLAUDE\.md.*pointed-at agent doc' "$WRITING_SKILLS" ||
  fail 'writing-for-agents lacks its generalized document trigger branches'
rg -q 'Existing-skill invocation edits stay here.*host creator owns new-skill scaffolding.*folder auditor owns directory audits' "$WRITING_SKILLS" ||
  fail 'writing-for-agents lost the local skill-authoring ownership boundary'
rg -q '^\*\*REQUIRED PRECONDITION:\*\*.*preserved RED trigger canary.*Step 2c RED satisfies this gate' "$WRITING_SKILLS" ||
  fail 'writing-for-agents does not accept a caller-provided Step 2c RED'
rg -q '^\*\*REQUIRED SUB-SKILL:\*\* For a misbehavior rewrite with no caller-supplied RED, invoke `diagnosing-bugs` first' "$WRITING_SKILLS" ||
  fail 'writing-for-agents does not scope the trigger-diagnosis dependency to a misbehavior rewrite'
rg -q 'full.*record a verdict for every applicable section' "$WRITING_SKILLS" ||
  fail 'writing-for-agents lacks the full-audit completion criterion'
rg -q 'scoped edit.*only the named branch' "$WRITING_SKILLS" ||
  fail 'writing-for-agents expands scoped edits into full audits'
rg -q 'trigger RED canary.*GREEN' "$WRITING_SKILLS" ||
  fail 'writing-for-agents does not preserve RED to GREEN evidence'
writing_words=$(LC_ALL=C wc -w < "$WRITING_SKILLS" | tr -d ' ')
[ "$writing_words" -le 500 ] ||
  fail "writing-for-agents exceeds its 500-word budget: $writing_words"
[ -r "$WRITING_GLOSSARY" ] ||
  fail 'writing-for-agents glossary is missing or unreadable'
[ -r "$WRITING_MECHANICS" ] ||
  fail 'writing-for-agents skill-mechanics branch is missing or unreadable'
rg -Fq '[Granularity](GLOSSARY.md#granularity)' "$WRITING_MECHANICS" ||
  fail 'writing-for-agents skill mechanics has a dead granularity pointer'
rg -q 'Split by sequence only when an observed rush survives a sharper completion criterion' "$WRITING_MECHANICS" ||
  fail 'writing-for-agents lost its evidence-gated sequence split'
rg -q 'Criteria that sweep a set are exhaustive' "$WRITING_SKILLS" ||
  fail 'writing-for-agents lost its exhaustive set criterion'
rg -q 'AGENTS\.md.*CLAUDE\.md.*pointed-at files use the same object' "$WRITING_GLOSSARY" ||
  fail 'writing-for-agents glossary did not generalize context pointers beyond skills'
rg -Fq 'Outside Invocation, every term applies to any agent-facing document' "$WRITING_GLOSSARY" ||
  fail 'writing-for-agents glossary leaves non-invocation terms skill-only'
rg -Fq '](GLOSSARY.md)' "$WRITING_SKILLS" ||
  fail 'writing-for-agents no longer points to its glossary'
rg -Fq '](SKILL-MECHANICS.md)' "$WRITING_SKILLS" ||
  fail 'writing-for-agents no longer discloses skill-only mechanics'
rg -q 'environment.*source of truth|environment.*canonical source' "$WRITING_SKILLS" ||
  fail 'writing-for-agents does not treat the live environment as a source of truth'
rg -q 'pinned provenance|lockfile.*precedence|lock.*provenance' "$WRITING_SKILLS" ||
  fail 'writing-for-agents lets environment lookup overwrite pinned provenance'
rg -Fq 'Look for repeated phrasing a **Leading Word** can collapse; keep it only when a canary shows improved invocation or execution.' "$WRITING_SKILLS" ||
  fail 'writing-for-agents no longer searches for evidence-gated leading words'
rg -Fq "Use each heading's exact term for that concept; synonyms dilute its **leading word**." "$WRITING_GLOSSARY" ||
  fail 'writing-for-agents no longer preserves canonical glossary terminology'
! rg -q '^_Avoid_:' "$WRITING_GLOSSARY" ||
  fail 'writing-for-agents glossary still carries negation sediment'
! rg -q '_comprehensive_, _thorough_' "$WRITING_GLOSSARY" ||
  fail 'writing-for-agents still presents thorough as both weak and effective'
rg -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*true$' \
  "$WRITING_SKILLS_POLICY" ||
  fail 'Codex policy blocks writing-for-agents implicit invocation'
fork_recorded writing-for-agents ||
  fail 'writing-for-agents fork is not recorded inside the fork index'
expected_writing_tree_sha="$(
  sed -n '/^## writing-for-agents$/,/^---$/p' "$AGENTS/vendored-forks.md" |
    sed -n 's/.*tree SHA-256: `\([a-f0-9]\{64\}\)`.*/\1/p'
)"
[ -n "$expected_writing_tree_sha" ] ||
  fail 'writing-for-agents fork record lacks an approved tree SHA-256'
indexed_writing_tree_sha="$(
  sed -n '/^| `writing-for-agents` |/s/.*tree SHA-256 `\([a-f0-9]\{64\}\)`.*/\1/p' \
    "$AGENTS/vendored-forks.md"
)"
[ "$indexed_writing_tree_sha" = "$expected_writing_tree_sha" ] ||
  fail 'writing-for-agents fork index and detailed fingerprint disagree'
actual_writing_tree_sha="$(vendored_tree_sha256 "$WRITING_SKILLS_DIR")"
[ "$actual_writing_tree_sha" = "$expected_writing_tree_sha" ] ||
  fail 'writing-for-agents tree differs from the recorded fork fingerprint'

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
rg -q 'Regression coverage: `tests/vendored-detection\.sh`, 58 cases' "$AGENTS/vendored-forks.md" ||
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
sed -n '/^## Claude$/,/^## Codex$/p' "$HOST_ADAPTERS_REF" |
  rg -q 'user-only skill command = `/<skill-name>`' ||
  fail 'Claude user-only invocation syntax missing'
sed -n '/^## Codex$/,/^## Copilot$/p' "$HOST_ADAPTERS_REF" |
  rg -q 'user-only skill command = `\$<skill-name>`' ||
  fail 'Codex user-only invocation syntax missing'
sed -n '/^## Copilot$/,$p' "$HOST_ADAPTERS_REF" |
  rg -q 'user-only skill command = `/<skill-name>`' ||
  fail 'Copilot user-only invocation syntax missing'

rg -q '2.?3.*options.*recommended.*first' "$GRILLING" ||
  fail 'grilling does not offer compact options with the recommendation first'
rg -q 'Prefix every question with a progress header.*Question N of ~M.*running estimate.*Re-estimate M' "$GRILLING" ||
  fail 'grilling does not show a re-estimated question progress header'
rg -q 'Map decisions as a design tree.*frontier.*prerequisites.*settled' "$GRILLING" ||
  fail 'grilling does not define the design tree frontier'
rg -q 'By default, work interactively one frontier decision at a time.*Ask one eligible question.*wait for feedback.*wait for explicit confirmation before acting' "$GRILLING" ||
  fail 'grilling does not preserve one-question HITL on the current frontier'
rg -q 'depends on another unresolved decision.*later turn' "$GRILLING" ||
  fail 'grilling does not defer dependent questions'
rg -q 'Keep dependent decisions.*off the frontier.*prerequisites settle' "$GRILLING" ||
  fail 'grilling can silently lose deferred dependency branches'
rg -q 'frontier is empty.*every branch.*nothing left silently assumed' "$GRILLING" ||
  fail 'grilling lacks its design-tree completion criterion'
rg -q 'explicitly authorizes.*answer every decision.*ask only when blocked' "$GRILLING" ||
  fail 'grilling lacks opt-in delegated decision-making'
rg -q 'In delegated-decision mode.*Ask only when no defensible recommendation remains.*material fact or user-only constraint.*user-only preference or authority.*low-confidence' "$GRILLING" ||
  fail 'grilling lacks evidence, preference, authority, and confidence blockers'
rg -q 'Risk alone does not make a decision unanswerable.*acting requires authorization' "$GRILLING" ||
  fail 'grilling conflates decision-making risk with action authorization'
rg -q 'calling workflow requires live HITL feedback.*keep the default interactive mode.*unless the user explicitly overrides that requirement' "$GRILLING" ||
  fail 'grilling does not preserve caller-required live HITL feedback'
rg -q 'Before acting in delegated-decision mode.*summarize every decision.*Delegated decision-making is not implementation authorization' "$GRILLING" ||
  fail 'grilling lacks a decision summary and separate action gate'
rg -q 'Proceed only when the action is already authorized and permitted by higher-priority rules.*Ask for authorization only when authorization is the sole blocker.*otherwise report the binding constraint' "$GRILLING" ||
  fail 'grilling lacks terminal branches for authorization and binding constraints'
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

# code-review 是 recorded fork（2026-08-03，[S5-4] 移除 sub-agent 輸出上限）。fork_recorded 只是
# 布林；沒有下面這段指紋斷言，一次 Matt set 全量重拉會把 `Under 400 words` 悄悄還原且三支測試全綠。
# 用 tree 而非 payload：這支 skill 是 SKILL.md + agents/openai.yaml 兩檔，payload 只雜湊前者。
CODE_REVIEW_DIR="$AGENTS/skills/code-review"
fork_recorded code-review ||
  fail 'code-review fork is not recorded inside the fork index'
expected_code_review_tree_sha="$(
  sed -n '/^## code-review$/,/^---$/p' "$AGENTS/vendored-forks.md" |
    sed -n 's/.*tree SHA-256: `\([a-f0-9]\{64\}\)`.*/\1/p'
)"
[ -n "$expected_code_review_tree_sha" ] ||
  fail 'code-review fork record lacks an approved tree SHA-256'
indexed_code_review_tree_sha="$(
  sed -n '/^| `code-review` |/s/.*tree SHA-256 `\([a-f0-9]\{64\}\)`.*/\1/p' \
    "$AGENTS/vendored-forks.md"
)"
[ "$indexed_code_review_tree_sha" = "$expected_code_review_tree_sha" ] ||
  fail 'code-review fork index and detailed fingerprint disagree'
actual_code_review_tree_sha="$(vendored_tree_sha256 "$CODE_REVIEW_DIR")"
[ "$actual_code_review_tree_sha" = "$expected_code_review_tree_sha" ] ||
  fail 'code-review tree differs from the recorded fork fingerprint'
# 這兩條刻意用 POSIX grep 而非 rg：本檔 73 條 rg 斷言都是 `|| fail`，缺 rg 會響亮失敗；反向斷言
# 寫成 `rg -q … && fail` 時缺 rg 反而靜默通過（CI 曾因此假綠）。負向檢查一律用必然存在的 grep。
rg -q 'Read the entire.*canonical reviewer-template' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review does not load the canonical reviewer contract'
rg -q 'Paste the required text into each actual reviewer input' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review dispatch can substitute a pointer for the full contract'
rg -q 'Both axes.*all-findings/no-word-or-count-cap/caller-side-filtering' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review: both axes must receive the canonical output contract ([S5-4])'
rg -q 'Standards.*complete canonical marked reviewer prompt block.*all five house items.*performance/correctness' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review: Standards dispatch omits required review coverage'
rg -q 'Spec.*common material.*missing or partial requirements.*scope creep.*incorrectly' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review: Spec dispatch omits requirements or common contract'
rg -q 'Do not merge or rerank across axes' "$CODE_REVIEW_DIR/SKILL.md" ||
  fail 'code-review aggregate merges independent axes'
grep -RqF 'Under 400 words' "$CODE_REVIEW_DIR" &&
  fail 'code-review sub-agent brief still carries an output cap ([S5-4])'

rg -q 'implement.*S4.*S5.*S6|S4.*S5.*S6.*implement' "$KERNEL" ||
  fail 'implement route does not return to S4-S6'
rg -q 'implement.*(isolated worktree|branch)' "$KERNEL" ||
  fail 'implement route lacks isolated branch entry'
rg -q 'implement.*(current|main).*(MUST NOT|不得)|MUST NOT.*implement.*(current|main)' "$KERNEL" ||
  fail 'implement route does not reject current/main commits'
rg -q 'GREEN.*micro-refactor|micro-refactor.*GREEN' "$KERNEL" ||
  fail 'post-GREEN micro-refactor rule missing'

# Host adapter 與 kernel 的加嚴契約。
#
# 為什麼釘在這裡（2026-08-04）：dotclaude PR #7 在 CLAUDE.md 加的 delegation 條文與
# [INT-4] 的無條件約束正面對撞，而 tier0 裁決鏈裁不了 kernel 與 host delta 這一對——
# 該檔實體在 skills/ 下（讀成程序步驟則 host delta 勝），功能是三 host 共用治理層
# （讀成協作層則 kernel 勝），兩種讀法都成立。
#
# 修法不是在鏈上插一格：這組關係不是線性位階。host 可以加一條 kernel 沒有的約束
# （PR #7 那樣是正當的），但不可放鬆 kernel 的 MUST——鏈上任一個位置都只能編碼其中
# 一半。所以契約寫在 seam 上，形狀比照 tier0 的「repo 層對 tier0 只可加嚴」。
ADAPTER_SECTION=$(cat "$HOST_ADAPTERS_REF") || fail 'cannot read host adapters reference'
printf '%s\n' "$ADAPTER_SECTION" | rg -q 'Host adapter 對本 kernel 只可加嚴' ||
  fail 'host adapters reference does not state the add-only contract'
printf '%s\n' "$ADAPTER_SECTION" | rg -q 'MUST NOT 放鬆.*(MUST|無條件約束)' ||
  fail 'add-only contract does not forbid loosening kernel MUSTs'
printf '%s\n' "$ADAPTER_SECTION" | rg -q '放鬆.*user 當下明示' ||
  fail 'add-only contract does not route loosening back to explicit user instruction'

# init-project-docs 的兩個掛載點。
#
# 為什麼釘（2026-08-04）：這支 skill 在 kernel、四個 references 與三個 host 入口檔
# 全都 0 次出現，走 workflow 進來的任務永遠到不了它。它的姊妹
# acquire-codebase-knowledge 在 S0 表上（「陌生 repo」列），而 S6 有一句
# 「架構變更同步 current architecture docs」講了 outcome 卻沒指名 skill——缺口正好
# 落在兩者之間，同一行的 BUGFIX 半句反而有指名 bug-fix-settlement。
sed -n '/^| Need | Route |$/,/^$/p' "$KERNEL" | rg -q 'init-project-docs' ||
  fail 'S0 routing table does not route init-project-docs'
rg -q '架構變更.*`init-project-docs`.*architecture docs' "$KERNEL" ||
  fail 'S6 architecture-docs obligation does not name init-project-docs'

# S0 路由的反向缺口。
#
# 既有斷言只驗單向（表上每支 skill 的檔案必須存在），所以「method skill 沒被 route」
# 是機械不可見的——上面那個缺口就是這樣活下來的。
#
# 判準不能是「所有 skill 都要被 route」：stack skill 本來就靠自己的 description 觸發，
# kernel 的 S0 只 route method skill，71 支裡有 36 支合法地不在 route 路徑上。所以改成
# 宣告式——實際未被 route 的集合必須等於下方宣告的集合。新增一支未 route 的 skill 會紅，
# 把宣告過的 skill 改成有 route 也會紅，兩個方向都逼出一次明確決定。
#
# 「被 route」取全檔提及而非只看 S0 表：Routing continuations 那段的 prose 也是合法路由
# 路徑（implement／handoff／to-spec 都只在那裡出現）。
UNROUTED_BY_DESIGN=$(cat <<'LIST'
agent-browser
apple-calendar
aspnet-api-architect
auth-implementation-patterns
c-cpp-best-practices
clean-code-dotnet
containerization
css-ui-best-practices
dapper-best-practices
dev-workflow
dotnet-core-best-practices
dotnet-framework-best-practices
dotnet-logging-best-practices
dotnet-testing-best-practices
dotnet-winforms-best-practices
ef-core-best-practices
ef6-best-practices
grill-me
jest-best-practices
mp-zoom-out
mysql-best-practices
next-best-practices
nodejs-best-practices
nuxt
playwright-best-practices
postgresql-best-practices
postgresql-optimization
prototype
react-best-practices
react-router-framework-mode
speak-human-tw
tailwind-v4-shadcn
teach
testing-library-react-best-practices
test-gap-analysis
typescript-best-practices
vite
vitest
vue-best-practices
web-design-reviewer
LIST
)
# 五類：stack skill、kernel 自身、由 upstream／使用者明示進入的 Matt skill、由
# ui-ux-pro-max own continuation 的 web-design-reviewer，以及靠精準 description model-invoke
# 的 specialist（test-gap-analysis；speak-human-tw 同類，但它的 description 精準度未經
# skills/auditing-skill-folder/evals/cases.jsonl 量測，分類是判斷不是實證）。
# 用純 bash glob 迭代，對齊 tests/vendored-detection.sh:306 的既有寫法：
# `ls | xargs basename` 配 `for s in $(...)` 會經過 word splitting，目錄名含空白或
# 換行時拆壞，且 glob 未命中時會把字面 pattern 當成一個項目。`[ -f "$sd/SKILL.md" ]`
# 同時擋掉未命中與缺 SKILL.md 的空目錄（後者曾讓 agents-sync 三個入口全 die）。
actual_unrouted=$(
  for sd in "$AGENTS"/skills/*/; do
    [ -f "$sd/SKILL.md" ] || continue
    # gitignored skill 不受本守衛管轄：本守衛管的是「進版控的共用 skill 有沒有被 route」。
    # 磁碟 glob 對 gitignore 無感，而 CI 跑 clean clone 根本看不到這些目錄——不跳過的話
    # 本機恆紅、CI 恆綠，且 UNROUTED_BY_DESIGN 也救不了（stale_declaration 分支要求
    # 宣告的項目必須存在於磁碟，CI 那側不存在即 FAIL，兩邊無法同時綠）。
    # 用 if 不用 `&&`：set -e 下 `cmd && continue` 在 cmd 非 0 時會讓整個 subshell 退出。
    if git -C "$AGENTS" check-ignore -q "$sd"; then continue; fi
    s=${sd%/}; s=${s##*/}
    grep -Fq "\`$s\`" "$KERNEL" "$ROUTING_CONTINUATIONS_REF" || printf '%s\n' "$s"
  done | sort
)
declared_unrouted=$(printf '%s\n' "$UNROUTED_BY_DESIGN" | rg -v '^\s*$' | sort)
newly_unrouted=$(comm -23 <(printf '%s\n' "$actual_unrouted") <(printf '%s\n' "$declared_unrouted"))
[ -z "$newly_unrouted" ] ||
  fail "skill 未被 route 且未宣告例外（route 進 S0，或加進 UNROUTED_BY_DESIGN）: $(printf '%s' "$newly_unrouted" | tr '\n' ' ')"
stale_declaration=$(comm -13 <(printf '%s\n' "$actual_unrouted") <(printf '%s\n' "$declared_unrouted"))
[ -z "$stale_declaration" ] ||
  fail "UNROUTED_BY_DESIGN 列出的 skill 其實已被 route 或已不存在，請移除: $(printf '%s' "$stale_declaration" | tr '\n' ' ')"

if rg -n 'superpowers:' "$AGENTS/skills" >/dev/null; then
  fail 'active shared skills still reference Superpowers'
fi
# 2026-07-30：掃描目標從 $AGENTS/core/routing.md 改為 ${KERNEL}（dev-workflow SKILL.md）。
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

fork_count=0
expected_upstream_tree_count=$(grep -c '^upstream_tree_sha256=' "$AGENTS/mattpocock-skills.lock")
upstream_tree_count=0
# Full-tree hashing is deliberate: provenance checks pay this small cost so any
# file, mode, or symlink drift in an upstream-identical skill fails closed.
while IFS='=' read -r key skill; do
  [ "$key" = skill ] || continue
  if fork_recorded "$skill"; then
    fork_count=$((fork_count + 1))
    indexed_fork_tree_sha="$(
      sed -n "/^| \`$skill\` |/s/.*tree SHA-256 \`\([a-f0-9]\{64\}\)\`.*/\1/p" \
        "$AGENTS/vendored-forks.md"
    )"
    if [ -n "$indexed_fork_tree_sha" ]; then
      [ "$(vendored_tree_sha256 "$AGENTS/skills/$skill")" = "$indexed_fork_tree_sha" ] ||
        fail "Matt fork tree differs from its recorded fingerprint: $skill"
    else
      indexed_fork_payload_sha="$(fork_payload_sha "$skill")"
      [ -n "$indexed_fork_payload_sha" ] ||
        fail "Matt fork lacks a recorded tree or payload fingerprint: $skill"
      [ "$(shasum -a 256 "$AGENTS/skills/$skill/SKILL.md" | awk '{ print $1 }')" = "$indexed_fork_payload_sha" ] ||
        fail "Matt fork payload differs from its recorded fingerprint: $skill"
    fi
    continue
  fi
  expected_upstream_tree="$(
    sed -n "s/^upstream_tree_sha256=${skill}:\([a-f0-9]\{64\}\)$/\1/p" \
      "$AGENTS/mattpocock-skills.lock"
  )"
  [ -n "$expected_upstream_tree" ] ||
    fail "unrecorded Matt upstream skill lacks a pinned tree: $skill"
  [ "$(printf '%s\n' "$expected_upstream_tree" | grep -c .)" -eq 1 ] ||
    fail "Matt upstream skill has duplicate pinned trees: $skill"
  actual_upstream_tree="$(vendored_tree_sha256 "$AGENTS/skills/$skill")"
  [ "$actual_upstream_tree" = "$expected_upstream_tree" ] ||
    fail "Matt upstream skill differs from its pinned tree: $skill"
  upstream_tree_count=$((upstream_tree_count + 1))
done < "$AGENTS/mattpocock-skills.lock"
[ "$upstream_tree_count" -eq "$expected_upstream_tree_count" ] ||
  fail "Matt upstream-identical tree count drifted: $upstream_tree_count"
rg -q "${upstream_tree_count} unmodified.*${fork_count} recorded forks" "$AGENTS/vendored-forks.md" ||
  fail 'Matt set summary does not match the verified upstream/fork counts'

# 最後兩個 pattern 是 2026-07-30 rules/ 退役加入的：那兩處只移除指向 ~/.agents/rules/
# 的死路徑，改成不帶路徑的「家規」措辭（規則內容本來就內聯在同一段）。兩者都是 house
# skill，不在 mattpocock-skills.lock 的 22 個內，所以上面第 106-112 行的 vendored gate
# 不適用。註解不能插在 case pattern 的 `\` 續行之間——那是語法錯誤。
#
# scripts/lint-descriptions.sh 於 2026-08-01 加入：Step 2 linter 補上 zh-TW 分類（TRAP 側
# 先落地，見該檔 SCOPE 段）。auditing-skill-folder 是 house skill、vendored_flag 判為 "-"，
# 同資料夾的 SKILL.md 與 scripts/lib-vendored.sh 早已在此列。變更由 tests/description-lint.sh
# 守護；2026-08-02 corpus 為 77 個 active skill（退役前為 81）。
# Lock 定義經審核後的 Stage B2 目錄集合與完整 tree（含 mode 與 symlink）。
[ -r "$B2_SKILLS_LOCK" ] || fail 'Stage B2 skill tree lock missing'
b2_skills="$(awk -F '\t' '$0 !~ /^#/ && NF == 2 { print $1 }' "$B2_SKILLS_LOCK" | LC_ALL=C sort)"
[ "$(printf '%s\n' "$b2_skills" | grep -c .)" -eq 4 ] ||
  fail 'Stage B2 skill tree lock inventory drifted'

[ ! -e "$AGENTS/skills/video-downloader" ] &&
  [ ! -L "$AGENTS/skills/video-downloader" ] ||
  fail 'retired video-downloader directory still exists'
for retired in clarify csharp-developer dotnet-core-expert dotnet-find-bugs dotnet-test make-skill-template native-feel-cross-platform-desktop nuget-manager pinia vue-debug-guides vueuse-functions; do
  [ ! -e "$AGENTS/skills/$retired" ] && [ ! -L "$AGENTS/skills/$retired" ] ||
    fail "retired skill remains active: $retired"
  [ -f "$AGENTS/attic/$retired/SKILL.md" ] ||
    fail "retired skill is not recoverable from attic: $retired"
done
[ ! -e "$AGENTS/skills/security-review" ] && [ ! -L "$AGENTS/skills/security-review" ] ||
  fail 'legacy security-review namespace remains active'
[ -f "$AGENTS/skills/shared-security-review/SKILL.md" ] ||
  fail 'shared-security-review namespace is missing'
for fork in clean-code-dotnet; do
  fork_recorded "$fork" || fail "$fork Stage B2 fork is not recorded"
done
clean_code_skill="$AGENTS/skills/clean-code-dotnet/SKILL.md"
clean_code_words="$(wc -w < "$clean_code_skill" | tr -d ' ')"
[ "$clean_code_words" -le 500 ] ||
  fail "clean-code-dotnet thin fork exceeds 500 words: $clean_code_words"
rg -q '^description:.*readability.*naming.*responsibilit.*SOLID' "$clean_code_skill" ||
  fail 'clean-code-dotnet description lost its narrow Clean Code triggers'
rg -q 'references/solid-principles\.md' "$clean_code_skill" ||
  fail 'clean-code-dotnet lost the disclosed SOLID reference'
! rg -q '^## SOLID Principles|writing new code|code review feedback' "$clean_code_skill" ||
  fail 'clean-code-dotnet still carries duplicated SOLID content or generic triggers'
[ ! -e "$AGENTS/skills/clean-code-dotnet/references/async-patterns.md" ] ||
  fail 'clean-code-dotnet still owns duplicated async guidance'
[ ! -e "$AGENTS/skills/clean-code-dotnet/references/editorconfig-template.md" ] ||
  fail 'clean-code-dotnet still owns repo-specific mechanical style config'
clean_code_solid="$AGENTS/skills/clean-code-dotnet/references/solid-principles.md"
rg -q '^# SOLID Principles - Illustrative Snippets$' "$clean_code_solid" ||
  fail 'clean-code-dotnet SOLID reference overstates snippet completeness'
! rg -q 'ABP module|public List<EmployeeData> Show' "$clean_code_solid" ||
  fail 'clean-code-dotnet SOLID reference contains framework bleed or invalid render returns'
fork_recorded web-design-reviewer ||
  fail 'web-design-reviewer thin fork is not recorded'
fork_recorded playwright-best-practices ||
  fail 'playwright-best-practices curated fork is not recorded'
fork_recorded ui-ux-pro-max ||
  fail 'ui-ux-pro-max portability fork is not recorded'
uiux_skill="$AGENTS/skills/ui-ux-pro-max/SKILL.md"
[ -f "$uiux_skill" ] || fail 'ui-ux-pro-max shared entrypoint is missing'
uiux_words="$(wc -w < "$uiux_skill" | tr -d ' ')"
[ "$uiux_words" -le 500 ] ||
  fail "ui-ux-pro-max entrypoint exceeds 500 words: $uiux_words"
! rg -q 'CLAUDE_PLUGIN_ROOT' "$AGENTS/skills/ui-ux-pro-max" ||
  fail 'ui-ux-pro-max still contains a Claude-only runtime path'
rg -Fq '$HOME/.agents/skills/ui-ux-pro-max/scripts/search.py' "$uiux_skill" ||
  fail 'ui-ux-pro-max shared runtime path is missing'
rg -q 'stack skills own implementation.*web-design-reviewer owns rendered-page QA' "$uiux_skill" ||
  fail 'ui-ux-pro-max ownership boundary drifted'
! rg -q 'reviewing UI|implementing navigation|creating/refactoring UI components' "$uiux_skill" ||
  fail 'ui-ux-pro-max broad implementation/review triggers returned'
rg -q '新 UI.*ui-ux-pro-max' "$AGENTS/skills/dev-workflow/SKILL.md" ||
  fail 'dev-workflow lost UI design routing'
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
#
# 2026-08-01 放行五個自有檔，全部來自同一輪稽核的實證缺陷修復（非重構、非體積調整）：
#   bug-fix-settlement/SKILL.md      三處硬編碼 ~/.claude 路徑，但這是三 host 共用 skill；
#                                    改為 host-neutral 指標，避免綁定任一 host 的目錄配置。
#   deps-check/scripts/deps-check.sh 四條「無法分析」路徑原本 exit 0（fail-open），配上判讀表
#                                    的「0 依賴 → 安全改動」會把「找不到檔案」讀成「可以放心改」。
#                                    改為 exit 2；「副檔名不適用」刻意維持 exit 0。
#   deps-check/SKILL.md              判讀表補 exit-code 前置條件，hook 段補 exit code 語意。
#   postgresql-optimization/SKILL.md :45 的 ATTACH PARTITION CONCURRENTLY 不是合法語法（PG 14–18
#                                    的 ATTACH 都不接受該選項），改為 DETACH；同檔 references/
#                                    partitioning.md 本來就寫對，屬單點筆誤。已加 version-tripwire 絆線。
#   shared-security-review/SKILL.md  description 補 → security-audit 反向 disambiguator，關掉
#                                    Step 2b collision；security-audit 是 VND 不能改，故改自有這側。
# 2026-08-02 namespace migration 將原 security-review 的八個 payload paths 原子改名，避開
# Claude/Copilot native identity collision；逐檔 allowlist 保持新增檔 fail-closed。
# 2026-08-02 READY Batch 2 只放行 handoff 明列的 direct-edit files；init-project-docs 的
# current-doc reference 修正逐檔列出，避免未審新增檔被 wildcard 靜默放行。
# 2026-08-02 Batch 4 closure 只再放行已逐檔裁決的 stance/scope/routing trims；其餘 skill
# 仍走 fail-closed fallback，避免全目錄 wildcard 把未審變更帶進 live tree。
# 2026-08-02 consolidation batch（77 → 71）。退役六支走 attic/ 快照，因此用目錄 wildcard；
# 其餘為承接內容的自有檔，逐檔列出：
#   dotnet-find-bugs/*                 VND 退役。唯一未遷移項（matching binaries/PDB guard）已寫入
#                                      dotnet-core-best-practices；11 條 security checklist 與五支
#                                      runtime 診斷工具在退役當下逐項重驗有更好的 owner。
#   dotnet-test/*                      VND 退役。真實用量 0（4 次全為 skilleval harness）；可攜的
#                                      BenchmarkDotNet 程序搬進 dotnet-testing-best-practices。
#   native-feel-cross-platform-desktop/*  VND 退役，未取出任何內容（使用者確認無跨平台桌面計畫）。
#   pinia/* vue-debug-guides/* vueuse-functions/*  併入 vue-best-practices。vueuse-functions 是
#                                      LICENSE-only VND，經使用者明示 override；MIT 姓名標示隨
#                                      payload 移到 references/vueuse/LICENSE.md。
#   dotnet-core-best-practices/references/security-performance.md  承接 PDB/symbol 前提。
#   dotnet-testing-best-practices/{SKILL.md,references/benchmarks.md}  承接 benchmark；description
#                                      補 run/benchmark trigger，避免 dotnet-test 退役造成能力退化。
#   vue-best-practices/references/{pinia,vueuse,debugging}/*  承接三支的 reference payload；
#                                      原 references/pinia.md 是指向已併入 skill 的轉址，一併刪除。
# 2026-08-05 dotnet/skills harvest。upstream 96 支中 1 支 vendor（test-gap-analysis，走 fork_recorded
# 不需列在此），6 項只取內容折進既有自有檔、不新增 skill。SKILL.md 與 security-performance.md 已
# 在上一批放行，本批只多兩個檔，逐檔列出：
#   dotnet-testing-best-practices/references/mocking-frameworks.md  承接 detect-static-dependencies 的
#                                      category→abstraction 對照與計數規則（依「碰到什麼」分類而非
#                                      依 static 關鍵字；Path.Combine 這類純 helper 不算阻塞項）。
#   dotnet-testing-best-practices/references/coverage-crap.md  新檔，承接 crap-score：CRAP 公式、
#                                      risk band、反解 cov_needed 及其 comp≥15 無解的邊界，以及
#                                      「絕不估算覆蓋率」的 fallback 階梯。Rule 12 的量化面。
# 2026-08-28 speak-human-tw 逐檔列舉，與 auditing-skill-folder 同理由。第一版寫成
# `skills/speak-human-tw/*`，理由是「漂移由 vendored-skills.lock 雙 SHA 釘死，逐檔不多守住
# 任何東西」——S5 Standards 軸用 ablation 推翻：在 payload 丟一個新檔、同一個 commit 把兩個
# SHA 一起更新，本測試與 vendored-detection.sh 全綠；只拿掉那行萬用字元才會紅。lock 的雙 SHA
# 守的是「內容有沒有變」，守不住「有沒有人看過這個新檔」，而後者正是這道閘的用途。既有的目錄
# 萬用字元（dotnet-find-bugs/*、pinia/* 等）全是 :723 那批**已退役**路徑，不會再變，判準不轉移
# 到 live skill。
# payload 不是整個 upstream repo：27 個檔只取 10 個，取捨規則記在 vendored-skills.lock 的檔頭
# 註解（SKILL.md 相對引用的遞移閉包 + LICENSE）。
while IFS= read -r changed; do
  case "$changed" in
    skills/agent-browser/SKILL.md | \
    skills/apple-calendar/* | \
    skills/dotnet-find-bugs/* | \
    skills/dotnet-test/* | \
    skills/native-feel-cross-platform-desktop/* | \
    skills/pinia/* | \
    skills/vue-debug-guides/* | \
    skills/vueuse-functions/* | \
    skills/dotnet-core-best-practices/references/security-performance.md | \
    skills/dotnet-testing-best-practices/SKILL.md | \
    skills/dotnet-testing-best-practices/references/benchmarks.md | \
    skills/dotnet-testing-best-practices/references/code-patterns.md | \
    skills/dotnet-testing-best-practices/references/coverage-crap.md | \
    skills/dotnet-testing-best-practices/references/mocking-frameworks.md | \
    skills/vue-best-practices/references/pinia.md | \
    skills/vue-best-practices/references/pinia/advanced-hmr.md | \
    skills/vue-best-practices/references/pinia/advanced-nuxt.md | \
    skills/vue-best-practices/references/pinia/advanced-ssr.md | \
    skills/vue-best-practices/references/pinia/best-practices-outside-component.md | \
    skills/vue-best-practices/references/pinia/best-practices-testing.md | \
    skills/vue-best-practices/references/pinia/core-stores.md | \
    skills/vue-best-practices/references/pinia/features-composables.md | \
    skills/vue-best-practices/references/pinia/features-composing-stores.md | \
    skills/vue-best-practices/references/pinia/features-plugins.md | \
    skills/vue-best-practices/references/pinia/unit-test-vue-pinia-patterns.md | \
    skills/vue-best-practices/references/vueuse/INDEX.md | \
    skills/vue-best-practices/references/vueuse/LICENSE.md | \
    skills/vue-best-practices/references/debugging/INDEX.md | \
    skills/vue-best-practices/references/component-patterns.md | \
    skills/vue-best-practices/references/testing.md | \
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
    skills/auditing-skill-folder/scripts/check-relative-references.sh | \
    skills/auditing-skill-folder/scripts/count-words.sh | \
    skills/auditing-skill-folder/scripts/eval-triggers.sh | \
    skills/auditing-skill-folder/scripts/lib-vendored.sh | \
    skills/auditing-skill-folder/scripts/lint-descriptions.sh | \
    skills/auth-implementation-patterns/SKILL.md | \
    skills/bug-fix-settlement/SKILL.md | \
    skills/bug-fix-settlement/references/settlement-guide.md | \
    skills/clarify/* | \
    skills/aspnet-api-architect/SKILL.md | \
    skills/aspnet-api-architect/templates/design.md | \
    skills/aspnet-api-architect/templates/tasks.md | \
    skills/backend-release-verification/SKILL.md | \
    skills/containerization/SKILL.md | \
    skills/context7-mcp/* | \
    skills/css-ui-best-practices/SKILL.md | \
    skills/css-ui-best-practices/references/design-system-patterns.md | \
    skills/csharp-developer/* | \
    skills/dependency-security-scan/SKILL.md | \
    skills/deps-check/SKILL.md | \
    skills/deps-check/scripts/deps-check.sh | \
    skills/dev-workflow/* | \
    skills/dapper-best-practices/SKILL.md | \
    skills/dapper-best-practices/references/rules-expanded.md | \
    skills/dotnet-core-best-practices/SKILL.md | \
    skills/dotnet-core-best-practices/references/architecture-di.md | \
    skills/dotnet-core-best-practices/references/code-patterns.md | \
    skills/dotnet-core-best-practices/references/configuration-hosting.md | \
    skills/dotnet-framework-best-practices/SKILL.md | \
    skills/dotnet-framework-best-practices/references/configuration-hosting.md | \
    skills/dotnet-winforms-best-practices/SKILL.md | \
    skills/dotnet-winforms-best-practices/references/code-patterns.md | \
    skills/dotnet-winforms-best-practices/references/layout-design.md | \
    skills/ef-core-best-practices/SKILL.md | \
    skills/ef-core-best-practices/references/rules-expanded.md | \
    skills/ef-core-best-practices/references/working-patterns.md | \
    skills/dotnet-logging-best-practices/SKILL.md | \
    skills/frontend-release-verification/SKILL.md | \
    skills/init-project-docs/SKILL.md | \
    skills/init-project-docs/references/README.md | \
    skills/init-project-docs/references/agents/copilot/README.md | \
    skills/init-project-docs/references/hooks/auto-api-docs.sh | \
    skills/init-project-docs/references/hooks/codex/README.md | \
    skills/init-project-docs/references/hooks/protect-files.sh | \
    skills/init-project-docs/references/host-matrix.md | \
    skills/init-project-docs/references/settings-templates/copilot/README.md | \
    skills/make-skill-template/* | \
    skills/mp-diagnose/* | \
    skills/mp-grill-with-docs/* | \
    skills/mp-improve-codebase-architecture/* | \
    skills/mp-tdd/* | \
    skills/nuxt/SKILL.md | \
    skills/postgresql-optimization/SKILL.md | \
    skills/nuget-manager/* | \
    skills/security-review/SKILL.md | \
    skills/security-review/references/changed-file-attack-surface.md | \
    skills/security-review/references/language-patterns.md | \
    skills/security-review/references/report-format.md | \
    skills/security-review/references/secret-patterns.md | \
    skills/security-review/references/vuln-categories.md | \
    skills/security-review/references/vulnerable-packages.md | \
    skills/security-review/references/workflow.md | \
    skills/shared-security-review/SKILL.md | \
    skills/shared-security-review/references/changed-file-attack-surface.md | \
    skills/shared-security-review/references/language-patterns.md | \
    skills/shared-security-review/references/report-format.md | \
    skills/shared-security-review/references/secret-patterns.md | \
    skills/shared-security-review/references/vuln-categories.md | \
    skills/shared-security-review/references/vulnerable-packages.md | \
    skills/shared-security-review/references/workflow.md | \
    skills/sdd/SKILL.md | \
    skills/speak-human-tw/LICENSE | \
    skills/speak-human-tw/SKILL.md | \
    skills/speak-human-tw/evals/benchmark.md | \
    skills/speak-human-tw/evals/run-eval.md | \
    skills/speak-human-tw/references/examples.md | \
    skills/speak-human-tw/references/changelog.md | \
    skills/speak-human-tw/references/humanize.md | \
    skills/speak-human-tw/references/patterns.md | \
    skills/speak-human-tw/references/protected-list.md | \
    skills/speak-human-tw/references/scenes.md | \
    skills/speak-human-tw/references/taiwan-localization.md | \
    skills/testing-library-react-best-practices/SKILL.md | \
    skills/typescript-best-practices/references/config-and-project.md | \
    skills/vue-best-practices/SKILL.md | \
    skills/vue-best-practices/references/rules-expanded.md | \
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

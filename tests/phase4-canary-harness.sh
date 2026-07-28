#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
HARNESS="$ROOT/bin/phase4-canary-harness"
MATRIX="$ROOT/proposals/2026-07-27-mattpocock-skills-workflow/23-phase4-canary-matrix.jsonl"
SCHEMA="$ROOT/proposals/2026-07-27-mattpocock-skills-workflow/26-phase4-v2-result-schema.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
accept() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    ng "$label"
  fi
}
reject() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then ng "$label"; else ok "$label"; fi
}
fixture_is_deterministic_red() {
  local fixture="$TMP/fixture"
  "$HARNESS" prepare-fixture "$fixture" >/dev/null || return 1
  local output rc
  output=$(cd "$fixture" && bash tests/count-lines.sh 2>&1)
  rc=$?
  [ "$rc" -ne 0 ] && ! grep -qi 'no such file' <<<"$output"
}
arms_are_isolated() {
  local arms="$TMP/arms"
  "$HARNESS" prepare-arms "$arms" >/dev/null || return 1
  local skill
  for skill in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
    [ -d "$arms/arm-a/home/.agents/skills/$skill" ] || return 1
    [ ! -e "$arms/arm-b/home/.agents/skills/$skill" ] || return 1
    [ -d "$arms/arm-b/home/.agents/attic/phase4-legacy/$skill" ] || return 1
  done
  while IFS='=' read -r key skill; do
    [ "$key" != skill ] || [ -d "$arms/arm-b/home/.agents/skills/$skill" ] || return 1
  done < "$ROOT/mattpocock-skills.lock"
  local host
  for host in claude codex copilot; do
    [ -L "$arms/arm-a/plugin-payloads/$host-superpowers" ] || return 1
    [ "$(find -L "$arms/arm-a/plugin-payloads/$host-superpowers/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 14 ] ||
      return 1
  done
  [ ! -e "$arms/arm-b/plugin-payloads" ] || return 1
  [ "$(jq -r '.superpowers_loaded' "$arms/arm-a/inventory-contract.json")" = true ] &&
    [ "$(jq -r '.superpowers_loaded' "$arms/arm-b/inventory-contract.json")" = false ]
}
schema_omits_codex_rejected_unique_items() {
  jq -e '[.. | objects | select(has("uniqueItems"))] | length == 0' "$SCHEMA" >/dev/null
}

mkdir -p "$TMP/good"
printf 'base\n' > "$TMP/good/README.md"
"$HARNESS" snapshot "$TMP/good" "$TMP/before.tsv"
cp "$TMP/before.tsv" "$TMP/after.tsv"

cat > "$TMP/inventory-good.json" <<'JSON'
{"skills":["code-review","diagnosing-bugs","tdd"],"superpowers_loaded":false,"legacy_wrappers":[]}
JSON
cat > "$TMP/inventory-arm-b-nonlegacy-mp.json" <<'JSON'
{"skills":["code-review","diagnosing-bugs","mp-zoom-out","tdd"],"superpowers_loaded":false,"legacy_wrappers":[]}
JSON
cat > "$TMP/inventory-bad.json" <<'JSON'
{"skills":["superpowers:test-driven-development","mp-tdd"],"superpowers_loaded":true,"legacy_wrappers":["mp-tdd"]}
JSON
cat > "$TMP/result-good.json" <<'JSON'
{"completed":true,"actual_workflows":["tdd"],"evidence":["test red","test green"]}
JSON
cat > "$TMP/result-wrong-route.json" <<'JSON'
{"completed":true,"actual_workflows":["diagnosing-bugs"],"evidence":["test red","test green"]}
JSON
cat > "$TMP/result-collision.json" <<'JSON'
{"completed":true,"actual_workflows":["tdd","superpowers:test-driven-development"],"evidence":["test red","test green"]}
JSON
cat > "$TMP/result-no-evidence.json" <<'JSON'
{"completed":true,"actual_workflows":["tdd"],"evidence":[]}
JSON
cat > "$TMP/result-completed-with-evidence.json" <<'JSON'
{"completed":true,"actual_workflows":["tdd"],"evidence":["claimed explanation"]}
JSON
cat > "$TMP/result-v2-good.json" <<'JSON'
{
  "completed": true,
  "route_telemetry": {
    "version": 2,
    "selected_workflows": ["bug-fix-settlement", "diagnosing-bugs", "tdd"],
    "supporting_workflows": ["dev-workflow"],
    "events": [
      {"sequence": 1, "role": "supporting", "workflow": "dev-workflow", "source": "injected-policy"},
      {"sequence": 2, "role": "selected", "workflow": "bug-fix-settlement", "source": "skill-file"},
      {"sequence": 3, "role": "selected", "workflow": "diagnosing-bugs", "source": "skill-file"},
      {"sequence": 4, "role": "selected", "workflow": "tdd", "source": "skill-file"}
    ]
  },
  "evidence": ["test red", "test green"],
  "summary": "fixed"
}
JSON
jq '.route_telemetry.supporting_workflows=["code-review"]
    | .route_telemetry.events[0].workflow="code-review"' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-unallowed-support.json"
jq '.route_telemetry.selected_workflows -= ["tdd"]
    | .route_telemetry.events = [.route_telemetry.events[] | select(.workflow != "tdd")]' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-missing-selected.json"
jq '.route_telemetry.events += [
      {"sequence":5,"role":"selected","workflow":"tdd","source":"skill-file"}
    ]' "$TMP/result-v2-good.json" > "$TMP/result-v2-duplicate-event.json"
jq '.route_telemetry.selected_workflows += ["tdd"]' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-duplicate-selected.json"
jq '.route_telemetry.supporting_workflows += ["dev-workflow"]' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-duplicate-supporting.json"
jq '.route_telemetry.events = [.route_telemetry.events[] | select(.workflow != "tdd")]' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-event-mismatch.json"
jq '.route_telemetry.supporting_workflows=["superpowers:using-superpowers"]
    | .route_telemetry.events[0].workflow="superpowers:using-superpowers"' \
  "$TMP/result-v2-good.json" > "$TMP/result-v2-forbidden.json"
cat > "$TMP/events-empty.jsonl" <<'JSON'
{"type":"assistant.message","content":"done"}
JSON
cat > "$TMP/events-tool-claude.jsonl" <<'JSON'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}
JSON
cat > "$TMP/events-tool-codex.jsonl" <<'JSON'
{"type":"item.started","item":{"type":"command_execution","command":"git status"}}
JSON
cat > "$TMP/events-tool-copilot.jsonl" <<'JSON'
{"type":"tool.execution","toolName":"shell","arguments":{"command":"git status"}}
JSON
cat > "$TMP/events-network.jsonl" <<'JSON'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"WebFetch"}]}}
JSON
cat > "$TMP/events-subagent.jsonl" <<'JSON'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Task"}]}}
JSON
cat > "$TMP/events-retry.jsonl" <<'JSON'
{"type":"turn.retry","retry_count":1}
JSON
cat > "$TMP/events-external-carriers.jsonl" <<'JSON'
{"type":"phase4.external_carrier","role":"standards"}
{"type":"phase4.external_carrier","role":"spec"}
JSON
cat > "$TMP/events-live-read.jsonl" <<'JSON'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/Users/pochientsai/.agents/skills/dev-workflow/SKILL.md"}}]}}
JSON
printf 'fingerprint-v4\n' > "$TMP/fingerprint-expected"
cp "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
printf 'fingerprint-drift\n' > "$TMP/fingerprint-bad"

cat > "$TMP/case-good.json" <<JSON
{"arm":"B","class":"bugfix","intended_workflows":["tdd"],"allowed_tools":[],"expected_file_mutations":[],"requires_evidence":true,"retry_budget":0}
JSON
cat > "$TMP/case-missing-mutation.json" <<JSON
{"arm":"B","class":"bugfix","intended_workflows":["tdd"],"allowed_tools":["shell"],"expected_file_mutations":["scripts/count-lines.sh"],"requires_evidence":true,"retry_budget":0}
JSON
cat > "$TMP/case-missing-evidence.json" <<JSON
{"arm":"B","class":"missing-evidence","intended_workflows":["tdd"],"allowed_tools":[],"expected_file_mutations":[],"requires_evidence":true,"retry_budget":0}
JSON
cat > "$TMP/case-local-tools.json" <<JSON
{"arm":"B","class":"bugfix","intended_workflows":["tdd"],"allowed_tools":["read","shell"],"allow_subagent":false,"nested_saas_runs":0,"expected_file_mutations":[],"requires_evidence":true,"retry_budget":0}
JSON
cat > "$TMP/case-v2.json" <<'JSON'
{
  "arm": "B",
  "class": "bugfix",
  "route_contract": {
    "version": 2,
    "selected_workflows": ["bug-fix-settlement", "diagnosing-bugs", "tdd"],
    "allowed_supporting_workflows": ["dev-workflow", "deps-check"],
    "forbidden_workflow_prefixes": ["superpowers:", "mp-"]
  },
  "allowed_tools": [],
  "forbidden_read_prefixes": ["/Users/pochientsai/.agents"],
  "allow_subagent": false,
  "nested_saas_runs": 0,
  "expected_file_mutations": [],
  "requires_evidence": true,
  "retry_budget": 0
}
JSON
jq '.route_contract.allowed_supporting_workflows += ["superpowers:using-superpowers"]' \
  "$TMP/case-v2.json" > "$TMP/case-v2-forbidden.json"
jq '.allowed_tools=["read"]' "$TMP/case-v2.json" > "$TMP/case-v2-local-read.json"
cat > "$TMP/case-v2-review.json" <<'JSON'
{
  "arm": "B",
  "class": "review",
  "route_contract": {
    "version": 2,
    "selected_workflows": ["code-review"],
    "allowed_supporting_workflows": ["dev-workflow", "deps-check"],
    "forbidden_workflow_prefixes": ["superpowers:", "mp-"]
  },
  "allowed_tools": ["read", "subagent"],
  "allow_subagent": true,
  "nested_saas_runs": 2,
  "expected_file_mutations": [],
  "requires_evidence": true,
  "retry_budget": 0
}
JSON
cat > "$TMP/result-v2-review.json" <<'JSON'
{
  "completed": true,
  "route_telemetry": {
    "version": 2,
    "selected_workflows": ["code-review"],
    "supporting_workflows": ["dev-workflow"],
    "events": [
      {"sequence": 1, "role": "supporting", "workflow": "dev-workflow", "source": "injected-policy"},
      {"sequence": 2, "role": "selected", "workflow": "code-review", "source": "skill-file"}
    ]
  },
  "evidence": ["standards checked", "spec checked"],
  "summary": "reviewed"
}
JSON

if [ -f "$MATRIX" ]; then
  accept "real 42-row matrix is complete" "$HARNESS" validate-matrix "$MATRIX"
else
  ok "real matrix validation SKIPPED until corpus commit"
fi
accept "Codex result schema omits rejected uniqueItems" schema_omits_codex_rejected_unique_items
accept "fixture regression is red for the intended contract" fixture_is_deterministic_red
accept "scratch Arm A/B carriers are physically isolated" arms_are_isolated
accept "valid synthetic result passes" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
accept "v2 selected and allowed supporting routes pass" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
accept "Arm B unrelated mp skill inventory passes when route is clean" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-arm-b-nonlegacy-mp.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 unallowed supporting route fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-unallowed-support.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 missing selected route fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-missing-selected.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 duplicate selected workflow fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-duplicate-selected.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 duplicate supporting workflow fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-duplicate-supporting.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 duplicate invocation event fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-duplicate-event.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 telemetry event mismatch fails" "$HARNESS" verify-result \
  "$TMP/case-v2.json" "$TMP/result-v2-event-mismatch.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 Arm B forbidden route fails even when supporting allowlisted" "$HARNESS" verify-result \
  "$TMP/case-v2-forbidden.json" "$TMP/result-v2-forbidden.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
accept "v2 external Codex review carriers count against the nested budget" "$HARNESS" verify-result \
  "$TMP/case-v2-review.json" "$TMP/result-v2-review.json" "$TMP/events-external-carriers.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "v2 tool event cannot read a live config prefix" "$HARNESS" verify-result \
  "$TMP/case-v2-local-read.json" "$TMP/result-v2-good.json" "$TMP/events-live-read.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "wrong route fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-wrong-route.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "legacy collision or double execution fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-collision.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "completed without evidence fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-no-evidence.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "missing-evidence probe cannot complete even with prose evidence" "$HARNESS" verify-result \
  "$TMP/case-missing-evidence.json" "$TMP/result-completed-with-evidence.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "Claude tool call is parsed and fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-tool-claude.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "Codex tool call is parsed and fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-tool-codex.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "Copilot tool call is parsed and fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-tool-copilot.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "network tool fails even when local tools are allowed" "$HARNESS" verify-result \
  "$TMP/case-local-tools.json" "$TMP/result-good.json" "$TMP/events-network.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "unbudgeted subagent fails" "$HARNESS" verify-result \
  "$TMP/case-local-tools.json" "$TMP/result-good.json" "$TMP/events-subagent.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "retry event is parsed and fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-retry.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"

printf 'changed\n' > "$TMP/good/README.md"
"$HARNESS" snapshot "$TMP/good" "$TMP/changed.tsv"
reject "unexpected file mutation fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/changed.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "missing expected file mutation fails" "$HARNESS" verify-result \
  "$TMP/case-missing-mutation.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "Arm B superpowers or legacy inventory fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-bad.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-actual"
reject "rollback fingerprint mismatch fails" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
  "$TMP/before.tsv" "$TMP/after.tsv" "$TMP/inventory-good.json" \
  "$TMP/fingerprint-expected" "$TMP/fingerprint-bad"

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

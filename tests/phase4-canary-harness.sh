#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
HARNESS="$ROOT/bin/phase4-canary-harness"
MATRIX="$ROOT/proposals/2026-07-27-mattpocock-skills-workflow/23-phase4-canary-matrix.jsonl"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
accept() {
  local label=$1
  shift
  "$@" >/dev/null 2>&1 && ok "$label" || ng "$label"
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

mkdir -p "$TMP/good"
printf 'base\n' > "$TMP/good/README.md"
"$HARNESS" snapshot "$TMP/good" "$TMP/before.tsv"
cp "$TMP/before.tsv" "$TMP/after.tsv"

cat > "$TMP/inventory-good.json" <<'JSON'
{"skills":["code-review","diagnosing-bugs","tdd"],"superpowers_loaded":false,"legacy_wrappers":[]}
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

if [ -f "$MATRIX" ]; then
  accept "real 42-row matrix is complete" "$HARNESS" validate-matrix "$MATRIX"
else
  ok "real matrix validation SKIPPED until corpus commit"
fi
accept "fixture regression is red for the intended contract" fixture_is_deterministic_red
accept "scratch Arm A/B carriers are physically isolated" arms_are_isolated
accept "valid synthetic result passes" "$HARNESS" verify-result \
  "$TMP/case-good.json" "$TMP/result-good.json" "$TMP/events-empty.jsonl" \
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

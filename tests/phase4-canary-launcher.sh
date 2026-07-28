#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
LAUNCHER="$ROOT/bin/phase4-canary-launcher"
MATRIX="$ROOT/proposals/2026-07-27-mattpocock-skills-workflow/27-phase4-v2-canary-matrix.jsonl"
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

case_from_matrix() {
  local id=$1 output=$2
  jq -e -c --arg id "$id" 'select(.id == $id)' "$MATRIX" > "$output"
}

claude_plan_is_isolated() {
  case_from_matrix claude-a-missing-evidence "$TMP/claude-case.json" || return 1
  "$LAUNCHER" plan "$TMP/claude-case.json" "$TMP/claude-plan.json" || return 1
  jq -e '
    .command as $command |
    .host == "claude" and
    .carrier_mode == "builtin-agent" and
    .environment.HOME == "/private/tmp/phase4-canary-v2/runtime/claude/A/home" and
    .environment.CLAUDE_CONFIG_DIR == "/private/tmp/phase4-canary-v2/runtime/claude/A/config" and
    (.isolation.deny_read_prefixes | index("/Users/pochientsai/.agents") != null) and
    ($command | index("--strict-mcp-config") != null) and
    ($command | index("{\"mcpServers\":{}}") != null) and
    ($command[($command | index("--tools")) + 1] == "") and
    ($command[($command | index("--json-schema")) + 1] | fromjson | has("$schema") | not) and
    ($command | join("\n") | contains("/private/tmp/phase4-canary/runs/") | not)
  ' "$TMP/claude-plan.json" >/dev/null
}

codex_review_uses_external_carriers() {
  case_from_matrix codex-b-review "$TMP/codex-case.json" || return 1
  "$LAUNCHER" plan "$TMP/codex-case.json" "$TMP/codex-plan.json" || return 1
  jq -e '
    .command as $command |
    .host == "codex" and
    .carrier_mode == "external-exec" and
    .requires_outer_unsandboxed == true and
    (.carrier_commands | length) == 2 and
    (.carrier_event_templates | map(.role)) == ["standards","spec"] and
    (.carrier_event_templates | all(.emit_after == "successful_carrier_exit")) and
    (.carrier_commands | all(
      (index("--disable") != null) and
      (.[index("--disable") + 1] == "multi_agent") and
      (index("read-only") != null) and
      (index("--dangerously-bypass-approvals-and-sandbox") == null)
    )) and
    ($command | index("--disable") != null) and
    ($command[($command | index("--disable")) + 1] == "multi_agent") and
    ($command | index("--enable") == null) and
    ($command | index("--dangerously-bypass-approvals-and-sandbox") == null) and
    ($command | join("\n") | contains("/private/tmp/phase4-canary/runs/") | not)
  ' "$TMP/codex-plan.json" >/dev/null
}

copilot_plan_embeds_exact_result_schema() {
  case_from_matrix copilot-a-architecture "$TMP/copilot-case.json" || return 1
  "$LAUNCHER" plan "$TMP/copilot-case.json" "$TMP/copilot-plan.json" || return 1
  local schema
  schema=$(jq -c 'del(."$schema")' "$SCHEMA") || return 1
  jq -e --arg schema "$schema" '
    .command as $command |
    ($command[($command | index("-p")) + 1]) as $prompt |
    .host == "copilot" and
    .credential_env == ["COPILOT_GITHUB_TOKEN"] and
    ($prompt | contains("Phase 4 v2 result schema: " + $schema)) and
    ($prompt | contains("Return exactly one JSON object matching this schema.")) and
    ($prompt | contains("Do not wrap it in Markdown fences or add prose."))
  ' "$TMP/copilot-plan.json" >/dev/null
}

v2_budget_is_staged() {
  jq -e -s '
    length == 42 and
    ([.[] | select(.stage == 1)] | length) == 6 and
    ([.[] | select(.stage == 1) | .top_level_saas_runs] | add) == 6 and
    ([.[] | select(.stage == 1) | .nested_saas_runs] | add) == 0 and
    ([.[] | select(.stage == 2) | .top_level_saas_runs] | add) == 36 and
    ([.[] | select(.stage == 2) | .nested_saas_runs] | add) == 9 and
    ([.[] | .top_level_saas_runs] | add) == 42 and
    ([.[] | .nested_saas_runs] | add) == 9 and
    ([.[] | select(.stage == 1) | .host] | group_by(.) | map(length) | sort) == [2,2,2] and
    all(.[]; .retry_budget == 0)
  ' "$MATRIX" >/dev/null
}

all_plans_are_bounded() {
  local cases="$TMP/cases" plans="$TMP/plans" row id case_file plan_file
  mkdir -p "$cases" "$plans"
  while IFS= read -r row; do
    id=$(jq -r '.id' <<<"$row") || return 1
    case_file="$cases/$id.json"
    plan_file="$plans/$id.json"
    printf '%s\n' "$row" > "$case_file"
    "$LAUNCHER" plan "$case_file" "$plan_file" || return 1
    jq -e \
      --arg fixture "$(jq -r '.fixture' "$case_file")" \
      --argjson forbidden_read_prefixes "$(jq '.forbidden_read_prefixes' "$case_file")" '
      .version == 2 and
      (.command | type == "array" and length > 5) and
      (.command | join("\n") | contains($fixture)) and
      (.command | join("\n") | contains("/private/tmp/phase4-canary/runs/") | not) and
      (.command | index("--dangerously-bypass-approvals-and-sandbox") == null) and
      ((.carrier_commands | length) ==
        (if .carrier_mode == "external-exec" then .budget.nested_saas_runs else 0 end)) and
      ((.carrier_event_templates | length) ==
        (if .carrier_mode == "external-exec" then .budget.nested_saas_runs else 0 end)) and
      (.carrier_commands | all(index("--dangerously-bypass-approvals-and-sandbox") == null)) and
      .budget.retry_budget == 0 and
      (.budget.timeout_seconds | type == "number" and . > 0) and
      (.environment.HOME | startswith("/private/tmp/phase4-canary-v2/runtime/")) and
      .isolation.network == false and
      .isolation.live_config_mutation == false and
      .isolation.deny_read_prefixes == $forbidden_read_prefixes
    ' "$plan_file" >/dev/null || return 1
  done < "$MATRIX"
}

reject "launcher refuses an unknown command" "$LAUNCHER" execute "$TMP/no-case.json"
accept "Claude missing-evidence plan is scratch-only and tool-free" claude_plan_is_isolated
accept "Codex review plan uses external carriers without nested sandbox bypass" codex_review_uses_external_carriers
accept "Copilot plan embeds the exact result schema without Markdown fences" copilot_plan_embeds_exact_result_schema
accept "v2 budget is split into 6-run Stage 1 and 45-run Stage 2" v2_budget_is_staged
accept "all 42 launch plans stay inside the v2 budget and scratch boundary" all_plans_are_bounded

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

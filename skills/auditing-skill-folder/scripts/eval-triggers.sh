#!/usr/bin/env bash
# Step 2c — Trigger accuracy eval. The BEHAVIOURAL counterpart to Step 2.
#
# Step 2 (lint-descriptions.sh) reads a description and guesses, from regex, whether it is written
# as a trigger. That is a proxy. This script measures the thing the proxy stands in for: given a
# prompt a user would actually type, does the skill fire — and when it must stay quiet, does it?
#
# It also makes Step 2b (trigger collision) empirical for the first time. Step 2b today is a human
# reading the lint table ACROSS rows and judging whether two descriptions claim one trigger space.
# Here every competing skill is loaded at once and the transcript names the WINNER, so a collision
# is observed rather than argued.
#
# Usage:
#   eval-triggers.sh --runner claude [--cases FILE] [--skills DIR] [--max-cases N] [--isolate] [--jsonl OUT]
#
#   --runner NAME   REQUIRED, no default, on purpose. 'claude' spends real rate-limit budget and
#                   'mock' returns canned data that must never be mistaken for an audit result;
#                   defaulting to either one is a way to be silently wrong.
#   --isolate       Load ONLY the skill each case targets. Measures the description in a vacuum:
#                   recall without collision pressure. Default (all skills loaded) is the realistic
#                   arm and the only one that can observe a collision.
#   --max-cases N   Stop after N cases. Prints what was skipped — a truncated run must never read
#                   as full coverage.
#
# Exit: 0 = every case matched its expectation. 1 = at least one mismatch. 2 = ran nothing.
#
# SCOPE: measures WHICH skill fires, not whether the skill's body then did good work. Output
# quality is a separate rubric and deliberately not conflated with trigger accuracy here.
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd) || exit 1
SKILL_ROOT=$(cd "$SELF_DIR/.." && pwd)
EVALS_DIR="$SKILL_ROOT/evals"
PLUGIN_NAME="skilleval"

RUNNER=""
CASES="$EVALS_DIR/cases.jsonl"
SKILLS_DIR="${AGENTS_HOME:-$HOME/.agents}/skills"
MAX_CASES=0
ISOLATE=0
JSONL_OUT=""

die() { printf 'eval-triggers: %s\n' "$*" >&2; exit 1; }
need_val() { [ "$#" -ge 2 ] || die "$1 requires a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    # need_val before every value-taking flag: `--runner` at the end of the line used to set an
    # empty value and then `shift 2` past the end. A bad invocation must die with one clear line,
    # not leak a shell diagnostic into a table that other tools parse.
    --runner)    need_val "$@"; RUNNER="$2"; shift 2 ;;
    --cases)     need_val "$@"; CASES="$2"; shift 2 ;;
    --skills)    need_val "$@"; SKILLS_DIR="$2"; shift 2 ;;
    --max-cases) need_val "$@"
                 case "$2" in ''|*[!0-9]*) die "--max-cases must be a non-negative integer, got: $2" ;; esac
                 MAX_CASES="$2"; shift 2 ;;
    --jsonl)     need_val "$@"; JSONL_OUT="$2"; shift 2 ;;
    --isolate)   ISOLATE=1; shift ;;
    -h|--help)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           die "unknown argument: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required (used by 5 existing tests/ scripts; brew install jq)"

RUNNERS_JSON="$EVALS_DIR/runners.json"
[ -r "$RUNNERS_JSON" ] || die "runners.json not found: $RUNNERS_JSON"

# The list is read from runners.json rather than spelled out here. A hard-coded list is a second
# source of truth that goes stale the moment a runner is added, and it goes stale silently — the
# message keeps looking authoritative while naming runners that no longer exist. Underscore-
# prefixed keys are documentation blocks, not runners.
runner_names() { jq -r 'keys[] | select(startswith("_") | not)' "$RUNNERS_JSON" 2>/dev/null | paste -sd'|' -; }
[ -n "$RUNNER" ] ||
  die "--runner is required ($(runner_names)). No default: a live runner spends rate limit and mock returns canned data, so defaulting to either is a way to be silently wrong."
[ -r "$CASES" ]  || die "cases file not found: $CASES"
[ -d "$SKILLS_DIR" ] || die "skills dir not found: $SKILLS_DIR"
jq -e --arg r "$RUNNER" 'has($r)' "$RUNNERS_JSON" >/dev/null 2>&1 ||
  die "runner '$RUNNER' not defined in $RUNNERS_JSON"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/skilleval.XXXXXX") || die "mktemp failed"
trap 'rm -rf "$TMP"' EXIT
PLUGIN_DIR="$TMP/plugin"
RUN_CWD="$TMP/cwd"          # fresh cwd => empty auto-memory namespace (see runners.json note 2)
mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/skills" "$RUN_CWD" || die "mkdir failed under $TMP"
printf '{"name":"%s","version":"0.0.1","description":"throwaway plugin for trigger eval"}\n' \
  "$PLUGIN_NAME" > "$PLUGIN_DIR/.claude-plugin/plugin.json"

# read_frontmatter_bool <skill.md> <key> -> "true" | "false"
# Only the frontmatter block is scanned: a body line saying "disable-model-invocation" is prose.
read_frontmatter_bool() {
  awk -v key="$2" '
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm==0 { exit }
    /^---[[:space:]]*$/ { exit }
    $0 ~ "^" key ":[[:space:]]*true[[:space:]]*$" { print "true"; exit }
  ' "$1" 2>/dev/null | grep -q true && echo true || echo false
}

# install_skill <name> — copy one skill folder into the throwaway plugin.
# -L dereferences symlinks: ~/.claude/skills entries are symlinks back into ~/.agents/skills, and
# a copied dangling symlink would present as a skill with no SKILL.md.
#
# The name is validated before it reaches any path. It arrives from cases.jsonl, which is a local
# file rather than hostile input — but this function does `rm -rf` on a path built from it, and a
# name containing `/` or `..` would put that deletion outside the throwaway plugin. A single
# fat-fingered case entry is enough; no attacker required.
install_skill() {
  local name="$1" src
  case "$name" in
    ''|.|..|*/*|*'\'*|.*) return 2 ;;
  esac
  src="$SKILLS_DIR/$name"
  [ -r "$src/SKILL.md" ] || return 1
  rm -rf "${PLUGIN_DIR:?}/skills/${name:?}"
  cp -RL "$src" "$PLUGIN_DIR/skills/$name" 2>/dev/null || return 1
  return 0
}

install_all_skills() {
  local d n ok=0
  for d in "$SKILLS_DIR"/*/; do
    n=$(basename "$d")
    install_skill "$n" && ok=$((ok + 1))
  done
  echo "$ok"
}

# Resolve the runner command, substituting placeholders.
# Read loop rather than `mapfile -t`: macOS ships bash 3.2, where mapfile does not exist. It fails
# as "command not found", which under `set -u` then surfaces as an unrelated "RUNNER_CMD: unbound
# variable" — every case scored ERR with no hint at the real cause. Keep this bash-3.2 clean.
RUNNER_CMD=()
while IFS= read -r _arg; do
  RUNNER_CMD+=("$_arg")
done < <(jq -r --arg r "$RUNNER" --arg p "$PLUGIN_DIR" --arg e "$EVALS_DIR" \
  '.[$r].command[] | gsub("\\{PLUGIN_DIR\\}"; $p) | gsub("\\{EVALS_DIR\\}"; $e)' "$RUNNERS_JSON")
[ "${#RUNNER_CMD[@]}" -gt 0 ] || die "runner '$RUNNER' has an empty command array"

# Mechanical check that the isolation flag documented in runners.json is actually on the command
# line. Without it a run silently measures the host's own CLAUDE.md instead of the skill (control
# group proved that), and the result still LOOKS like a clean audit — the failure mode this whole
# script exists to refuse. Prose in runners.json cannot enforce itself; this can.
# 'mock' is exempt: it never reaches a model, so there is nothing to isolate.
# The VALUE is checked, not just the flag's presence. `--setting-sources user` loads the host's
# own settings while still satisfying a presence-only check — the guard would pass and the run
# would quietly measure this machine's config instead of the skill, which is the precise failure
# it was added to prevent. Only the empty string means "load nothing".
if [ "$RUNNER" != "mock" ]; then
  _iso=0; _seen=0; _n=${#RUNNER_CMD[@]}; _i=0
  while [ "$_i" -lt "$_n" ]; do
    if [ "${RUNNER_CMD[$_i]}" = "--setting-sources" ]; then
      _seen=1
      _j=$((_i + 1))
      [ "$_j" -lt "$_n" ] && [ -z "${RUNNER_CMD[$_j]}" ] && _iso=1
    fi
    _i=$((_i + 1))
  done
  if [ "$_seen" -eq 0 ]; then
    die "runner '$RUNNER' has no --setting-sources: the run would load host config and the result would not be an isolated measurement"
  elif [ "$_iso" -eq 0 ]; then
    die "runner '$RUNNER' passes --setting-sources with a non-empty value: only \"\" loads nothing, so the result would not be an isolated measurement"
  fi
fi

# Both parsers below read the stream with `jq -R` + `fromjson?` rather than `jq -s`. -s slurps the
# whole file and fails outright on ONE unparseable line, so a single stray banner line (a CLI
# printing "Reading additional input from stdin..." before the stream, say) would take the entire
# run's parse with it. -R goes line by line and fromjson? drops what is not JSON.

# skill_calls <stream-file> -> every Skill invocation in the turn, one per line, in order.
#
# `..` recurses, so the filter is SHAPE-AGNOSTIC: it finds the tool_use whether it sits nested in
# {"type":"assistant","message":{"content":[…]}} (what claude 2.1.220 actually emits — see
# runners.json) or at the top level of its own event. That is not speculative generality. An
# envelope change would otherwise make both readers below return nothing, every case would score
# `quiet`, and `runner_failed` would still see its result event — so the run would report a clean
# sheet built on a parser that stopped parsing. Matching on the object rather than on its position
# removes the whole failure mode instead of adding a branch per known shape.
# `// empty` is not decoration. Under -r a missing .input.skill prints the literal string "null",
# which the scorer would then read as a fired skill named `null` — a phantom winner in a collision
# row and a phantom violation in a quiet row. The risk went UP when this filter became
# shape-agnostic, because `..` reaches partial or streaming tool_use objects that the old
# position-bound filter never visited.
skill_calls() {
  jq -R -r 'fromjson? | .. | objects
            | select(.type? == "tool_use" and .name? == "Skill")
            | .input?.skill? // empty' \
    "$1" 2>/dev/null
}

# fired_skill <stream-file> -> "skilleval:name" of the FIRST Skill tool call, or "" if none.
# First call is the answer to "which skill won this trigger", which is what a collision is about.
fired_skill() { skill_calls "$1" | head -1; }

# skill_ever_fired <stream-file> <plugin:skill> -> 0 if that skill was invoked ANYWHERE in the turn.
# Distinct from fired_skill on purpose: "who won the trigger" and "did this skill stay out of it"
# are different questions, and only the second one is what a quiet case asserts.
skill_ever_fired() { skill_calls "$1" | grep -Fxq "$2"; }

runner_failed() {
  # Infrastructure failure means: no result event, OR a result event that reports an error.
  # Scoring either as "did not fire" turns an outage into passing quiet cases.
  #
  # The is_error half is not hypothetical. Measured 2026-08-01: an expired OAuth session produced
  #   {"type":"result","subtype":"success","is_error":true,
  #    "result":"Failed to authenticate: OAuth session expired and could not be refreshed",
  #    "terminal_reason":"api_error"}
  # A presence-only check called that a healthy run, no skill fired, and every quiet case scored
  # TN — a clean sheet produced entirely by an auth outage. Note `subtype` said "success" while
  # is_error was true, so subtype is not a usable signal; is_error is.
  #
  # Parsed rather than grepped. This is the single guard standing between an outage and a
  # full-green report, so it must not hinge on the emitter's whitespace.
  _res=$(jq -R -r 'fromjson? | select(.type=="result")
                   | if (.is_error == true) then "err" else "ok" end' "$1" 2>/dev/null | head -1)
  [ "$_res" != "ok" ]
}

# runner_error_reason <stream-file> -> the emitter's own explanation, for the ERR row.
# "runner produced no result event" is useless when the real cause is a stale login; the operator
# needs to know whether to re-authenticate, wait out a rate limit, or fix a flag.
runner_error_reason() {
  jq -R -r 'fromjson? | select(.type=="result" and .is_error == true) | .result? // empty' \
    "$1" 2>/dev/null | head -1 | cut -c1-80
}

printf '%-26s %-30s %-7s %-7s %s\n' "CASE" "TARGET SKILL" "EXPECT" "ACTUAL" "RESULT"
printf '%-26s %-30s %-7s %-7s %s\n' "----" "------------" "------" "------" "------"

total=0; pass=0; fail=0; skipped=0; errored=0; truncated=0
tp=0; fp=0; fn=0; tn=0
# Truncate now and die if it fails. Without set -e an unwritable path (missing directory, no
# permission) would let the whole run proceed and finish "successfully" while the machine-readable
# output the caller asked for never existed.
[ -n "$JSONL_OUT" ] && { : > "$JSONL_OUT" 2>/dev/null || die "cannot write --jsonl target: $JSONL_OUT"; }

if [ "$ISOLATE" -eq 0 ]; then
  installed=$(install_all_skills)
  printf '# arm=collision  skills loaded=%s  runner=%s\n' "$installed" "$RUNNER"
else
  printf '# arm=isolate  (one skill per case)  runner=%s\n' "$RUNNER"
fi

while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in \#*) continue ;; esac

  # 2>/dev/null on every field read: a malformed line is already reported as `ERR malformed case`
  # below, and letting jq also spray its own parse error to stderr buries that row in noise and
  # breaks anything consuming this table.
  id=$(printf '%s' "$line"     | jq -r '.id // empty'     2>/dev/null)
  skill=$(printf '%s' "$line"  | jq -r '.skill // empty'  2>/dev/null)
  prompt=$(printf '%s' "$line" | jq -r '.prompt // empty' 2>/dev/null)
  expect=$(printf '%s' "$line" | jq -r '.expect // empty' 2>/dev/null)
  [ -n "$id" ] && [ -n "$skill" ] && [ -n "$prompt" ] && [ -n "$expect" ] || {
    printf '%-26s %-30s %-7s %-7s %s\n' "${id:-(no id)}" "${skill:-?}" "-" "-" "ERR malformed case"
    errored=$((errored + 1)); continue; }
  case "$expect" in fire|quiet) ;; *)
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR expect must be fire|quiet"
    errored=$((errored + 1)); continue ;;
  esac

  if [ "$MAX_CASES" -gt 0 ] && [ "$total" -ge "$MAX_CASES" ]; then
    truncated=$((truncated + 1)); continue
  fi
  total=$((total + 1))

  if [ "$ISOLATE" -eq 1 ]; then
    rm -rf "${PLUGIN_DIR:?}/skills"; mkdir -p "$PLUGIN_DIR/skills"
    install_skill "$skill" || {
      printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR skill not found"
      errored=$((errored + 1)); continue; }
  elif [ ! -r "$PLUGIN_DIR/skills/$skill/SKILL.md" ]; then
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR skill not found"
    errored=$((errored + 1)); continue
  fi

  # A user-invoked-only skill CANNOT auto-fire. Scoring such a case as a miss would blame the
  # description for a policy the frontmatter set on purpose. Codex/Copilot honour this key
  # differently, so the row is skipped with the reason named rather than folded into the totals.
  if [ "$expect" = "fire" ] &&
     [ "$(read_frontmatter_bool "$PLUGIN_DIR/skills/$skill/SKILL.md" "disable-model-invocation")" = "true" ]; then
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "n/a" "SKIP user-invoked only"
    skipped=$((skipped + 1)); continue
  fi

  # Numbered by position, NOT by $id. The id comes from cases.jsonl and an id containing `/`
  # would put these files outside $TMP; two cases sharing an id would silently overwrite each
  # other's transcript. Same class of defect as the skill-name check in install_skill — case data
  # never becomes a path fragment.
  stream="$TMP/stream.$total.jsonl"
  printf '%s' "$prompt" | (cd "$RUN_CWD" && "${RUNNER_CMD[@]}") > "$stream" 2>"$TMP/err.$total"

  if runner_failed "$stream"; then
    why=$(runner_error_reason "$stream")
    [ -n "$why" ] || why="runner produced no result event"
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR $why"
    errored=$((errored + 1)); continue
  fi

  won=$(fired_skill "$stream")

  # ACTUAL answers the SAME question EXPECT asks: did the TARGET skill fire? Reading it as "did
  # anything fire" produced rows that contradicted their own verdict — a quiet case that correctly
  # passed because another skill won printed `quiet fire PASS`, and the JSONL `actual` field told
  # downstream tooling the target had fired when it had not. Computed once here and reused by the
  # quiet branch below, so the transcript is parsed once and the column can never disagree with
  # the score. No information is lost: `winner` still names whoever took the turn.
  target_fired=1   # 1 = no, 0 = yes (shell truth)
  skill_ever_fired "$stream" "$PLUGIN_NAME:$skill" && target_fired=0
  actual="quiet"; [ "$target_fired" -eq 0 ] && actual="fire"

  if [ "$expect" = "fire" ]; then
    if [ "$won" = "$PLUGIN_NAME:$skill" ]; then
      verdict="PASS"; pass=$((pass + 1)); tp=$((tp + 1))
    elif [ -n "$won" ]; then
      verdict="FAIL collision — won by ${won#"$PLUGIN_NAME":}"; fail=$((fail + 1)); fn=$((fn + 1))
    else
      verdict="FAIL no skill fired"; fail=$((fail + 1)); fn=$((fn + 1))
    fi
  else
    # A quiet case asks "did the target stay out of this prompt entirely", which is NOT the same
    # question as "who won". Scoring it on $won alone reads the whole transcript through its first
    # tool call: a model that fires another skill first and the target second would score
    # `PASS (other skill fired: X)` while the target demonstrably did fire. That is a false pass in
    # the one direction this harness exists to refuse, so quiet is scored on the whole transcript.
    # The fire branch above keeps $won on purpose — there, losing to another skill IS the finding.
    if [ "$target_fired" -eq 0 ]; then
      verdict="FAIL fired when it should not"
      [ "$won" != "$PLUGIN_NAME:$skill" ] &&
        verdict="FAIL fired when it should not (after ${won#"$PLUGIN_NAME":} won the turn)"
      fail=$((fail + 1)); fp=$((fp + 1))
    else
      verdict="PASS"; pass=$((pass + 1)); tn=$((tn + 1))
      [ -n "$won" ] && verdict="PASS (other skill fired: ${won#"$PLUGIN_NAME":})"
    fi
  fi

  printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "$actual" "$verdict"
  [ -n "$JSONL_OUT" ] && jq -cn --arg id "$id" --arg skill "$skill" --arg expect "$expect" \
      --arg actual "$actual" --arg won "$won" --arg verdict "$verdict" --arg runner "$RUNNER" \
      '{id:$id,skill:$skill,expect:$expect,actual:$actual,winner:$won,verdict:$verdict,runner:$runner}' \
      >> "$JSONL_OUT"
done < "$CASES"

echo
if [ "$total" -eq 0 ]; then
  echo "SCANNED NOTHING: no usable case in '$CASES'. This is NOT a clean eval." >&2
  exit 2
fi

printf 'cases=%s  pass=%s  fail=%s  skipped=%s  err=%s\n' "$total" "$pass" "$fail" "$skipped" "$errored"
printf 'confusion: TP=%s (fired as intended)  FN=%s (missed trigger)  FP=%s (fired unbidden)  TN=%s (stayed quiet)\n' \
  "$tp" "$fn" "$fp" "$tn"
[ $((tp + fn)) -gt 0 ] && awk -v tp="$tp" -v fn="$fn" 'BEGIN{printf "recall    = %.2f  (of prompts that SHOULD fire it, how many did)\n", tp/(tp+fn)}'
[ $((tp + fp)) -gt 0 ] && awk -v tp="$tp" -v fp="$fp" 'BEGIN{printf "precision = %.2f  (of the times it fired, how many were wanted)\n", tp/(tp+fp)}'
[ "$truncated" -gt 0 ] && printf 'TRUNCATED: %s case(s) not run because --max-cases=%s. Coverage is partial.\n' \
  "$truncated" "$MAX_CASES"
[ "$RUNNER" = "mock" ] && echo 'RUNNER=mock: canned data. Valid for testing this script, NOT an audit result.'
[ "$errored" -gt 0 ] && echo "NOTE: $errored case(s) errored — those are unmeasured, not passes." >&2

[ "$fail" -eq 0 ] && [ "$errored" -eq 0 ] && exit 0
exit 1

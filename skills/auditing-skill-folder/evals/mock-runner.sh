#!/usr/bin/env sh
# Offline stand-in for the `claude` runner. Emits canned stream-json so tests/trigger-eval.sh can
# exercise the REAL parsing and scoring path in eval-triggers.sh with zero API calls and zero
# rate-limit spend — the same reason tests/description-lint.sh drives the real linter over fixture
# skills rather than reimplementing its regexes.
#
# Contract (kept deliberately narrow — this is a test double, not a simulator):
#   argv[1]  plugin dir (accepted and ignored; present so the command shape matches the real runner)
#   stdin    the prompt
#   $SKILLEVAL_MOCK_MAP  TSV: <prompt-substring> TAB <skill-name | "" | __NORESULT__>
#
# First matching row wins. No match => no skill fires (the honest default: a mock that invents a
# firing would make a missing fixture look like a passing case).
#   ""             -> no skill fires, normal result event
#   __NORESULT__   -> emit nothing at all, so the infrastructure-failure path can be tested
set -u

MAP="${SKILLEVAL_MOCK_MAP:-}"
prompt=$(cat)
fire=""

if [ -n "$MAP" ] && [ -r "$MAP" ]; then
  while IFS="$(printf '\t')" read -r pattern target; do
    [ -n "${pattern:-}" ] || continue
    case "$pattern" in \#*) continue ;; esac
    case "$prompt" in
      *"$pattern"*) fire="${target:-}"; break ;;
    esac
  done < "$MAP"
fi

[ "$fire" = "__NORESULT__" ] && exit 0

if [ -n "$fire" ]; then
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_mock","name":"Skill","input":{"skill":"skilleval:%s"}}]}}\n' "$fire"
fi
printf '{"type":"result","subtype":"success","is_error":false,"result":"mock"}\n'

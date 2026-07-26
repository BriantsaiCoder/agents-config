#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GATE="$ROOT/bin/pr-review-gate"
FAKEBIN=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-gate.XXXXXX")
REQUEST_LOG="$FAKEBIN/requests.log"
trap 'rm -rf "$FAKEBIN"' EXIT

cat > "$FAKEBIN/gh" <<'EOF'
#!/usr/bin/env bash
set -u

if [[ "$1 $2" == "repo view" ]]; then
  printf 'owner/repo\n'
elif [[ "$1 $2" == "pr view" ]]; then
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$FAKE_STATE" "$FAKE_DRAFT" "$FAKE_MERGEABLE" "$FAKE_HEAD" "$FAKE_CI" \
    "https://github.com/owner/repo/pull/42"
elif [[ "$1" == api && "$*" == *"/reviews"* ]]; then
  printf '%s\n' "$FAKE_REVIEW"
elif [[ "$1" == api && "$*" == *"/requested_reviewers"* && "$*" != *"--method POST"* ]]; then
  printf '%s\n' "$FAKE_REQUESTED"
elif [[ "$1 $2" == "api graphql" ]]; then
  filter=${!#}
  jq -nc --argjson count "$FAKE_UNRESOLVED" --argjson has_next "$FAKE_HAS_NEXT" '
    {data:{repository:{pullRequest:{reviewThreads:{
      nodes:[range(0; $count) | {
        isResolved:false,
        comments:{nodes:[{author:{login:"copilot-pull-request-reviewer[bot]"}}]}
      }],
      pageInfo:{hasNextPage:$has_next}
    }}}}}' | jq -r "$filter"
elif [[ "$1" == api && "$*" == *"--method POST"* ]]; then
  printf '%s\n' "$*" >> "$REQUEST_LOG"
  printf '{}\n'
else
  printf 'unexpected gh call: %s\n' "$*" >&2
  exit 99
fi
EOF
chmod +x "$FAKEBIN/gh"

pass=0
fail=0

probe() {
  local name="$1" want_rc="$2" want_state="$3" want_requests="$4"
  local review="$5" requested="$6" unresolved="$7" ci="$8"
  local draft="${9:-false}" has_next="${10:-false}" output rc request_count payload_ok=true

  : > "$REQUEST_LOG"
  output=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT="$draft" FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI="$ci" FAKE_REVIEW="$review" \
    FAKE_REQUESTED="$requested" FAKE_UNRESOLVED="$unresolved" \
    FAKE_HAS_NEXT="$has_next" "$GATE" 42 2>&1)
  rc=$?
  request_count=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
  if [[ "$want_requests" -gt 0 ]] &&
     ! grep -Fq 'reviewers[]=copilot-pull-request-reviewer[bot]' "$REQUEST_LOG"; then
    payload_ok=false
  fi

  if [[ "$rc" -eq "$want_rc" && "$output" == STATE="$want_state"* &&
        "$request_count" -eq "$want_requests" && "$payload_ok" == true ]]; then
    ((pass += 1))
    printf 'PASS %s\n' "$name"
  else
    ((fail += 1))
    printf 'FAIL %s: want_rc=%s want_state=%s want_requests=%s got_rc=%s got_requests=%s output=%s\n' \
      "$name" "$want_rc" "$want_state" "$want_requests" "$rc" "$request_count" "$output"
  fi
}

probe "current review passes"       0  PASS        0 head-new 0 0 SUCCESS
probe "stale review requests again" 11 REQUESTED   1 head-old 0 0 SUCCESS
probe "queued review is not doubled" 11 WAIT_REVIEW 0 head-old 1 0 SUCCESS
probe "unresolved thread blocks"    20 FINDINGS    0 head-new 0 2 SUCCESS
probe "pending CI waits"            10 WAIT_CI     0 head-new 0 0 PENDING
probe "missing CI waits"            10 WAIT_CI     0 head-new 0 0 NONE
probe "failed CI blocks"            30 FAIL_CI     0 head-new 0 0 FAILURE
probe "failure outranks pending CI" 30 FAIL_CI     0 head-new 0 0 FAILURE,PENDING
probe "draft PR waits"              11 WAIT_READY  0 head-new 0 0 SUCCESS true
probe "thread pagination fails safe" 30 UNAVAILABLE 0 head-new 0 0 SUCCESS false true

printf '%d PASS / %d FAIL\n' "$pass" "$fail"
((fail == 0))

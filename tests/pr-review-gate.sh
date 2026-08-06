#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GATE="$ROOT/bin/pr-review-gate"
FAKEBIN=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-gate.XXXXXX")
REQUEST_LOG="$FAKEBIN/requests.log"
trap 'rm -rf "$FAKEBIN"' EXIT

cat > "$FAKEBIN/gh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

if [[ "$1 $2" == "repo view" ]]; then
  # GH_FAKE_REPO_FAIL：模擬 repo 解析失敗，驗 unavailable() 在 repo 尚未賦值時的輸出。
  [[ -n "${GH_FAKE_REPO_FAIL:-}" ]] && exit 1
  printf 'owner/repo\n'
elif [[ "$1 $2" == "pr view" ]]; then
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$FAKE_STATE" "$FAKE_DRAFT" "$FAKE_MERGEABLE" "$FAKE_HEAD" "$FAKE_CI" \
    "https://github.com/owner/repo/pull/42"
elif [[ "$1" == api && "$*" == *"/commits/"* ]]; then
  # head commit 的時間，用來區分「CI 還在排程」與「run 根本沒被建立」。
  # FAKE_HEAD_DATE 留空模擬取不到時間——那時 gate 必須維持 WAIT（fail-closed）。
  [[ -z "$FAKE_HEAD_DATE" ]] && exit 1
  filter=${!#}
  jq -nc --arg d "$FAKE_HEAD_DATE" '{commit:{committer:{date:$d}}}' | jq -r "$filter"
elif [[ "$1" == api && "$*" == *"/reviews"* ]]; then
  filter=${!#}
  jq -nc --arg latest "$FAKE_REVIEW" '
    [
      {user:{login:"copilot-pull-request-reviewer[bot]"},commit_id:$latest,submitted_at:"2026-01-03T00:00:00Z"},
      {user:{login:"Copilot"},commit_id:"review-old",submitted_at:"2026-01-01T00:00:00Z"},
      {user:{login:"human"},commit_id:"human-head",submitted_at:"2026-01-04T00:00:00Z"}
    ]' | jq -r "$filter"
elif [[ "$1" == api && "$*" == *"/requested_reviewers"* && "$*" != *"--method POST"* ]]; then
  filter=${!#}
  jq -nc --argjson requested "$FAKE_REQUESTED" '
    {users:([{login:"human"}] +
      if $requested > 0 then [{login:"Copilot"}] else [] end),teams:[]}' |
    jq -r "$filter"
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
  # head commit 時間預設用「現在」，這樣既有的 CI=NONE 案例年齡是 0、仍走 WAIT。
  # 要測 ABSENT 就傳一個夠舊的日期進來，不必等真的過門檻。
  local head_date="${11:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

  : > "$REQUEST_LOG"
  output=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT="$draft" FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI="$ci" FAKE_REVIEW="$review" \
    FAKE_REQUESTED="$requested" FAKE_UNRESOLVED="$unresolved" \
    FAKE_HAS_NEXT="$has_next" FAKE_HEAD_DATE="$head_date" "$GATE" 42 2>&1)
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
# 零個 check 的兩種成因必須分開。前者 head 剛推上來（預設日期＝現在），run 可能還在排程；
# 後者 head 已經很舊，run 根本沒被建立——2026-08-06 實測撞過，舊版在此永遠卡住沒有出口。
probe "absent CI degrades"          12 PASS_NO_CI  0 head-new 0 0 NONE false false 2026-01-01T00:00:00Z
# 以下兩項是降級的 fail-closed 邊界：判不出年齡就不准降級。
# 取不到 head 時間（API 失敗）——不得因為「查不到」就當成過期。
probe "unknown head date waits"     10 WAIT_CI     0 head-new 0 0 NONE false false ""
# 時鐘偏移讓 head 落在未來，年齡是負數——同樣不得降級。
probe "future head date waits"      10 WAIT_CI     0 head-new 0 0 NONE false false 2099-01-01T00:00:00Z
probe "failed CI blocks"            30 FAIL_CI     0 head-new 0 0 FAILURE
probe "failure outranks pending CI" 30 FAIL_CI     0 head-new 0 0 FAILURE,PENDING
probe "draft PR waits"              11 WAIT_READY  0 head-new 0 0 SUCCESS true
probe "thread pagination fails safe" 30 UNAVAILABLE 0 head-new 0 0 SUCCESS false true

# UNAVAILABLE 行必須指名解析到的 repo。這支工具從 cwd 解析 repo，其餘 STATE 行都靠 url= 讓
# 「查錯 repo」看得出來，只有 UNAVAILABLE 兩者皆無——查錯 repo 與該 PR 真有問題會印出一模一樣
# 的一行。實測踩過兩次並誤判為暫時性失敗。
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=true "$GATE" 42 2>&1)
if [[ "$out" == *"repo=owner/repo"* ]]; then
  ((pass += 1)); printf 'PASS UNAVAILABLE names the resolved repo\n'
else
  ((fail += 1)); printf 'FAIL UNAVAILABLE names the resolved repo: output=%s\n' "$out"
fi

# repo 尚未解析出來時（repo_probe_failed）也不得印出空欄位——空的 repo= 會讀成「解析到空字串」
# 而不是「還沒解析」。
out=$(PATH="$FAKEBIN:$PATH" GH_FAKE_REPO_FAIL=1 "$GATE" 42 2>&1)
if [[ "$out" == *"repo=unresolved"* ]]; then
  ((pass += 1)); printf 'PASS repo probe failure says unresolved, not empty\n'
else
  ((fail += 1)); printf 'FAIL repo probe failure says unresolved, not empty: output=%s\n' "$out"
fi

printf '%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
((fail == 0))

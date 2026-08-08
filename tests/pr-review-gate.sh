#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GATE="$ROOT/bin/pr-review-gate"
# 本檔沒有 set -e：mktemp 失敗時 $FAKEBIN 為空，REQUEST_LOG 會變成 /requests.log。
FAKEBIN=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-gate.XXXXXX") ||
  { printf 'FAIL: 無法建立 fake bin 目錄，測試未執行\n' >&2; exit 1; }
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
elif [[ "$1" == api && "$*" == *"/jobs"* ]]; then
  # 被取消的 job 跑過幾個 step。0 代表 runner 拿到 job 卻從未開始執行。
  filter=${!#}
  jq -nc --argjson n "$FAKE_CANCELLED_STEPS" \
    '{jobs:[{steps:[range(0; $n) | {name:"step"}]}]}' | jq -r "$filter"
elif [[ "$1" == api && "$*" == *"head_sha="* ]]; then
  # head 上 conclusion=cancelled 的 run。留空模擬查不到——那時 gate 不得降級。
  filter=${!#}
  jq -nc --arg ids "$FAKE_CANCELLED_RUN_IDS" '
    {workflow_runs:
      ($ids | if . == "" then [] else split(",") end
        | map({id: (. | tonumber), conclusion: "cancelled"}))}' | jq -r "$filter"
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
  # 用 ${11-...} 而非 ${11:-...}：後者對空字串也套預設，於是「傳空字串模擬取不到時間」
  # 那項其實拿到的是現在時間，測的變成「未達門檻」——兩種 fail-closed 路徑混成一種。
  local head_date="${11-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  # 被取消的 run id 清單與其 job 跑過的 step 數。預設空清單＝查不到 cancelled run，
  # 那時 gate 不得降級，所以不傳這兩個參數的既有案例行為不變。
  local cancelled_ids="${12:-}" cancelled_steps="${13:-0}"

  : > "$REQUEST_LOG"
  output=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT="$draft" FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI="$ci" FAKE_REVIEW="$review" \
    FAKE_REQUESTED="$requested" FAKE_UNRESOLVED="$unresolved" \
    FAKE_HAS_NEXT="$has_next" FAKE_HEAD_DATE="$head_date" \
    FAKE_CANCELLED_RUN_IDS="$cancelled_ids" FAKE_CANCELLED_STEPS="$cancelled_steps" \
    "$GATE" 42 2>&1)
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

# CANCELLED 的六種形狀。分水嶺是「job 有沒有真的跑過 step」，不是「誰取消的」——
# GitHub 不提供取消者，但 steps 為空能區分「runner 拿到 job 卻沒開始」與「跑到一半被中斷」。
OLD=2026-01-01T00:00:00Z
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# runner 從未開始執行 + 等夠久 → 拿不到結論，降級。
probe "cancelled without steps degrades" 12 PASS_NO_CI 0 head-new 0 0 CANCELLED false false "$OLD" 900001 0
# 跑過 step 才被取消，可能中斷了一個正在失敗的測試——不必等門檻，直接擋死。
probe "cancelled after steps blocks"     30 FAIL_CI    0 head-new 0 0 CANCELLED false false "$OLD" 900001 3
# 從未執行但還沒等夠：這段時間內可能有人重跑。
probe "cancelled before threshold waits" 10 WAIT_CI    0 head-new 0 0 CANCELLED false false "$NOW" 900001 0
# 查不到 cancelled run（第三方 check、API 失敗）→ 無法確認，不降級。
probe "cancelled lookup failure blocks"  30 FAIL_CI    0 head-new 0 0 CANCELLED false false "$OLD" ""     0
# 還有 check 在跑就繼續等，即使同時有 CANCELLED——重跑後的新 run 正是這個形狀。
probe "cancelled with pending waits"     10 WAIT_CI    0 head-new 0 0 CANCELLED,PENDING false false "$OLD" 900001 0
# 硬失敗壓過一切，不因為旁邊有 CANCELLED 就降級。
probe "failure outranks cancelled"       30 FAIL_CI    0 head-new 0 0 CANCELLED,FAILURE false false "$OLD" 900001 0
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

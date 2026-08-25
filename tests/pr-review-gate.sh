#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GATE="$ROOT/bin/pr-review-gate"
# 本檔沒有 set -e：mktemp 失敗時 $FAKEBIN 為空，REQUEST_LOG 會變成 /requests.log。
FAKEBIN=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-gate.XXXXXX") ||
  { printf 'FAIL: 無法建立 fake bin 目錄，測試未執行\n' >&2; exit 1; }
REQUEST_LOG="$FAKEBIN/requests.log"
trap 'rm -rf "$FAKEBIN"' EXIT

# fake gh 以 fixture 檔複製而非 here-doc：here-doc 在 bash 3.2 一樣要建暫存檔（放 /tmp，
# 忽略 TMPDIR，理由見 tests/git-push-guard.sh 的切詞斷言區塊），/tmp 與 cwd 皆不可寫時
# redirect 失敗——而那正是本檔要驗的 sandbox 條件，測試搭建本身不該依賴它。
# （實測 0-byte gh 會讓套件大聲失敗而非假 PASS —— 不寫條數，那個數字每加一條案例就過期；cp 換掉的是
# 「在該條件下根本建不出 fake gh」這個相依，不是假綠風險。）
# 註：本套件的 mktemp 仍需要一個可寫的 TMPDIR；在 RED 條件下跑要自行指定。
cp "$ROOT/tests/fixtures/fake-gh" "$FAKEBIN/gh" ||
  { printf 'FAIL: 無法複製 fake gh fixture，測試未執行\n' >&2; exit 1; }
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
  local failure_job_id="${14:-}" failure_steps="${15:-0}" failure_annotation="${16:-}"
  local review_body="${17:-}"
  local failed_urls="${18:-}" annotation_fail="${19:-}" job_fail="${20:-}"
  local want_fragment="${21:-}" forbid_fragment="${22:-}" failure_conclusion="${23:-failure}"
  local failure_job_shape="${24:-valid}"
  if [[ -z "$failed_urls" ]]; then
    if [[ -n "$failure_job_id" ]]; then
      failed_urls="https://github.com/owner/repo/actions/runs/900002/job/$failure_job_id"
    else
      failed_urls=NONE
    fi
  fi

  : > "$REQUEST_LOG"
  output=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT="$draft" FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI="$ci" FAKE_FAILED_URLS="$failed_urls" FAKE_REVIEW="$review" \
    FAKE_REQUESTED="$requested" FAKE_UNRESOLVED="$unresolved" \
    FAKE_HAS_NEXT="$has_next" FAKE_HEAD_DATE="$head_date" \
    FAKE_CANCELLED_RUN_IDS="$cancelled_ids" FAKE_CANCELLED_STEPS="$cancelled_steps" \
    FAKE_FAILURE_STEPS="$failure_steps" FAKE_FAILURE_CONCLUSION="$failure_conclusion" \
    FAKE_FAILURE_ANNOTATION="$failure_annotation" FAKE_ANNOTATION_FAIL="$annotation_fail" \
    FAKE_JOB_FAIL="$job_fail" FAKE_JOB_SHAPE="$failure_job_shape" FAKE_REVIEW_BODY="$review_body" \
    "$GATE" 42 2>&1)
  rc=$?
  request_count=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
  if [[ "$want_requests" -gt 0 ]] &&
     ! grep -Fq 'reviewers[]=copilot-pull-request-reviewer[bot]' "$REQUEST_LOG"; then
    payload_ok=false
  fi

  if [[ "$rc" -eq "$want_rc" && "$output" == STATE="$want_state"* &&
        ( -z "$want_fragment" || "$output" == *"$want_fragment"* ) &&
        ( -z "$forbid_fragment" || "$output" != *"$forbid_fragment"* ) &&
        "$request_count" -eq "$want_requests" && "$payload_ok" == true ]]; then
    ((pass += 1))
    printf 'PASS %s\n' "$name"
  else
    ((fail += 1))
    printf 'FAIL %s: want_rc=%s want_state=%s want_requests=%s want_fragment=%s forbid_fragment=%s got_rc=%s got_requests=%s output=%s\n' \
      "$name" "$want_rc" "$want_state" "$want_requests" "$want_fragment" "$forbid_fragment" "$rc" "$request_count" "$output"
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
BILLING="The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings"
BILLING_REVIEW="The job was not started because recent GitHub Actions payments have failed or your spending limit needs to be increased."
probe "billing failure without steps degrades" 12 PASS_NO_CI 0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "ci=BILLING_QUOTA review=CURRENT" "STATE=PASS "
probe "non-billing zero-step failure blocks"   30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "runner assignment failed"
probe "billing failure after a step blocks"    30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 1 "$BILLING"
probe "single-clause near miss blocks"         30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "The job was not started because runner maintenance"
probe "payment-only near miss blocks"          30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "Recent account payments have failed or your spending limit needs to be increased."
probe "mixed external failure blocks"          30 FAIL_CI    0 head-new 0 0 FAILURE,ERROR false false "$NOW" "" 0 900002 0 "$BILLING" "" "https://github.com/owner/repo/actions/runs/900002/job/900002,https://checks.example/failure"
probe "external spoofed Actions URL blocks"    30 FAIL_CI    0 head-new 0 0 FAILURE,ERROR false false "$NOW" "" 0 900002 0 "$BILLING" "" "https://github.com/owner/repo/actions/runs/900002/job/900002,EXTERNAL:https://github.com/owner/repo/actions/runs/900002/job/900002"
probe "missing failure URL blocks"             30 FAIL_CI    0 head-new 0 0 FAILURE,ERROR false false "$NOW" "" 0 900002 0 "$BILLING" "" "https://github.com/owner/repo/actions/runs/900002/job/900002,MISSING"
probe "empty failure URL field blocks"         30 FAIL_CI    0 head-new 0 0 FAILURE,ERROR false false "$NOW" "" 0 900002 0 "$BILLING" "" "https://github.com/owner/repo/actions/runs/900002/job/900002,"
probe "annotation query failure blocks"        30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" 1
probe "job query failure blocks"               30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" 1
probe "non-failure job conclusion blocks"      30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" success
probe "missing steps schema blocks"            30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" failure missing_steps
probe "null steps schema blocks"               30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" failure null_steps
probe "missing conclusion schema blocks"       30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" failure missing_conclusion
probe "stale-head job blocks"                  30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" failure stale_head
probe "mismatched-run job blocks"              30 FAIL_CI    0 head-new 0 0 FAILURE false false "$NOW" "" 0 900002 0 "$BILLING" "" "" "" "" "" "" failure mismatched_run
probe "billing body is not a code review"      30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_REVIEW" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
# issue #94 的三種已知漂移：舊的「整段 ==」判準對這三種全部落 STATE=PASS
# （一則 billing 通知被當成通過的 code review）。錨在穩定核心之後三種都要落 UNAVAILABLE。
BILLING_DRIFT_WORD="The job was not started because recent GitHub Actions payment have failed or your spending limit needs to be increased."
BILLING_DRIFT_PHRASE="The job was not started because recent GitHub Actions payments have failed or your spending limit must be increased."
BILLING_DRIFT_SPACE="$BILLING_REVIEW "
# 這兩條是 `map(select(. != ""))` 版本的實際觸發點：CRLF 切開後的孤立 "\r" 與全空白行
# 都不是空字串，會被算成第二行 -> 判成「不是 billing」-> STATE=PASS。
BILLING_DRIFT_CRLF="$(printf '%s\r\n\r\n' "$BILLING_REVIEW")"
BILLING_DRIFT_WSLINE="$(printf '%s\n   \n' "$BILLING_REVIEW")"
MIXED_REVIEW="$BILLING_REVIEW"$'\nissue: real finding'
probe "mixed review body remains current"       0 PASS 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$MIXED_REVIEW" "" "" "" "review=CURRENT" "STATE=UNAVAILABLE"
probe "billing drift (payments->payment) is still billing"  30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_DRIFT_WORD" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
probe "billing drift (needs to->must) is still billing"     30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_DRIFT_PHRASE" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
probe "billing drift (trailing space) is still billing"     30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_DRIFT_SPACE" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
probe "billing drift (CRLF blank line) is still billing"    30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_DRIFT_CRLF" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
probe "billing drift (whitespace line) is still billing"    30 UNAVAILABLE 0 head-new 0 0 SUCCESS false false "$NOW" "" 0 "" 0 "" "$BILLING_DRIFT_WSLINE" "" "" "" "reason=review_actions_billing_or_quota" "review=CURRENT"
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

# ── 欄位切不出來時要指名真因，不能落到假原因或印出半空的 STATE 行 ──────────
#
# 這三條釘住的失效形狀，改用 cut 取欄位之後才有辦法區分：從前 here-string 的 read
# 整組不執行、變數維持 unset，set -u 讓整支中止在「state: unbound variable」，
# 看不出是 gh／jq 的輸出變了。
#
# GH_FAKE_PR_TSV 讓 pr view 直接吐指定字串，繞過正常的 @tsv 組裝。
out=$(PATH="$FAKEBIN:$PATH" GH_FAKE_PR_TSV="" "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 空 tsv 報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 空 tsv 報 pr_fields_unparsable: output=%s\n' "$out"
fi

# 最可能的變體：jq 改欄位數而第一欄仍在。舊 guard 只驗 state，於是 head 為空仍印
# STATE=PASS——而 hard_deny[1] 整條規則綁在 "at the current head SHA"。
out=$(PATH="$FAKEBIN:$PATH" GH_FAKE_PR_TSV="OPEN	false	MERGEABLE" "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 欄位數不足（head 缺）報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 欄位數不足（head 缺）報 pr_fields_unparsable: output=%s\n' "$out"
fi

# 逐欄隔離。上面兩條讓多個欄位同時為空，紅的原因未必是被測的那一欄；下面三條各只
# 挖掉一欄，才釘得住 guard 真的驗了它。mergeable 那條是 round 2 補的核心：它把關
# `mergeable == CONFLICTING` 與 `mergeable == UNKNOWN` 兩個決策，空字串兩條都不命中而直落 STATE=PASS
# —— 合併衝突檢查沒跑，輸出行卻外觀正常。
out=$(PATH="$FAKEBIN:$PATH" \
  GH_FAKE_PR_TSV="OPEN	false		head-new	SUCCESS	NONE	https://example.invalid/pull/42" \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 僅 mergeable 為空報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 僅 mergeable 為空報 pr_fields_unparsable: output=%s\n' "$out"
fi

out=$(PATH="$FAKEBIN:$PATH" \
  GH_FAKE_PR_TSV="OPEN	false	MERGEABLE	head-new	SUCCESS	NONE	" \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 僅 url 為空報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 僅 url 為空報 pr_fields_unparsable: output=%s\n' "$out"
fi

out=$(PATH="$FAKEBIN:$PATH" \
  GH_FAKE_PR_TSV="OPEN	false	MERGEABLE		SUCCESS	NONE	https://example.invalid/pull/42" \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 僅 head 為空報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 僅 head 為空報 pr_fields_unparsable: output=%s\n' "$out"
fi

out=$(PATH="$FAKEBIN:$PATH" \
  GH_FAKE_PR_TSV="	false	MERGEABLE	head-new	SUCCESS	NONE	https://example.invalid/pull/42" \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS 僅 state 為空報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL 僅 state 為空報 pr_fields_unparsable: output=%s\n' "$out"
fi

# draft 必須驗正值：`.isDraft | tostring` 讓 null 變字面 "null"，非空檢查放行，而
# "null" 不等於 true → draft PR 被當成非 draft 走到 STATE=PASS。fail-open，hard_deny[1]
# 只認 PASS／PASS_NO_CI，所以這是唯一一條能真的突破 merge gate 的欄位退化。
out=$(PATH="$FAKEBIN:$PATH" \
  GH_FAKE_PR_TSV="OPEN	null	MERGEABLE	head-new	SUCCESS	NONE	https://example.invalid/pull/42" \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS draft 非 true/false 報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL draft 非 true/false 報 pr_fields_unparsable: output=%s\n' "$out"
fi

# pr tsv 整行無分隔符：cut -fN 每個 N 都回整行，七個欄位全部非空，逐欄檢查全數通過。
# 額外斷言 0 次外部請求——這個形狀曾經走到 STATE=WAIT_CI 並送出 requested_reviewers POST，
# 垃圾輸入不該產生外部寫入。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  GH_FAKE_PR_TSV="OPEN" "$GATE" 42 2>&1)
req=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
if [[ "$out" == *"reason=pr_fields_unparsable"* && "$req" -eq 0 ]]; then
  ((pass += 1)); printf 'PASS pr tsv 無分隔符報 pr_fields_unparsable 且零外部請求\n'
else
  ((fail += 1)); printf 'FAIL pr tsv 無分隔符報 pr_fields_unparsable 且零外部請求: output=%s requests=%s\n' "$out" "$req"
fi

# 整行是字面 false／true 時 draft 的正值檢查會通過（每欄都拿到 "false"），要靠 tab 數
# 檢查才報得出真原因；沒有它會落到 pr_not_open——仍 fail-closed，但那正是本分支要修掉
# 的「報假原因」形狀。這條與下一條是該 conjunct 的鑑別點。
out=$(PATH="$FAKEBIN:$PATH" GH_FAKE_PR_TSV="false" "$GATE" 42 2>&1)
if [[ "$out" == *"reason=pr_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS pr tsv 整行為字面 false 報 pr_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL pr tsv 整行為字面 false 報 pr_fields_unparsable: output=%s\n' "$out"
fi

# 欄位插入：八欄時每個 -n 都拿得到非空值、draft 仍是 false，逐欄檢查全數通過。
# S5 實測部分插入位置會走到 STATE=PASS（head 與 ci 仍是真值，污染落在 url），
# 另一些位置走到 WAIT_CI 並送出一次 POST。tab 數檢查一次涵蓋。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  GH_FAKE_PR_TSV="OPEN	false	EXTRA	MERGEABLE	head-new	SUCCESS	NONE	https://example.invalid/pull/42" \
  "$GATE" 42 2>&1)
req=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
if [[ "$out" == *"reason=pr_fields_unparsable"* && "$req" -eq 0 ]]; then
  ((pass += 1)); printf 'PASS pr tsv 多一欄報 pr_fields_unparsable 且零外部請求\n'
else
  ((fail += 1)); printf 'FAIL pr tsv 多一欄報 pr_fields_unparsable 且零外部請求: output=%s requests=%s\n' "$out" "$req"
fi

# thread tsv 無分隔符：cut -fN 對整行無分隔符的輸入每個 N 都回整行，於是 unresolved
# 與 has_next 同時變成 "false"，has_next 檢查放行，接著 [[ "$unresolved" -gt 0 ]] 在
# 算術脈絡把 false 當變數名 → set -u 中止，而 bash 3.2 從 [[ ]] 算術脈絡觸發的中止
# **exit status 是 0**、stdout 全空。這支工具最不能有的形狀。
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  GH_FAKE_THREAD_TSV="false" "$GATE" 42 2>&1)
if [[ "$out" == *"reason=thread_fields_unparsable"* ]]; then
  ((pass += 1)); printf 'PASS thread tsv 無分隔符報 thread_fields_unparsable\n'
else
  ((fail += 1)); printf 'FAIL thread tsv 無分隔符報 thread_fields_unparsable: output=%s\n' "$out"
fi

# 上面那條數值 guard 擋不住的兩個形狀：純數字（unresolved 通過數值檢查、has_next 也是
# 該數字）與第二欄為空。兩者原本都報 review_thread_limit_exceeded 這個假原因。
thread_shape_probe() { # $1=名稱 $2=tsv
  local name="$1" tsv="$2" out
  out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    GH_FAKE_THREAD_TSV="$tsv" "$GATE" 42 2>&1)
  if [[ "$out" == *"reason=thread_fields_unparsable"* ]]; then
    ((pass += 1)); printf 'PASS %s\n' "$name"
  else
    ((fail += 1)); printf 'FAIL %s: output=%s\n' "$name" "$out"
  fi
}
thread_shape_probe 'thread tsv 純數字報 thread_fields_unparsable' '5'
thread_shape_probe 'thread tsv has_next 為空報 thread_fields_unparsable' '0	'
# thread 原本沒有 arity conjunct（見 bin/pr-review-gate 的 tab_count() 不變式）：同一個
# 「多一欄」形狀在 review 擋得住、在這裡卻每一欄檢查都通過而直落 rc=0 STATE=PASS，而
# hard_deny[1] 只認 PASS／PASS_NO_CI。與 pr、review、job 補的是同一個洞——列名而不列數，
# 站點的完整性由 tab_count() 的不變式斷言守。
thread_shape_probe 'thread tsv 多一欄報 thread_fields_unparsable' '0	false	EXTRA'
thread_shape_probe 'thread tsv 多兩欄報 thread_fields_unparsable' '0	false	EXTRA	MORE'

# ── review tsv 與 requested：99eb2fc 與 2cac0b0 補上 guard 的兩個 ────────────
#
# review tsv 無分隔符時 cut -fN 每個 N 都回整行，於是 latest_review 拿到整行。整行只要
# 不等於 head 就走 review=STALE，而該分支會對 GitHub 送出一次 requested_reviewers POST
# ——垃圾輸入產生外部寫入，與上面 pr tsv 那條同型，只是載具換成 review 端。
# 同一形狀下 suppressed 也拿到整行，舊版靜默改判為 0：2026-08-08 那類「六條 finding 有
# 四條在 Suppressed 摺疊區、gate 仍回 PASS」的 fail-open 會再次無聲成立。
review_shape_probe() { # $1=名稱 $2=tsv
  local name="$1" tsv="$2" out req
  : > "$REQUEST_LOG"
  out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    GH_FAKE_REVIEW_TSV="$tsv" "$GATE" 42 2>&1)
  req=$(wc -l < "$REQUEST_LOG" | tr -d ' ')
  if [[ "$out" == *"reason=review_fields_unparsable"* && "$req" -eq 0 ]]; then
    ((pass += 1)); printf 'PASS %s\n' "$name"
  else
    ((fail += 1)); printf 'FAIL %s: output=%s requests=%s\n' "$name" "$out" "$req"
  fi
}
# 整行不等於 head 是關鍵：等於 head 會走 review=CURRENT 而看不到 POST 那條路徑。
review_shape_probe 'review tsv 無分隔符報 review_fields_unparsable 且零外部請求' 'review-old'
review_shape_probe 'review tsv 多一欄報 review_fields_unparsable' 'head-new	0	false	EXTRA'
review_shape_probe 'review tsv billing 非 true/false 報 review_fields_unparsable' 'head-new	0	null'
review_shape_probe 'review tsv suppressed 非數字報 review_fields_unparsable' 'head-new	abc	false'
# suppressed 只被 printf 消費、不進算術，所以前導零沒有 fail-open 後果——但它與同檔
# 每一個進算術脈絡的值共用同一條嚴格 regex，這條 canary 讓「為什麼這裡也要嚴格」有
# 東西釘住。（不寫「另外 N 處」：站點的完整性由 tab_count() 的不變式斷言守，不由這裡的數字。）
review_shape_probe 'review tsv suppressed 前導零報 review_fields_unparsable' 'head-new	08	false'
# latest_review 為空是合法輸入（jq 的 `.commit_id // ""`，代表這個 PR 還沒有任何
# Copilot review），不得誤擋——這條是上面四條的極性反例。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  GH_FAKE_REVIEW_TSV="	0	false" "$GATE" 42 2>&1)
if [[ "$out" == STATE=REQUESTED* ]]; then
  ((pass += 1)); printf 'PASS 尚無 Copilot review（首欄為空）不被誤判為欄位壞掉\n'
else
  ((fail += 1)); printf 'FAIL 尚無 Copilot review（首欄為空）不被誤判為欄位壞掉: output=%s\n' "$out"
fi

# requested 沒有數值 guard。非數字值進 [[ ]] 算術脈絡撞 set -u，而 bash 3.2 由該脈絡
# 觸發的中止 **exit status 是 0**、stdout 全空——呼叫端比對 STATE= 拿到空字串，只看
# exit code 的當成通過。可達性低（jq 的 length 恆為數字），但形狀與 thread 那條相同。
requested_raw_probe() { # $1=名稱 $2=raw 值
  local name="$1" raw="$2" out
  : > "$REQUEST_LOG"
  out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    GH_FAKE_REQUESTED_RAW="$raw" "$GATE" 42 2>&1)
  if [[ "$out" == *"reason=requested_not_numeric"* ]]; then
    ((pass += 1)); printf 'PASS %s\n' "$name"
  else
    ((fail += 1)); printf 'FAIL %s: output=%s\n' "$name" "$out"
  fi
}
requested_raw_probe 'requested 非數字報 requested_not_numeric' 'abc'

# CI_ABSENT_AFTER 由環境進入 (( )) 算術脈絡，同樣沒有數值 guard，同樣是 rc=0 stdout 全空
# 那個形狀。它是唯一來源為環境變數的一個，所以也是唯一使用者自己 export 一個打錯的值
# 就能踩到的；其餘同型的值都來自 gh API。
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" CI_ABSENT_AFTER=abc \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=NONE FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  FAKE_HEAD_DATE=2026-01-01T00:00:00Z FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=ci_absent_after_not_numeric"* ]]; then
  ((pass += 1)); printf 'PASS CI_ABSENT_AFTER 非數字報 ci_absent_after_not_numeric\n'
else
  ((fail += 1)); printf 'FAIL CI_ABSENT_AFTER 非數字報 ci_absent_after_not_numeric: output=%s\n' "$out"
fi

# 極性反例，釘住 guard 的位置而不只是它的存在：CI 全綠時 past_threshold() 根本不會被
# 呼叫，CI_ABSENT_AFTER 也就不會被讀取，此時一個打錯的值不得擋掉這個 PR。少了這條，
# guard 會無聲飄回定義處，而那會讓一個 typo 擋掉每一個 PR（含 CI 全綠的）。
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" CI_ABSENT_AFTER=abc \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  "$GATE" 42 2>&1)
if [[ "$out" == STATE=PASS* ]]; then
  ((pass += 1)); printf 'PASS CI_ABSENT_AFTER 用不到時不得擋（guard 收斂在使用點）\n'
else
  ((fail += 1)); printf 'FAIL CI_ABSENT_AFTER 用不到時不得擋: output=%s\n' "$out"
fi

# ── 第二輪審查：前導零、job tsv 的 arity、pre-1970 epoch ─────────────────────
#
# ^[0-9]+$ 只驗「長得像數字」，不驗「進 bash 算術後還是同一個數」。CI_ABSENT_AFTER、
# requested、unresolved 三個會中，且在 main 上行為相同——這個分支新增的 guard 原本也沒
# 關掉它們。past_threshold 內的 e 打不中，但**理由不是分類**：它同樣進算術脈絡、同樣由
# 外部資料驅動（epoch_of 用 date 從 gh 回的字串算出來），任何分類標籤都會把它一起圈進來。
# 打不中的理由是形式——date 產出的 epoch 不會有前導零，所以它沒有對應 canary。

# 使用者今天 export 一個打錯的值就能踩到：(( )) 把 0600 讀成八進位 384，門檻由 600 秒
# 腰斬成 384 秒，PASS_NO_CI 提早成立，而 hard_deny[1] 認這個狀態。
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" CI_ABSENT_AFTER=0600 \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=NONE FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  FAKE_HEAD_DATE=2026-01-01T00:00:00Z FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
  "$GATE" 42 2>&1)
if [[ "$out" == *"reason=ci_absent_after_not_numeric"* ]]; then
  ((pass += 1)); printf 'PASS CI_ABSENT_AFTER 前導零報 ci_absent_after_not_numeric\n'
else
  ((fail += 1)); printf 'FAIL CI_ABSENT_AFTER 前導零報 ci_absent_after_not_numeric: output=%s\n' "$out"
fi

# 08／09 在 [[ ]] 算術是**錯誤**不是 false，而 [[ ]] 回非零與「條件不成立」無法區分——
# 這裡「不成立」正好是 fail-open 那一側：8 條未解 finding 直落 STATE=PASS。
thread_shape_probe 'thread tsv 前導零報 thread_fields_unparsable' '08	false'
requested_raw_probe 'requested 前導零報 requested_not_numeric' '08'

# job 端的 tsv 解析（billing_failure_never_ran）。多一欄時四項檢查全過 →
# return 0 → BILLING_QUOTA → PASS_NO_CI，與 review／thread 修掉的是同一個形狀。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=FAILURE FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    FAKE_HEAD_DATE="$NOW" FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
    FAKE_FAILURE_STEPS=0 FAKE_FAILURE_ANNOTATION="$BILLING" \
    FAKE_FAILED_URLS="https://github.com/owner/repo/actions/runs/900002/job/900002" \
  GH_FAKE_JOB_TSV="failure	0	head-new	900002	EXTRA" "$GATE" 42 2>&1)
if [[ "$out" == STATE=FAIL_CI* ]]; then
  ((pass += 1)); printf 'PASS job tsv 多一欄不得降級成 PASS_NO_CI\n'
else
  ((fail += 1)); printf 'FAIL job tsv 多一欄不得降級成 PASS_NO_CI: output=%s\n' "$out"
fi

# 極性反例：欄數正確時仍須降級——否則一個**恆假**的 guard（arity conjunct 永遠不成立，
# 於是每個 job 都 return 1）會讓上一條「多一欄不得降級」假綠通過。
# 實測把 conjunct 改成 -eq 99：本條與既有的「billing failure without steps degrades」
# 同時轉紅——本條不是唯一守護，它獨佔釘住的是 raw-TSV fixture 這條路徑。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=FAILURE FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    FAKE_HEAD_DATE="$NOW" FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
    FAKE_FAILURE_STEPS=0 FAKE_FAILURE_ANNOTATION="$BILLING" \
    FAKE_FAILED_URLS="https://github.com/owner/repo/actions/runs/900002/job/900002" \
  GH_FAKE_JOB_TSV="failure	0	head-new	900002" "$GATE" 42 2>&1)
if [[ "$out" == STATE=PASS_NO_CI* ]]; then
  ((pass += 1)); printf 'PASS job tsv 欄數正確時仍降級成 PASS_NO_CI\n'
else
  ((fail += 1)); printf 'FAIL job tsv 欄數正確時仍降級成 PASS_NO_CI: output=%s\n' "$out"
fi

# past_threshold 內 e 的數值檢查有可鑑別的 canary：epoch_of 對 pre-1970 的 committer
# date 會成功並回負數（1960-01-01 → -315619200，rc=0）。舊的 -n 檢查放行，年齡被算成
# 超過三十億秒 → past_threshold 為真 → 零 check 的 PR 直接降級成 PASS_NO_CI。
: > "$REQUEST_LOG"
out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
  FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
  FAKE_HEAD=head-new FAKE_CI=NONE FAKE_FAILED_URLS=NONE FAKE_REVIEW=head-new \
  FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
  FAKE_HEAD_DATE=1960-01-01T00:00:00Z FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
  "$GATE" 42 2>&1)
if [[ "$out" == STATE=WAIT_CI* ]]; then
  ((pass += 1)); printf 'PASS pre-1970 committer date 不得降級成 PASS_NO_CI\n'
else
  ((fail += 1)); printf 'FAIL pre-1970 committer date 不得降級成 PASS_NO_CI: output=%s\n' "$out"
fi

# ── suppressed comments 必須出現在 PASS 那行 ────────────────────────────────
#
# Copilot 會把部分 finding 收進 review body 的 "Suppressed comments" 摺疊區，那些
# **不會**產生 review thread，因此不計入 unresolved。2026-08-08 一輪跨四 repo 的守衛
# 修正中，六條 finding 有四條在該區塊，而 gate 在同一輪回過三次 STATE=PASS——每次都
# 有未修的 fail-open。這兩條釘死「數字要出現在那行輸出上」。
#
# 不驗「suppressed>0 就 block」：suppressed 沒有 resolve 機制，拿它當 blocking 條件
# 會變成永久死鎖。呈報 + review-triage 的人工閱讀義務才是這裡的契約。
suppressed_probe() { # $1=名稱 $2=review body $3=期望的 suppressed 值
  local name="$1" body="$2" want="$3" out
  out=$(PATH="$FAKEBIN:$PATH" REQUEST_LOG="$REQUEST_LOG" \
    FAKE_STATE=OPEN FAKE_DRAFT=false FAKE_MERGEABLE=MERGEABLE \
    FAKE_HEAD=head-new FAKE_CI=SUCCESS FAKE_REVIEW=head-new \
    FAKE_REQUESTED=0 FAKE_UNRESOLVED=0 FAKE_HAS_NEXT=false \
    FAKE_HEAD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    FAKE_CANCELLED_RUN_IDS="" FAKE_CANCELLED_STEPS=0 \
    FAKE_REVIEW_BODY="$body" "$GATE" 42 2>&1)
  if [[ "$out" == *"suppressed=$want"* ]]; then
    ((pass += 1)); printf 'PASS %s\n' "$name"
  else
    ((fail += 1)); printf 'FAIL %s: want suppressed=%s output=%s\n' "$name" "$want" "$out"
  fi
}
suppressed_probe "無 suppressed 區塊時報 0" "看起來一切正常的 review body" 0
suppressed_probe "有 suppressed 區塊時報實際數量" \
  '## Pull request overview

<details>
<summary>Suppressed comments (2)</summary>

**a.sh:1**
* something
</details>' 2

# ── 切詞路徑不得依賴暫存檔 redirect ────────────────────────────────────────
#
# 本分支的整個前提是「bash 3.2 的 <<< 要建暫存檔，/tmp 與 cwd 皆不可寫時建不出來」。
# 上面所有行為案例在 /tmp 可寫的環境（Linux CI、一般 macOS shell）對修正前的版本
# **全部仍然 PASS** —— 實測把 cut 那段還原成 here-string，行為案例全數維持綠，只有下面
# 這條靜態斷言轉紅。所以行為案例擋
# 不住復發，需要一條到哪都成立的靜態斷言。
#
# 作法沿用 tests/git-push-guard.sh 的切詞斷言區塊（2026-08-08 為 guard-git-push.sh
# 解過同一個問題），連同它記載過的三個坑：pattern 不對 delimiter 字元集合做假設
# （`<<1`、`<<=EOF`、`<< =` 都是合法 here-doc）；檔名前的 `--` 不可省；兩個 grep 拆開
# 跑並分辨 rc>=2，否則「掃不到就當乾淨」的假綠會回來。
# 只掃非註解行，否則本區塊自己的說明會讓它恆紅。而掃描名單含本檔自己（測試側的
# here-doc 正是這次要修掉的那個），所以 pattern 用兩個單字元拼出來——直接寫字面
# 的話，這一行本身就會被自己命中。
_hd=$(printf '<')
_pat="${_hd}${_hd}-?[[:space:]]*[^[:space:]]"
for _f in "$GATE" "$ROOT/tests/pr-review-gate.sh" "$ROOT/tests/fixtures/fake-gh"; do
  _src=""; _hits=""; _rc=0; _hits_rc=0
  _src="$(grep -vE '^[[:space:]]*#' -- "$_f")" || _rc=$?
  if [ "$_rc" -ge 2 ]; then
    ((fail += 1)); printf 'FAIL 靜態掃描讀不到內容（grep rc=%s）：%s\n' "$_rc" "$_f"
    continue
  fi
  # rc 三態不夠：本機 grep 是 ugrep，撞 sandbox 權限時會**靜默回零命中且 exit 0**。
  # S5 實測用一支「exit 0 無輸出」的 grep 替身，三條斷言全數假 PASS。這三個檔都是
  # 數百行的 shell，不可能整檔皆註解，空輸出必為工具失敗。
  if [ -z "$_src" ]; then
    ((fail += 1)); printf 'FAIL 靜態掃描回空輸出（grep 工具失敗，非檔案乾淨）：%s\n' "$_f"
    continue
  fi
  _hits="$(printf '%s\n' "$_src" | grep -E -- "$_pat")" || _hits_rc=$?
  if [ "$_hits_rc" -ge 2 ]; then
    ((fail += 1)); printf 'FAIL 靜態掃描自身失敗（grep rc=%s）：%s\n' "$_hits_rc" "$_f"
  elif [ -z "$_hits" ]; then
    ((pass += 1)); printf 'PASS 不依賴暫存檔 redirect：%s\n' "${_f#"$ROOT"/}"
  else
    ((fail += 1)); printf 'FAIL 仍有 here-doc／here-string（/tmp 與 cwd 皆不可寫時會失效）：%s\n' "${_f#"$ROOT"/}"
    printf '%s\n' "$_hits" | head -3 | sed 's/^/       /'
  fi
done

# ── tsv arity 不變式：每一處 tsv 解析都要有 tab_count 的 arity 檢查 ──────
#
# bin/pr-review-gate 的 tab_count() 宣告了這條不變式。散文計數在這支腳本上反覆寫歪過
# （歷史見 PR #85 的 commit 序列），每次都是「以為盤點完了而停止尋找」，所以判準下沉到
# 這裡（規則 9）。
#
# **比的是集合，不是總數。** 第一版比兩個計數，R4 審查用 ablation 打穿了它：拿掉 job
# 端的 arity conjunct、同時在 pr_state 上補一個多餘的 tab_count，兩邊總數仍相等而斷言
# 綠燈，但 job tsv 多一欄 → PASS_NO_CI 的 fail-open 真的復發。總數相等是比宣告弱一階
# 的不變式。改成從兩側各抽出**變數名**再逐一對照，站點錯配就轉紅。
#
# 解析點那側抽的是 `printf … "$X" | cut -f`，**不限第幾欄**——某處改成只切第 2、3 欄
# 一樣會被抽進來，所以那個形狀由前兩個檢查涵蓋。
#
# 第三個檢查（producer 數 == 解析點數）守的是另一個形狀：jq 產出了 tsv，卻**完全沒有
# 走 cut 這條路徑**去解析它（改用 read、awk，或整段被別的寫法取代）。那時前兩個集合
# 各自仍自洽，只有 producer 與解析點的數目對不上。兩者是 1:1，對不上就是有東西漂移了。
#
# **零 magic number。** 沒有任何一邊跟字面值比——那正是本區塊在消滅的東西。工具失敗
# 靠「剝掉註解後整檔為空」判別，沿用同檔上方 here-doc 掃描區塊已驗證過的機制：本機
# grep 是 ugrep，撞 sandbox 權限時會靜默回零命中且 exit 0，而它回的是**空字串不是 0**，
# 拿空字串去比大小會讓 [ ] 報 integer expression expected 並落進錯誤的分支。
#
# 先剝**整行**註解，沿用該區塊的作法：bin/pr-review-gate 的整行註解本來就寫過 cut -fN、
# cut -f3，哪天寫到 cut -f1 就會灌爆解析點那側而假紅。行尾註解不在剝除範圍內——真在
# 程式碼後面寫一個 cut -f 的例子會假紅，方向是 fail-closed，實測確認過。
_s_rc=0
_src="$(grep -vE '^[[:space:]]*#' -- "$GATE")" || _s_rc=$?
if [ "$_s_rc" -ge 2 ] || [ -z "$_src" ]; then
  ((fail += 1)); printf 'FAIL arity 不變式：掃描讀不到內容（grep rc=%s，工具失敗而非程式碼變更）\n' "$_s_rc"
else
  # 空白一律寫成 [[:space:]]*：這個斷言問的是「解析點有沒有對應 guard」，不該因為有人
  # 調整排版就整套假紅。producer 那側同理，用 [|][[:space:]]*@tsv 而非 fixed-string。
  _parsed="$(printf '%s\n' "$_src" | grep -oE 'printf[[:space:]]+.%s.[[:space:]]+"[$][a-z_]+"[[:space:]]*[|][[:space:]]*cut[[:space:]]+-f' | grep -oE '[$][a-z_]+' | sort -u)"
  # guard 那側要求 tab_count 的結果後面接 -eq：只做「有沒有提到 tab_count」的文字比對時，
  # 一行 debug printf 也會算成有 guard（實測：新增解析點 + 一行 printf 'dbg %s' 引用它，
  # 斷言照樣綠）。接 -eq 才是真的拿它去比對欄數。
  _guarded="$(printf '%s\n' "$_src" | grep -oE 'tab_count[[:space:]]+"[$][a-z_]+"\)"[[:space:]]*-eq' | grep -oE '[$][a-z_]+' | sort -u)"
  _prod_n="$(printf '%s\n' "$_src" | grep -cE -- '[|][[:space:]]*@tsv')"
  _parsed_n="$(printf '%s\n' "$_parsed" | grep -c . )"
  # 兩個計數在比較前先驗形狀。改成 != 只解掉「報 integer expression expected」那半，
  # 兩個空字串仍然相等而落進 PASS——實測用一支只讓 grep -c 回空的替身，套件整套全綠（`d53390d`）。
  # 這是本區塊自己在守的那個形狀（工具失敗被印成通過），所以判別要在比較之前。
  _counts_ok=yes
  case "$_prod_n$_parsed_n" in ''|*[!0-9]*) _counts_ok=no ;; esac
  if [ "$_counts_ok" = no ]; then
    ((fail += 1)); printf 'FAIL arity 不變式：計數非數字（grep 工具失敗，非程式碼變更）：producer=%s 解析點=%s\n' "$_prod_n" "$_parsed_n"
  elif [ -z "$_parsed" ]; then
    ((fail += 1)); printf 'FAIL arity 不變式：抽不出任何 tsv 解析點（pattern 已與實作脫節）\n'
  elif [ "$_parsed" != "$_guarded" ]; then
    ((fail += 1)); printf 'FAIL tsv 解析點與 arity 檢查的集合不一致\n'
    printf '       解析：%s\n' "$(printf '%s' "$_parsed" | tr '\n' ' ')"
    printf '       守護：%s\n' "$(printf '%s' "$_guarded" | tr '\n' ' ')"
  # 用 != 而非 -ne：兩邊都是 grep -c 產出的十進位字串，語意等價但不進算術脈絡。
  # -ne 在 grep 被替身掉、回空字串時會報 integer expression expected 並落進 else，
  # 於是工具失敗被印成 PASS（實測 76/0、exit 0）——正是本區塊上方註解警告的那個形狀。
  elif [ "$_prod_n" != "$_parsed_n" ]; then
    ((fail += 1)); printf 'FAIL tsv producer 數與解析點數不符（producer 未被 cut 解析，或抽取 pattern 已漂移）：producer=%s 解析點=%s\n' "$_prod_n" "$_parsed_n"
  else
    ((pass += 1)); printf 'PASS 每處 tsv 解析都有 arity 檢查（%s）\n' "$(printf '%s' "$_parsed" | tr '\n' ' ')"
  fi
fi

# ── reason 名跨檔 lint（issue #89）────────────────────────────────────────────
# review-triage.md 逐字列了一批 reason 名，helper 端改名時文件不會自己跟上——PR #85
# 就示範過一次（`ci_absent_after_invalid` -> `ci_absent_after_not_numeric`，靠手動同步）。
# glob 形式（`*_fields_unparsable`）抗腐，字面名不抗腐。
# **只查存在性，不查在允許側還是排除側**——doc **內部**的極性由
# tests/mattpocock-workflow.sh 那條允許側集合比對承擔（PR #92）；那三條全部只讀
# review-triage.md，**沒有一條讀 bin/pr-review-gate**，所以 helper 與 doc 之間的
# 存在性在本條之前完全無守衛。
# CONVENTIONS 規則 9（可機械化的檢查必須下沉為機械守護）涵蓋本條；規則 7 的字面範圍是
# skill／agent／MCP／hook 名，不含 helper 的 reason 名——#89 body 誤引了規則 7。
triage_doc="$ROOT/skills/dev-workflow/references/review-triage.md"

# 錨到**發射點**而不是裸出現：`rg -cF "$name" "$GATE"` 測的是「這個字串在檔案任何地方
# 出現過」，包含註解。helper 自己就有只出現在註解裡的 reason 名（`:16` 的診斷軼事），
# 所以「改名時順手在註解留一句舊名」會讓 lint 靜默通過——實測過。
# 兩個發射形狀都要認：多數走 `unavailable <name>`，而 review_actions_billing_or_quota
# 是 `:418` 的字面 `printf … reason=<name> …`，只認前者會打死 clean positive control。
# rc 三態：掃描器說成功卻交不出正整數計數 = 不可信，不得當成「找到了」（issue #95）。
# 同 repo 已有一份 rc 三態判別（tests/mattpocock-workflow.sh 的 rg_hits），contract 不同
# （它未命中回 stdout 0 + rc 0，這裡未命中回 rc 1），換用要重寫下方的 case 分派，
# 不是 drop-in。本地 5 行是刻意的：source 一支測試套件會把整套跑起來。
reason_in_gate() {  # reason_in_gate <name> -> 0=helper 端發射 1=沒有 2=掃描不可信
  local n rc=0
  n=$(rg -c -e "^[^#]*(unavailable ${1}\$|reason=${1}\b)" -- "$GATE") || rc=$?
  case "$rc" in
    0) case "$n" in ''|*[!0-9]*|0) return 2 ;; *) return 0 ;; esac ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

# 抽取用**排除清單**而不是後綴 allowlist。前一版寫 `(failed|quota|numeric|unparsable)`，
# 那是一份手寫名單：doc 端新增或改名成清單外的後綴時整條靜默跳過——實測把 doc 的
# `review_probe_failed` 改成 `review_probe_invalid`（helper 根本沒有這個名字）仍全綠，
# 而 `_invalid` 正是本註解引用的 PR #85 那個 motivating example 的後綴。
# 方向要挑會吵的那個：排除清單漏一項是紅的（誤報，看得見），allowlist 漏一項是綠的。
reason_not_a_name='^(reviews|unresolved|requested_reviewers|suppressed)$'

# 抽成函式，好讓下面的 control **跑同一段**判別而不是另寫一份近似的。
# 抽不出任何名字時不能靜默通過：那是「掃描器壞了」或「文件被改成不列名」，都要出聲。
reason_doc_extract() {  # -> stdout=名單；rc 0=可用 1=抽不出
  local rc=0 out
  out=$(rg -o -r '$1' -e '`([a-z][a-z_]*)`' -- "$triage_doc") || rc=$?
  { [ "$rc" -ne 0 ] || [ -z "$out" ]; } && return 1
  printf '%s\n' "$out"
}

if ! doc_reasons=$(reason_doc_extract); then
  ((fail += 1))
  printf 'FAIL reason-name lint: 掃不出 doc 端的 reason 名\n'
else
  reason_sorted=$(printf '%s\n' "$doc_reasons" | sort -u) || reason_sorted=
  if [ -z "$reason_sorted" ]; then
    # sort 失敗時 for 迴圈會跑零圈、兩個清單都空、直接印 PASS。上一行才小心接住 rg 的
    # rc，這裡放掉 sort 的就前功盡棄。
    ((fail += 1))
    printf 'FAIL reason-name lint: doc 端名單排序失敗\n'
  else
    reason_missing=
    reason_untrusted=
    reason_checked=0
    for reason_name in $reason_sorted; do
      # 用上面那個變數做排除，不要在這裡再手寫一份名單：兩份會改一處漏一處。
      [[ "$reason_name" =~ $reason_not_a_name ]] && continue
      reason_checked=$((reason_checked + 1))
      reason_in_gate "$reason_name"
      case "$?" in
        1) reason_missing="$reason_missing $reason_name" ;;
        2) reason_untrusted="$reason_untrusted $reason_name" ;;
      esac
    done
    if [ "$reason_checked" -lt 5 ]; then
      # 覆蓋面下限：抽取或排除規則壞掉時會靜默縮到零個名字仍印 PASS。實測把整個 for
      # body 換成 `:`、或把抽取正則縮成只剩一種後綴，`4ed9e30` 那一版都是整套全綠。
      ((fail += 1))
      printf 'FAIL reason-name lint 只檢查了 %s 個名字（doc 端至少該有 5 個字面 reason 名）\n' "$reason_checked"
    elif [ -z "$reason_missing" ] && [ -z "$reason_untrusted" ]; then
      ((pass += 1))
      printf 'PASS reason names in review-triage.md all fire in the helper (%s checked)\n' "$reason_checked"
    else
      ((fail += 1))
      printf 'FAIL reason names not fired by helper:%s / scan untrusted:%s\n' \
        "${reason_missing:- none}" "${reason_untrusted:- none}"
    fi
  fi
fi

# known-bad control：doc 端有而 helper 端沒發射的名字必須判成 missing（rc=1）。
reason_in_gate 'definitely_not_a_reason_failed'
if [ "$?" -eq 1 ]; then
  ((pass += 1)); printf 'PASS reason-name lint rejects its known-bad control\n'
else
  ((fail += 1)); printf 'FAIL reason-name lint rejects its known-bad control\n'
fi

# known-bad control 之二：註解行不算發射。「改名時順手在註解留一句舊名」會讓裸
# `rg -cF` 靜默通過（S5 Spec R1 實測過）。helper 檔目前沒有只出現在註解的 reason 名
# （15 個名字全部真的發射，已枚舉），所以這條直接驗 pattern 本身。
# rc=1（不命中）才算過：命中或掃描失敗都不算，control 自己不能 fail-open。
reason_prose_probe='#   舊名 reason=formerly_a_reason_failed 已於 2026-01-01 改名'
printf '%s\n' "$reason_prose_probe" |
  rg -c -e '^[^#]*(unavailable formerly_a_reason_failed$|reason=formerly_a_reason_failed\b)' \
  >/dev/null 2>&1
case "$?" in
  1) ((pass += 1)); printf 'PASS reason-name lint ignores names that only appear in prose\n' ;;
  *) ((fail += 1)); printf 'FAIL reason-name lint ignores names that only appear in prose\n' ;;
esac

# negative control ×2：掃描器故障必須回 2（不可信），不得塌成「沒找到」或「找到了」。
# 第二條（exit 0 卻無輸出）才是相對 `rg -qF` 的增量：rc=2 那格 `rg -q` 版本也守得住。
for reason_shim_rc in 2 0; do
  (rg() { return "$reason_shim_rc"; }; reason_in_gate 'review_request_failed')
  if [ "$?" -eq 2 ]; then
    ((pass += 1))
    printf 'PASS reason-name lint fails closed when the scanner returns rc=%s\n' "$reason_shim_rc"
  else
    ((fail += 1))
    printf 'FAIL reason-name lint fails closed when the scanner returns rc=%s\n' "$reason_shim_rc"
  fi
done

# doc 端抽取那條分支的 control：前一版四條 control 全部只驗 reason_in_gate 的 rc，
# extraction -> loop -> verdict 這條實際判定路徑零覆蓋——實測把整個 for body 換成 `:`
# 仍整套全綠（`4ed9e30`）。這兩條讓那條分支在掃描器故障時必須出聲。
# control 呼叫 **主 lint 用的同一支 reason_doc_extract**，不是另寫一份近似判別。
# 只驗「rg 產不產得出輸出」的話，主邏輯哪天把「rc=0 但無輸出」當成可用，control 照樣綠。
for reason_doc_shim_rc in 2 0; do
  reason_doc_probe=$( (rg() { return "$reason_doc_shim_rc"; }
    reason_doc_extract >/dev/null && printf 'USABLE' || printf 'REJECTED') 2>&1 )
  if [ "$reason_doc_probe" = REJECTED ]; then
    ((pass += 1))
    printf 'PASS reason-name lint extraction fails closed when the scanner returns rc=%s\n' "$reason_doc_shim_rc"
  else
    ((fail += 1))
    printf 'FAIL reason-name lint extraction fails closed when the scanner returns rc=%s\n' "$reason_doc_shim_rc"
  fi
done

# clean positive control（evidence-integrity.md 要求成對）。
reason_in_gate 'review_actions_billing_or_quota'
if [ "$?" -eq 0 ]; then
  ((pass += 1)); printf 'PASS reason-name lint accepts its clean positive control\n'
else
  ((fail += 1)); printf 'FAIL reason-name lint accepts its clean positive control\n'
fi

printf '%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
((fail == 0))

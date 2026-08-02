#!/usr/bin/env bash
# protect-files.sh 的 deny 路徑可達性回歸。
#
# 為何需要這支（2026-08-02 稽核）：這支 hook 在 PR #26 之前是壞的——訊息把變數
# 直接接上全形括號，展開因此在 hook_block 執行之前就 abort（set -uo pipefail），
# hook 回 exit 1 而非代表 deny 的 exit 2，敏感檔案保護 fail open。四層防線都沒攔到：
#   - 靜態檢查   parser 把「變數後接全形字元」讀成變數加文字，-S style 也 0 訊息
#   - 執行路徑   命中處在 deny 分支，平時不執行，不觸發
#   - bin/ci-local  當時 PASS 吞掉 stdout，就算觸發也看不見
#   - 語法守護   當時只掃 bin/ tests/ hooks/，漏掉 skills/
# tests/conformance.sh 現在有語法層守護，但語法正確不等於 deny 路徑走得到。
# 這支補行為層。
#
# ⚠️ locale 是這支測試能不能成立的前提。實測（bash 3.2.57，2026-08-02）：
#     LC_ALL=C            → 變數後接全形字元不誤解析，缺陷不重現
#     LC_ALL=en_US.UTF-8  → unbound variable，缺陷重現
#     LC_ALL=zh_TW.UTF-8  → 同上
#   第一版用 `env -i PATH HOME` 清環境，把 LANG/LC_ALL 一起剝掉，於是整支測試在
#   C locale 下跑——對它存在的目的完全是盲的（放進 #26 的缺陷版本仍 15 PASS）。
#   現在兩種 locale 都跑：C 是 CI runner 可能的預設，UTF-8 是 host 實際傳給 hook 的。
#
# deny 必須同時有理由輸出：host 收得到否決卻拿不到原因，等於使用者看到一個沒有
# 說明的阻擋。exit code 對了但訊息空掉，正是 #26 的失敗形狀。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$HOME/.agents}"
HOOK="$AGENTS/skills/init-project-docs/references/hooks/protect-files.sh"
pass=0; fail=0

ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

[ -f "$HOOK" ] || { printf 'FAIL  hook 不存在：%s\n' "$HOOK"; exit 1; }

probe() {  # $1=host標籤 $2=env指派 $3=expect $4=檔案路徑 $5=locale
  local label="$1" envset="$2" want="$3" path="$4" loc="$5"
  local rc actual=allow reason_seen=no out err
  # 分開兩次並各自處理：串成 && 時，第一個成功第二個失敗會直接 return，把已建立的
  # $out 留在檔案系統上（每個 case 洩漏一個檔）。
  out=$(mktemp) || {
    ng "$(printf '%-8s 無法建立 fixture（mktemp 失敗）' "$label")"; return
  }
  err=$(mktemp) || {
    rm -f "$out"
    ng "$(printf '%-8s 無法建立 fixture（mktemp 失敗）' "$label")"; return
  }

  # env -i 清空環境才能精確控制 HOOK_HOST 的推導；PATH/HOME 是 hook 自身需要的，
  # LC_ALL 則決定 bash 怎麼解析變數名後的多位元組字元（見檔頭）。
  printf '{"tool_input":{"file_path":"%s"}}' "$path" |
    env -i PATH="$PATH" HOME="$HOME" LC_ALL="$loc" $envset bash "$HOOK" >"$out" 2>"$err"
  rc=$?
  [ "$rc" -eq 2 ] && actual=deny
  [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || actual="BADEXIT($rc)"
  { [ -s "$out" ] || [ -s "$err" ]; } && reason_seen=yes
  rm -f "$out" "$err"

  if [ "$actual" != "$want" ]; then
    ng "$(printf '%-8s %-12s want=%-5s got=%-5s %s' "$label" "$loc" "$want" "$actual" "$path")"
  elif [ "$want" = deny ] && [ "$reason_seen" = no ]; then
    ng "$(printf '%-8s %-12s deny 但無理由輸出（host 收不到原因）%s' "$label" "$loc" "$path")"
  else
    ok "$(printf '%-8s %-12s %-5s %s' "$label" "$loc" "$want" "$path")"
  fi
}

for LOC in C en_US.UTF-8; do
  printf '── locale=%s ──\n' "$LOC"

  printf '  deny：四種 host 推導結果都必須 exit 2 且有理由\n'
  probe claude  "CLAUDECODE=1"    deny "/repo/.env" "$LOC"
  probe codex   "CODEX_HOME=/x"   deny "/repo/.env" "$LOC"
  probe copilot "COPILOT_HOME=/x" deny "/repo/.env" "$LOC"
  probe unknown ""                deny "/repo/.env" "$LOC"

  printf '  deny：11 個 PROTECTED_PATTERNS 逐一\n'
  for p in /a/.env /a/.env.local /a/.env.production /a/secrets.json \
           /a/appsettings.Production.json /a/credentials.json \
           /a/server.pem /a/id.key /a/yarn.lock /a/app.sqlite /a/data.db; do
    probe claude "CLAUDECODE=1" deny "$p" "$LOC"
  done

  printf '  positive control：一般檔案必須放行\n'
  # environment.ts 是刻意的：含 "environment" 但不是 .env，pattern 用 \.env$ 錨定
  probe claude  "CLAUDECODE=1"    allow "/repo/src/main.ts"    "$LOC"
  probe codex   "CODEX_HOME=/x"   allow "/repo/README.md"      "$LOC"
  probe copilot "COPILOT_HOME=/x" allow "/repo/package.json"   "$LOC"
  probe unknown ""                allow "/repo/docs/guide.md"  "$LOC"
  probe claude  "CLAUDECODE=1"    allow "/repo/environment.ts" "$LOC"
done

printf '\n── 解析器缺席：無從判斷即 fail-closed ──\n'
# 2026-08-02 稽核補測的漏網：本檔第一版驗了四種 host 與 11 個 pattern，就是沒驗
# 「jq 不在 PATH」。實測當時 rc=0（放行）——敏感檔案保護對整個缺 jq 的環境失效。
# 同 repo 的 hooks/guard-git-push.sh 檔頭早已明訂相反方向（解析失敗保守拒絕），
# 兩支 guard 對同一情境的處理不該相反。
NOJQ=$(mktemp -d) || exit 1
for _t in bash cat basename mktemp env printf grep sed; do
  _p=$(command -v "$_t" 2>/dev/null) && ln -sf "$_p" "$NOJQ/$_t"
done

nojq_probe() {  # $1=標籤 $2=payload $3=expect $4=額外env
  # 與 probe() 一樣要斷言「deny 必須有理由輸出」。第一版把輸出全丟 /dev/null 只驗
  # exit code——實測讓 hook_block 靜默（只 exit 2 不輸出）後，這裡 9 條全數 PASS，
  # 而 probe() 抓到 30 個。exit code 對但訊息空正是 #26 的失敗形狀，本檔檔頭就在
  # 講這件事，新加的 probe 卻沒做（2026-08-02 Copilot review 抓到）。
  local label="$1" payload="$2" want="$3" extra="$4" rc actual=allow reason_seen=no
  local out err
  out=$(mktemp) || { ng "$label 無法建立 fixture"; return; }
  err=$(mktemp) || { rm -f "$out"; ng "$label 無法建立 fixture"; return; }
  printf '%s' "$payload" |
    env -i PATH="$NOJQ" HOME="$HOME" LC_ALL=en_US.UTF-8 CLAUDECODE=1 $extra bash "$HOOK" \
    >"$out" 2>"$err"
  rc=$?
  [ "$rc" -eq 2 ] && actual=deny
  [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || actual="BADEXIT($rc)"
  { [ -s "$out" ] || [ -s "$err" ]; } && reason_seen=yes
  rm -f "$out" "$err"
  if [ "$actual" != "$want" ]; then
    ng "$(printf '%-34s want=%s got=%s' "$label" "$want" "$actual")"
  elif [ "$want" = deny ] && [ "$reason_seen" = no ]; then
    ng "$(printf '%-34s deny 但無理由輸出' "$label")"
  else
    ok "$(printf '%-34s %s' "$label" "$want")"
  fi
}

# 有 payload 但沒有解析器＝無從判斷，必須擋。一般檔也擋是刻意的：分不出安全與否時，
# 誤擋的代價遠低於放行敏感檔。
nojq_probe "無 jq，敏感檔"        '{"tool_input":{"file_path":"/repo/.env"}}'  deny  ""
nojq_probe "無 jq，一般檔"        '{"tool_input":{"file_path":"/repo/a.ts"}}'  deny  ""

# 「jq 在不在」不等於「讀得懂」。S5 補測：只 gate 在 command -v 會漏掉兩種失效，
# 兩者都讓 jq 回空字串而靜默放行。判準因此改成實際解析一次（jq -e .）。
printf '#!/usr/bin/env bash\nexit 5\n' > "$NOJQ/jq"; chmod +x "$NOJQ/jq"
nojq_probe "jq 存在但 exit 5，敏感檔" '{"tool_input":{"file_path":"/repo/.env"}}' deny ""
rm -f "$NOJQ/jq"

# 這兩條用真 jq：payload 本身不是合法 JSON，jq 解析失敗
badjson_probe() {  # $1=標籤 $2=payload $3=expect
  local rc actual=allow reason_seen=no out err
  out=$(mktemp) || { ng "$1 無法建立 fixture"; return; }
  err=$(mktemp) || { rm -f "$out"; ng "$1 無法建立 fixture"; return; }
  printf '%s' "$2" | env -i PATH="$PATH" HOME="$HOME" LC_ALL=en_US.UTF-8 CLAUDECODE=1 \
    bash "$HOOK" >"$out" 2>"$err"
  rc=$?
  [ "$rc" -eq 2 ] && actual=deny
  { [ -s "$out" ] || [ -s "$err" ]; } && reason_seen=yes
  rm -f "$out" "$err"
  if [ "$actual" != "$3" ]; then
    ng "$(printf '%-34s want=%s got=%s(rc=%s)' "$1" "$3" "$actual" "$rc")"
  elif [ "$3" = deny ] && [ "$reason_seen" = no ]; then
    ng "$(printf '%-34s deny 但無理由輸出' "$1")"
  else
    ok "$(printf '%-34s %s' "$1" "$3")"
  fi
}
badjson_probe "真 jq，JSON 截斷"    '{"tool_input":{"file_path":"/repo/.env"'  deny
badjson_probe "真 jq，非 JSON 文字"  'not json at all'                          deny
# 反向：合法 JSON 但沒有路徑欄位 → 必須放行，否則就是過度收緊。
# S5 指出第一版沒有這條，導致「把守護改成對任何非空 stdin 都擋」仍能全綠。
badjson_probe "真 jq，合法但無路徑欄位" '{"tool_input":{"prompt":"hi"}}'        allow
# 不該誤擋：沒有 stdin 代表根本不是 hook 呼叫；env fallback 有值時仍能正確判定。
nojq_probe "無 jq，無 stdin"      ''                                           allow ""
nojq_probe "無 jq，env 給一般檔"  '{}'  allow "CLAUDE_FILE_PATH=/repo/a.ts"
nojq_probe "無 jq，env 給敏感檔"  '{}'  deny  "CLAUDE_FILE_PATH=/repo/.env"

rm -rf "$NOJQ"

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是這支測試自己的 fail-open。稽核報告 Follow-up 3 記的就是這個形狀。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]

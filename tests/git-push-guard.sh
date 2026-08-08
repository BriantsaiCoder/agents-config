#!/usr/bin/env bash
#
# 共用 guard-git-push.sh 的雙格式回歸測試（[T0-3]）
#
# 為何存在：2026-07-25 實測 Claude 端舊 guard 有三個破口（--all / --mirror /
# 多 refspec 只查第一個），Codex 端同期版本沒有。合併為單一實作後，本測試對
# 兩種輸出格式各跑全部 payload，確保任一 host 的破口不會單邊復現。
#
# 契約：
#   codex  格式 — deny = stdout JSON(permissionDecision:deny) + exit 0；allow = 無輸出 + exit 0
#   claude 格式 — deny = exit 2（stderr JSON）；allow = 無 stdout + exit 0
set -ufo pipefail

GUARD=${GUARD:-"$HOME/.agents/hooks/guard-git-push.sh"}
JQ="$(command -v jq)"
pass=0
fail=0

# 固定分支的臨時 repo：讓「無明示 refspec」的案例可預期地解析到當前分支
# 本檔沒有 set -e：mktemp 失敗時變數為空，後續路徑會落到 / 底下而斷言照跑。
REPO="$(mktemp -d "${TMPDIR:-/tmp}/gpguard.XXXXXX")" ||
  { printf 'FAIL: 無法建立暫存 repo，測試未執行\n' >&2; exit 1; }
FAKEBIN="$(mktemp -d "${TMPDIR:-/tmp}/gpfake.XXXXXX")" ||
  { rm -rf "$REPO"; printf 'FAIL: 無法建立 fake bin 目錄，測試未執行\n' >&2; exit 1; }
trap 'rm -rf "$REPO" "$FAKEBIN"' EXIT   # 不清會在 /tmp 累積 gpguard.* / gpfake.*
PROBE_STDOUT="$REPO/probe.stdout"
PROBE_STDERR="$REPO/probe.stderr"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" branch -M feat/safe

classify_output() {
  local fmt="$1" rc="$2" stdout_file="$3" stderr_file="$4"

  if [ "$fmt" = codex ]; then
    if [ "$rc" -ne 0 ]; then
      printf 'BADEXIT(%s)' "$rc"
    elif [ -s "$stderr_file" ]; then
      printf 'BADOUTPUT'
    elif [ ! -s "$stdout_file" ]; then
      printf 'allow'
    elif "$JQ" -se '
      length == 1 and
      .[0].hookSpecificOutput.permissionDecision == "deny" and
      (.[0].hookSpecificOutput.permissionDecisionReason | type == "string" and length > 0)
    ' "$stdout_file" >/dev/null 2>&1; then
      printf 'deny'
    else
      printf 'BADOUTPUT'
    fi
  else
    if [ -s "$stdout_file" ]; then
      printf 'BADOUTPUT'
    elif [ "$rc" -eq 0 ] && [ ! -s "$stderr_file" ]; then
      printf 'allow'
    elif [ "$rc" -eq 2 ] && [ -s "$stderr_file" ] &&
      "$JQ" -se '
        length == 1 and
        .[0].decision == "block" and
        (.[0].reason | type == "string" and length > 0)
      ' "$stderr_file" >/dev/null 2>&1; then
      printf 'deny'
    elif [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
      printf 'BADOUTPUT'
    else
      printf 'BADEXIT(%s)' "$rc"
    fi
  fi
}

classifier_selfcheck() {
  : >"$PROBE_STDOUT"
  printf '\n' >"$PROBE_STDERR"
  [ "$(classify_output codex 0 "$PROBE_STDOUT" "$PROBE_STDERR")" = BADOUTPUT ] ||
    { printf 'FAIL  classifier accepted unexpected stderr\n'; exit 1; }

  printf '%s\n%s\n' \
    '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"x"}}' \
    '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"x"}}' \
    >"$PROBE_STDOUT"
  : >"$PROBE_STDERR"
  [ "$(classify_output codex 0 "$PROBE_STDOUT" "$PROBE_STDERR")" = BADOUTPUT ] ||
    { printf 'FAIL  classifier accepted a JSON stream\n'; exit 1; }

  printf '{"decision":"block","reason":"x"}' >"$PROBE_STDOUT"
  : >"$PROBE_STDERR"
  [ "$(classify_output claude 2 "$PROBE_STDOUT" "$PROBE_STDERR")" = BADOUTPUT ] ||
    { printf 'FAIL  classifier accepted Claude deny JSON on stdout\n'; exit 1; }
  printf '  PASS classifier malformed-output self-checks\n'
}

classifier_selfcheck

probe() {
  local fmt="$1" expected="$2" command="$3" rc actual
  "$JQ" -nc --arg command "$command" --arg cwd "$REPO" \
    '{tool_input:{command:$command},cwd:$cwd}' |
    bash "$GUARD" --format="$fmt" >"$PROBE_STDOUT" 2>"$PROBE_STDERR"
  rc=$?
  actual=$(classify_output "$fmt" "$rc" "$PROBE_STDOUT" "$PROBE_STDERR")
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1)); printf '  PASS %-6s %-5s %s\n' "$fmt" "$expected" "$command"
  else
    fail=$((fail + 1)); printf '  FAIL %-6s want=%s got=%s  %s\n' "$fmt" "$expected" "$actual" "$command"
  fi
}

run_suite() {
  local fmt="$1"
  printf '── format=%s ──\n' "$fmt"

  # 放行：非 push、一般 push（含推 main/master）、非保護分支的 lease
  probe "$fmt" allow "git status --short"
  probe "$fmt" allow "git init"
  probe "$fmt" allow "git add -A && git commit -m 'feat: x'"
  probe "$fmt" allow "git push"
  probe "$fmt" allow "git push origin main"
  probe "$fmt" allow "git push -u origin main"
  probe "$fmt" allow "git push origin master"
  probe "$fmt" allow "git push --tags"
  probe "$fmt" allow "git push --all origin"
  probe "$fmt" allow "git push --multiple origin backup"
  probe "$fmt" allow "git push -u origin feat/safe"
  probe "$fmt" allow "git push --force-with-lease origin feat/safe"
  probe "$fmt" deny  "git push --force-with-lease"            # Git config 可能改寫 effective destination
  probe "$fmt" allow "git pull --rebase && git push"

  # 攔截：非 lease force（任何分支）
  probe "$fmt" deny "git push --force origin feat/unsafe"
  probe "$fmt" deny "git push -f origin feat/unsafe"
  probe "$fmt" deny "git push -fu origin feat/unsafe"         # 短旗標捆綁
  probe "$fmt" deny "git push -4f origin feat/unsafe"         # 數字 + force 短旗標捆綁
  probe "$fmt" deny "git push --force --all origin"
  probe "$fmt" deny "git push --mirror origin"                # --mirror 隱含 force
  probe "$fmt" deny "git push origin +feat/x:main"            # +refspec 即 force
  probe "$fmt" deny 'git push "--mirror" origin'
  probe "$fmt" deny 'git "push" --mirror origin'
  probe "$fmt" deny 'git push "--force" origin main'
  probe "$fmt" deny 'git push --force-with-lease origin "main"'
  probe "$fmt" deny 'git p"ush" --force origin main'
  probe "$fmt" deny 'git push --for"ce" origin main'
  probe "$fmt" deny 'g"it" push --force origin main'
  probe "$fmt" deny '{git,push,--force,origin,main}'
  probe "$fmt" deny 'git push --force-with-lease origin ma"in"'
  probe "$fmt" deny 'git p\ush --force origin main'
  probe "$fmt" deny 'git push --force-w origin main'
  probe "$fmt" deny 'git push --force-with-l origin main'
  probe "$fmt" deny 'git push --mirr origin'
  probe "$fmt" deny 'git push --m origin'
  probe "$fmt" deny 'git push --mi origin'
  probe "$fmt" deny $'g\\\nit push --mirror origin'
  probe "$fmt" deny "\$'git' push --mirror origin"
  probe "$fmt" deny 'git push --force-with-l --al origin'
  probe "$fmt" deny 'git push --force-with-lease --repo=origin main'
  probe "$fmt" deny 'git push --force-with-lease --repo origin main'
  probe "$fmt" deny 'git push --force-with-lease --branches origin'
  probe "$fmt" deny 'git push --force-with-lease --br origin'
  probe "$fmt" deny 'git push --force-with-lease origin :'
  probe "$fmt" deny 'git push --force-with-lease origin refs/heads/*:refs/heads/*'
  probe "$fmt" deny 'git push --force-with-lease origin HEAD'
  probe "$fmt" deny 'git push --force-with-lease origin @'

  # 攔截：force 變體推 main/master
  probe "$fmt" deny "git push --force origin main"
  probe "$fmt" deny "git push --force-with-lease origin main"
  probe "$fmt" deny "git push --force-with-lease origin master"

  # 攔截：2026-07-25 實測的三個破口（Claude 舊版全部放行）
  probe "$fmt" deny "git push --force-with-lease --all origin"
  probe "$fmt" deny "git push --force-with-lease --mirror origin"
  probe "$fmt" deny "git push --force-with-lease origin feat/x main"
  probe "$fmt" deny "git push --force-with-lease origin feat/safe HEAD:refs/heads/master"

  # 攔截：複合指令中的危險段
  probe "$fmt" deny "echo hi && git push --force origin main"
  probe "$fmt" deny "(git push --mirror origin)"
  probe "$fmt" deny "(/usr/bin/git push --force origin main)"

  # 攔截：完整路徑 git（Copilot review agents-config#1 發現的第 5 個破口）
  # 只比對裸 token `git` 時，下列全部放行
  probe "$fmt" deny "/usr/bin/git push --force origin main"
  probe "$fmt" deny "/opt/homebrew/bin/git push --force-with-lease origin main"
  probe "$fmt" deny '"C:\Program Files\Git\bin\git.exe" push --force origin main'
  probe "$fmt" deny '"C:\Program Files\Git\bin\GIT.EXE" push --force origin main'
  probe "$fmt" deny '"C:\Program Files\Git\bin\GIT.EXE" p\ush --for\ce origin main'
  probe "$fmt" allow 'legit.exe push --force origin main'
  probe "$fmt" deny "'/usr/bin/git' push --force-with-lease --all origin"
  probe "$fmt" deny "env git push --force origin main"
  probe "$fmt" deny "GIT push --force origin main"
  probe "$fmt" allow "/usr/bin/git push -u origin main"      # 完整路徑的一般 push 仍放行
}

run_suite codex
run_suite claude

# 換成 main 後重驗無 refspec 仍保守拒絕
printf '── 當前分支 = main（無 refspec 同樣拒絕）──\n'
git -C "$REPO" branch -M main
probe codex  deny "git push --force-with-lease"
probe claude deny "git push --force-with-lease"

# jq 不可用時 MUST NOT 靜默放行（fail-open 會讓 [T0-3] 在缺 jq 的環境失效）
printf '── jq 不可用（降級路徑）──\n'
printf '#!/bin/sh\nexit 1\n' > "$FAKEBIN/jq"; chmod +x "$FAKEBIN/jq"
probe_nojq() {
  local fmt="$1" expected="$2" command="$3" payload rc actual
  payload=$("$JQ" -nc --arg command "$command" --arg cwd "$REPO" \
            '{tool_input:{command:$command},cwd:$cwd}')   # payload 先建好，再破壞 PATH
  printf '%s' "$payload" |
    PATH="$FAKEBIN:$PATH" bash "$GUARD" --format="$fmt" >"$PROBE_STDOUT" 2>"$PROBE_STDERR"
  rc=$?
  actual=$(classify_output "$fmt" "$rc" "$PROBE_STDOUT" "$PROBE_STDERR")
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1)); printf '  PASS %-6s %-5s (jq 壞) %s\n' "$fmt" "$expected" "$command"
  else
    fail=$((fail + 1)); printf '  FAIL %-6s want=%s got=%s (jq 壞) %s\n' "$fmt" "$expected" "$actual" "$command"
  fi
}
for f in codex claude; do
  probe_nojq "$f" deny  "git push --force origin main"        # 保守拒絕
  probe_nojq "$f" deny  "git push --force-with-lease origin feat/safe"
  probe_nojq "$f" deny  "GIT push --force origin main"
  probe_nojq "$f" deny  '"C:\Program Files\Git\bin\GIT.EXE" push --force origin main'
  probe_nojq "$f" allow "npm test"                            # 非 git 指令不受影響
  probe_nojq "$f" allow "ls -la"
done

# ── 唯讀 cwd：切詞機制不得因暫存檔建不起來而讓整段掃描被跳過 ──────────────
#
# 2026-08-08 實測的 fail-open：guard 原本用 here-string（`<<<`）切詞，而 macOS 的
# bash 3.2 把 here-doc／here-string 的暫存檔開在 **cwd** 而非 $TMPDIR。cwd 唯讀時
# redirect 失敗 → 陣列留空 → 掃描迴圈一次都不跑 → 落到檔尾 exit 0＝放行。
# 同一個 `git push --force origin main` payload：cwd 可寫回 rc=2 攔截，cwd 唯讀回
# rc=0 放行，而且無聲——錯誤訊息進 stderr，host 只看 exit code。
#
# 這條測的是「機制壞掉時的方向」，不是某個 payload 的判定，所以只需一個 deny 案例
# 加一個 allow 案例（確認修法沒把一般 push 也擋掉）。
readonly_dir="$REPO/readonly-cwd"
mkdir -p "$readonly_dir"
chmod 500 "$readonly_dir"
if ( cd "$readonly_dir" && : > .probe-write ) 2>/dev/null; then
  rm -f "$readonly_dir/.probe-write"
  printf '  SKIP  唯讀 cwd 案例：本環境下 chmod 500 仍可寫（root？），無法建立條件\n'
else
  ro_probe() {  # $1=expected $2=command
    local expected="$1" command="$2" rc actual
    "$JQ" -nc --arg command "$command" --arg cwd "$REPO" \
      '{tool_input:{command:$command},cwd:$cwd}' |
      ( cd "$readonly_dir" && bash "$GUARD" --format=claude ) \
        >"$PROBE_STDOUT" 2>"$PROBE_STDERR"
    rc=$?
    actual=$(classify_output claude "$rc" "$PROBE_STDOUT" "$PROBE_STDERR")
    if [ "$actual" = "$expected" ]; then
      pass=$((pass + 1)); printf '  PASS %-6s %-5s (唯讀 cwd) %s\n' claude "$expected" "$command"
    else
      fail=$((fail + 1)); printf '  FAIL %-6s want=%s got=%s (唯讀 cwd) %s\n' claude "$expected" "$actual" "$command"
    fi
  }
  ro_probe deny  "git push --force origin main"
  ro_probe allow "git push origin feat/safe"
fi
chmod 700 "$readonly_dir" 2>/dev/null || true

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]

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
set -uf

GUARD=${GUARD:-"$HOME/.agents/hooks/guard-git-push.sh"}
JQ="$(command -v jq)"
pass=0
fail=0

# 固定分支的臨時 repo：讓「無明示 refspec」的案例可預期地解析到當前分支
REPO="$(mktemp -d "${TMPDIR:-/tmp}/gpguard.XXXXXX")"
FAKEBIN="$(mktemp -d "${TMPDIR:-/tmp}/gpfake.XXXXXX")"
trap 'rm -rf "$REPO" "$FAKEBIN"' EXIT   # 不清會在 /tmp 累積 gpguard.* / gpfake.*
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" branch -M feat/safe

probe() {
  local fmt="$1" expected="$2" command="$3" out rc
  out=$("$JQ" -nc --arg command "$command" --arg cwd "$REPO" \
        '{tool_input:{command:$command},cwd:$cwd}' \
        | bash "$GUARD" --format="$fmt" 2>/dev/null)
  rc=$?
  local actual=allow
  if [ "$fmt" = codex ]; then
    printf '%s' "$out" | "$JQ" -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && actual=deny
    [ "$rc" -eq 0 ] || actual="BADEXIT($rc)"
  else
    [ "$rc" -eq 2 ] && actual=deny
    [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || actual="BADEXIT($rc)"
  fi
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
  probe "$fmt" allow "git push -u origin feat/safe"
  probe "$fmt" allow "git push --force-with-lease origin feat/safe"
  probe "$fmt" allow "git push --force-with-lease"            # 無 refspec，當前分支 feat/safe
  probe "$fmt" allow "git pull --rebase && git push"

  # 攔截：非 lease force（任何分支）
  probe "$fmt" deny "git push --force origin feat/unsafe"
  probe "$fmt" deny "git push -f origin feat/unsafe"
  probe "$fmt" deny "git push -fu origin feat/unsafe"         # 短旗標捆綁
  probe "$fmt" deny "git push origin +feat/x:main"            # +refspec 即 force

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

  # 攔截：完整路徑 git（Copilot review agents-config#1 發現的第 5 個破口）
  # 只比對裸 token `git` 時，下列全部放行
  probe "$fmt" deny "/usr/bin/git push --force origin main"
  probe "$fmt" deny "/opt/homebrew/bin/git push --force-with-lease origin main"
  probe "$fmt" deny "'/usr/bin/git' push --force-with-lease --all origin"
  probe "$fmt" deny "env git push --force origin main"
  probe "$fmt" allow "/usr/bin/git push -u origin main"      # 完整路徑的一般 push 仍放行
}

run_suite codex
run_suite claude

# 當前分支為 main 時，無 refspec 的 lease 必須攔截
printf '── 當前分支 = main（無 refspec 解析）──\n'
git -C "$REPO" branch -M main
probe codex  deny "git push --force-with-lease"
probe claude deny "git push --force-with-lease"

# jq 不可用時 MUST NOT 靜默放行（fail-open 會讓 [T0-3] 在缺 jq 的環境失效）
printf '── jq 不可用（降級路徑）──\n'
printf '#!/bin/sh\nexit 1\n' > "$FAKEBIN/jq"; chmod +x "$FAKEBIN/jq"
probe_nojq() {
  local fmt="$1" expected="$2" command="$3" payload out rc actual=allow
  payload=$("$JQ" -nc --arg command "$command" --arg cwd "$REPO" \
            '{tool_input:{command:$command},cwd:$cwd}')   # payload 先建好，再破壞 PATH
  out=$(printf '%s' "$payload" | PATH="$FAKEBIN:$PATH" bash "$GUARD" --format="$fmt" 2>/dev/null)
  rc=$?
  if [ "$fmt" = codex ]; then
    printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && actual=deny
  else
    [ "$rc" -eq 2 ] && actual=deny
  fi
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1)); printf '  PASS %-6s %-5s (jq 壞) %s\n' "$fmt" "$expected" "$command"
  else
    fail=$((fail + 1)); printf '  FAIL %-6s want=%s got=%s (jq 壞) %s\n' "$fmt" "$expected" "$actual" "$command"
  fi
}
for f in codex claude; do
  probe_nojq "$f" deny  "git push --force origin main"        # 保守拒絕
  probe_nojq "$f" deny  "git push --force-with-lease origin feat/safe"
  probe_nojq "$f" allow "npm test"                            # 非 git 指令不受影響
  probe_nojq "$f" allow "ls -la"
done

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]

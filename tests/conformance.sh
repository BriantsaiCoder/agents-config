#!/usr/bin/env bash
# conformance.sh — 三主機安全修復的綠態探針集（正本：proposals/2026-07-10-gpt56-review-verification/02-fix-plan.md Batch 9）
# 用途：驗證各批次修復的守護仍在。手動跑；改 guard / hook / settings / core 後必跑。
# 不掛 SessionStart（避免每 session 開銷）。任一 FAIL = 對應批次退綠，不得宣稱 done（[T0-2]）。
# 紅線：本腳本 MUST NOT 印出 audit-bash.log 內容或任何憑證樣式原值，只回報 PASS/FAIL。
set -u

pass=0; fail=0
ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# 探針 4 若中途被殺，確保部署檔已還原
RESTORE_SRC=""; RESTORE_DST=""
trap '[ -n "$RESTORE_SRC" ] && [ -f "$RESTORE_SRC" ] && mv "$RESTORE_SRC" "$RESTORE_DST"' EXIT

# ── 1. Batch 1：autoMode 三陣列保留 "$defaults"（內建防線未被覆寫）──
n=$(grep -c '"\$defaults"' "$HOME/.claude/settings.json" 2>/dev/null || echo 0)
[ "$n" -ge 3 ] && ok "settings.json \$defaults x$n (≥3)" || ng "settings.json \$defaults x$n (<3)"

# ── 2. Batch 2：audit-bash 遮罩 + log 權限 600 ──
LOG="$HOME/.claude/audit-bash.log"
dummy="probe_${$}_$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
printf '{"tool_input":{"command":"export API_KEY=%s"},"cwd":"/tmp"}' "$dummy" \
  | bash "$HOME/.claude/hooks/audit-bash.sh" >/dev/null 2>&1
perm=$(stat -f%Lp "$LOG" 2>/dev/null || stat -c%a "$LOG" 2>/dev/null || echo 0)
[ "$perm" = "600" ] && ok "audit-bash.log 權限 600" || ng "audit-bash.log 權限 $perm ≠ 600"
if tail -1 "$LOG" 2>/dev/null | grep -q '\*\*\*' && ! grep -q -- "$dummy" "$LOG" 2>/dev/null; then
  ok "audit-bash 遮罩生效（synthetic 值未落盤）"
else
  ng "audit-bash 遮罩失效（synthetic 值落盤或無 *** 標記）"
fi

# ── 3. Batch 3a/6：protect-files apply_patch fail-closed（.env 目標 → 拒絕）──
PF="$HOME/.agents/skills/init-project-docs/references/hooks/protect-files.sh"
printf '{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\\n*** Update File: .env\\n@@\\n-A\\n+B\\n*** End Patch"}}' \
  | env CLAUDECODE=1 bash "$PF" >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] && ok "protect-files apply_patch(.env) 拒絕 rc=$rc" || ng "protect-files apply_patch(.env) 放行 rc=0"

# ── 4. Batch 5：agents-sync --doctor 缺部署檔 → rc≠0（測畢還原）──
DEPLOY="$HOME/.codex/AGENTS.md"
if [ -f "$DEPLOY" ]; then
  tmpd=$(mktemp -d)
  RESTORE_SRC="$tmpd/AGENTS.md"; RESTORE_DST="$DEPLOY"
  mv "$DEPLOY" "$RESTORE_SRC"
  if "$HOME/.agents/bin/agents-sync" --doctor >/dev/null 2>&1; then rc=0; else rc=1; fi
  mv "$RESTORE_SRC" "$RESTORE_DST"
  RESTORE_SRC=""; RESTORE_DST=""
  rmdir "$tmpd" 2>/dev/null
  [ "$rc" -ne 0 ] && ok "doctor 缺部署檔 rc≠0" || ng "doctor 缺部署檔仍回 rc=0（假綠）"
  "$HOME/.agents/bin/agents-sync" --doctor >/dev/null 2>&1 \
    && ok "doctor 還原後 rc=0" || ng "doctor 還原後仍 rc≠0（還原不完整？）"
else
  ng "部署檔 $DEPLOY 不存在，探針 4 無法執行"
fi

# ── 5. Batch 7：CONVENTIONS 標題宣稱條數 == 實際 '## N' 節數 ──
CONV="$HOME/.agents/CONVENTIONS.md"
claimed=$(sed -n '1p' "$CONV" | grep -oE '[0-9]+ 條' | grep -oE '[0-9]+' | head -1)
actual=$(grep -c '^## [0-9]' "$CONV")
[ -n "$claimed" ] && [ "$claimed" = "$actual" ] \
  && ok "CONVENTIONS 條數宣稱 $claimed == 實際 $actual" \
  || ng "CONVENTIONS 條數宣稱 ${claimed:-無} ≠ 實際 $actual"

# ── 6. Batch 7：tdd agent 無 Rails dangling refs ──
if grep -qi rails "$HOME/.claude/agents/tdd.md" "$HOME/.codex/agents/tdd.toml" 2>/dev/null; then
  ng "tdd agent 仍含 Rails 殘留"
else
  ok "tdd agent Rails refs = 0"
fi

# ── 7. Batch 4b：guard-git-push 攔截 force-push master；放行非保護分支 lease ──
GUARD="$HOME/.claude/hooks/guard-git-push.sh"
printf '{"tool_input":{"command":"git push --force origin master"},"cwd":"%s"}' "$HOME" \
  | bash "$GUARD" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && ok "guard 攔截 force-push master rc=2" || ng "guard 未攔截 force-push master rc=$rc"
printf '{"tool_input":{"command":"git push --force-with-lease origin feat/x"},"cwd":"%s"}' "$HOME" \
  | bash "$GUARD" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "guard 放行 lease 非保護分支 rc=0" || ng "guard 誤攔 lease 非保護分支 rc=$rc"

# ── 8. Codex-native PreToolUse guard：allow / deny contract canary ──
if "$HOME/.agents/tests/codex-git-push-guard.sh" >/dev/null 2>&1; then
  ok "Codex hook + exec policy allow/deny canary 12 cases"
else
  ng "Codex hook + exec policy allow/deny canary 未通過"
fi

# ── 9. 共用 guard 雙格式回歸（2026-07-25 四破口：--all / --mirror / 多 refspec / -fu 捆綁）──
if "$HOME/.agents/tests/git-push-guard.sh" >/dev/null 2>&1; then
  ok "共用 guard 雙格式 50 cases（四破口回歸）"
else
  ng "共用 guard 雙格式回歸未通過"
fi

# ── 10. git hooks 已安裝且與版控來源同步 ──
# 為什麼要驗「同步」而不只是「存在」：.git/hooks/ 是 install-hooks.sh 的**複製**不是
# symlink，且 .git 不進版控。所以有三種靜默失效，只驗存在只抓到第一種：
#   (a) 新機器 clone 後沒跑 install-hooks.sh → 完全無守護
#   (b) 跑過但之後改了 hooks/*.sh 沒重裝 → 執行的是舊版邏輯
#   (c) 有人直接改 .git/hooks/ 而非改版控來源 → 正本與實際分岔
# 三者都不會報錯。cmp 逐位元組比對同時覆蓋三種。
# hooks 目錄問 git 而非自己拼：linked worktree 內 .git 是檔案不是目錄，且 --git-path
# 在一般 repo 回相對路徑、在 worktree 回絕對路徑，故需補上 repo root。
# AGENTS_HOME override 沿用 agents-sync 的既有慣例——本探針的三條失敗路徑（未安裝／
# 來源已改未重裝／.git/hooks 被直接改）都必須對隔離 clone 驗證，否則就得動 live hooks。
AG="${AGENTS_HOME:-$HOME/.agents}"
hp=$(cd "$AG" && git rev-parse --git-path hooks 2>/dev/null || echo '')
case "$hp" in
  '')  HOOKS_DIR='' ;;
  /*)  HOOKS_DIR="$hp" ;;
  *)   HOOKS_DIR="$AG/$hp" ;;
esac
if [ -z "$HOOKS_DIR" ]; then
  ng "無法解析 git hooks 目錄（$AG 不是 git repo？）"
else
  for pair in pre-commit-agents.sh:pre-commit post-checkout-agents.sh:post-checkout; do
    src="$AG/hooks/${pair%%:*}"; name="${pair##*:}"; dst="$HOOKS_DIR/$name"
    if [ ! -f "$src" ]; then
      ng "hook 來源缺失 hooks/${pair%%:*}"
    elif [ ! -x "$dst" ]; then
      ng "hook $name 未安裝或不可執行（跑 bash hooks/install-hooks.sh）"
    elif ! cmp -s "$src" "$dst"; then
      ng "hook $name 與版控來源不同步（來源已改？跑 bash hooks/install-hooks.sh 重裝）"
    else
      ok "hook $name 已安裝且與來源同步"
    fi
  done
fi

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

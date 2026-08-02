#!/usr/bin/env bash
# [T0-3] guard 的 deny 路徑可達性回歸。
#
# 為何需要這支（2026-08-02 稽核）：既有測試各驗一半，中間有縫。
#   tests/git-push-guard.sh   驗判定邏輯（68 cases）——但只對 $GUARD 指到的那一份。
#   tests/hook-parity.sh      驗漂移偵測機制本身，用 fixture，不碰真的 guard。
#   bin/hook-parity-check     驗三份副本內容一致——一致不等於「deny 路徑走得到」。
# 縫在於：沒有任何一支斷言「host 實際執行的那份，餵它 force push 真的會被擋」。
#
# PR #26 的教訓正是這個縫的形狀：protect-files.sh 的 hook_block 因為變數展開在它
# 執行前就 abort，deny 路徑其實走不到，而所有既有測試都是綠的。
#
# 驗的是「執行對象」不是「正本」：bin/hook-parity-check 檔頭記載 ~/.agents/hooks/
# 底下的檔沒有任何 host 會執行，三份是實體副本。稽核初期正是先驗錯了對象。
#
# ⚠️ 這支在 CI 上的增量有限，價值主要在開發機。runner 沒有 host-local 副本，
#   剩下的 16 個 repo 正本 case 是 tests/git-push-guard.sh（68 cases，同樣兩種
#   format）的子集。真正只有這支能驗的是「~/.claude 與 ~/.codex 那兩份實體副本
#   當下能不能擋」——那要在有 host 設定的機器上跑才成立。保留 CI 註冊是因為
#   bin/ci-local 從 ci.yml 解析步驟，不註冊就等於本機也不會跑。
#
# 不依賴 jq：payload 用 printf 組。ci.yml 只裝 ripgrep 與 gitleaks，jq 雖然 runner
# 預裝但不該當成契約。guard 自身缺 jq 的降級路徑由 tests/git-push-guard.sh 覆蓋。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$HOME/.agents}"
pass=0; fail=0; skipped=0

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()   { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skip() { printf '  SKIP  %s\n' "$1"; skipped=$((skipped + 1)); }

# command 是本檔內的固定字面值，不需跳脫；cwd 帶的是 AGENTS 的值，理論上可含 " 或 \。
# 那種路徑會產生非法 JSON，guard 解析失敗後走 fail-closed，表現為整批 want=allow
# 的 case 變 deny——失敗方向安全且吵，不會靜默。此處不加跳脫是刻意的取捨。
payload() { printf '{"tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2"; }

probe() {  # $1=guard路徑 $2=標籤 $3=format $4=expect $5=command
  local guard="$1" tag="$2" fmt="$3" want="$4" cmd="$5" out rc actual=allow
  out=$(payload "$cmd" "$AGENTS" | bash "$guard" --format="$fmt" 2>/dev/null)
  rc=$?
  if [ "$fmt" = codex ]; then
    # codex 契約：deny 走 stdout JSON，exit 0（guard-git-push.sh 檔頭「輸出契約依 host 分流」段）
    case "$out" in *'"permissionDecision":"deny"'*) actual=deny ;; esac
    [ "$rc" -eq 0 ] || actual="BADEXIT($rc)"
  else
    [ "$rc" -eq 2 ] && actual=deny
    [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || actual="BADEXIT($rc)"
  fi
  if [ "$actual" = "$want" ]; then
    ok "$(printf '%-9s %-6s %-5s %s' "$tag" "$fmt" "$want" "$cmd")"
  else
    ng "$(printf '%-9s %-6s want=%s got=%s %s' "$tag" "$fmt" "$want" "$actual" "$cmd")"
  fi
}

# 組裝而非字面：本檔會被 rg 掃，也可能被貼進 command 字串觸發 live guard 誤擋
F='--force'
FWL='--force-with-lease'

check_guard() {  # $1=路徑 $2=標籤
  local guard="$1" tag="$2" fmt
  for fmt in claude codex; do
    # deny：四種必須擋的形狀
    probe "$guard" "$tag" "$fmt" deny  "git push $F origin main"
    probe "$guard" "$tag" "$fmt" deny  "git push $F origin feature"
    probe "$guard" "$tag" "$fmt" deny  "git push $FWL origin main"
    probe "$guard" "$tag" "$fmt" deny  "git push $FWL --all origin"
    # positive control：全 deny 不具鑑別力，必須證明它分得出來
    probe "$guard" "$tag" "$fmt" allow "git push origin feature"
    probe "$guard" "$tag" "$fmt" allow "git push origin main"
    probe "$guard" "$tag" "$fmt" allow "git status"
    probe "$guard" "$tag" "$fmt" allow "git push $FWL origin feature"
  done
}

printf '── repo 正本（CI 唯一能驗的對象）──\n'
repo_guard="$AGENTS/hooks/guard-git-push.sh"
if [ -f "$repo_guard" ]; then
  check_guard "$repo_guard" "repo"
else
  ng "repo guard 不存在：$repo_guard"
fi

printf '\n── host 實際執行的副本 ──\n'
for h in claude codex; do
  hg="$HOME/.$h/hooks/guard-git-push.sh"
  if [ -f "$hg" ]; then
    check_guard "$hg" "$h"
  else
    skip "$h 副本不存在（${hg}）——CI 環境沒有 host-local 設定，非合規缺陷"
  fi
done

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skipped"
# 「至少跑到了」自證：repo 正本必定存在，pass 為 0 代表 probe 全數沒跑成功
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]

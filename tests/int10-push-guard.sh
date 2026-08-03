#!/usr/bin/env bash
#
# [INT-10] 直接推 main 的機械攔截回歸（guard-git-push.sh 的 int10_* 半邊）
#
# 與 tests/git-push-guard.sh 的分工：那支測 [T0-3] force-push 判定，fixture 是一個
# 普通臨時 repo；本支測 [INT-10]，判定的輸入是「cwd 屬於哪個 repo」，所以 fixture 必須
# 讓 $HOME/.agents 這類路徑真的存在。兩者 fixture 需求不同，合併會讓其中一邊的前置
# 條件污染另一邊。
#
# 為何需要機械閘（而非只有 [INT-10] 的 prose）：[T0-9]「merge 前 MUST 綠 CI + 處理 bot
# review」的觸發是「merge 前」，直接 push main 根本沒有 merge 動作，於是該 gate 連同它
# 唯一的獨立視角被整條繞過，且不違反任何條文。2026-08-03 有五個全域設定 commit 這樣
# 落地：CI 全綠、bot review 從未產生。隨後第一個走 PR 的變更（#40）立刻被 Copilot 抓到
# 一個真缺陷——那個對照就是本攔截存在的理由。
#
# 本測試不需要 --selftest：正反兩組互為對方的極性守衛。guard 若永遠放行，「應擋」那組
# 全 FAIL；若永遠拒絕，「應放行」那組全 FAIL。沒有「斷言整段不跑仍回綠」的空間。
set -ufo pipefail

GUARD=${GUARD:-"$HOME/.agents/hooks/guard-git-push.sh"}
GUARD=$(cd "$(dirname "$GUARD")" && pwd -P)/$(basename "$GUARD")   # HOME 覆寫前先定死
[ -r "$GUARD" ] || { printf 'FAIL  guard 不可讀: %s\n' "$GUARD" >&2; exit 1; }
command -v jq >/dev/null || { printf 'FAIL  jq 不可用，guard 會走 fail-closed 路徑\n' >&2; exit 1; }

pass=0; fail=0

# fixture：假 HOME，讓 $HOME/.agents 等路徑真的是 git repo。
# guard 的 int10_in_scope 比對 "$HOME/.agents" 等四個字面路徑，覆寫 HOME 即可在 runner
# 上跑完整判定——不需要真實的 ~/.agents（CI 沒有）。
# pwd -P 正規化：macOS 的 $TMPDIR 在 /var/folders 底下，而 /var 是 /private/var 的
# symlink。guard 內以 physical path 比對，fixture 若留 logical path，判定會全數落空——
# 第一版就是這樣，14 條「應擋」全部誤放行。
SCRATCH="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/int10guard.XXXXXX")" && pwd -P)"
trap 'rm -rf "$SCRATCH"' EXIT
export HOME="$SCRATCH"

mk_repo() {  # $1=路徑 $2=當前分支
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" commit -q --allow-empty -m init
  git -C "$1" branch -M "$2"
}

mk_repo "$SCRATCH/.agents" main          # 當前分支就是 main：測「無明示 refspec」
mk_repo "$SCRATCH/.claude" feat/safe
mk_repo "$SCRATCH/elsewhere" main        # 範圍外對照組
# worktree：cwd 在 .worktrees/<branch> 底下，common-dir 必須把它歸回 $SCRATCH/.agents
git -C "$SCRATCH/.agents" worktree add -q -b feat/wt "$SCRATCH/.agents/.worktrees/feat/wt" 2>/dev/null

probe() {  # $1=fmt $2=deny|allow $3=cwd $4=command $5=說明
  local fmt="$1" expect="$2" cwd="$3" cmd="$4" desc="$5" out rc
  out=$(jq -nc --arg c "$cwd" --arg m "$cmd" '{cwd:$c, tool_input:{command:$m}}' \
        | bash "$GUARD" "--format=$fmt" 2>&1); rc=$?

  local got=allow
  case "$fmt" in
    claude) [ "$rc" -eq 2 ] && got=deny ;;
    codex)  case "$out" in *'"permissionDecision":"deny"'*) got=deny ;; esac ;;
  esac

  if [ "$got" = "$expect" ]; then
    printf '  PASS  [%s] %s: %s\n' "$fmt" "$expect" "$desc"; pass=$((pass + 1))
  else
    printf '  FAIL  [%s] 期望 %s 實得 %s: %s (rc=%s) %s\n' \
      "$fmt" "$expect" "$got" "$desc" "$rc" "${out:0:80}" >&2; fail=$((fail + 1))
  fi
}

for fmt in claude codex; do
  # ── 應擋 ──
  probe "$fmt" deny "$HOME/.agents" "git push origin main"   "全域 repo 推 main"
  probe "$fmt" deny "$HOME/.claude" "git push origin master" "全域 repo 推 master"
  probe "$fmt" deny "$HOME/.agents" "git push"               "無明示 refspec，當前分支即 main"
  probe "$fmt" deny "$HOME/.agents" "git push origin feat/a main" "多 refspec 其一為 main"
  probe "$fmt" deny "$HOME/.agents/.worktrees/feat/wt" "git push origin main" \
        "worktree 內推 main（common-dir 歸屬主 repo）"
  probe "$fmt" deny "$HOME/.agents" "git push origin refs/heads/main" "refspec 帶 refs/heads/ 前綴"
  probe "$fmt" deny "$HOME/.agents" "git push origin HEAD:main" "src:dst 形式，dst 為 main"
  # 省略 remote 的 refspec：args 只有 1 個 token，位置上與 remote 無法區分。第一版只把它
  # 當 remote，於是落到當前分支分支——在當前分支非 main 的 repo 裡就整個繞過了
  # （Copilot 於 PR #42 指出）。fixture 用 .claude（當前分支 feat/safe）才驗得到這條。
  probe "$fmt" deny "$HOME/.claude" "git push HEAD:main"  "省略 remote 的 refspec 推 main"
  probe "$fmt" deny "$HOME/.claude" "git push :master"    "省略 remote 的刪除型 refspec 指向 master"
  # `git -C <path>` 決定實際操作哪個 repo；只看 payload 的 cwd 會讓範圍外目錄推範圍內
  # 的 main 整個繞過（Copilot 於 PR #42 指出）。cwd 一律用 elsewhere 才驗得到這條。
  probe "$fmt" deny "$HOME/elsewhere" "git -C $HOME/.agents push origin main" \
        "git -C 絕對路徑指向範圍內 repo"
  probe "$fmt" deny "$HOME/elsewhere" "git -C ~/.agents push origin main" \
        "git -C 波浪號路徑（hook 看到的是未展開字串）"
  probe "$fmt" deny "$HOME/elsewhere" "git -C$HOME/.claude push origin master" \
        "git -C 無空格形式"

  # ── 應放行 ──
  probe "$fmt" allow "$HOME/.agents" "git push origin feat/x"  "全域 repo 推 feature branch"
  probe "$fmt" allow "$HOME/.claude" "git push"                "無 refspec，當前分支非 main"
  probe "$fmt" allow "$HOME/.claude" "git push origin"         "只有 remote（不得被當成 refspec 誤擋）"
  probe "$fmt" allow "$HOME/.agents" "INT10_ACK=user當下明示 git push origin main" \
        "帶 INT10_ACK 前綴（[INT-10] 的例外，留稽核痕跡）"
  probe "$fmt" allow "$HOME/.agents" "cd /tmp && INT10_ACK=r git push origin main" \
        "複合命令中該段以 INT10_ACK 開頭（切段後有前導空白）"

  # ── 逃生門不得被「只是提到」打開（Copilot 於 PR #42 指出的繞過路徑） ──
  # 第一版用 `case "$CMD" in *INT10_ACK=*)` 對整個 command 做子字串比對，下面三種
  # 形態都會誤開例外。逃生門若能被字面提及觸發，它就不是逃生門而是繞過路徑。
  probe "$fmt" deny "$HOME/.agents" "echo INT10_ACK=fake; git push origin main" \
        "前段只是印出 INT10_ACK=（不得打開例外）"
  probe "$fmt" deny "$HOME/.agents" "git push origin main INT10_ACK=x" \
        "INT10_ACK= 出現在參數位置（不得打開例外）"
  probe "$fmt" deny "$HOME/.agents" "git commit -m INT10_ACK=x && git push origin main" \
        "前段 commit message 提到 INT10_ACK=（不得打開例外）"
  probe "$fmt" allow "$HOME/elsewhere" "git push origin main"  "範圍外 repo 推 main"
  probe "$fmt" allow "$HOME/.agents" "git -C $HOME/elsewhere push origin main" \
        "cwd 在範圍內但 git -C 指向範圍外（不得誤擋）"
  probe "$fmt" allow "$HOME/.agents" "git push origin --delete feat/x" "刪除 feature branch"
  probe "$fmt" allow "$HOME/.agents" "git status"              "非 push 指令"

  # ── [T0-3] 未被本次改動破壞（force 判定優先於 [INT-10]） ──
  probe "$fmt" deny "$HOME/elsewhere" "git push --force origin feat/x" \
        "[T0-3] 非 lease force push 仍擋（範圍外也擋）"
  probe "$fmt" deny "$HOME/elsewhere" "git push --force-with-lease origin main" \
        "[T0-3] lease force 推 main 仍擋"
done

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

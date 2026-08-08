#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/agents-branch.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/agents"
WT_ROOT="$TMP/worktrees"
git init -q -b main "$REPO"
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
printf 'baseline\n' > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm baseline
head=$(git -C "$REPO" rev-parse HEAD)

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/isolation-test >/dev/null

[ "$(git -C "$REPO" branch --show-current)" = main ]
[ "$(git -C "$REPO" rev-parse HEAD)" = "$head" ]
WT="$WT_ROOT/codex/isolation-test"
[ "$(git -C "$WT" branch --show-current)" = codex/isolation-test ]
[ "$(git -C "$WT" rev-parse HEAD)" = "$head" ]

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" --done codex/isolation-test >/dev/null
[ ! -d "$WT" ]

# ── --done 的失敗訊息：依「實際留下什麼」分辨後果，不寫死猜測 ──
# 舊版對所有失敗都印同一句「有未提交變更？加 --force」。2026-08-01 實測踩到的真因是沙箱擋住
# .git/worktrees/ 的刪除，目錄其實已移除成功——歸因錯誤（與變更無關），且暗示什麼都沒發生
# （實際已半完成）。正確的下一步是 git worktree prune，不是 --force。
run_done() {
  AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
    bash "$ROOT/bin/agents-branch" --done "$1" 2>&1
}

# 情境 A：目錄仍在（未提交變更）→ 必須轉述 git 原因，且不得宣稱已移除。
AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/dirty-test >/dev/null
printf 'uncommitted\n' > "$WT_ROOT/codex/dirty-test/scratch.txt"
git -C "$WT_ROOT/codex/dirty-test" add scratch.txt
out=$(run_done codex/dirty-test) && { echo "FAIL: 髒 worktree 竟然成功移除"; exit 1; }
case "$out" in
  *'git worktree remove 回報失敗'*) ;;
  *) echo "FAIL: 未轉述 git 的失敗（實得：${out}）"; exit 1 ;;
esac
case "$out" in
  *'worktree 目錄仍在'*) ;;
  *) echo "FAIL: 未指出目錄仍在（實得：${out}）"; exit 1 ;;
esac
[ -d "$WT_ROOT/codex/dirty-test" ] || { echo "FAIL: 失敗後目錄不該消失"; exit 1; }

# 情境 B：目錄已消失但登記仍在（半完成）→ 必須指向 git worktree prune，
# 且**不得**把原因說成未提交變更。
#
# 用注入的假 git 觸發，不是靠 rm + mkdir 擺弄真實狀態。這個分支的前提是「remove 失敗，但目錄
# 已經沒了」——真實 git 不會那樣結束（實測踩到時是沙箱擋住 .git/worktrees/ 的刪除才造成），
# 拿 mkdir 把目錄建回來只會讓 remove 直接成功，測試整段空轉卻仍然 PASS。
# 假 git 只攔 worktree remove／list 兩個子命令，其餘一律轉給真 git。
# 建在 $TMP 底下，讓本檔開頭既有的 trap 'rm -rf "$TMP"' EXIT 一併清掉。獨立 mktemp 只有跑到
# 最後那行 rm 才清得掉，任何斷言失敗提早 exit 就會留下暫存目錄——開發本檔時實際漏了好幾個。
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
# 真 git 的路徑必須在注入 PATH **之前**解析：替身自己叫 command -v git 只會找到它自己。
# 不寫死 /usr/bin/git——Nix、部分容器、只裝 Homebrew git 的機器都不在那個路徑。
REAL_GIT=$(command -v git) || { echo "FAIL: 找不到 git"; exit 1; }
export REAL_GIT
cat > "$FAKEBIN/git" <<'FAKE'
#!/usr/bin/env bash
set -u
# 攔截的兩個子命令都自己結束，不轉交真 git。轉交會讓真 git 的輸出與替身輸出交錯，測試結果
# 因此取決於緩衝與 exec 的時序（實測過：同一段程式在管線下時而命中時而不命中）。測試替身要
# 決定性，不要真實性。
if [[ "${1:-} ${2:-}" == "worktree remove" ]]; then
  rm -rf "$3"                                  # 目錄真的消失
  echo "fatal: 模擬 metadata 清理被擋" >&2
  exit 1                                       # 但回報失敗＝半完成
elif [[ "${1:-} ${2:-}" == "worktree list" ]]; then
  printf 'worktree %s\n' "${FAKE_STILL_REGISTERED:-}"
  exit 0
fi
exec "${REAL_GIT:?REAL_GIT 未設定}" "$@"         # 其餘轉給真 git（路徑由呼叫端解析後傳入）
FAKE
chmod +x "$FAKEBIN/git"

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/half-test >/dev/null
HALF="$WT_ROOT/codex/half-test"
out=$(PATH="$FAKEBIN:$PATH" FAKE_STILL_REGISTERED="$HALF" \
  AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" --done codex/half-test 2>&1) && \
  { echo "FAIL: 半完成情境不該回報成功"; exit 1; }
[ ! -d "$HALF" ] || { echo "FAIL: 假 git 未真的移除目錄，情境 B 沒被觸發"; exit 1; }
case "$out" in
  *'git worktree prune'*) ;;
  *) echo "FAIL: 半完成未指向 git worktree prune（實得：${out}）"; exit 1 ;;
esac
# 鎖舊版那句誤導的原文「有未提交變更？」，不是裸字串「未提交變更」——新訊息裡有「非未提交
# 變更」這個否定句，裸字串會把正確的訊息判成失敗（本檔第一版正是這樣假紅的）。
case "$out" in
  *'有未提交變更？'*) echo "FAIL: 半完成情境不得歸因為未提交變更（實得：${out}）"; exit 1 ;;
esac

echo "agents-branch isolated worktree PASS"
echo "agents-branch --done 失敗訊息 PASS"

# ── --help 印的必須是自己的檔頭 ──────────────────────────────────────
# 2026-08-02 缺陷：--help 用 `sed -n '…p' "$0"`，而腳本在那之前已 `cd "$AGENTS"`。
# 用相對路徑呼叫時 $0 於是解析到 $AGENTS 底下的同名檔，--help 印的是別份的檔頭。
# 兩份內容一致時完全看不出來——實測是在 worktree 裡加了新選項才顯現。
help_probe() {  # $1=cwd $2=呼叫用的路徑
  ( cd "$1" && AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" bash "$2" --help 2>&1 )
}
# 在 $REPO 裡放一份檔頭不同的同名檔，當作「另一份 checkout」
mkdir -p "$REPO/bin"
printf '#!/usr/bin/env bash\n# DECOY-HEADER-MUST-NOT-APPEAR\nset -euo pipefail\n' \
  > "$REPO/bin/agents-branch"

out=$(help_probe "$ROOT" "bin/agents-branch")
case "$out" in
  *DECOY-HEADER-MUST-NOT-APPEAR*)
    echo "FAIL: --help 印到了 \$AGENTS 底下那份的檔頭（\$0 在 cd 之後解析錯誤）"; exit 1 ;;
esac
case "$out" in
  *'agents-branch --merged'*) ;;
  *) echo "FAIL: --help 未印出本檔的 --merged 選項（實得前兩行：$(printf '%s' "$out" | head -2 | tr '\n' ' ')）"; exit 1 ;;
esac
# 印過頭會把 `set -euo pipefail` 這類程式碼當說明印出來
case "$out" in
  *'set -euo pipefail'*) echo "FAIL: --help 印出了程式碼，sed 範圍超出檔頭註解"; exit 1 ;;
esac
rm -f "$REPO/bin/agents-branch"

# ── --merged 的 fail-closed 判定 ─────────────────────────────────────
# 刪 remote 不可逆，所以判不出「已合併」時必須拒絕。三條路徑各驗一次：
# gh 缺席、查無 PR、PR 非 MERGED。成功路徑另用 mock gh 驗。
# PATH 只留 FAKEBIN——不能退回系統 PATH，否則「gh 缺席」那條會抓到真的 gh，
# 測到的就不是缺席行為。代價是腳本需要的每個外部工具都得手動 link 進來。
FAKEBIN="$TMP/fakebin"; mkdir -p "$FAKEBIN"
for t in bash git mktemp dirname basename sed grep rm printf; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$FAKEBIN/$t"
done

merged_probe() {  # $1=gh 行為(absent|none|"<num> <state>") $2=branch
  local ghmode="$1" br="$2"
  if [ "$ghmode" = absent ]; then
    rm -f "$FAKEBIN/gh"
  else
    # 腳本先用 --jq 'length' 問數量，再用 --jq '.[0]|…' 取狀態。mock 依參數分流，
    # 不能對兩種呼叫回同一個字串——第一版就是這樣，把 "42 OPEN" 餵給數量判斷。
    # none 模擬「查無 PR」：真 gh 此時 length 回 0（而 .[0] 會回字面 "null null"，
    # 那正是第一版誤用輸出形狀判斷的原因）。
    { printf '#!/usr/bin/env bash\n'
      printf 'case "$*" in\n'
      if [ "$ghmode" = none ]; then
        printf '  *"--jq length"*|*length*) printf 0 ;;\n'
        printf '  *) printf "null null" ;;\n'
      else
        printf '  *"--jq length"*|*length*) printf 1 ;;\n'
        printf '  *) printf %%s "%s" ;;\n' "$ghmode"
      fi
      printf 'esac\n'
    } > "$FAKEBIN/gh"
    chmod +x "$FAKEBIN/gh"
  fi
  ( AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
    PATH="$FAKEBIN" bash "$ROOT/bin/agents-branch" --merged "$br" 2>&1 ) || true
}

git -C "$REPO" branch nomerge-test 2>/dev/null || true

out=$(merged_probe absent nomerge-test)
case "$out" in
  *'gh 不可用'*) ;;
  *) echo "FAIL: gh 缺席時未拒絕（實得：${out}）"; exit 1 ;;
esac
git -C "$REPO" show-ref -q --verify refs/heads/nomerge-test ||
  { echo "FAIL: gh 缺席時不得刪除分支"; exit 1; }

out=$(merged_probe none nomerge-test)
case "$out" in
  *'沒有對應的 PR'*) ;;
  *) echo "FAIL: 查無 PR 時未拒絕（實得：${out}）"; exit 1 ;;
esac
git -C "$REPO" show-ref -q --verify refs/heads/nomerge-test ||
  { echo "FAIL: 查無 PR 時不得刪除分支"; exit 1; }

out=$(merged_probe "42 OPEN" nomerge-test)
case "$out" in
  *'不是 MERGED'*) ;;
  *) echo "FAIL: PR 未合併時未拒絕（實得：${out}）"; exit 1 ;;
esac
git -C "$REPO" show-ref -q --verify refs/heads/nomerge-test ||
  { echo "FAIL: PR 未合併時不得刪除分支"; exit 1; }

# ── 成功路徑：必須有真 remote 且分支真的未合併，否則測不到東西 ──────
# 第一版 fixture 沒有 remote、分支又剛好停在 main 的 HEAD，於是兩個 mutation 都能
# 存活：把 `git push origin --delete` 換成 true 仍綠（沒有 remote 可刪），把 -D 換成
# -d 也仍綠（git 認為分支已合併）。測不到的斷言等於沒有斷言。
BARE="$TMP/remote.git"
git init -q --bare "$BARE"
git -C "$REPO" remote add origin "$BARE"

# 分支帶自己的 commit → 相對 main 未合併，-d 會拒絕、-D 才成功（squash merge 後的形狀）
git -C "$REPO" checkout -q -b feat/real-merged
printf 'work\n' > "$REPO/work.txt"
git -C "$REPO" add work.txt
git -C "$REPO" commit -qm work
git -C "$REPO" push -q origin feat/real-merged
git -C "$REPO" checkout -q main
git -C "$REPO" ls-remote --exit-code --heads origin feat/real-merged >/dev/null ||
  { echo "FAIL: fixture 沒把分支推上 bare remote"; exit 1; }

out=$(merged_probe "42 MERGED" feat/real-merged)
case "$out" in
  *'收尾完成'*) ;;
  *) echo "FAIL: PR MERGED 時未完成收尾（實得：${out}）"; exit 1 ;;
esac
git -C "$REPO" show-ref -q --verify refs/heads/feat/real-merged &&
  { echo "FAIL: PR MERGED 後 local 分支仍在（-d 擋不住未合併分支，須用 -D）"; exit 1; }
# 直接查 remote 本身，不看訊息——訊息說刪了不等於真的刪了
git -C "$REPO" ls-remote --exit-code --heads origin feat/real-merged >/dev/null 2>&1 &&
  { echo "FAIL: PR MERGED 後 remote 分支仍在"; exit 1; }
case "$out" in
  *'remote    已刪'*) ;;
  *) echo "FAIL: 刪了 remote 卻沒如實回報（實得：${out}）"; exit 1 ;;
esac

# ── ls-remote 查詢失敗必須 fail-closed，不得讀成「remote 不存在」──────
# --exit-code 回 2 才是「沒有這個 ref」，128 是查詢本身失敗（網路／認證／remote 不存在）。
# 兩者混為一談時，網路一斷就會印「remote 無」+「收尾完成」rc=0，而分支好端端還在。
git -C "$REPO" branch feat/ls-fail
git -C "$REPO" remote set-url origin "$TMP/no-such-remote.git"
out=$(merged_probe "43 MERGED" feat/ls-fail)
case "$out" in
  *'無法查詢 origin'*) ;;
  *) echo "FAIL: ls-remote 查詢失敗時未 fail-closed（實得：${out}）"; exit 1 ;;
esac
case "$out" in
  *'remote    無'*) echo "FAIL: 查詢失敗被讀成 remote 不存在"; exit 1 ;;
esac
git -C "$REPO" remote set-url origin "$BARE"

# ── worktree 登記殘留必須指向 prune，不得報「無」──────────────────
# 目錄已刪但 .git/worktrees/ 登記還在（沙箱擋住那層刪除時的樣子）。報「worktree 無」
# 是宣稱沒驗證過的狀態，而且下一步 branch -D 會被殘留登記擋掉。
git -C "$REPO" branch feat/stale-wt
AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" feat/stale-wt >/dev/null
rm -rf "${WT_ROOT:?}/feat/stale-wt"          # 只刪目錄，登記留著
out=$(merged_probe "44 MERGED" feat/stale-wt)
case "$out" in
  *'git worktree prune'*) ;;
  *) echo "FAIL: worktree 登記殘留時未指向 prune（實得：${out}）"; exit 1 ;;
esac
case "$out" in
  *'worktree  無'*) echo "FAIL: 登記殘留被讀成 worktree 不存在"; exit 1 ;;
esac
git -C "$REPO" show-ref -q --verify refs/heads/feat/stale-wt ||
  { echo "FAIL: 登記殘留時不得刪除分支"; exit 1; }

echo "agents-branch --help 自我檔頭 PASS"
echo "agents-branch --merged fail-closed PASS"

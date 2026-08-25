# shellcheck shell=bash
# 掃描器 rc 三態的共用判別。由 tests/ 底下各測試檔 source。
#
# 為什麼存在：`rg -q PAT f && ok || ng` 是單一 bit——掃描器只要回非 0 就等同「沒命中」
# （方向 fail-closed 但歸因指錯地方），而一支**壞掉卻 exit 0** 的掃描器直接變 PASS。
# 那是 fail-open：真違規在掃描器靜默失敗時無聲變綠。issue #95（mattpocock-workflow）
# 與 #97（conformance 等）修的是同一個形狀。
#
# 這支檔案是那個判別的**唯一正本**。新增消費端時 source 它，不要複製第 N 份——
# PR #96 的 S5 Standards R2 逐字點名過這件事。

# 核心：把 rg 的 rc 與輸出兩邊都對過一次。
# 用 -c 而非 -q：`rg -q` 的 rc=0 只說「有命中」，壞掉但 exit 0 的 rg 同樣回 0。
# rc=0 卻交不出正整數總和 = 掃描器自相矛盾（rg 無命中時回 rc=1 且不印），
# 歸「掃描不可信」而非「沒命中」。檔案不存在不另外先驗：rg 對它回 rc=2，同一格。
# 省略 target 時讀 stdin（顯式的 `-`）；target 用 `--` 隔開，開頭是 `-` 也不會被當旗標。
# target 是目錄時 rg 逐檔各印一行，--no-filename 去掉 `path:` 前綴後逐行加總。
# 加總用參數展開而非 `<<<`：macOS 系統 bash 3.2 把 here-string 的暫存檔開在 **cwd**
# 而不是 TMPDIR，cwd 不可寫時整支套件會垮（PR #96 實測 354 -> 70 PASS）。
# rg 的 stderr 不吞：ERE -> Rust regex 的遷移新增了一整類只從 stderr 現形的失敗
# （`a{`、`a\q` 在 grep -qE 是「合法、無命中」，在 rg 是 regex parse error）。
# --hidden --no-ignore：target 是目錄時 rg 預設套 .gitignore 與 hidden 過濾，排除側會
# under-scan——違規檔只要被 gitignore 命中或是 dotfile 就掃不到，`scan_miss` 回「乾淨」。
# 本 repo 的 .gitignore 含 `.claude/`、`__pycache__/`、`*.bak*`、`backups/`。
# 多一個 target 一律回「不可信」而不是靜默只掃第一個：呼叫端傳兩個路徑時的靜默丟棄
# 比掃不到更難發現。
_rg_scan() {  # _rg_scan <re|fixed> <pattern> [target] -> stdout=命中行數總和；rc 0=可信 2=不可信
  local mode="$1" pattern="$2" out rc=0 total=0 line
  shift 2
  [ "$#" -le 1 ] || return 2
  if [ "$#" -eq 1 ]; then
    case "$mode" in
      fixed) out=$(rg -c --no-filename --hidden --no-ignore -F -e "$pattern" -- "$1") || rc=$? ;;
      *)     out=$(rg -c --no-filename --hidden --no-ignore    -e "$pattern" -- "$1") || rc=$? ;;
    esac
  else
    out=$(rg -c --no-filename -e "$pattern" -) || rc=$?
  fi
  case "$rc" in
    1) printf '0\n'; return 0 ;;
    0) ;;
    *) return 2 ;;
  esac
  while [ -n "$out" ]; do
    line=${out%%$'\n'*}
    case "$line" in ''|*[!0-9]*) return 2 ;; esac
    total=$((total + line))
    if [ "$out" = "$line" ]; then out=; else out=${out#*$'\n'}; fi
  done
  [ "$total" -gt 0 ] || return 2
  printf '%s\n' "$total"
}

# 回命中行數；rc 0=掃描可信、2=不可信。這是給「需要精確計數」的呼叫端的公開介面。
rg_hits() { _rg_scan re "$@"; }

# 回命中的**行內容**（rc 同 rg_hits）。給需要對每一行再做判定的呼叫端——例如
# 「這行有計數宣稱，但同行是否帶座標」這種 rg 的 Rust regex 沒有 lookahead 做不到的事。
rg_lines() {  # rg_lines <pattern> <target> -> stdout=命中行；rc 0=可信 2=不可信
  local out rc=0
  [ "$#" -eq 2 ] || return 2
  out=$(rg --no-filename -e "$1" -- "$2") || rc=$?
  case "$rc" in
    1) return 0 ;;
    0) printf '%s\n' "$out" ;;
    *) return 2 ;;
  esac
}

# fixed-string 版目前只有下面兩支 boolean wrapper 在用，不列為公開介面——真的出現
# 「精確計數 + 字面比對」的外部消費端再提上去。stdin 同理只走 regex 路徑
# （`scan_*_f` 全部帶檔案 target），所以 _rg_scan 的 stdin 分支不分 mode。
_rg_hits_f() { _rg_scan fixed "$@"; }

# Boolean 形式，取代 `rg -q` / `rg -Fq`。**掃描不可信一律回非 0**，所以
# `scan_hit … && ok || ng` 與 `if scan_hit …; then ok; else ng; fi` 都 fail-closed。
scan_hit()    { local n; n=$(rg_hits   "$@") && [ "$n" -gt 0 ]; }
scan_hit_f()  { local n; n=$(_rg_hits_f "$@") && [ "$n" -gt 0 ]; }

# 控制項骨架。**呼叫端 MUST 在 source 本檔之前定義 `ok()` 與 `ng()`**（本檔不自己印，
# 因為各測試檔的 verdict 格式與計數變數各不相同）。
# 驗**印出來的判定**而不只是 rc：這條線的症狀就是「印出 PASS」，而 ok／ng 都 return 0，
# helper 的 rc 只承載「掃描可不可信」——純 rc 版連 `ok "$1"; return 1` 這種假 helper 都會
# 全數放行（PR #96 的 S5 R2 實測）。什麼都沒印同樣不算通過。
# <helper> 若自己不印 verdict（`scan_hit` 只回 rc），傳一個把 rc 轉成 verdict 的 wrapper。
# **shim 目標是參數**，不是寫死的 `rg`：前一版寫死之後，任何不是用 rg 的判別（例如
# find_count）就補不了 control——那正是本輪 S5 Standards 的 BLOCKING 根因。
# 用 case 分派而不是 eval：shim 目標只有這兩個，明確列出比動態定義安全也好讀。
assert_fails_closed() {  # assert_fails_closed <prefix> <shim-cmd> <shim-rc> <helper> <args...>
  local prefix="$1" shim_cmd="$2" shim_rc="$3" why out
  shift 3
  case "$shim_rc" in
    2) why="$shim_cmd errors" ;;
    0) why="$shim_cmd exits 0 with no output" ;;
    *) why="$shim_cmd returns rc=$shim_rc" ;;
  esac
  case "$shim_cmd" in
    rg)   out=$( (rg()   { return "$shim_rc"; }; "$@") 2>&1 ) ;;
    find) out=$( (find() { return "$shim_rc"; }; "$@") 2>&1 ) ;;
    *)    ng "$prefix: 未知的 shim 目標 $shim_cmd"; return 1 ;;
  esac
  case "$out" in
    *'  PASS  '*) ng "$prefix fails closed when $why" ;;
    *'  FAIL  '*) ok "$prefix fails closed when $why" ;;
    *)            ng "$prefix fails closed when $why" ;;
  esac
}

# find 的結果與筆數。與 rg_hits 同一類（掃描器 rc 三態），所以家在這裡而不是消費端。
# 驗 rc **與 stderr**：局部失敗（某個子目錄不可讀）rc=1 但仍輸出部分結果，rc 偵測不到。
# **find 的 silent-success 偵測不到**：rc=0 + 空輸出是合法的 0（真的沒有那種檔），
# 與 rg -c 不同（rg 無命中回 rc=1，rc=0 卻無輸出才是自相矛盾）。呼叫端要自己配 canary。
find_list() {  # find_list <errfile> <find-args…> -> stdout=結果；rc 0=可信 2=不可信
  local errfile="$1" out rc=0
  shift
  [ -n "$errfile" ] || return 2
  out=$(find "$@" 2>"$errfile") || rc=$?
  { [ "$rc" -ne 0 ] || [ -s "$errfile" ]; } && return 2
  printf '%s' "$out"
}

find_count() {  # find_count <errfile> <find-args…> -> stdout=筆數；rc 0=可信 2=不可信
  local out n
  out=$(find_list "$@") || return 2
  [ -z "$out" ] && { printf '0\n'; return 0; }
  n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  case "$n" in ''|*[!0-9]*) return 2 ;; esac
  printf '%s\n' "$n"
}

# 給只回 rc 的 helper 用的 verdict wrapper。
scan_verdict() { "$@" && printf '  PASS  probe\n' || printf '  FAIL  probe\n'; }

# 反向（取代 `! rg -q` / `! rg -Fq`）。**不能寫成 `! scan_hit`**——那樣掃描不可信時
# `scan_hit` 回非 0，`!` 反轉成 true，違規反而放行。這兩支把「不可信」與「沒命中」分開。
scan_miss()   { local n; n=$(rg_hits   "$@") && [ "$n" -eq 0 ]; }
scan_miss_f() { local n; n=$(_rg_hits_f "$@") && [ "$n" -eq 0 ]; }

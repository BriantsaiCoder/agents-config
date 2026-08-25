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
_rg_scan() {  # _rg_scan <re|fixed> <pattern> [target] -> stdout=命中行數總和；rc 0=可信 2=不可信
  local mode="$1" pattern="$2" out rc=0 total=0 line
  shift 2
  if [ "$#" -ge 1 ]; then
    case "$mode" in
      fixed) out=$(rg -c --no-filename -F -e "$pattern" -- "$1") || rc=$? ;;
      *)     out=$(rg -c --no-filename    -e "$pattern" -- "$1") || rc=$? ;;
    esac
  else
    case "$mode" in
      fixed) out=$(rg -c --no-filename -F -e "$pattern" -) || rc=$? ;;
      *)     out=$(rg -c --no-filename    -e "$pattern" -) || rc=$? ;;
    esac
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

# 回命中行數；rc 0=掃描可信、2=不可信。需要精確計數的呼叫端用這兩支。
rg_hits()   { _rg_scan re    "$@"; }
rg_hits_f() { _rg_scan fixed "$@"; }

# Boolean 形式，取代 `rg -q` / `rg -Fq`。**掃描不可信一律回非 0**，所以
# `scan_hit … && ok || ng` 與 `if scan_hit …; then ok; else ng; fi` 都 fail-closed。
scan_hit()    { local n; n=$(rg_hits   "$@") && [ "$n" -gt 0 ]; }
scan_hit_f()  { local n; n=$(rg_hits_f "$@") && [ "$n" -gt 0 ]; }

# 反向（取代 `! rg -q` / `! rg -Fq`）。**不能寫成 `! scan_hit`**——那樣掃描不可信時
# `scan_hit` 回非 0，`!` 反轉成 true，違規反而放行。這兩支把「不可信」與「沒命中」分開。
scan_miss()   { local n; n=$(rg_hits   "$@") && [ "$n" -eq 0 ]; }
scan_miss_f() { local n; n=$(rg_hits_f "$@") && [ "$n" -eq 0 ]; }

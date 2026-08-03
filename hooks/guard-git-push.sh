#!/usr/bin/env bash
#
# 共用 PreToolUse(Bash) guard — [T0-3] force-push 前置攔截（兩 host 單一實作）
#
# 用法: guard-git-push.sh --format=claude|codex   （由各 host 的薄 wrapper 傳入）
#
# 攔截：任何非 lease force push（--force / -f / 短旗標捆綁如 -fu / +refspec）；
#       任何 force 變體推 main/master；--force-with-lease 搭 --all/--mirror。
# 放行：非保護分支的 --force-with-lease、一般 push（含 push origin main）、非 push 指令。
# 無明示 refspec 時以 payload cwd 解析當前分支；解析失敗保守拒絕（fail-closed）。
# git 可執行檔認 git / */git / git.exe / */git.exe——只認裸 token 會被完整路徑繞過。
# jq 不可用或解析失敗時，對含 git+push 的 payload 保守拒絕（不得靜默放行）。
#
# 輸出契約依 host 分流：
#   claude — {"decision":"block"} → stderr，exit 2
#   codex  — {"hookSpecificOutput":{…permissionDecision:"deny"}} → stdout，exit 0
# 放行路徑兩者相同：無輸出、exit 0。
#
# ⚠️ 已知且刻意的誤擋：比對對象是整個 command 字串，所以「只是提到」危險
# payload 的指令也會被擋（如 commit message 內文引用 --force-with-lease --all）。
# MUST NOT 為消除此誤擋而改成解析 shell 語法區分「真指令 vs 字串」——那會開出
# 引號規避路徑（false negative 對安全閘的代價遠高於 false positive）。
# 遇到誤擋的正解：把該文字移出 command 字串（如 git commit -F <file>）。
set -ufo pipefail

FORMAT=claude   # 未指定時取 exit-2 語意（fail-closed：寧可誤擋不可誤放）
for arg in "$@"; do
  case "$arg" in
    --format=claude) FORMAT=claude ;;
    --format=codex)  FORMAT=codex ;;
    --format=*)      printf 'guard-git-push: 未知 --format=%s，回退 claude\n' "${arg#--format=}" >&2 ;;
  esac
done

# JSON 字串轉義：純 bash 參數展開，不依賴 jq——deny() 必須在 jq 不可用時仍能輸出合法 JSON
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"   # 反斜線必須先轉，否則會把後面補的反斜線再轉一次
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

deny() {
  case "$FORMAT" in
    codex)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$(json_escape "$1")"
      exit 0
      ;;
    *)
      printf '{"decision":"block","reason":%s}\n' "$(json_escape "$1")" >&2
      exit 2
      ;;
  esac
}

JQ="$(command -v jq 2>/dev/null || true)"
INPUT="$(cat)"

# jq 不可用或解析失敗時 MUST NOT 靜默放行（那會讓 [T0-3] 在缺 jq 的環境失效）。
# 但也不能一律拒絕——那會擋掉所有 Bash 指令。折衷：只對「原始 payload 就含 git+push」
# 的請求保守拒絕，其餘放行；使用者會看到明確理由而非靜默失去防線。
if [ -z "$JQ" ] || ! CMD=$(printf '%s' "$INPUT" | "$JQ" -r '.tool_input.command // empty' 2>/dev/null); then
  case "$INPUT" in
    *git*push*) deny "[T0-3] jq 不可用或 payload 解析失敗，無法判定 push 目標，保守拒絕。請確認 jq 已安裝且在 PATH 中。" ;;
  esac
  exit 0
fi

[ -z "$CMD" ] && exit 0
case "$CMD" in *git*push*) ;; *) exit 0 ;; esac
CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""

# [INT-10] 的例外是「使用者當下明示直接推 main」。hook 看不到對話，所以要求把明示
# 具體化成指令前綴 INT10_ACK=<原因>：它會留在 command 字串裡，事後可稽核。
# 刻意不用環境變數——那不會出現在 payload，等於一個看不見的後門。
# 與 [T0-3] 的差別：force push 無例外可言，本條有，所以逃生門是規則本身要求的。
#
# 判定下放到 check_seg 的段層級，不在此處對整個 CMD 做子字串比對：後者會讓
# `echo INT10_ACK=x; git push origin main` 這種「只是提到」的形態打開例外，等於
# 另一個看不見的後門（Copilot 於 PR #42 指出）。逃生門必須是它宣稱的那個形狀
# ——該段自己的開頭——否則它就不是逃生門而是繞過路徑。

# refspec token 正規化。check_seg 的 tokenization 是 shell word splitting，不解析引號，
# 所以 `git push origin "main"` 的 token 是帶引號的 "main"，直接比對 main|master 永遠
# 命不中——[T0-3] 與 [INT-10] 都能用加一對引號繞過（Copilot 於 PR #42 指出 [INT-10] 側，
# [T0-3] 側是同一個缺陷的另一半）。去引號的處理檔案上方判定 git 可執行檔時已有，
# 這裡是它漏掉的另一處。
normalize_ref() {
  local s="$1"
  s="${s%\"}"; s="${s#\"}"
  s="${s%\'}"; s="${s#\'}"
  s="${s##*:}"                     # refspec 可能是 src:dst，取 dst
  printf '%s' "${s#refs/heads/}"
}

check_target() {
  local target; target=$(normalize_ref "$1")
  case "$target" in
    main|master) deny "[T0-3] 禁止 force push（含 --force-with-lease）到 main/master。" ;;
  esac
}

# ── [INT-10] 全域設定 repo 必須走 PR 路徑 ─────────────────────────
# 為什麼需要機械閘：[T0-9]（merge 前 MUST 綠 CI + 處理 bot review）的觸發是「merge 前」，
# 而直接 push main 根本沒有 merge 動作，於是該 gate 連同它唯一的獨立視角（bot review）
# 被整條繞過，且不違反任何條文。2026-08-03 有五個全域設定 commit 這樣落地：CI 全綠、
# bot review 從未產生；隨後走 PR 的第一個變更（#40）就被 Copilot 抓到一個真缺陷。
# [INT-10] 補了 prose 規則，本節是它的 enforcement。
#
# 範圍以 repo 為單位而非逐檔比對 diff：這四個 repo 整體就是全域設定，且 push 前算 diff
# 會增加失敗面。過度攔截的代價是多開一個 PR，漏攔截的代價是防線再次被靜默繞過——
# 依 fail-closed 選前者。
int10_repo_root() {
  local cwd="$1" gitdir
  [ -n "$cwd" ] || return 1
  # --git-common-dir 而非 --show-toplevel：worktree 的 toplevel 是 .worktrees/<branch>，
  # 用它會讓 worktree 逃出範圍判定；common-dir 一律指回主 repo 的 .git。
  gitdir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null) || return 1
  [ -n "$gitdir" ] || return 1
  case "$gitdir" in /*) ;; *) gitdir="$cwd/$gitdir" ;; esac
  (cd "$gitdir/.." 2>/dev/null && pwd -P) || return 1
}

int10_in_scope() {
  local root home
  root=$(int10_repo_root "$1") || return 1
  # $HOME 也要正規化：int10_repo_root 回的是 pwd -P 的 physical path，而 $HOME 可能含
  # symlink（macOS 的 /var → /private/var 是最常見的一個）。兩邊不同基準時比對永遠不成立，
  # 而失敗方向是靜默放行——這道閘會看起來還在，實際上什麼都沒擋。
  home=$(cd "$HOME" 2>/dev/null && pwd -P) || home="$HOME"
  case "$root" in
    "$home/.agents"|"$home/.claude"|"$home/.codex"|"$home/.copilot") return 0 ;;
  esac
  return 1
}

# $1=路徑 $2=相對路徑的 base。~ 自己展開——hook 拿到的是尚未交給 shell 的原始字串。
abs_path() {
  case "$1" in
    "~")   printf '%s' "$HOME" ;;
    "~"/*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    /*)    printf '%s' "$1" ;;
    *)     printf '%s/%s' "$2" "$1" ;;
  esac
}

# git-dir 指向的是 .git 本身，repo root 是它的 parent；裸 .git 目錄（bare）則用它自己。
gitdir_root() {
  local gd; gd=$(abs_path "$1" "$2")
  case "$gd" in
    */.git|*/.git/) printf '%s' "${gd%/.git*}" ;;
    *)              printf '%s' "$gd" ;;
  esac
}

int10_check() {
  local target; target=$(normalize_ref "$1")
  case "$target" in
    main|master)
      deny "[INT-10] 全域設定 repo 不得直接 push 到 ${target}，必須走 PR 路徑：isolated branch → Ready PR → bot-review gate → squash merge → 刪 branch。理由：[T0-9] 的觸發是「merge 前」，直接推 main 沒有 merge 動作，該 gate 連同 bot review 會被整條繞過。使用者當下明示要直接推時，在指令前加 INT10_ACK=<原因> 前綴，例外即成立且留下稽核痕跡。"
      ;;
  esac
}

check_seg() {
  local seg="$1" t target
  local IFS=$' \t\n'
  local -a toks=($seg) args=()
  local i seen_git=0 seen_push=0 has_force=0 has_lease=0 broad_refset=0
  local dash_c="" work_tree="" git_dir="" want_c=0 want_wt=0 want_gitdir=0
  for ((i = 0; i < ${#toks[@]}; i++)); do
    t=${toks[i]}
    if (( ! seen_push )); then
      # 環境變數前綴同樣能改變實際操作的 repo，且出現在 git 之前。
      # `-C` 只是這一族的其中一個成員——Claude Code 自己的 changelog 修過同一組
      # （worktree 隔離被 git -C / --git-dir / GIT_DIR 重導）。只擋 -C 等於留三個門。
      if (( ! seen_git )); then
        case "$t" in
          GIT_DIR=*)       git_dir="${t#GIT_DIR=}"; continue ;;
          GIT_WORK_TREE=*) work_tree="${t#GIT_WORK_TREE=}"; continue ;;
        esac
      fi
      # 只認裸 token `git` 會被完整路徑繞過（/usr/bin/git push --force …）。
      # 去掉外層引號後，比對 git 可執行檔的常見型態。
      local bare="${t%\"}"; bare="${bare#\"}"; bare="${bare%\'}"; bare="${bare#\'}"
      case "$bare" in git|*/git|git.exe|*/git.exe) seen_git=1 ;; esac
      # `git -C <path>` 決定實際操作哪個 repo，payload 的 cwd 只是 shell 所在目錄。
      # 不看它就能用 `git -C ~/.agents push origin main` 從範圍外目錄推範圍內的 main
      # （Copilot 於 PR #42 指出）。同一個位移也會讓下方 [T0-3] 的當前分支解析查錯 repo，
      # 所以兩處共用同一個 effective cwd。
      if (( seen_git )); then
        if (( want_c ));      then dash_c="$t";    want_c=0;      continue; fi
        if (( want_wt ));     then work_tree="$t"; want_wt=0;     continue; fi
        if (( want_gitdir )); then git_dir="$t";   want_gitdir=0; continue; fi
        case "$t" in
          -C)            want_c=1; continue ;;
          -C?*)          dash_c="${t#-C}"; continue ;;
          --work-tree)   want_wt=1; continue ;;
          --work-tree=*) work_tree="${t#--work-tree=}"; continue ;;
          --git-dir)     want_gitdir=1; continue ;;
          --git-dir=*)   git_dir="${t#--git-dir=}"; continue ;;
        esac
      fi
      [[ $seen_git -eq 1 && "$t" == push ]] && seen_push=1
      continue
    fi
    case "$t" in
      --force-with-lease|--force-with-lease=*) has_lease=1 ;;
      -f|--force)                              has_force=1 ;;
      --all|--mirror)                          broad_refset=1 ;;
      # 短旗標捆綁（git push -fu origin main）——單獨比對 -f 會漏
      -[a-zA-Z]*)                              [[ "$t" == *f* ]] && has_force=1 ;;
      --*)                                     : ;;
      +*)                                      has_force=1; args+=("${t#+}") ;;
      *)                                       args+=("$t") ;;
    esac
  done
  (( seen_push )) || return 0

  # effective cwd = payload cwd 疊上 -C / --work-tree / GIT_WORK_TREE / --git-dir /
  # GIT_DIR。~ 要自己展開：hook 看到的是尚未交給 shell 的原始字串，波浪號還在。
  #
  # base 的順序很重要：git 依 token 順序處理 -C，所以 `git -C ~/.agents --git-dir .git`
  # 裡的 .git 是相對於 -C 後的目錄，不是相對於 payload cwd。一律用 cwd 當 base 會把它
  # 解成 ${CWD}/.git，範圍判定落空而漏擋（Copilot 於 PR #42 指出）。
  #
  # 相對路徑另外保留一個以 cwd 為 base 的候選：若上面對 git base 解析的理解有誤，
  # 第二個候選會兜住。範圍判定對候選取聯集（任一在範圍內就擋）——多擋的代價是一個
  # 誤擋，漏擋的代價是防線失效。
  local eff_cwd base
  base="${CWD:-.}"
  [ -n "$dash_c" ] && base=$(abs_path "$dash_c" "${CWD:-.}")

  local -a eff_cands=()
  add_cand() { [ -n "$1" ] && eff_cands+=("$1"); }

  if [ -n "$git_dir" ]; then
    eff_cwd=$(gitdir_root "$git_dir" "$base")
    add_cand "$eff_cwd"
    case "$git_dir" in /*|"~"|"~"/*) ;; *) add_cand "$(gitdir_root "$git_dir" "${CWD:-.}")" ;; esac
  elif [ -n "$work_tree" ]; then
    eff_cwd=$(abs_path "$work_tree" "$base")
    add_cand "$eff_cwd"
    case "$work_tree" in /*|"~"|"~"/*) ;; *) add_cand "$(abs_path "$work_tree" "${CWD:-.}")" ;; esac
  else
    eff_cwd="$base"
    add_cand "$eff_cwd"
  fi

  (( has_force )) && deny "[T0-3] 禁用非 lease force push（--force / -f / +refspec）。非保護分支請改用 --force-with-lease。"

  # [INT-10] 例外只認「本段開頭」的 INT10_ACK= 前綴。去前導空白後比對，因為複合命令
  # 切段後多半帶一個前導空格（`cd /x && INT10_ACK=r git push …`）。
  local lead="${seg%%[![:space:]]*}" seg_ack=0
  case "${seg#"$lead"}" in INT10_ACK=*) seg_ack=1 ;; esac

  # [INT-10] 判定必須在下面 has_lease 的早退之前——一般 push（無 force 無 lease）
  # 正是本條要擋的主要形態，放在早退之後等於永遠不執行。
  local in_scope=0 cand
  for cand in "${eff_cands[@]}"; do
    int10_in_scope "$cand" && { in_scope=1; break; }
  done
  if (( ! seg_ack )) && (( in_scope )); then
    if (( ${#args[@]} >= 2 )); then
      for ((i = 1; i < ${#args[@]}; i++)); do int10_check "${args[i]}"; done
    else
      # args 為 1 個時無法從位置區分 remote 與「省略 remote 的 refspec」——
      # `git push origin` 與 `git push HEAD:main` / `git push :master` 都長這樣。
      # 只當它是 remote 就會漏掉後兩者（Copilot 於 PR #42 指出）：args 只有 1 個時
      # 落到當前分支分支，當前分支不是 main 便放行，而實際推的是 main。
      # 兩者都查：當 refspec 查一次、再解析當前分支查一次。不會誤傷——remote 名
      # （origin 之類）不可能命中 main/master，命中的本來就該擋。
      (( ${#args[@]} == 1 )) && int10_check "${args[0]}"
      # 無明示 refspec：推的是當前分支。解析不出來時不擋——[T0-3] 那邊 fail-closed 是
      # 因為 force push 破壞性不可逆，這裡最壞情況只是漏擋一次可回復的 push。
      target=$(git -C "$eff_cwd" symbolic-ref --short HEAD 2>/dev/null || true)
      [ -n "$target" ] && int10_check "$target"
    fi
  fi

  (( has_lease )) || return 0
  (( broad_refset )) && deny "[T0-3] --force-with-lease 搭配 --all/--mirror 無法排除保護分支，已保守拒絕。"
  if (( ${#args[@]} >= 2 )); then
    # args[0] 是 remote，其餘每個 refspec 都要查——只查第一個是舊版的破口
    for ((i = 1; i < ${#args[@]}; i++)); do
      check_target "${args[i]}"
    done
  else
    target=$(git -C "$eff_cwd" symbolic-ref --short HEAD 2>/dev/null || true)
    [[ -z "$target" ]] && deny "[T0-3] --force-with-lease 未明示 refspec 且無法解析當前分支，保守拒絕（請明示 origin <branch>）。"
    check_target "$target"
  fi
  return 0
}

# 複合命令切段（; | & 皆為段界），只檢查含 git push 的段
IFS=$'\n'
for seg in $(printf '%s' "$CMD" | tr ';|&' '\n\n\n'); do
  case "$seg" in *git*push*) check_seg "$seg" ;; esac
done
exit 0

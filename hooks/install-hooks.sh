#!/usr/bin/env bash
# 安裝本 repo 的 git hooks 到 .git/hooks/（不變動 git config）。
# 新機器 clone 後執行：bash hooks/install-hooks.sh
# ~/.agents 與三個 host global-config repo：bash hooks/install-hooks.sh --global-pre-push
# 回復安裝前狀態：bash hooks/install-hooks.sh --remove-global-pre-push
#
# 安裝的 hook：
#   pre-commit    ← hooks/pre-commit-agents.sh
#   post-checkout ← hooks/post-checkout-agents.sh（離開 main 時警告三家 host 不一致）
#   pre-push      ← hooks/pre-push-global-config.sh（只有 --global-pre-push）
#
# 注意：hooks 存在 .git/hooks/ 而 .git 不進版控，所以這是**每台機器各自要跑一次**的
# 安裝步驟，不是自動生效的。linked worktree 共用 common dir 的 hooks，無需重裝。
set -euo pipefail

# hooks 目錄一律問 git，不要自己拼 "$(git rev-parse --show-toplevel)/.git/hooks"：
# 在 linked worktree 裡 .git 是**檔案**不是目錄（內容為 gitdir 指標），自己拼的路徑
# 會讓 mkdir 報 "Not a directory" 並在 set -e 下直接死掉。
# `--git-path hooks` 兩種情形都對，且在 worktree 內回傳共用的 common dir hooks
# （實測：worktree 內回傳 ~/.agents/.git/hooks，正是 git 實際會執行的位置）。
# 且路徑一律由**腳本自身位置**解析，不用 cwd：`--show-toplevel` 解析的是 **cwd** 的
# repo，所以從別的 repo 內以絕對路徑呼叫本腳本（`bash ~/.agents/hooks/install-hooks.sh`）
# 會去操作**那個** repo 的 .git/hooks——實測從 DCT 專案內呼叫，它試圖 `mkdir .git/hooks`
# 指向 DCT repo；本次只因 SRC_DIR 同樣跑掉（該 repo 無 hooks/）加上沙箱攔阻才沒真裝錯。
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR" && git rev-parse --show-toplevel)"
SRC_DIR="$REPO_ROOT/hooks"

blob_oid() {
  git -C "$REPO_ROOT" hash-object --no-filters -- "$1"
}

published_main_source() {
  local rel branch head upstream upstream_name actual_oid head_oid
  branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [ "$branch" = main ] || {
    printf '錯誤：global pre-push 只能從已同步的 main 安裝（目前：%s）\n' "${branch:-detached}" >&2
    return 1
  }
  for rel in hooks/install-hooks.sh hooks/pre-push-global-config.sh; do
    if [ ! -f "$REPO_ROOT/$rel" ] || [ -L "$REPO_ROOT/$rel" ]; then
      printf '錯誤：global pre-push 部署檔必須是實體檔案：%s\n' "$rel" >&2
      return 1
    fi
    head_oid="$(git -C "$REPO_ROOT" rev-parse "HEAD:$rel" 2>/dev/null || true)"
    actual_oid="$(blob_oid "$REPO_ROOT/$rel")" || return 1
    [ -n "$head_oid" ] && [ "$actual_oid" = "$head_oid" ] || {
      printf '錯誤：global pre-push 部署檔與 HEAD 不一致：%s\n' "$rel" >&2
      return 1
    }
  done
  head="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  upstream="$(git -C "$REPO_ROOT" rev-parse --verify '@{upstream}' 2>/dev/null || true)"
  upstream_name="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
  [ "$upstream_name" = origin/main ] && [ "$head" = "$upstream" ] || {
    printf '錯誤：main 必須與 origin/main 完全一致後才能部署 global pre-push\n' >&2
    return 1
  }
}

repo_hooks_dir() {
  local requested="$1" mode="$2" root hooks_dir hooks_parent common
  requested="$(cd "$requested" 2>/dev/null && pwd -P)" || return 1
  root="$(git -C "$requested" rev-parse --show-toplevel 2>/dev/null)" || return 1
  root="$(cd "$root" && pwd -P)" || return 1
  [ "$root" = "$requested" ] || {
    printf '錯誤：目標不是獨立 repo root：%s（實際 root：%s）\n' "$requested" "$root" >&2
    return 1
  }
  if [ "$mode" = install ]; then
    if git -C "$root" config --get core.hooksPath >/dev/null 2>&1; then
      printf '錯誤：偵測到自訂 core.hooksPath，拒絕安裝：%s\n' "$root" >&2
      return 1
    fi
    hooks_dir="$(git -C "$root" rev-parse --git-path hooks)" || return 1
    case "$hooks_dir" in /*) ;; *) hooks_dir="$root/$hooks_dir" ;; esac
  else
    # rollback 必須忽略安裝後才設定的 core.hooksPath，移除原本的 default hook。
    common="$(git -C "$root" rev-parse --git-common-dir)" || return 1
    case "$common" in /*) ;; *) common="$root/$common" ;; esac
    hooks_dir="$common/hooks"
  fi
  hooks_parent="$(cd "$(dirname "$hooks_dir")" && pwd -P)" || return 1
  hooks_dir="$hooks_parent/$(basename "$hooks_dir")"
  if [ -L "$hooks_dir" ] || { [ -e "$hooks_dir" ] && [ ! -d "$hooks_dir" ]; }; then
    printf '錯誤：拒絕非實體 hooks 目錄：%s\n' "$hooks_dir" >&2
    return 1
  fi
  printf '%s\n' "$hooks_dir"
}

managed_hook() {
  local dst="$1" stamp="$2" recorded actual
  [ -f "$dst" ] && [ ! -L "$dst" ] && [ -f "$stamp" ] && [ ! -L "$stamp" ] || return 1
  recorded="$(< "$stamp")"
  actual="$(blob_oid "$dst")" || return 1
  [ "$recorded" = "$actual" ]
}

install_global_pre_push() {
  local src="$SRC_DIR/pre-push-global-config.sh" repo hooks_dir dst stamp src_oid failed=0 i
  local -a targets=() stamps=()
  [ -f "$src" ] || { echo "錯誤：找不到 $src" >&2; return 1; }
  published_main_source || return 1
  src_oid="$(blob_oid "$src")" || return 1

  for repo in "$HOME/.agents" "$HOME/.claude" "$HOME/.codex" "$HOME/.copilot"; do
    if ! git -C "$repo" rev-parse --show-toplevel >/dev/null 2>&1; then
      printf '錯誤：必要 target 不是 Git repo：%s\n' "$repo" >&2
      failed=1
      continue
    fi
    repo="$(cd "$repo" && pwd -P)"
    hooks_dir="$(repo_hooks_dir "$repo" install)" || { failed=1; continue; }
    dst="$hooks_dir/pre-push"
    stamp="$hooks_dir/.pre-push-int10-managed"
    if [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -f "$dst" ]; } \
       || [ -L "$stamp" ] || { [ -e "$stamp" ] && [ ! -f "$stamp" ]; }; then
      printf '錯誤：拒絕覆寫既有 pre-push：%s\n' "$dst" >&2
      failed=1
      continue
    fi
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst" && ! managed_hook "$dst" "$stamp"; then
      printf '錯誤：拒絕覆寫既有 pre-push：%s\n' "$dst" >&2
      failed=1
      continue
    fi
    if [ -e "$stamp" ] && ! managed_hook "$dst" "$stamp"; then
      printf '錯誤：managed metadata 與 pre-push 不一致：%s\n' "$stamp" >&2
      failed=1
      continue
    fi
    targets+=("$dst")
    stamps+=("$stamp")
  done

  [ "${#targets[@]}" -gt 0 ] && [ "$failed" -eq 0 ] || return 1
  for i in "${!targets[@]}"; do
    dst="${targets[$i]}"
    stamp="${stamps[$i]}"
    mkdir -p "$(dirname "$dst")"
    install -m 0755 "$src" "$dst"
    printf '%s\n' "$src_oid" > "$stamp"
    printf '已安裝 pre-push → %s\n' "$dst"
  done
}

remove_global_pre_push() {
  local src="$SRC_DIR/pre-push-global-config.sh" repo hooks_dir dst stamp failed=0 i
  local -a targets=() stamps=()
  [ -f "$src" ] || { echo "錯誤：找不到 $src" >&2; return 1; }

  for repo in "$HOME/.agents" "$HOME/.claude" "$HOME/.codex" "$HOME/.copilot"; do
    if ! git -C "$repo" rev-parse --show-toplevel >/dev/null 2>&1; then
      printf 'SKIP  非 Git repo：%s\n' "$repo"
      continue
    fi
    repo="$(cd "$repo" && pwd -P)"
    hooks_dir="$(repo_hooks_dir "$repo" remove)" || { failed=1; continue; }
    dst="$hooks_dir/pre-push"
    stamp="$hooks_dir/.pre-push-int10-managed"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ] && [ ! -e "$stamp" ] && [ ! -L "$stamp" ]; then
      printf 'SKIP  pre-push 未安裝：%s\n' "$dst"
      continue
    fi
    if [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -f "$dst" ]; } \
       || [ -L "$stamp" ] || { [ -e "$stamp" ] && [ ! -f "$stamp" ]; }; then
      printf '錯誤：拒絕移除非本工具管理的 pre-push：%s\n' "$dst" >&2
      failed=1
      continue
    fi
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst" && ! managed_hook "$dst" "$stamp"; then
      printf '錯誤：拒絕移除非本工具管理的 pre-push：%s\n' "$dst" >&2
      failed=1
      continue
    fi
    targets+=("$dst")
    stamps+=("$stamp")
  done

  [ "$failed" -eq 0 ] || return 1
  for i in "${!targets[@]}"; do
    dst="${targets[$i]}"
    stamp="${stamps[$i]}"
    rm -f "$dst" "$stamp"
    printf '已移除 pre-push → %s\n' "$dst"
  done
}

case "${1:-}" in
  --global-pre-push)
    [ "$#" -eq 1 ] || { echo '錯誤：--global-pre-push 不接受其他參數' >&2; exit 2; }
    install_global_pre_push
    exit $?
    ;;
  --remove-global-pre-push)
    [ "$#" -eq 1 ] || { echo '錯誤：--remove-global-pre-push 不接受其他參數' >&2; exit 2; }
    remove_global_pre_push
    exit $?
    ;;
  -h|--help)
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
    exit 0
    ;;
  '') ;;
  *)
    printf '錯誤：未知參數：%s\n' "$1" >&2
    exit 2
    ;;
esac

hp="$(cd "$REPO_ROOT" && git rev-parse --git-path hooks)"
case "$hp" in
  /*) HOOKS_DIR="$hp" ;;
  *)  HOOKS_DIR="$REPO_ROOT/$hp" ;;
esac
mkdir -p "$HOOKS_DIR"

install_one() {
  local src="$SRC_DIR/$1" dst="$HOOKS_DIR/$2"
  [ -f "$src" ] || { echo "錯誤：找不到 $src" >&2; return 1; }
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "已安裝 $2 → $dst"
}

install_one pre-commit-agents.sh    pre-commit
install_one post-checkout-agents.sh post-checkout

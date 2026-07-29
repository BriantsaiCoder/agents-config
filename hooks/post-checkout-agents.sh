#!/usr/bin/env bash
# Warn when the live shared-skills checkout leaves main. Never auto-fix.

[ "${3:-0}" = "1" ] || exit 0

# Linked worktrees are isolated candidates and are intentionally silent.
gitdir="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
common="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
[ "$gitdir" = "$common" ] || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[ "$branch" = "main" ] && exit 0
[ "$branch" = "HEAD" ] && exit 0

cat >&2 <<EOF

⚠ shared skills：live ~/.agents 目前在 ${branch}（非 main）。

Claude、Codex、Copilot 會立即讀到這個 branch 的 workflow skills。
請切回 main，或改用 isolated worktree：
  git -C ~/.agents switch main
  ~/.agents/bin/agents-branch ${branch}

檢查：~/.agents/bin/agents-sync --doctor

EOF
exit 0

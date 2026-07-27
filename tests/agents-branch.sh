#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
TMP=$(mktemp -d)
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

echo "agents-branch isolated worktree PASS"

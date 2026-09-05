# Immutable review snapshot

Read before creating the review snapshot, and when a reviewer needs an ablation copy.

## Clean committed review

Resolve both the selected fixed point and HEAD to immutable commit SHAs. Preserve the user's original ref for the report; use only the resolved SHAs in commands and briefs:

```bash
base_sha=$(git rev-parse --verify '<fixed-point>^{commit}')
review_sha=$(git rev-parse --verify 'HEAD^{commit}')
git diff "$base_sha...$review_sha"
git log "$base_sha..$review_sha" --oneline
git worktree add --detach <snapshot-dir> "$review_sha"
```

Require successful ref resolution and a non-empty comparison before dispatch. An empty diff means no changes in that comparison, not a reviewed PASS; explain the scope and clarify only if the requested work is missing. Stop on any failed command. Place the snapshot outside the repository, in the OS temp directory or an agreed scratch location.

If the sandbox denies `.git/worktrees` writes, use `git clone --local --no-hardlinks <repo> <snapshot-dir>`, then `git -C <snapshot-dir> checkout --detach "$review_sha"`; require both to succeed. `--no-hardlinks` supports hosts that disallow hardlinks. Verify the snapshot HEAD matches `review_sha`.

## Dirty review

Before reading any raw dirty diff, complete the [dirty review package gate](../../dev-workflow/references/dirty-review-package.md): metadata inventory, all three applicable gitleaks scans, then package assembly. Findings block assembly. Include staged, unstaged, and eligible untracked/ignored candidates with the gate's secret, size and binary rules. Record immutable HEAD, package content hash, manifest and scan exit codes. Both axes receive that same immutable source package, not a commit-only snapshot omitting requested work. No checkpoint commit is required merely to review dirty work.

## Why isolate

A moving checkout makes line numbers and PASS results refer to different source states. A detached worktree preserves both content and Git metadata. An unchecked `git archive | tar` pipeline can hide the archive failure behind the final command's exit status; an extracted tree also cannot support Git-dependent checks. Copies inside the source tree can change status or fingerprints.

## Ablation ownership

The live worktree and the shared review snapshot/package are read-only to reviewers; this is a behavioral constraint, not an OS guarantee. Every ablation runs on the reviewer’s own separate copy. When checks require Git, create a detached worktree or local no-hardlinks clone instead of a plain directory copy. For dirty reviews, reproduce the exact scanned package in that private copy and verify its source identity before experiments. Never run an ablation in another axis's input or experiment directory. Report the original reviewed SHA/package hash independently of experimental changes.

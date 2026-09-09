---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **See the current state** of the merge/rebase. Check git history, and the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Continue within the authorized merge goal. If the required intents cannot both be preserved safely, report the concrete trade-off and pause only the dependent resolution; an authorized abort follows shared `dev-workflow` S6.

4. Discover the project's **automated checks** and run them — typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish within the agreed scope.** After applicable checks pass, stage only the explicit allowlist of resolved files. Commit or continue the merge/rebase only when that completion action is already authorized; otherwise report the prepared result. Shared `dev-workflow` S6 owns scoped staging, abort, and closeout; never use `git add -A`.

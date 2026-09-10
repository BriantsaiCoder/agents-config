# Setup write contract

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to add to whichever of `<workspace>/CLAUDE.md` / `<workspace>/AGENTS.md` is being edited (see step 4 for selection rules)
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md` (the last only when `triage` is installed)

Apply any requested changes to the draft. Once the exact output/host scope is authorized, write it without a second confirmation; unresolved target or policy changes still follow S2.

### 4. Write

**Pick the file to edit:**

- If `<workspace>/CLAUDE.md` exists, edit it.
- Else if `<workspace>/AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create — don't pick for them.

Never create `<workspace>/AGENTS.md` when `<workspace>/CLAUDE.md` already exists (or vice versa) — always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout — "single-context" or "multi-context"]. See `docs/agents/domain.md`.
```

Include the `### Triage labels` sub-block, and write `docs/agents/triage-labels.md`, only when `triage` is installed and Section B ran. When it isn't, both are omitted.

Then write the docs files using the seed templates in this skill folder as a starting point:

- [issue-tracker-github.md](../issue-tracker-github.md) — GitHub issue tracker
- [issue-tracker-gitlab.md](../issue-tracker-gitlab.md) — GitLab issue tracker
- [issue-tracker-local.md](../issue-tracker-local.md) — local-markdown issue tracker
- [triage-labels.md](../triage-labels.md) — label mapping (only if `triage` is installed)
- [domain.md](../domain.md) — domain doc consumer rules + layout

For "other" issue trackers, write `docs/agents/issue-tracker.md` from scratch using the user's description.

## Verification

Before declaring setup complete, verify each selected artifact exists at its authorized path, parses where applicable, has valid links, and can be read by the intended consumer. Run relevant existing checks and record command/exit evidence; mark unavailable checks explicitly. Do not add hooks/config checks when those artifacts were not selected.

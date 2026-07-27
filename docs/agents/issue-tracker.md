# Issue tracker fallback contract

Use this global contract only when the repository has no `docs/agents/issue-tracker.md`. A repo contract always wins.

## Carrier selection

- GitHub remote + working `gh`: use GitHub Issues.
- Otherwise use local markdown under `sdd/<slug>/tickets/`.
- `.scratch/` is forbidden; it must not become a second persistence convention.

## Operations

| Operation | GitHub carrier | Local carrier |
|---|---|---|
| Publish | `gh issue create` | create `sdd/<slug>/tickets/<NN>-<slug>.md` |
| Fetch | `gh issue view <n> --comments` | read the referenced ticket file |
| Comment | `gh issue comment <n> --body ...` | append under `## Comments` |
| Close | `gh issue close <n> --comment ...` | set `Status: resolved` |

Local tickets begin with:

```text
Category: bug|enhancement
Type: research|prototype|grilling|task
Status: needs-triage|needs-info|ready-for-agent|ready-for-human|wontfix|claimed|resolved
```

## Roles and labels

Category roles are `bug` and `enhancement`.

| State role | Actual GitHub label |
|---|---|
| `needs-triage` | `needs-triage` |
| `needs-info` | `needs-info` |
| `ready-for-agent` | `ready-for-agent` |
| `ready-for-human` | `ready-for-human` |
| `wontfix` | `wontfix` |

PRs as a triage request surface: **off**.

## Wayfinder

- **Map**: one GitHub issue labelled `wayfinder:map`, or `sdd/<slug>/map.md`.
- **Child**: a GitHub sub-issue, or `sdd/<slug>/tickets/<NN>-<slug>.md`.
- **Blocking**: native GitHub dependency, or `Blocked by: <ticket ids>`.
- **Claim**: assign the GitHub issue to the current user, or set `Status: claimed`.
- **Frontier**: first open, unblocked, unclaimed child in map order.
- **Resolve**: comment/close the GitHub child, or add `## Answer` and set `Status: resolved`; then update the map.
- `Type:` is one of `research`, `prototype`, `grilling`, or `task`.

## Canonical artifacts

- Specs: `docs/agents/specs/`
- Plans: `docs/agents/plans/`
- Lightweight work: `sdd/<slug>/`
- Single context: root `CONTEXT.md` + `docs/adr/`
- Multi-context: root `CONTEXT-MAP.md` points to each context’s `CONTEXT.md`

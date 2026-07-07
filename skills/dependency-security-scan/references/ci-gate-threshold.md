# CI Gate Threshold

Recommended defaults. Any deviation (e.g. accepted critical CVE awaiting upstream fix) requires a written exception with **owner + expiry date** in the repo.

| Finding | Action |
|---|---|
| Secret detected (any severity) | **Block merge** — rotate credential, re-run history scan |
| Dependency CVE: critical / high | **Block merge** — patch, pin, or document accepted risk with expiry |
| Dependency CVE: medium | **Warn** — schedule fix within sprint |
| Dependency CVE: low | Track in backlog |
| Container OS package: critical / high | **Block merge** — update base image |
| Container application layer: critical / high | **Block merge** |
| SBOM missing on release | **Block release** — must accompany every published artifact |

## Failure Response Patterns

- **Secret found post-merge** → revoke credential, force-rotate, scan all branches, add to gitleaks rules to prevent regression.
- **New CVE in production dependency** → check exploitability against your usage path, patch or pin, document in changelog.
- **Container CVE only in unused OS package** → still patch on next image rebuild, do not silently accept.

## Exception Process

Accepted CVE entries must include:
- Owner (engineer or team)
- Expiry date
- Re-review trigger (e.g. upstream fix released, version bump)
- Rationale (why exploit path is not reachable in this codebase)

Treating "high CVE acceptable for now" as permanent without expiry is the most common drift failure.

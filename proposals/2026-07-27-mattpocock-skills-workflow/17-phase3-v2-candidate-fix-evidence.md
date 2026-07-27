# Phase 3 v2 cross-repo candidate fix

> Observation window: **2026-07-27 19:03–19:26 Asia/Taipei**. Isolated candidate only; no live deployment, setup/link script, vendored payload edit, delegation, or Superpowers removal.

## Root cause and regression

The first deployment exposed a second routing source in `~/.claude/CLAUDE.md`: its hand-written `Workflow default` line still named the replaced Superpowers/mp routes outside the generated `agents-routing` block. Phase 3 had verified the managed block and generated Codex/Copilot bodies, but had no pre-deploy assertion for this unmanaged Claude text.

`tests/claude-routing-collision.sh` now ignores the managed block and rejects the retired workflow route names elsewhere. It is wired into:

- `agents-sync` lint rule 8, so the wrong cross-repo pairing stops before deployment;
- local `tests/conformance.sh`, so deployment readback catches recurrence;
- CI `--selftest`, so the probe cannot silently stop detecting its own fixture.

RED against live rollback state:

```text
FAIL  Claude unmanaged routing collision：line 19
exit=1
```

GREEN against the paired Claude candidate:

```text
PASS  Claude unmanaged routing collision = 0
exit=0
```

The paired `agents-sync --check` passes. Running the same candidate against the still-unfixed live Claude file intentionally fails lint rule 8; this is the deployment-order guard, not a candidate failure.

## Verification

| Gate | Result |
|---|---|
| Claude collision selftest | PASS |
| Paired-candidate `agents-sync --check` | PASS; Codex 8425B, Copilot 9165B |
| Matt workflow contracts | 54 PASS / 0 FAIL |
| Vendored detection | 33 PASS / 0 FAIL |
| Git push guard | 68 PASS / 0 FAIL |
| Version tripwire | 44 clear; selftest 44 trigger / 0 stale |
| Scratch deploy body + Claude stamp comparison | PASS |
| Local conformance with paired Claude candidate | 16 PASS / 0 FAIL |
| `bash -n` for changed shell files | PASS |
| Local `shellcheck -S error` | UNAVAILABLE: executable is not installed; CI gate remains configured |

Delegation/reviewer-agent execution is **SKIPPED** by explicit user scope. Diff review is performed inline before commit.

## Candidate commits

### `~/.agents`

Branch `codex/mattpocock-workflow-migration-v2`, based on rollback baseline `678ab6d`:

1. `d543d7c` — Phase 1 stable-22 import.
2. `42b4f66` — Phase 2 carriers/contracts.
3. `c0b6371` — Phase 3 Matt routing switch.
4. The commit containing this document — collision probe, lint/conformance/CI wiring, and v2 evidence.

### `~/.claude`

Branch `codex/mattpocock-workflow-migration-v2`, based on `20554ed`:

1. `8986be3` — replace the duplicated hand-written route list with one neutral canonical-source sentence.
2. `1519436` — align the managed stamp with the v2 `core/routing.md`.

The two Claude commits are intentionally separate so deployment never exposes a new route before the corresponding skills exist.

## Byte budget

| Surface | Live rollback | Paired v2 candidate | Delta | Limit |
|---|---:|---:|---:|---:|
| Codex generated body | 8563B | 8425B | -138B | 10240B |
| Copilot generated body | 9303B | 9165B | -138B | 10240B |
| Claude file + core tier0–2 | 15009B | 14370B | -639B | 20480B |

## Atomic deployment gate

Do not execute until the user confirms the revised candidate.

1. Revalidate exact live heads, dirty-file attribution, backups, and probe RED.
2. Fast-forward `~/.claude/main` only to `8986be3`; verify collision probe GREEN while the old managed stamp remains.
3. Fast-forward `~/.agents/main` to the v2 candidate head; verify lint with live Claude.
4. Fast-forward `~/.claude/main` to `1519436`; verify the stamp equals v2 `core/routing.md`.
5. Run `agents-sync --bootstrap`, `--doctor`, local conformance, byte budgets, and fresh-host canaries.
6. Stop on any failure. Phase 6 and every Superpowers removal remain out of scope.

This order keeps every intermediate state usable: the duplicate disappears first; the new skills exist before the new managed routes become active; bootstrap then becomes an idempotent readback/deployment step.

## Rollback

- Before step 3: revert `8986be3` in `~/.claude`; no `.agents` rollback is needed.
- After step 3: revert the v2 `~/.agents` commits in reverse order, revert `1519436` then `8986be3` in `~/.claude`, run live `agents-sync --bootstrap`, and verify doctor/conformance.
- If generated host files are partially written, restore the mode-0600 pre-deploy backups before the final bootstrap/readback.
- Never reset, force-push, modify `settings.json`, or remove Superpowers during rollback.

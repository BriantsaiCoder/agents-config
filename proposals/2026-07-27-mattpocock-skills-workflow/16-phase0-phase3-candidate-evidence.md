# Phase 0–3 isolated candidate evidence

> Scope: isolated candidate only; no live deployment, setup script, vendored payload edit, delegation, or Superpowers removal.

## Phase 0 revalidation

Observation window: **2026-07-27 18:26–18:29 Asia/Taipei**.

| Surface | Observation |
|---|---|
| `~/.agents` | `main` at `19be2eb545d61c9a0866fff0784c5d0de2b01f3f`; ahead of `origin/main` by 4; target source files clean; proposal documents 10–14 untracked |
| `~/.claude` | `main` at `20554ed154029bb39b55edfb6b1188098fc2750a`; `settings.json` dirty; Claude Code 2.1.220; Superpowers enabled, cache 6.2.0 |
| `~/.codex` | `main` at `bd1195dbee85b405b959a387b59f64d5449ab581`; generated `AGENTS.md` dirty; codex-cli 0.145.0; model `gpt-5.6-sol`, effort `high`; Superpowers enabled, cache 6.2.0 |
| `~/.copilot` | `main` at `4b47fee53c68644f1dbcd75136440c01fda09f9d`; generated `copilot-instructions.md` dirty; both fixed executables report CLI 1.0.75; Superpowers 6.2.0 enabled |
| Copilot inventory | 128 total: builtin 1, personal-agents 50, plugin 77, disabled 0; `dynamicRetrieval.skills` and `disabledSkills` unset; list schema exposes `description,enabled,name,path,source` |
| Upstream | `ed37663cc5fbef691ddfecd080dff42f7e7e350d`; manifest SHA-256 `e712cc026f5e78058067d17cd1fdf9665388d70db59dc50688286cb029e38eba`; 22 unique skill basenames |
| Live generated state | `agents-sync --check` PASS: Codex 8563B, Copilot 9303B; `agents-sync --doctor` PASS |

Copilot context-level description coverage was probed twice with the fixed executable, model, and effort. Both attempts returned no stdout/stderr and no usable exit status, so the probe is **UNAVAILABLE**. This blocks live canary/deployment approval, not isolated candidate construction.

The candidate lives at `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration` on `codex/mattpocock-workflow-migration`. The live checkout remained on `main`. Delegation was **SKIPPED** because the user explicitly withheld it.

## Phase 3 proposed deployment

Generated only under `/private/tmp/agents-candidate-deploy-phase3`:

| Host | Live bytes | Candidate bytes | Delta | Candidate manifest SHA-256 |
|---|---:|---:|---:|---|
| Codex | 8563 | 8425 | -138 | `cbd3281295812b2b2d5483b59e98bc878f15a0da41088cedbc06d55645f50434` |
| Copilot | 9303 | 9165 | -138 | `e8902ea6c19e04d510d04ae1000bd448de18257fd0c0ea991a837bb102d547d7` |

The proposed diff adds `[T1-10]`, switches model routes to Matt invocation-on skills, exposes the two explicit user entries, and changes closeout to action-triggered gates. No tier0 rule changes.

### Dirty-hunk attribution and rollback carrier

The live generated files contain only a generated banner and routing-source drift relative to their host repos; `agents-sync --doctor` proves they match current live `~/.agents` source. They are generated deployment state, not candidate-owned source edits:

| Live file | Before SHA-256 | Mode | Attribution |
|---|---|---:|---|
| `~/.codex/AGENTS.md` | `440f7de45fe2abb3f22a033fbb761006a16bbb51b06e66e9c6bb228c1f688a5a` | 0644 | current live `agents-sync` output |
| `~/.copilot/copilot-instructions.md` | `82270ddece743bec09b61fd2135e99cbcc1845aab4d2faf8ab353b744051afe3` | 0644 | current live `agents-sync` output |

Before any deployment, copy both files to a mode-0600 timestamped backup directory outside the repositories and record their hashes. A partial deploy must restore both backups atomically, then run live `agents-sync --doctor` and `tests/conformance.sh`. Source rollback is a reverse-order `git revert` of the Phase 3, Phase 2, and Phase 1 commits followed by `agents-sync --bootstrap`; never reset or force-push `main`.

`~/.claude/settings.json` is unrelated pre-existing dirty state and remains untouched.

## Post-confirmation canary design

Do not run until the user says **部署 candidate**:

1. Integrate the three candidate commits into live `~/.agents/main`, create the two deployment backups, run `agents-sync --bootstrap`, `--doctor`, and local conformance.
2. In fresh Claude, Codex, and Copilot sessions, record intended vs actual skill for implicit prompts targeting `grilling`, `domain-modeling`, `codebase-design`, `diagnosing-bugs`, and `tdd`.
3. Verify `/grill-with-docs` and `/improve-codebase-architecture` as explicit prompt entries; do not run `setup-matt-pocock-skills`.
4. Verify invocation-off skills do not model-route implicitly. Codex must use the actual `$HOME/.agents/skills` policy; Copilot must record fixed-version observed behavior even if `skill list --json` omits invocation metadata.
5. Repeat Copilot description-coverage and dynamic-retrieval probes. Any unavailable/failed host-specific gate stops that host’s canary and leaves Superpowers installed and enabled.

Phase 6 is outside this candidate. No host may remove Superpowers until all host-agnostic and applicable host gates pass and the user confirms again.

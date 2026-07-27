# Superpowers helper ledger

> Candidate observation: 2026-07-27 18:38 Asia/Taipei. `rg` outside proposals/attic/backups found no active caller for these helpers. The DCT repo retains 50 files under `.superpowers/sdd/`; those artifacts are preserved and are not executable consumers.

| Capability | Helper | Candidate action | Evidence / reason |
|---|---|---|---|
| SDD workspace ledger | `sdd-workspace` | drop after Superpowers retirement | Existing artifacts remain readable; neutral workflow uses `sdd/<slug>/`, and no active caller invokes the helper |
| Per-task brief | `task-brief` | drop after Superpowers retirement | No active caller; Matt tickets + host todo carry the brief |
| Review diff package | `review-package` | drop after Superpowers retirement | No active caller; S5 reviews a pinned git diff directly |
| Test pollution search | `find-polluter.sh` | drop after Superpowers retirement | No active caller; retain the capability only if a real pollution incident proves the need |
| Brainstorm preview server | `start-server.sh`, `stop-server.sh`, `helper.js` | drop after Superpowers retirement | No active caller or generated preview artifact |
| Graph rendering | `render-graphs.js` | drop after Superpowers retirement | No active caller; fixed skill-section/Graphviz authoring policy is retired |

No helper is re-homed in Phase 1–3: copying unused executable payload would create a second vendored maintenance surface without a consumer. Re-home only if a canary or live task produces an explicit failing capability gap.

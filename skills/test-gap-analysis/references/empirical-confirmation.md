# Empirical confirmation

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

## 3. Optional empirical confirmation

Static reasoning can produce false survivors. Enter empirical mode only with **explicit mutation authorization**; an analysis or review request alone is not authorization to edit production code.

1. **Isolate and fingerprint.** Create an isolated temporary copy or worktree from the target HEAD. Record the original production-file hashes and package manifest. Never mutate the user's active checkout.
2. **Establish a bounded green baseline.** Run the full affected test suite (`dotnet test <affected-project>`, `pytest <affected-suite>`, `npm test`, `go test ./...`, `cargo test`, …) inside that isolation and record the pass count and elapsed duration. Before each mutation, also time its exact narrow command while unmutated. Every empirical test command needs a finite runner/host timeout that can terminate the spawned test process tree; use an existing native mechanism and stay static if none is available. Set each mutant timeout from the corresponding unmutated duration: `duration × 2 + 30 seconds`, or a larger project-owned bound, and record the calculation. Missing timing evidence, a baseline timeout, or a baseline failure stops empirical work; do not repair project wiring as part of this analysis.
3. **Apply one candidate mutation** to the isolated production file.
4. **Triage narrowly, certify broadly.** Run the narrowest covering tests first under its calibrated narrow-command timeout. A relevant assertion failure kills the mutant; compile/setup failures remain unverified. On timeout, terminate and wait for the spawned test process tree, classify the mutant **TimedOut** (detected/killed), and continue directly to cleanup. If narrow tests stay green, run the full affected test project or suite under its separately calibrated full-suite timeout; only a fully green affected suite confirms **Survived**.
5. **Always undo and prove cleanup.** After green, red, error, or timeout, apply the inverse edit with the same editing tool, then require the production-file hashes to match the baseline before the next mutation. If process-tree termination or cleanup cannot be proven, stop and leave the isolation intact for recovery. Do **not** use `git stash`, `git stash -u`, `git checkout --`, or `git restore`; those can affect unrelated worktree state.
6. **Close the isolation.** Re-run the full affected suite, confirm the package manifest has no unexpected diff, and then remove the temporary copy/worktree.
7. **Report what ran.** State the affected-suite command and timeout, empirical killed/timed-out counts, mutation score, and cleanup/hash evidence.

Without authorization, isolation, a green baseline, or a runnable suite, stay in static mode: label each candidate **unverified (static reasoning)**, downgrade confidence, and do not publish a mutation score.

## Evidence labels and scoring

Only executed evidence supports **Killed**, **TimedOut**, **Survived**, or verified **No coverage**. Killed requires a relevant test failure, not a compile/setup failure; errors without a meaningful verdict remain unverified. TimedOut requires calibrated timing and confirmed process-tree termination. Survived requires a green full affected suite while mutated. Claim No coverage only with execution evidence for that path, otherwise retain the static candidate label.

For a completed empirical run, report commands, pass counts, durations, timeout calculations, per-mutant outcomes and final restoration/hash evidence. Exclude equivalents and unresolved invalid/error outcomes from the score and disclose their counts; an incomplete run cannot certify all candidates.

`Mutation score = (Killed + TimedOut) / (Killed + TimedOut + Survived + No coverage)`

If that denominator is zero, report `Mutation score: N/A`; omit percentages and threshold judgments. Scores apply only to the evaluated sample and stated test scope.

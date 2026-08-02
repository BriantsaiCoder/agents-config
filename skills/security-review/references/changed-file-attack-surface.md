# Changed-file attack-surface ledger

Use this working ledger only for branch/diff security reviews. Findings still
follow `report-format.md` and remain grouped by vulnerability category.

1. Resolve and state the comparison base or merge-base.
2. Enumerate every changed file, including generated files and documentation.
3. For each file, record relevant inputs and trust boundaries:
   - database reads/writes;
   - authentication, authorization, object ownership, and session/state changes;
   - external calls, file/process access, serialization, and dynamic execution;
   - secrets, cryptography, unbounded resources, concurrency, and error paths.
4. Mark files without boundary-relevant behavior as `no attack surface`; mark
   generated or excluded files as `skipped` with a reason. Never omit a file.
5. Reconcile the ledger before reporting:

```text
mapped + no-attack-surface + skipped-with-reason == changed-file total
```

Use the ledger to prove coverage, not to manufacture findings. Report only
self-verified, exploitable risks, then append the compact per-file coverage
ledger required by `report-format.md`.

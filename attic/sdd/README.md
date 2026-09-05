# SDD archive — 2026-09-05

Historical source preserved byte-for-byte from baseline `017c0017b2e305f45b019b184ae7aaf4bec75617`; not an active skill. Relative links in the preserved SKILL.md describe its former `skills/sdd/` location.

Small tasks now use dev-workflow S0/S2 session acceptance criteria. Optional existing `sdd/<slug>/` artifacts and archive behavior are owned by `skills/dev-workflow/references/sdd-artifacts.md`. Existing project artifacts are not moved by this migration.

Rollback: restore this folder to `skills/sdd/` together with the baseline routing and trigger/test callers; remove this archive note. Do not restore only the former invocation route. Host-local aliases and symlinks must be reconciled during a separately authorized live cutover.

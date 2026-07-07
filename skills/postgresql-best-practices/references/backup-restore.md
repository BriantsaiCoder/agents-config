# PostgreSQL Backup and Restore

## Backup Tool Selection

| Tool | Use Case |
|------|----------|
| `pg_dump` | Logical backup of one DB; portable across versions/OS |
| `pg_dumpall --globals-only` | Roles/tablespaces — run alongside per-DB `pg_dump` |
| `pg_basebackup` | Physical base backup; required for PITR and streaming replicas |
| WAL archiving | Continuous incremental; pair with `pg_basebackup` for PITR |
| `pgBackRest` / `Barman` | Production orchestration: parallelism, retention, delta restores |

Rule of thumb:
- < 100 GB, portability matters → `pg_dump` nightly.
- Large / HA / RPO < 1h → `pg_basebackup` + WAL archiving managed by pgBackRest.

## pg_dump and pg_restore

Prefer custom (`-Fc`) or directory (`-Fd`) format — they support parallel and selective restore plus compression. Avoid plain SQL (`-Fp`) for large DBs.

```bash
# Parallel directory dump
pg_dump -h db.example.com -U backup_user -d app \
        -Fd -j 4 -Z 9 -f /backups/app-$(date -u +%Y%m%dT%H%M%SZ)

# Parallel restore
pg_restore -h new-db -U admin -d app_restore \
           -j 4 --clean --if-exists /backups/app-20260420T030000Z

# Selective restore
pg_restore -t orders -d app_restore /backups/app-20260420T030000Z
```

Key flags: `-j N` parallel workers (dir format only); `-Z 0-9` compression; `--no-owner --no-privileges` for cross-env restores; `--clean --if-exists` for idempotent re-runs; `-L list.txt` to restore a subset (export list with `pg_restore -l`).

## Point-in-Time Recovery (PITR)

1. Enable WAL archiving on the primary:
   ```
   wal_level = replica
   archive_mode = on
   archive_command = 'test ! -f /wal-archive/%f && cp %p /wal-archive/%f'
   ```
2. Take a base backup: `pg_basebackup -D /backups/base -Ft -Xs -z -P`.
3. To restore to a point in time, put base backup in data dir and add `recovery.signal` + `restore_command` + `recovery_target_time = '2026-04-20 12:00:00+00'` in `postgresql.conf`.
4. Start the cluster — it replays WAL until the target, then promotes.

For any RPO below a few minutes, use pgBackRest/Barman rather than rolling your own WAL scripts.

## Automation, Retention, Validation

Schedule via cron / systemd timer off-peak. Credentials via `~/.pgpass` or secret manager, not CLI args. Pipe through `gpg --encrypt` before shipping off-host; store keys in a separate system (KMS / Vault).

Retention tiers: 7 daily + 4 weekly + 12 monthly + off-site cold for compliance. Monitor backup duration, size trend, last-success timestamp — alert on drift.

**Unverified backups are not backups.** Automate a weekly restore into a throwaway environment and run a smoke test (SELECT counts on key tables + application health check).

## Pitfalls

- **UNLOGGED tables** — truncated on crash, not included in `pg_basebackup`. Don't rely on them surviving restore.
- **Materialized views** — dumped as empty shells by default; `REFRESH MATERIALIZED VIEW` post-restore.
- **Extensions** — `pg_dump` records `CREATE EXTENSION` but not contents; ensure same versions on restore targets.
- **Large BYTEA** — inflates dump size dramatically; consider external storage (S3) with only metadata in the DB.

See also `mysql-best-practices/references/backup-restore.md` for mysqldump / XtraBackup.

# MySQL Backup and Restore

## Backup Tool Selection

| Tool | Type | Use Case | Notes |
|------|------|----------|-------|
| `mysqldump` | Logical | Small/medium DBs, portability, selective restore | Single-threaded, slower on large data |
| `mysqlpump` | Logical | Parallel logical dump | 5.7+; less feature-complete than mysqldump |
| `mysqlsh` util.dumpInstance | Logical | MySQL 8.0+ official parallel dump | Fastest logical option; compresses, chunks |
| Percona XtraBackup | Physical | Large DBs, hot backup, PITR | Open source; non-blocking for InnoDB |
| MySQL Enterprise Backup | Physical | Commercial alternative to XtraBackup | Requires Enterprise license |
| Binary logs (`binlog`) | Incremental | Point-in-time recovery | Combine with a full backup |

Rule of thumb:
- < 50 GB, restore time not critical → `mysqldump` nightly + binlog.
- 50 GB – several TB, RPO < 1h → XtraBackup weekly full + daily incremental + binlog.
- MySQL 8.0+ and want the maintained modern logical tool → `mysqlsh util.dumpInstance`.

## mysqldump Essentials

```bash
mysqldump \
  -h db.example.com -u backup_user -p \
  --single-transaction \
  --quick \
  --routines --triggers --events \
  --set-gtid-purged=OFF \
  --default-character-set=utf8mb4 \
  --databases app \
  | gzip -9 > /backups/app-$(date -u +%Y%m%dT%H%M%SZ).sql.gz
```

Flags that matter:
- `--single-transaction` — consistent snapshot for InnoDB without locking tables. **Do not combine with `--lock-tables`.** Required unless every table is MyISAM (which you should not have).
- `--quick` — stream rows instead of buffering in RAM.
- `--routines --triggers --events` — include stored programs; omitted by default.
- `--set-gtid-purged=OFF` — unless you're restoring into a replication topology.
- `--master-data=2` — write binlog coordinates as a comment (useful for provisioning replicas).
- `--default-character-set=utf8mb4` — guard against silent utf8 (utf8mb3) truncation.
- `--no-tablespaces` — for users without `PROCESS` privilege in 8.0.21+.

**Do not** use `--lock-all-tables` in production: it freezes the whole server.

## mysqlsh (MySQL Shell) Dump — 8.0+ Preferred

```bash
mysqlsh --uri backup_user@db.example.com -- \
  util dumpInstance /backups/app-$(date -u +%Y%m%dT%H%M%SZ) \
  --threads=8 --compression=zstd --ocimds=false
```

Parallelizes per-table, chunks large tables, writes a manifest. Restore with `util.loadDump()` at similar speed.

## Restore

```bash
# From mysqldump .sql.gz
zcat /backups/app-20260420T030000Z.sql.gz \
  | mysql -h new-db -u admin -p

# From mysqlsh dumpInstance
mysqlsh --uri admin@new-db -- util loadDump /backups/app-20260420T030000Z --threads=8
```

For large XtraBackup physical restores: `xtrabackup --prepare --target-dir=/backups/full` then copy back and `chown mysql:mysql` before starting the server.

## Point-in-Time Recovery with Binlogs

1. Ensure binlog is enabled and retained long enough:
   ```ini
   log_bin = /var/log/mysql/mysql-bin.log
   binlog_format = ROW
   binlog_expire_logs_seconds = 604800   # 7 days
   sync_binlog = 1
   ```
2. Restore the most recent full backup.
3. Replay binlogs up to the target time:
   ```bash
   mysqlbinlog \
     --start-datetime="2026-04-20 02:00:00" \
     --stop-datetime="2026-04-20 12:34:56" \
     mysql-bin.000123 mysql-bin.000124 \
     | mysql -u admin -p
   ```
4. For topology-aware PITR, replay between GTIDs instead of datetimes.

## Automation, Retention, Validation

Credentials in `~/.my.cnf` or `/etc/mysql/backup.cnf` with `chmod 600` (never on the CLI — visible in `ps`). Pipe through `gzip` then `gpg --encrypt` before shipping off-host; keys stored separately (KMS / Vault).

Schedule via cron / systemd off-peak; hold a lock file to prevent overlap. Retention: 7 daily + 4 weekly + 12 monthly + off-site cold for compliance. Monitor last-success timestamp, dump size delta, restore time — alert on regression.

**Unverified backups are not backups.** Weekly restore into a throwaway instance + smoke test (row counts on key tables, app health check).

## Pitfalls

- **`--single-transaction` only snapshots transactional engines.** Any MyISAM table in the dump is inconsistent — migrate it to InnoDB (see golden rule #7).
- **Character set** — always pass `--default-character-set=utf8mb4` on dump and restore. Without it a client defaulting to the 3-byte `utf8` silently truncates 4-byte code points (emoji, rare CJK) round-trip.
- **GTID in replication** — omit `--set-gtid-purged=OFF` when provisioning a replica; include it for standalone restores.
- **`mysqldump` is single-threaded** — at multi-hundred-GB scale, switch to `mysqlsh util.dumpInstance` or XtraBackup.

See also `postgresql-best-practices/references/backup-restore.md` for pg_dump / WAL / PITR.

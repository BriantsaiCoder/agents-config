---
name: ef-core-best-practices
description: 'Use when writing or reviewing EF Core data access — Microsoft.EntityFrameworkCore DbContext/DbSet, Include/ThenInclude, projection, AsNoTracking, migrations, FromSqlRaw/FromSqlInterpolated, optimistic concurrency, change tracking, query performance, or N+1 fixes.'
---

# Entity Framework Core Best Practices

EF Core only — `System.Data.Entity` (EF6), Dapper, and plain ADO.NET fall outside.

## Mode

1. **Writing** — apply Golden Rules proactively. Don't ask before using `AsNoTracking` on read paths or `Select` projection; just do it and briefly explain *why* if it differs from the user's draft.
2. **Reviewing** — walk the rules as a checklist. Prioritize security (raw SQL injection) → correctness (DbContext lifetime, threading, migrations) → performance (N+1, tracking, projection).

## Golden Rules

Each rule's *why* + writing/reviewing patterns live in `references/rules-expanded.md`.

1. **Scoped or `IDbContextFactory`, never Singleton.** *Why:* DbContext is not thread-safe; singleton across requests = corruption.
2. **`AsNoTracking()` for read-only queries.** *Why:* tracking snapshots cost 20–35% + memory for nothing on read path.
3. **`Select` to project columns.** *Why:* full-entity returns transfer unused columns; large `text`/`varbinary` blow up cheap queries.
4. **Navigation properties + `Include`/`ThenInclude`; deep loads → `AsSplitQuery()`.** *Why:* missing nav = manual joins; lazy/loop access = N+1; deep `Include` = cartesian explosion.
5. **Async + `CancellationToken` end-to-end.** *Why:* sync EF blocks threadpool; CT releases connections on client disconnect.
6. **Never share DbContext across threads.** *Why:* no internal locking; identity-map races, silent corruption.
7. **No `Database.Migrate()` at startup.** *Why:* scaled deploys race on `__EFMigrationsHistory`; runtime user needs schema rights = least-privilege violation.
8. **Parameterize raw SQL** — `FromSqlInterpolated` or `FromSqlRaw` with `@param`. *Why:* string concat into raw SQL = SQLi.
9. **`ExecuteUpdate` / `ExecuteDelete` for bulk** (EF Core 7+). *Why:* avoids load-mutate-save round trips.
10. **Fluent API for column types, lengths, precision, indexes.** *Why:* conventions default `nvarchar(max)`, `decimal(18,2)`, no useful indexes.
11. **`AddDbContextPool<T>` for high-throughput.** *Why:* reuses context instances; eliminates per-request allocation under load.
12. **Handle `DbUpdateException` / `DbUpdateConcurrencyException`.** *Why:* swallowed exception hides constraint failures; ignored concurrency = lost updates.

## Reference Map

| Need | File |
|---|---|
| Why behind each rule + writing / reviewing patterns | `references/rules-expanded.md` |
| DI registration (scoped, factory, pool), Blazor Server, background services, `IServiceScopeFactory` | `references/dbcontext-lifecycle.md` |
| N+1 detection, `Include`/`ThenInclude`, tracking trade-offs, projection, split queries, compiled queries, global filters, raw SQL | `references/query-performance.md` |
| Change tracker internals, `SaveChanges` batching, optimistic concurrency, `ExecuteUpdate`/`ExecuteDelete`, bulk insert, exception handling | `references/change-tracking-saving.md` |
| Migration deployment, Fluent API config, TPH/TPT/TPC inheritance, owned types, compiled models | `references/migrations-modeling.md` |

Open one file at a time — don't preload.

# EF Core Golden Rules — Expanded

The Why behind each rule.

## 1. Scoped or `IDbContextFactory`, never Singleton

`AddDbContext<T>` (scoped) for web apps. `AddDbContextFactory<T>` for Blazor Server, background services, parallel branches.

**Why**: DbContext is not thread-safe. Singleton across concurrent requests → `InvalidOperationException`, corrupted change-tracker state, undiagnosable data integrity failures under load.

## 2. `AsNoTracking()` for read-only queries

Or `UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking)` on read-heavy contexts.

**Why**: Tracking snapshots every loaded entity. Read-only path → 20–35% slower + memory pressure for nothing. NoTracking also prevents accidental persistence of stale state.

## 3. Project columns via `Select`

Map to DTO / anonymous type before materialize.

**Why**: Selecting full entities transfers unused columns; large `text` / `varbinary` make fast queries orders of magnitude slower. EF translates `Select` to column-level SQL.

## 4. Navigation properties + `Include`/`ThenInclude`

Every FK gets a navigation property. Eager load with `Include`/`ThenInclude`. Deep eager loads → split queries (`AsSplitQuery()`).

**Why**: FK without nav property forces manual joins or second queries. Lazy/loop access = N+1 (1k rows = 1k extra queries). Deep `Include` = cartesian explosion → split query.

## 5. Async + `CancellationToken`

`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`, `ExecuteUpdateAsync`. Forward CT through every signature.

**Why**: Sync EF Core blocks threadpool for full DB round-trip → starvation under load. CT propagation releases connections when client disconnects.

## 6. No DbContext sharing across threads

No static field, no singleton service field, no parallel `Task.WhenAll` branches sharing one context.

**Why**: No internal locking. Concurrent access → exceptions, silent corruption, identity-map races.

## 7. No `Database.Migrate()` at startup

`dotnet ef database update` or scripted as a pre-deploy step. Review SQL before prod.

**Why**: Scaled deploys race on `__EFMigrationsHistory` → table corruption + destructive changes run multiple times. Also forces app's runtime user to hold schema-change rights → least-privilege violation.

## 8. Parameterize raw SQL

`FromSqlRaw` with `@param` + parameter objects; or `FromSqlInterpolated` (`FormattableString` auto-parameterizes).

**Why**: String concat into raw SQL = SQL injection. `FromSqlInterpolated` converts holes to `DbParameter` (not inline text). `FromSqlRaw` requires explicit placeholders.

## 9. `ExecuteUpdate` / `ExecuteDelete` for bulk

EF Core 7+. Replaces load-mutate-save loop.

**Why**: Load-mutate-save transfers all rows, mutates in tracker, sends individual statements. `ExecuteUpdate`/`ExecuteDelete` = single `UPDATE … WHERE` / `DELETE … WHERE` with zero materialization.

## 10. Fluent API model config

`OnModelCreating` or `IEntityTypeConfiguration<T>` for column types, max length, precision, nullability, indexes.

**Why**: Conventions default `string` → `nvarchar(max)`, `decimal` → `decimal(18,2)`, indexes only on PK/FK. Bad query plans, excessive storage, silent schema drift between environments.

## 11. `AddDbContextPool<T>` for high-throughput

Replace `AddDbContext` when context has no per-request state beyond connection string + options.

**Why**: Pooling reuses context instances after state reset. Eliminates per-request allocation overhead under load; negligible cost when idle.

## 12. Handle `DbUpdateException` / `DbUpdateConcurrencyException`

Specific catch blocks around `SaveChangesAsync`. For optimistic concurrency, inspect `entry.OriginalValues` vs `entry.CurrentValues` and retry or resolve.

**Why**: Swallowed `DbUpdateException` hides constraint / unique / FK failures — caller thinks write succeeded. `DbUpdateConcurrencyException` = lost-update race; ignoring it silently overwrites another user's changes.

## Working Pattern — Writing

1. Confirm the database provider and EF Core version (7+ for `ExecuteUpdate`/`ExecuteDelete`; 8+ for primitive collections, complex types, `EF.Constant`, `SqlQuery<T>`; 9+ for `EnableThreadSafetyChecks` and experimental precompiled queries; 10+ for non-expression `ExecuteUpdateAsync` setters, multi-parameter collection translation, and named default-value constraints via `HasConstraintName`).
2. DI: `AddDbContext` (scoped) or `AddDbContextFactory` (manual lifetime). High-throughput → `AddDbContextPool`.
3. Model: Fluent API for column types, lengths, precision, indexes. Navigation properties for every FK.
4. Read paths: `AsNoTracking()` + `Select` projection. Eager-load with `Include`/`ThenInclude`; deep loads → `AsSplitQuery()`.
5. Write paths: async `SaveChangesAsync` with CT. Return generated IDs, affected rows, or a domain result. Bulk → `ExecuteUpdateAsync`/`ExecuteDeleteAsync`. Optimistic concurrency → `[Timestamp]` row version + concurrency exception handler.
6. Migrations: `dotnet ef migrations add`, review generated SQL, apply via deployment pipeline (never at runtime).

## Working Pattern — Reviewing

1. **Security** — hardcoded credentials, `FromSqlRaw($"…{userInput}…")`, or string concat in raw SQL? → HIGH. Move secrets to configuration; parameterize SQL with `FromSqlInterpolated` or explicit `@param`.
2. **Lifetime** — DbContext registered as Singleton? Stored in static field? Shared across `Task.WhenAll` branches? → critical correctness.
3. **Migrations** — `Database.Migrate()` / `EnsureCreated()` at startup, or edits to a published migration? → flag and move schema changes to the deployment pipeline.
4. **Async hygiene** — Sync `ToList`/`First`/`SaveChanges` on async path? `.Result`/`.Wait()`? Missing CT?
5. **Performance** — Read-only query without `AsNoTracking`? Full-entity return where DTO would do? Navigation access in loop without `Include`?
6. **Bulk** — `foreach` with `Remove` + `SaveChanges`, or load-mutate-save when `ExecuteUpdate`/`ExecuteDelete` would work?
7. **Error handling** — `try { SaveChanges(); } catch { return null; }` swallowing `DbUpdateException`? Concurrency exception ignored?
8. **Modeling** — Default `nvarchar(max)`, default `decimal(18,2)`, no Fluent API config? Missing indexes on hot query columns?

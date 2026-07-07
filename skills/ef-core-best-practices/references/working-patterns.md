# EF Core Working Patterns

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Working pattern for writing new EF Core code

1. **Confirm the target database provider and EF Core version.** The correct NuGet package (`Microsoft.EntityFrameworkCore.SqlServer`, `Npgsql.EntityFrameworkCore.PostgreSQL`, etc.) and version determines which features (ExecuteUpdate, compiled models, JSON columns) are available.

2. **Design entities with explicit Fluent API configuration.** For every entity, specify: primary key strategy, string max lengths and nullability, decimal precision and scale, indexes required for query patterns, and all relationship cardinalities and delete behaviors. **For every FK property (e.g. `CategoryId`), define the corresponding navigation property (e.g. `public Category Category { get; set; }`)** — this enables `Include`-based eager loading and makes relationships explicit. Use `IEntityTypeConfiguration<T>` to keep `OnModelCreating` readable.

3. **Register DbContext in DI with the correct lifetime.** Use `AddDbContext<T>` for standard web APIs and MVC apps (scoped). Use `AddDbContextFactory<T>` for Blazor Server, background `IHostedService`/`BackgroundService` implementations, and any scenario requiring concurrent or long-lived contexts. Never use singleton lifetime.

4. **Write queries with tracking behavior appropriate to use case.** Apply `AsNoTracking()` for all read queries that do not feed into SaveChanges. Use `Include`/`ThenInclude` to load related data required by the query result. Apply `Select` to project only the fields callers need. Add `AsSplitQuery()` if joins produce cartesian-product result sets.

5. **Use async EF Core methods with CancellationToken throughout.** Every `DbContext` method has an async overload. Accept `CancellationToken` in the enclosing method signature and pass it to every async EF Core call.

6. **For multi-row updates and deletes, use `ExecuteUpdateAsync`/`ExecuteDeleteAsync`.** Fall back to load-modify-save only when business logic must run per entity (validation, domain events, computed fields).

7. **Return meaningful results from write operations.** Return the created entity's ID, the number of affected rows, or a domain result type. Do not return `void` from methods that write data — callers need to know whether the operation succeeded and what was produced.

## Working pattern for reviewing EF Core code

Work through this checklist in severity order. Report all Critical items before moving to lower severities.

**Critical — Security**
- [ ] Does any `FromSqlRaw`, `ExecuteRawSql`, or `Database.ExecuteSqlRaw` call concatenate or interpolate a user-supplied string rather than using parameters? Flag as SQL injection.
- [ ] Are connection strings or credentials hardcoded in `DbContextOptions` configuration? Flag as secret exposure.

**Critical — DbContext Lifetime and Thread Safety**
- [ ] Is `DbContext` registered as a singleton, or stored as a field in a singleton service? Flag as threading violation.
- [ ] Is the same `DbContext` instance passed into `Task.WhenAll` or used across concurrent `await` branches? Flag as threading violation.
- [ ] Is `DbContext` injected into a `BackgroundService` or `IHostedService` directly (rather than via `IDbContextFactory` or a created scope)? Flag as lifetime mismatch.

**High — Query Efficiency**
- [ ] Are navigation properties accessed inside a loop without a preceding `Include`? Flag as N+1.
- [ ] Are read queries missing `AsNoTracking()`? Flag as unnecessary tracking overhead.
- [ ] Does the query load an entire table without a `Where` clause or `Select` projection? Flag as over-fetching.
- [ ] Do `Include` chains exceed two or three levels without `AsSplitQuery()`? Flag as potential cartesian explosion.

**High — Async Correctness**
- [ ] Are synchronous EF Core methods (`ToList`, `FirstOrDefault`, `SaveChanges`) used in an async context? Flag as threadpool blocking.
- [ ] Are `.Result` or `.Wait()` called on EF Core tasks? Flag as sync-over-async deadlock risk.
- [ ] Is `CancellationToken` accepted by the method but not forwarded to EF Core calls? Flag as incomplete cancellation.

**Medium — Change Tracking**
- [ ] Are entities tracked when they will not be saved? Flag for `AsNoTracking`.
- [ ] Are detached entities re-attached with `context.Attach` or `context.Entry(e).State = Modified` without verifying their state? Flag as potential over-write.

**Medium — Migrations**
- [ ] Is `database.Migrate()` or `EnsureCreated()` called at application startup? Flag as migration safety violation.
- [ ] Are migration scripts committed without a review of the generated SQL? Flag for review requirement.
- [ ] Are published migrations edited? Flag — published migrations must never be modified.

**Medium — Bulk Operations**
- [ ] Is there a `foreach` loop that calls `SaveChangesAsync` inside the loop (one call per entity)? Flag for batching or `ExecuteUpdate`/`ExecuteDelete`.
- [ ] Are `ExecuteUpdate`/`ExecuteDelete` available (EF Core 7+) but not used for mass mutations? Flag for optimization opportunity.

**Low — Error Handling**
- [ ] Is `SaveChangesAsync` called without catching `DbUpdateException` or `DbUpdateConcurrencyException`? Flag for explicit error handling.
- [ ] Is there a broad `catch (Exception)` that swallows these specific exception types? Flag as silent failure.

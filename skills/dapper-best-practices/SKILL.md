---
name: dapper-best-practices
description: 'Use when writing or reviewing C#/.NET data access with Dapper — IDbConnection, SQL connections, QueryAsync/Execute/ExecuteAsync, DynamicParameters, QueryMultiple, splitOn, Dapper.Contrib, or raw SQL inside a Dapper repository. Apply even when user just says "add a Dapper query", "speed up this Dapper repo", or "split this multi-result set" without naming this skill.'
---

# Dapper Best Practices

For EF Core / LINQ-to-SQL / other ORMs this skill does **not** apply — say so and stop.

## Mode

1. **Writing** — apply Golden Rules proactively. Don't ask permission to use parameterized queries or async; just do it and briefly mention *why* if it differs.
2. **Reviewing** — walk the rules as a checklist. Prioritize security → correctness (connection / transaction lifecycle) → performance.

## Golden Rules

Each rule's *why* + writing/reviewing patterns live in `references/rules-expanded.md`.

1. **Always parameterize.** `@name` + anonymous object / POCO / `DynamicParameters`. *Why:* SQLi defense + plan cache.
2. **Own connection lifetime with `await using`.** *Why:* deterministic pool return on exception.
3. **`*Async` + `CancellationToken`** via `CommandDefinition`. *Why:* sync Dapper starves threadpool; can't cancel.
4. **No `IEnumerable<T>` from inside `using`** (when `buffered: false`). Buffer, materialize, or use `IAsyncEnumerable<T>`. *Why:* deferred iteration → `ObjectDisposedException`.
5. **Right method for arity**: `QueryAsync` / `QueryFirstOrDefaultAsync` / `QuerySingleAsync` / `ExecuteScalarAsync`. *Why:* communicates intent + DB stops early.
6. **Kill N+1**: batch `IN @ids`, `QueryMultipleAsync`, or multi-mapping with `splitOn`. *Why:* 100 round trips = 100ms wasted.
7. **Transaction: open / pass / commit / dispose.** Pass `transaction: tx` to *every* call inside. *Why:* no auto-enlist; missing → silent atomicity break.
8. **DI owns connection factory, not constructor.** *Why:* ctor connection has class lifetime → singleton = forever leak.
9. **POCOs, not `dynamic`.** Snake_case via `DefaultTypeMap.MatchNamesWithUnderscores`. *Why:* compile-time checks; refactor-safe.
10. **No bulk inserts in a Dapper loop.** `SqlBulkCopy` + `FastMember`, `Dapper.Plus`, TVP, `MERGE`, staging table. *Why:* 10–100× faster.
11. **Stored procs: explicit `commandType`.** Read output via `parameters.Get<T>("@name")` after call. *Why:* default `CommandType.Text` → malformed SQL.
12. **Don't swallow `SqlException`.** Wrap with context but never log raw parameter values with PII. *Why:* turns DB error into mystery NRE upstream.

## Reference Map

| Need | File |
|---|---|
| Why behind each rule + writing / reviewing patterns | `references/rules-expanded.md` |
| Method cheat sheet, parameterization (anonymous / POCO / DynamicParameters), `IN @ids`, `LIKE` escaping, dialect notes | `references/core-crud-safety.md` |
| `buffered`, `IAsyncEnumerable`, `QueryMultipleAsync`, multi-mapping + `splitOn` pitfalls, `.Result` / `ConfigureAwait` | `references/performance.md` |
| `IDbConnectionFactory`, DI lifetimes, `IDbTransaction` vs `TransactionScope`, `IEnumerable from using` trap, unit-of-work | `references/connections-transactions.md` |
| `Dapper.Contrib`, `SqlBulkCopy` + `FastMember`, output params, TVP, JSON, provider notes (PG / SQLite / MySQL / Oracle) | `references/advanced.md` |
| `Dapper.AOT` — build-time interceptors, NativeAOT / trimming, reflection-free materialization | `references/advanced.md` |

Open one file at a time — don't preload.

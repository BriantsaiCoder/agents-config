---
name: dapper-best-practices
description: "Write, review, or tune Dapper data access, including queries, mapping, connection ownership, and transactions."
---

# Dapper Best Practices

For EF Core / LINQ-to-SQL / other ORMs this skill does **not** apply — say so and stop.

## Mode

1. **Writing** — within authorized DAL changes, parameterize queries and reuse provider/TFM-compatible async patterns. Public contracts, provider changes, and transaction-boundary changes follow `dev-workflow` S2; review-only work produces findings.
2. **Reviewing** — walk the rules as a checklist. Prioritize security → correctness (connection / transaction lifecycle) → performance.

## Golden Rules

Open the topical reference that matches the task; it contains the detailed rationale and patterns.

1. **Always parameterize.** `@name` + anonymous object / POCO / `DynamicParameters`. *Why:* SQLi defense + plan cache.
2. **Dispose owned connections deterministically.** Use `using` or `await using` supported by the installed provider/TFM; preserve the owner and pool return on exceptions.
3. **Use supported async/cancellation APIs for asynchronous I/O**, such as `CommandDefinition`; preserve the existing caller contract and avoid sync-over-async.
4. **No `IEnumerable<T>` from inside `using`** (when `buffered: false`). Buffer, materialize, or use `IAsyncEnumerable<T>`. *Why:* deferred iteration → `ObjectDisposedException`.
5. **Right method for arity**: `QueryAsync` / `QueryFirstOrDefaultAsync` / `QuerySingleAsync` / `ExecuteScalarAsync`. *Why:* communicates intent + DB stops early.
6. **Kill N+1**: batch `IN @ids`, `QueryMultipleAsync`, or multi-mapping with `splitOn`. *Why:* 100 round trips = 100ms wasted.
7. **Transaction: open / pass / commit / dispose.** Pass `transaction: tx` to *every* call inside. *Why:* no auto-enlist; missing → silent atomicity break.
8. **DI owns connection factory, not constructor.** *Why:* ctor connection has class lifetime → singleton = forever leak.
9. **POCOs, not `dynamic`.** Snake_case via `DefaultTypeMap.MatchNamesWithUnderscores`. *Why:* compile-time checks; refactor-safe.
10. **Evaluate bulk paths against the workload.** Reuse installed provider-native batching or existing bulk tools when round trips are a measured bottleneck; preserve transaction semantics and review new dependencies separately.
11. **Stored procs: explicit `commandType`.** Read output via `parameters.Get<T>("@name")` after call. *Why:* default `CommandType.Text` → malformed SQL.
12. **Don't swallow `SqlException`.** Wrap with context but never log raw parameter values with PII. *Why:* turns DB error into mystery NRE upstream.

## Reference Map

| Need | File |
|---|---|
| Method cheat sheet, parameterization (anonymous / POCO / DynamicParameters), `IN @ids`, `LIKE` escaping, dialect notes | `references/core-crud-safety.md` |
| `buffered`, `IAsyncEnumerable`, `QueryMultipleAsync`, multi-mapping + `splitOn` pitfalls, `.Result` / `ConfigureAwait` | `references/performance.md` |
| `IDbConnectionFactory`, DI lifetimes, `IDbTransaction` vs `TransactionScope`, `IEnumerable from using` trap, unit-of-work | `references/connections-transactions.md` |
| `Dapper.Contrib`, `SqlBulkCopy` + `FastMember`, output params, TVP, JSON, provider notes (PG / SQLite / MySQL / Oracle) | `references/advanced.md` |
| `Dapper.AOT` — build-time interceptors, NativeAOT / trimming, reflection-free materialization | `references/advanced.md` |

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.

---
name: ef6-best-practices
description: "Write, review, or tune Entity Framework 6 data access identified by System.Data.Entity, regardless of target runtime."
---

# EF6 Best Practices

Use this skill for Entity Framework 6 code on any supported runtime. EF 6.3+ (Sept 2019) runs on .NET Core 3.0 and later as well as .NET Framework; EF 6.5.2 (April 2026) is .NET 10 compatible. EF6 is not EF Core: APIs, migration tooling, async behavior, lifetime guidance, and Include syntax differ.

## When This Skill Applies

Use when code references `EntityFramework` NuGet or `System.Data.Entity` — regardless of target framework. That covers .NET Framework / classic ASP.NET / WinForms / WPF and also .NET Core 3.0+ / .NET 5–10 projects (EF 6.3+ is cross-platform). The package and namespace are the signal, not the TFM.

Do not use when code references `Microsoft.EntityFrameworkCore`; use `ef-core-best-practices` instead.

## Golden Rules

1. Keep `DbContext` short-lived and disposed; never static or shared across threads.
2. Disable lazy loading unless explicitly required; use eager loading deliberately.
3. Use EF6 `.Include()` syntax, including `.Select()` for nested navigation; do not use EF Core `.ThenInclude()`.
4. Use `AsNoTracking()` for read-only queries.
5. Use EF6 async APIs from `System.Data.Entity` and avoid `.Result` / `.Wait()`.
6. Avoid navigation access inside loops unless related data was eagerly loaded.
7. Keep EDMX models synchronized with database schema and commit model diffs.
8. Parameterize `Database.SqlQuery` and `ExecuteSqlCommand`; never concatenate user input.
9. Control `ObjectStateManager` size with short contexts, no-tracking reads, and detach when necessary.
10. Keep connection strings in config or secret stores, not source code.
11. Review migrations/scripts before production deployment.
12. Catch and handle `DbUpdateException` / concurrency failures explicitly where writes can fail.

## Writing Workflow

1. Confirm EF6 vs EF Core by package, namespace, target framework, and project style.
2. Choose Database First/EDMX, Code First, or existing project pattern; do not mix casually.
3. Define context lifetime and loading strategy before writing queries.
4. Write queries with explicit filters, projections, includes, and no-tracking where appropriate.
5. Use parameterized raw SQL only when LINQ cannot express the query cleanly.
6. Add tests or manual verification for query shape, write failures, and migration impact.

## Review Checklist

- Critical: raw SQL concatenates user input, hardcoded credentials, shared/static context, or cross-thread context usage.
- High: lazy loading causes N+1, missing `AsNoTracking`, unbounded table reads, sync-over-async, stale EDMX.
- Medium: long-lived context, oversized change tracker, migration deployment risk, swallowed update exceptions.
- Low: unclear projections, inconsistent naming, or conventions that differ from the existing EF6 model.

## References

- Context lifetime: `references/context-lifetime.md`
- EDMX and Code First: `references/edmx-codefirst.md`
- Migrations/deployment: `references/migration-deployment.md`
- Query performance: `references/query-performance.md`

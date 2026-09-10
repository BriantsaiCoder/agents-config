---
name: dotnet-core-best-practices
description: "Write, review, or diagnose .NET 8+ and ASP.NET Core behavior. For .NET Framework 4.x, use dotnet-framework-best-practices."
---

# .NET 8/10 & ASP.NET Core Best Practices

Prefer built-ins over third-party workarounds. .NET Framework 4.x → `dotnet-framework-best-practices`. Cross-ref: `ef-core-best-practices`, `dapper-best-practices`, `dotnet-logging-best-practices`. Rule detail in `references/code-patterns.md#rule-N`.

## 12 Golden Rules

1. **DI lifetimes** — mismatch = captive deps. `ValidateScopes + ValidateOnBuild` in dev. Keyed services on .NET 8+.
2. **Configuration ownership** — preserve repo extension points; where Options are used, validate required settings and choose `IOptions<T>` / snapshot / monitor by lifetime. Diagnose incorrect configuration behavior before replacing service patterns.
3. **HTTP lifetime** — reuse the repo factory or long-lived client with appropriate handler lifetime. Investigate socket/DNS behavior; preserve retry and idempotency contracts rather than adding retries to a local patch.
4. **Middleware order** — ExceptionHandler → HSTS → HttpsRedirection → StaticFiles → Routing → CORS → Auth → Authorization → RateLimiter → OutputCache → MapControllers. Misorder = silent security bug.
5. **Choose endpoint model by requirements.** Minimal APIs suit focused endpoints; Controllers suit APIs needing filters, binding conventions, or versioning.
6. **Structured logging** — `ILogger<T>` templates (`"Order {OrderId}"`), not interpolation. Detail → `dotnet-logging-best-practices`.
7. **`CancellationToken` everywhere** — auto-binds; accept and forward. Ignoring wastes CPU / DB on dead responses.
8. **Health/telemetry** — `/health/ready` (deps), `/health/live` (process); ASP.NET Core OTel/OTLP → `references/security-performance.md#opentelemetry-for-aspnet-core`.
9. **No secrets in `appsettings.json`** — User Secrets (dev), env (CI), Key Vault / Vault (prod).
10. **Global error handling** — `UseExceptionHandler` + `ProblemDetails` (RFC 9457); `AddProblemDetails()` auto-wires on .NET 8+.
11. **Authorization policies** — `AddAuthorizationBuilder().AddPolicy(...)` + `[Authorize(Policy = "...")]`. Not inline `User.IsInRole`.
12. **Platform features** — `RateLimiter`/`OutputCache` (.NET 7+), keyed services (.NET 8+), `HybridCache`/OpenAPI (.NET 9+), built-in validation `AddValidation()` + `AddOpenApiOperationTransformer` replacing deprecated `WithOpenApi` (.NET 10+), AOT. Matrix → `code-patterns.md`.

## Review Severity Checklist

Assign severity from demonstrated lifetime, security, or version-behavior impact. Existing library/console patterns and valid alternatives are not defects by themselves.

| Review | Check | Rule |
|---|---|---|
| Inspect | Secrets in `appsettings.json` | 9 |
| Inspect | User input concat'd into SQL / shell / paths | — |
| Inspect | Scoped (DbContext) into singleton | 1 |
| Inspect | Per-request client lifetime causes socket/DNS problems | 3 |
| Inspect | Middleware misorder | 4 |
| Inspect | `CancellationToken` not forwarded | 7 |
| Inspect | Weak crypto (`MD5`/`SHA1`/`Random` tokens) | sec-perf |
| Inspect | `IConfiguration` magic strings | 2 |
| Inspect | Inline `User.IsInRole` | 11 |
| Inspect | `Console.WriteLine` / interpolated log | 6 |
| Inspect | Health missing for critical deps | 8 |
| Inspect | Vulnerable / deprecated NuGet | config-host |
| Inspect | .NET 7+/8+ features reimplemented | 12 |

## Reference Navigation

- `references/code-patterns.md` — Rules 1–12, 7-step pattern, Console, version matrix, C# 12, async
- `references/architecture-di.md` — DI, lifetimes, Options, keyed services, Clean Architecture, CQRS/MediatR
- `references/aspnet-core-api.md` — Minimal vs Controllers, filters, caching, rate limit, versioning, OpenAPI
- `references/configuration-hosting.md` — appsettings, Kestrel, health, Worker, NuGet/CPM
- `references/security-performance.md` — Identity/JWT, CORS, Data Protection, factory, crypto, AOT, runtime diagnostics (`dotnet-counters`, `dotnet-trace`, `dotnet-dump`)

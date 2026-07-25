---
name: dotnet-core-best-practices
description: 'Use when writing or reviewing .NET 6+ / ASP.NET Core — WebApplication.CreateBuilder, Minimal API, controllers, DI lifetimes, middleware ordering, HttpClientFactory, ProblemDetails, options pattern, configuration binding, "scaffold ASP.NET Core API", "wire up DI". Symptoms: DI scope mismatch (scoped from singleton), BackgroundService stops silently, middleware misorder (auth after endpoint), HttpClient socket exhaustion, IOptions returns default.'
---

# .NET 6/8/10 & ASP.NET Core Best Practices

Prefer built-in primitives over third-party workarounds. Not for .NET Framework 4.x (use `dotnet-framework-best-practices`). Cross-ref: `ef-core-best-practices`, `dapper-best-practices`, `dotnet-logging-best-practices`. Rule detail in `references/code-patterns.md#rule-N`.

## 12 Golden Rules

1. **DI lifetimes** — mismatch = captive deps. `ValidateScopes + ValidateOnBuild` in dev. Keyed services on .NET 8+.
2. **Options pattern** — bind with `ValidateDataAnnotations()` + `ValidateOnStart()`. Pick `IOptions<T>` / `IOptionsSnapshot<T>` / `IOptionsMonitor<T>` by lifetime. Never read `IConfiguration` in services.
3. **`IHttpClientFactory`** — never `new HttpClient()` (socket exhaustion). `.AddStandardResilienceHandler()`; `Idempotency-Key` for non-idempotent retries.
4. **Middleware order** — ExceptionHandler → HSTS → HttpsRedirection → StaticFiles → Routing → CORS → Auth → Authorization → RateLimiter → OutputCache → MapControllers. Misorder = silent security bug.
5. **Controller-based Web API default; Minimal API only for prototypes** (CLAUDE.md). Controllers: attribute routing, filters, binding, versioning, OpenAPI.
6. **Structured logging** — `ILogger<T>` templates (`"Order {OrderId}"`), not interpolation. Detail → `dotnet-logging-best-practices`.
7. **`CancellationToken` everywhere** — auto-binds; accept and forward. Ignoring wastes CPU / DB on dead responses.
8. **Health checks** — `MapHealthChecks` with `/health/ready` (deps) + `/health/live` (process).
9. **No secrets in `appsettings.json`** — User Secrets (dev), env (CI), Key Vault / Vault (prod).
10. **Global error handling** — `UseExceptionHandler` + `ProblemDetails` (RFC 9457); `AddProblemDetails()` auto-wires on .NET 8+.
11. **Authorization policies** — `AddAuthorizationBuilder().AddPolicy(...)` + `[Authorize(Policy = "...")]`. Not inline `User.IsInRole`.
12. **Platform features** — `RateLimiter`/`OutputCache` (.NET 7+), keyed services (.NET 8+), `HybridCache`/OpenAPI (.NET 9), AOT. Matrix → `code-patterns.md`.

## Review Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | Secrets in `appsettings.json` | 9 |
| Critical | User input concat'd into SQL / shell / paths | — |
| Critical | Scoped (DbContext) into singleton | 1 |
| High | `new HttpClient()` not factory | 3 |
| High | Middleware misorder | 4 |
| High | `CancellationToken` not forwarded | 7 |
| High | Weak crypto (`MD5`/`SHA1`/`Random` tokens) | sec-perf |
| Medium | `IConfiguration` magic strings | 2 |
| Medium | Inline `User.IsInRole` | 11 |
| Medium | `Console.WriteLine` / interpolated log | 6 |
| Medium | Health missing for critical deps | 8 |
| Medium | Vulnerable / deprecated NuGet | config-host |
| Low | .NET 7+/8+ features reimplemented | 12 |

## Reference Navigation

- `references/code-patterns.md` — Rules 1–12, 7-step pattern, Console, version matrix, C# 12, async
- `references/architecture-di.md` — DI, lifetimes, Options, keyed services
- `references/aspnet-core-api.md` — Minimal vs Controllers, filters, caching, rate limit, versioning, OpenAPI
- `references/configuration-hosting.md` — appsettings, Kestrel, health, Worker, NuGet/CPM
- `references/security-performance.md` — Identity/JWT, CORS, Data Protection, factory, crypto, AOT

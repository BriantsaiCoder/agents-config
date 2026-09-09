---
name: dotnet-framework-best-practices
description: "Write, review, or diagnose .NET Framework 4.x applications, including classic ASP.NET, Windows Services, and WCF."
---

# .NET Framework 4.x Best Practices

No built-in DI, `System.Web` pipeline, `Global.asax`, XML transforms. Not for `Microsoft.AspNetCore.*` (use `dotnet-core-best-practices`). Cross-ref: `ef6-best-practices`, `dapper-best-practices`, `dotnet-logging-best-practices`.

## 12 Golden Rules

1. **Keep dependency creation at the Composition Root.** Reuse the existing container or manual constructor wiring. Do not add Autofac/Unity/Ninject merely to patch an existing application.
2. **Never use Service Locator.** `container.Resolve<T>()` hides deps, fails at runtime, drags container into tests. Constructors only; resolve at Composition Root.
3. **Async all the way — never `.Result` or `.Wait()`.** ASP.NET `SynchronizationContext` marshals continuations to request thread; blocking deadlocks.
4. **`ConfigureAwait(false)` in library code, not controllers.** Library without `HttpContext` skips marshaling. Controllers needing `HttpContext` do NOT.
5. **Validate at boundary.** No middleware pipeline — Data Annotations on DTOs, check `ModelState.IsValid` in every action, return `400` with details.
6. **Global error handlers — never swallow.** MVC: `Application_Error` or `IExceptionFilter`. Web API 2: `IExceptionHandler` + `IExceptionLogger`.
7. **Action filters over repetitive cross-cutting code.** Auth / logging / timing / validation duplicated → `ActionFilterAttribute` / `IActionFilter` / `IAuthorizationFilter`.
8. **Never store secrets in plain-text Web.config.** Encrypt sections via `aspnet_regiis -pe`, or pull from env / Key Vault at startup.
9. **Anti-Forgery on state-changing MVC actions.** `@Html.AntiForgeryToken()` + `[ValidateAntiForgeryToken]`. Web API 2 + cookie auth needs custom CSRF.
10. **`HttpClient` shared static or factory, never per-request `using`.** Causes socket exhaustion (TIME_WAIT).
11. **Output caching + bundling for MVC.** `[OutputCache]` (`Duration` + `VaryByParam`) + `BundleConfig` for CSS/JS minify.
12. **Keep startup ownership clear.** Preserve the existing Global.asax/OWIN initialization model; moving to OWIN belongs to an authorized migration, not a routine patch.

## Review Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | Secrets in plain Web.config? | R8 |
| Critical | User input concatenated into SQL / commands / paths? | — |
| Critical | State-changing MVC missing `[ValidateAntiForgeryToken]`? | R9 |
| High | `.Result` / `.Wait()` in controller/request context? | R3 |
| High | `HttpClient` per-request `using`? | R10 |
| High | Deps `new`-ed inside controllers/services? | R1 |
| Medium | `ModelState.IsValid` unchecked? | R5 |
| Medium | Cross-cutting duplicated instead of filters? | R7 |
| Medium | `ConfigureAwait(false)` missing in library async? | R4 |
| Low | Global.asax bloated with init that could move to OWIN? | R12 |

## Reference Navigation

- `references/code-patterns.md` — 12 Rules, 7-step writing pattern, Console, logging anti-patterns
- `references/architecture-di.md` — layering, Unity/Autofac/Ninject, Composition Root, Service Locator
- `references/aspnet-mvc-webapi.md` — MVC 5 + Web API 2, routing, filters, binding, negotiation
- `references/configuration-hosting.md` — Web/App.config, transforms, OWIN/Katana, IIS, Global.asax, legacy NuGet
- `references/security-performance.md` — FormsAuth/OWIN, CSRF, CORS, caching, async, HttpClient

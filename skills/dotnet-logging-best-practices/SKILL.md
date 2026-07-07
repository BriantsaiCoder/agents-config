---
name: dotnet-logging-best-practices
description: 'Use when adding or reviewing logging in .NET applications — Microsoft.Extensions.Logging ILogger generic logging, Serilog/NLog/log4net, LoggerMessage source generators, structured logs, sinks, log levels, correlation IDs, Activity/ActivitySource, OpenTelemetry exporters, or appsettings configuration. Applies to both .NET 6+ and .NET Framework logging stacks. Apply even when user just says "add logging here", "structured logs", or "wire up Serilog" without naming this skill.'
---

# .NET Logging Best Practices

Four pillars: structured logging, log-level strategy, performance, sensitive-data protection.

## Scope

Covers .NET 6+ / ASP.NET Core / Worker / .NET Framework (NLog/log4net). Not for distributed tracing or metrics. Cross-ref: `dotnet-core-best-practices`, `dotnet-framework-best-practices`.

## 12 Golden Rules

Detail: `references/code-patterns.md` (R8 → `serilog-deep-dive.md`; R9 → `nlog-log4net-guide.md`).

1. **Message templates, not interpolation.** `"Order {OrderId}"` indexes `OrderId=42`; `$"Order {id}"` is opaque. PascalCase placeholders.
2. **Right log level.** Critical → Error → Warning → Info → Debug → Trace. Production: Info+ on; Debug/Trace off.
3. **`[LoggerMessage]` on hot paths — zero alloc when disabled.** Standard `Log*` boxes value types even when off. .NET 6+ source-gen; .NET Framework: `LoggerMessage.Define`.
4. **Guard expensive log params with `IsEnabled`.** Structured logging evaluates params eagerly. Source-gen includes the check.
5. **Never log secrets / PII** — passwords, tokens, credit cards. Violates GDPR/PCI-DSS. Log IDs not JWT. Serilog destructure policies for redaction.
6. **Per-namespace log levels.** EF Core / HttpClient / ASP.NET emit verbose Debug. Filter via `appsettings.json` `Logging.LogLevel` or NLog `<rules>`.
7. **Correlation IDs** — trace requests across services. ASP.NET middleware + `BeginScope`; Serilog `.Enrich.WithCorrelationId()`.
8. **Serilog on .NET 6+** — two-stage init: bootstrap logger → `builder.Host.UseSerilog(...)`. `Main` try/catch/finally + `Log.CloseAndFlush()`.
9. **NLog on .NET Framework — XML config, not code.** `NLog.config` Copy Always; targets/rules/JsonLayout. Ops change levels without recompile.
10. **Log at boundaries.** Entry/exit of significant ops (requests, outgoing calls, business decisions, error recovery). Skip trivial steps.
11. **Error logs need exception + operation + IDs.** `LogError(ex, "Payment failed for order {OrderId}", id)`, not `LogError("Failed")`.
12. **Centralize for production** — local files lost on container recycle. Seq / ELK / App Insights / Loki.

## Review Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | Secrets / PII logged? | R5 |
| Critical | Exceptions swallowed (`catch { }`)? | — |
| High | Interpolation vs message templates? | R1 |
| High | Error log missing exception or IDs? | R11 |
| High | Everything as Information? | R2 |
| Medium | Noisy framework namespaces unfiltered? | R6 |
| Medium | Expensive params without `IsEnabled`? | R4 |
| Medium | Correlation IDs missing? | R7 |
| Low | Hot paths using `Log*` not `LoggerMessage`? | R3 |
| Low | Logs only to local files in prod? | R12 |

## Reference Navigation

- `references/code-patterns.md` — R1–7, 10–12 examples + .NET 6+ / Framework / log4net quick ref
- `references/serilog-deep-dive.md` — sinks, enrichers, two-stage init, audit, perf
- `references/nlog-log4net-guide.md` — targets/rules/layouts, log4net, migration

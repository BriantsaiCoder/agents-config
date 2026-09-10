---
name: dotnet-logging-best-practices
description: "Implement or review application logging in .NET and .NET Framework. ASP.NET Core OpenTelemetry/OTLP export routes to dotnet-core-best-practices."
---

<!-- last-verified: 2026-07-26 -->
# .NET Logging Best Practices

Four pillars: structured logging, log-level strategy, performance, sensitive-data protection.

## Scope

Covers .NET 6+ / ASP.NET Core / Worker / .NET Framework (NLog/log4net). Application logging stays here; ASP.NET Core on .NET 8+ OpenTelemetry/OTLP traces, metrics, or log export → `dotnet-core-best-practices`. Cross-ref: `dotnet-framework-best-practices`.

## 12 Golden Rules

Detail: `references/code-patterns.md` (R8 → `serilog-deep-dive.md`; R9 → `nlog-log4net-guide.md`).

1. **Message templates, not interpolation.** `"Order {OrderId}"` indexes `OrderId=42`; `$"Order {id}"` is opaque. PascalCase placeholders.
2. **Right log level.** Critical → Error → Warning → Info → Debug → Trace. Preserve repo production thresholds; change levels only for a concrete diagnostic/operational need and authorized configuration scope.
3. **`[LoggerMessage]` on hot paths — zero alloc when disabled.** Standard `Log*` boxes value types even when off. .NET 6+ source-gen; .NET Framework: `LoggerMessage.Define`.
4. **Guard expensive log params with `IsEnabled`.** Structured logging evaluates params eagerly. Source-gen includes the check.
5. **Never log secrets / PII** — passwords, tokens, credit cards. Violates GDPR/PCI-DSS. Log IDs not JWT. Serilog destructure policies for redaction.
6. **Per-namespace log levels.** EF Core / HttpClient / ASP.NET emit verbose Debug. Filter via `appsettings.json` `Logging.LogLevel` or NLog `<rules>`.
7. **Correlation IDs** — trace requests across services. ASP.NET middleware + `BeginScope`; Serilog `.Enrich.WithCorrelationId()`.
8. **Preserve the installed logger.** If Serilog is selected, use its bootstrap/shutdown contract; compare alternatives only when a required capability is missing.
9. **Preserve logger configuration ownership.** For NLog/log4net, follow the existing XML or code configuration and deployment convention; ensure operations can adjust intended settings.
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

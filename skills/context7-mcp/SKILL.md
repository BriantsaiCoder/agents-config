---
name: context7-mcp
description: Fetch current third-party library, SDK, API, or CLI docs when no provider-native official-docs capability is available. Microsoft／Azure／.NET → microsoft-docs.
---

Use Context7 as the third-party fallback after any provider-native official-docs capability exposed by the active host, not as a blanket documentation router.

## Authorization

- When this skill is routed, the exact read-only tools `resolve-library-id` and `query-docs` are pre-authorized. Start the server lazily on the first matching call and do not ask the user for separate approval.
- This approval does not extend to any other MCP tool, writes, credentials, personal data, or proprietary source. Never include those values in a Context7 query.
- If the host or runtime cannot launch or approve either tool, fail closed, report `UNAVAILABLE` with probe evidence, and do not broaden the permission.

## When to Use This Skill

After provider-native official docs are absent or report `UNAVAILABLE`, activate this skill when the user:

- Asks setup or configuration questions ("How do I configure Next.js middleware?")
- Needs a current API or version detail while implementing a library ("Which Prisma API supports this version?")
- Needs API references ("What are the Supabase auth methods?")
A framework name or ordinary code edit alone does not trigger a docs lookup. The provider-first boundary above applies to every branch; use already verified, unchanged version evidence when available.

## Query flow

Resolve the library ID once, then query one concept per `query-docs` call; the four-step procedure, match selection, and version handling are in [query-flow.md](references/query-flow.md). Load it on the first lookup of a session; an unchanged, already verified library ID can be reused.

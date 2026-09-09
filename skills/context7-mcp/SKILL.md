---
name: context7-mcp
description: Use for current third-party library, framework, SDK, API, CLI, or cloud docs when the active host exposes no provider-native official-docs capability or that capability is UNAVAILABLE. Microsoft／Azure／.NET → microsoft-docs or microsoft-code-reference.
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

## How to Fetch Documentation

### Step 1: Resolve the Library ID

Call `resolve-library-id` with:

- `libraryName`: The library name extracted from the user's question
- `query`: What to look up in the library's documentation (improves relevance ranking)

### Step 2: Select the Best Match

From the resolution results, choose based on:

- Exact or closest name match to what the user asked for
- Higher benchmark scores indicate better documentation quality
- If the user mentioned a version (e.g., "React 19"), prefer version-specific IDs

### Step 3: Fetch the Documentation

Call `query-docs` with:

- `libraryId`: The selected Context7 library ID (e.g., `/vercel/next.js`)
- `query`: What to look up in the library's documentation, scoped to a single concept

If the user's question spans multiple distinct concepts (e.g. routing and auth and caching), make a separate `query-docs` call per concept with the same library ID, unless the question is about how the concepts interact — combined queries dilute ranking and return shallow results for each topic.

### Step 4: Use the Documentation

Incorporate the fetched documentation into your response:

- Answer the user's question using current, accurate information
- Include relevant code examples from the docs
- Cite the library version when relevant

## Guidelines

- **Be specific**: Describe what to look up in the library's documentation, but keep each query to a single concept
- **One topic per query**: Split multi-topic questions into separate `query-docs` calls — resolve the library ID once, then query per concept, unless the question is about how the concepts interact
- **Version awareness**: When users mention versions ("Next.js 15", "React 19"), use version-specific library IDs if available from the resolution step
- **Prefer official sources**: When multiple matches exist, prefer official/primary packages over community forks

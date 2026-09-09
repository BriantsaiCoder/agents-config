---
name: microsoft-docs
description: "Look up current official Microsoft concepts, tutorials, configuration, and limits; API signatures and SDK samples use microsoft-code-reference."
compatibility: Requires Microsoft Learn MCP Server (https://learn.microsoft.com/api/mcp)
---

# Microsoft Docs

## Tools

| Tool | Use For |
|------|---------|
| `microsoft_docs_search` | Find documentation—concepts, guides, tutorials, configuration |
| `microsoft_docs_fetch` | Get full page content (when search excerpts aren't enough) |

## When to Use

- **Understanding concepts** — "How does Cosmos DB partitioning work?"
- **Learning a service** — "Azure Functions overview", "Container Apps architecture"
- **Finding tutorials** — "quickstart", "getting started", "step-by-step"
- **Configuration options** — "App Service configuration settings"
- **Limits & quotas** — "Azure OpenAI rate limits", "Service Bus quotas"
- **Best practices** — "Azure security best practices"

## Query tips

Specific queries with version, task intent, and platform context are in [query-tips.md](references/query-tips.md); load it when a search returns broad or off-target results.

## When to Fetch Full Page

Fetch after search when:
- **Tutorials** — need complete step-by-step instructions
- **Configuration guides** — need all options listed
- **Deep dives** — user wants comprehensive coverage
- **Search excerpt is cut off** — full context needed

---
name: microsoft-code-reference
description: "Verify Microsoft API signatures, packages, and SDK samples when implementing an unfamiliar API or diagnosing API/version mismatches."
compatibility: Requires Microsoft Learn MCP Server (https://learn.microsoft.com/api/mcp)
---

# Microsoft Code Reference

## Tools

| Need | Tool | Example |
|------|------|---------|
| API method/class lookup | `microsoft_docs_search` | `"BlobClient UploadAsync Azure.Storage.Blobs"` |
| Working code sample | `microsoft_code_sample_search` | `query: "upload blob managed identity", language: "python"` |
| Full API reference | `microsoft_docs_fetch` | Fetch URL from `microsoft_docs_search` (for overloads, full signatures) |

## When to Verify

Always verify when:
- Method name seems "too convenient" (`UploadFile` vs actual `Upload`)
- Mixing SDK versions (v11 `CloudBlobClient` vs v12 `BlobServiceClient`)
- Package name doesn't follow conventions (`Azure.*` for .NET, `azure-*` for Python)
- Using an API for the first time

## Routing

| Need | Reference |
|---|---|
| Working sample before or after writing code | [samples.md](references/samples.md) |
| Confirm a method, class, or package; full validation sequence | [api-lookup.md](references/api-lookup.md) |
| Method／type not found, wrong signature, deprecation, auth or 403 errors | [troubleshooting.md](references/troubleshooting.md) |

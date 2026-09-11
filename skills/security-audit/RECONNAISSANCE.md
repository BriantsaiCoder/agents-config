# Phase 1: Understand the Application

### Phase 1: Understand the application

Before looking for bugs, understand what you're auditing. This requires depth, not just a directory listing. Cover the three workstreams below in the main context. Under shared `dev-workflow` INT-4, delegate only workstreams that are substantial, independent, and likely to improve coverage or wall-clock time; combine related work and use the smallest useful number of agents.

**Workstream 1a: Overview, tech stack, and comparable baseline**
```
Explore the codebase at <path>. Answer:
1. What is this application? What kind of software? (web app, API, CLI tool, library, daemon, desktop app, mobile backend, etc.)
2. Who uses it and how? (end users, developers, operators, other services)
3. What's the tech stack? (languages, frameworks, databases, runtime, deployment model)
4. What comparable mainstream software exists? What security tradeoffs does the comparable accept?
5. What's the high-level directory structure?
Return specific file paths for key entry points.
```

**Workstream 1b: Trust boundaries and access control**
```
Explore the codebase at <path>. Find and read ALL code related to:
1. Trust boundaries — where does untrusted input enter the system? (HTTP requests, CLI args, file reads, IPC, message queues, environment variables, config files, etc.)
2. Authentication — how do callers prove identity? (sessions, tokens, API keys, mTLS, Unix sockets, etc.) If there's no authentication, note that.
3. Authorization — how are permissions enforced? (middleware, decorators, capability checks, file permissions, etc.) If there's no authorization model, note that.
4. Privilege separation — does the code run as root? Drop privileges? Use sandboxing? Fork workers?
5. Any bypass mechanisms (dev-only modes, test helpers, setup flows, debug flags)
Return the trust model: who are the actors, what can each do by design, and which code enforces it. Include specific file paths and line numbers.
```

**Workstream 1c: Input surface inventory**
```
Explore the codebase at <path>. Produce a complete inventory of where external input enters the system:
1. Network-facing surfaces (HTTP endpoints, gRPC services, WebSocket handlers, TCP/UDP listeners, etc.) — list each with method/verb and purpose
2. File-based input (file uploads, config file parsing, log ingestion, import/export, etc.)
3. IPC and inter-service input (message queues, shared memory, Unix sockets, environment variables, CLI arguments)
4. User-generated content surfaces (anywhere users provide content that is stored and later rendered, served, or processed)
5. External integrations (OAuth, webhooks, third-party APIs, plugin loading, dynamic code execution)
6. All places where input reaches dangerous sinks (SQL/query builders, HTML/template output, file paths, shell commands, deserialization, eval, dynamic imports)
Return specific file paths. Be exhaustive.
```

Synthesize the three workstreams into `<output-dir>/architecture.md`:
- Cover the application type, tech stack, trust model, input surfaces, and baseline comparable at the length the codebase needs, without padding or redundant summaries.
- Include the key file paths from all workstreams — these become the starting points for Phase 2.
- Include the relevant scoped excerpt in each delegated Phase 2 brief; do not duplicate unrelated context.

If Phase 1 reveals a larger or more complex codebase than expected (for example, a plugin system, multi-tenant architecture, complex auth chains, or multiple deployment targets), deepen those areas before proceeding. Apply INT-4 again rather than automatically adding agents.

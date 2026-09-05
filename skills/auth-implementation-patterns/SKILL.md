---
name: auth-implementation-patterns
description: Use when implementing or reviewing JWT, OAuth2/OIDC, sessions, cookies, refresh tokens, RBAC/ABAC, multi-tenant authorization, SSO, login, endpoint access control, token storage, cross-tenant data access, or any auth-related security bug.
---

# Authentication & Authorization Patterns

Auth is **not done** until token handling, storage, authorization checks, failure behavior, and tests are explicit. Wrong = account takeover, tenant escape, silent privilege escalation. Not for generic form validation.

## Pick The Pattern

| Scenario | Token | Storage |
|---|---|---|
| **Browser SPA** | Short JWT / opaque session | **httpOnly + Secure + SameSite=Lax** cookie; CSRF token |
| **Mobile** | Short access + rotating refresh | OS keychain. Never AsyncStorage plaintext |
| **M2M** | OAuth2 `client_credentials`, short JWT | Memory; validate `aud`/`iss`/`exp` strictly |
| **3rd-party API** | Long-lived API key / OAuth2 scopes | Hashed at rest; per-key rate limit + revoke UI |
| **SSO** | OIDC code flow + PKCE | httpOnly cookie; redirect allowlist; `state` + `nonce` |
| **B2B multi-tenant** | + tenant claim | Verify tenant on **every** data access (repository) |
| **CDN + auth UI** | None on CDN | Don't gate static; skeletons + API 401 |

Two rows apply → use storage row, layer multi-tenant on top.

## Required Workflow

1. **Trust boundary** — browser / API / service / worker / IdP.
2. **State model** — server session / stateless / opaque / hybrid.
3. **Lifetimes** — access expiry, refresh rotation, idle/absolute timeout, logout, compromised-token response.
4. **Storage explicit** — browser default = httpOnly cookie; never `localStorage` / `sessionStorage` for tokens or PII.
5. **Authorization at TWO layers** — boundary (middleware/guard) AND business ops (ownership / tenant / resource). Guards alone insufficient.
6. **Structured errors without leakage** — `references/security-checklist.md`.
7. **Tests** — success, expiry, revocation, missing auth, wrong role/owner/tenant, replay, refresh reuse, logout idempotency.

## Review Priority

1. **Leakage / bypass / tenant escape / replay / missing authz.** Exploitable now.
2. **Expiry / rotation / revocation / CSRF gaps.** Time bombs.
3. **Error / logging / observability / test gaps.** Hurts in incident.
4. **Maintainability.**

## Reference Map

- `references/security-checklist.md` — credentials / tokens / authz / OAuth / logging
- `references/jwt.md` — validation, claims, key rotation, pitfalls
- `references/oauth-oidc.md` — code flow, PKCE, state, refresh, B2B SSO

Read reference before implementing — flow details, claim names, timing windows vary.

## Boundary

- **This skill** = vendor-neutral patterns (model, lifecycle, RBAC/ABAC, threat, "done").
- Better Auth / NextAuth / IdentityServer / Keycloak: this skill gives the model; library syntax via Context7 MCP.

## Notes

Prefer framework's official auth extension points over custom middleware — re-implementing session/CSRF/PKCE is the top auth CVE source.

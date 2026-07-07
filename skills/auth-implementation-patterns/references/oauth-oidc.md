# OAuth 2.0 & OIDC — Flow & Integration

Read this when integrating with an external IdP (Google, Microsoft, GitHub, Auth0, Okta, Keycloak) or building one yourself. OAuth2 = delegated authorization; OIDC = authentication on top of OAuth2.

## Pick The Flow

| Use case | Flow | Notes |
|---|---|---|
| Server-side web app login (you control redirect URI) | **Authorization Code + PKCE** | Default. PKCE recommended even for confidential clients. |
| SPA login (no server) | **Authorization Code + PKCE** | Never implicit flow — deprecated, leaks tokens via fragment. |
| Mobile / desktop native app | **Authorization Code + PKCE** | Use system browser, not embedded webview. |
| Machine-to-machine (cron, backend service) | **Client Credentials** | No user. Cache token until expiry. |
| Device with no browser (CLI, smart TV) | **Device Authorization Grant** | User completes auth on a different device. |
| Legacy / first-party password (not recommended) | Resource Owner Password Credentials | **Avoid**. OAuth2.1 deprecates this. |

OAuth2.1 (in progress) standardizes: PKCE always, no implicit, no ROPC. Aim for OAuth2.1-compatible from day one.

## Authorization Code + PKCE Flow

1. Client generates `code_verifier` (random 43–128 chars) and `code_challenge` = SHA-256(verifier), base64url-encoded.
2. Client redirects user to authorization endpoint with: `client_id`, `redirect_uri`, `response_type=code`, `scope`, `state` (random, CSRF), `code_challenge`, `code_challenge_method=S256`, plus `nonce` for OIDC.
3. User authenticates and consents at IdP.
4. IdP redirects back to `redirect_uri` with `code` and the original `state`.
5. **Client verifies `state`** matches what was sent (CSRF defense). Reject mismatches.
6. Client POSTs to token endpoint: `code`, `redirect_uri`, `client_id`, `code_verifier`. IdP verifies `SHA-256(code_verifier) == code_challenge`.
7. IdP returns access token + refresh token (+ id_token for OIDC).
8. **For OIDC**: validate id_token signature, `iss`, `aud`, `exp`, **`nonce`** (matches what client sent), `at_hash` if present.

## Critical Validation

- **Redirect URI**: registered exactly with IdP. No wildcard subdomains. No open redirect on your side.
- **state**: must round-trip; verify on callback. Bind to user's session (e.g., set as cookie pre-redirect).
- **nonce** (OIDC): same — round-trip and verify.
- **id_token** validation = JWT validation (see `jwt.md`) plus `nonce` check.
- **Token endpoint** call uses HTTPS, includes client authentication (client_secret for confidential, none for public + PKCE).

## Common Pitfalls

- **No PKCE on public clients**: token theft via authorization code interception (especially mobile apps with custom URL schemes).
- **`state` not verified**: CSRF — attacker tricks user into linking their account to attacker's.
- **`nonce` not verified**: token replay across sessions.
- **Implicit flow** (`response_type=token`): tokens in URL fragment leak via Referer / browser history. Removed in OAuth2.1.
- **Embedded webview for OAuth**: user can't see the URL, can't trust they're at the real IdP. Use system browser (`SFAuthenticationSession` / `Custom Tabs` / `BrowserView`).
- **Storing access token where XSS can read it**: localStorage = bad. Use httpOnly cookie (server-managed session) or memory (re-auth on reload).
- **Wildcard redirect URI registration**: `https://*.example.com/cb` allows attacker subdomain takeover to steal tokens.
- **Skipping refresh token rotation**: see `jwt.md` § Refresh Token Patterns.
- **`offline_access` scope without considering implications**: long-lived refresh tokens = persistent grant; needs a way for users to revoke from IdP.
- **Trusting `email_verified=false` from IdP**: attacker registers email they don't control; if your app links by email, they hijack the account. Require `email_verified=true` or do your own verification.

## Server-Side Session Pattern (Recommended For Web Apps)

Don't pass IdP tokens to the browser. Instead:

1. Server completes the OAuth flow.
2. Server stores access/refresh tokens server-side (DB or session store).
3. Server issues its **own** session cookie (httpOnly + Secure + SameSite) to the browser.
4. Browser sends session cookie; server uses stored tokens to call the IdP / resource server.

Pros: token never touches browser; server controls revocation; XSS can't steal the IdP token (only the session cookie, which the server can revoke).

This is the default for new projects per global CLAUDE.md.

## SSO (Multiple Apps Behind One IdP)

- Each app is an OAuth client; users sign in once at the IdP and SSO-jump.
- Logout has two flavors:
  - **Local logout**: clears app session only — user still signed in at IdP.
  - **Single Logout (SLO)**: also calls IdP's logout endpoint. OIDC RP-Initiated Logout spec — pass `id_token_hint` and `post_logout_redirect_uri`. Allowlist the redirect like the login redirect.
- For B2B: support per-tenant IdP (different orgs use different IDPs) by routing on email domain → tenant → IdP config.

## B2B SAML (When OIDC Is Not Available)

Some enterprise IdPs only speak SAML. Treat as a black box: use a battle-tested library (e.g., `Sustainsys.Saml2` for .NET, `passport-saml` for Node) — never roll your own SAML. The validation surface (signature, encryption, replay, XML signature wrapping) is huge.

## Verification

- Test: callback with mismatched `state` → reject.
- Test: callback without `code` → reject.
- Test: id_token with bad `nonce` → reject.
- Test: id_token signed with key not in IdP's JWKS → reject.
- Test: redirect URI with extra query params or fragment → reject (or normalized to registered URI exactly).
- Test: refresh token revocation on logout actually invalidates IdP-side grant when SLO is enabled.
- Test: `email_verified=false` accounts handled per your linking policy.

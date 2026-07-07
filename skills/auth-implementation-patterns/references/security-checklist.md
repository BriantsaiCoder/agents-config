# Auth — Security Checklist

Walk this list when implementing or reviewing any auth flow. Each item is a "won't be undone if you ship without it" risk.

## Credentials

- Passwords hashed with **Argon2id**, **bcrypt**, or **PBKDF2** with appropriate work factors.
- Never plain SHA-256 / MD5 / unsalted hashes.
- Account enumeration prevented: signup / login / reset return identical responses regardless of whether the email exists.
- Rate limiting and lockout / exponential backoff for login, password reset, OTP, refresh, and token endpoints. Per-account AND per-IP, with operator unlock.

## Tokens

- Access tokens **short-lived** (5–30 min typical).
- Refresh tokens **rotated** on every use, **hashed at rest**, **revocable** server-side. Detect rotation reuse.
- JWT validation: verify **signature**, **iss**, **aud**, **exp**, **nbf**, and an **algorithm allowlist** (reject `alg: none`; reject HS256 when expecting RS256). Support key rotation via `kid` + JWKS.
- Cookies: `HttpOnly` + `Secure` + appropriate `SameSite` (`Lax` default, `Strict` for sensitive). CSRF protection (token or `SameSite=Strict`) on every state-changing endpoint that uses cookie auth.

## Authorization

- Centralized policy- or attribute-based authorization. No scattered manual `if (user.role === 'admin')` in route handlers.
- Multi-tenant code verifies tenant boundary on **every** data access path — at the repository layer, not just the controller. See `references/jwt.md` § "Tenant claim handling".

## OAuth / OIDC

- `state` (CSRF) and **PKCE** used. PKCE always for public clients, recommended even for confidential.
- Redirect URIs **allowlisted exactly**. No wildcard hosts.

## Logs and Errors

- No passwords, raw tokens, secrets, reset links, or full PII in logs or error responses.
- Log token IDs / hashes only.
- No "user not found" vs "wrong password" distinction surfaced to the client.

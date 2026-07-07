# JWT — Validation Flow & Pitfalls

Read this when implementing or reviewing JWT issuance, validation, refresh, or revocation. Most JWT bugs come from skipping a validation step or trusting a claim before verifying the signature.

## Issuance Defaults

- **Algorithm**: prefer **RS256** (asymmetric) for distributed systems; **HS256** only when the verifier is the issuer (single service).
- **Lifetime**:
  - Access token: **5–30 min** (short enough to limit blast radius, long enough to avoid refresh storms).
  - Refresh token: **7–30 days** with rotation on every use; absolute max 90 days.
- **Required claims**: `iss`, `sub`, `aud`, `exp`, `iat`, `jti` (unique per token, enables revocation list).
- **Optional but useful**: `nbf` (not-before), `auth_time`, `scope`, custom claims (`tenant_id`, `role`, `permissions`).

Don't put PII (email, full name, address) in the access token unless the client genuinely needs it on every request — JWTs are visible to any holder.

## Validation Steps (In Order)

1. **Decode** without verifying — read header to find `kid` and `alg`.
2. **Algorithm allowlist**: reject `alg: none`, reject `HS256` when expecting `RS256` (the classic algorithm-confusion attack), reject any algorithm not in your allowlist.
3. **Fetch the verification key** — for RS256 use JWKS endpoint with `kid`; cache JWKS with TTL (5–60 min) and refresh on `kid` miss.
4. **Verify signature** — fail closed if anything is wrong with the signature.
5. **Verify claims**:
   - `exp` > now (with small leeway, e.g., 30s clock skew).
   - `nbf` ≤ now (if present).
   - `iss` matches expected issuer exactly (string compare, not regex).
   - `aud` contains your audience (may be string or array).
6. **Now** trust the claims — extract `sub`, `tenant_id`, `role`, etc.

Skipping step 4 and reading claims is the most common bug. Library defaults usually do this in the right order — use the library's `verify()`, not its `decode()`.

## Key Rotation

- Issuer publishes JWKS (`/.well-known/jwks.json`) with `kid`s.
- Verifier caches JWKS; on `kid` miss, refresh once before failing.
- Roll new `kid` in advance, keep old `kid` in JWKS until all tokens with old `kid` have expired.
- Never sign with multiple keys simultaneously — one active signing key, multiple verification keys during overlap.

## Refresh Token Patterns

| Pattern | Pros | Cons |
|---|---|---|
| **Rotation + reuse detection** | Detects stolen tokens | Requires server state |
| Stateless refresh (just longer JWT) | Simple | Can't revoke |
| Sliding session cookie | Simple, works with stateful sessions | Requires sticky sessions or shared store |

**Recommended (rotation + reuse detection)**:

1. Refresh request: client sends current refresh token.
2. Server validates signature + lookup in DB (refresh tokens are **stored hashed**, like passwords).
3. Mark the used refresh token as **consumed** (don't delete — keep for reuse detection window).
4. Issue **new** refresh token + access token.
5. If a **consumed** refresh token is presented again → **revoke entire token family** (all descendants). This is reuse detection: someone replayed an old token, treat as compromise.

## Revocation

Stateless JWTs cannot be "revoked" — they're valid until `exp`. Two approaches:

- **Short-lived access tokens**: 5–15 min `exp` makes revocation = "wait 15 min". Acceptable for most use cases.
- **Revocation list**: maintain a `jti` blocklist (Redis with TTL = remaining token lifetime). Check on every request — adds latency but enables instant logout/ban.

Pick one and document it. "We use JWT" without a stated revocation strategy is a gap.

## Common Pitfalls

- **`alg: none` accepted**: ancient bug, but still surfaces in custom verifiers. Always allowlist algorithms.
- **Algorithm confusion**: server expects RS256 but accepts HS256 with the public key as HMAC secret → attacker forges tokens. Allowlist enforces the expected algorithm only.
- **No `aud` check**: token issued for service A accepted by service B.
- **`exp` of `0`** or missing: some libraries treat this as "no expiry" — reject tokens without `exp`.
- **Trusting claims before signature verification**: any header/payload data is attacker-controlled until signature is verified.
- **JWT in localStorage**: XSS = full token theft. Use httpOnly cookies (default in global CLAUDE.md).
- **Refresh token in localStorage**: same issue, worse blast radius (long-lived).
- **No refresh rotation**: stolen refresh = permanent access until manual revocation.
- **Refresh tokens stored plaintext in DB**: DB leak = all sessions compromised. Hash like passwords.

## Tenant Claim Handling (B2B Multi-Tenant)

Token contains `tenant_id` claim. Two enforcement layers:

1. **Middleware** sets `req.tenantId = jwt.tenant_id` after validation.
2. **Repository layer** filters every query by `tenantId` — never trust the controller to pass it. Use a Postgres RLS policy, EF Core query filter, or repository wrapper that injects the tenant filter automatically.

Tenant escape happens when one layer is bypassed (admin queries skipping the filter, raw SQL, internal service calls without context). Make it impossible to forget by enforcing at the data layer, not the request layer.

## Verification

- Test: token with bad signature → 401.
- Test: token with `alg: none` → 401.
- Test: token with valid signature but expired `exp` → 401.
- Test: token with wrong `aud` → 401.
- Test: refresh token reused → all descendant tokens revoked (assert via login attempt with new access token failing).
- Test: tenant A user requesting tenant B resource → 403 (or 404 to prevent enumeration).

---
# 全域規則，無 paths
---

# 安全性規則

## 認證 / 授權

- **Web API**：JWT 優先放 httpOnly cookie，不放 localStorage / sessionStorage
- **Refresh token** 必須 httpOnly + SameSite=Strict + Secure
- Public endpoint 必須明確標註（屬性 / 路徑前綴 / middleware 設定）
- Role / permission 檢查在 middleware / filter，不散落於 controller

## Secrets 管理

- 程式內禁止 hardcode secret；一律 env var 或 secret manager
- 提供 `.env.example`（**只含 key name，禁實際值**）
- `.env`、`appsettings.Production.json`、`secrets.json` 必須加入 `.gitignore`
- WinForms / Console 本機 secrets 用 DPAPI / `ProtectedData`，不明文
- CI/CD secrets 透過 GitHub Actions Secrets / Vault，禁透過 env file commit

## 輸入驗證

- **所有外部輸入**（HTTP body、query、header、file name、filesystem path）必須驗證
- 白名單優先（allow specific pattern）而非黑名單（block known bad）
- 檔名 / 路徑：拒絕 `..`、絕對路徑、special char
- 上傳檔案：驗證 MIME + magic number + 副檔名三者

## Injection 防護

- **SQL**：一律用參數化查詢 / ORM；禁字串拼接
- **Command injection**：用 exec 陣列語法，不 `shell: true`；必要時 escape
- **LDAP / XPath**：用 library 提供的 escape API
- **Path traversal**：`path.resolve()` 後檢查是否在允許的 base dir 內

## XSS / CSRF

- 輸出 encoding：template engine 預設 escape（Razor / Vue / React 皆自動）
- 原始 HTML 注入 API（React `dangerouslySetInnerHTML` / Vue `v-html`）使用前必須經 sanitizer 過濾（例：DOMPurify）
- CSRF：SameSite cookie + CSRF token（非 SPA）/ double submit cookie
- CSP header：`default-src 'self'`；不 inline script（用 nonce）

## 密碼

- Hash：Argon2id 優先，bcrypt 次之；**禁 MD5 / SHA-1**
- 最短長度 12 字；不強制符號組合（降低 entropy）
- 登入失敗速率限制（per-account + per-IP）
- 密碼重設 token：single-use + 15 min TTL + httpOnly cookie 或 URL

## 前端儲存禁令

- `localStorage` / `sessionStorage` **禁放 tokens / 敏感資料**
- 敏感資料只存記憶體（closure / store）；重整後重新取得
- 第三方 script（analytics、ads）需確認不讀取 app state

## CORS

- 明確列出 allowed origins，不用 `*`（除非 public API）
- `credentials: true` 時 origin 必須白名單，且不可為 `*`

## Dependency 安全

- CI pipeline 加 `npm audit` / `dotnet list package --vulnerable`
- `Renovate` / `Dependabot` 設 security patch 自動合併
- 主版本升級開 PR 討論，測試回歸

---
# 全域規則，無 paths
---

# Git Commit 規則

## Message 格式（Conventional Commits, zh-TW）

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

## Type 類型

| Type | 用途 | 範例 |
|------|------|------|
| `feat` | 新功能 | `feat(auth): 新增 JWT refresh token 機制` |
| `fix` | Bug 修復 | `fix(api): 修正訂單金額四捨五入錯誤` |
| `chore` | 雜務（deps、config） | `chore(deps): 更新 EF Core 至 9.0` |
| `refactor` | 重構（不改行為） | `refactor(user): 抽出 UserService 共用邏輯` |
| `test` | 測試 | `test(order): 補 CreateOrder 邊界測試` |
| `docs` | 文件 | `docs(readme): 更新啟動指令` |
| `perf` | 效能優化 | `perf(query): 加 index 降低 order list 查詢時間` |
| `style` | 格式（不改邏輯） | `style: prettier 格式化` |
| `build` | 建置系統 | `build(docker): 升級 base image` |
| `ci` | CI 設定 | `ci: 新增 lint step` |

## Scope 慣例

- 模組名稱（`api`、`auth`、`user`、`order`）
- Monorepo 可用 package 名（`@myapp/web`、`@myapp/api`）
- 跨模組變更省略 scope：`refactor: 統一 logger instance`

## Description 規則

- **zh-TW**，首字小寫（中文無大小寫）
- 動詞開頭：新增 / 修正 / 更新 / 移除 / 重構 / 優化
- 50 字以內；詳細內容寫 body
- 不加句點
- 指令式語氣（「新增 xxx」不是「新增了 xxx」）

## Branch 命名

- `feat/` — 新功能
- `fix/` — Bug 修復
- `chore/` — 雜務
- `refactor/` — 重構
- Kebab-case：`feat/user-2fa-login`

## 禁止 commit

- `.env`、credentials、private key
- `node_modules/`、`bin/`、`obj/`、`dist/`
- `*.log`、`*.swp`、`.DS_Store`
- 大型二進位（> 1 MB）除非必要
- Lockfile 衝突未解決版

## Tag / Release

- SemVer：`v{major}.{minor}.{patch}`
- Breaking change → major；新功能 backward compatible → minor；bug fix → patch
- Pre-release：`v1.2.0-rc.1`、`v1.2.0-beta.2`

## Force push 政策

- `main` / `master`：**禁止 force push**
- 個人 feature branch：僅 `--force-with-lease`，不用 `--force`

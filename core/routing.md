<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/routing.md | last-verified: 2026-07-27 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（正本：dev-workflow）

- 開發任務先讀 ~/.agents/skills/dev-workflow/SKILL.md 並依 S0 路由。錯誤行為／測試失敗／regression → BUGFIX；單一 target file、≤3 actionable tasks 且無風險攔截 → sdd。
- 三 host 點名路由：dev-workflow、sdd、deps-check、mp-grill-with-docs、mp-diagnose、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan。
- 通用：stack 實作 → `*-best-practices`；Auth → `auth-implementation-patterns`；Docker → `containerization`；Tailwind v4 → `tailwind-v4-shadcn`；新專案 → `init-project-docs`；整庫上手 → `acquire-codebase-knowledge`。
- 專項：Vite → `vite`；Vitest → `vitest`；安全稽核 → `security-audit`；PR 安全審查 → `security-review`；瀏覽器探索 → `agent-browser`；React Router framework mode → `react-router-framework-mode`；原生感跨平台桌面 app → `native-feel-cross-platform-desktop`；skill 稽核 → `auditing-skill-folder`；VueUse 選型 → `vueuse-functions`。
- Stack 細則：`~/.agents/rules/<stack>.md`（dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook）。

## 最高風險攔截（常駐，防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈）

- [R-1] 收尾類 skill（如 finishing-a-development-branch）MUST NOT 在 S4/S5 全綠前 invoke。觸發：任務仍有 FAIL 或未跑的 verify / review gate。驗證：S4 與 S5 四態全 PASS 才放行。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無 seam（須標記）。

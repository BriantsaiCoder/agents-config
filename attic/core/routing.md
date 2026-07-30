<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/routing.md | last-verified: 2026-07-27 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（正本：dev-workflow）

- 先讀 ~/.agents/skills/dev-workflow/SKILL.md 並依 S0 路由。錯誤／測試失敗／regression → BUGFIX；單一 target file、≤3 tasks 且無風險攔截 → sdd。
- 三 host：dev-workflow、sdd、deps-check、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan；需求壓測 → grilling + domain-modeling；架構 → codebase-design；診斷 → diagnosing-bugs；TDD → tdd；review → code-review。顯式：/grill-with-docs、/improve-codebase-architecture（Copilot prompt）。
- 通用：stack → `*-best-practices`；Auth → auth-implementation-patterns；Docker → containerization；Tailwind v4 → tailwind-v4-shadcn；新專案 → init-project-docs；整庫 → acquire-codebase-knowledge。
- 專項：Vite → vite；Vitest → vitest；安全稽核 → security-audit；PR 安全審查 → security-review；瀏覽器探索 → agent-browser；React Router → react-router-framework-mode；跨平台桌面 app → native-feel-cross-platform-desktop；skill 稽核 → auditing-skill-folder；VueUse → vueuse-functions。
- Stack 細則：`~/.agents/rules/<stack>.md`（dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook）。

## 最高風險攔截

- [R-1] push／open PR／merge／final closeout MUST NOT 在 S4/S5 全綠前執行。觸發：任一收尾動作。驗證：S4 與 S5 各適用 gate PASS；SKIPPED／UNAVAILABLE 附理由或 probe。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無 seam（須標記）。

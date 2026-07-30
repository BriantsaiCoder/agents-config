# 語料分割基準 — 2026-07-28

生成方式（可重跑）:

```bash
bash ~/.agents/skills/auditing-skill-folder/scripts/check-vendored.sh
grep "^skill=" ~/.agents/mattpocock-skills.lock | cut -d= -f2
```

detector 健康度: `bash ~/.agents/tests/vendored-detection.sh` → 33 PASS / 0 FAIL（2026-07-28 實跑）

| 群 | 數量 | 可否原地編輯 |
|---|---|---|
| 全部 | 72 | — |
| VND（vendored） | 29 | ✗ 只能 leave / wrap / retire / replace |
| ├ mattpocock pinned set | 22 | ✗ 整組替換 + lock/hash 驗證 |
| └ 其他上游 | 7 | ✗ agent-browser 的 SKILL.md 例外 |
| house-editable | 44 | ✓ |

## VND — mattpocock pinned（22）

- `ask-matt`
- `code-review`
- `codebase-design`
- `diagnosing-bugs`
- `domain-modeling`
- `grill-me`
- `grill-with-docs`
- `grilling`
- `handoff`
- `implement`
- `improve-codebase-architecture`
- `prototype`
- `research`
- `resolving-merge-conflicts`
- `setup-matt-pocock-skills`
- `tdd`
- `teach`
- `to-spec`
- `to-tickets`
- `triage`
- `wayfinder`
- `writing-great-skills`

## VND — 其他上游（7）

- `=`
- `agent-browser`
- `native-feel-cross-platform-desktop`
- `playwright-best-practices`
- `security-audit`
- `tailwind-v4-shadcn`
- `vueuse-functions`

## house-editable（44）

- `acquire-codebase-knowledge`
- `auditing-skill-folder`
- `auth-implementation-patterns`
- `backend-release-verification`
- `bug-fix-settlement`
- `c-cpp-best-practices`
- `containerization`
- `css-ui-best-practices`
- `dapper-best-practices`
- `dependency-security-scan`
- `deps-check`
- `dev-workflow`
- `dotnet-core-best-practices`
- `dotnet-framework-best-practices`
- `dotnet-logging-best-practices`
- `dotnet-testing-best-practices`
- `dotnet-winforms-best-practices`
- `ef-core-best-practices`
- `ef6-best-practices`
- `frontend-release-verification`
- `init-project-docs`
- `jest-best-practices`
- `mp-diagnose`
- `mp-grill-with-docs`
- `mp-improve-codebase-architecture`
- `mp-tdd`
- `mp-zoom-out`
- `mysql-best-practices`
- `next-best-practices`
- `nodejs-best-practices`
- `nuxt`
- `pinia`
- `postgresql-best-practices`
- `postgresql-optimization`
- `react-best-practices`
- `react-router-framework-mode`
- `sdd`
- `security-review`
- `testing-library-react-best-practices`
- `typescript-best-practices`
- `vite`
- `vitest`
- `vue-best-practices`
- `vue-debug-guides`

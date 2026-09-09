---
name: playwright-best-practices
description: "Write, review, or debug Playwright tests; use its MCP branch only when Playwright is the chosen browser tool."
---

# Playwright Best Practices

Most flakiness comes from fighting Playwright's auto-waiting model: CSS locators over user-facing locators, `waitForTimeout`, shared state, and assertions before the UI is observable.

## Default Workflow

1. Read existing `playwright.config.*`, fixtures, projects, and test style. Match conventions before adding abstractions.
2. Pick the narrowest test type and run: API/component/E2E/visual, then `npx playwright test <file> -g "title"`.
3. Prefer role/label/text locators, then `getByTestId`; use DOM/CSS selectors only with a maintenance reason.
4. Use web-first assertions (`toBeVisible`, `toHaveText`, `toHaveURL`) instead of fixed sleeps.
5. On failure, inspect trace/screenshot/console/network/locator state before changing waits.

## Top Rules

- Reuse auth state with global setup and `storageState` when the app supports it.
- Keep tests isolated: own context/data; no implicit state sharing through `beforeAll`.
- Register `page.route(...)` before navigation or user actions that trigger the request.
- Avoid full-page snapshots; snapshot small stable regions or mask volatile areas.
- Do not make tests serial to hide a flake. Fix the shared state, timing, or selector problem.
- For local browser exploration or MCP-driven flows, capture screenshots and report console/page errors.

## MCP / Browser Workflow

- Read `references/mcp-workflow.md` when driving Playwright MCP to explore, generate, or fill forms.
- Keep ownership of pages/contexts clear; close only pages opened by the agent.
- For frontend validation, cover mobile and desktop viewports; add tablet for critical flows.

## Common Patterns

- Read `references/common-patterns.md` for concise examples.
- Read `references/python-tooling.md` only for Python Playwright projects.
- For deep or version-sensitive Playwright APIs, check the project's installed Playwright version and official docs instead of relying on vendored long references.

## Validation Loop

1. Run targeted: `npx playwright test <file> --reporter=list`.
2. Debug with trace / screenshot / console / network evidence.
3. Fix root cause; rerun targeted.
4. For formerly flaky critical tests, rerun with `--repeat-each=10` when practical.

# Playwright MCP Workflow

Use the Playwright MCP server (`mcp__playwright__*` tools) to drive a real browser interactively — exploring sites, filling forms for users, or generating tests grounded in actual page snapshots rather than guesswork.

## Contents

- Exploring a website before authoring tests
- Generating a `@playwright/test` test from observed steps
- Automating form fill-out for users (with safety gate)

## Exploring a Website for Test Authoring

When the user asks to "explore this site for testing", "map out the user flows", or "see what is on this page":

1. Navigate to the provided URL via `browser_navigate`. If no URL given, ask.
2. Identify and interact with 3–5 core features or user flows (e.g., login, search, primary CTA, settings, checkout).
3. For each interaction, use `browser_snapshot` to capture the accessibility tree and note:
   - The user-facing action (e.g., "Submit search query")
   - The exact locator strategy (`getByRole('button', { name: 'Search' })`, `getByLabel('Email')`, `getByTestId('submit-btn')`)
   - The expected outcome (URL change, visible toast, network call, DOM update)
4. Close the browser context (`browser_close`) when done.
5. Return a concise summary of findings.
6. Propose candidate test cases derived from the exploration; do not write code yet — generation is a separate step.

## Generating a Playwright Test from a Scenario

When the user asks to "write a Playwright test for X", "generate e2e test for login", or "automate this scenario":

**Iron rule**: do not write test code based solely on the textual scenario. Drive the MCP first; emit code last.

1. If no scenario is given, ask for one.
2. Run each step of the scenario via MCP tools (`browser_navigate`, `browser_click`, `browser_fill_form`, `browser_press_key`, `browser_wait_for`, etc.). Capture `browser_snapshot` between steps to confirm state.
3. Only after the scenario completes successfully, emit a `@playwright/test` TypeScript test based on the observed message history. Use:
   - User-facing locators (`getByRole`/`getByLabel`/`getByText`) over CSS.
   - Web-first assertions (`await expect(locator).toBeVisible()`).
   - `test.describe` + `test.beforeEach` for shared setup.
   - Trace and screenshot config in `playwright.config.ts` for failure diagnosis.
4. Save under the project's tests directory (typically `tests/` or `e2e/` — check existing structure).
5. Execute the generated test and iterate until it passes.

## Automating Form Fill-Out for Users

When the user asks to "fill in this form for me", "automate this signup flow", or "complete this checkout via Playwright":

1. Confirm the form URL and the field values from the user. Do not invent values.
2. Navigate via `browser_navigate`.
3. Use `browser_snapshot` to inspect actual field structure (input names, select options, checkbox groups, file upload widgets, conditional fields revealed only after parent selections).
4. Fill fields via `browser_fill_form` or per-field tools (`browser_click`, `browser_type`, `browser_select_option`, `browser_file_upload`).
5. Handle dynamic/conditional fields by re-snapshotting after each parent change.
6. **Do NOT submit by default.** Pause and ask the user to review the filled form before triggering submission. Only submit after explicit confirmation.

## Safety Notes

- Default to `--isolated` MCP config (per `~/.claude/playwright-mcp-config.json`) so sessions do not leak state.
- Always close pages/contexts at end of session — orphan Chromium processes signal missing cleanup.
- Never persist credentials the user provided as one-off values into stored files.

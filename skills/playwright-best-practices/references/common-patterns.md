# Common E2E Testing Patterns (Playwright + Cypress)

Framework-agnostic E2E testing patterns that apply to **both Playwright and Cypress**. For Playwright-specific deep references see `core/`, `advanced/`, `debugging/`, `testing-patterns/` folders. For Python Playwright tooling see `references/python-tooling.md`.

> Merged from: `e2e-testing-patterns` (originally covered both Playwright and Cypress).

## Testing Philosophy

### What to Test with E2E

- Critical user journeys (login, checkout, signup)
- Complex interactions (drag-and-drop, multi-step forms)
- Cross-browser compatibility
- Real API integration
- Authentication flows

### What NOT to Test with E2E

- Unit-level logic (use unit tests)
- API contracts (use integration tests)
- Edge cases (too slow to exercise via browser)
- Internal implementation details

### Testing Pyramid

```
        /\
       /E2E\         ← Few, focused on critical paths
      /─────\
     /Integr\        ← More, test component interactions
    /────────\
   /Unit Tests\      ← Many, fast, isolated
  /────────────\
```

## Core Best Practices (both tools)

1. **Test user behavior, not implementation** — click/type/see, not internal state
2. **Keep tests independent** — no shared mutable state between tests
3. **Make tests deterministic** — flaky test = broken test
4. **Optimize for speed** — mock external APIs, use parallel execution
5. **Use data attributes** — `data-testid` / `data-cy` over CSS classes
6. **Clean up test data** — each test creates and destroys its own fixtures

## Good vs Bad Selectors (both tools)

```typescript
// ❌ Bad — couples to implementation
cy.get(".btn.btn-primary.submit-button").click();
cy.get("div > form > div:nth-child(2) > input").type("text");
page.locator("div > form > div:nth-child(2)").click();

// ✅ Good — semantic & stable
cy.getByRole("button", { name: "Submit" }).click();
cy.getByLabel("Email address").type("user@example.com");
cy.get('[data-testid="email-input"]').type("user@example.com");

page.getByRole("button", { name: "Submit" }).click();
page.getByLabel("Email address").fill("user@example.com");
page.getByTestId("email-input").fill("user@example.com");
```

## Playwright vs Cypress — Quick Comparison

| Aspect | Playwright | Cypress |
|---|---|---|
| Browser support | Chromium, Firefox, WebKit | Chromium-family (+ experimental Firefox) |
| Language | JS/TS, Python, .NET, Java | JS/TS only |
| Parallel execution | Built-in, free | Paid dashboard or external orchestration |
| iframe support | Full | Limited |
| Multiple tabs/windows | Native | Workaround required |
| Network mocking | `page.route()` | `cy.intercept()` |
| Auto-waiting | Yes (locators auto-wait) | Yes (commands auto-retry) |
| Cross-origin testing | Built-in | Requires config |
| Recording tools | Playwright Codegen | Cypress Studio |

**Recommendation for new projects**: Playwright first, Cypress if team is already invested or needs Cypress Cloud features.

## Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30000,
  expect: { timeout: 5000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [["html"], ["junit", { outputFile: "results.xml" }]],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
    { name: "mobile", use: { ...devices["iPhone 13"] } },
  ],
});
```

## Cypress Configuration

```typescript
// cypress.config.ts
import { defineConfig } from "cypress";

export default defineConfig({
  e2e: {
    baseUrl: "http://localhost:3000",
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    setupNodeEvents(on, config) {
      // Implement node event listeners
    },
  },
});
```

## Pattern: Page Object Model (both tools)

See `core/page-object-model.md` for deep Playwright POM treatment. Brief example:

```typescript
// Playwright POM
export class LoginPage {
  constructor(private page: Page) {}

  readonly emailInput = this.page.getByLabel("Email");
  readonly passwordInput = this.page.getByLabel("Password");
  readonly loginButton = this.page.getByRole("button", { name: "Login" });

  async goto() { await this.page.goto("/login"); }
  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }
}
```

Cypress equivalent uses custom commands rather than classes:

```typescript
Cypress.Commands.add("login", (email: string, password: string) => {
  cy.visit("/login");
  cy.getByLabel("Email").type(email);
  cy.getByLabel("Password").type(password);
  cy.getByRole("button", { name: "Login" }).click();
});
```

## Pattern: Fixtures for Test Data (Playwright)

See `core/test-data.md` and `core/fixtures-hooks.md` for deep Playwright fixtures. Brief example:

```typescript
import { test as base } from "@playwright/test";

export const test = base.extend<{ testUser: { email: string; password: string } }>({
  testUser: async ({}, use) => {
    const user = { email: `test-${Date.now()}@example.com`, password: "Test123!@#" };
    await createTestUser(user);
    await use(user);
    await deleteTestUser(user.email);  // cleanup
  },
});
```

## Pattern: Waiting Strategies

**Always prefer condition-based waits over fixed timeouts.** See `core/assertions-waiting.md` for deep Playwright coverage.

```typescript
// ❌ Bad: Fixed timeouts
await page.waitForTimeout(3000);

// ✅ Good: Wait for specific conditions
await page.waitForLoadState("networkidle");
await page.waitForURL("/dashboard");

// ✅ Better: Auto-waiting with assertions
await expect(page.getByText("Welcome")).toBeVisible();
await expect(page.getByRole("button", { name: "Submit" })).toBeEnabled();

// Wait for API response
const responsePromise = page.waitForResponse(
  (r) => r.url().includes("/api/users") && r.status() === 200
);
await page.getByRole("button", { name: "Load Users" }).click();
await responsePromise;
```

Cypress equivalent uses `cy.wait('@alias')` with intercept aliases.

## Pattern: Network Mocking

See `core/configuration.md` and `advanced/network-advanced.md` for deep Playwright coverage.

**Playwright** — `page.route()`:
```typescript
test("displays error when API fails", async ({ page }) => {
  await page.route("**/api/users", (route) => {
    route.fulfill({
      status: 500,
      contentType: "application/json",
      body: JSON.stringify({ error: "Internal Server Error" }),
    });
  });
  await page.goto("/users");
  await expect(page.getByText("Failed to load users")).toBeVisible();
});
```

**Cypress** — `cy.intercept()`:
```typescript
cy.intercept("GET", "/api/users", {
  statusCode: 200,
  body: [{ id: 1, name: "John" }, { id: 2, name: "Jane" }],
}).as("getUsers");
cy.visit("/users");
cy.wait("@getUsers");
cy.get('[data-testid="user-list"]').children().should("have.length", 2);
```

## Pattern: Visual Regression Testing (Playwright)

```typescript
import { test, expect } from "@playwright/test";

test("homepage looks correct", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveScreenshot("homepage.png", {
    fullPage: true,
    maxDiffPixels: 100,
  });
});

test("button in all states", async ({ page }) => {
  await page.goto("/components");
  const button = page.getByRole("button", { name: "Submit" });

  await expect(button).toHaveScreenshot("button-default.png");

  await button.hover();
  await expect(button).toHaveScreenshot("button-hover.png");

  await button.evaluate((el) => el.setAttribute("disabled", "true"));
  await expect(button).toHaveScreenshot("button-disabled.png");
});
```

## Pattern: Parallel Testing with Sharding (Playwright)

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: "shard-1",
      use: { ...devices["Desktop Chrome"] },
      grepInvert: /@slow/,
      shard: { current: 1, total: 4 },
    },
    {
      name: "shard-2",
      use: { ...devices["Desktop Chrome"] },
      shard: { current: 2, total: 4 },
    },
  ],
});
```

CI 命令：`npx playwright test --shard=1/4`

## Pattern: Accessibility Testing

```typescript
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("page should not have accessibility violations", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page })
    .exclude("#third-party-widget")
    .analyze();
  expect(results.violations).toEqual([]);
});
```

## Common Pitfalls (both tools)

- **Flaky Tests**: use proper waits, not fixed timeouts
- **Slow Tests**: mock external APIs, use parallel execution
- **Over-Testing**: don't test every edge case with E2E (use unit tests)
- **Coupled Tests**: tests should not depend on each other
- **Poor Selectors**: avoid CSS classes and `nth-child`
- **No Cleanup**: clean up test data after each test
- **Testing Implementation**: test user behavior, not internals

## Debugging

```bash
# Playwright
npx playwright test --headed      # visible browser
npx playwright test --debug       # step-through with inspector
npx playwright show-trace trace.zip  # trace viewer
```

```typescript
// Playwright: structured steps for clearer reports
test("checkout flow", async ({ page }) => {
  await test.step("Add item to cart", async () => {
    await page.goto("/products");
    await page.getByRole("button", { name: "Add to Cart" }).click();
  });
  await test.step("Proceed to checkout", async () => {
    await page.goto("/cart");
    await page.getByRole("button", { name: "Checkout" }).click();
  });
});

await page.pause();  // pause and open inspector
```

See `debugging/debugging.md`, `debugging/flaky-tests.md`, `debugging/console-errors.md` for Playwright-specific deep dives.

# Deployment Gate Implementation

CI pass alone does not establish readiness. Assess the following gates against changed behavior and the repo/authorized deployment contract. Record PASS/FAIL/SKIPPED/UNAVAILABLE and reasons; examples below are not new mandatory infrastructure. Required gates block promotion, while absent optional gates become a documented gap.

## 1. Bundle Size Budget

- **Tools:** `size-limit` (multi-framework, lockfile-aware) or `bundlewatch`. Framework-native equivalents (`next-bundle-analyzer`, Vite `rollup-plugin-visualizer`) for inspection only.
- **Thresholds:** absolute cap per chunk (e.g., main bundle ≤ 200 kB gzipped, route chunk ≤ 80 kB) plus relative diff vs base branch (warn +5%, block +10%).
- **CI step:** PR job runs build, computes size, compares to base; fail if any cap or block-threshold tripped.
- **Evidence:** bundle report artifact and comparison; publish a PR comment only within authorized scope.
- **Skip rationale (must record):** pure backend/config change with no client output.

## 2. Lighthouse CI (LHCI)

- **Tools:** `@lhci/cli` invoked via `treosh/lighthouse-ci-action` or equivalent. Run against PR preview URL (Vercel/Netlify/Cloudflare Pages) or temporary local server.
- **Targets (Core Web Vitals 2024+):** LCP ≤ 2.5s, CLS ≤ 0.1, INP ≤ 200ms, TBT ≤ 200ms. Categories — Performance ≥ 0.9, Accessibility ≥ 0.95, Best Practices ≥ 0.95, SEO ≥ 0.9 for marketing pages.
- **`.lighthouserc.json` minimal shape:**
  ```json
  {
    "ci": {
      "collect": { "url": ["https://preview.example.com/"] },
      "assert": {
        "assertions": {
          "categories:performance": ["error", { "minScore": 0.9 }]
        }
      }
    }
  }
  ```
- **Failure handling:** `error`-level assertions block merge; `warn`-level surfaces in PR but does not block.
- **Skip rationale (must record):** non-public route, internal admin tool with no perf SLA, or no preview URL available.

## 3. Staging Smoke E2E (post-deploy)

- **Stack:** Playwright with a dedicated `staging` project in `playwright.config.ts` whose `baseURL` points at the staging deployment.
- **Scope:** critical-path subset only — auth login, primary data flow, checkout, mutation endpoints. Tag with `*.smoke.spec.ts` filename or `@smoke` annotation. Do NOT run full E2E suite against staging.
- **Trigger:** deploy-to-staging job's post-deploy hook (GitHub Actions `needs: deploy-staging`), not the PR CI.
- **Failure handling:** auto-rollback the staging deploy or hold the prod promotion gate. Never auto-promote to prod on red staging smoke.
- **Evidence:** Playwright trace + screenshot artifacts retained per staging-smoke run; surface in deploy summary.
- **Unavailable/skip rationale (must record):** no staging environment exists. Report the gap; block promotion when staging smoke is required by the deployment contract. Do not provision staging without authorization.

## Browser Smoke Detail

For user-facing frontend changes, verify at least:

- App opens without blank screen or blocking runtime error.
- Changed critical journey works in a real browser.
- Relevant route navigation and data mutation work when touched.
- Error / empty / loading state covered when the change affects API state handling.
- Mobile `375px` and desktop `1280px` checked. Add tablet `768px` for auth, checkout, forms, routing, or data mutation.
- Console errors and page errors captured, classified, and not ignored. A run with unexplained errors is not a clean pass.
- Screenshot or equivalent browser evidence available for UI/layout changes.

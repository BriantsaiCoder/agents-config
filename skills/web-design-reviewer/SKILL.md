---
name: web-design-reviewer
description: "Use when visually reviewing a running website or repairing a rendered defect with browser evidence. Review-only requests produce findings; release gates use frontend-release-verification."
---

# Visual web repair

Own visual assessment of a rendered page and explicitly authorized visual repairs. Reuse the available browser and repository styling system.

## Boundaries

- Review-only requests stop after evidence-backed findings.
- A request containing fix／repair／修 authorizes source changes within the
  reviewed page's files; a bare review reports only. Treat production as
  read-only unless that authorization is explicit.
- Known code-only CSS/accessibility work routes to `css-ui-best-practices`.
- Behavioral, console, and responsive bug debugging uses the installed frontend testing/debugging capability (for example `build-web-apps:frontend-testing-debugging`). Product-flow critique uses `product-design:audit`; visual assessment stays here.
- Release gates route to `frontend-release-verification`; committed browser
  tests route to `playwright-best-practices`.

**REQUIRED BACKGROUND:** `css-ui-best-practices` for CSS/accessibility
classification after live evidence is captured.

## Workflow

1. Confirm the URL, affected page/state, viewport(s), repository, and whether
   source edits are authorized.
2. Read the repository to identify the framework, design system, and styling
   mechanism. Capture a baseline screenshot plus relevant DOM and console/page
   errors at the affected viewport. Apply the required background to classify
   CSS/accessibility defects; this skill still owns the browser-to-source loop.
3. Identify the rendered element by selector, visible text, class, test ID, or
   component structure. Use `rg` to trace that evidence to the source and the
   actual style owner. If the source cannot be proven, do not edit it.
4. For review-only work, report the visual defect, evidence, source candidate,
   severity, and recommended fix, then stop.
5. For authorized repair, change one finding at a time. Preserve the existing
   component and styling patterns; avoid redesign or new dependencies.
6. Reload/HMR and capture the same viewport. Compare before/after; for shared
   CSS, check both mobile and desktop for regressions. Record console/page
   errors.
7. Repeated failure calls for diagnosis using the selector, source candidates,
   screenshots, errors, and attempts made. Continue authorized checks and fixes;
   ask only when a missing fact, access, or action authorization blocks the next
   dependent repair.

## Completion evidence

Report URL/state, viewport(s), changed source files, verification result, and
unresolved risks. Review-only work includes baseline/finding evidence; repairs
include same-viewport before/after evidence. Never claim a visual fix from code
inspection alone.

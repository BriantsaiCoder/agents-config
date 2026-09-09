---
name: testing-library-react-best-practices
description: "Write or review React Testing Library tests for observable user behavior, accessible queries, and async interactions; runner configuration uses Jest or Vitest."
---

# React Testing Library Best Practices

> **Scope**: this skill covers React + React Testing Library specifically. For Vue component, composable, or Pinia store testing, use `vue-best-practices`. For Vitest configuration / mocking issues regardless of framework, use `vitest`.

## Core Rule

Test what the user can observe or do. Avoid testing component state, private functions, CSS selectors, DOM structure, or implementation-specific test IDs unless no user-facing query exists.

## Writing Workflow

1. Identify the user behavior and expected visible result.
2. Render through the same providers/routes the feature needs.
3. Create `const user = userEvent.setup()` and use `await user.*` for interactions.
4. Query via `screen`, using accessibility-first queries.
5. Assert visible state, accessible names, validation messages, navigation, or callback effects at public boundaries.
6. For async UI, use `findBy*` or `waitFor` around the final observable result.
7. Add regression coverage for the bug or branch that motivated the test.

## Query Priority

Use queries in this order:
1. `getByRole` with accessible name.
2. `getByLabelText` for form controls.
3. `getByText` for visible content.
4. `getByDisplayValue` / `getByAltText` where appropriate.
5. `getByTestId` only when there is no stable user-facing query.

Use `queryBy*` only for absence assertions. Use `findBy*` when the element appears after async work.

## Review Checklist

- Tests use `screen` and accessibility queries instead of `container.querySelector`.
- Interactions use `userEvent`, not low-level `fireEvent`, except for unsupported events.
- Tests await async interactions and async UI updates.
- Assertions verify behavior, not internal state or class names.
- Forms are tested through labels, roles, validation messages, and submit behavior.
- Mocks are at external boundaries such as network, router, storage, clock, or browser APIs.
- Each regression test fails before the fix and passes after it.

## React-Specific Reference

For React Testing Library, `renderHook`, hooks, context providers, forms, Suspense, and router patterns, read `references/react.md` only when the task needs those details.

## Verification

Run the relevant test command from project config. For flaky interaction tests, rerun the targeted test and inspect whether timing, missing awaits, or implementation-focused queries are the cause.

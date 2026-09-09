---
name: typescript-best-practices
description: "Write or review TypeScript types, narrowing, runtime boundaries, and compiler configuration; framework-specific behavior uses its own stack skill."
---

# TypeScript Best Practices

## Mode

1. **Writing** — keep touched code type-safe within authorized scope and existing compiler policy. Repository-wide strict/compiler changes and public contracts follow S2; review-only work produces findings.
2. **Reviewing** — walk the rules as a checklist. Prioritize type safety (`any` / `as`) → correctness (missing narrowing) → patterns (`enum` vs `as const`).

If the code is primarily React- or Vue-specific, those skills apply too — but TS rules still cover the typing aspects.

## Golden Rules

Each rule's *why* + code examples + writing/reviewing patterns live in `references/rules-expanded.md`.

1. **Follow repository compiler policy and keep changed code type-safe.** Use strict checks for new projects; enabling `"strict": true` across an existing repo is a separate change when it expands scope.
2. **Prefer inference; annotate signatures + exports only.** *Why:* over-annotation = maintenance burden; masks inference improvements.
3. **`unknown` over `any`** + narrow before use. *Why:* `any` is a viral escape hatch that silently disables the checker.
4. **Discriminated unions for state**, not optional flags. *Why:* optional fields allow impossible states; literal discriminant = exhaustive-checkable.
5. **Validate external data at runtime with existing tools.** Use installed schemas or narrow guards; compare new schema dependencies only if required capability is missing.
6. **Generics only when type genuinely varies.** *Why:* unnecessary generics obscure intent.
7. **`as` is a code smell.** Prefer type guards, discriminated unions, schema validation. *Why:* `as` bypasses the checker exactly where you need it.
8. **`satisfies` over `as const` + type annotation.** *Why:* preserves literal-type inference AND verifies shape against target type.
9. **Consider branded IDs when domain confusion is a demonstrated risk**, preserving public/serialization contracts.
10. **Exhaustive switch with `never` default.** *Why:* new union variant flags every unhandled switch.
11. **Preserve the repo's enum/literal convention.** Change representation only for a concrete runtime, compiler, or domain need; inspect consumers first.
12. **`@ts-expect-error` with reason, never `@ts-ignore`.** *Why:* expect-error fails when the error disappears; ignore silently hides forever.

## Reference Map

| Need | File |
|---|---|
| Why behind each rule + code examples + writing / reviewing patterns | `references/rules-expanded.md` |
| Type inference, union/intersection, literal/template-literal/conditional/mapped/index access types | `references/type-system-fundamentals.md` |
| Generic patterns (constraints, defaults, inference), built-in utility types, custom utilities | `references/generics-and-utilities.md` |
| Discriminated unions, type guards (`is`/`asserts`), exhaustive checking, branded types, Zod / Valibot | `references/patterns-and-guards.md` |
| `tsconfig` strict mode breakdown, `module`/`target`/`paths`, barrel exports, ESLint + typescript-eslint, declaration files, monorepo | `references/config-and-project.md` |
| Aggregated working patterns + advanced type design | `references/working-patterns.md` |

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.

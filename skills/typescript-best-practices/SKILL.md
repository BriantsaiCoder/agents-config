---
name: typescript-best-practices
description: 'Use when writing or reviewing TypeScript: .ts/.tsx, generics, conditional/mapped/template-literal types, discriminated unions, type guards, assertion functions, Zod schemas, tsconfig strictness, any/as cleanup, API typing, or tightening types. Apply even when user just says "tighten this type", "any is leaking", "add Zod schema", "infer this generic", "narrow this union", or asks why a type is unexpectedly widened.'
---

# TypeScript Best Practices

## Mode

1. **Writing** — apply Golden Rules proactively. Don't ask before using strict types or discriminated unions; just do it and briefly explain *why* if it differs.
2. **Reviewing** — walk the rules as a checklist. Prioritize type safety (`any` / `as`) → correctness (missing narrowing) → patterns (`enum` vs `as const`).

If the code is primarily React- or Vue-specific, those skills apply too — but TS rules still cover the typing aspects.

## Golden Rules

Each rule's *why* + code examples + writing/reviewing patterns live in `references/rules-expanded.md`.

1. **`"strict": true` always.** *Why:* `strictNullChecks` alone prevents the majority of "cannot read property of undefined" crashes.
2. **Prefer inference; annotate signatures + exports only.** *Why:* over-annotation = maintenance burden; masks inference improvements.
3. **`unknown` over `any`** + narrow before use. *Why:* `any` is a viral escape hatch that silently disables the checker.
4. **Discriminated unions for state**, not optional flags. *Why:* optional fields allow impossible states; literal discriminant = exhaustive-checkable.
5. **Zod / Valibot at runtime boundaries**; `z.infer` for the static type. *Why:* TS types erased at runtime; external data needs runtime proof.
6. **Generics only when type genuinely varies.** *Why:* unnecessary generics obscure intent.
7. **`as` is a code smell.** Prefer type guards, discriminated unions, schema validation. *Why:* `as` bypasses the checker exactly where you need it.
8. **`satisfies` over `as const` + type annotation.** *Why:* preserves literal-type inference AND verifies shape against target type.
9. **Branded types for semantically-distinct IDs.** *Why:* prevents passing `OrderId` where `UserId` expected.
10. **Exhaustive switch with `never` default.** *Why:* new union variant flags every unhandled switch.
11. **Avoid `enum`; use `as const` object.** *Why:* enums have runtime quirks; as-const = plain JS that tree-shakes cleanly.
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

Open one file at a time — don't preload.

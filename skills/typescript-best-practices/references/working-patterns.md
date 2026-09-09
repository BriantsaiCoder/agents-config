# TypeScript Working Patterns & Advanced Type Design

Detailed working patterns extracted from `SKILL.md` to keep the main file compact.

## Working pattern for *writing* new TypeScript code

1. Confirm the target environment — Node.js version, bundler (Vite/webpack/esbuild), framework (React/Vue/none). This determines `module`, `moduleResolution`, and `target` in tsconfig.
2. Define the data shapes first. Use interfaces for object shapes, type aliases for unions/intersections/utilities.
3. Use discriminated unions for any multi-state domain object (API responses, form state, auth state).
4. At API boundaries, validate with existing schemas or narrow runtime guards; follow the [canonical boundary-validation choice](rules-expanded.md#5-zod--valibot-at-runtime-boundaries). Derive types from schemas when the selected library supports it.
5. Write functions with explicit return type annotations for public APIs; let inference handle internal functions.
6. Use generics only when the function genuinely operates on a parameterized type.
7. If you need to narrow an unknown value, write a type guard (`function isUser(x: unknown): x is User`).
8. For `fetch` calls: check `res.ok` before parsing and await `res.json()` when a JSON body is expected; validate the result with the existing schema or sufficient runtime guards, using the same boundary-validation criteria.
9. Run `tsc --noEmit` to verify — zero errors is the goal.

## Working pattern for *reviewing* TypeScript code

Walk the file top-to-bottom and check, in this order:

1. **Type safety**: any `any` types? `as` assertions without justification? `@ts-ignore` instead of `@ts-expect-error`? Missing `strictNullChecks`?
2. **Runtime correctness**: missing `await` on async calls (especially `res.json()`)? Unchecked `res.ok` on fetch? Unhandled Promise rejections? Missing error handling on I/O?
3. **Correctness**: optional fields where a discriminated union is more appropriate? Missing exhaustive checks in switch/if chains? Unchecked `.data!` non-null assertions?
4. **Patterns**: using `enum` where `as const` would be better? Over-annotating types the compiler can infer? Unnecessary generics? (Note: `as const` + exhaustive switch work together — see `references/patterns-and-guards.md` for combined example.)
5. **Boundary safety**: API responses typed but not validated at runtime? `JSON.parse()` result used without validation?
6. **Security**: logging or exposing sensitive data (tokens, passwords, PII) in `console.log`, error messages, or string templates? Secrets should never appear in logs or error output.
7. **Config**: is `strict: true`? Are path aliases set up? Is `moduleResolution` appropriate for the bundler?

Report findings grouped by severity (type safety → correctness → patterns → config), each with a concrete code-level fix.

## Advanced type design (generics, conditional/mapped/template-literal types)

When the request is to *design* complex type logic — generic helpers, conditional types, mapped types, template literal types, type-level state machines — apply this decision flow before reaching for cleverness.

### Decision workflow

1. **Define the invalid states** the type should prevent. If you can't name a real bug class, the type isn't pulling its weight.
2. **Check for existing utilities** in the project, schema layer (Zod), or framework (React's `ComponentProps`, Vue's `ExtractPropTypes`). Don't reinvent.
3. **Pick the simplest construct** that enforces the rule, in this order: explicit interface → union → discriminated union → generic with constraint → mapped type → conditional type → template literal type. Stop at the first one that works.
4. **Keep runtime validation separate.** Compile-time types don't protect untrusted boundaries; use existing schemas or sufficient runtime guards under the same boundary-validation criteria.
5. **Add type tests** (`expectTypeOf`, `tsd`, or compile-fail snippets) for reusable utilities so behavior doesn't silently change.
6. **Watch compiler perf and error readability.** Deeply recursive conditional types kill `tsc` perf and produce unreadable errors. If `hover` shows a multi-line monster, simplify.

### Design checklist

- Prefer discriminated unions over optional-property soup for variant state (Golden Rule 4).
- Prefer `unknown` + narrowing over `any` at boundaries (Golden Rule 3).
- Prefer **inference at call sites**; avoid forcing callers to pass generic parameters manually. Add `<T extends Foo = DefaultFoo>` defaults sparingly.
- Avoid deeply recursive / highly nested conditional types unless there is clear payoff.
- Document exported utility types with one **valid** and one **invalid** example so reviewers see the intent.
- Use `satisfies` or `as const` when preserving literal types improves safety (Golden Rule 8).
- Add exhaustive checks (Golden Rule 10) anywhere a discriminated union is consumed.

### Review questions

- Does the type prevent a real bug, or only mirror obvious structure?
- Could a simpler interface or union express the same rule?
- Are `as` assertions hiding unsafe casts?
- Are runtime inputs validated before being trusted as typed values?
- Are errors understandable when the type fails?
- Are there compile-time tests for shared utility types?

### Verification

Run the project's TypeScript check — usually `tsc --noEmit`, `vue-tsc --noEmit`, or the configured `typecheck` script. For library utilities, add or run type tests when the project supports them.

# TypeScript Golden Rules — Expanded

The Why behind each rule + code examples.

## 1. Respect repository compiler policy

`"strict": true` enables strict checking for new projects. In an existing repo, keep touched code safe under current policy; a repository-wide compiler migration requires matching scope.

**Why**: `strictNullChecks` alone prevents the majority of "cannot read property of undefined" runtime crashes. Turning it off defeats TS's primary value.

## 2. Prefer inference; annotate signatures + exports

Don't annotate every variable. Annotate function returns and public API signatures explicitly.

**Why**: Over-annotation is maintenance burden + masks inference improvements in newer TS. `const x = 5` is `5`, not `number`.

## 3. `unknown`, not `any`

When type is genuinely unknown (API response, catch block, dynamic data), use `unknown` and narrow before use.

```typescript
// ❌ Bad
function parse(input: any) { return input.name; }

// ✅ Good
function parse(input: unknown): string {
  if (typeof input === 'object' && input !== null && 'name' in input) {
    return (input as { name: string }).name;
  }
  throw new Error('Invalid input');
}
```

**Why**: `any` silently disables the type checker for that value and everything it flows into — viral escape hatch.

## 4. Discriminated unions for state

Literal discriminant field, not optional properties.

```typescript
// ❌ allows { loading: false, data: undefined, error: undefined }
type State = { loading: boolean; data?: User; error?: Error };

// ✅ each state distinct + exhaustive-checkable
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: User }
  | { status: 'error'; error: Error };
```

**Why**: Optional fields allow impossible states; discriminated unions make each state explicit.

## 5. Zod / Valibot at runtime boundaries

Validate fetch responses, form input, and env vars using the existing schema library or narrow runtime guards. The Zod example applies when Zod is already selected; do not add it merely to follow the example.

```typescript
const UserSchema = z.object({ id: z.string(), name: z.string() });
type User = z.infer<typeof UserSchema>;
const user = UserSchema.parse(await res.json());
```

**Why**: TS types erased at runtime. External data needs runtime proof; `z.infer` keeps type + validation in sync.

## 6. Generics only when type genuinely varies

**Why**: Unnecessary generics obscure intent. `function identity<T>(x: T): T` is a textbook example, not a production pattern.

## 7. `as` is a code smell

Every `as` is "trust me, compiler". Prefer type guards, discriminated unions, schema validation.

**Why**: `as` bypasses the type checker exactly where you need it most; wrong assertion = silent runtime bug.

## 8. `satisfies` over `as const` + type annotation

```typescript
// ❌ Loses literal types
const routes: Record<string, string> = { home: '/', about: '/about' };

// ✅ Preserves literal types + checks shape
const routes = { home: '/', about: '/about' } satisfies Record<string, string>;
```

**Why**: Get both autocomplete on inferred literals AND compile-time check against target type.

## 9. Consider branded types for demonstrated ID-confusion risks

```typescript
type UserId = string & { readonly __brand: unique symbol };
type OrderId = string & { readonly __brand: unique symbol };
function getUser(id: UserId): User { ... } // OrderId won't fit
```

**Why**: Prevents passing `OrderId` where `UserId` expected — bug class plain `string` can't catch.

## 10. Exhaustive switch + `never`

```typescript
default: {
  const _exhaustive: never = value;
  return _exhaustive;
}
```

**Why**: Adding a new union variant flags every unhandled switch — instant zero-cost coverage.

## 11. Choose enum or literal representation from repository needs

`const Status = { Active: 'active', Inactive: 'inactive' } as const`.

**Why**: Enums have runtime quirks (numeric reverse mapping, `const enum` + `--isolatedModules` issues). As-const = plain JS, tree-shakes cleanly.

## 12. `@ts-expect-error` with reason, never `@ts-ignore`

If you must suppress, `@ts-expect-error // reason`.

**Why**: `@ts-expect-error` fails when the error goes away (signals cleanup); `@ts-ignore` silently hides issues forever.

## Working Pattern — Writing

1. Inspect compiler policy; a local fix does not authorize changing repository-wide strict settings.
2. Start from data shapes and validate external input with existing schemas/guards; infer types where the selected library supports it.
3. Model state with discriminated unions; never optional flags that allow impossible combinations.
4. Functions: annotate return + parameters; let body types infer.
5. `unknown` for dynamic input + narrow with type guards / `in` / `typeof`.
6. `satisfies` for config objects, route maps, lookup tables.
7. Consider branded IDs only where domain confusion warrants them; preserve consumers and serialization contracts.
8. Exhaustive switch with `never` default for unions.

## Working Pattern — Reviewing

1. **Type safety** — `any` (explicit or implicit)? `as` to cast away mismatches? `@ts-ignore` without reason?
2. **State modeling** — boolean flags allowing impossible combos? Optional `data` + optional `error` instead of discriminated union?
3. **Boundary validation** — `await res.json()` typed by hand without runtime check? Form input cast to type without parse?
4. **Inference** — over-annotated locals? Function return type omitted on exported function?
5. **Generics** — generic that only ever takes one type? Constraint missing on a generic that should be narrowed?
6. **Patterns** — `enum` in new code? `as const` + manual type annotation where `satisfies` would work?
7. **Suppression** — `@ts-ignore` without justification? Stale `@ts-expect-error` that no longer triggers?

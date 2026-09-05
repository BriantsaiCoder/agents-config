# Mutation Catalog

Read when selecting candidate mutations. These examples do not replace domain analysis; classify mode and evidence using [SKILL.md](../SKILL.md).

## Boundary Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `<` | `<=` | Off-by-one at upper bound |
| `>` | `>=` | Off-by-one at lower bound |
| `<=` | `<` | Boundary inclusion |
| `>=` | `>` | Boundary inclusion |
| `== 0` | `== 1` or `<= 0` | Zero-boundary handling |
| `i < length` | `i < length - 1` or `i <= length` | Loop boundary |
| `index + 1` | `index` or `index + 2` | Index arithmetic |

## Boolean and Logic Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `&&` | `\|\|` | Condition independence |
| `\|\|` | `&&` | Condition necessity |
| `!condition` | `condition` | Negation correctness |
| `if (x)` | `if (!x)` | Branch selection |
| `true` (constant) | `false` | Hardcoded assumption |
| `flag \|\| other` | `other` | Short-circuit first operand |

## Return Value Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `return result` | `return null` / `return None` / `return nil` / `return undefined` | Null/None/nil handling downstream |
| `return result` | `return default(T)` / `return T()` / `return ""` / `return 0` | Default value handling |
| `return true` | `return false` | Boolean return verification |
| `return list` | `return new List<T>()` / `return []` / `return Array.Empty<T>()` / `return make([]T, 0)` / `return Vec::new()` / `return @[]` | Empty collection handling |
| `return count` | `return 0` or `return count + 1` | Numeric return verification |
| `return string` | `return ""` or `return null`/`None`/`nil` | String return verification |
| `return Ok(x)` | `return Err(...)` (Rust) | Result/error variant |
| `return value, nil` | `return zero, err` (Go) | Error tuple |

## Exception / Error Removal Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `throw new ArgumentNullException(...)` (.NET) / `raise ValueError(...)` (Python) / `throw new Error(...)` (JS) / `throw new IllegalArgumentException(...)` (Java) / `panic!(...)` (Rust) / `panic(...)` (Go) / `raise ArgumentError` (Ruby) / `throw RuntimeException(...)` (Kotlin) / `throw FooError.bar` (Swift) / `throw "..."` (Pester) / `throw std::invalid_argument(...)` (C++) | _(remove entire throw/raise/panic)_ | Guard clause verification |
| `if (x == null) throw ...` / `if x is None: raise ...` / `if (!x) throw ...` / `if x == nil { return err }` (Go) / `assert!(x.is_some())` (Rust) | _(remove entire guard)_ | Null/None/nil guard testing |
| `if (!IsValid()) throw ...` / `if not is_valid(): raise ...` / etc. | _(remove entire check)_ | Validation testing |
| `return err` after error check (Go) | _(remove or swallow error)_ | Error propagation |
| `?` operator (Rust) | `.unwrap()` or `.expect(...)` | Error short-circuit |

## Arithmetic Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `a + b` | `a - b` | Addition correctness |
| `a - b` | `a + b` | Subtraction correctness |
| `a * b` | `a / b` | Multiplication correctness |
| `a / b` | `a * b` | Division correctness |
| `a % b` | `a / b` | Modulo correctness |
| `x++` | `x--` | Increment direction |
| `-value` | `value` | Sign flip |

## Null / None / Nil-Check Removal Mutations

| Original | Mutation | What it tests |
|----------|----------|---------------|
| `if (x == null) return ...` / `if x is None: return ...` / `if (!x) return ...` / `if x == nil { return ... }` / `unless x; return; end` (Ruby) / `if x.is_none() { return ... }` (Rust) | _(remove null/None/nil check)_ | Null path coverage |
| `if (x != null) { ... }` / `if x is not None: ...` / `if x: ...` / `if x != nil { ... }` / `x?.let { ... }` (Kotlin) / `if let Some(x) = ... { ... }` (Rust) | _(always enter block)_ | Null/None/nil guard necessity |
| `x ?? defaultValue` (.NET/JS/Swift) / `x or defaultValue` (Python) / `x \|\| defaultValue` (JS) / `x.unwrap_or(defaultValue)` (Rust) / `x \|\| defaultValue` (Kotlin: `x ?: defaultValue`) | `x` (drop coalescing) | Null coalescing coverage |
| `x?.Method()` (.NET/Swift/Kotlin) / `x && x.method()` (JS) / `x and x.method()` (Python) | `x.Method()` | Null-conditional coverage |
| `x!` (Swift) / `x!!` (Kotlin) / `.unwrap()` (Rust) | `x` | Runtime force-unwrap necessity; C# and TypeScript `!` are compile-time-only and therefore equivalent mutants |

# C / C++ Core Rules

## Contents
- Part A: C
- Part B: Modern C++
- Part C: Shared CMake, toolchain, sanitizers, testing
- Part D: Platform specifics

## Part A — C (`.c` / `.h`)

A1. **Encode memory ownership in API and naming, not comments.** C has no destructor; ownership transfer is invisible without convention. Use `_own` suffix on returned pointers that the caller must free, `_ref` on borrowed pointers; pair every `malloc`/`calloc`/`realloc` with one `free` in the same logical owner. Allocate sized buffers via `calloc(n, sizeof(T))` not `malloc(n * sizeof(T))` — `calloc` checks for integer overflow.

A2. **Pick one error channel per function: return code OR `errno`, never both.** Mixing creates ambiguity (was the call OK? did `errno` leak from a prior call?). POSIX-style: return `int` (0 = OK, nonzero = code) or `-1` + `errno`. Reset `errno = 0` before calls that signal only via `errno` (`strtol`, `wcstoll`). Document the channel in the header.

A3. **`goto cleanup` is the right pattern for multi-resource functions.** No destructors means no RAII; nested `if/else` with duplicated `free` in every branch is the worse alternative. Acquire → check → on error `goto fail;` → release in reverse order at one label. Caught by maintainers; recommended by Linux kernel coding style.

A4. **Header hygiene: opaque pointer + forward declaration over wide includes.** `typedef struct foo foo_t;` in the public header, full `struct foo { ... };` in the `.c`. Cuts compile time and ABI surface; consumers can't poke fields. Use `#pragma once` (universally supported on MSVC / GCC / Clang / MinGW); fall back to include guards only for strict portability requirements.

A5. **`extern "C"` at the C/C++ boundary, opaque handle, no class types in the header.** C++ name-mangling and class layout aren't C ABI. Wrap public declarations:
```c
#ifdef __cplusplus
extern "C" {
#endif
typedef struct foo foo_t;
foo_t* foo_create(void);
void   foo_destroy(foo_t*);
#ifdef __cplusplus
}
#endif
```
Pass C++ objects across the boundary only via opaque handles + free function.

A6. **String / buffer: `snprintf` with explicit size; never `strcpy` / `sprintf` / `gets` / `scanf %s`.** (CLAUDE.md mandates the blacklist.) Always pass destination capacity; check return: `< 0` is error, `>= size` is truncation — both must be handled. For dynamic strings, `realloc` into a temp pointer first, check non-NULL, then assign — direct `p = realloc(p, n)` leaks on failure.

A7. **`static` for internal linkage; default `extern` is too leaky.** Functions and globals not in the public header get `static`. Reduces symbol pollution, enables LTO inlining, prevents accidental cross-TU collision. ❌ unmarked global helper used by one `.c`. ✅ `static int helper(...)`.

A8. **C standard: target C17 explicitly.** Set `set(CMAKE_C_STANDARD 17)` + `CMAKE_C_STANDARD_REQUIRED ON`. C23 (typeof, nullptr, constexpr, true/false keywords) needs GCC 13+ / Clang 18+ / MSVC v17.9+ — adopt only when the entire compiler matrix supports it.

A9. **Test pure C with Unity or cmocka; reserve GoogleTest for C++ wrapping a C lib.** Unity is single-file MIT, easy CMake integration; cmocka has built-in mocking. Don't compile `.c` as `.cpp` to use GoogleTest — language semantics differ (e.g., `void*` implicit conversion, struct initializer rules).

---

## Part B — Modern C++ (`.cpp` / `.hpp` / `.cc`, C++17/20/23)

B1. **Default to `std::unique_ptr`; `std::shared_ptr` only for genuinely shared ownership.** `unique_ptr` is zero-overhead vs raw pointer; `shared_ptr` adds atomic refcount cost and obscures ownership. Use `std::weak_ptr` to break cycles. Raw pointer is acceptable for non-owning observation (see B2). ❌ `new`/`delete` outside library internals — use `std::make_unique` / `std::make_shared`.

B2. **Function signatures encode ownership: by-value owns, reference / `string_view` / `span` borrows.** Sink parameter (`std::string s`) takes ownership via move; `const std::string&` borrows; `std::string_view` (C++17) borrows without forcing null-termination. (C++20) `std::span<const T>` borrows a contiguous range — replaces the C-ism `T*, size_t`.

B3. **Rule of 0 by default; Rule of 5 only when managing a raw resource.** If members are smart pointers, containers, fundamental types — the compiler-generated copy/move/destructor is correct and optimal. Defining one of {dtor, copy ctor, copy=, move ctor, move=} forces all five — easy to break invariants. ❌ adding a dtor "just to log" silently disables move generation.

B4. **Error handling: `std::expected<T, E>` (C++23) or `std::optional<T>` for expected failures; exceptions for unrecoverable / invariant violations.** `std::expected` propagates without exceptions and works in `noexcept` paths. Mark moves and dtors `noexcept` — STL containers fall back to copy without it (silent perf regression). Embedded / RTTI-off: error-code only, exceptions disabled at compiler flag.

B5. **C++20 concepts replace SFINAE; CTAD eliminates explicit template arguments.** `template<std::integral T>` is clearer than `enable_if_t<is_integral_v<T>>`; `requires` clauses for ad-hoc constraints. CTAD: `std::pair{1, "x"}` not `std::pair<int, const char*>{1, "x"}`. `if constexpr` replaces tag dispatch for compile-time branching.

B6. **STL algorithms / ranges over raw loops.** `std::ranges::sort(v)` not `std::sort(v.begin(), v.end())`; `views::filter | views::transform` over handwritten loop-with-condition. Easier to read, harder to bug, often optimal under `-O2`. Raw `for (size_t i = 0; ...)` is a smell unless indexing is genuinely required (parallel arrays, index arithmetic).

B7. **Concurrency: `std::jthread` (C++20) over `std::thread`; `std::shared_mutex` for read-heavy; choose atomic memory order deliberately.** `jthread` auto-joins on destruction (RAII); `thread` requires explicit `.join()` or `std::terminate`. Default atomic to `seq_cst`; relax to `acquire/release` only with measured benefit and documented happens-before reasoning. Pad shared atomics to cache-line size (`alignas(64)`) to avoid false sharing.

B8. **PIMPL for ABI stability and compile-time isolation; modules only when toolchain-mature.** PIMPL (`std::unique_ptr<Impl> impl_;` in header, `Impl` defined in `.cpp`) hides implementation; ABI changes don't recompile consumers. C++20 modules eliminate header-include overhead; compiler support for `import std` has shipped (Clang 18.1.2+ with libc++ or libstdc++, MSVC toolset 14.36+ / VS 17.6+, GCC 15+), but the CMake side is still behind the experimental `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` gate and `CXX_MODULE_STD` defaults to off for backward compatibility (`CMAKE_CXX_MODULE_STD` needs CMake 3.30+) — production projects wait. Until then: `pragma once` + forward-declare aggressively (include-what-you-use principle).

B9. **Performance: alignment, layout, move semantics, RVO.** Hot structs: `alignas(64)` for cache-line alignment; group hot fields together (SoA over AoS for SIMD-friendly traversal). Pass / return by value to enable copy elision (RVO/NRVO); explicit `std::move` for sink parameters and returning local objects through `try`/`catch`. ❌ `return std::move(local);` defeats RVO — just `return local;`.

B10. **Anti-patterns: `new`/`delete`, C-style cast, macro for constants, singleton, mutable globals.**
- `new`/`delete` → `std::make_unique` / `std::make_shared`
- `(int)x` → `static_cast<int>(x)` (caught by clang-tidy `cppcoreguidelines-pro-type-cstyle-cast`)
- `#define PI 3.14` → `inline constexpr double pi = 3.14;`
- singleton / mutable global → constructor injection / explicit parameter / `inline thread_local`

---

## Part C — Shared (CMake, toolchain, sanitizers, testing)

C1. **CMake: target-based; `PUBLIC` / `PRIVATE` / `INTERFACE` keywords are mandatory.** `target_link_libraries(app PRIVATE foo)` — `app` uses `foo` but doesn't expose `foo`'s headers. `PUBLIC` propagates to consumers. `INTERFACE` for header-only libs. ❌ `link_libraries(...)` / `include_directories(...)` (global, pollutes siblings). CMake version window: 3.20+ for `CMakePresets.json`; on the upper side, CMake 4.0 removed compatibility with versions older than 3.5 — `cmake_minimum_required(VERSION <3.5)` or a `cmake_policy` targeting such a version is now a hard error, not a warning. On a legacy repo, read the top of `CMakeLists.txt` first: either raise the floor to 3.5+ or keep old policy behavior via range syntax (`cmake_minimum_required(VERSION 3.5...4.0)`), and verify the policy changes instead of bumping blind.

C2. **`CMakePresets.json` defines the toolchain matrix; CI runs every preset.** Define `windows-msvc` (VC++ / cl.exe), `windows-mingw` (mingw64 GCC), `linux-gcc`, `linux-clang`, `macos-clang`. CLAUDE.md mandates MSVC + MinGW both green for Windows code — ABI / runtime divergence catches latent bugs (e.g., MSVCRT vs UCRT mismatch).

C3. **Dependencies: vcpkg manifest mode (`vcpkg.json` + baseline) preferred; Conan 2 (`conanfile.txt` + `conan.lock`) as alternative.** Both lockfiles must commit. `find_package` consumes vcpkg / Conan output identically. ❌ `FetchContent_Declare` for production deps — no version pinning, no binary cache, slow CI.

C4. **Sanitizers: ASan + UBSan in dev and CI; TSan for multi-threaded modules.** GCC / Clang: `-fsanitize=address,undefined`. MSVC v16.9+: `/fsanitize=address` (UBSan not supported on MSVC — use Clang in CI for UBSan coverage). Run unit tests under sanitizers in at least one CI job. MinGW sanitizer support is patchy — fall back to MSVC ASan or valgrind on Windows-only targets.

C5. **clang-tidy + clang-format: committed config, CI gate.** Minimum `.clang-tidy` checks: `bugprone-*`, `cppcoreguidelines-*` (with project-specific suppressions for legitimate C-style buffer code), `modernize-*`, `performance-*`, `clang-analyzer-*`, `readability-*`. `.clang-format`: pick `Google` or `LLVM` base, customize once, never rotate styles within a repo (every rotation = full-tree diff noise).

C6. **Toolchain flags: VC++ `/W4 /WX /permissive- /utf-8`; GCC / Clang `-Wall -Wextra -Wpedantic -Werror`. `dllexport` via macro, never inline.** Treat warnings as errors prevents silent bit-rot. For DLL boundary, define `MYLIB_EXPORT` macro that expands to `__declspec(dllexport/import)` on MSVC / MinGW, `__attribute__((visibility("default")))` on GCC / Clang. Centralize in one header; `__declspec` scattered across declarations rots fast.

C7. **GoogleTest fixture / parameterized / death tests; Unity for C-only targets.** `TEST_F` for shared setup; `TEST_P` for parameter sweeps (avoid copy-pasted near-identical tests); `EXPECT_DEATH` for assertion / abort paths. Run the test binary under sanitizers in CI — production bugs surface as sanitizer reports, not test failures.

---

## Part D — Platform Specifics (Windows / cross-platform)

D1. **VC++ compiler flags: `/W4 /WX /permissive- /utf-8`. UCRT is default runtime.** `/permissive-` enforces standard conformance (rejects MSVC-specific extensions); `/utf-8` makes source + execution charset UTF-8 to avoid mojibake on non-Latin code. For `__declspec(dllexport/import)` see export macro pattern in C6.

D2. **MinGW-w64 specifics: MSYS2 `mingw64` env (GCC + MSVCRT runtime, NOT UCRT).** Do not link C++ binaries across MSVC and MinGW — CRT mismatch causes heap / locale / iostream divergence. For Windows API: pass `-municode` + explicit libs (`-lws2_32`, `-lkernel32`, `-luser32`). MSYS2 `ucrt64` env exists but its sanitizer support lags behind `mingw64`; default to `mingw64`.

D3. **Headers: `#pragma once` (default; supported by all major compilers since 2010). Follow Include-What-You-Use (IWYU) — don't rely on transitive includes.** When a TU uses `std::vector`, it must `#include <vector>` directly even if some transitively-included header pulls it in; transitive includes are an implementation detail and can break across STL upgrades.

D4. **Cross-platform APIs: prefer `<filesystem>` (paths), `<chrono>` (time), `<thread>` / `<jthread>` (concurrency), `<format>` (string formatting).** POSIX-only or Win32-only APIs must be isolated in `platform_*.cpp` files behind a stable C++ interface, or guarded with `#ifdef _WIN32` / `__linux__` / `__APPLE__`. Spreading `#ifdef` across business logic creates ports that drift.

D5. **Export macro pattern (DLL / shared object boundary):**
```cpp
// mylib_export.h
#ifdef MYLIB_BUILDING
  #define MYLIB_API __declspec(dllexport)  // MSVC / MinGW build side
#elif defined(_WIN32)
  #define MYLIB_API __declspec(dllimport)  // Windows consumer
#else
  #define MYLIB_API __attribute__((visibility("default")))  // GCC / Clang
#endif
```
Centralize once; never scatter `__declspec` across declarations.

D6. **Maintenance mode for legacy C / C++98/03 / pre-C++11 codebases: match existing style, don't modernize unsolicited.** Mixing modern RAII with legacy manual cleanup in the same file produces ABI / style hybrids that confuse reviewers and break refactor tools. Only introduce modern idioms in new files; flag legacy style as tech debt rather than rewriting silently.

---

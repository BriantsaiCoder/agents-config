---
name: c-cpp-best-practices
description: "Apply C/C++ safety, ownership, concurrency, and toolchain guidance when writing, reviewing, or debugging C/C++ code."
---

# C / C++ Best Practices

Match existing legacy style for old code unless the user asks for modernization.

## Workflow

1. Identify whether the touched files are C, C++, mixed C ABI, CMake/toolchain, or review-only.
2. Read [core-rules.md](references/core-rules.md) before implementing non-trivial C/C++ changes or when a review finding needs a rule explanation.
3. Apply the matching rule IDs: A for C, B for modern C++, C for shared toolchain/testing, D for platform specifics.
4. In reviews, report the rule ID and a concrete fix; do not rewrite unrelated legacy style.

## Routing

- Do not use for embedded, RTOS, bare-metal, Boost, Qt, or framework-specific patterns unless the user asks for general C/C++ safety guidance.
- Use `dotnet-testing-best-practices` for C++ wrappers consumed by .NET test projects.

## Reviewing — Severity Checklist

Use rule IDs to locate memory-safety, ABI, ownership, and concurrency risks. Severity follows reachable consequences and repository policy; raw `new`, casts, `shared_ptr`, or `std::thread` alone are not Critical/High defects. Treat style/tool alternatives as suggestions unless evidence establishes a defect.

| Review | Check | Rule |
|---|---|---|
| Inspect | `strcpy` / `sprintf` / `gets` / `scanf %s` | A6 |
| Inspect | Mismatched `malloc`/`free`, double-free, use-after-free | A1 + ASan |
| Inspect | Raw `new`/`delete` in C++ (outside lib internals) | B1 |
| Inspect | Atomic memory order without justification | B7 |
| Inspect | C++ class crossing C ABI without `extern "C"` + opaque handle | A5 |
| Inspect | `shared_ptr` without genuinely shared ownership | B1 |
| Inspect | `std::thread` instead of `std::jthread` on C++20 | B7 |
| Inspect | C-style cast `(T)x` instead of `static_cast` / `reinterpret_cast` | B10 |
| Inspect | `errno` + return code mixed in same API | A2 |
| Inspect | `target_link_libraries` without `PUBLIC`/`PRIVATE`/`INTERFACE` | C1 |
| Inspect | Custom dtor / copy without Rule of 5 | B3 |
| Inspect | Public C++ header includes impl (no PIMPL / fwd decl) | B8 |
| Inspect | `return std::move(local);` defeats RVO | B9 |
| Inspect | CMake global `link_libraries` / `include_directories` | C1 |
| Inspect | No `CMakePresets.json` despite multi-toolchain | C2 |
| Inspect | `FetchContent` for prod dep instead of vcpkg / Conan | C3 |
| Inspect | Sanitizer not enabled in any CI job | C4 |
| Inspect | `noexcept` missing on move ctor / dtor | B4 |
| Inspect | clang-tidy / clang-format not committed | C5 |
| Inspect | C/C++ standard not pinned in CMake | A8/B5 |
| Inspect | `dllexport` / `__declspec` scattered | C6 |

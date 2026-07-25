---
name: c-cpp-best-practices
description: 'Use when writing or reviewing C/C++: .c/.h/.cpp/.hpp/.cc/.cxx, ownership/malloc-free, errno/return codes, goto cleanup, C ABI, RAII/smart pointers, std::move/rule of 0/5, templates, threading, CMake/toolchains, vcpkg/Conan, MSVC/MinGW, unsafe C APIs, sanitizers ASan/UBSan/TSan. Symptoms: segfault/SIGSEGV, use-after-free, double-free, memory leak, undefined behavior, stack overflow, heap corruption, linker/unresolved symbol, dangling pointer, data race.'
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

Walk top-down. Flag rule ID (A1 / B7 / C3 …) + concrete fix from that rule. Critical = block merge; High = needs deferral justification; Medium/Low = tracked follow-up.

| Severity | Check | Rule |
|---|---|---|
| Critical | `strcpy` / `sprintf` / `gets` / `scanf %s` | A6 |
| Critical | Mismatched `malloc`/`free`, double-free, use-after-free | A1 + ASan |
| Critical | Raw `new`/`delete` in C++ (outside lib internals) | B1 |
| Critical | Atomic memory order without justification | B7 |
| Critical | C++ class crossing C ABI without `extern "C"` + opaque handle | A5 |
| High | `shared_ptr` without genuinely shared ownership | B1 |
| High | `std::thread` instead of `std::jthread` on C++20 | B7 |
| High | C-style cast `(T)x` instead of `static_cast` / `reinterpret_cast` | B10 |
| High | `errno` + return code mixed in same API | A2 |
| High | `target_link_libraries` without `PUBLIC`/`PRIVATE`/`INTERFACE` | C1 |
| Medium | Custom dtor / copy without Rule of 5 | B3 |
| Medium | Public C++ header includes impl (no PIMPL / fwd decl) | B8 |
| Medium | `return std::move(local);` defeats RVO | B9 |
| Medium | CMake global `link_libraries` / `include_directories` | C1 |
| Medium | No `CMakePresets.json` despite multi-toolchain | C2 |
| Medium | `FetchContent` for prod dep instead of vcpkg / Conan | C3 |
| Medium | Sanitizer not enabled in any CI job | C4 |
| Medium | `noexcept` missing on move ctor / dtor | B4 |
| Low | clang-tidy / clang-format not committed | C5 |
| Low | C/C++ standard not pinned in CMake | A8/B5 |
| Low | `dllexport` / `__declspec` scattered | C6 |

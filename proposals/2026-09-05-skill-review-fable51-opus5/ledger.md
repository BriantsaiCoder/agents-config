| Skill | VND | 模式 | 行 | 字 | desc 字元 | 用量 | listing tokens（CLI） | 本 session desc | 全域設定引用 | Verdict |
|---|---|---|---:|---:|---:|---:|---|---|---|---|
| acquire-codebase-knowledge | - | model | 92 | 482 | 323 | 8 | ~120 | - | dev-workflow | Keep |
| agent-browser | VND | model | 54 | 262 | 387 | 3 | ~130 | - | agents/ | Keep |
| apple-calendar | - | model | 145 | 658 | 214 | 1 | ~80 | - | — | Keep |
| ask-matt | VND* | user-only | 71 | 1113 | 83 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| aspnet-api-architect | - | model | 43 | 201 | 159 | 0 | ~60 | - | — | Keep |
| auditing-skill-folder | - | model | 43 | 290 | 283 | 16 | ~100 | - | dev-workflow | Keep |
| auth-implementation-patterns | - | model | 57 | 470 | 364 | 1 | ~130 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| backend-release-verification | - | model | 64 | 500 | 225 | 32 | ~90 | - | dev-workflow | Keep |
| bug-fix-settlement | - | model | 31 | 113 | 149 | 13 | ~60 | - | rules/cookbook, dev-workflow | Keep |
| c-cpp-best-practices | - | model | 49 | 483 | 458 | 2 | ~160 | - | — | Keep |
| clean-code-dotnet | VND* | model | 39 | 360 | 295 | 0 | ~110 | - | — | Keep |
| code-review | VND* | model | 49 | 736 | 175 | 17 | ~60 | - | CLAUDE.md, dev-workflow | Keep |
| codebase-design | VND | model | 115 | 865 | 265 | 1 | ~100 | - | dev-workflow | Keep |
| containerization | - | model | 53 | 475 | 336 | 0 | ~120 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| context7-mcp | - | model | 63 | 497 | 251 | 0 | ~90 | - | dev-workflow | Keep |
| css-ui-best-practices | - | model | 57 | 439 | 401 | 0 | ~140 | - | agents/ | Keep |
| dapper-best-practices | - | model | 43 | 453 | 370 | 56 | ~130 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| dependency-security-scan | - | model | 63 | 475 | 297 | 36 | ~110 | - | dev-workflow | Keep |
| deps-check | - | model | 34 | 144 | 196 | 13 | ~70 | - | rules/cookbook, dev-workflow | Keep |
| dev-workflow | - | model | 123 | 1018 | 33 | 6 | <20 | - | CLAUDE.md, rules/testing, agents/ | Keep |
| diagnosing-bugs | VND* | model | 135 | 1425 | 240 | 0 | ~90 | - | dev-workflow | Keep |
| diagram-design | - | model | 585 | 5890 | 747 | 0 | ~260 | - | — | **Delete**（untracked、與 plugin 2.6.12 byte-identical、雙重列出；SKILL.md 585 行超官方 500 行） |
| domain-modeling | VND | model | 75 | 515 | 216 | 0 | ~80 | - | dev-workflow | Keep |
| dotnet-core-best-practices | - | model | 50 | 498 | 407 | 26 | ~150 | - | agents/ | Keep |
| dotnet-framework-best-practices | - | model | 47 | 481 | 416 | 4 | ~150 | - | agents/ | Keep |
| dotnet-logging-best-practices | - | model | 52 | 486 | 374 | 7 | ~140 | - | — | Keep |
| dotnet-testing-best-practices | - | model | 38 | 613 | 442 | 7 | ~160 | - | agents/ | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| dotnet-winforms-best-practices | - | model | 40 | 455 | 400 | 0 | ~140 | - | — | Keep |
| ef-core-best-practices | - | model | 43 | 434 | 369 | 1 | ~130 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| ef6-best-practices | - | model | 53 | 474 | 380 | 0 | ~130 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| exec-briefing | - | model | 38 | 59 | 191 | 0 | ~70 | - | profile.md | Keep |
| frontend-release-verification | - | model | 75 | 498 | 237 | 2 | ~90 | - | rules/frontend-spa, dev-workflow | Keep |
| grill-me | VND | user-only | 8 | 20 | 51 | 1 | - | - | — | Keep（user-only，listing 零成本） |
| grill-with-docs | VND | user-only | 8 | 34 | 106 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| grilling | VND* | model | 23 | 460 | 340 | 2 | ~120 | - | dev-workflow | Keep |
| handoff | VND* | user-only | 19 | 203 | 86 | 12 | - | - | CLAUDE.md, dev-workflow | Keep（user-only，listing 零成本） |
| implement | VND | user-only | 16 | 70 | 62 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| improve-codebase-architecture | VND* | user-only | 79 | 815 | 125 | 7 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| init-project-docs | - | model | 46 | 296 | 255 | 12 | ~90 | - | dev-workflow | Keep |
| jest-best-practices | - | model | 61 | 387 | 410 | 0 | ~140 | - | — | Keep |
| microsoft-code-reference | VND | model | 79 | 419 | 349 | 0 | ~130 | - | dev-workflow | Keep |
| microsoft-docs | VND | model | 57 | 288 | 384 | 0 | ~130 | 剝除 | dev-workflow | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| mp-zoom-out | - | model | 15 | 123 | 198 | 4 | ~70 | - | — | Keep |
| mysql-best-practices | - | model | 44 | 410 | 397 | 17 | ~140 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| next-best-practices | - | model | 35 | 353 | 409 | 0 | ~140 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| nodejs-best-practices | - | model | 61 | 395 | 383 | 1 | ~140 | - | — | Keep |
| nuxt | - | model | 62 | 482 | 302 | 0 | ~100 | 剝除 | rules/frontend-spa | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| playwright-best-practices | VND* | model | 45 | 374 | 407 | 1 | ~150 | - | agents/ | Keep |
| postgresql-best-practices | - | model | 45 | 409 | 397 | 1 | ~140 | - | — | Keep |
| postgresql-optimization | - | model | 46 | 495 | 392 | 0 | ~140 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| prototype | VND* | model | 27 | 495 | 179 | 0 | ~60 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| react-best-practices | - | model | 54 | 460 | 420 | 2 | ~150 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| react-router-framework-mode | - | model | 112 | 493 | 433 | 0 | ~160 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| research | VND | model | 13 | 133 | 238 | 0 | ~80 | 剝除 | dev-workflow | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| resolving-merge-conflicts | VND | model | 15 | 134 | 72 | 1 | ~30 | - | dev-workflow | Keep |
| security-audit | VND | model | 102 | 1324 | 310 | 0 | <20 | 剝除 | dev-workflow | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| setup-matt-pocock-skills | VND | user-only | 117 | 1038 | 181 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| shared-security-review | - | model | 62 | 447 | 535 | 0 | <20 | 剝除 | dev-workflow | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| speak-human-tw | VND* | model | 125 | 340 | 418 | 0 | <20 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| tailwind-v4-shadcn | VND* | model | 47 | 326 | 174 | 0 | ~70 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| tdd | VND* | model | 37 | 531 | 149 | 0 | <20 | 剝除 | dev-workflow | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| teach | VND | user-only | 141 | 1490 | 61 | 0 | - | - | — | Keep（user-only，listing 零成本） |
| test-gap-analysis | VND* | model | 61 | 1199 | 1027 | 0 | <20 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| testing-library-react-best-practices | - | model | 52 | 385 | 349 | 0 | <20 | 剝除 | — | Keep → 建議 `name-only`（0 用量、已被剝 description、無任何 route；未來 temp-disable A/B 首選） |
| to-spec | VND | user-only | 76 | 493 | 150 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| to-tickets | VND | user-only | 106 | 909 | 247 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| triage | VND* | user-only | 113 | 998 | 137 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| typescript-best-practices | - | model | 44 | 466 | 420 | 1 | ~150 | - | — | Keep；**Trim description**（Group 2 trigger-case enumeration，見 §4） |
| ui-ux-pro-max | VND* | model | 55 | 387 | 325 | 3 | ~110 | - | dev-workflow | Keep |
| vite | - | model | 70 | 498 | 303 | 0 | <20 | 剝除 | rules/frontend-spa | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| vitest | - | model | 56 | 436 | 417 | 0 | <20 | 剝除 | rules/testing | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| vue-best-practices | - | model | 57 | 497 | 430 | 1 | ~150 | - | — | Keep |
| wayfinder | VND | user-only | 129 | 2019 | 199 | 0 | - | - | dev-workflow | Keep（user-only，listing 零成本） |
| web-design-reviewer | VND* | model | 50 | 345 | 351 | 0 | <20 | 剝除 | rules/frontend-spa | Keep → 建議 `name-only`（0 用量、本 session 已被剝 description；kernel／rules 以名字 route，安全） |
| writing-for-agents | VND* | model | 38 | 466 | 372 | 1 | ~130 | - | dev-workflow | Keep |

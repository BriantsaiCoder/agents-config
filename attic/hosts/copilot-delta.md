<!-- tier: host | consumed-by: copilot | generated-from: hosts/copilot-delta.md | last-verified: 2026-07-13 -->
<!-- FP:COPILOT-DELTA-2026Q3 -->

- Copilot 全域規則由本檔與共用層組裝；勿假設 `~/.claude/CLAUDE.md` 在 context。探針：`copilot -p '複誦 context 內 FP: 開頭 codeword' --available-tools=` 應含 FP:COPILOT-DELTA / FP:AGENTS-T0 / FP:ROUTING。
- Fallback 疑過期：查 .NET=microsoft-learn、Node LTS=官方 release schedule 最新版；提醒更新 `~/.agents/rules/<stack>.md`；MUST NOT 改寫。例外：無。驗證：該路徑無寫入。
- 路由：`available_skills` 缺項 MUST NOT 呼叫，改用內建工具或 `~/.agents/core/routing.md`；勿引用 `dist/skill-index.md`、手寫清單，勿主動呼叫 spark / copilot-sdk / security-guidance。
- Hookify：MUST 只用 CWD `.claude/hookify.*.local.md`；新 repo 提議 `cp ~/.copilot/files/hookify-templates/hookify.*.local.md .claude/`（secret-scan 先 gitleaks、claude-local-gitignore 提醒）。
- MCP：Microsoft/Azure/.NET/EF Core=microsoft-learn>Context7>web search；其他 library=Context7>web search；browser=chrome-devtools/playwright。

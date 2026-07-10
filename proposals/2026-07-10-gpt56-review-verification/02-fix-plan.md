<!-- status: PLAN（待用戶批准；批准原句須引用於執行紀錄，[T0-8]）| created: 2026-07-10 | author-model: claude-fable-5 | basis: 01-verdicts.md §D | readers: AI models（Opus / Sonnet / Codex GPT 5.5+）-->
# 02 修復執行計畫（GPT 5.6 review 驗證後）

> 適用：`~/.claude`、`~/.codex`、`~/.copilot`、`~/.agents`（四者皆已 git 化）｜整體風險：**中**
> Rollback 總策略：每批次 = 各自 repo 一個獨立 commit（[T1-3] reproducible）；任一批次出問題 `git revert <sha>` 單獨回退，批次間無交叉依賴（Batch 9 除外，只讀）。
> 驗證紀律：每批次先寫紅探針（修復前預期 FAIL 的指令）再改（R-2 語意）；全部完成後跑 Batch 9 conformance 收尾。

## 執行順序與批次

### Batch 1｜P0-F1：autoMode 恢復內建防線 —— 風險：低

- 檔：`~/.claude/settings.json:293` autoMode 的 `allow` / `soft_deny` / `environment` 三陣列，各在**首位**插入字面字串 `"$defaults"`（官方語意：defaults 拼接於該位置，自訂規則保留）。`hard_deny` 未設，不動（空缺即繼承內建）。
- 紅探針：`grep -c '"\$defaults"' ~/.claude/settings.json` → 修前 0，修後 3。
- 注意：settings.json 在沙箱 Bash 寫入 deny 清單；用 Edit 工具改。若 Edit 被權限層擋，改為輸出精確 JSON diff 供用戶手動套用。
- 副作用檢查：JSON 有效性（`jq . ~/.claude/settings.json >/dev/null`）；改後開新 session 確認 autoMode 分類器無異常訊息。
- Rollback：`git -C ~/.claude revert <sha>`。

### Batch 2｜P0-F3：audit log 衛生 —— 風險：中（遮罩 regex 誤傷會降低 audit 價值）

- 檔 1：`~/.claude/hooks/audit-bash.sh` —— 寫入前對 CMD 套遮罩（`password=`、`token=`、`api[_-]key=`、`Authorization:`、`AKIA[0-9A-Z]{16}`、PEM header 等樣式 → 值改 `***`）；log 建檔後 `chmod 600`；既存 `~/.claude/audit-bash.log` 與 `.log.1` 一併 `chmod 600`（歷史內容不回溯清洗——rotation 會自然汰換，避免改寫稽核紀錄）。
- 檔 2：`~/.claude/hooks/pre-commit-claude.sh:72,:77` —— stderr 只印「檔名:行號 + 命中 pattern 名」，不印命中行內容。
- 紅探針：`printf '{"tool_input":{"command":"echo password=hunter2"}}' | bash ~/.claude/hooks/audit-bash.sh; tail -1 ~/.claude/audit-bash.log` → 修前含 `hunter2`，修後為 `password=***`；`stat -f%Lp ~/.claude/audit-bash.log` → 600。
- Rollback：`git -C ~/.claude revert <sha>`（log 檔本身不在版控，權限改動無需回退）。

### Batch 3｜P0-F4：Codex fail-open + key externalize —— 風險：中（fail-closed 誤擋合法 apply_patch；env var 未設會讓 stitch MCP 掛掉）

前置（[T1-1] 高扇入模板列依賴方）：`grep -rl 'protect-files.sh' ~/.agents ~/.codex ~/.copilot ~/Downloads/coding_agent_project/*/.codex 2>/dev/null` 列出全部消費 repo，逐一同步。

- 3a 檔：`~/.agents/skills/init-project-docs/references/hooks/protect-files.sh`（正本）+ 各 repo 已部署副本 —— apply_patch 改 fail-closed：解析 patch body 的 `*** Update/Add/Delete File:` 目標路徑；解析不到目標即 deny（exit 2 / decision:block），不再空值放行。
  - 紅探針：synthetic apply_patch(.env) payload 進腳本 → 修前 exit 0，修後 exit≠0；對照合法路徑 payload 修後仍放行（防誤擋）。
- 3b 檔：`~/.codex/rules/default.rules` —— 兩條 `rm -rf` prefix_rule 刪除或改精確 argv 全匹配（歷史一次性放行，已無現役用途，優先刪）。
  - 紅探針：`grep -c 'rm.*-rf' ~/.codex/rules/default.rules` → 修後 0。
- 3c 檔：`~/.codex/config.toml:72` —— stitch `X-Goog-Api-Key` 改 env var 引用。前置驗證：確認本機 Codex 版本支援 `env_http_headers`（探針：`codex --version` + 官方 config 文件查 `env_http_headers`；github MCP 的 `bearer_token_env_var` 已證明同類機制可用）。步驟：用戶把 key 值放入 shell profile 的 `STITCH_API_KEY`（**值不經過 AI，用戶帶外操作**）→ 我改 config.toml 為 env 引用 → 驗證 stitch MCP 可連 → 用戶後台撤舊 inline 值。若版本不支援 env 引用：本項降級為「保持 inline + 已 rotate + .gitignore 防入版控」，記錄於執行紀錄。
- Rollback：`git -C ~/.codex revert <sha>`；3c 失敗時 config.toml 回退即恢復連線。

### Batch 4｜P1-F2/C2：T0-3 防線幻覺消除（+ 可選 git guard hook）—— 風險：中（hook 誤擋合法 push）

- 4a 檔：`~/.agents/core/tier0-safety.md:18`（正本；`~/.claude/core` 為 symlink 單點生效）—— [T0-3] 驗證句 Claude 半句改「Claude=audit-bash 事後稽核 log（async 註冊，無前置攔截）」；Codex/Copilot 半句補「hooks 能力已有（PreToolUse 可 deny），現況未配置」。同步跑 `agents-sync --check` + deploy 讓 Codex/Copilot 注入層同步。
- 4b（可選，建議做）新檔：`~/.claude/hooks/guard-git-push.sh` —— PreToolUse Bash hook（`async:false`、timeout 3）：偵測 `git push` 且（`--force` 非 lease，或任何 force 變體目標 main|master）→ exit 2 + stderr 說明。settings.json 註冊於 audit-bash 之前。保留 permissions.allow 的 `--force-with-lease *`（feature branch 日常需要），由 hook 補 main/master 這一刀。
  - 紅探針：synthetic `{"tool_input":{"command":"git push --force-with-lease origin master"}}` → 修前無攔截，修後 exit 2；`git push --force-with-lease origin feat/x` → 修後仍 exit 0。
- Rollback：revert + 移除 hook 註冊即恢復。

### Batch 5｜P1-F6：agents-sync doctor 補 rc —— 風險：低

- 檔：`~/.agents/bin/agents-sync:330,:335` —— 「manifest 有列但部署檔缺失」與「manifest.tsv 缺失但 dist/ 有產物」改設 `rc=1`（維持 UNAVAILABLE 字樣，語意=四態中的 FAIL 化）；usage line 8 刪「/ diff」字樣（或補 diff 實作，擇一，預設刪字）。
- 紅探針：`mv ~/.codex/AGENTS.md /tmp/ && ~/.agents/bin/agents-sync --doctor; echo $?; mv /tmp/AGENTS.md ~/.codex/` → 修前 0，修後 1（drift-check 隨之會在 SessionStart 印告警，行為鏈修復）。
- Rollback：`git -C ~/.agents revert <sha>`。

### Batch 6｜P1-F9：Copilot hook adapter 對齊官方 schema —— 風險：低中

- 檔：protect-files.sh copilot 分支（隨 Batch 3a 同檔）—— deny 輸出改 `{"permissionDecision":"deny","permissionDecisionReason":...}` 並改 exit 2（fail-closed 雙保險）；jq 擷取路徑補 `.toolArgs.path // .toolArgs.file_path`；`references/hooks/copilot/README.md:35` 同步。
- 檔：`~/.agents/skills/dev-workflow/SKILL.md:135` —— 改「Copilot 已支援 user-level hooks（~/.copilot/hooks/ + config.json inline），現況未配置；機械守護目前依賴 repo 層」。
- 驗證：camelCase `preToolUse` synthetic payload（`toolArgs.path=.env`）→ 修後 deny；落地後以最小 hook 實測一次 runtime（01-verdicts F9 註明靜態比對須實測補證）。
- Rollback：git revert。

### Batch 7｜P1-F11+F12：dangling reference 與計數修正 —— 風險：低

- `~/.codex/agents/tdd.toml:24` 與 `~/.claude/agents/tdd.md:29,58,80` —— 刪/改 `Rails Testing Expert` 引用（改指實際存在的 testing agent 或刪句）。
- `~/.agents/CONVENTIONS.md:1,:68` 與 `~/.agents/README.md:17` —— 「11 條」→「13 條」；`CONVENTIONS.md:3` 「違反 = build fail」改「lint 現覆蓋第 2（部分）/7/8 條，其餘為書寫規範待下沉」；`README.md:23` 「SessionStart 自動再生」改「SessionStart drift 巡檢告警（再生須手動 agents-sync）」。
- 驗證：`grep -rn '11 條' ~/.agents/CONVENTIONS.md ~/.agents/README.md` → 0；`grep -rn 'Rails Testing Expert' ~/.claude/agents ~/.codex/agents` → 0。
- Rollback：各 repo git revert。

### Batch 8｜P2-F5/F10/F7：workflow 文件清晰度 —— 風險：低

- `~/.agents/skills/dev-workflow/SKILL.md` S6 ACTION —— 第 2/3 步對調（triage 先於 merge），第 2 步（原 merge 步）補「（[T0-9]；四態 PASS 前不得 merge，正本 references/review-triage.md）」。
- 同檔 S0 —— row 6 移到 row 5 之前（表格語意自足，不再依賴周邊 prose 補救）。
- `~/.agents/skills/sdd/SKILL.md` 終態前加一句：「宣稱完成前 MUST 通過 dev-workflow S4–S6 對應 gate，或逐項標 SKIPPED 附理由。」
- `~/.agents/bin/agents-sync` lint 增列 CONVENTIONS 12 量測（CLAUDE.md+core ≤20480B，超標 fail）。
- 驗證：改後重讀 S0 表逐列走一次 first-hit 模擬；`agents-sync --check` 綠。
- Rollback：git revert。

### Batch 9｜conformance test 收尾 —— 風險：低（唯讀探針 + 新檔）

- 新檔：`~/.agents/tests/conformance.sh` —— 探針集（每項對應上方批次的綠態）：
  1. `grep -c '"\$defaults"' ~/.claude/settings.json` ≥ 3
  2. `stat -f%Lp ~/.claude/audit-bash.log` = 600；synthetic secret → log 含 `***` 不含原值
  3. apply_patch(.env) synthetic → protect-files.sh exit≠0
  4. 暫移部署檔 → `agents-sync --doctor` rc=1（測畢還原）
  5. `grep -c '^## [0-9]' ~/.agents/CONVENTIONS.md` = 標題宣稱數
  6. `grep -c 'Rails Testing Expert' ~/.claude/agents ~/.codex/agents -r` = 0
  7. （若 Batch 4b 執行）force-push master synthetic → guard hook exit 2
- 掛載：不進 SessionStart（避免每 session 開銷）；README 記「手動跑 + 改 guard/config 後必跑」。
- 全綠 = 本計畫 S4 gate PASS；任一 FAIL → 該批次視為未完成，不得宣稱 done（[T0-2]）。

## 不做（明確出界，理由見 01-verdicts §C）

- YAML policy engine / roles manifest / dist 全家桶改組（over-engineering，駁回）
- Workflow v2 全重寫（局部修補已覆蓋）
- 三主機 agents/ 治理面收斂（規模大，另立提案）
- audit-bash.log 歷史內容回溯清洗（rotation 自然汰換；改寫稽核紀錄有反效果）
- stitch key 後台撤舊值（用戶帶外操作，AI 不經手 key 值）

## Commit 對照（各 repo 內 Conventional Commits zh-TW）

| 批次 | repo | message 前綴 |
|------|------|-------------|
| 1 | ~/.claude | `fix(automode): 三陣列補 $defaults 恢復內建防線` |
| 2 | ~/.claude | `fix(hooks): audit log 遮罩 secret + 0600；pre-commit 不印命中行` |
| 3 | ~/.agents + ~/.codex | `fix(hooks): protect-files apply_patch fail-closed` / `chore(codex): default.rules 收斂 + stitch key 外部化` |
| 4 | ~/.agents (+~/.claude) | `docs(tier0): T0-3 驗證句消除防線幻覺` / `feat(hooks): PreToolUse git force-push guard` |
| 5 | ~/.agents | `fix(agents-sync): doctor 缺檔設 rc=1` |
| 6 | ~/.agents | `fix(hooks): copilot adapter 對齊 permissionDecision schema` |
| 7 | ~/.agents + ~/.claude + ~/.codex | `docs: 修 dangling reference 與 stale 計數` |
| 8 | ~/.agents | `docs(dev-workflow): S6 步序 / S0 row 順序 / sdd gate 句` |
| 9 | ~/.agents | `test: 新增 conformance.sh 探針集` |

Push 統一在全批次綠後進行（累積 commit 屬同一邏輯工程，逐批 push 無額外價值；push 前跑 gitleaks）。

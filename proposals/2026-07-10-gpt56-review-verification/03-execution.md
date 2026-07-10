# 03 — 執行紀錄（2026-07-10）

> 讀者是 AI 模型。本檔是 `02-fix-plan.md` Batch 1–9 的執行帳本：每批 commit 座標、綠態證據形態、以及 **git 管不到的 rollback 配方**（未追蹤檔 / 無 git 目錄）。回滾 git 內變更一律 `git revert <sha>`，不在此重複。

## 授權

[T0-8] 確認原句：用戶於 AskUserQuestion「批准執行 02-fix-plan.md 的哪個範圍？」選擇 **「全部 Batch 1–9（建議）」**。

## Commit 帳本（依 repo）

| repo | sha | 批次 | 內容 |
|------|-----|------|------|
| ~/.claude | `67fc667` | B1 | autoMode 三陣列補 `"$defaults"` |
| ~/.claude | `4d08982` | B2 | audit-bash 遮罩 + log 600；pre-commit 不印命中行 |
| ~/.claude | `711a2a9` | B4b | guard-git-push.sh PreToolUse 前置攔截 + settings 掛載（guard 先、audit 後）+ CLAUDE.md routing stamp |
| ~/.claude | `f9dae34` | B7 | agents/tdd.md 移除 Rails dangling refs |
| ~/.agents | `a926319` | B3a | protect-files apply_patch fail-closed（canonical） |
| ~/.agents | `3035553` | B6 | copilot 分支對齊官方 permissionDecision schema + exit 2 雙保險；toolArgs 路徑鍵；README/SKILL.md 對齊 |
| ~/.agents | `cd13abe` | B4a | [T0-3] 驗證句消除防線幻覺（+dist 再生） |
| ~/.agents | `0cb9bd7` | B5 | agents-sync doctor 缺檔 rc=1；usage 移除 diff 宣稱 |
| ~/.agents | `84424e1` | B7 | CONVENTIONS 11→13 條、lint 覆蓋宣稱、README tier0 守護描述對齊實況 |
| ~/.agents | `c4b1dd8` | B8 | S0 表序自足、S6 triage 先於 merge（[T0-9] 句）、sdd 終態 gate 句、lint7 常駐面預算 |
| ~/.agents | `b4b376e` | B9 | tests/conformance.sh（10 探針）+ README 掛載說明 |
| ~/.codex | `26de319` | B3b/3c | default.rules 收斂（刪 3 條 rm -rf 放行）；config.toml stitch key 外部化 → stitch.env |
| ~/.codex | `8e53afe` | B4 | AGENTS.md 部署再生（T0-3 驗證句） |
| ~/.codex | `7d76d22` | B7 | agents/tdd.toml 移除 Rails dangling refs（泛稱角色） |
| ~/.copilot | `f739dff` | B4 | copilot-instructions.md 部署再生（T0-3 驗證句） |
| Stacking_Map | `fe106e2` | B6 | 3 份部署變體 port（twins fail-closed；copilot 變體 schema+toolArgs+fail-closed） |

## 綠態證據形態（[T0-2]）

- 各批紅→綠探針輸出見執行 session（fc19450e）；持久化守護 = `~/.agents/tests/conformance.sh`，收尾時 **10 PASS / 0 FAIL**。
- `agents-sync --check` 收尾綠：lint 7 條 PASS；codex 9351B / copilot 10099B（≤10240B）；lint7 常駐面 16403B（≤20480B）。
- guard-git-push 探針 11/11（force/-f/+refspec 攔、lease-master 攔、lease-feat 放、no-refspec 依 cwd 分支判定、解析失敗 fail-closed）。

## Git 管不到的 rollback 配方

以下標的不在任何 git 追蹤面（~/.codex 為 allowlist gitignore；homework 目錄無 git），回滾靠本節配方：

1. **`~/.codex/rules/default.rules`（B3b 刪 3 條 rm -rf 放行）**：回滾 = 依檔內既有語法補回 `prefix_rule(pattern=["rm", "-rf", …], decision="allow")` 形態的放行行（原值可自 session transcript `fc19450e-c0c1-456a-8063-f604b67a1072.jsonl` 考古）。刻意不在本檔複寫原行——它們是被判定過寬而移除的，補回前先重讀 01-verdicts 對應條目。
2. **`~/.codex/config.toml`（B3c stitch key 外部化）**：現狀 `[mcp_servers.stitch.env_http_headers]` 引用 env var `STITCH_API_KEY`（值在 `~/.codex/stitch.env`，0600）。回滾 = 段名改回 `http_headers` 並將值自 stitch.env 移回 —— **值的搬運一律 Bash pipeline 帶外操作，MUST NOT 經 AI 工具參數或印出（[T0-4]）**。
3. **`2026-ai-adv-homework-course02/.claude/hooks/protect-files.sh`（B6 整檔換新，無 git）**：回滾 = `git -C ~/.agents show a926319^:skills/init-project-docs/references/hooks/protect-files.sh > <該路徑>`（舊 canonical 與其位元組相同）。

## 用戶帶外事項（AI 不經手）

- shell profile 加 `source ~/.codex/stitch.env`，讓 codex CLI 與 codex plugin 取得 `STITCH_API_KEY`（未加前 stitch MCP 會缺 header）。
- （建議）擇期至 Google 後台 rotate stitch key；rotate 後只改 stitch.env 檔內值。

## 出界未做（正本 02 §不做）

YAML policy engine、workflow v2 重寫、三主機 agents/ 治理收斂（另立提案）、audit log 歷史回溯清洗、stitch 舊 key 撤銷（帶外）。

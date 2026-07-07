<!-- status: PROPOSAL 附件 | 執行前提: 用戶明確批准 | 每步含機械驗證 + 獨立回滾 | readers: AI models -->
# 04 合併遷移序（設定層 + workflow 層合流）

> 適用：全 host｜載入：無（PROPOSAL，未生效）
>
> 風險等級：**中高**（動三家全域設定）。總回滾點 = Step 0 快照；每步另有獨立回滾。
> 執行紀律：**依序執行、每步驗證通過才進下一步**；任何探針失敗 → 停在該步回滾並回報，不硬推。

## 分段選項（先裁決再動手）

- **B0（止血批）**：不屬於 A/B 的前置批——修「正在發生的失守」（Codex 防線休眠、明文 key、autopilot 繞 gate），30 分鐘、與遷移完全獨立、每項可回滾。**無論之後選 A 或 B，B0 都先做**（裁決依據見 [06-final-review.md](06-final-review.md) C-R1）。
- **方案 A（完整遷移）**：Step 0–13 一次走完。一週內三家收斂，但單批變更面大。
- **方案 B（過渡先行）**：先只做 Step 0–2 + Step 4W/6 的 workflow 部分（dev-workflow + sdd skills + routing stamp 進**現行 live 檔**，含 `AGENTS.override.md`）——三家立即跑同一條 workflow；設定層（tier 蒸餾、override 刪除、rules 遷移）之後另批。**推薦 B**：workflow 統一是用戶的最終目標，先拿到最大收益、變更面最小；設定層遷移風險獨立分批。

## B0 止血批（前置於方案 A/B；需用戶批准後執行）

> 設計約束：B0 只用「終局遷移本來就要退役的載體」（fenced markers stamp、既有檔補行），不新增任何會活過遷移的機制——止血不留疤。B0.1 的 stamp 於 Step 8 隨 override 退役；B0.2 的增量於 Step 9 隨 global-core 歸檔。

| # | 動作 | 驗證（機械） | 回滾 |
|---|------|--------------|------|
| B0.0 | tar 快照 B0 觸及檔：`~/.codex/AGENTS.override.md`、`~/.codex/config.toml`、`~/.copilot/{copilot-instructions.md,instructions/global-core.instructions.md,mcp-config.json}`、`~/.zshrc`、`~/.claude.json` | `tar -tzf` 條目 = 7 | ——（本步即回滾點） |
| B0.1 | tier0 摘要以 fenced markers stamp 進 `~/.codex/AGENTS.override.md` 尾端（區塊全文見下，照貼勿改寫） | `codex debug prompt-input 'x' \| grep -c 'FP:OVERRIDE-T0'` = 1 | 刪 markers 區塊（含 begin/end 行） |
| B0.2 | Copilot 兩檔修補：(a) `instructions/global-core.instructions.md` 補 3 條缺口（rollback 義務、DB migration 分段、merge-gate bot review）+ FP 句 `FP:COPILOT-CORE-2026Q3`；(b) `copilot-instructions.md` 刪第 4 行假繼承宣稱（改為「核心規則由 instructions/global-core.instructions.md 常駐提供；CLAUDE.md **不會**被載入」+ 附探針）、刪 9 死名（名單見 06 B-6） | `copilot -p '複誦 FP: 開頭句' --available-tools=` 命中；對 9 死名逐一 `grep -c` = 0 | B0.0 快照還原兩檔 |
| B0.3 | rotate stitch `X-Goog-Api-Key`：發新 key → 更新 `~/.codex/config.toml` 與 `~/.claude.json` → 撤舊 key → **刪 3 份 `config.toml.bak*`**（全程只認 key 名，勿印值） | 全 home `grep -rc 'X-Goog-Api-Key'` 命中數 = 2（僅兩份正本）；舊 key 已撤（呼叫 stitch 一次確認新 key 可用） | 新 key 失效 → 暫回舊 key（撤舊前勿刪） |
| B0.4 | 刪 `~/.zshrc:183-184` 的 `copilot()` function（**是 function 非 alias**）；要 autopilot 另立顯式 `copilot-auto()` | `zsh -ic 'type copilot'` 輸出不含 function（指向實體執行檔） | B0.0 快照還原 .zshrc |
| B0.5 | `~/.copilot/mcp-config.json`：`chrome-devtoolss` → `chrome-devtools` | `grep -c 'chrome-devtoolss'` = 0 | 還原一字 |

### B0.1 stamp 區塊全文（照貼進 AGENTS.override.md 尾端）

```markdown
<!-- agents-tier0:begin FP:OVERRIDE-T0-2026Q3（止血 stamp；終局遷移 Step 8 隨本檔退役）-->
## Hard Rules（tier0 安全底線）
- [T0-1] MUST NOT 假設未驗證的 file path / API / config key。
- [T0-2] MUST NOT 無 evidence 宣稱 task done（evidence = test/build/lint 輸出或探針結果）。
- [T0-3] MUST NOT force-push main/master；force push 只用 --force-with-lease 於非保護分支。
- [T0-4] MUST NOT 把 token/secret 寫入 frontend localStorage/sessionStorage；log/console 不印憑證，設定輸出遮罩。
- [T0-5] 模糊時 MUST 停下發問（攤開假設 X、影響範圍 Y），不靜默推進。
- [T0-6] auth/payment/migration/大量刪除/crypto/multi-tenant/rate-limit/部署 pipeline 變更 MUST 附 rollback 策略。
- [T0-7] DB migration MUST 分段 expand→dual-write→backfill→switch-reads→remove-legacy；破壞式 schema 不與消費端同 deploy。
- [T0-8] 非 trivial（3+ 步/多檔/架構性）MUST 先出計畫並取得用戶確認才改檔（任何 auto 模式不豁免）。
- [T0-9] merge 前 MUST 綠 CI + 處理 bot review（bot review 異步 2–3 分鐘產出，開 PR 當下為空是延遲不是無）。
<!-- agents-tier0:end -->
```

## 遷移步驟

| Step | 動作 | 驗證（機械） | 回滾 |
|------|------|--------------|------|
| 0 | tar 快照 `~/.agents`、`~/.codex/{AGENTS.md,AGENTS.override.md,hooks.json,rules}`、`~/.copilot/{copilot-instructions.md,instructions}`、`~/.claude/rules` | `tar -tzf` 條目數 > 0 | ——（本步即回滾點） |
| 1 | `~/.agents` git 化：先拆 `skills/ecpay/.git`（記 UPSTREAM.txt：URL + SHA）→ `git init` + baseline commit | `git status --porcelain` 空；`find ~/.agents -mindepth 2 -name .git` 空 | 刪 `.git/`（不影響內容） |
| 2 | 殭屍 lock 隔離：`.skill-lock.json` → `attic/` | **隔離探針**：新 Codex/Copilot session 各列 skills，數量仍 50 | `git mv` 回原位並記錄為 live 依賴 |
| 3 | Claude skills symlink 相對化（修換機斷鏈） | 斷鏈掃描輸出空；新 session skill 數不變 | git restore（dotclaude repo） |
| 4 | 蒸餾 `core/`（tier0/1/2 + routing.md）與 `hosts/`（codex-delta / copilot-delta）；每檔 metadata 檔頭 + 唯一 FP 句；CONVENTIONS.md 落地根目錄 | `grep -rc 'FP:'` 每檔恰 1；`wc -l tier0` ≤30、routing ≤30 | git revert（尚未部署，零影響） |
| **4W** | 撰寫 `skills/dev-workflow/`（SKILL.md ≤400 行 + references 三檔，收割 override 的 Closeout Ledger 原文進 ledgers.md）+ `skills/sdd/`（自 commands/sdd.md 改寫）；`~/.claude/skills/` 補掛兩條相對 symlink；`~/.claude/commands/sdd.md` 改一行薄殼 invoke skill | 三家各自 list skills 含 dev-workflow、sdd（52）；X0 契約抽查：SKILL.md 內 grep 不到無檔案/關鍵字/exit-code 依據的 EXIT 條件 | git revert + 刪 symlink |
| 5 | rules 正本遷移（cp 8 檔 → 編輯 PIN 標記 / paths frontmatter → `~/.claude/rules/` 改相對 symlink） | **探針**：含 .cs 檔專案 `claude -p '複誦 dotnet 規則檔 FP 句'` 命中；未命中 → fallback：還原實體檔、rules 改列生成目標 | 還原實體檔（快照有） |
| 6 | 寫 `bin/agents-sync`（含 targets 資料表、lint 六條、no-clobber、--check、--bootstrap；**routing 區塊為組裝段之一**）並首跑 | 連跑兩次第二次零寫入；塞死名 `fake-skill` 確認 exit 1；manifest 與三目標 hash 一致 | dist/ 未部署前 git revert 即可 |
| 7 | Claude 接線：CLAUDE.md 頂部 4 行 @import；刪與 tier 檔重複段；**Workflow Playbooks 章遷入 dev-workflow，原地只留 routing 區塊 + Claude adapter 段** | `claude -p '輸出全部 FP: codeword'` 含 T0/T1/T2 + routing 枚 | dotclaude git restore |
| 8 | Codex 切換：agents-sync 部署 `~/.codex/AGENTS.md`；舊 32KB 檔加退役警語檔頭後歸檔 attic；`AGENTS.override.md` → attic；修剪 default.rules 兩條放行 | `codex debug prompt-input 'x'` grep：`FP:AGENTS-T0`=1、Closeout Ledger 存活=1、舊 B 殘留=0 | attic 內兩檔 mv 回原位（快照亦有） |
| 9 | Copilot 切換：部署 instructions/00-agents-shared + 新 copilot-instructions.md（刪假宣稱、9 死名、幽靈段；含 S2 強制令）；global-core.instructions.md → attic | `copilot -p '列 instruction 檔路徑並複誦 FP codeword' --available-tools=`：新兩檔在列、codeword 命中、無 global-core、無死名 | 快照還原 |
| 10 | hooks 合併：patch-*-mcp.sh 兩支遷 `~/.agents/hooks/`，兩家掛載點改指；刪 Codex 端死副本。阻擋型三支**暫不遷**——先 Codex PreToolUse 最小實測（echo hook + hooks.state 觀察），有觸發證據才遷 | 新 session 後 patch 目標 mtime 更新；`md5` 與備份一致 | 快照還原 hooks.json/settings.json |
| 11 | drift 守護掛載 + 演練：兩家 SessionStart 加 `agents-sync --check`；改 core 檔一字 → 新 session → 確認自動再生 → git checkout 還原 | 演練通過（FP 探針 + manifest mtime） | 移除 SessionStart 條目 |
| 12 | 收尾 buyoff：`agents-sync --doctor` 全綠（斷鏈 0、manifest 相符、**override 不存在**、三探針全過）；`gitleaks detect --source ~/.agents`；commit + `gh repo create agents-config --private --push` | doctor 輸出全綠；gitleaks 0 findings | ——（驗收步） |
| 13 | workflow 挂載驗證（新增）：三家各開一個真 session 丟同一個小任務，確認 (a) S0 決策表被引用 (b) S2 ⏸ 有停 (c) 三欄回報出現 | 三家 session transcript 各命中三項 | 若某家未跑：檢查該家 routing 區塊 FP → 修 stamp |

## 帶外並行待辦（與遷移不混批，同一 milestone 追蹤）

> 原列於此的三項安全項（rotate key、autopilot alias、chrome-devtoolss）已升入 B0 止血批（B0.3–B0.5），不再重列。

1. Codex PreToolUse 實測 → 通過則補註冊 audit-bash / guard-cookbook-orphan / watch-ci-after-push。
2. `init-project-docs` 模板擴充（repo 層路由行 + 產物路徑表 + `.github/hooks/` 守護骨架）；本 repo（DCT）下次動協作檔時補同段。

## 全域回滾策略

任一步失敗且獨立回滾不乾淨 → `tar -xzf` Step 0 快照整批還原三家設定 + `rm -rf ~/.agents/.git`（內容檔案不動）。快照保留至 Step 13 驗收後 30 天。

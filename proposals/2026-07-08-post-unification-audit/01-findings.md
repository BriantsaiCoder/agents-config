<!-- status: EXECUTED（findings 已修正落地，見 §E）| created: 2026-07-08 | author-model: claude-fable-5 | method: 三家注入層+workflow 全量審計 vs live 探針 | readers: AI models（Opus / Sonnet / Codex GPT 5.5+）-->
# 01 Post-unification 審計：F1–F11 findings 與修正

> 適用：全 host｜載入：無（proposals 不注入；接手時按需讀）
>
> 結論先行：**2026-07-07 統一遷移（proposals 01–06）架構成立、運轉正常；但注入層有 3 處「與事實不符的宣稱」、新機重建有 1 條靜默斷鏈路徑、CLAUDE.md 與 core 有大面積雙正本。**
> 本檔記錄 F1–F11 findings（探針可重跑）與修正。讀者注意：快照距今 >7 天先重跑 §B 探針再引用結論。

## A. 審計方法

對象：`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.copilot/copilot-instructions.md`、`~/.agents/{core,hosts,rules,bin,skills/dev-workflow}`。
方法：每一句「載入宣稱 / 部署宣稱 / 守護宣稱」都跑探針對 live 狀態核對（CONVENTIONS 5 精神）；重複條文逐行對照 tier0-2 / routing / ledgers.md 正本。

## B. Live 快照（2026-07-08 21:2x；探針可重跑）

| # | 事實 | 探針 | 本次結果 |
|---|------|------|----------|
| B-1 | `~/.copilot/instructions/` 為空目錄 | `ls -la ~/.copilot/instructions/` | 0 檔（舊 00-agents-shared 已歸 attic） |
| B-2 | agents-sync 部署目標僅 2 個 | `grep -A3 '^TARGETS' ~/.agents/bin/agents-sync` | codex→AGENTS.md、copilot→copilot-instructions.md |
| B-3 | .bak 違規（CONVENTIONS 11 應為 0） | `ls ~/.claude/*.bak* ~/.codex/*.bak* 2>/dev/null \| wc -l` | claude 8 + codex 3 = 11 |
| B-4 | key 明文面（**勿印值**） | `grep -c 'X-Goog-Api-Key' ~/.codex/config.toml ~/.claude.json`；`grep -l ... ~/.codex/*.bak* \| wc -l` | 1 + 1 + bak×2 |
| B-5 | `~/.agents/.git/hooks/` 不存在 | `ls ~/.agents/.git/hooks/` | No such file（無 pre-commit） |
| B-6 | `rules/*.md` 無 PIN 區塊 | `grep -rc 'PIN' ~/.agents/rules/*.md \| grep -v ':0' \| wc -l` | 0 |
| B-7 | 注入預算 | `agents-sync --check` | codex 9037B（88%）、copilot 9429B（92%）/ 10240B |
| B-8 | CLAUDE.md 體積 | `wc -c ~/.claude/CLAUDE.md` | 15612B / 120 行 |
| B-9 | Codex hooks 全為 SessionStart | `grep -o '"[A-Za-z]*":' ~/.codex/hooks.json \| sort -u` | 僅 SessionStart（無 PreToolUse） |
| B-10 | Copilot 無全域 hooks；Claude 有 audit-bash | `grep -c 'audit-bash' ~/.claude/settings.json` | 1（僅 Claude） |
| B-11 | `~/.codex/skills/` 8 個實體目錄、0 symlink 到 ~/.agents | `ls -la ~/.codex/skills/` | 全實體；config.toml 無 skill path 設定 |
| B-12 | codex / copilot 目錄未 git 化 | `ls -d ~/.codex/.git ~/.copilot/.git` | 皆不存在 |
| B-13 | `~/.claude/core/` 3 條相對 symlink 健康 | `ls -la ~/.claude/core/` | tier0/1/2 → ../../.agents/core/ ✅ |

## C. Findings（F 編號永不重編；每條：現象→探針→為何是問題→修法）

### F1（P0）copilot-delta 假部署宣稱
- 現象：`hosts/copilot-delta.md` L8 宣稱部署至「`~/.copilot/instructions/00-agents-shared.instructions.md` 與 copilot-instructions.md」；`README.md` L31 同句。
- 探針：B-1 + B-2 → instructions/ 為空、TARGETS 僅 copilot-instructions.md。
- 為何是問題：這句話**每個 Copilot session 都注入**。未來 AI 讀到會推導出「有第二部署副本」，在除錯載入問題時走錯路（正是 06 審查記錄的「假繼承宣稱」同型錯誤，統一後又長回來）。違反 CONVENTIONS 5。
- 修法：改為單一目標事實；README 同步。**教訓（制度化）：部署宣稱唯一權威是 `agents-sync` 的 TARGETS 表，散文只准轉述它、且須附探針。**

### F2（P0）copilot-delta fallback 提醒指錯目標
- 現象：copilot-delta L13 要求偵測 fallback 版本過期時「提醒 user 自行更新 `~/.claude/CLAUDE.md`」。
- 探針：`grep -n 'rules' ~/.claude/CLAUDE.md` L12 → 版本 pin 正本已在 `~/.agents/rules/*.md`（經 ~/.claude/rules symlink）。
- 為何是問題：照做會提醒用戶去改「不含版本 pin 的檔」，指令失效。
- 修法：目標改 `~/.agents/rules/<stack>.md`。

### F3（P0）[T0-3] 驗證句對 2/3 host 不成立
- 現象：tier0 [T0-3] 驗證欄寫「hook audit-bash + default.rules 無全域 git 放行」。
- 探針：B-9 + B-10 → audit-bash 僅 Claude 有；Codex hooks 全 SessionStart；Copilot 無全域 hooks。另 dev-workflow SKILL.md L129 寫 Codex「三支 guard（前置 PreToolUse 實測）」與 live 不符。
- 為何是問題：tier0 是三家共用正本，驗證句只對 Claude 成立 → Codex/Copilot 上的 AI 會去找不存在的 hook，或誤信有機械防線而放鬆警惕（防線幻覺比無防線更危險）。
- 修法：驗證句改 host 分列（Claude=hook；Codex/Copilot=無全域機械防線，靠 repo 層 CI/pre-commit + 本條 prose）；SKILL.md L129 改「SessionStart 三支（提示性，非攔截）」。

### F4（P1）新機重建靜默斷鏈：bootstrap/doctor/gitignore 三缺口
- 現象：`agents-sync --bootstrap` 重建 skills+rules symlink 但不建 `~/.claude/core/`；`--doctor` 斷鏈掃描僅 `~/.claude/skills`；dotclaude `.gitignore` allowlist 無 `!core/`。
- 探針：讀 `bin/agents-sync` bootstrap()/doctor()；`grep 'core' ~/.claude/.gitignore` = 0。
- 為何是問題：新機 clone dotclaude + agents 後跑 bootstrap，`~/.claude/core/` 不存在 → CLAUDE.md 的 3 個 @import 靜默失敗 → **tier0 安全紅線整層消失且無告警**。三個缺口互為 backup 卻同時缺席。
- 修法：bootstrap 補 core symlink；doctor 掃 core+rules；.gitignore 補 `!core/ !core/**`（symlink 本身可 commit）。

### F5（P1）stack pins 對 Codex/Copilot 不可見
- 現象：`~/.agents/rules/*.md`（8 檔，含 .NET/Node 版本 pin）只有 Claude 經 @import 附錄載入；routing/deltas 無任何指引。
- 探針：B-6 + `grep -rn 'agents/rules' ~/.agents/core/ ~/.agents/hosts/` = 0 hit。
- 為何是問題：Codex/Copilot 上的 AI 遇 .NET 專案時不知道 pin 存在 → 用過期 fallback 或自行查網，三家行為分歧。
- 修法：routing.md 加一行 on-demand pointer（預算內）。

### F6（P1）CONVENTIONS 11 現行違規 + 無 pre-commit 守門
- 現象：B-3（11 個 .bak，其中 codex 2 份含明文 key）、B-5（agents repo 無 hooks）。
- 為何是問題：.bak 含 key = 洩漏面×2；「版控取代 .bak」規則生效但無機械 enforcement。
- 修法：掃描（只印計數）→ 含密 .bak 直接刪、其餘刪除（正本皆在 git）；`~/.agents` 裝 pre-commit（gitleaks + .bak 阻擋）。key rotation 屬用戶帶外動作（live config.toml/claude.json 明文 ×2 仍在，見 B-4）。

### F7（P2）CLAUDE.md 與 core 雙正本（drift 面）
- 現象：CLAUDE.md 120 行中約 25 行逐句重複 tier0-2/routing/ledgers：L43≈T1-2、L44-45≈T1-7、L46≈S4 自簡化、L47≈T2-1、L48≈T1-6、L58/63≈T2-2、L61≈T0-9+S6、L62≈T0-3、L74-76≈T2-3/4。
- 為何是問題：同一規則兩處正本，改 core 不改 CLAUDE.md 即 drift（本次 F2 就是同型病）；Claude 常駐 ≈23KB 無預算約束。
- 修法：重複段刪除、留 rule-ID 一行引用；Claude 專屬操作面（Self-Maintenance、Auto-mode commit、@import 表、Claude 端 skill 名路由）保留。分類三分法：(a) 已在正本→刪 (b) 共用價值未入正本→升遷或明列不升理由 (c) host 專屬→留。
- 升遷評估結論（(b) 類）：`L61 merge-gate bot-subset 教訓`（PR #36 案例）正本已在 dev-workflow S6 + ledgers → 刪；`L64 reproducible commit`＝T1-3 → 刪；`L87 baseline capture`＝T1-4 → 刪。無需新增 core 條文。

### F8（P2）codex-delta 重述 ledger 正本
- 現象：codex-delta L10-19 逐欄重述 Closeout Ledger 6 欄；L21-23 PR monitoring 與 S6 step3/T0-9 重疊。
- 探針：`references/ledgers.md` 已是三家共用權威定義（S6 EXIT 強制）。
- 為何是問題：雙正本 drift 面 + 佔 88% 預算的注入空間。
- 修法：縮為引用 + 保留 codex 特有 heartbeat 語句。

### F9（P3）lint/doctor 守護缺口
- 現象：lint1 名稱掃描僅 core/routing.md，不掃 hosts/*.md；doctor 無 per-host skill 可見度探針。
- 為何是問題：9 死名事故的教訓只防了一半——host delta 寫死 skill 名一樣會腐爛。
- 修法：lint1 擴 hosts/*.md；doctor 加探針提示句。

### F10（P3）~/.codex/skills 在管理視野外
- 現象：B-11 → 8 個實體目錄，非 ~/.agents symlink；`codex-primary-runtime` 是空目錄；config.toml 無 skill 載入設定。
- 修正認知：`architecture-html-doc` **仍在服役**（SKILL.md L129：退役為 mermaid→HTML 衍生器，非棄用）——不可歸檔。
- 為何是問題：這批 skills 無版控、無 lint、無 doctor 覆蓋；空目錄與確實停用者（chronicle、migrate-to-codex、codex-primary-runtime）混在服役者旁邊。
- 修法：僅歸檔「確定停用」者到 `~/.agents/attic/codex-legacy-skills/`（搬移可逆）；服役者（architecture-html-doc、pdf、playwright、codex-dynamic-workflows、security-ownership-map）留置並記錄清單。判不準者留置。

### F11（P3）codex/copilot 手寫設定無版控
- 現象：B-12。hooks.json / mcp-config.json / config.toml 等手寫設定改壞無法 revert；CONVENTIONS 11「版控取代 .bak」在此二目錄不可執行——.bak 之所以長出來，正因沒有 git。
- 修法：最小 allowlist git 化（預設 `*` 忽略；追蹤 hooks.json、mcp-config.json、permissions-config.json、config.toml 除外——**含明文 key，外部化前永不追蹤**；auth/session/db/log 一律排除）+ 同款 pre-commit。

### F12（P1）通用 skill 路由知識只存在 CLAUDE.md（用戶發現）
- 現象：CLAUDE.md L18-35 的 Skill Routing 含大量三家皆可用的路由（`init-project-docs`、`acquire-codebase-knowledge`、stack `*-best-practices` 系列…），但 routing.md 點名清單只有 10 個主鏈 skill。
- 探針：`ls -d ~/.agents/skills/init-project-docs`（存在）+ `grep -c 'init-project-docs' ~/.codex/AGENTS.md ~/.copilot/copilot-instructions.md` = 0+0。
- 為何是問題：skill 資產在共用層，發現機制卻是 Claude 獨有。影響分家——Copilot 有 available_skills description 觸發，勉強能自救；**Codex description 截斷 2-6 字元、路由全靠點名，沒點名＝skill 形同不存在**。三家同一任務（如新專案初始化）行為分歧。
- 修法：併入 rules-visibility → 擴為「routing 可見度補全」：routing.md 加壓縮類別句（一句涵蓋一類，照 CLAUDE.md L19 壓縮法），僅收「三家皆在 ~/.agents/skills」者；Claude 專屬（superpowers plugin、agents、mp-* escalation 細節）留在 CLAUDE.md。預算由 F8 釋放空間補償。
- **教訓（制度化）：判斷「路由知識放 host 檔還是 core」的準則＝skill 本體在共用層則路由句必須在共用層；host 檔只准路由 host 專屬資產。**

## D. 制度沉澱（新條款進 CONVENTIONS，理由在此、條文在彼）

1. **CONVENTIONS 12「常駐面總預算」**：注入預算只管 codex/copilot 組裝檔，Claude 常駐面（CLAUDE.md+core+routing stamp）無上限 → 訂量測式上限，超標先刪重複再新增。
2. **CONVENTIONS 13「加一刪一」**：預算 88-92% 常態下，注入層新增內容須同批指出刪除補償來源，防止逐句膨脹到 lint 硬失敗才處理。

## E. 執行結果（2026-07-08 完成；接手 AI 從此表核對）

| Todo | 狀態 | 驗證 |
|------|------|------|
| fix-copilot-delta (F1,F2) | ✅ | copilot-delta.md L8 改單一部署目標；L13 指向 `~/.agents/rules/<stack>.md`；README L31 同步 |
| fix-codex-delta (F8) | ✅ | Closeout 6 欄重述→引用 ledgers.md；PR monitoring→S6/T0-9 引用，保留 codex heartbeat |
| fix-t0-verify (F3) | ✅ | T0-3 驗證欄分 host（Claude=hook audit-bash；Codex/Copilot=無全域機械攔截）；dev-workflow L129 adapter 改「三支皆 SessionStart」 |
| sync-bootstrap-core (F4) | ✅ | bootstrap 建 core symlink；doctor 掃 core+rules+skills 斷鏈+core 3 檔存在；dotclaude .gitignore 加 `!core/`；隔離環境（HOME=/tmp）實測通過 |
| rules-visibility (F5,F12) | ✅ | routing.md +2 行（通用路由句+rules pointer）；三家注入體 grep 皆命中 |
| lint-extend (F9) | ✅ | lint1b 掃 core+hosts backtick kebab 死名（NONSKILL allowlist）；紅綠測試通過；doctor 加三家 skill 可見度探針句 |
| bak-cleanup (F6) | ✅ | 11 個 .bak 掃 secret 後全刪；`ls *.bak*\|wc -l`=0；app 自管 dotfile bak（`.codex-global-state.json.bak`）另掃無 leak、依 CONVENTIONS 11 例外保留 |
| agents-precommit (F6) | ✅ | pre-commit-agents.sh（.bak 阻擋+gitleaks）+install 腳本；紅綠測試 3/3；後續修正：無 .gitleaks.toml 的 repo 改用 gitleaks 內建 default（~/.codex 誤攔實證） |
| claude-dedup (F7) | ✅ | CLAUDE.md 15.6KB→10.1KB（-35%，含 stamp 刷新後）；重複片語 grep=0；@import 完好；Claude 專屬語意（Push back 語氣/subagent/auto-mode/system override）保留 |
| codex-skills-attic (F10) | ✅ | migrate-to-codex 歸檔 attic/codex-legacy-skills/（附 README 處置表）；codex-primary-runtime 空目錄刪除；architecture-html-doc 確認在役保留 |
| gitify-hosts (F11) | ✅ | ~/.codex（49 檔）+~/.copilot（9 檔）allowlist git 化；config.toml/auth.json/data.db 未追蹤；gitleaks staged 掃描乾淨；pre-commit 已裝 |
| conventions-update (D) | ✅ | CONVENTIONS 12（Claude 常駐面 ≤20KB 量測式；現況 16.3KB）+13（≥90% 加一刪一）+11 例外句（app 自管 bak） |
| budget-recheck | ✅ | lint PASS；codex 9234B/copilot 9982B ≤10240B；doctor 全綠；stamp 機械刷新落地（refresh_claude_stamp）；三家 FP 靜態探針命中 |

### 執行中新增的制度產物（原計畫外）

- `agents-sync refresh_claude_stamp()`：CLAUDE.md routing stamp 由 deploy 機械刷新——手動快照必 drift 的實證（routing.md 加行後 stamp 停留舊版一整輪）落地為 CONVENTIONS 9「可機械化必下沉」案例。
- F12（用戶提問發現）：通用 skill 路由句只存在 CLAUDE.md → Codex/Copilot 不可見；已併入 rules-visibility 修正。制度教訓：**skill 本體在共用層，路由句就必須在共用層**。

## F. 接手指令（給下一個 AI）

1. 先跑 §B 全部探針；任何結果與表不符 → 以 live 為準、更新本表再行動。
2. 改注入層前必跑 `agents-sync --check`（lint+預算），改後部署 + `--doctor`。
3. 部署宣稱唯一權威 = agents-sync TARGETS；散文轉述必附探針（F1 教訓）。
4. 防線宣稱必分 host 核對——一家有 hook 不代表三家有（F3 教訓）。
5. key rotation 與 config.toml key 外部化仍是用戶帶外待辦（B-4）。

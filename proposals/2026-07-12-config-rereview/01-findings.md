# 01 — Findings（48 confirmed + 6 critic gaps，0 refuted）

> **讀者是 AI 模型**。severity 為對抗驗證後調整值；`▼`= 被降級、`▲`= 被升級。每條附可重跑探針——探針輸出若與本檔宣稱不符，以現場為準（本檔是 2026-07-12 的 point-in-time 快照）。原始 evidence 全文在 Workflow `wf_b640f194-398` journal（session e7b2a094）。

---

## P1（5 條）

### HOOKS-F2 — Copilot 機械守護零配置 + $HOME 全域 write auto-approve
- **主張**：三家防線最弱者（Copilot：無 hooks、無 drift-check、無 audit）反而權限最寬——`~/.copilot/permissions-config.json` 的 `locations["/Users/pochientsai"].tool_approvals` 含 `{"kind":"write"}`，全檔無任何 deny。
- **探針**：`python3 -c "import json;d=json.load(open('$HOME/.copilot/permissions-config.json'));print(d['locations']['/Users/pochientsai']['tool_approvals'])"`
- **建議**：移除 $HOME 級 write auto-approve，只留具體專案根；conformance.sh 加探針。

### GAP-2（critic）— Codex [projects] 22 項全 trusted，含 `/` 與 $HOME
- **主張**：`~/.codex/config.toml` `[projects."/"]` 與 `[projects."/Users/pochientsai"]` 皆 `trust_level="trusted"`，搭配 `sandbox_mode="workspace-write"`——任何陌生 repo（含惡意 AGENTS.md）啟動即繼承 trusted。是 HOOKS-F2 的 Codex 對偶。22 項多為一次性目錄（.Trash、/private/tmp），屬「每問必按 trust」累積非設計。
- **探針**：`grep -B1 'trust_level' ~/.codex/config.toml | grep -E 'projects\."(/|/Users/pochientsai)"\]'`
- **建議**：容器級路徑（`/`、$HOME、~/Downloads、/private/tmp）全數移除 trusted；conformance 探針見 03 [C-trust]。

### SYNC-F1 / F-R3 — ~/.claude repo 62 路徑未 commit（含 core/ symlink）
- **主張**：3 ??/49 M/10 T 未入版控，含未追蹤的 `core/` symlink——fresh clone 會使 CLAUDE.md 頂部 tier0 @import 斷鏈；off-machine backup 缺這 62 路徑已 2–5 天。
- **探針**：`git -C ~/.claude status --porcelain | wc -l`
- **建議**：gitleaks 過後 commit + push（Batch A3）。

### AG-1 — agents/ 是唯一無正本、無 banner、無 sync 覆蓋的部署資產類
- **主張**：44 `.md`（Claude）+ 43 `.toml`（Codex）+ 5（Copilot）全手寫平行維護，agents-sync 零覆蓋。治理方案：正本落 `~/.agents/agents/*.md`（Claude 格式）、Claude 端 symlink、Codex 端 md→toml render（配方已存在：`skills/init-project-docs/references/agents/codex/README.md`）、Copilot 不納入（維持「不預養第三格式」決策）。唯一 speculation：Codex `multi_agent` 載入 `~/.codex/agents/*.toml` 的實際語意未實測，落地前需一次 codex 探針。
- **探針**：`ls ~/.claude/agents/*.md | wc -l; ls ~/.codex/agents/*.toml | wc -l; grep -c 'agents/' ~/.agents/bin/agents-sync`
- **佐證（AG-2）**：drift 已實際發生第一筆——`tdd` 對在 07-10 同一修復被兩側各自手改成不同結果（md 指名 dotnet-testing-expert、toml 泛稱）；其餘 42 對 body 逐字相同。

### META-1 — 衝突裁決鏈對「plugin hook 常駐注入 prose」無槽位
- **主張**：ponytail SessionStart/SubagentStart 注入的行為指令（「Ship the lazy version…never stall」「Code first」）與 [T0-5]（模糊時停下發問）、[T0-8]（先計畫後改檔）正面衝突，而 tier0 裁決鏈六個位階沒有任何一格收容「plugin 注入 prose」——模型無裁決依據。（標 speculation：「模型會誤歸 user 當下明示」是推理路徑非實測；裁決空洞本身是事實。）
- **探針**：`grep -n '裁決鏈' ~/.agents/core/tier0-safety.md`——確認位階清單無 plugin/注入槽位。
- **建議**：新增 [T0-10]，見 03。

---

## P2（26 條，含 critic 3 條）

### INJ-1 — 缺 source→dist staleness 守護；現行部署即為 dirty-tree 產物
- **主張**：`~/.codex/AGENTS.md` banner 宣稱 `@3035553` 但 body 含 `cd13abe` 的內容（dirty tree 時部署造成 sha 與內容脫鉤）；doctor / drift-check / pre-commit 三者皆偵測不到「core 已 commit 但未重跑 sync」。spec `2026-07-07-three-host-unification/02-config-layer.md` L73 明文要求 STALE 偵測但實作漏掉——規格符合性缺口。
- **探針**：`head -3 ~/.codex/AGENTS.md | grep -o '@[0-9a-f]*'; git -C ~/.agents log --oneline -1`
- **建議**：agents-sync 部署前驗乾淨工作區；doctor 加 fresh-regen body 比對（現 conformance 已有類似探針，但 doctor 常跑面沒有）。

### INJ-2 — FP 指紋 HTML comment 載體在 Claude host 被剝離
- **主張**：`claude -p '輸出 context 中所有 FP: 開頭字串'` → NONE；對照組復誦 [T0-3] 成功——證明 core 本體有載入、`<!-- FP:... -->` 不進 context。FP 機制在三家中對 Claude 全盲。
- **探針**：`claude -p "列出你 context 中所有 FP: 開頭的 codeword，沒有就回 NONE" --max-turns 1`
- **建議**：FP 載體改為會進 context 的散文行（03 CONVENTIONS-15）。

### INJ-3 — CLAUDE.md 反引號名稱引用（40+）不在 lint 覆蓋
- **主張**：lint1b 只掃 core/hosts 的引用存在性；`~/.claude/CLAUDE.md` 自身點名的 skill/agent/hook/template 無 lint。今日逐一驗證零死名，但這正是 07-06「9 死名事故」的同型面。
- **探針**：`grep -n 'lint1b' ~/.agents/bin/agents-sync`（確認掃描範圍）
- **建議**：lint10（03）。

### INJ-4 / HOOKS-F1 ▼ / SYNC-F3 — Codex audit-bash 舊版未接線（dormant footgun）
- **主張**：`~/.codex/hooks/audit-bash.sh` 仍為 4/17 舊版（無遮罩、無 600），未被 `~/.codex/hooks.json` 引用（dormant）；但 `config.toml` `[hooks.state]` 留 stale `trusted_hash`，一旦照殘留恢復掛載即無遮罩落盤，且 LOG 硬編碼寫 `~/.claude/audit-bash.log`（跨 host 汙染）。降級理由：現況未執行。
- **探針**：`grep -c 'mask\|600' ~/.codex/hooks/audit-bash.sh; grep -c 'audit-bash' ~/.codex/hooks.json; grep -n 'trusted_hash' ~/.codex/config.toml`
- **建議**：對齊 ~/.agents/hooks 正本或明確除役＋清 trusted_hash。

### HOOKS-F4 — ~/.codex 755 + logs_2.sqlite 644（1.2GB session 全文 staff 可讀）
- **探針**：`stat -f '%Lp %N' ~/.codex ~/.codex/logs_2.sqlite`（對照 ~/.claude 的 600/700 紀律）
- **建議**：`chmod 700 ~/.codex; chmod 600 ~/.codex/logs_2.sqlite`。

### HOOKS-F5 — pre-commit-claude.sh 獨缺 gitleaks 段（四 repo 唯一）
- **主張**：只靠手寫 regex；gitleaks 8.30.1 binary 在機。
- **探針**：`grep -c gitleaks ~/.agents/hooks/pre-commit-claude.sh`（對照其他三份 pre-commit-*.sh）
- **建議**：補齊 gitleaks 段。

### SYNC-F2 — ~/.codex 與 ~/.copilot 無 git remote，零 off-machine backup
- **主張**：gitleaks 掃全歷史 0 findings，建 private remote 無前置風險；本機連 Time Machine 都無（verifier 加重事實）。
- **探針**：`git -C ~/.codex remote -v; git -C ~/.copilot remote -v; tmutil latestbackup 2>&1`
- **建議**：比照 agents-config 建 private remote push（Batch A4）。

### SYNC-F4 — Codex 權限正本 rules/default.rules 未版控
- **主張**：被 `.gitignore` 的 `*` 吞掉；7 條 prefix_rule、無 secret，07-10 B3b 修剪後只存在工作區。
- **探針**：`git -C ~/.codex check-ignore rules/default.rules && echo IGNORED`
- **建議**：gitignore 加 `!rules/` 例外後 commit。

### SYNC-F5 — doctor 三盲點
- **主張**：不驗 source freshness（見 INJ-1）、不驗 missing skill symlink（僅 --bootstrap 建）、不掃 ~/.claude/hooks 斷鏈。
- **探針**：`grep -c 'newer\|symlink\|hooks' ~/.agents/bin/agents-sync`（doctor 分支）
- **建議**：三項全補進 --doctor。

### SKILL-01 — 「Codex description 截斷 2–6 字元」宣稱 stale（散布 9 處）
- **主張**：codex-cli 0.144.0 `codex debug prompt-input` 實測 52 條 description 全文注入。宣稱散布：`core/routing.md:7`、`hosts/codex-delta.md:21`、dist×2、三家部署檔、DCT 專案 `CLAUDE.md:87`、Claude auto-memory `three-host-config-audit-facts.md`。副作用：「description 寫壞也無所謂」假設不再成立（description 現在是 routing 的實質輸入面）。根因：host CLI 升版（0.142.5→0.144.0）後能力宣稱未重驗——制度化見 03 CONVENTIONS-14。
- **探針**：`codex debug prompt-input 2>/dev/null | grep -c 'description'`；`grep -rn '2–6 字元\|2-6 字元' ~/.agents/core ~/.agents/hosts ~/.agents/dist`

### SKILL-02 — skill description 常駐注入量無預算 lint
- **主張**：Codex 每 session 吃 ~29-30KB skills_instructions（99 條 entry）；lint7 只管 core 常駐面，description 總量無人管。
- **建議**：lint8（03）。

### AG-2 — agents drift 第一筆實證（tdd 對，3 行分歧）
- **探針**：`diff <(sed -n '/prompt/,$p' ~/.codex/agents/tdd.toml) <(cat ~/.claude/agents/tdd.md)` 形態比對（精確指令見 workflow journal；中間產物曾落 scratchpad norm/*.body）。

### AG-3 — 44 個 Claude agent 中制度層只點名 3 個（93% 零引用）
- **主張**：CLAUDE.md/routing 只點名 code-reviewer / dotnet-code-reviewer / uiux-reviewer；code-simplifier 實際來自 plugin 非 agents/。建議 keep/trim 收斂 87→~25 檔。
- **探針**：`for f in ~/.claude/agents/*.md; do n=$(basename $f .md); grep -rq "$n" ~/.claude/CLAUDE.md ~/.agents/core/ || echo "unreferenced: $n"; done`

### F-R2 — stitch key 外部化的帶外前提未完成（已逾期 2 天）
- **主張**：shell profile 無 `source ~/.codex/stitch.env`（6 檔 grep 0 hit）→ codex 側 stitch MCP 自 07-10 起缺 header；且無任何探針監測帶外事項逾期。
- **探針**：`grep -l 'stitch.env' ~/.zshrc ~/.zprofile ~/.zshenv ~/.profile ~/.bashrc ~/.bash_profile 2>/dev/null | wc -l`
- **建議**：用戶帶外補 source；制度化見 03 GOV-4。

### F-R4 — 2026-07-11 審計 6 條 P1 未持久化（審計成果遺失實證）
- **主張**：proposals/ 無該日目錄、`grep -rn '2026-07-11' ~/.agents/proposals/` 0 命中；其中「audit-bash versioning drift」一條今日已無法自題面重現。
- **建議**：GOV-3 持久化義務（03）；本檔即是對此的償還。

### F-R6 — 三家防線失衡仍開放
- **主張**：Codex/Copilot 阻擋式 hooks 未配置（[T0-3] 驗證欄自己誠實記載）；Claude `permissions.allow` 含 `Bash(gh *)` 廣放行（涵蓋 `gh api -X DELETE` 等破壞面）。
- **探針**：`python3 -c "import json;print([x for x in json.load(open('$HOME/.claude/settings.json'))['permissions']['allow'] if 'gh' in x])"`

### META-2 — proposals/ 無狀態總表且 per-file status 標頭已 rot
- **主張**：07-07 README 標 PROPOSAL 但遷移早已執行；07-10 01-verdicts 標「修復未執行」但 03-execution 已記全部 commit。
- **建議**：`STATUS-draft.md` 落地為 `proposals/STATUS.md` + GOV-1。

### META-3 — CONVENTIONS.md 可發現性斷鏈
- **主張**：常駐面唯一指標是 [T2-5] 的 bare filename 引用（自違 CONVENTIONS 4）；~/.agents 根無 CLAUDE.md/AGENTS.md 觸發載入。
- **探針**：`grep -rn 'CONVENTIONS' ~/.agents/core/*.md`

### META-4 — 模型/host 換代韌性缺制度
- **主張**：tier0/routing 內嵌可變 live 狀態與 host 版本事實（如 [T0-3] 驗證欄的 hooks 配置現況）無重驗排程；FP 年季（2026Q3）無輪替義務。SKILL-01 即此缺口的實害案例。
- **建議**：CONVENTIONS-14 + GOV-5（03）。

### META-5 — 缺「新增 skill 上線 checklist」
- **主張**：lint 只防死引用（點名了不存在的 skill）不防隱形（實存 skill 未被 routing 點名）。
- **建議**：GOV-2（03）。

### GAP-1（critic，P1→歸類 P2 修復但屬結構性）— memory／知識沉澱制度整維度缺席
> critic 原判 P1；修復可分批，但這是「三 AI 共用一條 workflow」最大的未點名結構障礙。
- **主張**：三 host 三套互不相通記憶儲存（Claude auto-memory / `~/.codex/memories/` 自有格式 / Copilot memory MCP 且無 MEMORY_FILE_PATH、知識圖落 npx cache 易失）；共用正本 skill `bug-fix-settlement` L67/L78 硬編 Claude 專屬 auto-memory 為沉澱目標，host adapter 層零映射。
- **探針**：`grep -n 'auto memory\|MEMORY.md' ~/.agents/skills/bug-fix-settlement/SKILL.md; grep -c 'memory' ~/.agents/hosts/codex-delta.md ~/.agents/hosts/copilot-delta.md`
- **建議**：`~/.agents/memory/`（git 版控）為跨 host 教訓正本；三家映射寫進 host adapters；Copilot MCP 補 MEMORY_FILE_PATH。規範見 03 CONVENTIONS-18。

### GAP-3（critic）— 系統性根因 A：機械守護落地無「三家 parity」制度步驟
- **主張**：至少 8 條存活 findings 同根因（Copilot 零守護、Codex audit-bash 舊版、Codex log 644、pre-commit gitleaks 獨缺、Copilot 無 drift-check、Codex/Copilot 阻擋 hooks 未配置、GAP-1、GAP-2）——Claude-first 實作、其餘兩家沉默缺席；conformance.sh 84 行探針全部只驗 Claude 側路徑；`~/.claude/commands/sdd.md` 存在而 `~/.codex/prompts/`、`~/.copilot/prompts/` 皆空（slash 資產同樣單家落地）。制度知道失衡（[T0-3] 驗證欄自白）卻無條文要求 parity 檢查，於是每次修復都再生產一次失衡。
- **探針**：`grep -c 'codex\|copilot' ~/.agents/tests/conformance.sh`
- **建議**：parity 矩陣義務（03 CONVENTIONS-16）。

### GAP-4（critic）— 系統性根因 B：規則「驗證：」欄與可執行探針全面脫鉤
- **主張**：core 四檔 24 條驗證欄 vs conformance.sh 僅 10 探針且綁死在 07-10 單一 proposal 批次；「宣稱式防線」findings（FP 對 Claude 失效、doctor 只印不執行、lint4 只查 2/5 要素、CONVENTIONS 11 glob 假綠、[T0-3] fallback 幻覺等 ≥7 條）全是此結構的實例。驗證欄是 prose，無機制連到可重跑探針，「宣稱有驗證」與「驗證真的會跑」永久漂移。
- **探針**：`grep -c '驗證：' ~/.agents/core/*.md; head -5 ~/.agents/tests/conformance.sh`
- **建議**：probe registry（03 CONVENTIONS-17）。

---

## P3（23 條，含 critic 2 條）

| ID | 主張（一句話） | 探針 |
|----|----------------|------|
| INJ-5 | tier0 檔頭 last-verified 標 07-08，實際最後 commit 07-10——時戳 rot | `head -3 ~/.agents/core/tier0-safety.md; git -C ~/.agents log -1 --format=%cs -- core/tier0-safety.md` |
| INJ-6 | codex-delta「已載入」宣稱無探針佐證 | `grep -n '已載入\|loaded' ~/.agents/hosts/codex-delta.md` |
| INJ-7 | copilot 部署檔 98.6%＝10099B/10240B，餘 141B 容不下一條 tier0 規則行 | `wc -c ~/.copilot/copilot-instructions.md` |
| INJ-8 | `~/.claude/plugins/` 三個 .bak 逃逸 CONVENTIONS 11 驗證式 | `find ~/.claude/plugins -name '*.bak*' -o -name '*.backup*'` |
| HOOKS-F3 ▼ | [T0-3] 驗證欄的 pre-commit/CI fallback 攔不住 force-push（四 repo 皆無 pre-push hook）；唯一有效是 server 端 branch protection | `ls ~/.claude/.git/hooks/pre-push ~/.agents/.git/hooks/pre-push 2>&1` |
| HOOKS-F6 | guard-git-push 可被 `sh -c` / `$VAR` 繞過（已知天花板，非新洞） | 設計文件既載 |
| HOOKS-F7 | 衛生債：.DS_Store 進版控／session-time orphan／stale hooks.state／watch-ci 誤報 | `git -C ~/.agents ls-files | grep DS_Store` |
| SYNC-F6 ▼ | ~/.agents 無 CI（三家 parity 靠人工；降級因 conformance 手動可跑） | `ls ~/.agents/.github/workflows 2>&1` |
| SYNC-F7 | banner `@gsha` 綁 HEAD 致非冪等 churn（無關檔 commit 也改 banner） | `grep -n 'gsha\|rev-parse' ~/.agents/bin/agents-sync` |
| SYNC-F8 | CONVENTIONS 11 驗證式假綠：`*.bak*` 抓不到 `*.backup*`；~/.claude 有 3 件 4-5 月殘留 | `find ~/.claude -maxdepth 2 -name '*.backup*'` |
| SYNC-F9 | lint 未覆蓋 CONVENTIONS 1/6/10 | `grep -c 'lint' ~/.agents/bin/agents-sync` |
| SYNC-F10 | .DS_Store 進版控 + .gitignore 缺排除 | `grep -c DS_Store ~/.agents/.gitignore` |
| SKILL-03 | ecpay 佔 skills 46% 體積、上游更新無 drift 偵測、已實際 behind | `du -sh ~/.agents/skills/ecpay; cat ~/.agents/skills/ecpay/UPSTREAM.txt` |
| AG-4 | codex agents .toml 用 `"""` 違自家 `'''` 配方；檔名與 name 不一致三例 | `grep -l '"""' ~/.codex/agents/*.toml | wc -l` |
| AG-5 | Copilot 5 agent 檔為社群匯入獨立體系（非治理缺口本體，記錄供 AG-1 方案排除） | `ls ~/.copilot/agents/` |
| F-R1 ▼ | 「雙 key」被推翻（三處同一把 key，sha256_8=5c957e66）；殘留＝`~/.claude.json` 明文仍在、rotate 帶外未執行 | `shasum -a 256 相關值比對（值不印明文，[T0-4]）` |
| F-R5 ▼ | 「FP 活體測試從未執行」被 memory 反證（07-08 Step 13 三家綠燈）；殘留＝07-10 部署後未重跑 | 見 INJ-2 探針 |
| F-R7 | agents 治理「另立提案」承諾尚未立案（下月未立案應升 P2）——本提案 Batch D1 即立案 | `ls ~/.agents/proposals/ | grep -c agents` |
| F-R8 | banner gsha 語意易誤判 drift（讀者以為 body==該 commit 內容） | 同 SYNC-F7 |
| META-6 | CONVENTIONS L3 宣稱 lint 強制五要素，實際 lint4 只查 2/5 | `grep -n '五要素' ~/.agents/CONVENTIONS.md ~/.agents/bin/agents-sync` |
| META-7 | README 宣稱 doctor 執行 FP 探針，實際只印指令不執行 | `grep -n 'FP' ~/.agents/bin/agents-sync` |
| GAP-5（critic） | plugins 是第五類平行維護部署資產：Claude 39／Codex 25／Copilot 9，行為級 plugin（ponytail、superpowers）三家 revision 各自漂移（Codex ponytail 14a0d79@07-10、superpowers d884ae0@07-06），零 parity 偵測——版本分歧＝同一 workflow 三家語意分歧 | `grep -o '\[plugins."[^"]*"' ~/.codex/config.toml | wc -l` |
| GAP-6（critic） | `~/.claude/settings.json` skipAutoPermissionPrompt / skipDangerousModePermissionPrompt / skipWorkflowUsageWarning 三鍵全 true，警示層自行卸除且無探針覆蓋（標 speculation：各鍵精確語意未見官方文件佐證；值為 true 是實測事實） | `python3 -c "import json;d=json.load(open('$HOME/.claude/settings.json'));print({k:d.get(k) for k in ('skipAutoPermissionPrompt','skipDangerousModePermissionPrompt','skipWorkflowUsageWarning')})"` |

---

## 回歸確認（全綠，防重複審計）

- conformance.sh 10/10 PASS（探針 4 暫移之 AGENTS.md 已還原，shasum 前後一致）。
- settings.json autoMode 三陣列 `"$defaults"` 皆在；deny 22 條健在（rm -rf 探針被實際攔截，活體驗證）。
- guard-git-push async:false 先於 audit-bash；11 種 push 形態判定正確。
- audit-bash 遮罩實測生效（synthetic key → `***` 落盤、log 600）。
- dist/manifest/live 三方 hash 一致；fresh body == live body（僅 banner @gsha 落後，見 SYNC-F7）。
- 四 repo pre-commit 皆安裝且與正本 identical；gitleaks 掃四 repo 全歷史 0 findings。
- Claude skills symlink 52/52 相對路徑、斷鏈 0；skill-index 與實際 diff IDENTICAL；三家 skill 載入面全驗證成功（Claude symlink＋session 可見／Codex debug prompt-input／Copilot skill list 1.0.70）。
- 四 repo 07-10 之後零 commit、~/.codex ~/.copilot ~/.agents 工作區乾淨 → 無 commit 級回歸。

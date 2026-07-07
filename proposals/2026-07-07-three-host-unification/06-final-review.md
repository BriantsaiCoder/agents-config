<!-- status: PROPOSAL 附件（最終審查裁決）| created: 2026-07-07 | author-model: claude-fable-5 | method: 對 01–05 批判性複審 + live 同日再驗證 | readers: AI models（Opus / Sonnet / Codex GPT 5.5+）-->
# 06 最終審查：裁決、精度修正與 B0 止血批

> 適用：全 host｜載入：無（PROPOSAL，未生效）
>
> 結論先行：**六檔藍圖整體成立，維持推薦方案 B；但新增一個必須前置的「B0 止血批」**。
> 理由一句：現行方案把「正在流血的風險」（Codex 防線休眠＋approval 自動放行、明文 API key、autopilot 繞過 plan gate）排在「並行待辦」，風險排序倒置——這三件事不需要任何基礎設施，30 分鐘可止血，且與遷移完全獨立。

## A. 六檔裁決表

| 檔 | 裁決 | 修訂（已直接織入該檔，本表僅記錄） |
|----|------|------|
| README | 成立 | 文件地圖補本檔；帶外待辦改指 B0 |
| 01-audit-findings | 成立 | 一處精度修正：Copilot 覆蓋率「0%」→「摘要覆蓋＋第三平行正本」（見 C-R2）；F3 補 9 死名逐列 |
| 02-config-layer | 成立 | 一處簡化：`agents-doctor` 併入 `agents-sync --doctor` 子命令——少一支腳本＝少一個 drift 面（見 C-R4） |
| 03-workflow-layer | 成立，無修訂 | 複核通過「拔掉全部 Claude 專屬件仍能跑」測試；X0 機械判定契約（ENTER/EXIT 只准檔案存在／用戶關鍵字／exit code）是全案最重要的抗模型換代設計，任何後續修訂不得弱化 |
| 04-migration | 成立 | 插入 B0 止血批（前置於方案 A/B）；帶外安全三項升入 B0 |
| 05-conventions | 成立 | 增補第 11 條「版控取代 .bak」（見 C-R3） |

## B. Live 現況快照（2026-07-07 20:4x 再驗證；快照距今 >7 天則重跑探針再行動）

| # | 事實 | 探針（可重跑） | 本次結果 |
|---|------|----------------|----------|
| B-1 | `~/.agents` 未 git 化；13 步遷移 0 執行 | `ls -d ~/.agents/.git` | 不存在 |
| B-2 | stitch key 明文面 | `grep -c 'X-Goog-Api-Key' ~/.codex/config.toml ~/.claude.json`（**勿印值**）；`ls ~/.codex/config.toml.bak*` | 1 + 1 + .bak×3 |
| B-3 | Codex 注入仍僅 `AGENTS.override.md`（1.5KB；32KB `AGENTS.md` 遭整檔取代，防線休眠） | 檔案 mtime 未變（override 2026-06-30、AGENTS.md 2026-07-03）；活體探針見 02 | 屬實 |
| B-4 | Codex 目錄 .bak 檔 26 份（AGENTS×23 + config.toml×3）；Copilot 4 份 | `ls ~/.codex/*.bak* \| wc -l` | 26 / 4 |
| B-5 | Copilot 常駐 = `copilot-instructions.md`（含假繼承宣稱＋9 死名）+ `instructions/global-core.instructions.md`（45 行英文摘要，**確實常駐**） | `copilot -p '列 instruction 檔' --available-tools=` | 屬實 |
| B-6 | 9 死名逐列（對 `~/.agents/skills/` 機械核對）：`dotnet-design-pattern-review`、`dotnet-timezone`、`api-design-principles`、`devops-rollout-plan`、`refactor-plan`、`refactor-method-complexity-reduce`、`mp-to-prd`、`ai-prompt-engineering-safety-review`、`unit-test-vue-pinia` | 對每名 `[ -d ~/.agents/skills/<name> ]` | 9/9 DEAD |
| B-7 | `~/.zshrc:183-184` 以 **function**（非 alias）包 `copilot --autopilot` | `zsh -ic 'type copilot'` | 屬實 |
| B-8 | `chrome-devtoolss` 拼錯仍在 | `grep -c 'chrome-devtoolss' ~/.copilot/mcp-config.json` | 1 |
| B-9 | `~/.claude/skills/` 50 條 symlink 全為絕對路徑（換機斷鏈） | `ls -la ~/.claude/skills \| grep -c '/Users/'` | 屬實 |
| B-10 | 共用原料未變：`~/.agents/skills/` = 50、`~/.claude/rules/` = 8、`~/.claude/commands/sdd.md` 存在 | `ls` 計數 | 屬實 |

## C. 優化建議（R1–R5；R 編號永不重編）

### R1 新增 B0 止血批（最高優先；已織入 04）

現行 04 的「帶外並行待辦」語意 = 「與遷移平行、不急」；但其中三項是**現在進行式的暴露**，另兩項（防線休眠、假宣稱）是**現在進行式的失守**。修正：前置 B0 批（快照→stamp tier0 進 Codex override→修 Copilot 兩檔→rotate key→拆 autopilot function→改拼錯），每項獨立驗證與回滾，全文與照貼區塊見 04。設計約束：B0 只用「終局遷移本來就要退役的載體」（fenced markers stamp），不新增任何會活過遷移的機制——止血不留疤。

### R2 精度修正：「Copilot 覆蓋率 0%」→「摘要覆蓋＋第三平行正本」（已織入 01）

再驗證發現 `global-core.instructions.md` 確實常駐且含 force-push 禁令、no-evidence-no-done、模糊即停等核心條款。01 原句把「宣稱的繼承來源（CLAUDE.md）沒被載入」誤寫成「什麼都沒載入」。修正後的精確結論：Copilot 持有 45 行英文摘要版，**缺 rollback 義務、DB migration 分段、merge-gate bot review 三類**；且該檔構成第三份無同步的平行正本——這不削弱反而強化收斂理由（現有三個平行版本：CLAUDE.md 完整版／global-core 英文摘要版／AGENTS.override 近乎無）。制度教訓（適用未來一切審計）：**審計結論本身也要能被重驗；量化斷言（0%、100%）必附計算口徑**。

### R3 制度增補：版控取代 .bak（已織入 05 第 11 條）

30 份手工 .bak 是「無版控環境長出的手工版控」病徵，其中 3 份 config.toml.bak 額外複製了同一明文 API key——**備份檔是 secrets 殘留的最大死角**（rotate 正本、忘了 .bak = 白 rotate）。git 化後：設定變更一律 commit、禁產 .bak；既有 .bak 掃 secret 後刪除或歸檔 attic/。

### R4 簡化：agents-doctor 併入 agents-sync --doctor（已織入 02、04）

02 已把 `--check` / `--bootstrap` 設計為子命令，巡檢沒有理由獨立成第二支腳本。同一支腳本共用 targets 資料表與 manifest 解析，少一份實作漂移面。DRIFT / STALE 判定語彙不變。

### R5 Copilot 修補選「補缺」不選「再貼」（已織入 04 B0.2）

恢復 Copilot 安全底線有兩條路：(a) 把 tier0 整塊 stamp 進 `copilot-instructions.md`；(b) 在既有 `global-core.instructions.md` 補上缺的 3 條＋FP 句。選 (b)：global-core 已是 Copilot 事實上的核心層且經驗證常駐，(a) 會誕生第四份平行正本。終局遷移 Step 9 時 global-core 整檔歸檔 attic，由生成檔取代——(b) 的增量屆時一併退役。

## D. 執行順序總建議

```
B0 止血批（30 分，等用戶批准後當日做）
→ Step 0–2（快照、~/.agents git 化、殭屍 lock 隔離）
→ 方案 B（workflow 層：dev-workflow + sdd skills + routing stamp）
→ 設定層批次（tier 蒸餾、override 退役、rules 遷移、agents-sync）
→ Step 13 workflow 挂載驗證
```

維持 04 對方案 B 的推薦不變；B0 與方案 B 的差別：B0 修「正在發生的失守」，方案 B 建「不再失守的制度」。

## E. 下一個模型的接手指令（決定表，由上而下第一命中即走）

1. 先讀 [README.md](README.md) 與本檔 B 節快照；快照日期距今 >7 天 → 重跑 B 節全部探針，結果不符者以新結果為準並更新本檔。
2. 用戶已批准 B0 → 照 [04-migration.md](04-migration.md) B0 節逐項執行（B0.0 快照先行；每項驗證通過才下一項）。
3. 用戶已批准方案 B（或 A）→ 依 04 遷移表執行；任何探針失敗停在該步回滾回報，不硬推。
4. 均未批准 → 只回報現況與建議，**不動任何 live 檔**（README 鐵則：live 設定在用戶明確批准前一律不動）。
5. 執行中發現本目錄文件與 live 事實矛盾 → 以活體探針為準，修文件、記錄於本檔 B 節，再繼續。

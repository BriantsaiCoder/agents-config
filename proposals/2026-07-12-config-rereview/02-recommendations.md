# 02 — 修復建議（分批，未執行）

> **讀者是 AI 模型**。批次按「風險止血 → 根因制度 → 宣稱修正 → 治理資產 → 衛生」排序；每批可獨立批准/執行/回滾。執行任一批前重跑 01 對應探針確認現況未變（[T0-1]）。全部 git 內變更回滾＝`git revert`；git 管不到的標的在各批註明配方。

## Batch A — P1 權限與備份止血（風險：中；rollback：本批全部有明確原值記錄）

| # | 動作 | 對應 finding | rollback |
|---|------|--------------|----------|
| A1 | `~/.copilot/permissions-config.json` 移除 `locations["/Users/pochientsai"]` 的 write auto-approve，只留具體專案根 | HOOKS-F2 | 執行前 `git -C ~/.copilot` commit 現狀（該 repo 已 git 化） |
| A2 | `~/.codex/config.toml` `[projects]` 移除 `/`、$HOME、~/Downloads、/private/tmp 等容器級 trusted；只留具體專案根 | GAP-2 | 執行紀錄列出被移除條目原文（無 secret，可直接記） |
| A3 | ~/.claude repo：gitleaks 過 → commit 62 路徑 → push | SYNC-F1 | git revert |
| A4 | ~/.codex、~/.copilot 各建 GitHub private remote 並 push（gitleaks 已全歷史 0 findings） | SYNC-F2 | 刪 remote 即可，本地不變 |
| A5 | tier0 新增 [T0-10]（注入 prose 裁決槽位，文本見 03）＋ 重跑 agents-sync | META-1 | git revert + 重跑 sync |
| A6 | conformance.sh 為 A1/A2 加常設探針 | HOOKS-F2、GAP-2 | git revert |

前置：A1/A2 屬權限收斂，收斂後若某工具流程被打斷，放寬時只加回「具體路徑」不加回容器級。

## Batch B — 兩大系統性根因的制度落地（風險：低；純文件＋腳本）

| # | 動作 | 對應 |
|---|------|------|
| B1 | **parity 矩陣**：CONVENTIONS 新增第 16 條（03）；conformance.sh 重構——每個守護一節，三家各一探針或 `UNAVAILABLE(理由)` 標記；先補齊 GAP-3 列出的 8 個既有實例的矩陣現況 | GAP-3 |
| B2 | **probe registry**：CONVENTIONS 新增第 17 條（03）；core/ 24 條「驗證：」欄逐條標注 `[probe:<id>]` 或 `[manual:<頻率>]`；conformance.sh 從綁 proposal 批次改為 probe-id 索引的常設 registry；lint 檢查標注存在性 | GAP-4、META-6 |

> 為什麼 B 在 C 之前：不先立這兩條，Batch C/D 的每個修復又會是「Claude-first + 無探針」，重蹈覆轍。

## Batch C — sync/staleness 與 stale 宣稱修正（風險：低）

| # | 動作 | 對應 |
|---|------|------|
| C1 | agents-sync：部署前驗乾淨工作區（dirty 即 abort，`--force-dirty` 顯式豁免）；doctor 加 source-newer-than-dist STALE 探針 | INJ-1、SYNC-F5、SYNC-F7（順帶把 banner 改 content-hash 解非冪等） |
| C2 | FP 載體從 HTML comment 改為散文行（如「本檔載入驗證碼：FP:XXX-2026Q3」）；重跑三家活體探針並記錄輸出 | INJ-2、F-R5 |
| C3 | 更新 9 處「description 截斷 2–6 字元」stale 宣稱（core/routing.md、hosts/codex-delta.md、dist、三家部署檔＝重跑 sync 自動帶出；DCT 專案 CLAUDE.md:87 另在該 repo 提交；Claude auto-memory 已於本次審計同步更正）；補「description 現為 routing 實質輸入」的新事實 | SKILL-01 |
| C4 | Codex audit-bash：對齊 ~/.agents/hooks 正本（含遮罩＋600＋host 自己的 log 路徑）或明確除役；兩者皆須清 config.toml stale trusted_hash | INJ-4 |
| C5 | pre-commit-claude.sh 補 gitleaks 段（與其他三份對齊） | HOOKS-F5 |
| C6 | `chmod 700 ~/.codex; chmod 600 ~/.codex/logs_2.sqlite` | HOOKS-F4 |
| C7 | 帶外事項補探針：conformance 加「shell profile 含 stitch.env source」檢查（fail 時提示用戶帶外補做，不自動改 shell profile） | F-R2、GOV-4 |
| C8 | lint 補洞：lint4 補齊五要素檢查、lint8（description 預算）、lint9（FP 存在＋散文載體）、lint10（CLAUDE.md 名稱引用存在性）、CONVENTIONS 11 驗證式改雙 pattern | META-6、SKILL-02、INJ-3、SYNC-F8/F9 |

## Batch D — 治理資產（風險：中；agents/ 涉 87 檔）

| # | 動作 | 對應 |
|---|------|------|
| D0 | **前置探針**：實測 Codex `multi_agent` 對 `~/.codex/agents/*.toml` 的載入語意（AG-1 唯一 speculation），結果決定 D1 走 render 或退回文件化 | AG-1 |
| D1 | agents/ 治理：正本 `~/.agents/agents/*.md` → Claude symlink、Codex render（`'''` literal＋banner＋no-clobber＋conformance 探針；配方升格自 init-project-docs references）；Copilot 不納入 | AG-1、AG-2、AG-4、F-R7 |
| D2 | agents 數量收斂 87→~25（keep/trim 清單另出，依「制度層引用＋近 30 天實際 dispatch」篩） | AG-3 |
| D3 | plugin manifest：`~/.agents/` 記 ponytail、superpowers 的來源＋pin revision＋三家安裝狀態；`agents-sync --check` 比對三家 revision | GAP-5 |
| D4 | memory 正本：建 `~/.agents/memory/`（git 版控）；`bug-fix-settlement` 沉澱目標改指正本＋host adapters 三家映射；Copilot memory MCP 補 `MEMORY_FILE_PATH` | GAP-1 |
| D5 | `STATUS-draft.md` → `proposals/STATUS.md`；07-07/07-10 舊檔補一行 status 指標（不重寫內文） | META-2、GOV-1 |

## Batch E — P3 衛生（風險：低；一次 commit 可清）

.DS_Store 出版控＋gitignore、plugins/ 三個 .bak 依 CONVENTIONS 11 處置、last-verified 時戳更新、ecpay UPSTREAM drift 檢查機制、`~/.claude.json` stitch 明文（**待用戶帶外 rotate 後**再清，[T0-4]）、settings.json skip* 三鍵語意確認後決定去留（至少 skipDangerousModePermissionPrompt 建議回 false 或記錄有意豁免）、copilot 體積預算擴編或內容瘦身（141B 餘裕）、codex prompts/ 補 sdd 對等資產（併入 B1 parity 矩陣）。

## 不做清單（明確出界）

- audit log 歷史清洗（.log.1 10MB 含修復前未遮罩歷史）：0600 已緩解，收益低風險高——維持不做。
- Copilot agents 第三格式：維持 07-10「不預養」決策。
- guard-git-push 的 `sh -c`/`$VAR` 繞過（HOOKS-F6）：已知天花板，真防線是 server 端 branch protection（建議用戶於 GitHub 對 4 個 config repo 開 branch protection，屬帶外）。
- workflow v2 重寫、YAML policy engine：沿用 07-10 出界決策。

## 帶外事項（用戶親手，AI 不經手；對應 GOV-4 全數配探針）

1. shell profile 加 `source ~/.codex/stitch.env`（F-R2，已逾期）。
2. Google 後台 rotate stitch key；rotate 後清 `~/.claude.json` 明文與 .backup（F-R1 殘留）。
3. GitHub 上 4 個 config repo 開 branch protection（HOOKS-F3 唯一有效防線）。

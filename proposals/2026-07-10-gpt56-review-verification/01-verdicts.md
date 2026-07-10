<!-- status: PROPOSED（判定完成，修復未執行；修復需用戶確認後另開執行單）| created: 2026-07-10 | author-model: claude-fable-5 | method: 13 個獨立驗證 agent（Workflow wf_9362c960-f5f，940k tokens）+ 主線親讀雙軌，每項 finding 對 live 檔案/官方文件/binary 實作跑探針 | readers: AI models（Opus / Sonnet / Codex GPT 5.5+）-->
# 01 GPT 5.6 sol ultra review 逐項驗證判定

> 適用：全 host｜載入：無（proposals 不注入；接手時按需讀）
>
> 結論先行：**GPT 5.6 的 14 項 findings 中 8 項 CONFIRMED、6 項 PARTIAL（方向對、定性或細節誇大）、0 項 REFUTED；其 P0 五件中三件成立（F1/F3/F4）、兩件降級（F2→P1、F5→P2）。其提出的目標架構「語意採納、形式駁回」：semantic canon + host adapter + 可執行 conformance test 的方向正確，但 YAML policy engine / roles manifest / dist 全家桶對單一用戶環境屬 over-engineering——現有 markdown+規則 ID 已是 AI 可讀 canon，缺的只是可執行測試與修掉三處 false-green。**
> 讀者注意：快照距今 >7 天先重跑 §B 探針再引用結論。GPT 原始 review 全文在 session transcript，本檔只存判定與差異。

## A. 方法

對 GPT 5.6 review 的每項 finding 派一個獨立驗證 agent（回傳 finding_id / verdict / evidence 座標 / nuance / recommended_adjustment 結構化輸出），另主線親讀 settings.json、agents-sync、CONVENTIONS.md、dev-workflow SKILL.md、audit-bash.sh、drift-check.sh 交叉比對。verdict 定義：CONFIRMED=宣稱成立；PARTIAL=核心方向成立但定性/範圍/細節需修正；STALE=曾成立、07-08 審計已修；REFUTED=不成立。

## B. 判定表（F 編號沿用 GPT review 的 P0/P1/P2 分組；永不重編）

| # | GPT 宣稱 | GPT 級別 | 判定 | 級別調整 | 關鍵差異 |
|---|---------|---------|------|---------|---------|
| F1 | settings.json:293 autoMode 三陣列無 `"$defaults"` → 內建防線整段被取代 | P0 | CONFIRMED | 維持 P0 | 損失限 allow/soft_deny/environment 三段；`hard_deny` 鍵未設 → HARD BLOCK 內建規則仍完整生效。binary v2.1.206 的 merge 函式與 schema 三重印證 per-section 取代語意 |
| F2 | audit-bash.sh 永遠 exit 0 只 log 不擋；T0-3 驗證句是不實 enforcement 宣稱 | P0 | PARTIAL | **降 P1** | 「只 log 不擋」成立（且 GPT 沒發現註冊為 `async:true`，結構上不可能擋）；但 T0-3 驗證欄本就指事後稽核非 enforcement，「不實」定性過重 → 改「措辭誤導（防線幻覺）」。GPT 漏掉更實質缺口：permissions.allow 全域放行 `Bash(git push --force-with-lease *)`（含推 main）與 `Bash(gh *)` |
| F3 | audit-bash.log 1.65MB 0644 含 secret 樣式；pre-commit 把命中行印 stderr | P0 | CONFIRMED | 維持 P0 | 行號修正：印出在 pre-commit-claude.sh:72/:77（非 68），有 head -5 上限。既有緩解未被 GPT 計入：log 在 commit 黑名單、10MB rotation → 威脅模型限縮為本機磁碟/同機使用者/transcript 捕捉，非 git 歷史 |
| F4 | Codex protect-files.sh 對 apply_patch fail-open；prefix_rule 可前綴繞過；config.toml 明文 API key | P0 | CONFIRMED | 維持 P0 | fail-open 屬系統性：init-project-docs canonical 模板同缺 apply_patch body 解析。key 在 config.toml:72（stitch http_headers）；**rotate ≠ externalize**——07-10 B0.3 換發後仍是 inline 明文，須比照 github `bearer_token_env_var` 改 env var 引用 |
| F5 | dev-workflow S6 無條件 commit/merge/刪分支、bot review 排在 merge 後，違反 T0-9 | P0 | PARTIAL | **降 P2** | 「違反 T0-9」不成立：review-triage.md:6 明訂 merge 前四態 PASS、:45 明訂未等 review 就 merge = gate FAIL 撤回；裁決鏈（tier0-safety.md:9）讓 tier0 壓過 skill 步驟。真實問題只是 S6 ACTION 第 2（merge）、第 3（triage）步序易被逐字執行的 AI 誤讀 |
| F6 | agents-sync --check false-green、doctor 缺檔 exit 0、drift-check 恆 exit 0 | P1 | PARTIAL | 維持 P1（收窄） | 真實洞收窄為一條：**部署檔被刪 → doctor 只印 UNAVAILABLE 不設 rc（agents-sync:330,:335）→ drift-check 僅在 doctor 非零才告警 → 全鏈靜默**。--check 是設計上的 source 端 dry-run 非 bug（但 usage line 8 宣稱印 diff 實際沒有，doc 超賣）；「Claude 無 atomic deployment」錯誤——refresh_claude_stamp 有 mktemp+mv 原子寫入 |
| F7 | TARGETS 只覆蓋 2/3 host，Claude 無 delta/manifest/no-clobber | P1 | PARTIAL | 維持 P1（重定性） | 字面屬實（agents-sync:23-26），但 Claude 經 `@import` symlink 直接消費正本、無生成物可 drift，「未覆蓋」是架構選擇非缺陷。真缺口：CLAUDE.md 本體（Claude delta 等價物）無 manifest 列、預算檢查（CONVENTIONS 12）未機械化進 lint |
| F8 | Copilot 五檔 32,405B 重複注入；precedence 宣稱不可靠 | P1 | PARTIAL | 維持 P1（修證據） | 重複載入有活體實錘（CLI session 四份全文串接、AGENTS.md/CLAUDE.md 相似度 0.707）；但實際注入 30,770B（path rule 1,635B 不進 CLI）；「官方說 precedence 不確定」論證已過時——官方文件現已明定順序且與 line 5 宣稱一致，惟未明文涵蓋 CLI、且機制是無 enforcement 的全文串接 |
| F9 | 共用 protect-files.sh 的 Copilot adapter 過時；「無全域 hooks」宣稱 stale | P1 | CONFIRMED | 維持 P1 | 範本註冊的 camelCase `preToolUse` 模式下 payload（`toolArgs.path`）無 jq 路徑命中 → 靜默放行；deny 回應 schema 兩模式皆不符官方 `permissionDecision`。SKILL.md:135「無全域 hooks」作為**能力**陳述已過時（CLI 1.0.69 支援 ~/.copilot/hooks/），作為**現況**陳述仍真（未配置） |
| F10 | workflow 四處自相矛盾（S0 row6 不可達 / T0-8 vs 計畫產物 / 分支時序 / sdd 無 gate） | P1 | PARTIAL | 維持 P1（收窄） | 4 項 → 2 真 + 2 瑕疵：(a) S0 row 5 catch-all 使 row 6 表格語意不可達（周邊 prose :58 有補救但形式矛盾真）、(d) sdd SKILL.md 終態只靠 checkbox 無機械 gate——此二真；(b) T0-8「改檔」未豁免計畫產物是用詞不精非矛盾；(c) 分支時序是不優雅非矛盾 |
| F11 | 三平行 agent 治理面 44/43/5 手工維護；tdd 引用不存在的 Rails Testing Expert | P1 | CONFIRMED | 維持 P1 | 計數精準；生成管線與 manifest 完全不涵蓋 agents/。範圍擴大：Rails dangling reference 不只 Codex tdd.toml:24，Claude tdd.md:29,58,80 同殘留（同源範本），修復須兩檔並改 |
| F12 | CONVENTIONS 標題 11 條實際 13；lint 宣稱 > 實作；README「SessionStart 再生」不實 | P2 | CONFIRMED | 維持 P2 | 「11 條」stale 有三處（title、README:17、CONVENTIONS:68 附錄 B）；lint 僅 6 檢查、覆蓋 13 條中約 2.5 條，「違反 = build fail」超賣；SessionStart hook 只跑唯讀 --doctor 告警，「自動再生」是 proposal 設計意圖未落地 |
| C1 | Claude 官方語意：$defaults 省略即取代；PreToolUse 阻擋須 exit 2 / permissionDecision deny | 佐證 | CONFIRMED | — | 官方 docs + binary 實作一致。修正歸屬：無 "autoApprove" 這個 key；$defaults 只存在於 autoMode 四陣列，permissions.allow/deny 無此機制 |
| C2 | Codex/Copilot 均已支援可阻擋的 hooks（能力 drift） | 佐證 | CONFIRMED | — | 兩 CLI 能力屬實（Codex 0.144.0 PreToolUse 可 deny；Copilot ~/.copilot/hooks/*.json）。區分能力 vs 配置：「目前無全域機械攔截」作為配置陳述仍真；T0-3 應改寫為「能力已有、尚未配置」 |

統計：CONFIRMED 8（F1,F3,F4,F9,F11,F12,C1,C2）；PARTIAL 6（F2,F5,F6,F7,F8,F10）；REFUTED 0。GPT 的事實查核品質高（無一項憑空捏造），系統性偏差是**定性偏重**：把「文件措辭誤導」升格為「enforcement 不實」（F2）、把「有 gate 但步序易誤讀」升格為「違反 tier0」（F5）、忽略既有緩解與架構意圖（F3/F6/F7）。

## C. 架構提案裁決（GPT 的 semantic canon / policy engine / Workflow v2 / 6-phase rollout）

| GPT 提案 | 裁決 | 理由 |
|---------|------|------|
| 語意升級：shared prose → semantic canon + per-host verifiable adapter + executable conformance tests | **採納（語意）** | 方向正確且與既有 CONVENTIONS 5/6/9 同路——缺的不是新格式，是「可執行測試」補上 |
| ~/.agents/ 改組為 policy/ workflows/ capabilities/ hosts/ hooks/ roles/ tests/ dist/ + YAML DSL | **駁回（形式）** | 單一用戶環境；markdown + 五要素規則 + 規則 ID 已是 AI 可讀 canon（本次 13 agent 全靠它完成驗證即為實證）。YAML policy engine 需要自建 parser/validator，違反 [T1-7] 選型層級與 CONVENTIONS 9「可機械化者下沉為 hook/lint/test」——下沉目標是既有 bash lint 與 conformance script，不是新 DSL |
| 13 條 normative rules（GOV/AUTH/VER/GEN/SEC/CAP/OWN…） | **部分採納** | 吸收為既有體系增補而非平行命名空間：AUTH-001（commit/push/PR/merge/cleanup 各自獨立授權）→ 併入 S6 與 T0-9 補強；SEC-001（log 只記 command class/hash、0600）→ audit-bash 修復規格；GEN-001（fresh/dist/manifest/live 四方一致）→ doctor 補 fresh-vs-live 比對；CAP-001（能力宣稱附探測與有效期）→ 併入 CONVENTIONS 5 增補「能力 vs 配置」句式。其餘（GOV/VER/OWN）與既有規則重複，不另立 |
| Workflow v2（intent-first 全重寫） | **駁回** | F5/F10 驗證顯示問題是兩處局部（S6 步序、S0 row 順序 + sdd gate 缺句），局部修補 < 全機重寫的 drift 風險 |
| 6-phase rollout | **收斂為一份修復清單（§D）** | 規模不成比例；P0 三件是 config/腳本行級修改，不需要 phase gate |

## D. 修復清單（PROPOSED；執行前逐項取得用戶確認，[T0-8]）

P0（機械防線實質缺口）：
1. **F1**：`~/.claude/settings.json` autoMode 的 `allow`/`soft_deny`/`environment` 三陣列各補一項字面字串 `"$defaults"`（恢復內建 force-push / curl|bash / production-deploy 分類器防線，保留自訂規則）。
2. **F3**：audit-bash.sh 寫入前遮罩 secret 樣式（`password=***` 類）+ log `chmod 600`；pre-commit-claude.sh:72/:77 改印「檔名:行號 + key 名」不印命中行內容。
3. **F4**：protect-files.sh（含 init-project-docs canonical 模板）對 apply_patch 改 fail-closed（解析不到目標檔即擋）；`~/.codex/config.toml:72` stitch key 比照 github 改 env var 引用並於後台撤舊值；default.rules prefix_rule 改精確 argv 比對。

P1（false-green / 防線幻覺 / 治理面）：
4. **F2+C2**：T0-3 驗證句 Claude 半句改「audit log 事後稽核，無前置機械攔截」；權衡是否收斂 permissions.allow 的 `git push --force-with-lease *`（至少排除 main/master）；可選：落地 PreToolUse git guard（async:false + exit 2），Codex/Copilot 比照（能力已有）。
5. **F6**：agents-sync doctor 對「manifest 有列但部署檔缺失」設 rc=1；usage line 8 刪「diff」或補實作。
6. **F9**：protect-files.sh copilot 分支改輸出 `permissionDecision` schema（或 exit 2）、jq 補 `.toolArgs.path`；SKILL.md:135 改寫「能力已有、現況未配置」。
7. **F11**：刪 Codex tdd.toml:24 與 Claude tdd.md:29,58,80 的 Rails dangling reference；三主機 agents/ 治理面收斂另立提案（規模大、非本單範圍）。
8. **F12**：CONVENTIONS 三處「11 條」改 13；:3 build-fail 宣稱改列 lint 實際覆蓋範圍；README「SessionStart 自動再生」改「drift 巡檢告警」。

P2（文件清晰度）：
9. **F5**：S6 ACTION 第 2/3 步對調，或第 2 步補註「merge 待 triage 四態 PASS（[T0-9]）」。
10. **F10**：S0 row 6 移到 row 5 前（或 row 5 加「且無 LIGHT 研判」）；sdd SKILL.md 終態前加「MUST 通過 S4–S6 對應 gate 或逐項標 SKIPPED 附理由」。
11. **F7**：CLAUDE.md 納入 manifest 量測（CONVENTIONS 12 機械化進 lint）。

新增 conformance test（GPT 語意的落地形式；一支 bash 即可，掛 `~/.agents/tests/`）：
- 探針集：`grep -c '\$defaults' ~/.claude/settings.json` ≥3；audit-bash.log mode=600；apply_patch synthetic payload 進 protect-files.sh exit≠0；doctor 對暫時 mv 走部署檔回 rc=1；CONVENTIONS 標題數字 = 實際 `grep -c '^## [0-9]'`。

## E. 教訓（判斷類，供後續 AI 沿用）

1. **外部 review 的定性要重驗，事實可信**：GPT 5.6 事實查核 0 捏造，但 5 件 P0 有 2 件靠「忽略既有 gate 文件與裁決鏈」撐起嚴重度。接收外部 audit 時，先驗其「違反 X」宣稱中 X 的完整語境（正本 + 裁決鏈 + 引用的 references），再接受級別。
2. **能力 vs 配置要分開陳述**（CAP-001 語意）：「無全域 hooks」這類句子會因 CLI 升版靜默過時。載入/守護宣稱（CONVENTIONS 5）之外，能力宣稱也須附探測指令與檢查日期。
3. **async:true 的 PreToolUse hook 結構上不可能攔截**：Claude Code 語意 fire-and-forget，exit code 被忽略。任何「hook 防線」宣稱先查註冊處的 async 欄位。
4. **rotate ≠ externalize**：換發金鑰不消除 inline 明文債，只重置洩漏時鐘。externalization（env var 引用）才是結構修復。

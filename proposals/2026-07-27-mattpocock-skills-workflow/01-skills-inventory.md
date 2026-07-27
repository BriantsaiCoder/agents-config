# mattpocock/skills — engineering / productivity 兩資料夾逐項說明

> 來源：`github.com/mattpocock/skills` @ `main`，`pushed_at` 2026-07-23，189,547 stars。
> 本機快照 clone 於 scratchpad，本檔所有引述皆取自 SKILL.md 正本，非影片轉述。

## 0. 這個 repo 的分類軸：誰能觸發

README「Reference」段落把 skill 分成兩類，**這是理解整套設計的關鍵**，不是分類癖：

| 類別 | frontmatter | 誰能叫 | 成本 |
|------|------------|--------|------|
| **User-invoked** | `disable-model-invocation: true` | 只有你打 `/name`；**其他 skill 也叫不到** | 零 context load，但花你的認知負荷（你得記得它存在） |
| **Model-invoked** | 無此欄位 + 富觸發詞 description | 你或 agent 自動 | description 每回合都在 window 內 |

規則（`writing-great-skills` 正本）：**user-invoked skill 可以叫 model-invoked skill，但絕不叫另一個 user-invoked skill。** 這條讓組合關係是一棵樹而非任意圖。

當 user-invoked 多到記不住，解法是 **router skill**（就是 `ask-matt`），不是把它們改成 model-invoked。

影片 M6mYodf0dJM 實測佐證：裝滿 38 個 skill 後 `/context` 只佔 **660 tokens**——因為大多數是 user-invoked，description 不進 window。

總計 **22 個 skill**：engineering 17、productivity 5；其中 user-invoked 13、model-invoked 9。

> **為什麼影片說 38 個？** installer 會列出 repo 內全部 skill，但 Matt 在 M6mYodf0dJM 裡明講它們分兩群：「mattpocock skills 是我認可、夠格公開的那些；其他那些是我現在還在實驗、未來可能刪掉的」。那另外 16 個在 `skills/{in-progress,misc,personal,deprecated}/`，不在本次評估範圍。engineering + productivity = 他自己認證的正式集合。

---

## 1. Engineering（17）

### User-invoked（9）— 編排層

| Skill | 做什麼 | 關鍵設計 |
|-------|--------|---------|
| **`ask-matt`** | router，問「我這情況該用哪條流程」 | 整個 workflow 的正本就寫在這支的 SKILL.md 裡（78 行）。`disable-model-invocation: true`——它是給人用的目錄 |
| **`setup-matt-pocock-skills`** | 每 repo 跑一次的前置設定 | 問三件事：① issue tracker（GitHub / GitLab / 本地 markdown / 自訂）② triage 標籤詞彙 ③ domain docs 佈局（單 context / 多 context）。寫出 `docs/agents/{issue-tracker,domain,triage-labels}.md`，並在 `CLAUDE.md`（若無則 `AGENTS.md`）插入 `## Agent skills` 區塊 |
| **`grill-with-docs`** | 需求拷問 + 同步產 docs | **正本只有 7 行**：「Run a `/grilling` session, using the `/domain-modeling` skill.」——薄殼，實體在兩個 model-invoked skill |
| **`wayfinder`** | 大到一個 session 裝不下的模糊工作，畫成 issue tracker 上的**決策地圖** | v1.1 旗艦。產出「決策而非交付物」。詳見下方專節 |
| **`to-spec`** | 把當前對話壓成 spec，發到 tracker | **不做訪談**，純綜合已談內容。v1.1 從 `to-PRD` 改名（Matt：我們產的本來就不是 PRD 是 spec） |
| **`to-tickets`** | 把 spec 切成 tracer-bullet 票，每票宣告 blocking edges | v1.1 從 `to-issues` 改名。切片規則見下方專節 |
| **`implement`** | 依 spec / 票實作 | **全文 15 行**（含 frontmatter）。Matt 自陳「我差點沒為它做 skill，因為太簡單了」——但因為大家一直問「flow 是什麼」，它需要在鏈上佔一格 |
| **`improve-codebase-architecture`** | 掃全庫找 deepening 機會 → HTML 視覺報告 → 就你挑的那個開拷問 | 定位是保養，不是 feature work。Matt 建議「每幾天跑一次」 |
| **`triage`** | 把 issue / 外部 PR 推過 triage 角色狀態機 | 兩個 category role（bug / enhancement）+ 五個 state role（needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix）。**只處理不是你自己開的 issue**——`to-tickets` 產的票已經 agent-ready，不要 triage |

### Model-invoked（8）— 紀律層

| Skill | 做什麼 | 關鍵設計 |
|-------|--------|---------|
| **`tdd`** | 紅→綠迴圈的參考材料 | **v1.1 重大改動：refactor 被踢出迴圈**，移到 code-review 階段。理由：「別讓實作階段超載」。現在是純 reference（無步驟），可以直接丟給 AFK agent。核心概念 **seam**（測試邊界）——「未經確認的 seam 不寫測試」 |
| **`code-review`** | 兩軸審查 | **Standards 軸**（repo 標準 + Fowler 12 種 code smell 基線）與 **Spec 軸**（是否忠實實作原始 issue）**平行跑兩個 sub-agent**，互不污染 context，且**不合併、不重排**兩軸結果 |
| **`diagnosing-bugs`** | 難 bug / 效能回歸的診斷迴圈 | reproduce → minimise → hypothesise → instrument → fix → regression-test。拒絕在拿到「一行就能重現紅燈的指令」之前開始推論 |
| **`codebase-design`** | deep module 的共用詞彙 | module / interface / depth / seam / adapter / leverage / locality。`tdd` 與 `improve-codebase-architecture` 都講這套話 |
| **`domain-modeling`** | 主動經營專案領域語言 | 維護 `CONTEXT.md` 詞彙表 + `docs/adr/`。挑戰模糊詞、拆解一詞多義 |
| **`prototype`** | 丟棄式原型回答一個設計問題 | 兩分支：**logic**（可互動的 terminal app 推狀態機）/ **UI**（同一 route 上數個差異極大的變體，用 URL search param 切換）。「第一天就是丟棄品」 |
| **`research`** | 背景 agent 查一手來源 | 12 行。強制 primary source（官方文件、原始碼、規格），產出帶引用的 markdown |
| **`resolving-merge-conflicts`** | 逐 hunk 解衝突 | 依雙方的一手來源追意圖；**絕不 `--abort`** |

---

## 2. Productivity（5）

非程式碼專用的通用工作流工具。

| Skill | 類別 | 說明 |
|-------|------|------|
| **`grilling`** | model-invoked | **整個 repo 的靈魂，全文 12 行。** 「不斷面談我直到達成共識、走完決策樹每一分支、每題附上你的建議答案、**一次只問一題**（一次多題令人不知所措）、**能靠探索環境查到的『事實』自己去查，『決策』才問我**、**在我確認達成共識前不要動手**。」後三條都是 v1.1 修的 bug（見 §4） |
| **`grill-me`** | user-invoked | 全文一句：「Run a `/grilling` session.」給沒有 codebase 的場合，無狀態、不留檔 |
| **`handoff`** | user-invoked | 把當前對話壓成交接文件，**存到 OS 暫存目錄而非工作區**。要求：不複述其他 artifact 已有的內容（改引路徑）、附「suggested skills」段、遮罩敏感資訊 |
| **`teach`** | user-invoked | 把當前目錄當成有狀態的教學工作區：`MISSION.md`（為何學）、`RESOURCES.md`、`./reference/*.html`、`./learning-records/*.md`（等同學習版 ADR，用來算 zone of proximal development）、`./lessons/*.html`。核心律：**「永遠不要信任你的參數化知識」** |
| **`writing-great-skills`** | user-invoked | 寫 skill 的參考。核心命題：**skill 存在的目的是從隨機系統中榨出決定性**；根本德性是**可預測性**（每次走同一個 process，而非產出同一份輸出）。含資訊階層三階（in-skill step → in-skill reference → external reference）與 description 撰寫規則 |

`grill-me` / `grill-with-docs` 都只是 `grilling` 的薄殼——差別只在 `grill-with-docs` 額外掛 `domain-modeling` 留下文件足跡。這是「user-invoked 薄殼 + model-invoked 實體」模式的教科書範例。

---

## 3. 兩個要點的細節

### `to-tickets` 的切片規則

- 每片是 **tracer bullet**：窄但**完整**地穿過所有層（schema / API / UI / test）——垂直，不是水平切一層
- 完成後可獨立 demo 或驗證
- **每片剛好塞得進一個全新 context window**
- prefactor 排最前（"make the change easy, then make the easy change"）
- **例外：wide refactor**（改欄名、改共用型別這種 blast radius 掃全庫的機械變更）不套垂直切片，改用 **expand → migrate（依 blast radius 分批，每批一票）→ contract** 三段

### `wayfinder` 的地圖模型

- 地圖 = tracker 上一個標 `wayfinder:map` 的 issue；票 = 它的子 issue，每票 body 就是一個問題，**尺寸抓一個 100K token session**
- 票分四型：**research**（AFK，跑 `/research` 子代理）、**prototype**（HITL）、**grilling**（HITL，預設型）、**task**（做事而非決策，但它靠解鎖一個決策掙得位置）
- **HITL 票 agent 絕不代替人回答**（「一個自問自答的 grilling agent 已經破壞了這條」）
- **fog of war**：不畫你還看不到的東西。判準是**「你現在能不能精準說出這個問題」**，不是「你現在能不能回答」。能精準說出 → 開票（即使被 blocked）；不能 → 寫進地圖的 `Not yet specified`
- **out of scope** 與 fog 不同：fog 只往 destination 聚集，超出 destination 的是 scope 問題，關票並在 `Out of scope` 留一行，**永不畢業**
- **每個 session 只解一張票**（research 票例外）

---

## 4. v1.1 改了什麼（影片 A8mokin_YOs）

| 改動 | 內容 | 為什麼 |
|------|------|--------|
| **改名 ×2** | `to-PRD` → `to-spec`；`to-issues` → `to-tickets` | 產出的本來就不是 PRD 是 spec；issue 偏 GitHub/Linear 語彙，ticket 才中性。**升級要手動刪舊 skill 重裝**，installer 認不出改名 |
| **`grilling` 三修** | ① 補上「一次多題令人不知所措」的**理由**（光下指令模型還是會一次問多題）② 加確認閘「在我確認共識前不要動手」③ **fact / decision 二分**——事實自己查、決策才問人 | ③ 是修「agent 自己拷問自己」的怪 bug（Fable 上特別常見） |
| **`tdd` 去步驟化** | 從「有步驟的流程」改為**純參考材料**，只留紅→綠順序 | 原本要跟你確認要寫哪些測試，不符合「TDD skill 應該能直接丟給 AFK agent」的期待 |
| **refactor 移出 TDD 迴圈** | 不再是 red-green-refactor，只有 red-green；refactor 歸 code-review | 「別讓實作階段超載」 |
| **`code-review` 加 Fowler 基線** | 12 種 code smell，各一句話 | Refactoring 這本書夠老夠常被引用，這些詞**深埋在模型的先驗裡**，只要喚起關鍵詞（message chains / middle man / data clumps），模型就會把詞複述回來並據以行動。「大概 10 行，實測兩週，outrageously useful」 |
| **新增 `wayfinder`** | 見上 | v1.1 主打 |
| **新增 `research` / `implement`** | 支撐 wayfinder 與補上實作那一格 | |
| **`prototype` 改 model-invoked** | 讓 wayfinder 能自己叫它 | |

---

## 5. 兩處來源衝突（已裁決）

1. **wayfinder 的預設地位**。影片 A8mokin_YOs 說「在你想用 grill-with-docs 的場合，改預設用 wayfinder」；但 shipped 的 `ask-matt/SKILL.md` 說 wayfinder「更慢更密，**留給正好是那種情況的時候，絕不用在範圍清楚的 feature 上**」。**以 repo 為準**（2026-07-23 push，晚於影片）——影片那句是作者的個人偏好宣傳，不是 shipped 契約。
2. **M6mYodf0dJM 逐字稿有一句把多 session 分支講反了**（"big enough that it will need multiple agent sessions, then you can skip numbers two and three and go straight into implement"）。同一支影片後段他自己走的是正確版本（「我假裝這會超過一個 session，所以我改叫 to-spec」），且與 `ask-matt` 一致。正確版：**單 session → 直接 `/implement`；多 session → `/to-spec` → `/to-tickets` → 每票各一個 `/implement`**。

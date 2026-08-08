<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | parent: SKILL.md (S5 REVIEW) | last-verified: 2026-08-08 -->

# S5 泛用 reviewer prompt（host 中立）

> 用途：沒有專屬 review agent 的 host（Codex、Copilot 等）在 S5 直接把下方「reviewer prompt」整塊餵給一次審查。
> prompt 本體保持 host 中立、不寫任何專屬 agent 名；host 差異只寫在本檔外圍說明，不混進 prompt。
> 有專屬 review agent 的 host（如 Claude 的 stack 專精 reviewer）改用該 agent。**豁免的是 prompt 區塊本身、以及「怎麼用」中以該區塊為前提的步驟**；本檔其餘各節對它們一樣有約束力。這裡不列舉是哪幾節——這行原本列了兩節，後來新增的節就掉在外面，列舉本身就是那個 bug。

## 怎麼用

1. 把「── reviewer prompt 開始 ──」到「── reviewer prompt 結束 ──」之間整塊複製給審查者，連同本次 diff / PR 一起送。這個 prompt 是一次合併審查，同時承擔 Standards 與 Spec 兩軸的 outcome——[S5-3] 綁的是「Standards 軸 prompt」，本區塊涵蓋該軸，所以五條 baseline 對它成立，不因為沒有軸分割而豁免。
2. 審查者回來後，依「回饋處理」逐條做技術評估，再回 SKILL.md S5 判 EXIT。
3. 無審查者可用時走「UNAVAILABLE 規則」——先 probe、留失敗證據，才可標 UNAVAILABLE；禁默默降級成自審。

## UNAVAILABLE 規則（先於一切）

- 只有在「probe 過審查能力且失敗」並留下失敗證據（指令 + 非 0 exit、或工具回傳錯誤摘錄）後，才可把 S5 標 `UNAVAILABLE`。
- 禁止：沒 probe 就宣稱無審查者、或以自審默默取代獨立審查而不標記。
- 標 `UNAVAILABLE` 時 MUST 一併記錄 probe 指令與失敗理由，讓 S5 gate 可機械複核。

── reviewer prompt 開始 ──

你是本次變更的獨立 code reviewer。只審下方 diff / PR，不重寫程式碼。

**審查優先序（由高到低，高風險先看，逐級往下）**
1. **breaking changes** — 破壞既有呼叫端 / 公開 API / 資料契約 / 相依方的變更。
2. **security** — 注入、憑證外洩、認證與授權破口、不安全反序列化、輸入未於信任邊界驗證。
3. **performance regression** — 新增 N+1、全表掃描、同步阻塞熱路徑、演算法複雜度惡化、非必要重複計算。
4. **correctness** — 邊界條件、null / 空集合、off-by-one、錯誤處理遺漏、狀態機轉換錯誤。
5. **stack 專項** — 只套用 diff 實際命中的技術棧，未命中者跳過：
   - **ASP.NET Core**：DI 生命週期不匹配（singleton 取 scoped）、middleware 順序（auth 在 endpoint 之後）、`CancellationToken` 未往下傳、`HttpClient` 未走 factory、`BackgroundService` 吞例外後靜默停止。
   - **EF Core / Dapper**：N+1、該用 `AsNoTracking` 卻追蹤、transaction 邊界跨越 repository、字串拼接取代參數化。
   - **React**：`useEffect` 缺 cleanup、stale closure、`key` 用陣列 index、context value 每次 render 新物件造成全樹 re-render。
   - **Vue**：解構 `reactive()` 丟失響應性、`watch` 未清理副作用、`computed` 內有副作用、`v-for` 與 `v-if` 同元素。
   - **TypeScript**：`any` 從邊界洩漏進內部、`as` 斷言掩蓋型別不符、公開簽名被放寬（optional 化 / union 加寬）。
   - **Node.js**：unhandled rejection、stream / socket / listener 未清理、同步 I/O 或 CPU 密集運算落在請求熱路徑。

先掃高風險級別，命中就記；同一級別掃完再往下一級。不確定是否為問題時，用 `question:` 提出而非略過。

**每條 finding 用 conventional comment 前綴標示嚴重度 / 型別**
- `issue:` — 必須修，屬 bug / 破壞 / 安全漏洞。
- `suggestion:` — 建議改善，非阻擋。
- `nitpick:` — 微小、可選，通常不阻擋合併。
- `question:` — 我不確定，需要作者澄清意圖或確認假設。

**依 [S5-3]：house over-engineering baseline 五條，逐字適用於本 prompt。** 與上方「優先序」不同，這五條要求你**多報**而非少報：
- **Reinvented Stdlib** — 手刻標準庫或平台已提供的功能 → 指名該 API 取代。
- **Redundant Dependency** — 為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。
- **Unused Local Reuse** — 這個 repo 裡已經有的 helper／type／pattern 被重寫一份。與「同一 diff 內重複」不同，這條看的是 diff 對**既有資產**的重複 → 指名既有符號並改呼叫它。
- **Needless Indirection** — 單一使用點的抽象層、只做轉發的中間層、或為 spec 沒有的需求預留的參數與 hook → 內聯回去，等真的第二個使用點出現再抽。
- **Wrong Altitude** — 抽象層級錯置：實作細節洩漏進高層介面，或高層策略埋進低層工具 → 把該決策移回它該在的層。

五條皆為 judgement call；documented repo standard 覆寫之。

**依 [S5-4]：全部回報、下游過濾。** 命中項一律回報（含 `nitpick:` 與 `question:`），不設字數或條數上限，不在本階段自行丟棄。每條除上述前綴外另標確信度 `確信：高／中／低`。篩選與排序由 main context 於單一 review 軸內另跑一 pass；Standards／Spec 跨軸不合併、不重排。

**每條 finding 格式**：`<前綴> <檔案:行> — <一句描述問題> → <觸發情境：什麼輸入 / 狀態會出錯> → <建議修法>`。
沒有可回報的問題時，明確輸出「無 actionable findings」，不要為湊數而編。

**收斂前自我核對**：若本次改到高扇入共用函式的反模式，不要只看被 diff 標到的行；枚舉全部呼叫端逐一核對同類問題（bot / 單次掃描只覆蓋子集）。

── reviewer prompt 結束 ──

## 五條 baseline 的設計註記（寫給 config 作者，MUST NOT 混進上方 prompt）

- **不含 efficiency 維**：冗餘計算與複雜度惡化由 prompt 內優先序第 3 級（performance regression）承擔，另立一條只會讓同一 finding 在兩處打架。**前提是該 reviewer 真的收到那份優先序**——沒有優先序清單的專屬 reviewer 不適用此推論，必須另行確認 efficiency 有落點。
- **專屬 reviewer 的等價性**（[S5-3] 要求的「等價完整 contract」怎麼算數）：有自己 smell 清單的 host reviewer 若某條已被既有條目承擔，MUST 在該清單就地寫出對應關係，並確認被指派的條目**真的涵蓋原條目的每個 clause**——只寫「由 X 承擔」而 X 的判準漏掉某個子類，等於無聲少給。不必重複同一段文字：reviewer 讀到同一個概念兩次會把它加權兩次。

## 審查者 MUST 記錄（S5 gate 機械複核用）

審查跑完，無論結果如何，MUST 輸出這三欄，缺一不得判 S5 PASS：

| 欄 | 內容 |
|----|------|
| reviewer 型別 | 用哪種審查者（例：host 內建 review agent / 一次性 prompt 審查 / stack 專精 agent）。 |
| agent id | 審查者識別（agent 名或 session id）；無審查者時填 `UNAVAILABLE` 並附 probe 指令 + 失敗理由。 |
| finding 摘要 | 最終 finding 逐條摘要（前綴 + 檔案:行 + 一句）；無問題填「無 actionable findings」。 |

`UNAVAILABLE` 只能在有 probe 失敗證據後填；不得以自審默默頂替。

## 回饋處理（收到 findings 後）

- 每條 finding 給**技術評估**：採納（並修）、或有據 pushback（附技術理由，於對應 thread 回覆）。
- 禁表演式同意——不做無理由的「好的我改」；也不做無理由的「不用改」。
- finding 是 bug → 回 S3；有 stable／valuable seam 時先補 RED，否則用同一 repro 留 before／after 並記錄理由（[INT-2]）。
- 全部 findings 皆已 resolved（修掉或有據駁回並回覆）才可回 SKILL.md S5 判 EXIT。

## S5 EXIT 判準（迴圈的出口）

修 findings 會產生新 diff，新 diff 又要重審——沒有出口的迴圈與沒有迴圈一樣糟。判準如下，**在回饋處理完成之後**才判：

- 兩軸的 finding 經 caller 技術評估後沒有 `issue:` 即 EXIT；仍有 `issue:` **且其處置產生了新 diff**，MUST 再審一輪。用 diff 而不是「改了 code」當判準：規則檔、文件、測試斷言的 repo 沒有「code」可言，照字面判會讓這條在那些 repo 永不觸發，而它們正是最需要它的地方。**級別以 caller 的評估為準，reviewer 自標僅為初值**——出口若是自標 prefix 的函數，等於把 gate 交給單一 agent 自行決定，而「多一輪」的成本全落在 caller 身上，誘因一律指向低標。
- 各軸的終局狀態不由本判準決定，仍是 kernel 定義的四態：`PASS`、`SKIPPED`（附理由）、`UNAVAILABLE`（附 probe）都可續行，`FAIL` 不可。四態直接寫在這裡而不指向出處：它在 kernel 是一條無 ID 的裸 bullet，指過去等於指一個沒有穩定性保證的位置。
- host 有 apply pass（如 Claude 的 `simplify`）時，其 diff 依該 host adapter 一併納入本輪的兩軸範圍，不遞增輪次計數——「不另起一輪」指的是計數，不是豁免審查。該 pass 未產生改動時，MUST 明述 no-op（[T0-2]：沒跑過與跑了沒動，證據不同）。
- 未採納或未解答的 finding（含被 caller 駁回的 `issue:`）MUST 逐條列進 PR body 的 Preflight row 6 並附理由；級別經 caller 改動者一併寫出 reviewer 初值，否則降級後與原生的 `suggestion:` 同形，事後無從分辨。

依據是實測而非推論：`issue:` 級的修復確實會引入新的 `issue:`（2026-08-08，`beebb6b`——補 fail-open 守衛的第一版自己是假綠）。

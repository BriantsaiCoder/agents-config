<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | parent: SKILL.md (S5 REVIEW) | last-verified: 2026-08-09 -->

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

## Reviewer input hygiene（送出審查前）

獨立性由輸入決定，不由 reviewer 的能力決定；輸入一旦污染，這一軸的成本照付而結論不算數。

- MUST 餵原始請求，加上此後每一項人類核准的 scope change 與 spec 修訂。少了核准過的變更，一次合法的 scope 修訂會被讀成 spec gap，回報成 false positive。
- MUST NOT 餵 executor（本次變更的作者，同本檔「五條 baseline 的設計註記」用語）對本次 diff 的辯護、未 persist 的 draft evidence，或既往 findings／缺陷 case study——被 prime 過的審查者只會去看已被點名的類別。已 persist 的 spec／ticket artifact 不在此限，Spec 軸本來就要拿它。
- MUST 標明審查對象的精確 source state（clean tree 記 current HEAD；dirty tree 記 immutable HEAD 加上已過 gitleaks 的完整 dirty review package content hash，定義逐字沿用 `evidence-integrity.md` 的 Fresh final evidence），且 MUST NOT 送出與該 source state 不一致的內容。約束的是一致性不是體積；送出範圍與體積上限依 [S5-2] 的 `dirty-review-package.md`。
- MUST 確認 reviewer 讀的是 source，MUST NOT 以 installed／built copy 取代它。一份過期的 editable install 或建置產物會讓審查跑在它宣稱之外的原始碼上，之後每個結果都失去意義。產物（`bin`／`obj`／快取／editable install）本身不必排除——[S5-2] 的 `dirty-review-package.md` 若把它們列為 candidate，依該檔的大小／binary 規則以 path／size／hash 形式納入即可；本條約束的是它們不得被當成受審的原始碼。

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

先掃高風險級別，命中就記；同一級別掃完再往下一級。只有缺少的資訊會阻擋 correctness／spec verdict 時才用 `question:`，不要把一般不確定性轉成作者待辦。

**每條 finding 用 conventional comment 前綴標示嚴重度 / 型別**
- `issue:` — 必須修，屬 bug / 破壞 / 安全漏洞。
- `suggestion:` — 建議改善，非阻擋。
- `nitpick:` — 僅限有具體維護成本或 repo standard 證據的微小問題；純偏好不報。
- `question:` — 缺少的資訊會阻擋 correctness／spec verdict，需要作者澄清。

**依 [S5-3]：house over-engineering baseline 五條，逐字適用於本 prompt。** 命中且有具體影響與修法時回報：
- **Reinvented Stdlib** — 手刻標準庫或平台已提供的功能 → 指名該 API 取代。
- **Redundant Dependency** — 為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。
- **Unused Local Reuse** — 這個 repo 裡已經有的 helper／type／pattern 被重寫一份。與「同一 diff 內重複」不同，這條看的是 diff 對**既有資產**的重複 → 指名既有符號並改呼叫它。
- **Needless Indirection** — 單一使用點的抽象層、只做轉發的中間層、或為 spec 沒有的需求預留的參數與 hook → 內聯回去，等真的第二個使用點出現再抽。
- **Wrong Altitude** — 抽象層級錯置：實作細節洩漏進高層介面，或高層策略埋進低層工具 → 把該決策移回它該在的層。

五條皆為 judgement call；documented repo standard 覆寫之。

**依 [S5-4]：evidence-first actionable review。** 回報有可重現觸發情境、具體影響與可行修法的 findings；不設字數或條數上限，也不為湊數加入純 style preference。`nitpick:` 必須有 repo standard 或可觀察維護成本；`question:` 只用於缺少資訊會阻擋 verdict。每條另標確信度 `確信：高／中／低`。main context 於單一 review 軸內依 severity／confidence 排序與處理；Standards／Spec 跨軸不合併、不重排。

**每條 finding 格式**：`<前綴> <檔案:行> — <一句描述問題> → <觸發情境：什麼輸入 / 狀態會出錯> → <建議修法>`。
沒有可回報的問題時，明確輸出「無 actionable findings」，不要為湊數而編。

**收斂前自我核對**：若本次改到高扇入共用函式的反模式，不要只看被 diff 標到的行；枚舉全部呼叫端逐一核對同類問題（bot / 單次掃描只覆蓋子集）。

── reviewer prompt 結束 ──

## 五條 baseline 的設計註記（寫給 config 作者，MUST NOT 混進上方 prompt）

- **五條的標題同時是 S5 ledger 的載入證據**：`ledgers.md` 的 Preflight row 6 要求逐字引用其中至少兩條。
  這是為了解決一個實際發生過的失效——PR body 寫「全數套用本檔的 canonical over-engineering contract」，而本檔從未被載入（2026-08-09，[T0-1]）。
  用五條標題而不是在檔頭放一個識別碼：**驗的是 contract 本身，不是旁邊的 token**。引得出標題代表真的讀到這一節；標題被轉述出去等於 contract 被轉述出去，而那正是本檔想要的結果，所以它沒有「洩漏面」這個概念，也不需要隨季度輪替。
  它是**弱訊號不是證明**——決心造假的人照樣抄得到兩個詞。要防的是「宣稱套用了本節卻沒讀過」，不是刻意造假；刻意造假由 review 本身承擔。
  舉證責任在 executor（填 ledger 的人）而非 reviewer：失效模式是 executor 的宣稱，不是 reviewer 的產出。因此這條要求寫在 `ledgers.md` 的 row 6，不進上方 prompt，也不進「審查者 MUST 記錄」三欄。

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

## S5 dispatch and output gates

- [S5-3] 非 SKIPPED 的 Standards 軸 prompt MUST 套用 `references/reviewer-template.md` 的 canonical over-engineering contract；專屬 reviewer 也須收到等價完整 contract。觸發：S5 review。例外：無。驗證：prompt evidence。
- [S5-4] Reviewer output MUST 套用 `references/reviewer-template.md` 的 evidence-first actionable contract 與單軸 aggregate contract；不得用固定字數／條數上限截斷 findings。觸發：任何 review agent prompt。例外：無。驗證：review output evidence。

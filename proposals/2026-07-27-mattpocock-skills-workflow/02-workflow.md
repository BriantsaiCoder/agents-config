# mattpocock/skills 建議的 workflow（正本：`ask-matt/SKILL.md`）

> workflow 的規格正本不在 README、不在影片，而在 `skills/engineering/ask-matt/SKILL.md`（78 行）。
> 兩支影片是它的操作演示（M6mYodf0dJM = 主流程走一遍；A8mokin_YOs = v1.1 差異）。

## 0. 心智模型：一條主流程 + 兩條匝道 + 三個側掛層

```
                      ┌── /triage ────────────┐   （bug/請求堆積：別人開的 issue）
        匝道 ─────────┤                        │
                      └── /wayfinder ─────────┤   （大到裝不下、被霧包住）
                                               ↓
主流程  /grill-with-docs ──→ [單 session?] ──→ /implement ──→（內部叫 /tdd、收尾叫 /code-review）──→ commit
   idea→ship         │              │
                     │              └[多 session] → /to-spec → /to-tickets → 每票各開一個乾淨 session 跑 /implement
                     │
                     └─[問題需要「跑起來才知道」]→ /handoff 出去 → /prototype → /handoff 回來

側掛：  /improve-codebase-architecture（保養，產出 idea 餵回主流程起點）
        /domain-modeling + /codebase-design（詞彙層，跑在所有 skill 底下）
        /handoff（跨 session 橋，雙向）
```

`/diagnosing-bugs` 是第三條匝道（「東西壞了」），它的 post-mortem 會在「發現問題根源是沒有好 seam」時交棒 `/improve-codebase-architecture`。

## 1. 主流程逐步

### 步驟 1：`/grill-with-docs`——用拷問取代 plan mode

**這是整套設計最反直覺也最核心的一步。** Matt 的原話（A8mokin_YOs）：「你不該用 plan mode，你該讓 agent 拷問你。」

為什麼：README 引 The Pragmatic Programmer「沒有人確切知道自己要什麼」。最常見的失敗不是模型笨，是**對齊失敗**。plan mode 是 agent 單向產計畫給你看；grilling 是**雙向逼出你自己都還沒想清楚的分支**。

實際行為（`grilling` 正本）：
- 一次只問一題，等你答完再問下一題
- 每題附上它的建議答案（降低你的負擔）
- **能自己查的「事實」自己去查，只把「決策」丟給你**
- 走完決策樹每個分支
- **在你確認達成共識前不動手**

影片實測：Matt 丟出一句極模糊的指令（「我想把這個 CLI 的內部工具拿掉，只留公開的，這裡雜訊太多」），6 題問完就得到可執行計畫。他說自己平常「大概 20 題左右，看規模」。

有 codebase 用 `/grill-with-docs`（有狀態，會沉澱 `CONTEXT.md` 與 ADR）；沒有 codebase 用 `/grill-me`（無狀態）。

### 步驟 2（分支）：問題能不能純靠講話解決？

若某個問題需要**跑起來才知道答案**（狀態模型對不對、business logic、UI 長相），繞道原型：`/handoff` 出去 → 新 session 跑 `/prototype` → `/handoff` 回來 → 在原討論串引用。

不是回到同一個 session 做——是**開新 session**，因為原 session 要保住 grilling 的思路。

### 步驟 3（分支）：這是不是多 session 的工作？

**判準是 context 容量，不是複雜度。**

- **單 session 塞得下** → 原地 `/implement`
- **塞不下** → `/to-spec`（把整段對話壓成 spec，這是**目的地**）→ `/to-tickets`（切成 tracer-bullet 票，這是**路徑**）→ 每票各開一個**乾淨的 session** 跑 `/implement`

Matt 在影片裡的實際盤算：「我還剩約 100k 預算，要拿掉 10 個 command，這超簡單，直接 implement。」

### 步驟 4：`/implement`

全文就是這幾句：依 spec/票實作 → **在事先講好的 seam 上用 `/tdd`** → 定期跑 typecheck 與單檔測試、最後跑一次全套 → **叫 `/code-review`** → commit 到當前分支。

`/code-review` 兩軸平行 sub-agent 的理由（影片原話）：「在主 agent 裡做審查很糟，因為程式是它自己寫的——agent 對自己剛寫的東西特別不會改，它會覺得『這很棒啊』。開子 agent 才有乾淨的 context window。」

## 2. 三條貫穿全流程的紀律

### (a) Context hygiene / smart zone

- **步驟 1–3 必須待在同一個沒有中斷的 context window**，`/to-tickets` 之前**不 compact、不 clear**——讓 grilling、spec、tickets 建立在同一份思考上
- 上限是 **smart zone**：SOTA 模型約 **120k tokens**（`ask-matt` 正本數字；影片口述 140k）。超過就進入注意力退化，開始出現奇怪的幻覺
- 逼近 smart zone 就別硬撐 → `/handoff` 換新 thread
- **每個 `/implement` 從乾淨 context 開始**，只從票裡拿資訊
- `/handoff` 是**分叉**（開新 session）；`/compact` 是**續行**（同 session）。compact 只在階段之間的刻意斷點用，**絕不在階段中間 compact**

### (b) 兩層文件當共享語言

`CONTEXT.md`（領域詞彙表）+ `docs/adr/`（難以逆轉的決策）。README 的說法：這解決「agent 太囉唆」——agent 被丟進專案後自己猜行話，於是用 20 個字講 1 個字的事。

範例（README 引自 Matt 自己的 repo）：
- **前**：「當一個 course 的 section 裡的 lesson 被『實體化』（也就是在檔案系統裡拿到位置）時有問題」
- **後**：「materialization cascade 有問題」

附帶效益：變數 / 函式 / 檔案命名一致 → codebase 對 agent 更好導航 → **thinking token 也變少**。

### (c) issue tracker 當狀態儲存

spec 與票不留在對話裡，一律發到 tracker（GitHub / GitLab / 本地 markdown / 任何你描述得出來的）。這讓 session 可以隨時扔掉——狀態在 tracker 上，不在 context 裡。`wayfinder` 把這點推到極致：整張決策地圖都是 tracker 上的 issue，因此**可跨 team 協作**。

## 3. 與 GSD / BMAD / Spec-Kit 的立場差異

README 第 17 行講得很直白：那些框架「試圖擁有整個流程，但這麼做的同時奪走了你的控制權，而且讓流程本身的 bug 難以排除」。

這套的反命題是：**小、好改、可組合、與模型無關**。所以 `/implement` 才會只有 15 行——它刻意不寫死步驟，靠 agent 的先驗與 harness 本身。這是設計選擇，不是偷懶。

**代價要講清楚**：整套沒有任何機械閘。沒有 exit code 要求、沒有證據義務、沒有「未通過不得前進」的檢查點。全靠 prose 說服模型 + 人在迴圈裡看著。

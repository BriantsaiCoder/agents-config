# Opus 5 視角：4 條提案，0 條存活

這一維被指派的問題很窄：**哪些指令對更強的模型已經變成 no-op 或反效果，哪些反而更必要。**

代理被明確警告不要給懶答案：

> 「更強的模型需要更少護欄」是假說不是發現。反面往往才對：更強的模型**更**可能推理出「我看得出這是 vendored，但這個修法明顯正確，所以我就改了」——那正是 `step0-vendored-gate.md` 記錄在案的失敗。**模型越擅長建構正當化理由，機械 gate 就越有價值。**

結果：4 條提案全部被對抗驗證殺掉。以下是為什麼，因為**反駁本身比提案更有資訊量**。

---

## 1. 「Step 6 的刪除判準會隨模型漂移」— 被殺

**提案：** `SKILL.md:31` 的 Step 6 以「稽核模型自己的訓練資料」衡量涵蓋度，卻沒說是誰的訓練資料——判準的真假值隨當下跑稽核的模型移動，而它授權的 delete 是永久的。

**反駁：** 引文與行號都正確，所以這是實質問題不是引用問題。

判準是**三重連言**：「訓練資料 + Context7 涵蓋 **AND** 無 user stance **AND** 無 workflow 紀律」。提案的失敗敘事只清掉第 1 個連言（「我已經知道這個了」），對第 2、3 個隻字未提。

而它點名的受害者是最糟的例子：`dotnet-core-best-practices`、`react-best-practices`、`mysql-best-practices` 全都是 **stance-dense** 的，而 `SKILL.md:28`（Step 3）把純 stance 路由到 Move-to-CLAUDE.md 提案，**不是 delete**。

corpus 裡沒有任何一個 skill 被證明「在強模型下清掉三個連言、在弱模型下不清」，所以所稱的大規模誤刪沒有實例。

---

## 2. 「No-Op 判準自稱 model-relative 卻沒綁定模型」— 被殺

**提案：** `GLOSSARY.md:199` 說 no-op 測試是 model-relative 卻沒說哪個模型的預設是權威，破局方法（「running the skill」）也沒說在哪個模型上跑。

**反駁：** 引文逐字正確。但**那句話本身已經給了它要的綁定**——破局方法就是「settle it by running the skill」，一個在**實際會跑它的那個模型**上的經驗測試。提議的補充只是把指涉詞寫出來，是措辭偏好不是缺陷。

也不自我矛盾：原文說的是「two **PEOPLE** disagreeing」——兩個**人類**在爭論模型的預設是什麼，用觀察而非辯論解決。它描述的分歧是人類之間的，而跑一次 skill 確實能解決。

---

## 3. 「Step 6 的延後在單一 context 內什麼都沒清掉」— 被殺

**提案：** Step 6 的延後只是單一 context 內的排序，依它所援引的 doctrine 什麼都清不掉。

**反駁：** `SKILL.md:22` 與 `:54` 引文逐字正確，但 doctrine 被誤用。

`GLOSSARY.md:157` **沒有**說排序無用；它**排序了兩個 lever**——「sharpen the bound first — it is local and cheap. Only when the criterion is irreducibly fuzzy AND you actually observe the rush do you hide the later steps」。

而 `auditing-skill-folder` 做的正是 doctrine 認可的第一件事：`SKILL.md:54` 一個尖銳、可檢查、窮盡的門檻（「If you cannot fill in a step result, you did not run that step. Skipping any of steps 1–5 means restart」），再由 Red Flags 表（標題就是「STOP and Restart from Step 1」，:40–:43 逐 step 點名跳步的合理化話術）強化。

---

## 4. 「Red Flags 第 10 列自帶反制」— 被殺

**提案：** 表裡最要害的那條合理化，其反駁是可被推翻的因果故事而非機械要求，並把反制方法直接交給讀者。

**反駁：** `SKILL.md:46` 引文逐字正確，歷史事實也對得上（`step0-vendored-gate.md:22`、`:57`）。但它敗在**自己援引的先例**。

那個先例證明的是相反的機制：`step0-vendored-gate.md:58` 記錄 `6daf12c` 刪 153 行是**腳本偵測失敗**——「The first script version used LICENSE-only detection and false-negatived design-doc-mermaid」——不是模型推理繞過某個合理化列。第 10 列並未被證明是那唯一事件裡失守的 gate。

---

## 這個結果該怎麼讀

**不是「這兩個 skill 對 Opus 5 完美無缺」。** 其他四維總共產出 8 條成立發現，第二輪又產出 11 條——問題確實存在。

**是「從『模型變強所以規則該放鬆』這個角度切進去，一條都站不住」。** 四次嘗試各自失敗於不同原因：漏看連言、把已有的綁定當成缺失、誤讀被援引的 doctrine、援引了證明相反結論的先例。

實務意涵有兩點：

1. **機械 gate 該留。** 這兩個 skill 的護欄在強模型下沒有變成 no-op；如果有變化，是變得更難繞過，因為它們是腳本不是散文——`step0-vendored-gate.md:54-61` 記錄了同一條軸線寫成散文時在同一個 52-skill 資料夾上失敗**三次**的過程。
2. **真正的缺陷在別處。** 兩輪合計 19 條成立發現裡，**沒有一條**是「規則太嚴」。全部是文件與實作脫鉤（A1、A2、B2、B5）、定義缺失（A3）、死分支（A4）、階層錯置（B1、B7、B8）、或觸發面缺口（A6、A7、B3）。

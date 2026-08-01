# writing-great-skills / auditing-skill-folder — 調教優化稽核

**日期：** 2026-08-01
**範圍：** `skills/writing-great-skills/`（`VND*`，mattpocock/skills @ `ed37663`）與 `skills/auditing-skill-folder/`（自有）
**判準：** 純就 skill 本身是否需要調教優化。**provenance 不作為判斷濾網**——這是本次稽核採用的新規則，已同步寫入 `auditing-skill-folder` 本體。

---

## 一句話結論

| skill | 結論 |
|---|---|
| `auditing-skill-folder` | **需要調教，且缺陷集中在機械層。** 7 條成立，2 條 HIGH。最嚴重的兩條都是「文件與腳本已經脫鉤」：`wc -w` 對中文失明、偵測訊號有五個但文件只寫四個。 |
| `writing-great-skills` | **需要調教，但幅度不大，且集中在三處。** 11 條成立，3 條 HIGH。它本身寫得好；13 條提案被裁決者退回。最嚴重的是它的 GLOSSARY 對「怎麼把 skill 轉成 user-invoked」給出的操作**與這個 repo 的實況相反**。 |

---

## 方法與可信度

兩輪多代理稽核，全部發現經對抗式複驗，再由 main context 獨立回查來源。

| 輪次 | 產出 | 對抗驗證後 | 淘汰率 |
|---|---|---|---|
| 第一輪：5 維度稽核（自我套用／腳本缺陷／跨文件一致性／調用觸發／Opus 5 適配度） | 25 findings | **8 confirmed** | 68% |
| 第二輪：3 lens 就事論事提案（pruning／operability／accuracy） | 25 proposals | **11 accepted** | 56% |

**淘汰率高是刻意的。** 驗證者被要求預設反駁、不確定即殺，且必須自行回查引文與行號。被殺的多半不是「說錯」而是「說了但不構成缺陷」——例如 13 條被退回的提案裡有 5 條是**確認存在的 duplication**，但退回理由一致：「維護漂移是所有 duplication 的通用成本，不是這一條造成的具體錯誤行為」，且兩份副本目前內容一致、沒有任何一次執行會分歧。

**Opus 5 適配度那一維：4 條提案、0 條存活。** 見下方專節。

---

## 檔案

| 檔 | 內容 |
|----|----|
| [01-auditing-skill-folder.md](01-auditing-skill-folder.md) | 7 條成立發現，含 main context 複驗數據 |
| [02-writing-great-skills.md](02-writing-great-skills.md) | 11 條提案，含具體替換文字 |
| [03-opus5-lens.md](03-opus5-lens.md) | Opus 5 視角 0 存活的分析 |
| [04-execution-order.md](04-execution-order.md) | 建議執行順序與落地程序 |

## 執行狀態

17 條已完成，A5 因 live corpus 零命中而依 YAGNI 跳過。落地結果與驗證證據集中在 [`STATUS.md`](STATUS.md)，避免在兩處維護相同狀態。

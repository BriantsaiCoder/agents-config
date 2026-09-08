# Settlement decision guide

在 `SKILL.md` Step 1 有知識保存建議，或需要分類例、持久化格式、摘要範例時讀取。

## 目標分類

| 目標 | 適用知識 | 例子 |
|---|---|---|
| Cookbook（隨 repo） | 專案特定、工具看不出的陷阱或業務規則 | 事件順序、DI lifetime、感測器離線門檻 |
| Memory | 使用者明示要保存的跨專案 feedback | 偏好的確認粒度 |
| Workflow | 流程缺口本身造成錯誤 | 某階段缺少 completion check |

Cookbook 的位置與格式以目前 host 的 `rules/cookbook.md` 為準。先搜尋既有 `docs/cookbook/**/*.md`；有合適檔就增量更新，沒有才依核准 path 建立。建議格式：問題 → 根因 → 正確做法／錯誤做法。

## 知識範圍與升格

- 建議保存時，附適用 repo／版本／條件、支持證據與已知例外；版本限定的 workaround 不得寫成通用規則。
- 單一專案的觀察預設留在該專案。只有跨情境證據支持，或使用者明示為通用偏好，才建議升格為跨專案知識；重複次數本身不等於普遍適用。
- 新證據推翻舊結論時，指明被取代的條目與原因，優先修訂或取代，避免矛盾規則並存。實際寫入沿用 `SKILL.md` Step 2 與 host memory contract；append-only memory 以授權的修訂 note 指向舊條目，不直接改寫底層記憶。
- 未授權時只列待授權建議，不自動觀察 session、寫入記憶或生成 skills；不以未校準的數值 confidence 代替證據。

方法參考：[ECC continuous-learning-v2](https://github.com/affaan-m/ECC/blob/5064474d4d762dc9640234a41617cccb79185cec/skills/continuous-learning-v2/SKILL.md) 的 project scope／promotion 思路；不引入背景 observer 或自動升格。

## 常見裁決

- Signature 漂移：compiler 能守，補 type 或 build gate。
- 計算結果回歸：test 能守，補最小 regression test。
- 可由 import／caller 搜尋得到：執行 `deps-check`，不另寫 cookbook。
- Race、event ordering、reflection 或外部 library 的環境差異：mechanical guard 不足時，考慮 cookbook。
- Architecture choice 的 why：若程式看不出且會被反覆推翻，考慮 ADR／cookbook。

## 摘要範例

三者皆不需要時，只用一句，例如：「無需另存知識；新增的 regression test 已守住這個行為。」有需展開的項目才選用下列相關列，不強制標題或列出無需動作的項目。

```text
📝 錯誤學習評估：
- Cookbook: 不需要／待授權／已寫入 <path>（原因）
- Memory: 不需要／待授權／已寫入 <path>（原因）
- Workflow: 不需要／待授權／已寫入 <path>（原因）
- 替代 guard: <type／lint／test／deps-check／無需動作>
```

若已授權寫入，只報實際落盤項；不得把建議狀態描述成已寫入。

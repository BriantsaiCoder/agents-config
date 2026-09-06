# Settlement decision guide

只在 `SKILL.md` Step 1 需要分類例、持久化格式或摘要範例時讀取。

## 目標分類

| 目標 | 適用知識 | 例子 |
|---|---|---|
| Cookbook（隨 repo） | 專案特定、工具看不出的陷阱或業務規則 | 事件順序、DI lifetime、感測器離線門檻 |
| Memory | 使用者明示要保存的跨專案 feedback | 偏好的確認粒度 |
| Workflow | 流程缺口本身造成錯誤 | 某階段缺少 completion check |

Cookbook 的位置與格式以目前 host 的 `rules/cookbook.md` 為準。先搜尋既有 `docs/cookbook/**/*.md`；有合適檔就增量更新，沒有才依核准 path 建立。建議格式：問題 → 根因 → 正確做法／錯誤做法。

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

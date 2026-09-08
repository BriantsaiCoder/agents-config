# Delegation contract

考慮 delegation 或 downstream skill 指示使用 agent 時載入。

Delegation 的**約束**不變，改變的只有**誰決定**。Host adapter 明定的 eligibility 例外以外，任何 delegation 機制只在工作可獨立平行且預期能實質改善品質或 wall-clock time 時使用；是否委派、何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定並直接執行，MUST NOT 為此停下發問。不得設定 user-authored 的固定數量、併發、累計或 S 階段限制；host/runtime 可用容量仍是技術上限。

委派訊息 MUST 交代目標與用途（為誰、輸出要讓什麼成立）、working directory／可修改範圍、已決事項與限制、必要文件（已落檔者給路徑）、驗收方式；必要背景 MUST 先摘要進訊息，不靠子代理自行推斷。

## Context 缺口回報

- 缺少會影響結論的 context 時，回報已查範圍、具體缺口、受影響的判斷，以及下一個最小查證動作。
- 能在授權範圍內自行查證時直接續查，依新發現的術語與缺口縮小搜尋；無法取得時，只把對應結論保留為未確認，續做不相依工作。
- 不以固定搜尋輪數、檔案數或 relevance 分數判定 context 足夠，也不因缺口回報自動擴張授權或新增 delegation。

方法參考：[ECC iterative-retrieval](https://github.com/affaan-m/ECC/blob/5064474d4d762dc9640234a41617cccb79185cec/skills/iterative-retrieval/SKILL.md)；僅吸收依缺口續查與回報的方式。

## Eligibility 與約束

Eligibility 例外只有 [host adapter](host-adapters.md) 明定的 Codex [Codex conditional implementation routing](host-adapters.md#codex)，允許 bounded scope 的 large/noisy context 明確受益於 isolation 時委派，以及 Claude [Claude conditional implementation routing](host-adapters.md#claude)，允許已完整規範、驗收可機械判定且預期不需回頭問設計的 packet 交由 implementer 執行。Codex context-isolation 例外不適用其他 host，Claude packet 例外不適用 Codex／Copilot；兩者都不放寬 sequencing、non-overlap ownership、authorization、parent evidence verification 或 read-only S5 review，same-work recursion is forbidden。

無條件約束（不因任何授權而放寬）：序列相依工作 MUST 序列化或合併；併發 subagent 的寫入 ownership MUST 不重疊；main context MUST 重驗其回報，subagent 回報不是完成證據。無條件約束不在可授權範圍內，即使取得授權也 MUST NOT 執行衝突工作。

S5 Standards／Spec outcomes 與 downstream research coverage 在各自 gate 命中時仍須完成；如使用 review agents，MUST 為 read-only，數量與批次由 AI 決定。下游 skill 的固定 spawn 時機／數量一律由本條覆寫為 advisory choreography；coverage、outcome 與 independence requirements 保留。

MUST NOT 用 delegation 迴避 S2 授權或 [T0-8] plan gate；條件模糊時依 [T0-5] 停下發問。

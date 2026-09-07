# Delegation contract

考慮 delegation 或 downstream skill 指示使用 agent 時載入。

Delegation 的**約束**不變，改變的只有**誰決定**。Codex 例外以外，任何 delegation 機制只在工作可獨立平行且預期能實質改善品質或 wall-clock time 時使用；是否委派、何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定並直接執行，MUST NOT 為此停下發問。不得設定 user-authored 的固定數量、併發、累計或 S 階段限制；host/runtime 可用容量仍是技術上限。

Codex 的唯一 eligibility 例外是 [host adapter](host-adapters.md#codex) 定義的 Astra→Sol serial implementation routing；已授權的 serial work 依 adapter 自動交由 implementer 執行。此例外不適用 Claude／Copilot，也不放寬 sequencing、non-overlap ownership、authorization、parent evidence verification 或 read-only S5 review；same-work recursion is forbidden。

無條件約束（不因任何授權而放寬）：序列相依工作 MUST 序列化或合併；併發 subagent 的寫入 ownership MUST 不重疊；main context MUST 重驗其回報，subagent 回報不是完成證據。無條件約束不在可授權範圍內，即使取得授權也 MUST NOT 執行衝突工作。

S5 Standards／Spec outcomes 與 downstream research coverage 在各自 gate 命中時仍須完成；如使用 review agents，MUST 為 read-only，數量與批次由 AI 決定。下游 skill 的固定 spawn 時機／數量一律由本條覆寫為 advisory choreography；coverage、outcome 與 independence requirements 保留。

MUST NOT 用 delegation 迴避 S2 授權或 [T0-8] plan gate；條件模糊時依 [T0-5] 停下發問。

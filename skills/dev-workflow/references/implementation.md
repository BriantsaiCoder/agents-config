# Implementation details

Kernel 依 [INT-2] 選定 stable／valuable seam 並進入 [tdd](../../tdd/SKILL.md) cycle 時載入；同版已讀可重用。[INT-9] 覆寫下游 seam／refactor 程序。

既有 public behavior seam 視為已確認；只有改變 public contract／架構／scope 的新 seam 依 S2 確認。每輪 GREEN 後可做一次不改 behavior 的 micro-refactor，且 MUST 立即重跑當輪 test。

wide／structural refactor 留到獨立核准 change 或 S5 finding，RED 時不得 refactor。保留 RED／GREEN／retest evidence；完成後回 S4→S5→S6。

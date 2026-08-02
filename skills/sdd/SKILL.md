---
name: sdd
description: 適用於單一 target file、單一行為、≤3 個 actionable tasks 且未命中風險 gate 的小功能、明確 bug 或局部重構；需求模糊、跨模組、public API、schema 或 deployment pipeline 改走 dev-workflow。
---

# sdd — 輕量規格驅動開發

本 skill 只定義 proposal → implementation → optional archive 三階段；routing、authorization、risk、RED→GREEN 與 S4–S6 一律以 [dev-workflow](../dev-workflow/SKILL.md) 為準。

## ENTER

- 收到可執行的需求且尚未核准 plan → 進階段一。
- 使用者明確核准 session plan（引用原句）→ 進階段二。
- 使用者明確要求持久化／歸檔，且 repo 中有 `sdd/<slug>/` → 進階段三。

若需求有多種合理解讀且會改檔，依 [T0-5] 列出假設與影響後發問。Slug 使用英文小寫與連字號。

## 階段一：提案（ENTER：有需求、尚無核准 plan）

1. 在 session proposal artifact 記錄 slug、類型、為何做、行為、影響檔案與情境式驗收條件。
2. 拆成 ≤3 個 host todo，每項 ≤1 小時；超過 3 項即退出 sdd，回 dev-workflow 重新 route。
3. 呈現完整 plan 後停止並等待核准。完成條件：可引用 proposal 與使用者核准原句。

核准前不寫 repo。核准後僅於使用者／repo 要求或有跨 session、交接、稽核價值時，持久化為 `sdd/<slug>/proposal.md` 與 `tasks.md`。

## 階段二：實作（ENTER：session plan artifact + 使用者核准原句）

1. 讀核准的 session plan；若已持久化，再核對 `proposal.md` 與 `tasks.md`。
2. 逐項實作並優先重用現有能力；通過該項驗收後才更新 todo 或 `- [x]`。
3. 規格不足或方向偏離時停止並請使用者裁決。
4. 全部完成後通過 dev-workflow S4–S6，或逐項記錄 `SKIPPED` 理由，再交付驗收。

## 階段三：選用歸檔（ENTER：使用者要求歸檔且 `sdd/<slug>/` 存在）

1. 確認 `tasks.md` 每項皆為 `- [x]`；未完成就停止並回報。
2. 用 `date +%F` 取得日期，再以 `git mv` 移至 `sdd/archive/<日期>-<slug>/`。
3. 回報新路徑與一句摘要。

若沒有持久化產物，本階段標 `SKIPPED`，不補造檔案。

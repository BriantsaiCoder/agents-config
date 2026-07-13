# 03 — 規範候選（最終版，ID 已重編去衝突）

> **讀者是 AI 模型**。Workflow 各 finder 提出的 norm candidates 原始 ID 有衝突（兩個 C14、SYNC-1/CONV-6a 等暫名）；本檔為重編後正本。全部沿用五要素格式（ID＋RFC2119＋觸發＋例外＋驗證）。「驗證：」欄已按本檔第 17 條自標 [probe:] 或 [manual:]——自舉示範。

## tier0 新增（1 條）

**[T0-10]** plugin / hook / host 機制常駐注入的 prose 指令，位階固定為裁決鏈「被 invoke skill 的程序步驟」同級（即低於 tier0 / repo 協作檔 / user 明示）；注入 prose MUST NOT 被解讀為放鬆 tier0 的依據。觸發：注入指令與任一 tier0 條文衝突（如「never stall」vs [T0-5]、「code first」vs [T0-8]）。例外：user 當下明示採納該注入指令。驗證：裁決鏈條文含「注入 prose」槽位 [probe:t0-chain-slot]。

## tier1 新增（1 條）

**[T1-8]** 任何跨 host 同構部署資產（instructions／agents／plugins／hooks／memory／prompts）MUST 有單一正本＋生成管線＋GENERATED banner，或在 parity 矩陣明記 UNAVAILABLE＋理由；MUST NOT 兩側手寫平行維護。觸發：新增第二份同語意 host 檔。例外：host 專屬且無對等物（記錄於 hosts/*-delta.md）。驗證：conformance parity 節對該資產類有三 host 條目 [probe:parity-matrix]。

## CONVENTIONS 修訂（2 條）

- **修訂 4**：常駐層（core/、CLAUDE.md、部署檔）引用檔案 MUST 用完整路徑（如 `~/.agents/CONVENTIONS.md`），bare filename 只准在同目錄 README。理由：META-3 可發現性斷鏈。
- **修訂 11**：驗證式從單一 `-name '*.bak*'` 改為 `\( -name '*.bak*' -o -name '*.backup*' \)`。理由：SYNC-F8 假綠實證。

## CONVENTIONS 新增（14–19）

**14 · host 能力宣稱附版本與日期**：任何「host X 會／不會 Y」的能力宣稱 MUST 附 CLI 版本號＋實測日期＋探針指令；host CLI 升版後引用該宣稱前 MUST 重跑探針。觸發：書寫或引用 host 行為事實。例外：官方文件有明確語意保證者（附連結）。驗證：grep 能力宣稱行含版本號 pattern [manual:host 升版時]。（根因案例：SKILL-01「截斷 2–6 字元」stale 散布 9 處）

**15 · FP 載體須進 context**：fingerprint codeword MUST 以會進 model context 的散文行承載；MUST NOT 僅存於 HTML comment 或其他會被 host 剝離的載體。觸發：新增或搬移 FP。例外：無。驗證：三家活體探針各命中一次 [probe:fp-live-x3]。（根因案例：INJ-2 Claude host 剝離 comment）

**16 · 三家 parity 矩陣**：新增或修改任何機械守護（hook／guard／permission／audit／drift-check）時 MUST 同時記錄三主機 parity 狀態（已實作／等效替代／UNAVAILABLE＋理由），並在 conformance.sh 為每家加探針或 UNAVAILABLE 標記。觸發：diff 命中 hooks/、*permissions*、guard-*.sh、audit-*.sh。例外：平台原生不支援（明記 UNAVAILABLE）。驗證：conformance parity 節三 host 條目齊備 [probe:parity-matrix]。（根因：GAP-3，≥8 條 findings 同源）

**17 · probe registry**：core/ 與 rules/ 每條規則行的「驗證：」欄 MUST 標注 `[probe:<id>]`（對應 conformance.sh 同 id 探針函式）或 `[manual:<重驗頻率>]`。觸發：新增或修改規則行。例外：純判斷類規則（標 [manual]）。驗證：lint 檢查每條驗證欄含兩種標注之一、每個 probe id 在 conformance.sh 有同名函式 [probe:registry-lint]。（根因：GAP-4，24 條驗證欄 vs 10 探針脫鉤）

**18 · 共用層禁 host 專屬沉澱目標**：共用層（skills/、core/）的任何步驟 MUST NOT 以單一 host 專屬儲存（Claude auto-memory、~/.codex/memories、memory MCP）為必要沉澱目標；跨專案知識正本 MUST 落 `~/.agents/memory/`（git 版控），host 原生機制僅為快取。觸發：skill 文本出現 host 專屬儲存且無三家映射。例外：hosts/*-delta.md 內的 host 專屬補充。驗證：`grep -rn 'auto memory' ~/.agents/skills/` 每一命中同檔存在 host adapters 映射段 [probe:mem-canonical]。（根因：GAP-1）

**19 · 行為級 plugin pin**：三家共同依賴的行為級 plugin（現況：ponytail、superpowers）MUST 在 ~/.agents/ manifest pin 來源 revision；三家安裝 revision 與 manifest 不一致即 drift。觸發：任一家更新上列 plugin。例外：host 專屬 plugin 不入 manifest。驗證：agents-sync --check 比對三家 revision == manifest [probe:plugin-pin]。（根因：GAP-5）

## host delta 新增（1 條）

**codex-delta · trust 邊界**：Codex `[projects]` trust_level="trusted" MUST NOT 授予容器級路徑（`/`、$HOME、~/Downloads、/private/tmp）；只可授予具體專案根。觸發：config.toml 新增 trusted 條目。例外：無。驗證：conformance 探針掃容器路徑 trusted = 0 [probe:codex-trust]。（根因：GAP-2）

## lint 新增（agents-sync；3 條）

- **lint8**：skill description 常駐注入總量預算（Codex skills_instructions 實測 ~30KB 為基線，超額 FAIL）。（SKILL-02）
- **lint9**：FP 存在性＋載體形態（每 source 檔恰一句、且為散文行非 comment）。（INJ-2、CONVENTIONS 15 的機械面）
- **lint10**：`~/.claude/CLAUDE.md` 反引號名稱引用存在性（比照 lint1b 擴大掃描面）。（INJ-3）

## 治理義務（GOV；落 proposals/README 與 CONVENTIONS 附錄，5 條）

- **GOV-1 · STATUS 總表**：`proposals/STATUS.md` 一提案一行（狀態 enum：PROPOSAL／APPROVED／EXECUTED／PARTIAL／SUPERSEDED＋執行紀錄連結）；提案狀態變更 MUST 同步該表，勿改舊檔內文。（META-2）
- **GOV-2 · 新 skill 上線 checklist**：新增 skill MUST 三步——routing.md 點名或明示「不點名（description 路由）」、`agents-sync --check` 綠、skill-index 再生。（META-5）
- **GOV-3 · 審計持久化**：任何審計的 confirmed findings MUST 在同 session 落 `proposals/<date>-<slug>/`；只存 transcript 視同遺失。（F-R4 實證：07-11 六條 P1 遺失、一條已無法重現）
- **GOV-4 · 帶外事項配探針**：交給用戶帶外的事項 MUST 附機械探針＋逾期升級規則（下次審計探針 FAIL 即升一級）。（F-R2 實證：stitch source 逾期 2 天無人知）
- **GOV-5 · host 事實重驗排程**：core/ 內嵌的 host 版本事實與 live 狀態宣稱，MUST 於 host CLI 升版或每季（FP 年季輪替時）重驗；FP 年季（現 2026Q3）到期 MUST 輪替並重跑三家活體探針。（META-4、SKILL-01）

## 原始暫名 → 最終 ID 對照

| 原始暫名 | 最終 |
|----------|------|
| SYNC-1（乾淨工作區部署） | 併入 02 Batch C1（實作，非規範） |
| CONV-6a（FP 禁 comment-only） | CONVENTIONS 15 |
| C14（hooks symlink 正本制） | [T1-8]（一般化） |
| C14'（host 能力宣稱附版本） | CONVENTIONS 14 |
| lint rule 8 / 9 | lint8 / lint9 |
| T1-8（多 host 同構資產） | [T1-8] |
| T0-10（注入 prose 裁決） | [T0-10] |
| GOV-1 / GOV-2 | GOV-1 / GOV-2 |
| OOB-1 | GOV-4 |
| AUD-1 | GOV-3 |
| C-mem / C-trust / C-parity / C-probe / C-plugin | CONVENTIONS 18 / codex-delta trust / CONVENTIONS 16 / CONVENTIONS 17 / CONVENTIONS 19 |
| CONVENTIONS 11 驗證式修訂 | 修訂 11 |
| CONVENTIONS 4a | 修訂 4 |
| T0-3 驗證欄修訂 | 併入 02 Batch B2（probe registry 標注時一併改寫，明記唯一有效防線＝server 端 branch protection） |

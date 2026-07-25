# DCT_data_import 整庫優化審查報告

> 2026-07-16 · 基準 commit `055e54f` · 54-agent workflow(8 維度 finder + 完整性稽核 + 逐條對抗驗證)
> 原始 findings 48 條 → 去重 42 → 補漏 +3 → 驗證成立 **43**、推翻 2

## HIGH（1 條）

### ImportFailPinLog 的 fail_pin_rate_list NULL 判定誤用 Rows[0] 而非 Rows[i]:整檔 dut/site 的 NULL 決策綁在第一列

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:936`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high

**問題**：順帶發現(超出效能維度但證據明確,CONCERNS.md 未載):fail_pin_rate_list 逐列 INSERT 迴圈以 i 走訪所有列,但「空/NA → NULL」判斷讀的是 Rows[0][j],寫入值卻取 Rows[i][j]。fail_pin_rate_list 一個 DUT 一列、必然多列。兩個失敗模式:(a) 第 0 列 dut/site 為空或 NA → 後續所有列的 dut/site 一律寫 NULL,即使實際有值——靜默資料遺失;(b) 第 0 列有值、第 k 列為 NA → 走 else 分支,ConvertEmptyToDefaultString 後把字串 "NA" 綁進 int 欄位(dct.sql:118,120 `dut int null` / `site int null`),MySQL strict mode 下整檔匯入失敗判 Result 3。同型寫法在 tester_status(:662)因只匯 row 0(i>0 即 break)而無害、tester_production_analysis(:760)因解析端只產一列僅 latent,唯獨此處是活的。

**證據**：
```
for (int i = 0; i < content.Fail_pin_rate_list.Rows.Count; i++)
{ ...
  if (doubleTypeColumn.Contains(columnName) && (content.Fail_pin_rate_list.Rows[0][j].ToString().Trim() == string.Empty || content.Fail_pin_rate_list.Rows[0][j].ToString().Trim() == "NA"))
  { values += "NULL"; }
  else
  { values += AddInsertParameter(failPinRateListParameters, ref failPinRateListParameterIndex, "fail_pin_rate_list", ConvertEmptyToDefaultString(content.Fail_pin_rate_list.Rows[i][j].ToString())); }
```

**建議**：把判定改讀當前列:`content.Fail_pin_rate_list.Rows[i][j]`(讀一次存局部變數,順帶消掉同 cell 的兩次 ToString().Trim())。先補 failing regression test:構造第 0 列 dut 有值、第 1 列 dut="NA" 的 FailPinLogContentFormat,以 characterization 子類攔 ExecuteInsert 斷言第 1 列產出 NULL 而非參數 "NA"。tester_production_analysis(:760)可同 PR 順手對齊(行為現階段等價),tester_status 保持不動。

**驗證註記**：親自核實全部證據:FileProcess.cs:936 確以 Rows[0][j] 做 NULL 判定、:942 以 Rows[i][j] 取值,迴圈走訪所有列;dut/site 欄名為小寫(FileContentFormat.cs:229,231)與 doubleTypeColumn 完全匹配,分支為活的;dct.sql 確為 dut/site int null;ConvertEmptyToDefaultString 對 "NA" 原樣回傳(:1416),strict mode 綁進 int 欄會失敗,鏈路終點確為 FailPin.cs:108 的 Result 3。兩對照點也屬實:tester_status:654 的 i>0 break 使同型寫法無害;Tester.cs:234-240 解析端加一列即 return,:760 僅 latent。CONCERNS.md 全文無此項,非已知債;修法不違反任何硬性約束,且僅在第 0 列與第 i 列空值狀態不一致(即出錯情境)時改變行為,一致檔案行為不變。唯一小瑕疵:「必然多列」略為過強(單 DUT 檔可能存在),但不影響結論。

---

## MEDIUM（21 條）

### FileReadRawData 每次解析都 new TsmcIeda()，建構子無條件從 FTP 重新下載整份 lot_mapping.csv

- **位置**：`DCT_data_import/ReadAndImport/ImportData.cs:446`
- **維度**：io-ftp ｜ **工作量**：M ｜ 驗證信心：high（原評 high，驗證後校準）

**問題**：FileReadRawData（RawData 與 MultiSpecRawData 共用的解析函式）在每次解析一個 rawdata CSV 時 new 一個 TsmcIeda，而 TsmcIeda 建構子（TsmcIeda.cs:18-22）無條件呼叫 GetLotMapping()，以 ReadBig5File(ftpserver, reader => reader.ReadToEnd())（TsmcIeda.cs:232）從 FTP 完整下載 TSMC_DATA/LotID/lot_mapping.csv。後續使用（GetNetNameList）卻只在 Customer == "TSMC"（ImportData.cs:448）才發生——即非 TSMC 的每一個 rawdata / 每一個 MultiSpec site 檔解析，都白付一次整檔 FTP RETR；MultiSpec 一個 8-site lot 會重複下載同一 mapping 檔 8 次。此下載還落在 readTakeTime 的碼錶區間內，污染 check_log 的讀檔耗時統計；FTP 暫時性故障時每次解析都額外噴一筆 error log。

**證據**：
```
ImportData.cs:446 `TsmcIeda tsmcIeda = new TsmcIeda();`；TsmcIeda.cs:18-22 `public TsmcIeda() { GetLotMapping(); }`；TsmcIeda.cs:232 `string lines = ReadBig5File(ftpserver, reader => reader.ReadToEnd());`
```

**建議**：最小改法（單檔）：把 GetLotMapping() 從建構子移到 GetNetNameList 首次使用時 lazy-load（如 private DataTable 屬性 + null 檢查），非 TSMC lot 即零下載。進一步（跨檔）：RunTesterImportBatch 每輪建一個 TsmcIeda 並注入 RawData/MultiSpecRawData 重用（已有 TsmcIeda(IImportFileSource) test seam 可沿用注入模式），把每輪下載次數收斂到至多 1 次。不動 ImportResult 語意。

**驗證註記**：全部證據逐行核實成立：ImportData.cs:446 在 FileReadRawData（RawData.cs:45 與 MultiSpecRawData.cs:169 共用）內 new TsmcIeda()；TsmcIeda.cs:18-29 兩個建構子皆無條件呼叫 GetLotMapping()；TsmcIeda.cs:232 以 ReadToEnd 整檔下載 lot_mapping.csv（FTP 模式為每次一個 FtpWebRequest RETR，且發生在 rawdata 串流仍開啟的 ReadBig5File callback 內）；mapping 只在 Customer=="TSMC"（ImportData.cs:448-451）才被 GetNetNameList 使用；MultiSpec 每 site 檔各下載一次；下載落在 readTakeTime 碼錶內（RawData.cs:43-48、MultiSpecRawData.cs:167-172）污染 check_log；GetLotMapping catch 每次失敗噴一筆 error log。不與 CONCERNS.md 既載債重複（S2/D4 是別的議題），建議不違反任何硬性約束，TsmcIeda(IImportFileSource) seam 確實存在。惟 severity 應降為 medium：GetLotMapping 吞掉所有例外，匯入結果與資料正確性完全不受影響，實害是熱路徑上的白費 FTP 往返、readTakeTime 統計污染與 log 噪音，屬效能/可觀測性缺陷非正確性缺陷。另一實作注意點：FileReadIeda（TsmcIeda.cs:128）也消費 _lotMappingDt，lazy-load 必須做在 mapping 存取點而非只在 GetNetNameList，否則會被 ParserCharacterizationTests.cs:190 的既有測試抓到。

---

### 匯入 commit 成功後的 CompleteSuccess 清理與匯入共用同一 try：FTP 刪檔暫時性失敗被誤判為匯入失敗（Result 3 + 搬錯誤區），MultiSpec 路徑甚至逸出成 Result 0

- **位置**：`DCT_data_import/ReadAndImport/RawData.cs:124`
- **維度**：io-ftp ｜ **工作量**：M ｜ 驗證信心：high

**問題**：RawData（同構模式亦見 Tester/FailPin/RecoveryRate/UiStatus/EverySiteItem）在 uow.Commit() 成功後才呼叫 CompleteSuccess(ftpFilePath)（FTP DeleteFile），但它位在外層 catch-all 的 try 內：FTP 刪檔一個暫時性 WebException 就走 catch → MoveToError + 回 ImportResult(3, "Exception error occurred during import.")——實際上資料已 commit 進 DB。後果：finalize 記失敗並觸發寄信誤報，來源檔被搬到錯誤區，維運重投會撞 IsDBKeyExistInDB 再回 3。MultiSpecRawData.cs:253-258 更糟：post-commit 的 CompleteSuccess 迴圈完全在 try/catch 之外，例外直接逸出到 Program.cs 的 Raw Data catch 被包成 ImportResult(0)（『檔案不存在』語意），db_key 續留 pending、下一輪重跑再撞 duplicate。

**證據**：
```
RawData.cs:124 `deleteStatus = CompleteSuccess(ftpFilePath);`（位於 :38 起的 try 內）；catch（:136-142）`MoveToError(ftpFilePath, errorPath); return new ImportResult(3, "Exception error occurred during import.");`；MultiSpecRawData.cs:253-258 post-commit `CompleteSuccess(filePath)` 無任何 try 包覆
```

**建議**：把 commit 後的檔案副作用移出匯入 try、獨立 try/catch：清理失敗只 WriteErrorLog + 在 cleanupStatus / ImportResult.Message 註記『匯入成功但清理失敗』，仍回 Result 1（回傳碼 0/1/2/3 語意不動——1 本來就代表匯入成功）。MultiSpec 的 post-commit 迴圈同樣包 try 逐檔容錯。各 importer 同構修改並補 regression test（fake IImportFileSource 讓 CompleteSuccess 擲例外、斷言仍回 1）。

**驗證註記**：Verified line-by-line: RawData.cs:124 CompleteSuccess (FTP DeleteFile, no internal exception handling per ImportFileSource.cs:233-247) runs post-commit inside the outer try(:38); catch(:136-142) misclassifies a transient cleanup failure as Result 3 + MoveToError while data is already committed, triggering false-failure finalize (import_status=2, mail=1) and duplicate-collision on re-queue. MultiSpecRawData.cs:253-258 post-commit loop is confirmed outside any try/catch; exception escapes to Program.cs:642-649 and becomes ImportResult(0). Decisive corroboration: MultiSpecRawData's own comments (:139-141, :243-244) explicitly name this exact escape-to-Result-0 hazard and guard BeginUnitOfWork/Commit against it, but the post-commit cleanup loop was missed. Isomorphic pattern confirmed in Tester.cs:111 (read), RecoveryRate/UiStatus/FailPin/EverySiteItem (grep). Not a duplicate of CONCERNS.md R-b (that covers pre-commit transient DB failures where DB and status agree; this is post-commit DB/status divergence). Suggested fix respects all hard constraints (keeps 0/1/2/3, returns truthful 1, no async, no piggyback rule misapplication) and no existing test pins the current behavior. One detail overstated: the MultiSpec Result-0 path does NOT leave db_key pending — Program.cs finalize still runs and flips import_status to 2 + mail; the duplicate collision occurs on manual re-queue, not automatically next round. This correction doesn't weaken the defect, and adds an unstated consequence: Result!=1 silently skips the EverySiteItem/RealTimeDetection piggyback for that db_key permanently. Medium severity is correctly calibrated: standing exposure across 6+ importers in an unattended long-running ETL, but rare per-import trigger and no data loss/double-import (duplicate guard holds).

---

### TSMC net-name CSV 在解析階段（DB 交易 commit 前）就被 CompleteSuccess 刪除：rollback 重試與 MultiSpec 後續 site 永遠拿不到 net_name

- **位置**：`DCT_data_import/ReadAndImport/TsmcIeda.cs:208`
- **維度**：io-ftp ｜ **工作量**：M ｜ 驗證信心：high

**問題**：GetNetNameList 讀完 TSMC_DATA/CSV/ 的 net-name 檔後立即 CompleteSuccess 刪除來源檔，但它是從 FileReadRawData（解析階段，ImportData.cs:448-451）呼叫的——此時該 lot 的 DB 交易尚未開始。若後續匯入失敗 rollback（或 IsDBKeyExistInDB 擋下），重投該 rawdata CSV 時 net-name 檔已不存在，重試匯入的 net_name 靜默全空。MultiSpec 多 site lot 更是必然踩到：第一個 site 檔解析即刪檔，site 2+ 的 GetNetNameList 開檔擲例外 → recursive 重試再失敗 → 對已不存在的檔案 MoveToError 再噴一筆 log → 回空 list，site 2+ 的統計列 net_name 全空。這是解析函式帶不可逆檔案副作用的順序風險。

**證據**：
```
TsmcIeda.cs:207-208 `// 刪除已成功讀完的TSMC CSV檔案` `CompleteSuccess(ftpserver);`（於 GetNetNameList 內，呼叫點 ImportData.cs:448-451 在任何 DbUnitOfWork 建立之前）
```

**建議**：GetNetNameList 改為只讀不刪、回傳（netNameList, csvPath），由 importer 在該 lot 交易 commit 成功後統一 CompleteSuccess；MultiSpec 情境同時把 netnameList 以 AO_lot 為 key 在單一 lot 匯入期間快取，避免 site 2+ 重讀。搭配整合測試驗證『rollback 後重投仍有 net_name』。

**驗證註記**：All cited code verified exact: TsmcIeda.cs:206-208 deletes the TSMC net-name CSV inside GetNetNameList, invoked from the parse callback FileReadRawData (ImportData.cs:446-451) — in RawData.cs this runs at line 45, before field validations (53-81), the dup check (85), and BeginUnitOfWork (101); FTP CompleteSuccess is a permanent DeleteFile. Rollback/re-submit is the designed recovery path (MultiSpecRawData.cs:137 comment; CONCERNS R-b documents manual re-submission), and on retry GetNetNameList swallows the FileNotFound, returns an empty list, and the lot commits as success with net_name silently empty — unrecoverable. MultiSpec per-site loop (lines 156-169) re-invokes GetNetNameList per site file, so site 2+ of a TSMC multi-site lot hit the deleted file exactly as described; the early deletion also contradicts the codebase's own "file side effects deferred until after commit" pattern established at MultiSpecRawData.cs:219. Not a CONCERNS.md duplicate (item F fixed only the missing-header case; D4 is a different TSMC inconsistency), violates no hard constraint, and the proposed fix mirrors an existing in-repo pattern. Severity medium is correct: silent, permanent data-quality loss but scoped to TSMC lots on retry/multi-site paths, with an error-log breadcrumb emitted.

---

### mail_temp.txt 讀→寄→刪非原子且不持鎖,跨執行緒失敗通知可能靜默遺失

- **位置**：`DCT_data_import/DbApi/DbAccess.cs:449`
- **維度**：threading ｜ **工作量**：M ｜ 驗證信心：high

**問題**：mail_temp.txt 有兩個寫入端跨執行緒:Tester thread(UpdateDbKeyImportStatus:234)與 UiStatus thread(UpdateDbKeyUiStatusImportStatus:305),皆經 WriteToMailTemp 持 DCT_MailTemp_ 具名 mutex。但讀取端 SelectFailDbKeyFromFile(DbAccess.cs:443-464,裸 StreamReader)與刪除端 CleanupMailTempFiles(NotificationService.cs:237-239,裸 File.Delete)完全不持該 mutex,且 Program.cs:414-425 的「讀檔→SMTP 寄信→刪檔」序列橫跨數秒非原子。race:Tester 讀完檔開始寄信期間,UiStatus thread append 一筆新失敗紀錄;寄信成功後 CleanupMailTempFiles 刪檔,該筆紀錄未被讀過即消失。DB 端 worklist SELECT 帶 AND mail=0(DbAccess.cs:88,92),失敗列已標 mail=1/import_status=2 永久離開 worklist,無任何路徑重讀 mail=1 列——通知永久遺失。通知風暴(兩 thread 同時大量失敗)正是 race 最容易命中的時刻。次要 race:StreamWriter append 用 FileShare.Read,讀端可能讀到半行(torn line),Split(',') 產生錯誤 remark;Windows 上 File.Delete 撞到持鎖寫入會擲 IOException 被吞、下輪重複寄信。CONCERNS.md R6/R-c 記的是 DB 層多實例 TOCTOU,此檔案層跨執行緒 race 未載。

**證據**：
```
// DbAccess.cs:449 無鎖讀
using (StreamReader reader = new StreamReader(log_path))
// NotificationService.cs:239 無鎖刪
File.Delete(logPath);
// 對照寫入端 WriteToLog.cs:249 持鎖
RunWithFileLock(mutexName, "Mail temp write failed", () => { ... });
```

**建議**：以既有 GetMutexName("DCT_MailTemp_", log_path) 的同一具名 mutex 保護消費端:在鎖內把 mail_temp.txt File.Move 到 mail_temp.processing.txt(原子搶佔,寫入端此後 append 會重建新主檔),釋放鎖後再從 processing 檔讀取並寄信;寄成功刪 processing 檔,寄失敗保留待下輪合併重讀。改動集中在 SelectFailDbKeyFromFile 與 CleanupMailTempFiles 兩處,可用兩 thread 併發 append/consume 的 stress test 釘 race(單次通過不算證據)。

**驗證註記**：All cited code verified exact: writers WriteToMailTemp (DbAccess.cs:234 Tester thread, :305 UiStatus thread) hold the DCT_MailTemp_ named mutex (WriteToLog.cs:247-263), while the consumer path is fully unlocked — SelectFailDbKeyFromFile bare StreamReader (DbAccess.cs:449) and CleanupMailTempFiles bare File.Delete (NotificationService.cs:240) — spanning a multi-second SMTP send (Program.cs:414-425, Tester thread only). A UiStatus-thread append landing between the read and the delete is discarded unread; the corresponding db_key row is already import_status=2/mail=1 and both worklist SELECTs filter AND mail=0 (DbAccess.cs:88,92) with no path re-reading mail=1 rows, so the email notification is permanently lost. Not in CONCERNS.md (R6/R-c are DB-layer multi-instance TOCTOU, different layer). No hard constraint violated; proposed mutex-protected File.Move fix is local. Two minor caveats that don't change the verdict: the secondary torn-line claim is largely non-exploitable on Windows prod (StreamReader FileShare.Read causes a caught IOException instead), and the fix needs a DryRun guard (DryRunModeTests pins that mail_temp.txt survives DryRun). Impact is alert loss not data loss (failure persists in db_key.remark and error logs), but email is the designed alert channel for this unattended service and the race window peaks exactly during failure bursts — medium stands.

---

### mail_temp.txt 讀取與刪除不持鎖,跨執行緒 race 會永久遺失失敗通知信

- **位置**：`DCT_data_import/Common/NotificationService.cs:240`
- **維度**：quiet-correctness ｜ **工作量**：M ｜ 驗證信心：high

**問題**：mail_temp.txt 是「待寄失敗通知」的狀態通道:寫入端 WriteToLog.WriteToMailTemp(WriteToLog.cs:249)有取具名 mutex(DCT_MailTemp_),但讀取端 DbAccess.SelectFailDbKeyFromFile(DbAccess.cs:449,直接 StreamReader)與刪除端 NotificationService.CleanupMailTempFiles(File.Delete)皆不持同一把鎖。Tester 執行緒的寄信流程(Program.cs:414-424)是「讀 snapshot → SMTP 送信(秒級)→ 送成功即刪整檔」;UiStatus 執行緒在 UpdateDbKeyUiStatusImportStatus(DbAccess.cs:305)隨時可能 append 新失敗項。在 snapshot 讀取之後、File.Delete 之前寫入的項目會被連檔刪掉且從未寄出。因 SelectDbKey 只掃 mail=0(DbAccess.cs:88,92),全庫無任何 mail=1 的補掃機制(已 grep 確認),遺失即永久靜默——log 也不會有任何跡象。另外 WriteToMailTemp 寫入失敗被 RunWithFileLock 吞成 Console-only(WriteToLog.cs:335)、回傳值恆為空字串且 caller 不檢查,是同一通道的第二個靜默失效模式。

**證據**：
```
NotificationService.cs:237-241: string logPath = Path.Combine(AppContext.BaseDirectory, "mail_temp.txt"); if (File.Exists(logPath)) { File.Delete(logPath); ... }  /  DbAccess.cs:449: using (StreamReader reader = new StreamReader(log_path))(皆無 GetMutexName("DCT_MailTemp_", log_path) 鎖;對照 WriteToLog.cs:248-249 寫入端有鎖)
```

**建議**：把「讀取+送信判定+刪除」納入與寫入端同一把具名 mutex:最小改法是在 WriteToLog 增加一個 internal 的 RunWithFileLock 包裝(mutex 名沿用 GetMutexName("DCT_MailTemp_", path)),Tester 寄信流程在鎖內先 File.Move 到 mail_temp.processing 快照檔再釋放鎖,之後對快照送信、送成功刪快照(失敗則把快照內容 append 回原檔)。如此寫入端不會被 SMTP 秒級延遲阻塞,又保證 snapshot 之後的新項留在原檔等下一輪。並讓 WriteToMailTemp 失敗改走 WriteErrorLog 而非僅 Console。

**驗證註記**：親自逐行驗證全部成立:寫入端 WriteToMailTemp(WriteToLog.cs:245-265)確實持具名 mutex(GetMutexName("DCT_MailTemp_", path)),但讀取端 SelectFailDbKeyFromFile(DbAccess.cs:449 bare StreamReader)與刪除端 CleanupMailTempFiles(NotificationService.cs:240 File.Delete)皆不持鎖。三執行緒並行確認(Program.cs:152-154);Tester 寄信流程(Program.cs:414-424)為「讀 snapshot → SMTP 送信 → 成功即刪整檔」,而 UiStatus 執行緒可隨時經 UpdateDbKeyUiStatusImportStatus(DbAccess.cs:305)append;且 ImportUiStatusMode 自身無寄信流程,其失敗項只能靠 Tester 執行緒送出——跨執行緒共用此檔是設計本身,race 視窗真實存在。永久性成立:SelectDbKey 只掃 mail=0 AND import_status=0(DbAccess.cs:88,92),全庫 grep 無任何 mail=1 補掃,finalize UPDATE 帶 WHERE import_status=0 不會重排入佇列;遺失項僅留一句不含內容的「郵件暫存檔已清理」info log。次要主張(RunWithFileLock 吞例外至 Console-only、回傳值恆空且 caller 不檢查)亦逐行確認。非 CONCERNS.md 已載債(R6/R-c 是多實例 DB TOCTOU,機制不同);建議修法局部、不違反任何硬性約束(唯須保留 DryRun 不刪檔語意,屬實作細節)。緩解因素:視窗窄(每輪 ~7.2 分僅 SMTP 秒級視窗)且失敗 remark 仍留 DB,只失去通知非資料——故維持 medium 不升不降。

---

### 5 個單檔 importer 的『驗證失敗守衛＋成功/失敗收尾』整段複製貼上（約 350+ 行）

- **位置**：`DCT_data_import/ReadAndImport/Tester.cs:41`
- **維度**：simplify-dup ｜ **工作量**：M ｜ 驗證信心：high

**問題**：Tester(:41-81)、RawData(:49-92)、FailPin(:42-70)、RecoveryRate(:45-89)、UiStatus(:37-50) 每個驗證失敗點都是同一 4-5 行套路：Console.WriteLine ＋ WriteErrorLog ＋ MoveToError ＋ return ImportResult(2/3, msg)，全庫約 20 處；另外『check-log 計時寫入』4 行（`"DCT_data_check_log_" + type + dateStr` ＋ FormatFileSize ＋ WriteToCheckLog）在 5 檔逐字重複（Tester:104-106、RawData:117-119、FailPin:93-95、RecoveryRate:112-114、MultiSpecRawData:213-215）。這類複製貼上已實際造成漂移 bug：CONCERNS.md『錯誤可觀測性強化』記載 Tester guard 曾漏 log＋搬檔（兄弟皆有）、RecoveryRate:86-87 的重複訊息漏印檔案路徑格式也與兄弟不一致。每加一個 importer 或改一次錯誤處理慣例都要同步 5+ 處。

**證據**：
```
if (!testStatusContentFormat.CompareInfo())
{
    Console.WriteLine("Tester Status 之 information 欄位名稱不符:  " + filename);
    writeToLog.WriteErrorLog("... " + ftpFilePath + " - " + testStatusContentFormat.ErrMsg);
    MoveToError(ftpFilePath, errorPath);
    return new ImportResult(2, "Information field name not match. " + testStatusContentFormat.ErrMsg);
}
```

**建議**：不建 template-method 框架（各 importer 驗證組合差異大，會過度抽象）；只在 ImportData 基底抽兩個小 helper：(1) `protected ImportResult FailAndMoveToError(WriteToLog log, string consoleMsg, string logMsg, string path, string errorPath, int code, string resultMsg)`；(2) `protected void WriteImportCheckLog(WriteToLog log, string typeSlug, string filename, long fileSize, double readSec, double importSec)`。逐檔機械替換、訊息文字原樣傳參數，行為零變更；MultiSpecRawData 已有 RollbackAndFail 先例。既有 ImporterReadErrorRegressionTests / ImporterEmptyContentRegressionTests 可護航。

**驗證註記**：All evidence verified against source: the guard pattern (Console+WriteErrorLog+MoveToError+return ImportResult) exists at the cited lines in all 5 importers, and the check-log 4-line block is byte-identical in exactly the 5 cited files (grep-confirmed). The claimed drift bugs are real — RecoveryRate.cs:86-87 logs filename instead of ftpFilePath inconsistently with siblings, and CONCERNS.md documents the Tester guard that once silently lacked log+MoveToError. No hard-constraint violation: suggestion is two small local helpers in the ImportData base, no async/modernization, result codes passed through unchanged, piggyback importers correctly excluded, MultiSpecRawData's RollbackAndFail difference acknowledged. Not a CONCERNS.md duplicate (it records the fixed incident, not the duplication debt). Cited regression tests (ImporterReadErrorRegressionTests, ImporterEmptyContentRegressionTests) exist. Minor caveat only: guard variants differ (WriteInfoLog vs WriteErrorLog, two guards lack Console output), so the FailAndMoveToError helper signature needs a log-level/nullable-console accommodation — implementation detail, not fatal.

---

### FileProcess 11 處欄名正規化迴圈重複（ToLower/Replace/改名/backtick/尾逗號手術）

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:318`
- **維度**：simplify-dup ｜ **工作量**：M ｜ 驗證信心：high

**問題**：『迴圈跑 DataTable.Columns → ToLower → Replace 空白 → 特例改名 → 拼 `col`, → 最後一欄不加逗號』的樣板在 ImportRecoveryData(:231-247)、ImportRawDataCore(:318-343, :426-444, :485-502)、ImportTesterStatus(:570-608, :633-647, :692-705, :739-748)、ImportUIStatus(:797-806)、ImportFailPinLog(:868-889, :914-923, :973-982) 共 11 處、約 130 行，僅改名映射表不同。其中 ImportFailPinLog(:881-882) 還因跳過空欄做 `columns.Substring(0, columns.Length - 1)` 尾逗號手術——若第 0 欄值就是空的會 Substring(0,-1) 擲 ArgumentOutOfRangeException（latent、資料相依）。每次新增欄名改名規則要在多處找對迴圈改。

**證據**：
```
string column_name = content.LotInfo.Columns[i].ColumnName.ToLower();
column_name = column_name.Split('(', ')')[0];
if (column_name == "bondingdiagram") column_name = "bonding_diagram";
...
columns += "`" + column_name.Trim() + "`";
if (i != content.LotInfo.Columns.Count - 1) { columns += ","; }
```

**建議**：抽 `internal static string BuildColumnList(DataTable table, Func<string,string> rename)`（內部用 string.Join 取代尾逗號邏輯，也消掉 Substring 手術），純欄名的 8 處直接替換；columns/values 交織組裝的 2-3 處（tester_device_info、fail_pin_rate_info）維持現狀不硬套。改名映射改為每表一個 static readonly Dictionary。既有 FileProcessImportRawDataCharacterizationTests 與 ExecuteInsert virtual seam 可驗證輸出逐字等價。順手把各 Import* 內層迴圈的 numTypeColumn/doubleTypeColumn 陣列（:820、:661、:935 每 cell 配置一次）提為 static readonly。

**驗證註記**：親自逐段核實 FileProcess.cs:全部 12 處（finding 少算為 11）欄名正規化迴圈逐字存在且樣板一致;evidence 片段與 :320-342 完全吻合;:881-882 的 Substring(0,-1) latent 例外成立(該迴圈在 try 之外,首欄空值即擲 ArgumentOutOfRangeException);宣稱的驗證 seam(FileProcessImportRawDataCharacterizationTests + public virtual ExecuteInsert :1074)皆存在;不與 CONCERNS.md 重複(P1 是另一件已證偽的 O(n²) perf 主張)、不與 PR#69/#76 重疊;建議不違反任何硬性約束(局部單檔 dedup,保留 Dapper 參數化與 identifier guard)。瑕疵僅在校準面:計數 12 非 11、純欄名應為 ~9 處/交織 3 處(lots_info :318-343 也是交織,finding 漏列)、且「消掉 Substring 手術」與其自身「交織處維持現狀」互相矛盾——依其 scope Substring 風險其實不會被修掉。核心 dedup 主張與維護成本(改名規則歷史上確實隨 CSV 格式演化而變)成立,維持 medium。

---

### importer 例外→Result 0→終態 finalize+寄信 的決策鏈零測試覆蓋(FTP transport 失敗會被永久終結)

- **位置**：`DCT_data_import/Program.cs:608`
- **維度**：test-gaps ｜ **工作量**：M ｜ 驗證信心：high（原評 high，驗證後校準）

**問題**：RunTesterImportBatch 四個 per-importer catch 把「任意例外」一律映成 ImportResult(0, ex.Message)(:608/:648/:690/:717),之後 finalize 照常執行 UpdateDbKeyImportStatus——分量 0 使 bit 不設 → importResult != check_status → import_status=2(終態)+ mail=1 + WriteToMailTemp。FTP transport 失敗必走此鏈:FtpImportFileSource.Exists 對非 550 的 WebException 是 rethrow(ImportFileSource.cs:170),而各 importer 的 FileExists 呼叫在其 try 區塊之外(RecoveryRate.cs:25,try 從 :33 起)。等效行為:FTP 短暫斷線一輪,該輪所有待處理 db_key 被永久終結為失敗+寄信,檔案仍在 FTP 上但列不會再被撿起(import_status!=0,需人工 re-queue)。此決策鏈目前無任何 characterization/regression test:RunTesterImportBatch 只被 opt-in MySQL E2E 的快樂路徑走到,單元測試僅涵蓋 ImportDecision 純函式與 importer 內部的讀檔錯誤(Result 2)分支。CONCERNS.md R-b 只載「MySQL transient 打成終態 Result 3」,FTP transport 例外→Result 0→終態這條並未記載。

**證據**：
```
Program.cs:602-608 `catch (Exception ex) { ... importResult = new ImportResult(0, ex.Message); }`;ImportFileSource.cs:162-171 `catch (WebException ex) { response = ex.Response as FtpWebResponse; if (response?.StatusCode == FtpStatusCode.ActionNotTakenFileUnavailable) { return false; } throw; }`;RecoveryRate.cs:25 `bool isFileExist = FileExists(ftpFilePath);`(位於 :33 try 之外);DbAccess.cs:221-234 分量不符即 `importStatus = "2"; mail = "1"; writeToLog.WriteToMailTemp(dbKey + "," + remark);`
```

**建議**：分兩步:(1) 先補 characterization test 釘住現行為——為 ImportData.FileSource 增加測試用 factory override(比照既有 ImportSourceSettings.SetOverridesForTests 模式),注入一個 Exists 擲 WebException 的 fake IImportFileSource,斷言 RunTesterImportBatch 不中斷批次、分量回 0、finalize 走失敗分支(可搭現有 MySqlIntegrationFixture 驗 import_status=2 + mail=1);(2) 據測試證據與維運討論是否把「transport 例外」與「檔案確實不存在」區分——transport 失敗該輪跳過 finalize(維持 import_status=0 下輪重試),不動 0/1/2/3 回傳碼語意。

**驗證註記**：Every cited code location verified accurate: Program.cs:602-608/:648/:690/:717 map any importer exception to ImportResult(0, ex.Message); FtpImportFileSource.Exists (ReadAndImport/ImportFileSource.cs:162-171) rethrows non-550 WebException; FileExists sits outside the try in RecoveryRate(:25)/RawData(:28)/Tester(:25) so transport exceptions escape to Program.cs; finalize (DbAccess.cs:221-234) then sets import_status=2 + mail=1 + WriteToMailTemp, and SelectDbKey (DbAccess.cs:88) filters import_status=0 AND mail=0 — permanent termination needing manual re-queue. Test-gap claim holds in substance: no unit or integration test exercises the exception→Result 0→finalize chain (CheckStatusWeightedSumTests = pure function only; ThrowingReadFileSource tests stream disposal only; E2E uses Local source exclusively). Not a CONCERNS.md duplicate: R-b covers MySQL transient→Result 3 with transient-verdict log mitigation which the FTP path bypasses; R1 notes FTP test absence but not this decision chain. No hard-constraint violations (0/1/2/3 untouched, characterization-first, behavior change gated on ops discussion). Two minor inaccuracies that don't change the conclusion: FailPin.cs:28 has FileExists inside its try (returns terminal Result 3 instead), and the E2E does exercise the finalize failure branch via validation rejection (lot 052), so "只被快樂路徑走到" is overstated. Severity downgraded to medium: the hazard extends a documented, deliberately-deferred debt class (R-b Low–Medium / R1 Low), occurrence frequency is unevidenced on internal-network FTP, and it is a test-gap (not an active regression).

---

### 兩處時間窗寄信決策 DateTime.Now inline、無 seam 無測試,且 10 分鐘窗 × 7.2 分鐘輪詢必然可重複寄信

- **位置**：`DCT_data_import/Common/NotificationService.cs:221`
- **維度**：test-gaps ｜ **工作量**：M ｜ 驗證信心：high

**問題**：兩個 mail 寄送決策直接讀 DateTime.Now,無注入點、零測試:(1) NotificationService.ShouldSendProgramStatusNotification(:219-223)判「週一 8:00-8:10」——`(int)nowTime.DayOfWeek == 1` 的魔術數字語意(Monday)無測試釘住;(2) Program.cs:379-387 的 Tester 資料遺失窗(dataCount==0 且 hour==8 且 minutes<10)是另一份 inline 重複的同型邏輯。supervisor 迴圈週期約 7.2 分鐘(SupervisorSleepMilliseconds=432000,CONCERNS 項 B),小於兩個 10 分鐘窗,同一窗內可命中兩次 → 週報/資料遺失信可能重複寄出,現況無任何測試能抓到這件事,邊界(8:09 寄、8:10 不寄)也無 pin。這是典型「時間寫死」的脆弱設計,一旦有人調整輪詢週期或窗寬,行為變化完全無迴歸防護。

**證據**：
```
NotificationService.cs:219-223 `public bool ShouldSendProgramStatusNotification() { DateTime nowTime = DateTime.Now; return (int)nowTime.DayOfWeek == 1 && nowTime.Hour == 8 && nowTime.Minute < 10; }`;Program.cs:381-386 `if (DateTime.Now.TimeOfDay.Hours == 8) { if (DateTime.Now.TimeOfDay.Minutes >= 0 && DateTime.Now.TimeOfDay.Minutes < 10) { _notificationService.SendDataMissingNotification("Tester"); } }`
```

**建議**：抽兩個 internal static 純函式 `IsWithinWeeklyStatusWindow(DateTime now)` / `IsWithinDataMissingWindow(DateTime now)`(比照 ImportDecision 抽 seam 的既有模式),caller 傳 DateTime.Now,用 [Theory] 釘邊界:週一 07:59/08:00/08:09/08:10、週二 08:05。重複寄信若要根治,可加「當窗已寄」的 last-sent 記憶並以測試釘住冪等——先測後改,不動寄信通道本身。

**驗證註記**：All evidence verified verbatim: NotificationService.cs:219-223 and Program.cs:379-387 both read DateTime.Now inline with no seam; Program.cs:23 SupervisorSleepMilliseconds=432000 (7.2 min) < both 10-min windows, and the supervisor loop (checks status mail each cycle) plus per-cycle worker restart make double-fires within one window genuinely possible for both mails. Grep confirms zero tests pin either window (only BuildMailListIniPath/CleanupMailTempFiles/namespace tests touch NotificationService), and the cited ImportDecision pure-function seam precedent exists (ImportDecision.cs + ImportDecisionTests.cs). No hard-constraint violation (local extraction, no async/result-code/SQL changes), no CONCERNS.md duplication (item B only fixed the Sleep comment), and the suggested fix is behavior-preserving. Minor nit: title's "必然可重複" overstates — double-hit is phase-dependent, and impact is only duplicate notification noise — but the description itself says "可能", and the test-gap on unattended alerting logic is real, so medium stands.

---

### mail_temp.txt 讀取→寄信→刪除窗口與並行 append 有 TOCTOU,期間寫入的失敗通知會被靜默刪除且永不重寄

- **位置**：`DCT_data_import/Program.cs:421`
- **維度**：config-startup ｜ **工作量**：M ｜ 驗證信心：high

**問題**：WriteToMailTemp(append)有具名 Mutex 保護,但 SelectFailDbKeyFromFile(讀,DbAccess.cs:449)與 CleanupMailTempFiles(刪,NotificationService.cs:237)都不取同一把鎖。Tester 執行緒讀完檔→SMTP 寄信(耗時數秒)→寄成功才刪檔;此窗口內 UiStatus 執行緒(UpdateDbKeyUiStatusImportStatus 失敗路徑)append 的新通知會隨檔案一起被刪。因該 db_key 在 DB 已標 mail=1/import_status=2 退出 worklist,這筆異常通知從此無人知曉——通知靜默遺失,維運不會收到信。

**證據**：
```
bool sendResult = _notificationService.SendErrorNotification("下列資料發生異常，請確認檔案內容", details);
if (sendResult)
{
    _notificationService.CleanupMailTempFiles();
}
```

**建議**：把「取快照」做成原子操作:在 WriteToLog 新增 ReadAndClearMailTemp(),於既有 DCT_MailTemp_ Mutex 內先 File.Move(mail_temp.txt → mail_temp.processing.txt) 再解鎖,之後從快照讀取與寄信;寄成功刪快照,寄失敗把快照內容 append 回主檔(同樣走 Mutex)。窗口內的新 append 會落在新的 mail_temp.txt,不受影響。

**驗證註記**：Verified in code: WriteToMailTemp appends under named Mutex (WriteToLog.cs:245-265) but SelectFailDbKeyFromFile (DbAccess.cs:443-464) and CleanupMailTempFiles (NotificationService.cs:228-248) take no lock; Program.cs:414-423 does read→synchronous SMTP→delete-on-success. The UiStatus thread (Program.cs:153/791 → DbAccess.cs:305) appends concurrently with the Tester thread's send window, so a line appended in that window is deleted unsent. Loss is permanent for the email channel: worklist queries filter import_status=0 AND mail=0 (DbAccess.cs:88,92) and no path re-derives pending mail from mail=1 rows — the file is the sole mail queue. Not covered by CONCERNS.md (R6/R-c are DB-side TOCTOU, different mechanism); no hard-constraint violation; fix is local and sync. Two calibrations: (1) impact slightly overstated — DB remark/import_status=2/mail=1 and the *_Error folder still record the failure, only the proactive email is lost; (2) the proposed File.Move snapshot must respect DryRun (CleanupMailTempFiles is deliberately no-op under DryRun, pinned by DryRunModeTests.CleanupMailTempFiles_WhenDryRun_DoesNotDeleteFile) or it breaks that test/invariant — implementation caveat, not a refutation. Medium stands: silent, unretried loss of the alerting channel in a long-running unattended service, rare trigger but permanent per occurrence.

---

### EverySiteItem/RealTimeDetection piggyback：commit 成功後的 CompleteSuccess 清理與匯入共用同一 try，EverySiteItem 例外路徑還把已入庫的檔搬到錯誤區

- **位置**：`DCT_data_import/ReadAndImport/EverySiteItem.cs:85`
- **維度**：gap-audit ｜ **工作量**：M ｜ 驗證信心：high

**問題**：既有 io-ftp finding 只點名 RawData.cs:124 的「清理與匯入共用同一 try」模式，但兩支 piggyback importer 複製了同一缺陷且未被覆蓋，而且 EverySiteItem 的變體更糟：uow.Commit()（:70）成功後，:85 的 CompleteSuccess（FTP DeleteFile，暫時性 WebException 可擲）若失敗會落入 :88 catch → 記「匯入處理發生例外錯誤」→ :92 MoveToError 把來源檔搬進 Multisite_Statistic_Data_Error → 回 Result 3。結果是資料已在 site_test_statistics，但維運看到「匯入失敗」+檔案在錯誤區；人工重投會撞 SiteStatisticsExistForLot 冪等 skip（Result 3），狀態永遠對不上。RealTimeDetection.cs:147-153 同 pattern（commit 後最多 3 個 CompleteSuccess 在同一 try 內，例外 → Result 3 且來源檔殘留；因 piggyback 每 db_key 只跑一次，殘留檔無自然重清機會）。piggyback 回傳碼不進 bitmask 狀態機（符合約束 4），故影響是維運誤判與錯誤區污染，非狀態機損毀。

**證據**：
```
// EverySiteItem.cs:70 uow.Commit(); ... :85
string deleteStatus = CompleteSuccess(ftpFilePath);
...
catch (Exception ex)
{
    writeToLog.WriteErrorLog($"EverySiteItem 匯入處理發生例外錯誤: ...");
    MoveToError(ftpFilePath, errorPath);   // :92 — DB 已 commit 仍搬錯誤區
    return new ImportResult(3, "Exception error occurred during import.");
}
```

**建議**：比照 RawData.cs:124 finding 的修法一併處理兩支 piggyback：把 commit 之後的 CompleteSuccess/LogImportSuccess 移出主 try（或包獨立 try），清理失敗只記「資料已入庫、來源檔清理失敗待人工刪除」的 info/error log 並回 Result 1，絕不 MoveToError、不回 Result 3。RealTimeDetection.cs:147-153 同步套用（其 footprint 冪等已能吸收重複清理）。各補一條「commit 成功 + 清理擲例外 → Result 1 且不搬檔」的 regression test。

**驗證註記**：全部證據逐行核實成立：EverySiteItem.cs :70 Commit 後 :85 CompleteSuccess 與匯入共用同一 try，catch(:88) 會 MoveToError(:92) 並回 Result 3(:93)；CompleteSuccess 確實可擲（FTP DeleteFile GetResponse 無 try/catch、Local File.Move/Delete 可擲 IOException，基底類別不吞——對照 MoveToError 有自己的 catch，且 repo 歷史 PR#76 證明 FTP 暫時性失敗真實存在）。RealTimeDetection.cs :147-153 三個 CompleteSuccess 同 pattern（catch 保留檔案、回 Result 3），piggyback 每 db_key 只跑一次故殘留檔無自然重清。RawData.cs:124 兄弟 pattern 存在，gap-audit 前提成立。不違反任何硬性約束（修法保持 0/1/2/3 語意、明確尊重約束 4）；非 CONCERNS.md 已載債（其「來源 CSV 命運與交易解耦」只記設計、R-a~R-e 皆不涵蓋此缺陷）；修法不破壞既有測試（EverySiteItemReturnCodeTests 未 pin 清理例外路徑）。唯一小瑕疵：「狀態永遠對不上」略誇大——冪等 skip 路徑的 info log「資料庫已存在此 lot 統計」對細心維運可揭露真相；且 Program.cs:655/:663 丟棄回傳值故 Result 3 無機器後果，實害限於誤導性錯誤日誌＋已入庫檔案污染錯誤區觸發窗口低（commit 成功後、清理當下的暫時性失敗）。綜合：缺陷真實、影響為維運誤判非資料損毀，medium 對長駐無人值守 ETL（錯誤區＝triage 佇列）屬合理校準。

---

### db_key / db_key_ui_status 旗標表零二級索引,輪詢與終結路徑全數全表掃描(前審 D-1,仍成立)

- **位置**：`DCT_data_import/sql/dct.sql:1`
- **維度**：db-sql ｜ **工作量**：S ｜ 驗證信心：high（原評 high，驗證後校準）

**問題**：整個狀態機的心臟表 db_key(dct.sql:1-17)與 db_key_ui_status(:19-32)只有 auto_increment PK,無任何二級索引,而程式對它們的查詢/更新沒有一條能用 PK:(1) SelectDbKey worklist `WHERE check_status>0 AND import_status=0 AND mail=0`(DbAccess.cs:88,92)每輪詢週期各跑一次;(2) SelectDataCountInDays `WHERE datetime >= @threshold`(DbAccess.cs:49)每輪一次;(3) 每筆待處理 db_key 的終結流程至少 3 次 `WHERE db_key=@dbKey [AND import_status=0]`(BuildDbKeyStatusSelectQuery:388、BuildDbKeyImportStatusUpdateQuery:405、SyncPendingRemark 經 BuildPendingRemarkUpdateQuery:432)。db_key 表由外部系統持續灌入且本程式無任何清理機制,列數無上界;每輪成本 ≈ (3 + 3×待處理筆數) 次全表掃描,且 UPDATE 全掃在 InnoDB 預設 REPEATABLE READ 下會對掃過的列取鎖,表越大鎖持有面越大。前次審查已排入為 D-1 但未落地,本次驗證仍成立。(同批驗證:D-2 lot_mapping 快取已不成立——TsmcIeda 建構子每輪僅載一次 lot_mapping.csv 至實例 DataTable,detection_methods 亦由 RealTimeDetection._detectionMethodIds 實例快取,無需再列。)

**證據**：
```
dct.sql:1-17 create table db_key (id int auto_increment primary key, datetime int null, db_key varchar(255) null, ... ) ——無任何 create index;對照 DbAccess.cs:88 "SELECT id AS Id, ... FROM `db_key` WHERE `check_status`>0 AND `import_status` =0 AND mail=0;"、DbAccess.cs:405-406 "UPDATE db_key SET ... WHERE `db_key`=@dbKey AND import_status=0;"、DbAccess.cs:432-434 BuildPendingRemarkUpdateQuery "UPDATE db_key SET remark=@remark WHERE `db_key`=@dbKey AND import_status=0;"
```

**建議**：對兩張表各加三支索引並同步 dct.sql canonical schema:(a) `ADD INDEX idx_db_key (db_key)`——覆蓋終結 SELECT/UPDATE 與 pending remark UPDATE 的等值查詢(db_key 具高選擇性);(b) `ADD INDEX idx_worklist (import_status, mail, check_status)`——兩個等值欄在前、range 欄殿後,worklist 查詢可全走索引;(c) db_key 表另加 `ADD INDEX idx_datetime (datetime)` 供 SelectDataCountInDays。MySQL 8 對加索引為 INPLACE online DDL,不鎖寫入;既有 prod DB 由 DBA 以 runbook 套用(比照 ui_status uk_ui_status 遷移模式),與程式 deploy 解耦、程式零改動。rollback = DROP INDEX。

**驗證註記**：全部引用逐一核實屬實：dct.sql:1-17/19-32 兩張旗標表僅 auto_increment PK、零二級索引（同 schema 其他表皆有 db_key 索引，此為異常非風格）；DbAccess.cs:49/88/92/388/405-406/432-434 六條查詢逐字吻合且無一能用 PK；grep 全程式無 DELETE db_key，無界成長宣稱屬實；每輪成本估算與 Program.cs 呼叫圖吻合（:379/:398/:754 + 每 pending key 的 :589/finalize，實為保守估）。非 CONCERNS.md 重複（R-a 是 ui_status 表 UNIQUE 去重，不同表）；建議為純加法 DDL、不觸五條硬性約束、dct.sql 已含 create index 且被整合測試消費故落地不破壞。惟 severity 校準降為 medium：輪詢週期 432000ms≈7.2 分鐘非高頻熱路徑、表窄、prod 列數與慢查詢/鎖競爭皆無現場證據，「UPDATE 全掃鎖面 → R-b transient 誤判終態」影響鏈技術正確但屬推論；另建議文案「worklist 可全走索引」不成立（非 covering index），效益結論不受影響。屬必然劣化的低成本可修債，非進行中事故。

---

### 終結 remark 無長度截斷,超過 varchar(255) 在 strict mode 使整個 finalize UPDATE 失敗、白跑一輪並重複寄信

- **位置**：`DCT_data_import/DbApi/DbAccess.cs:405`
- **維度**：db-sql ｜ **工作量**：S ｜ 驗證信心：high

**問題**：db_key.remark 為 varchar(255)(dct.sql:14),但 finalize UPDATE 的 @remark 參數(BuildDbKeyImportStatusUpdateQuery:405-407)由 Program.cs:722-726 串接最多 4 個 importer Message 而成,而 2026-07-01 錯誤可觀測性強化後 Message 會攜帶 FileContentFormat.ErrMsg 的欄位診斷(點名 label + 壞欄位清單)與例外訊息,單一分量即可能超過 255 字。MySQL 8 預設 STRICT_TRANS_TABLES 下 UPDATE 直接以 error 1406 (Data too long) 失敗:該 db_key 的 recovery_rate/tester/... 分量結果與 import_status 全部沒寫進去,列停留在 import_status=0 → 下一輪重新派工全部分量(檔案已搬錯誤區,通常以短訊息 self-heal),且 WriteToMailTemp(:234)在 UPDATE 前已寫入,失敗重試會累積重複通報行。非 strict 部署則是靜默截斷(較輕)。BuildPendingRemark(Program.cs:536)的心跳 remark 為固定短句不受影響,問題僅在 importResult 訊息串接路徑。

**證據**：
```
dct.sql:14 remark varchar(255) null;DbAccess.cs:405-407 Query = "UPDATE db_key SET recovery_rate=@recoveryRate,...,remark=@remark WHERE `db_key`=@dbKey AND import_status=0;", Parameters = new { ..., remark, dbKey };Program.cs:723 remark += ... "recovery rate: " + importResult.Message + "  ";(×4 分量串接,無任何長度守衛)
```

**建議**：在三個 query builder(BuildDbKeyImportStatusUpdateQuery / BuildDbKeyUiStatusImportStatusUpdateQuery / BuildPendingRemarkUpdateQuery)單點對 remark 參數做安全截斷(如 remark.Length > 255 ? remark.Substring(0, 252) + "..." : remark),完整訊息本就已進 file-log 不損失可追溯性;或走 schema 路線 ALTER remark 為 varchar(1024)/TEXT 並同步 dct.sql 與 DBA runbook。截斷路線為單檔小改 + 單元測試即可鎖行為,建議優先。

**驗證註記**：全部證據與程式碼一致:dct.sql:14/29 remark varchar(255);DbAccess.cs:405-407/420 finalize UPDATE 帶 @remark 且同語句承載 4 分量旗標+import_status+mail;Program.cs:722-726 無守衛串接最多 4 個 Message;全專案 grep 無任何截斷防線;WriteToMailTemp(DbAccess.cs:234/305)在 UPDATE 前寫入,失敗重試確會累積重複通報行。超長訊息路徑真實存在:ex.Message 原樣進 Message(Program.cs:608/648/690/717、Tester.cs:129),Compare* ErrMsg 可含例外訊息與畸形 CSV header 欄名。MySQL 8 預設 STRICT_TRANS_TABLES 下 1406 使整句失敗、列滯留 import_status=0 → 下輪重派,通常一輪 self-heal 但 mail_temp 已重複、最壞情境(例外反覆且檔案未搬移)成永久重試迴圈。非 CONCERNS.md 已載債(可觀測性強化段記了 ErrMsg→remark 流向但未記 255 溢位風險);建議修法不違反任何硬性約束、不破壞既有測試(SqlParameterizationTests 用短 payload pin 參數 passthrough,截斷 255 不受影響)。唯一小瑕疵:finding 稱 ErrMsg 帶「壞欄位清單」,實際 Compare* 首個非預期欄位即 return(單欄名非清單,FileContentFormat.cs:31-37),略縮單一分量溢位窗口,但不影響結論。medium 嚴重度校準正確:觸發窗口窄(需 >255 字且僅失敗路徑)、典型情境一輪自癒,非 strict 部署僅靜默截斷。

---

### FileReadRawData 對每個測項的 raw-value payload 重複 String.Join + ToArray,最大宗資料被多複製 ~3 次(LOH 壓力)

- **位置**：`DCT_data_import/ReadAndImport/ImportData.cs:473`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high（原評 high，驗證後校準）

**問題**：RawData 讀檔尾段把每個測項跨全部 unit 的 raw 值 join 成 "[v1, v2, ...]" 存進 value 欄。這是 100MB 級 CSV 中體積最大的 payload(R7 E2E 已證實單檔可達 103MB),單一測項的 joined 字串常超過 85KB 直接進 LOH。現行程式對同一個 rawData_list[i] 呼叫 String.Join 兩次(一次只為判空、一次真正組值),且兩次都先 ToArray() 複製 List,判空還對整條 megabyte 字串做 Trim()。合計每個測項 payload 被複製約 5 次(ToArray×2 + Join×2 + 串括號 1),其中 3 次純屬浪費——在大檔上等於數百 MB 的多餘暫時性 LOH 配置,直接推高 Gen2/LOH GC。line 487 又以 dataRow["value"].ToString().Substring(len-1) 檢查尾字元,再多一次 1-char 字串配置。PR#69 的 stream read 只解了讀檔端,這段組值端的重複配置仍在。

**證據**：
```
string strJoin = String.Join(", ", rawData_list[i].ToArray());
if (string.IsNullOrEmpty(strJoin.Trim())) { dataRow["value"] = "[]"; }
else { dataRow["value"] = "[" + String.Join(", ", rawData_list[i].ToArray()) + "]"; }
...
if (dataRow["value"].ToString().Substring(dataRow["value"].ToString().Length - 1) != "]")
```

**建議**：Join 一次、重用結果:`string strJoin = string.Join(", ", rawData_list[i]);`(直接吃 List<string>,免 ToArray),判空改 `strJoin.AsSpan().Trim().IsEmpty` 或 `rawData_list[i].All(string.IsNullOrWhiteSpace)`(零配置),組值重用 `"[" + strJoin + "]"`。修正後 value 恆以 ']' 結尾,line 487-490 的補尾檢查可直接刪除(或保守改 `EndsWith(']')` char overload)。單檔 payload 複製次數 5→2,行為逐字元等價。

**驗證註記**：程式碼逐字存在(ImportData.cs:473-490):同一 rawData_list[i] 確實 String.Join+ToArray 各兩次,且該路徑正是 CONCERNS.md R7 證實的 103MB RawData CSV 匯入路徑(RawData.cs:45 / MultiSpecRawData.cs:169),PR#69 只修讀檔端未動組值端,CONCERNS.md 無此項記載,修法不違反任何硬性約束。但嚴重度被灌水:(1) ToArray 複製的是 reference array(8B/元素)非 payload 字元資料,不能算 payload 複製;(2) Trim() 對無前後空白的字串回傳原 reference、零配置,「對整條 megabyte 字串做 Trim」的成本宣稱錯誤;(3) 實際純浪費是 ~1 次全 payload 複製(重複 Join)+2 次小型 ref array,非「5 次中浪費 3 次」。另建議中的 All(string.IsNullOrWhiteSpace) 判空與現行為不等價(多個空字串 join 成 ", " → Trim 後 "," 非空 → 現行輸出 "[, ]" 而非 "[]"),只有 AsSpan().Trim().IsEmpty 變體逐字元等價;line 487-490 現在就已是 dead code(三分支恆以 ']' 結尾),非修正後才可刪。浪費本身真實(每大檔約整個 raw 區段的 UTF-16 暫時性 LOH 配置)但屬暫時性 GC 壓力、無正確性影響、每檔一次的批次節奏 → medium 而非 high。

---

### FileReadRawData 第三部分逐 raw-value cell 以 Substring 檢查尾字元:每 cell 一次 1-char 字串配置,且空 cell 會擲例外使整檔判讀檔失敗

- **位置**：`DCT_data_import/ReadAndImport/ImportData.cs:406`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high

**問題**：raw-value 區是整檔 cell 數最多的區塊(unit 數 × 測項數,大檔為千萬級 cell)。line 406 以 `values[i].Substring(values[i].Length - 1) == "."` 檢查尾端小數點,每個 cell 配置一個 1-char 字串——千萬級 cell 即千萬次微配置,純 Gen0 但量大。此外這行對空字串 cell 會呼叫 Substring(-1) 擲 ArgumentOutOfRangeException,被外層 catch 接住後整檔設 ErrMsg → Result=2 搬錯誤區:一個中段缺測值的 cell 就讓整檔匯入失敗,錯誤訊息還只有 generic 的 "讀檔內容錯誤",無法定位壞 cell(穩定性隱患,與效能同一行、同一修法)。

**證據**：
```
else if (result_part == 2 && i < rawData_part_index + rawData_list.Count)
{
    // 讀值若含有小數點"."而沒有小數位，則移除小數點
    if (values[i].Substring(values[i].Length - 1) == ".") values[i] = values[i].Substring(0, values[i].Length - 1);
```

**建議**：改 `if (values[i].EndsWith('.'))`(char overload,零配置,且對空字串回 false 不擲例外)或 `values[i].Length > 0 && values[i][values[i].Length - 1] == '.'`。非空 cell 行為逐字元等價;空 cell 從「整檔炸掉」變「原樣通過」——後者屬行為變更,若要保守可先只修配置(補 Length > 0 守衛)並對空 cell 情境補一條 characterization test 定案預期行為。

**驗證註記**：Line 406 of ImportData.cs (FileReadRawData) matches the evidence verbatim. Both claims verified: (1) per-cell 1-char Substring allocation on the hottest parse region — CONCERNS.md R7 confirms real 103MB RawData CSVs, making tens-of-millions of cells realistic; PR#69 optimized this method but left line 406 untouched. (2) Empty-cell crash is reachable: line 284 splits on ','/'\0', lines 287-290 deliberately skip empty-cell filtering for content_part==3, line 369 only guards values[0], so an empty raw-value cell hits Substring(-1) → ArgumentOutOfRangeException → outer catch sets ErrMsg → RawData.cs:54 returns Result=2 (whole-file failure, moved to error area). No existing test pins empty-raw-cell behavior, so the proposed fix breaks no tests and the finding correctly flags the empty-cell behavior change with a conservative alternative. Not duplicated in CONCERNS.md; no hard constraint violated. Minor nit: ErrMsg appends ex.Message so it is not purely generic, but it still cannot locate the bad cell/row — diagnosability claim stands in substance.

---

### EraseSpecificChar 回 null 的契約只有 FailPin 有守——Tester/UiStatus 空行即 NRE 整檔退件

- **位置**：`DCT_data_import/ReadAndImport/Tester.cs:143`
- **維度**：simplify-dup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：ImportData.EraseSpecificChar 對全空行明確回 null（ImportData.cs:55，且有 EraseSpecificCharTests 釘住此契約），FailPin.cs:135-137 有 `if (values == null) continue;` 防護，但 Tester.cs:142-143 與 UiStatus.cs:103-104 直接 `values.Length` 解參考。CSV 內任一空白行（如檔尾雙 CRLF、純逗號行）→ NullReferenceException → 被外層 catch 收進 ErrMsg → 整檔 Result 2 搬錯誤區，錯誤訊息只有無診斷價值的 "Object reference not set..."。同一 helper 的三個 caller 行為分歧是典型兄弟漂移，好檔會因無害空行被整檔拒收。

**證據**：
```
// Tester.cs:142-143
var values = EraseSpecificChar(line);
if (values.Length < 1) continue;
// ImportData.cs:54-55
int first = Array.FindIndex(values, s => !string.IsNullOrEmpty(s));
if (first == -1) return null;
```

**建議**：先各補一條 failing regression test（Tester/UiStatus 檔內含空白行仍應正常解析），再比照 FailPin 在兩處加 `if (values == null) continue;`；或把判斷收斂為 `if (values is not { Length: > 0 }) continue;` 統一三處寫法，杜絕下一個 caller 再踩。

**驗證註記**：Verified against source: ImportData.cs:55 returns null for all-empty lines (contract pinned by EraseSpecificCharTests), FailPin.cs:135-138 guards null, but Tester.cs:142-143 and UiStatus.cs:103-104 dereference values.Length unguarded. Blank line ("" from double CRLF) or pure-comma line is reachable via ReadLine loop → NRE → caught into ErrMsg → caller returns Result 2 + MoveToError, rejecting an otherwise-good file with an undiagnostic message. Not in CONCERNS.md, violates no hard constraint (local null guard, no result-code/async/SQL change), and no existing test pins the NRE behavior so the fix is safe. Minor imprecision only: the catching try/catch is inside the FileRead* method itself, not the outer caller — outcome chain unchanged. Medium severity is calibrated: full-file false rejection per occurrence, but file is preserved in error dir and trigger frequency in production feeds is unknown.

---

### DbUnitOfWork『commit-or-rollback』12 行區塊在 7 個 importer 逐字重複

- **位置**：`DCT_data_import/ReadAndImport/RawData.cs:101`
- **維度**：simplify-dup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：`using (DbUnitOfWork uow = DatabaseService.BeginUnitOfWork()) { result = fileAccess.ImportXxx(...); if (result) uow.Commit(); else uow.Rollback(); }` 這段在 RawData(:101-112)、Tester(:88-99)、FailPin(:77-88)、RecoveryRate(:96-107)、UiStatus(:54-65)、EverySiteItem(:65-76)、TsmcIeda(:67-78) 共 7 處逐字相同（約 84 行）。交易邊界語意是全庫最關鍵的不變量（CONCERNS.md lot 級原子性章節），散在 7 處代表未來調整（例如補 transient retry R-b）要同步 7 個檔。MultiSpecRawData 與 RealTimeDetection 的交易流程刻意不同（跨檔共用 uow / outcome 判斷），不在收斂範圍。

**證據**：
```
using (DbUnitOfWork uow = DatabaseService.BeginUnitOfWork())
{
    import_result = fileAccess.ImportRawData(rawDataContentFormat, DatabaseService, uow);
    if (import_result)
    {
        uow.Commit();
    }
    else
    {
        uow.Rollback();
    }
}
```

**建議**：在 ImportData 基底加 `protected static bool RunCommittedImport(DatabaseService db, Func<DbUnitOfWork, bool> import)`（using + commit/rollback + 回傳結果），7 個呼叫點改一行 lambda。行為零變更，FileProcessImportTransactionCharacterizationTests 與 Integration/ImporterRollbackIntegrationTests 可直接護航。明確不動 MultiSpecRawData / RealTimeDetection 的變體流程。

**驗證註記**：All 7 cited duplication sites verified at exact line ranges (RawData:101-112, Tester:88-99, FailPin:77-88, RecoveryRate:96-107, UiStatus:54-65, EverySiteItem:65-76, TsmcIeda:67-78); wrapper pattern is structurally identical, only the inner import call differs — absorbed by the proposed Func<DbUnitOfWork,bool>. No hard-constraint violation (transaction mechanics only; EverySiteItem piggyback semantics untouched). Not duplicated in CONCERNS.md (transactionalization PRs #45-#49 documented, the 7-site dup itself is not). Benefit concrete: CONCERNS.md R-b (deferred transient retry) would insert exactly at this boundary, requiring 7 synchronized edits today. Fix feasible: all 7 classes extend ImportData; named guard tests exist (FileProcessImportTransactionCharacterizationTests, Integration/ImporterRollbackIntegrationTests). Exclusions verified genuinely different: RealTimeDetection commits on outcome enum (Written||AlreadyComplete), MultiSpecRawData creates uow outside using with RollbackAndFail across a loop.

---

### 環境判定只取第一個 IPv4 且無明確 override,多網卡時可能靜默把 Prod 判成 Dev

- **位置**：`DCT_data_import/Program.cs:357`
- **維度**：config-startup ｜ **工作量**：S ｜ 驗證信心：high（原評 high，驗證後校準）

**問題**：GetLocalIPAddress 回傳 DNS AddressList 中「第一個」IPv4,GetEnvironment 再以硬編 productionIps 比對決定 Prod/Dev。Windows 上 AddressList 順序不保證穩定,prod 機一旦裝了 VPN/Hyper-V/Docker 虛擬網卡,第一個 IPv4 可能不是 10.16.92.67/68,程式會靜默切成 Dev:改連 DevHost=localhost(root/root)、FTP 路徑切到 /DCT_DB_DATA_Dev/,prod 匯入無聲停擺。判定結果只印 Console(Environment: Dev),不寫 file log,重啟後無從追溯。CONCERNS.md 未記載此項。

**證據**：
```
foreach (IPAddress ip in hostEntry.AddressList) { if (ip.AddressFamily == AddressFamily.InterNetwork) { return ip.ToString(); } } ... string[] productionIps = { "10.16.92.67", "10.16.92.68" }; environment = Array.Exists(productionIps, ip => ip == localIp) ? "Prod" : "Dev";
```

**建議**：三步收斂:(1) 支援明確 override(環境變數 DCT_ENVIRONMENT 或 App.config Environment 鍵,有設即用,偵測僅作 fallback);(2) 偵測改掃「全部」IPv4 而非第一個:hostEntry.AddressList.Where(ip => ip.AddressFamily==InterNetwork).Any(ip => productionIps.Contains(ip.ToString()));(3) 啟動時 WriteInfoLog 記錄最終判定與所有偵測到的 IPv4 清單,誤判可稽核。

**驗證註記**：全部證據屬實：Program.cs:353-358 確實回傳 DNS AddressList 第一個 IPv4，:323/:331 硬編 productionIps 比對；誤判 Dev 的後果鏈已驗證（Program.cs:26-31 切 DevHost=localhost/root/root，ImportFileSource.cs:147 FTP 路徑切 /DCT_DB_DATA_Dev/）；判定結果僅 Program.cs:53 Console 輸出、成功路徑無 file log。CONCERNS.md 全文無此項，建議不違反任何硬性約束且與既有 DCT_MYSQL_PASSWORD override 慣例一致，無測試 pin 該行為。唯 severity 校準：「無聲停擺」略誇大——localhost 連不上時每輪輪詢的連線錯誤仍會進 error log（吵但根因不可追溯），且觸發需 prod 機網路拓撲變動（裝 VPN/虛擬網卡），屬 latent 風險非現行缺陷，故 high 降 medium。

---

### 全程式的 file log 只記 ex.Message,無 stack trace 與 InnerException,長駐無人值守服務事後無法定位

- **位置**：`DCT_data_import/Program.cs:239`
- **維度**：config-startup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：Main 的 4 個 catch、3 個 worker top-level catch 與批次迴圈 catch 一律 WriteErrorLog($"...{ex.Message}")。TypeInitializationException 的 Message 是「The type initializer for 'X' threw an exception.」,真因在 InnerException;NullReferenceException 的 Message 無任何位置資訊。DbAccess 部分 catch 有 Console.WriteLine(ex.ToString()) 印完整堆疊,但 console 輸出在服務/排程環境會遺失——持久化的 file log 全程式沒有任何一處記 stack trace。CONCERNS.md 的錯誤可觀測性批次補的是「靜默路徑加 log」,未涵蓋「log 內容缺堆疊」這一層。

**證據**：
```
writeToLog.WriteErrorLog($"[Main] 程式執行時發生嚴重錯誤: {ex.Message}");
Console.WriteLine($"程式執行時發生嚴重錯誤: {ex.Message}");
```

**建議**：最小改:Main 的 4 個 catch 與 3 個 worker top-level catch(ImportTesterMode/ImportUiStatusMode/ImportTsmcMode 最外層)把 WriteErrorLog 的內容改用 ex.ToString()(含型別、InnerException、堆疊),Console 維持 ex.Message 短訊息。批次內 per-db_key 的 catch 可維持 Message 避免洪泛。可加一個 FormatException(Exception) helper 統一格式。

**驗證註記**：核心成立:Main 4 個 catch(Program.cs:209/219/229/239)、3 個 worker top-level catch(:436/:813/:847)與批次迴圈 catch 確實只 WriteErrorLog ex.Message;DbAccess 5 處 ex.ToString() 只進 Console(服務環境遺失)。CONCERNS.md 可觀測性批次只補「靜默路徑加 log」,無任何條目涵蓋「log 內容缺堆疊」,非重複。建議不觸犯任何硬性約束,WriteToLog 無測試 seam 故無測試破壞,ex.ToString() 不含憑證不違 S1/S3。兩點校正:(1)「全程式沒有任何一處記 stack trace」為過度陳述——FileProcess.cs:419 有一處 WriteErrorLog(ex.StackTrace)(212 個 call site 中唯一,僅覆蓋統計驗證 catch,不影響結論);(2) DB 路徑失敗多不擲到這些 catch——DatabaseService.FormatDatabaseError(:504-590)回傳的錯誤字串已含例外型別、MySQL 錯誤碼與 InnerException.Message,最常見的失敗類別已有部分診斷資訊。真正不透明的是非 DB 未處理例外(解析 NRE、thread 錯誤)打到頂層 catch 的情境,那正是長駐無人值守服務事後定位的關鍵面,file log 僅剩無位置資訊的 Message。medium 嚴重度合理。

---

### 寄信失敗只記「寄信失敗!」,失敗原因(SendResult)只印 Console,持久 log 無法區分設定錯 vs SMTP 故障

- **位置**：`DCT_data_import/Common/NotificationService.cs:205`
- **維度**：config-startup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：EmailModels.SendEmail 已細分失敗原因並寫入 SendResult 屬性(收件人清單為空/SmtpServer 未設定/SMTP 錯誤/…),但各失敗分支只 Console.WriteLine;NotificationService.SendMailModelInternal 收到 false 後寫進 file log 的訊息固定是「寄信失敗!」。服務環境 console 遺失後,維運只能從 log 得知信沒寄出,無從判斷是 dct_import_mail_list.ini 缺 mail_to、App.config SMTP 設定壞掉,還是 relay 主機掛了——三者的修復動作完全不同。

**證據**：
```
else
{
    _writeToLog.WriteErrorLog("寄信失敗!");
    return "FAIL";
}
```

**建議**：單行改:_writeToLog.WriteErrorLog($"寄信失敗! 原因: {emailModel.SendResult}")。SendResult 內容為設定鍵名與例外訊息,不含憑證,符合 S1/S3 遮罩約束。

**驗證註記**：Verified against source: NotificationService.cs:205 logs only the fixed string "寄信失敗!" while EmailModels.SendEmail (EmailModels.cs:34,43,56,67,123-141) sets distinct SendResult reasons that are emitted only via Console.WriteLine — persistent file log cannot distinguish missing mail_to vs bad App.config SMTP config vs relay failure. The repo's own 2026-07-01 observability audit (CONCERNS.md 錯誤可觀測性強化) treats exactly this class (Console-only failure detail on an unattended long-running service) as remediation-worthy and fixed sibling paths, but missed this one — so it is a new residual gap, not a documented-debt duplicate. Fix is a safe one-liner: emailModel.SendResult is in scope and public; no test pins the "寄信失敗!" string; SMTP is anonymous internal relay (S4) so SendResult/ex.Message cannot contain credentials, consistent with S1/S3 masking. No hard constraint touched.

---

### TsmcIeda 讀檔/驗證失敗即 return，中止整批剩餘 IEDA 檔案

- **位置**：`DCT_data_import/ReadAndImport/TsmcIeda.cs:62`
- **維度**：gap-audit ｜ **工作量**：S ｜ 驗證信心：high

**問題**：ReadAndImportIeda 以 for 迴圈逐一處理 TSMC_DATA/IEDA/ 目錄下所有檔案，但讀檔內容錯誤（ErrMsg 非空）路徑在 MoveToError 後直接 `return new ImportResult(2, ...)`，跳出整個方法——同迴圈內的匯入失敗路徑（:88-93）與例外路徑（:95-100）都是 continue 繼續處理下一檔。TsmcMode 是 single-pass thread、每 ~7.2 分鐘由 supervisor 重啟一輪，故每出現一個格式壞檔，排在其後的所有好檔都要多等一輪；連續 N 個壞檔時好檔會被延遲 N×7.2 分鐘。且整輪回傳 Result 2 語意誤導（其實只有一個檔壞）。此檔僅被既有 findings 覆蓋 :208（net-name CSV 刪除時機），本缺口未被覆蓋。

**證據**：
```
if (!string.IsNullOrEmpty(iedaDataFormat.ErrMsg))
{
    MoveToError(ftpserver, errorPath);
    return new ImportResult(2, iedaDataFormat.ErrMsg);
}
// 對照同迴圈匯入失敗路徑(:88-93)僅 MoveToError 後繼續下一檔,catch(:95-100)亦 continue
```

**建議**：將 ErrMsg 分支改為與匯入失敗分支一致：MoveToError 後記錄錯誤並 continue 處理下一檔；於迴圈外彙總失敗檔數決定回傳碼（全部成功回 1，有失敗檔回 2/3 並在 Message 列出檔名）。改動限單檔、行為以既有 TsmcIedaImportTransactionCharacterizationTests 加一條「壞檔不阻斷後續檔」regression test 釘住。

**驗證註記**：Verified at TsmcIeda.cs:59-63: ErrMsg path does MoveToError then `return new ImportResult(2, ...)`, aborting the remaining files, while the import-failure branch (:88-93) and catch (:95-100) continue the loop — asymmetry confirmed. Caller ImportTsmcMode (Program.cs:819-852) is single-pass and supervisor restarts it every SupervisorSleepMilliseconds=432000ms (~7.2 min), so drain rate is one bad file per round; N bad files delay trailing good files ~N×7.2 min as claimed. Bad file is moved out before return, so no permanent blockage (self-healing, no data loss). Minor overstatement: the "Result 2 misleading" point is observability-only — TSMC path ignores Result except logging (no db_key bitmask/mail). No hard constraint violated (fix keeps 0/1/2/3 semantics, no async/ComputeImportResult/piggyback/SQL changes). Not in CONCERNS.md (D4 is a different TsmcIeda issue) and not covered by PR#69/#76. Existing TsmcIedaImportTransactionCharacterizationTests only pin ImportIeda transaction behavior, not the loop — the suggested fix plus a new regression test would not break them.

---

## LOW（21 條）

### 每個 INSERT 無條件多打一次 SELECT LAST_INSERT_ID(),批次匯入路徑的語句數翻倍

- **位置**：`DCT_data_import/DbApi/DatabaseService.cs:345`
- **維度**：db-sql ｜ **工作量**：M ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：ExecuteCommandBody 對所有以 INSERT 開頭的語句一律追打一次獨立的 `SELECT LAST_INSERT_ID()` round-trip(DatabaseService.cs:345-357),但全 codebase 實際消費 InsertId 的只有 5 個寫入點(lots_info:359、tester_device_info:626、fail_pin_rate_info:906、fail_pin_rate_list 逐列:956、ieda_title TsmcIeda.cs:288)。其餘 12 條 ExecuteBatchInsert 路徑(lots_result、lots_statistic、recovery_rate、pin_ball、test_result、site_test_statistics、ieda_content、good_lots、anomaly_lots、anomaly_units、anomaly_lot_process_mapping)與 ui_status/tester_status/tester_sw_version/tester_production_analysis 單列 INSERT 全都白付:大 RawData 檔 lots_result 80+ 批就是 80+ 次無效查詢,pin_ball 在現行 50/批下更是每 50 列一次。非交易路徑(ExecuteNonQueryCommand:285)還把它包在 BEGIN/COMMIT 內,再加兩次 round-trip。

**證據**：
```
DatabaseService.cs:344-349 long insertId = 0; if (query.Trim().StartsWith("INSERT", StringComparison.OrdinalIgnoreCase)) { try { insertId = connection.QuerySingleOrDefault<long>("SELECT LAST_INSERT_ID()", transaction: transaction); } ...
```

**建議**：在 DbSqlRequest 或 ExecuteCommand 加 `fetchInsertId` 旗標(預設 false),僅上述 5 個寫入點開啟;或對需要 id 的 INSERT 改為單一 round-trip:`connection.QuerySingleOrDefault<long>(query + "; SELECT LAST_INSERT_ID();", ...)`(text protocol + 同連線,語意不變)。批次路徑(ExecuteBatchInsert)一律不取 id,大檔匯入的 DB 語句數即減半。需同步調整 FileProcess.ExecuteInsert 簽章與 characterization tests(其覆寫 seam 觀測寫入序列,契約會變)。

**驗證註記**：Code claim fully verified: DatabaseService.ExecuteCommandBody (DatabaseService.cs:344-357) unconditionally issues a discarded SELECT LAST_INSERT_ID() round-trip for every INSERT, and only 5 write points consume InsertId (FileProcess.cs:359/626/906/956, TsmcIeda.cs:288) — all 11 ExecuteBatchInsert paths and the single-row tester_*/ui_status INSERTs pay it for nothing. Not a CONCERNS.md duplicate (P1 cites LAST_INSERT_ID only as a future backfill technique) and the flag-based fix violates no hard constraint. However the impact is overstated: (1) the "80+ batches" example contradicts the repo's own R7 evidence — the real 103MB E2E CSV at ~25KB/row yields ~7 byte-capped 16MB batches, not 80+; (2) SELECT LAST_INSERT_ID() is a session-variable read costing one sub-ms round-trip vs multi-MB batch INSERTs, so wall-clock overhead on the hot path is <1% in a non-latency-sensitive background ETL; (3) the BEGIN/COMMIT side-claim is moot — DbAccess has no INSERTs and every production INSERT path passes a DbUnitOfWork, so no INSERT reaches the auto-transaction path; (4) the fix churns the ExecuteInsert virtual seam that three characterization test suites observe. Real efficiency cleanup, but low severity, not medium.

---

### FTP 來源對同一檔案連發兩次 SIZE：Exists 取得 ContentLength 後丟棄，GetLength 再打一次

- **位置**：`DCT_data_import/ReadAndImport/ImportFileSource.cs:222`
- **維度**：io-ftp ｜ **工作量**：M ｜ 驗證信心：high

**問題**：FtpImportFileSource.Exists（:151-176）以 GetFileSize 指令判斷檔案存在，response.ContentLength 已在手卻直接丟棄；RawData（:28,:42）、Tester（:25,:34）、FailPin（:28,:35）、RecoveryRate（:25,:37）緊接著呼叫 GetLength（:222-231）對同一路徑再發一次 GetFileSize——每個有檔案的 db_key 每輪多付一次 FTP 控制通道 round-trip，而檔案大小只用於 check log 顯示。Local 來源無此成本（File.Exists / FileInfo 皆便宜）。

**證據**：
```
ImportFileSource.cs:158 `request.Method = WebRequestMethods.Ftp.GetFileSize;`（Exists 內，回傳 bool 丟棄長度）與 :225 `request.Method = WebRequestMethods.Ftp.GetFileSize;`（GetLength 內）；呼叫端 RawData.cs:28 `bool isFileExist = FileExists(ftpFilePath);` + :42 `long fileSize = GetFileLength(ftpFilePath);`
```

**建議**：在 IImportFileSource 增加 `bool TryGetLength(string path, out long length)`（FTP 端單次 GetFileSize 同時回存在性與長度、550 回 false；Local 端用 FileInfo），四個 importer 以其取代 Exists+GetLength 兩段呼叫；既有 Exists/GetLength 保留給其他呼叫者，介面變更前先 grep 依賴方。

**驗證註記**：全部證據逐行核實成立：Exists(:158) 與 GetLength(:225) 對同一路徑各發一次 FTP GetFileSize，Exists 丟棄已到手的 ContentLength；四個 importer（RawData:28/42、Tester:25/34、FailPin:28/35、RecoveryRate:25/37）確實連續呼叫兩者，且 fileSize 只用於 check log 顯示（另有 MultiSpecRawData:166 第五個呼叫點，finding 未列但強化其論點）。建議不違反任何硬性約束、不與 CONCERNS.md 既載債重複、不與 PR#69/#76 重疊；保留既有 Exists/GetLength 使變更非破壞性（僅兩個測試 fake 需補新成員，finding 已提醒先 grep 依賴方）。效益校準：多付的 SIZE 只在檔案存在被處理那一輪發生、走 KeepAlive 既有控制連線，相對 RETR 下載（可達 ~100MB）成本微小——low 嚴重度自評正確，維持不變。

---

### fail_pin_rate_list_pin_ball / fail_pin_rate_test_result 批次大小硬編 50,大檔多付 100 倍 INSERT round-trip

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:1013`
- **維度**：db-sql ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：全 codebase 的批次 INSERT 都以 MaxInsertBatchRows=5000 + MaxInsertBatchBytes=16MB 雙維度封批(lots_result、lots_statistic、recovery_rate、site_test_statistics、anomaly_* 皆是),唯獨 ImportFailPinLog 的兩張孫表 pin_ball(:1013)與 test_result(:1056)硬編 cutSize=50——這是 #57 批次 builder 去重時逐字保留的 legacy 值,非封包考量(位元組維度已由 BuildBatchRequests 的 MaxInsertBatchBytes 夾制,列很寬也切得住)。大型 fail pin log 的 pin_ball 列數可達數千:例如 10,000 列在 50/批下要 200 個 INSERT 語句(每個又額外附一次 SELECT LAST_INSERT_ID(),見另一 finding),改用 MaxInsertBatchRows 後同量資料只需 2 個。CONCERNS C 項修 lots_statistic 批次退化時未涵蓋這兩處。

**證據**：
```
FileProcess.cs:1013 response = ExecuteBatchInsert(DatabaseService, "fail_pin_rate_list_pin_ball", columns, rows, 50, uow); 以及 :1056 response = ExecuteBatchInsert(DatabaseService, "fail_pin_rate_test_result", columns, rows, 50, uow); 對照 :138 int cutSize = (rows.Count > MaxInsertBatchRows) ? MaxInsertBatchRows : rows.Count;(其他路徑的標準寫法)
```

**建議**：兩處 cutSize 改為與其他路徑一致的 Math.Min(rows.Count, MaxInsertBatchRows)(或直接傳 MaxInsertBatchRows,BuildBatchRequests 自會封批)。安全性由既有 MaxInsertBatchBytes 位元組夾制兜底,無爆 max_allowed_packet 疑慮;FileProcessBuildBatchRequestsTests 已鎖 byte-split 契約,僅需補一條驗證新 cutSize 的 characterization test。

**驗證註記**：All cited evidence verified: FileProcess.cs:1013/:1056 hard-code cutSize=50 while every other batch path uses Math.Min(rows.Count, MaxInsertBatchRows=5000); git show cbc936a (PR #57) confirms 50 is a verbatim legacy carry-over of the old "每50個row就匯入一次" loop, not a packet-size decision; BuildBatchRequests always applies the 16MB byte guard so raising cutSize is packet-safe; each INSERT batch does cost an extra SELECT LAST_INSERT_ID() round-trip (DatabaseService.cs:345-349). No hard constraint violated, no test pins the 50 (characterization fixture is 1 row; InsertId unused after these calls, so behavior is unchanged), and CONCERNS.md item C only fixed lots_statistic — this residue is undocumented. Severity is overstated though: on the same import path the parent fail_pin_rate_list must insert per-row (insertId feeds child FK), so parent round-trips dominate total import RTT and the standalone win from this fix is modest; the service is a long-poll batch worker where the main benefit is a shorter transaction hold window. Calibrated to low.

---

### ImportRawDataCore 的 lots_result 逐 cell 迴圈:每 cell 最多 9 次迴圈不變的欄名比較 + 最多 3 次重複 ToString()/Trim()

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:516`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：lots_result 是最大的表(一 unit 一列;103MB E2E 等級的檔為數十萬列 × ~11 欄 = 數百萬 cell)。內層 j 迴圈對每個 cell 重複做欄名分類:line 516 六個 ColumnName 比較、line 520 兩個、line 524 一個——全部是迴圈不變式(欄序整檔固定),卻每 cell 重算。命中特殊欄時同一 cell 值又被 Rows[i][j].ToString().Trim() 取 2~3 次(如 real time 欄:516 一次、528 一次、530 再 ToString 一次),每次 ToString/Trim 都是新字串配置。合計數百萬次多餘比較與字串配置,落在單檔匯入的最熱路徑。

**證據**：
```
if ((content.LotResult.Columns[j].ColumnName == "SN Num" || content.LotResult.Columns[j].ColumnName == "SiteID" || content.LotResult.Columns[j].ColumnName == "real time" || content.LotResult.Columns[j].ColumnName == "X" || content.LotResult.Columns[j].ColumnName == "Y" || content.LotResult.Columns[j].ColumnName == "P/F") && content.LotResult.Rows[i][j].ToString().Trim() == string.Empty)
... else if (content.LotResult.Columns[j].ColumnName == "real time") {
  if (DateTime.TryParse(content.LotResult.Rows[i][j].ToString().Trim(), out out_dateTime)) {
    cells.Add(InsertCell.Param(ConvertEmptyToDefaultString(content.LotResult.Rows[i][j].ToString())));
```

**建議**：進 row 迴圈前先掃一次 Columns 建 per-column 分類陣列(enum:NullableIfEmpty / ZeroIfEmpty / RealTime / Regular),row 迴圈內以 `var kind = kinds[j]` switch 分派;cell 值 `string raw = content.LotResult.Rows[i][j].ToString();` 取一次、`string trimmed = raw.Trim();` 一次,後續全部重用。單一方法內改動、輸出 SQL 逐字元不變,現有 characterization test(ExecuteInsert 攔截)可直接驗證等價。

**驗證註記**：程式碼與行號完全屬實（FileProcess.cs:516/520/524/528/530），欄名比較確為迴圈不變式且每 cell 重算，建議的 per-column kind 預掃描是局部、行為等價、不違反任何硬性約束的合法清理，且非 CONCERNS.md（P1/R7）或 PR#69 已涵蓋項目。但嚴重度被高估為 medium：(1) 配置聲稱大半不成立——LotResult 欄位皆 typeof(string)（ImportData.cs:366,394-397），string.ToString() 回同一參考零配置、Trim() 無空白時回原實例、DBNull.ToString() 回快取 Empty，「每次 ToString/Trim 都是新字串配置」在常見情況為假；(2) 剩餘成本是每 cell ~9 次快速失敗的 ordinal 比較＋重複 DataRow indexer，5.5M cells 約為亞秒級，對照 big5 解析、DataTable 建置、每 cell 必然的 InsertCell/DynamicParameters 配置與 ~100MB MySQL 網路 INSERT，實際 wall-clock 收益估低個位數百分比；(3)「現有 characterization test 可直接驗證等價」亦誇大——ExecuteInsert seam 存在且攔得到 lots_result，但現有 fixture 只有 Serial 欄，特殊欄分支（SN Num/real time/test time 等）無覆蓋，須先補測試。屬真實但低價值的 micro-optimization，correctedSeverity=low。

---

### CalculateSPC.SeperatePassValue 以 List.RemoveAt 逐一剔除 fail 值,最壞 O(n × fail_n) 的元素搬移

- **位置**：`DCT_data_import/Common/CalculateSPC.cs:148`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：RawData/MultiSpec 匯入前每張 statistic table 都跑 AverageOfSumSquare;value 清單長度 = unit 數(大檔數十萬)。SeperatePassValue 從尾端反向掃描、對 out-of-spec 值呼叫 List.RemoveAt(i)——每次 RemoveAt 把 i 之後的所有元素左移一格,成本 O(Count-i)。當 fail 值集中在清單前段且 # of FAIL 大時,總成本 O(n × fail_n),對 10 萬值 × 數千 fail 即上億次元素搬移,而且是每張測項表各跑一次。PR#69 只處理了 FilterByFirstOccurrenceIndex 的 O(n²),這條仍在。

**證據**：
```
for (int i = double_values.Count - 1; i >= 0; i--)
{
    if (double_values[i] > spec_max || double_values[i] < spec_min)
    {
        double_values.RemoveAt(i);
        fail_count++;
    }
    if (fail_count == fail_n) break;
}
```

**建議**：改兩段式 O(n):先反向掃描把要剔除的索引記進 bool[](至多 fail_n 個、break 條件不變),再單趟正向重建新 List<double> 跳過標記索引。語意逐項等價(仍是「由尾端起最多剔 fail_n 個 out-of-spec 值」),可用現有 CalculateSpcTests 加一條大清單 + 前段 fail 的等價 regression 鎖行為。

**驗證註記**：Code verified at CalculateSPC.cs:144-152, evidence matches verbatim, O(n×fail_n) analysis correct, not covered by PR#69 (which fixed FilterByFirstOccurrenceIndex in ImportData.cs) nor CONCERNS.md, and the two-pass fix is exactly semantics-preserving with no constraint violation. However, severity is overstated: the "數十萬 unit" premise lacks repo evidence — the largest documented real file (CONCERNS R7, 103MB at ~25KB/row) implies ~4k units/lot, with # of PASS ≥ 10000 (item C) as the realistic ceiling (~10^4, not 10^5). At that scale the RemoveAt cost is vectorized double memmove totaling milliseconds-to-low-seconds even in pathological high-fail lots, dwarfed by 103MB CSV DataTable parsing and per-row child-table INSERT round-trips (P1's noted real bottleneck), in a batch pipeline with ~7-minute polling cadence. Worth doing as a cheap local cleanup consistent with PR#69 precedent, but low severity.

---

### FileReadFailPinLog 在逐 pin 迴圈內重算同一 DUT 的 remark:String.Join(fail_pin_log) × fail pin 數

- **位置**：`DCT_data_import/ReadAndImport/FailPin.cs:259`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：每個 DUT 列解析後,對其 fail_pin_list 逐 pin 建一列 pin_ball,remark 欄填 String.Join(",", fail_pin_log.ToArray())——join 結果對同一 DUT 恆等,卻在迴圈內每 pin 重算一次(外加 ToArray 複製一次)。fail 密集的 DUT 有 k 個 fail pin、log 有 m 項時,配置量為 O(k × m) 而非 O(m);一個 fail-heavy 檔上千 DUT 累積即數十 MB 級的重複字串配置。

**證據**：
```
for (int i = 0; i < fail_pin_list.Count; i++)
{
    DataRow dr_fail_pin_rate_list_pin_ball = failPinLogContentFormat.Fail_pin_rate_list_pin_ball.NewRow();
    ...
    dr_fail_pin_rate_list_pin_ball["remark"] = String.Join(",", fail_pin_log.ToArray());
```

**建議**：把 join 提出迴圈:在 `for (int i = 0; i < fail_pin_list.Count; i++)` 之前做 `string remark = string.Join(",", fail_pin_log);`(List<string> overload 免 ToArray),迴圈內填 `dr[...]["remark"] = remark;`。單檔單點修改,輸出值逐字元不變。

**驗證註記**：FailPin.cs:259 確實在逐 pin 迴圈內每次重算 String.Join(",", fail_pin_log.ToArray())，而 fail_pin_log 在該迴圈（244–261 行）內不變（僅於 225 行填入），join 結果對同一 DUT 恆等，ToArray 又多一次複製；且每列 DataRow 各持有一份獨立字串直到匯入完成，非純瞬時配置。建議的 hoist 為單行、行為逐字元不變、不觸犯任何硬性約束，亦未與 CONCERNS.md 重複（P1 是 FileProcess.cs 的 += 假前提，不同檔不同機制；PR#69 未動此迴圈）。但 severity 應下修：CONCERNS.md P1 已實證此類 parse 路徑的真實瓶頸是逐列 INSERT round-trip 而非字串工作，配置多為 Gen0 短命，「數十 MB」是推測性最壞情況——屬合理但低影響的微優化。

---

### ImportUIStatus / ImportFailPinLog / ImportTesterStatus 在逐 cell 迴圈內配置迴圈不變的查表陣列並重複 ToLower/ToString

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:820`
- **維度**：alloc-parse ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：ImportUIStatus 的內層 j 迴圈(每列 × 每欄執行)每個 cell 都 new 一個 17 元素 string[](陣列本體 ~160B/次),再對 ColumnName 呼叫 ToLower()(line 821、825 各一次,皆新字串),cell 值 Rows[i][j].ToString().Trim() 在條件鏈中最多取 4 次。22 欄 × N 列的 ui_status 檔即 22N 次陣列配置 + 44N 次 ToLower + 最多 88N 次 ToString/Trim。同一反模式:line 935(fail_pin_rate_list 的 doubleTypeColumn,列數 = DUT 數,同樣熱)、line 661(tester_status,僅跑一列、影響小)、line 579(tester_device_info,每欄一次)。這些查表集全是編譯期常數,不該進迴圈。

**證據**：
```
for (int j = 0; j < content.UI_status.Columns.Count; j++)
{
    string[] numTypeColumn = { "auto_learn", "dct_product_file_setting_ui", ... "dct_downloadtp_kh" };
    if (numTypeColumn.Contains(content.UI_status.Columns[j].ColumnName.ToLower()) && (content.UI_status.Rows[i][j].ToString().Trim() == string.Empty || content.UI_status.Rows[i][j].ToString().Trim() == "NA"))
```

**建議**：各查表集抽成 `private static readonly HashSet<string>`(建構時傳 `StringComparer.OrdinalIgnoreCase`,同時取代 ToLower 呼叫——順帶消掉 culture-sensitive ToLower 的 tr-TR 隱患);cell 值取一次存局部變數 `string cell = content.UI_status.Rows[i][j].ToString(); string trimmed = cell.Trim();` 重用。四處(FileProcess.cs:579,661,820,935)同 PR 一次收斂,行為等價(HashSet.Contains + OrdinalIgnoreCase 對這些純 ASCII 欄名與原 ToLower+Contains 結果相同)。

**驗證註記**：Evidence 全數屬實：FileProcess.cs:820（17 元素陣列每 cell 配置 + 2×ToLower + 最多 4×ToString/Trim）、:935（每 DUT 列 × 每欄配置）、:661/:579（單列、影響小，finding 已自行標註）皆與現碼一致。建議不違反任何硬性約束，且修法行為等價已驗證：FileContentFormat.cs:176-180/:202-206 對 Tester_status/UI_status header 做 exact-case 白名單驗證、fail_pin_rate_list 欄名為程式內定義小寫（FileContentFormat.cs:229-232），OrdinalIgnoreCase HashSet 對可達輸入結果不變。但 severity=medium 高估：這些迴圈每列都付一次同步 ExecuteInsert DB round-trip（FileProcess.cs:841、:949），CONCERNS.md P1 已對同一批迴圈裁定「真實成本是逐列 INSERT RTT、字串微優化是白工」——每列數 KB 的 gen0 配置相對每列一次網路 RTT 不可量測，且服務為 ~7 分鐘輪詢批次。殘餘價值是 code hygiene + 消除 culture-sensitive ToLower（與先前 K 項 DBmysql ToUpper→Ordinal 修復同類），屬 Low。與 P1 非重複（P1 講字串累加，未涵蓋查表陣列與 ToLower culture 面向），有新增資訊。

---

### 每寫一筆 log 就做一次 retention 全目錄掃描（DeleteExpiredLogFiles）＋具名 Mutex 建立＋SHA256＋開關檔

- **位置**：`DCT_data_import/Common/WriteToLog.cs:68`
- **維度**：io-ftp ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：WriteToDataImportLog（:68）、WritePiggybackSkipLog（:130）、WriteImportSuccessLog（:171，且在重試迴圈內每次 attempt 都掃）、WriteToCheckLog（:271）在『每一筆』寫入前都呼叫 DeleteExpiredLogFiles：枚舉 log 目錄 1-2 個 glob pattern 並對每個檔案 File.GetLastWriteTime。預設保留 90 天、每日分檔（主 log + success log + piggyback + check log），目錄常態近 200 檔——全 repo 有 249 個 log 寫入呼叫點，熱迴圈（每個 db_key 缺檔記 Info、每次 RawData 成功記 piggyback skip、每檔記 check log）每行 log 都付一次全目錄枚舉＋stat。每筆寫入還重算 SHA256 mutex 名稱、建立/釋放 kernel 具名 Mutex、開關 StreamWriter。開關檔與 Mutex 屬跨程序安全的刻意設計可保留，但 retention 掃描一天掃一次就夠。

**證據**：
```
WriteToLog.cs:68 `DeleteExpiredLogFiles(logDirectory, "DCT_data_import_Log_*.txt", "DCT_data_import_Success_Log_*.txt");`（WriteToDataImportLog 每次呼叫都執行；同模式 :130、:171、:271）
```

**建議**：加一個 static DateTime（每 log 家族一個，Interlocked/lock 保護）記錄上次清掃日，DeleteExpiredLogFiles 僅在跨日（或行程啟動首寫）時執行；行為不變（過期檔最晚隔日清），單檔小改。順帶消除兩 thread 同時 File.Delete 的良性 race 噪音。

**驗證註記**：Evidence fully verified: WriteToLog.cs:68/:130/:171/:271 all invoke DeleteExpiredLogFiles per write (line 171 inside the retry loop), with per-write SHA256 mutex-name hashing and kernel named-Mutex churn; hot-loop callers (EverySiteItem.cs:26, RealTimeDetection.cs:50, 5 importers' check-log writes) and ~235 call sites confirmed. Not a CONCERNS.md duplicate — R4 records retention cleanup exists but not its per-write scan cost. Suggestion violates no hard constraint and overlaps no recent PR. Severity downgraded to low: per-write cost is single-digit ms against a ~7.2-min polling cadence, log volume is bounded per-file (per-row logging was deliberately aggregated), and there is no observed symptom — waste is real but not medium-impact. Caveat for implementers: a naive process-wide static latch would make WriteToLogPathTests.WriteLogs_WhenRetentionEnabled_DeletesOnlyExpiredKnownLogFiles order-dependent; key the latch per directory or add an internal test-reset hook (matching the existing SetLogRootOverrideForTests pattern).

---

### EmitStaleStatusHints 對已完成的 single-pass worker 每輪必發假「逾時提示」,常態噪音淹沒真 stuck 訊號

- **位置**：`DCT_data_import/Program.cs:512`
- **維度**：threading ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：三條 worker(ImportTesterMode/ImportUiStatusMode/ImportTsmcMode)都是單趟執行後 thread 死亡、由 supervisor 每 7.2 分鐘(SupervisorSleepMilliseconds=432000)重啟。worker 通常數秒內完成並發布終態「重試中/本輪完成」後死亡,其 LastUpdatedAt 在 supervisor 睡眠期間必然超過 90 秒門檻——EmitStaleStatusHints 於是每一輪對 TesterMode/UiStatusMode/TsmcMode 加 Supervisor 自身(睡前發布的「重試中」也會過期)各印一次「仍在處理中,已 N 秒未更新」,但 worker 實際已完成或正常閒置。結果是 90 秒 stale 偵測在常態運行下每輪產生 4 筆假陽性,真正卡死的 worker 警示與例行噪音無法區分,偵測機制形同失效。ProgramWorkerStatusTests 只釘了門檻機制(stale 翻轉/fresh 不翻),未涵蓋「已完成 worker 不應告警」語意。

**證據**：
```
TimeSpan staleTime = now - pair.Value.LastUpdatedAt;
if (staleTime < WorkerStaleThreshold) { continue; }
...
Reason = $"仍在處理中，已 {Math.Round(staleTime.TotalSeconds)} 秒未更新；可能原因: {pair.Value.Reason}",
```

**建議**：在 EmitStaleStatusHints 對終態 stage(「重試中」,即本輪完成等待下一輪)直接 continue 跳過 stale 判定;或於 worker 方法 return 前發布明確的「已完成」stage 並讓 stale 檢查排除之。同步更新 ProgramWorkerStatusTests 加一條「終態不告警」案例。改動侷限 Program.cs 單檔。

**驗證註記**：機制屬實：worker 為單趟執行（ImportTesterMode/UiStatusMode/TsmcMode 無內部迴圈，Program.cs:370-441/745/819），發布終態「重試中」後 thread 死亡；supervisor 睡 432000ms（:23，≈7.2 分）期間 SleepWithHeartbeat 每 10 秒呼叫 EmitStaleStatusHints（:491），90 秒門檻（:22）後 3 個 worker + Supervisor 自身（:178 睡前「重試中」）必然全數過期，「逾時提示」latch（:507）限每輪各一次 → 常態每輪 4 筆假「仍在處理中」提示；ProgramWorkerStatusTests:119-175 確實只釘門檻翻轉、無「終態不告警」案例。建議修法侷限單檔、不觸任何硬性約束，CONCERNS.md 亦無此項記載。但嚴重度被高估：(1) 提示只印 Console、明確不寫 log 檔（:529-530，測試 :158-164 釘死），file-log 監控與 DB remark 完全不受影響（_workerRuntimeStatuses 無其他消費者）；(2) 提示帶原 Reason（「可能原因: 本輪 Tester 匯入完成」vs「本輪共 N 筆待處理」），人工可區分完成 vs 卡死，「無法區分」屬過度陳述——真正的害處是「仍在處理中」對已完成 worker 是事實錯誤文案 + 告警疲勞削弱該功能意圖；(3) 零功能/資料影響。故成立但校準為 low。

---

### EmitStaleStatusHints 無條件 indexer 覆寫與 worker 併發 PublishWorkerStatus 有 lost-update race

- **位置**：`DCT_data_import/Program.cs:527`
- **維度**：threading ｜ **工作量**：S ｜ 驗證信心：high

**問題**：EmitStaleStatusHints 在 supervisor thread 的 SleepWithHeartbeat 期間執行,與 worker thread 的 PublishWorkerStatus(:471,同為 indexer 寫入)併發。supervisor 讀取 pair.Value 快照後到 :527 覆寫之間,worker 可能剛發布一筆全新進度狀態;supervisor 以基於舊快照的「逾時提示」(帶舊 LastUpdatedAt)把它蓋掉,worker 的最新狀態遺失直到其下一次發布。ConcurrentDictionary 保證單操作原子,但 read-modify-write 序列本身不原子。影響僅限主控台可見度(狀態短暫錯誤、自癒),故列 low,但修法成本極低。

**證據**：
```
_workerRuntimeStatuses[pair.Key] = staleStatus;  // 無條件覆寫,非 CAS
```

**建議**：改用 _workerRuntimeStatuses.TryUpdate(pair.Key, staleStatus, pair.Value) 做 CAS:僅當字典中仍是讀取時的舊實例才覆寫,worker 剛發布新狀態時 CAS 失敗即放棄本次提示(下一 heartbeat slice 會重判)。單行改動。

**驗證註記**：Evidence verified line-by-line: Program.cs:527 is an unconditional indexer overwrite in EmitStaleStatusHints (supervisor/main thread, via SleepWithHeartbeat at :193) while worker threads concurrently write the same ConcurrentDictionary via PublishWorkerStatus at :471; the read-modify-write is non-atomic so a worker publish in the window is lost and replaced by a stale hint carrying the old LastUpdatedAt (:524), with the :507 "逾時提示" latch suppressing further hints until the worker next publishes — exactly as claimed. Not in CONCERNS.md (R6 is a distinct DB-level multi-instance TOCTOU). Impact is honestly scoped: the dictionary's sole consumer is EmitStaleStatusHints itself, so effect is console visibility only, self-healing — low is correct. Proposed TryUpdate CAS is sound (WorkerRuntimeStatus has no Equals override, so default comparer is reference equality), violates no hard constraint, and the existing single-threaded test EmitStaleStatusHints_WithStaleAndFreshWorkers_FlipsOnlyStaleToTimeoutHint still passes since the reference is unchanged between read and write. Only caveat: the race window is microseconds and requires a worker to publish exactly then after 90+ s of silence, so real-world frequency is very low — but that is already priced into the low severity.

---

### 08:00–08:10 通知窗與 7.2 分鐘輪詢週期錯配:同窗可重複寄信、長匯入時整窗錯過

- **位置**：`DCT_data_import/Program.cs:381`
- **維度**：threading ｜ **工作量**：S ｜ 驗證信心：high

**問題**：SendDataMissingNotification 的觸發條件是「hour==8 且 minute∈[0,10)」,而 Tester worker 由 supervisor 每 432000ms(7.2 分鐘)重啟一次:10 分鐘窗內可落入兩次 pass(例 8:01 與 8:08),同一天寄出兩封資料遺失警告;反之若前一輪 Tester pass 因大檔匯入拖過 7.2 分鐘,下一次 pass 可能整個錯過 10 分鐘窗,該日警告靜默漏發。ShouldSendProgramStatusNotification(NotificationService.cs:222,週一 8:00-8:10)掛在 supervisor 迴圈上有同樣的重複問題(supervisor 睡眠固定 7.2 分鐘,錯過面較小)。純輪詢時間窗邏輯,無執行緒安全問題,但通知去重/保證送達目前完全依賴時間巧合。

**證據**：
```
if (DateTime.Now.TimeOfDay.Hours == 8)
{
    if (DateTime.Now.TimeOfDay.Minutes >= 0 && DateTime.Now.TimeOfDay.Minutes < 10)
    {
        _notificationService.SendDataMissingNotification("Tester");
```

**建議**：以「最後寄送日期」做冪等:static DateTime(單 process 即夠,三 thread 中只有 Tester thread 觸發此通知)或落地小標記檔記錄 yyyy-MM-dd,當日已寄則跳過;窗口判定改為「今天尚未寄且現在時刻已過 08:00」即同時消除重複與漏發。NotificationService 的週報同法。改動小、可單元測試(注入時鐘或抽 ShouldSend 純函式已有 seam)。

**驗證註記**：Verified against source: Program.cs:379-387 window check and NotificationService.cs:219-223 both exist as quoted; supervisor cadence is 432000ms (Program.cs:23,193) with worker restart-per-loop, and the send path (SendDataMissingNotification → SendMailModelInternal → EmailModels.SendEmail) has zero dedup (only a DryRun short-circuit). In the data-missing scenario the Tester pass is fast, so checks recur every ~7.2 min and two checks fall inside the 10-min window whenever the first lands in [8:00,8:02.8) — duplicate emails on ~39% of data-missing mornings. The miss scenario is also mechanically real: aliveness is sampled only after the sleep, so a pass >7.2 min stretches cadence to ~14.4 min > window, plausible exactly when FTP is slow/failing. Not covered by CONCERNS.md; the suggested last-sent-date idempotency violates no hard constraint and is local/testable. Severity low is correctly calibrated: operational annoyance (duplicate mail) plus a low-frequency silent miss of a monitoring alert, no data corruption. Note the category label "threading" is inapt (pure time-window logic, as the finding itself admits) but this does not affect validity.

---

### 統計值 double 解析/字串化全程 culture-sensitive,逗號小數 locale 下矽默寫入錯誤數值

- **位置**：`DCT_data_import/Common/CalculateSPC.cs:69`
- **維度**：quiet-correctness ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：Program.cs 啟動未固定任何 culture(已 grep 確認無 DefaultThreadCurrentCulture / CurrentCulture 設定),而 CSV 是固定用 '.' 小數點的協定字串。CalculateSPC 的量測值陣列與 Spec MAX/MIN(:49,:54,:69,:134)、FailPin 的 test result 數值(FailPin.cs:232)、FileProcess.ValidateAndConvertStatisticValue 的 stdev/avg/cp/cpk(FileProcess.cs:1443)全用無 culture 參數的 double.TryParse(吃 CurrentCulture)。在群組分隔符為 '.' 的 locale(de-DE、fr-FR 等)下,"1.23" 會解析成 123(.NET 不驗證千分位群組位數)——TryParse 回 true、不進任何錯誤分支,avg/avg2/stdev 以百倍/千倍錯值矽默寫入 lots_statistic。寫出腿同樣裸奔:lots_statistic INSERT 以 item?.ToString()(FileProcess.cs:465)把 boxed double 轉字串,逗號小數 locale 下產生 "0,333" 送進 MySQL DOUBLE 欄。目前 production Windows(zh-TW/en-US)為 '.' 小數點所以 latent,但同庫較新程式碼(EverySiteItem.cs:132、RealTimeDetection.cs:390、FileProcess.ToValueCell:1209)已全面綁 InvariantCulture,這批舊路徑是硬化不一致的殘留。

**證據**：
```
CalculateSPC.cs:69: if (double.TryParse(split_str[str_id], out out_d))  /  CalculateSPC.cs:49: if (!double.TryParse(content.LotStatistic.Tables[i].Rows[0]["Spec MAX"].ToString(), out spec_max))  /  FileProcess.cs:1443: if (double.TryParse(trimmedValue, out double result))(對照 RealTimeDetection.cs:390 已用 NumberStyles.Float, CultureInfo.InvariantCulture)
```

**建議**：比照 RealTimeDetection.ParseDouble 的既有寫法,把 CalculateSPC.cs(4 處)、FailPin.cs:232、FileProcess.cs:1443 的 double.TryParse 補上 NumberStyles.Float + CultureInfo.InvariantCulture;lots_statistic 寫出腿(FileProcess.cs:465)對 IConvertible 數值型別改 Convert.ToString(item, CultureInfo.InvariantCulture)。各補一條 exotic-culture(de-DE)下解析結果不變的 regression test(模式沿用 DateTimeParserCultureTests 的 culture 切換 scaffold)。

**驗證註記**：全部證據親自核實成立:CalculateSPC.cs:49/54/69/134、FailPin.cs:232、FileProcess.cs:1443 確為無 culture 參數的 double.TryParse,Program.cs 零 culture 設定,且寫出腿比 finding 描述更完整——AddColumnForDataset(FileProcess.cs:1402)以 typeof(double) 建 avg_2 欄使 FileProcess.cs:465 的 item?.ToString() 真的對 boxed double 吃 CurrentCulture,另 :409/:1405 的 DataTable 隱式 double/decimal→string 轉換同樣 culture 敏感。對照組(RealTimeDetection.cs:390 等已綁 InvariantCulture)屬實,硬化不一致成立;CONCERNS.md 僅載已修的 J(DateTime)/K(ToUpper),本批未記載、非重複。建議不違反任何硬性約束且複製 repo 既有 ParseDouble 寫法,落地行為變更風險實質為零(值內不可能含千分位逗號)。唯一校準點:嚴重度——production 固定 Windows zh-TW/en-US、CI ubuntu/macos 皆 '.' 小數點,當前所有部署面不可觸發(finding 自認 latent),且 repo 對同觸發類已修項 J/K 皆評 Low;依 repo 內部校準應降為 low(爆炸半徑較大但觸發前提相同)。

---

### DB-bound DateTime 字串化 4 處缺 InvariantCulture,與已修復的 CustomizeDateTimeParser 不一致

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:215`
- **維度**：quiet-correctness ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：CONCERNS.md finding A/J 已把 CustomizeDateTimeParser 的 parse+format 兩腿綁 InvariantCulture(FileProcess.cs:199,205),但三個兄弟路徑只修了 parse 腿、format 腿仍吃 CurrentCulture:(1) ValidateDateTime(:215,:220,寫 recovery_rate.date);(2) ImportTesterStatus start_time/end_time(:589,寫 tester_device_info);(3) EverySiteItem piggyback 的 ToDateTimeCell(:1223,寫 site_test_statistics)。自訂格式字串中 ':' 是 time-separator specifier 非字面字元,更危險的是 'yyyy' 跟隨 culture 曆法——th-TH(佛曆)會把 2026 渲染成 2569、ar-SA(Um-Al-Qura 曆)整組日期平移,產出「格式合法但年份錯 543 年」的字串矽默寫入 MySQL datetime 欄,TryParse 不會失敗、無任何 log。DateTimeParserCultureTests 只鎖已修復的 CustomizeDateTimeParser,FileProcessHelperTests 的 ValidateDateTime 測試未跨 culture,此 gap 無測試防護。production Windows locale 下 latent,但修法與 finding A/J 完全同型、單檔 4 行。

**證據**：
```
FileProcess.cs:215: return result.ToString("yyyy-MM-dd HH:mm:ss");  /  :220: return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");  /  :589: datetime.ToString("yyyy-MM-dd HH:mm:ss")  /  :1223: return InsertCell.Param(dt.ToString("yyyy-MM-dd HH:mm:ss"));(對照 :199,:205 已帶 CultureInfo.InvariantCulture)
```

**建議**：4 處 ToString 補第二參數 CultureInfo.InvariantCulture(與 :199/:205 對齊)。regression:把 DateTimeParserCultureTests 的 ar-SA/th-TH culture 切換 scaffold 套到 ValidateDateTime 與 BuildEverySiteItemRows(後者已是 internal static 可測 seam),斷言輸出 literal 跨 culture 不變。附帶:FileProcess.cs:528 與 :587 的 DateTime.TryParse parse 腿仍吃 CurrentCulture,DateTimeRoundTripCaptureTests 已將其釘為特性化行為,若要一併硬化須先確認 production CSV 日期格式集合再綁定,勿與本修混批。

**驗證註記**：All 4 evidence lines verified verbatim in FileProcess.cs (:215/:220 ValidateDateTime, :589 ImportTesterStatus, :1223 ToDateTimeCell) — each formats DB-bound datetime with culture-sensitive ToString while sibling CustomizeDateTimeParser (:199/:205) already binds InvariantCulture on both legs. Mechanism is real (yyyy follows culture calendar under ICU; MySQL silently accepts year 2569/1447), no hard-constraint violation, not a CONCERNS.md duplicate (A/J covers only CustomizeDateTimeParser; this is the unpropagated remainder), test-gap claim verified (DateTimeParserCultureTests only exercises CustomizeDateTimeParser; BuildEverySiteItemRows internal static seam exists at :1155), and the fix is behavior-preserving under Gregorian ':' cultures so no test breaks. Severity calibrated Medium→Low: trigger requires a non-Gregorian-default-calendar or non-':' host locale, production is Windows zh-TW/en-US (Gregorian), and CONCERNS.md's own precedent rated the identical bug class (finding J, same method, latent ar-SA drift) as Low. Minor framing slip (claims siblings "fixed parse leg only" but :587 parse leg was never fixed) is self-corrected in the finding's own addendum and does not invalidate it.

---

### CSV header→DB 欄名映射用 culture-sensitive ToLower(),tr-TR locale 下產生錯誤 identifier

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:428`
- **維度**：quiet-correctness ｜ **工作量**：S ｜ 驗證信心：high

**問題**：FileProcess 多處把 CSV 欄名經 ColumnName.ToLower() 直接變成 SQL identifier:lots_statistic(:428)、recovery_rate(:233 及 :236-241 的 "DB Key".ToLower() 等常數比對)、lots_info(:320-329)、tester_device_info(:572)。ToLower() 吃 CurrentCulture,土耳其語系(tr-TR/az-AZ)的 'I'→'ı'(無點):"Item Name"→"ıtem_name"、"Spec MIN"→"spec_mın",產生的 backtick identifier 在 MySQL 是不存在的欄 → 整檔匯入失敗(Result 2/3)。屬 loud failure 非矽默,且 production locale 下 latent,列 low;但 CONCERNS.md finding K 已為同族問題(DBmysql ToUpper)修過一次(改 OrdinalIgnoreCase/ToUpperInvariant),這批 ToLower 是漏網同款。

**證據**：
```
FileProcess.cs:428: string column_name = content.LotStatistic.Tables[0].Columns[i].ColumnName.ToLower();  /  :236: if (column_name == "DB Key".ToLower()) column_name = "db_key";
```

**建議**：全部改 ToLowerInvariant()(行為對 ASCII 完全等價,零風險);:236-241 這類常數比對可直接寫小寫字面值省掉運算。與 finding K 的修復慣例一致。

**驗證註記**：All cited call sites verified present (FileProcess.cs:428, :233/:236-241, :320-329, :572; grep shows 20+ ToLower() identifier sites total). Mechanism is real: no InvariantGlobalization in csproj and no DefaultThreadCurrentCulture pinning, so ToLower() follows OS locale; under tr-TR, real headers like "Item Name"/"Spec MIN" on the :428 path become nonexistent identifiers (ıtem_name/spec_mın) causing loud import failure. Minor overstatement: the :236-241 constant comparisons are self-consistent (both sides ToLower same culture) so remapped columns survive; breakage is only on pass-through columns — which :428/:572 paths have. Not a CONCERNS.md duplicate (finding K covered the removed DBmysql ToUpper, these sites are unrecorded). Fix (ToLowerInvariant) is ASCII-equivalent, zero-risk, and matches the codebase's own K/J culture-fix precedent and line 260's OrdinalIgnoreCase. Violates no hard constraint. Low severity is correctly calibrated: latent under production zh-TW locale, loud (Result 2/3) not silent when triggered.

---

### check-log/成功 log 時戳的 '/' 與 ':' 是 culture separator specifier;另回報 hh 殘留現況已清零

- **位置**：`DCT_data_import/Common/WriteToLog.cs:162`
- **維度**：quiet-correctness ｜ **工作量**：S ｜ 驗證信心：high

**問題**：受命查證的 (a) 項現況:全庫 grep 小寫 'hh' 格式字串,production code 已零殘留(僅 DateTimeRoundTripCaptureTests 保留 hh 斷言作為 BCL 佐證,且該測試的 ProductionSources_DoNotUseAmbiguousTwelveHourTimestampFormat 已機械守護不回退)——記憶中「check-log 5 處 live 殘留」已過時。殘餘小問題:log 時戳格式的 '/'(date separator)與 ':'(time separator)是 culture specifier 非字面字元——WriteToLog.cs:162 的 $"{DateTime.Now:yyyy/MM/dd HH:mm:ss}" 與五個 importer 的 WriteToCheckLog 行(RawData.cs:119、Tester.cs:106、RecoveryRate.cs:114、FailPin.cs:95、MultiSpecRawData.cs:215)在非預設 separator 的 locale 下會產出 "2026.07.16" 這類漂移格式,污染 check_logs CSV 的 Time 欄位一致性。純 log/CSV 可觀測性,不觸 DB,列 low。

**證據**：
```
WriteToLog.cs:162: string logMessage = $"{DateTime.Now:yyyy/MM/dd HH:mm:ss} [SUCCESS] {message}";  /  RawData.cs:119: ... + DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss") + ...(皆無 IFormatProvider)
```

**建議**：6 處補 CultureInfo.InvariantCulture(interpolation 改 DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss", CultureInfo.InvariantCulture));五個 importer 的 check-log 行重複度高,可順手抽成 WriteToLog 上的一個 FormatCheckLogTimestamp helper 單點固定,但非必要。

**驗證註記**：Evidence verified verbatim: WriteToLog.cs:162 and all five importer WriteToCheckLog lines use "yyyy/MM/dd HH:mm:ss" with no IFormatProvider; csproj has no InvariantGlobalization, so '/' and ':' are live culture separator specifiers (documented BCL behavior — under e.g. de-DE they render as '.'), causing latent timestamp drift in log/check-log CSV output. The hh zero-residue status claim also checks out (case-sensitive grep for lowercase hh in production sources = 0 hits; guard test ProductionSources_DoNotUseAmbiguousTwelveHourTimestampFormat exists at DateTimeRoundTripCaptureTests.cs:104). Not duplicated in CONCERNS.md (items A/J/K cover hh→HH and parse-side culture, not format-side separators). Fix is behavior-preserving on default locales (invariant separators are '/' and ':') and violates no hard constraint. Minor correction: WriteToLog.cs actually has 4 occurrences (lines 75, 90, 133, 162), so the true total is 9 sites, not 6 — the remediation list undercounts but the finding stands. Severity low is correctly calibrated: production Windows zh-TW/en-US locales mask the issue, impact is log/CSV observability only, no DB path.

---

### ImportUIStatus 殘留 5 個只寫不讀的區域變數（去重預檢移除後的死碼）

- **位置**：`DCT_data_import/FileAccess/FileProcess.cs:796`
- **維度**：simplify-dup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：`mac_address, area, factory, os_machine, date` 五個變數每列賦值（:810-814）、date 又在 :827 被設為 "null"，但整個方法內沒有任何讀取——是 R-a 去重改走 DB 原生 upsert（方案 B）後，舊 app 層預檢刪除時遺留的孤兒賦值。恰好是 ui_status 自然鍵五欄，讀者會誤以為仍有 app 層鍵檢查邏輯，造成理解成本；每列多做 5 次 ToString().Trim() 也是白工。

**證據**：
```
string mac_address, area, factory, os_machine, date;
...
mac_address = content.UI_status.Rows[i]["Mac_Address"].ToString().Trim();
area = content.UI_status.Rows[i]["Area"].ToString().Trim();
...
date = "null";  // :827,無任何後續讀取
```

**建議**：刪除五個變數宣告、:810-814 的賦值與 :827 的 `date = "null";`（保留該分支的 `values += "NULL";`）。屬 pre-existing 死碼，建議經用戶確認後刪；build ＋ 既有 UiStatus 相關測試綠即可。

**驗證註記**：Verified: FileProcess.cs:796 declares mac_address/area/factory/os_machine/date; assigned at :810-814 and :827 with zero reads in the method (grep confirms). Git history confirms they are orphans of a removed app-layer dedup pre-check (isUIStatusDataExistInDB in 25a522f), though removal predates the R-a plan-B work (minor attribution slip, no substance change). Not duplicated in CONCERNS.md; no hard-constraint violation. One caveat the finding misses: the assignments sit OUTSIDE the inner try/catch and their DataRow string-indexer access is an accidental fail-fast — a CSV header missing Area/Factory/OS_Machine/Date (CompareUiStatus only rejects unexpected columns, never missing ones) currently throws → caller catch → ImportResult(3)+MoveToError; after naive deletion such a file imports with NULL natural-key columns that uk_ui_status UNIQUE cannot dedup. Existing tests (BuildMinimalUiStatusContent has all 5 columns) would not detect this, so 'build+既有測試綠' is insufficient — removal should add an explicit column-presence check or consciously document the malformed-input behavior change.

---

### GetErrorPath 的 multiSpecRawdata 分支與 GetErrorPathForSpecificFile 的 else 分支互為死碼

- **位置**：`DCT_data_import/ReadAndImport/ImportData.cs:141`
- **維度**：simplify-dup ｜ **工作量**：S ｜ 驗證信心：high

**問題**：全庫唯一呼叫 `GetErrorPathForSpecificFile` 的是 MultiSpecRawData.cs:85 且恆傳 "multiSpecRawdata"，所以其 else 分支 `return GetErrorPath(fileType, dbKey);`（:149）不可達；反向地，`GetErrorPath` 沒有任何 caller 傳 "multiSpecRawdata"（grep 確認六個 caller 皆為其他 fileType），其字典項（:120）與特判分支（:128-131）也不可達。錯誤目錄字串 "Data_Cloud_CSV_MultiSpec_Error/" 因此在兩個方法重複硬編，未來改目錄名要改兩處且其中一處是死的。另外 GetFilePath/GetErrorPath 每次呼叫都重建 Dictionary，可順手提為 static readonly。

**證據**：
```
protected string GetErrorPathForSpecificFile(string fileType, string fileName, string dbKey)
{
    if (fileType == "multiSpecRawdata")
    {
        return GetSourcePath("Data_Cloud_CSV_MultiSpec_Error/" + fileName);
    }
    else
    {
        return GetErrorPath(fileType, dbKey);  // 唯一 caller 恆傳 multiSpecRawdata,不可達
    }
}
```

**建議**：把 GetErrorPathForSpecificFile 內聯回 MultiSpecRawData（或簡化為無 fileType 參數的 `GetMultiSpecErrorPath(fileName)`），同時刪 GetErrorPath 中的 multiSpecRawdata 字典項與特判分支，讓錯誤目錄字串只剩一處。兩個 pathMap 提為 static readonly Dictionary。屬 pre-existing 死碼，經用戶確認後再刪。

**驗證註記**：全部證據親自驗證成立：GetErrorPathForSpecificFile 全庫唯一 caller 為 MultiSpecRawData.cs:85 且恆傳字面 "multiSpecRawdata"，其 else 分支（ImportData.cs:149）不可達；GetErrorPath 的六個 caller（recovery/uistatus/everysiteitem/tester/rawdata/failpin）無一傳 "multiSpecRawdata"，:120 字典項與 :128-131 特判分支不可達；"Data_Cloud_CSV_MultiSpec_Error/" 確實重複於 :120（死）與 :145（活）兩處。建議不違反任何硬性約束（不動 result codes、ComputeImportResult、piggyback、SQL、同步模型），CONCERNS.md D3 只載 Program.cs/DbAccess 的註解掉 dead code、不含此項，測試僅經 wrapper 打 GetFilePath 未觸及死分支故清理不破壞測試。finding 亦已正確標註 pre-existing 死碼需用戶確認後再刪（符合 T1-6）。唯一補充：ImportData.cs:108 的 XML doc 列 multiSpecRawdata 為支援類型，落地時需同步更新，屬細節非反駁。severity low 校準恰當。

---

### EverySiteItem E2E 以硬編常數 364 對帳,綁死 gitignored fixture 的內容形狀

- **位置**：`DCT_data_import.Tests/Integration/EverySiteItemEndToEndIntegrationTests.cs:73`
- **維度**：test-gaps ｜ **工作量**：S ｜ 驗證信心：high

**問題**：`Assert.Equal(0L, stats % 364L)` 假設每個 lot 恰為 2 sites × 182 items = 364 列,但 fixture CSV 是 gitignored、由使用者自行放置:放入 site/item 數不同的新 fixture 時測試假紅(或 stats 碰巧是 364 倍數時假綠),失敗訊息也無法指出「是資料形狀變了」。測試自己已解析出 dbKeys 清單,期望列數其實可以從 fixture 本身推導,不必寫死。

**證據**：
```
EverySiteItemEndToEndIntegrationTests.cs:72-73 `// 已驗證 fixture:單 lot 2 sites × 182 items = 364 列。以「站點數×項目數」對帳避免硬編單一 lot 情境。` `Assert.Equal(0L, stats % 364L);`
```

**建議**：測試在匯入前用 SUT 自身的 EverySiteItem parser(或最簡 CSV 掃描)對每個 fixture 檔計算 sites×items,加總成期望列數後 `Assert.Equal(expected, stats)`——比模數對帳更強(能抓掉列),且與 fixture 內容解耦。

**驗證註記**：Evidence verified exactly (EverySiteItemEndToEndIntegrationTests.cs:72-73; test_data/ gitignored at .gitignore:282). The defect is structural: the E2E enumerates ALL user-supplied EverySiteItem_*.csv fixtures (DiscoverEverySiteItemDbKeys) yet asserts stats % 364 == 0 bound to one fixture's shape — unlike EverySiteItemParserTests.FindFixture which pins the exact filename before asserting 182/2/364 and thus degrades safely. A differently-shaped fixture (item count is program-specific) causes a false red with an uninformative message. Suggested fix is feasible and constraint-compliant: FileReadEverySiteItem is internal with InternalsVisibleTo("DCT_data_import.Tests") and BuildEverySiteItemRows writes exactly sites×items rows, so expected count is derivable per fixture from dataRoot before consumption. Test-only change, no hard-constraint violation, not in CONCERNS.md. Minor calibration: the false-green claim is overstated — per-lot import is all-or-nothing in one DbUnitOfWork and the round-2 idempotency loop (Assert rerunResult.Result==3 per dbKey) would catch a silently dropped whole lot, so the real payoff is the false-red elimination and clearer diagnostics; consistent with low severity.

---

### 兩個 E2E 整合測試檔各自複製 LoadSchema/CopyDirectory/FindRepoRoot 基礎設施

- **位置**：`DCT_data_import.Tests/Integration/ImporterEndToEndIntegrationTests.cs:395`
- **維度**：test-gaps ｜ **工作量**：S ｜ 驗證信心：high

**問題**：LoadSchema(FK-off 全表 DROP + 重灌 dct.sql)、CopyDirectory、FindRepoRoot 三個 helper 在 ImporterEndToEndIntegrationTests(:395)與 EverySiteItemEndToEndIntegrationTests(:120)逐字重複。dct.sql 演進時(如新表加 FK)兩份 LoadSchema 需同步修,漏改一份會讓其中一個 E2E 以過期方式重建 schema。效能面實測無虞(整包 unit suite 465 tests 跑 1 秒;整合 job 只有兩個 E2E test 各重建一次全 schema,屬必要隔離成本),純屬維護重複。

**證據**：
```
ImporterEndToEndIntegrationTests.cs:395 與 EverySiteItemEndToEndIntegrationTests.cs:120-127 相同實作:`string sql = File.ReadAllText(dctSqlPath); var tables = Regex.Matches(sql, @"create\s+table\s+(\w+)", RegexOptions.IgnoreCase)... _fixture.ExecuteScript("SET FOREIGN_KEY_CHECKS=0;\n" + drops + sql + "\nSET FOREIGN_KEY_CHECKS=1;");`
```

**建議**：把 LoadSchema(接受 dct.sql 路徑)、CopyDirectory、FindRepoRoot 收進 MySqlIntegrationFixture(它已是兩檔共用的 collection fixture,且註解自述負責 schema 職責),兩個測試檔改呼叫 fixture 版並刪除本地複本。

**驗證註記**：逐字驗證成立:LoadSchema/FindRepoRoot/CopyDirectory 三個 helper 確實在 ImporterEndToEndIntegrationTests.cs(:395/:405/:420)與 EverySiteItemEndToEndIntegrationTests.cs(:120/:129/:143)功能等價重複(僅 lambda 變數名與例外訊息字面差異),引用行號與程式碼片段完全相符。建議為 test-only DRY 收斂,不觸犯任何硬性約束;CONCERNS.md 無此項記載(R1 講整合測試覆蓋非 helper 重複);收進 MySqlIntegrationFixture 可行且無行為變更(LoadSchema 本已依賴 _fixture.ExecuteScript,fixture:68 註解自述 admin 連線「供建 schema」;Skip gate 不受影響)。旁證:ImporterRollbackIntegrationTests.cs:118 註解「對齊 E2E LoadSchema」是第三個須手動同步的點,DateTimeRoundTripCaptureTests.cs:108 另有第四個 FindRepoRoot 近似變體,重複模式確在擴散。唯一微幅過重之處:漏改一份的失敗模式多半是 loud(漏 DROP 的表撞 CREATE 報錯)而非靜默過期 schema,故維持 low 不升級。

---

### Console.OutputEncoding 設定在 try 區塊外,無主控台環境(服務/排程)擲 IOException 繞過全部啟動失敗處理

- **位置**：`DCT_data_import/Program.cs:45`
- **維度**：config-startup ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：Console.OutputEncoding setter 在 Windows 無 console 附掛時(Windows 服務、Task Scheduler「不論使用者登入與否」模式)呼叫 SetConsoleOutputCP 失敗會擲 IOException(The handle is invalid)。此行位於 Main 的 try 之前,例外會未捕捉直接 crash——WriteErrorLog 不會執行、ExitAsStartupFailure/ExitCode 機制全被繞過,file log 零紀錄。專案已明確為非互動環境設計防護(IsInteractiveConsole/ExitAsStartupFailure 的 XML doc 點名「無 TTY 的服務/排程環境」),但這條 guard 出現在防護生效之前,防護形同虛設。

**證據**：
```
Console.OutputEncoding = System.Text.Encoding.UTF8;
WriteToLog writeToLog = new WriteToLog();
try
{ ...
```

**建議**：以獨立 try/catch(IOException) 包住(無主控台時編碼本就無關緊要,略過即可並可 WriteInfoLog 註記):try { Console.OutputEncoding = System.Text.Encoding.UTF8; } catch (IOException) { /* 服務/排程無主控台,略過 */ }。注意不能只搬進主 try——現有 catch 鏈沒有 IOException 專屬分支,會落到通用 catch 後 ReadKey 邏輯,語意不對。

**驗證註記**：代碼與宣稱完全相符:Program.cs:45 的 Console.OutputEncoding setter 位於 try(:47)與 WriteToLog 建立(:46)之前,.NET 8 Windows 上無附掛 console 時 SetConsoleOutputCP 失敗確實擲 IOException(官方文件列明 setter 可擲 IOException),未捕捉即 crash、繞過專案明確為非互動環境打造的 ExitAsStartupFailure/IsInteractiveConsole(:289/:307,XML doc 點名服務/排程環境)。非 CONCERNS.md 重複(零 OutputEncoding 記載;最近似的 G 項是不同路徑),建議修法局部且不違反任何硬性約束、無測試引用該行。但嚴重度被高估:(1) Task Scheduler 觸發宣稱大多不成立——console-subsystem exe 即使「不論使用者登入與否」仍會配置隱形 conhost,SetConsoleOutputCP 成功;真正觸發限 DETACHED_PROCESS / 無 console 的服務包裝等更窄場景;(2) 失敗是啟動即 100% 重現的響亮 crash(WER 事件 + 非零 exit code),非靜默損壞,損失僅 app 自有 file log 無紀錄;(3) production 現行部署顯然有 console(否則早已每次啟動崩潰),屬 latent 部署模式風險非現行 bug;(4) 同 repo 同類缺陷(CONCERNS.md 項 G:static-init 例外繞過友善 catch)先例定為 Low。故校準為 low。

---

### UiStatus 每成功匯入一檔無條件 Thread.Sleep(500)，backlog 大時串行浪費

- **位置**：`DCT_data_import/ReadAndImport/UiStatus.cs:83`
- **維度**：gap-audit ｜ **工作量**：S ｜ 驗證信心：high（原評 medium，驗證後校準）

**問題**：ReadAndImportUIStatus 成功路徑尾端有一行無註解的 `Thread.Sleep(500)`，源自最初 commit（25a522f data monitor version），七個 importer 中僅此一支有；失敗/缺檔路徑不 sleep。UiStatusMode 逐 db_key 串行呼叫此方法，backlog N 檔即多付 N×0.5 秒純等待（1000 檔 ≈ +8.3 分鐘/輪，超過一個 7.2 分鐘輪詢週期），拖慢 ui_status 佇列消化並放大 EmitStaleStatusHints 的逾時噪音。無任何 throttle 語意記錄，其他 importer（含同為 FTP 來源的 Tester/RecoveryRate）皆無等效節流仍正常運作，判定為殘留死碼。

**證據**：
```
if (import_result)
{
    ...
    deleteStatus = CompleteSuccess(ftpFilePath);
    LogImportSuccess(writeToLog, "UiStatus", dbKeyUiStatus, filename, importTakeTime, deleteStatus);
}
else { ... return new ImportResult(3, "Import failed."); }
Thread.Sleep(500);
```

**建議**：直接刪除該行（單檔一行改動）；若維運顧慮 FTP 節流，改為 App.config 可設定的 per-file delay 並預設 0，同時在 commit message 註明源自 25a522f 無記錄語意。以既有 UiStatusUpsertIntegrationTests / E2E 全綠驗證行為不變。

**驗證註記**：Verified in code: UiStatus.cs:83 has unconditional Thread.Sleep(500) on the success path only (all failure paths return earlier); git -S confirms it dates from initial commit 25a522f with no documented rationale; grep confirms no other importer has an equivalent per-file sleep; Program.cs ImportUiStatusMode (745-808) serially loops per db_key so N×0.5s waste is arithmetically correct. Not in CONCERNS.md, no hard constraint violated, and removal is behavior-safe (sleep is after commit/file-delete/logging; the only tests hitting this method exercise failure paths that return before line 83, and none assert timing). Severity downgraded to low: impact is elapsed-time-only on one worker thread, material mainly in post-outage backlog scenarios where real per-file work (FTP+parse+DB transaction) likely dominates the 0.5s; the EmitStaleStatusHints amplification sub-claim is overstated since PublishWorkerStatus fires per file and 0.5s never approaches the 90s stale threshold.

---

## 被對抗驗證推翻的 findings（2 條，記錄避免重報）

- `DCT_data_import/ReadAndImport/MultiSpecRawData.cs:75` **MultiSpec fallback 對同一共用目錄每個 pending db_key 各自完整 LIST 一次**
  - 推翻理由：引用程式碼屬實（每個 fallback db_key 對固定共用目錄各發一次完整 FTP LIST），但 finding 的放大前提為假：RunTesterImportBatch 每筆結尾無條件呼叫 UpdateDbKeyImportStatus（Program.cs:719-727），importStatus 恆設 "1" 或 "2"、缺檔失敗還會設 mail=1（DbAccess.cs:221-237），而 SelectDbKey worklist 過濾 import_status=0 AND mail=0（DbAccess.cs:88）——缺檔 db_key 一輪後即退出 pending，不會「每輪重試」，程式內也無任何路徑把 import_status 重設為 0（re-queue 是外部人工動作）。故「M×目錄大小、積壓放大」的跨輪複利成本不存在；真實成本只是每個 multispec 型 db_key 一生一次的目錄 LIST（本來就必要的檔案探索）加上同輪內偶發的重複 LIST，屬冷路徑一次性小開銷。更關鍵的是建議修法的安全論證「清單過期最多延後一輪、下一輪自然補上」依賴同一個假前提：因 db_key 單次處理後即終結，輪初快取 LIST 漏掉輪中新到檔案會把該 db_key 終態標成 import_status=2 + 誤發失敗信、CSV 卡目錄需人工重投——落地反而引入行為回歸。專案 memory 亦記載此「每輪重跑」誤解曾誤導 advisor 與兩個代理。

- `DCT_data_import/ReadAndImport/ImportFileSource.cs:112` **ImportFileNameMatcher.IsMatch 的「* 只匹配數字」特化語意無直接單元測試**
  - 推翻理由：Evidence mischaracterizes actual coverage (criterion a). The finding claims only one indirect happy-path test covers IsMatch, but three tests exercise it through both production call paths: LocalImportFileSourceTests.ListFiles_UsesExistingMultiSpecPattern (:97) plus two FtpImportFileSourceListingTests (:21, :43). Its specific "unpinned" edges are mostly pinned: (1) "site* 不匹配 siteA" IS pinned — the Local test creates test_result_siteA_DB001.csv and asserts it is excluded; (2) "空 pattern 恆 true" IS pinned by ParseListing_WithEmptyPattern_ReturnsAllLines (matching the real TsmcIeda.cs:43 empty-pattern caller); (3) Regex.Escape removal would break the Local test fixtures (site* as raw regex = "sit"+e*, so site1 stops matching). The headline risk — "把它當一般 glob 改寫 regex 現有測試抓不到" — is false: rewriting \\d+ to .* fails ListFiles_UsesExistingMultiSpecPattern immediately because siteA would then match. Only IgnoreCase and "* 不匹配空串" remain genuinely unpinned — negligible residue below actionable threshold for an already-low test-gaps finding.

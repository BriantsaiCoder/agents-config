#!/usr/bin/env bash
#
# version-tripwire.sh — 版本回歸絆線
#
# 這是回歸測試，不是預測。每一條都對應已用官方文件確認並修掉的版本缺陷；
# 初始 28 條來自 2026-07-26 稽核（commit 1b3d600 / 3370201 / f3bb004 /
# 6c8093a），後續 refresh 只在同樣有 live evidence 時加絆線。這些缺陷是
# 「skill 教了已死的 API 或版本」，照抄會編譯失敗、build 失敗、測試假綠，
# 或讓 security review 漏掉新 advisory。這支腳本讓已知缺陷的複發成本歸零。
#
# 三個設計決定，每個都有實測理由：
#
# 1. 掃 skills/ bin/ hooks/ .github/，排除 tests/ 與 proposals/。
#    原本只掃 skills/，理由寫的是「其他路徑本來就合法地含有這些死字串，尤其
#    attic/ 的 348 個歸檔副本，repo-wide grep 會上線第一天全紅」。2026-08-02
#    稽核 Follow-up 1 逐目錄實測，推翻了 attic/ 那半句：
#
#      hooks/ bin/ .github/ attic/ docs/   0 條
#      tests/                             33 條（測試檔本身帶 pattern 字面值）
#      proposals/                          2 條（稽核報告引用死寫法當例子）
#
#    假陽性完全不來自 attic/，而是 tests/ 與 proposals/——那兩處含有 pattern 是
#    它們的職責，不是缺陷。所以正解不是「不擴大」，是「擴大到不含它們的範圍」。
#    SCAN_DIRS 是 allowlist 不是 denylist：未列出的目錄就不掃，沒有排除機制可找。
#    未列入的理由——tests/ 納入等於絆線抓自己；proposals/ 與 docs/ 必須能引用死寫法
#    當反例；attic/ 是 CONVENTIONS 規則 11 的退役物，不再維護。
#
#    已知的自我指涉風險：.github/workflows/ci.yml 現在同時被掃，而它正是記錄本絆線
#    的檔案之一——若哪天在那裡的註解寫出 pattern 字面值，CI 會把自己的說明判成死寫法。
#    這與 tests/ 被排除的理由同源，差別只在 ci.yml 的守護價值大於該風險。要在那裡引用
#    死寫法時，寫進 proposals/ 再連結過去。
#
# 2. 收緊 pattern，不用檔案豁免清單。多條死字串在 HEAD 仍有命中，但都落在
#    刻意寫的警語裡（「不要用 X，改用 Y」）。豁免整個檔案會自廢武功 ——
#    AnyZodObject / req.query 的警語所在檔，正好就是原缺陷所在檔。改用更
#    精確的 pattern：程式碼形狀命中、散文形狀不命中。例如
#    `AnyZodObject[;,]` 只中 import 清單與型別宣告，不中被 backtick 包住的
#    警語；`: z.string().email(` 的前導冒號只中 schema 屬性，不中散文。
#
# 3. -F 與 -E 逐條決定，不可統一。`AnyZodObject[;,]` 誤用 -F 會把 [;,] 當
#    字面值而永遠 0 命中 —— 一條永遠不會紅的絆線比沒有絆線更糟，因為它
#    製造被保護的錯覺。--selftest 就是為了擋這個。
#
# 用法:
#   bash tests/version-tripwire.sh              掃描 SCAN_DIRS 列出的目錄，有命中即 FAIL
#   bash tests/version-tripwire.sh --selftest   對基準線斷言每條都會觸發
#
# 要展示死寫法時的慣例：放進 `//` 或 `#` 註解裡，不要留成裸的一行。
# 全庫 41 個 skill 用 `❌ Wrong` 標記共 145 處，其形狀是註解行 + 下一行裸
# 壞碼 —— 行首錨點擋得住註解形，擋不住裸行。真的需要裸行時，逃生門是在
# 本檔加豁免，不是刪掉絆線。
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." || exit 1

BASE_COMMIT=8d701ca     # 2026-07-26 那輪修復之前的最後一個 commit
# 掃描範圍與各目錄的取捨見檔頭設計決定 1。空白分隔，展開時刻意不加引號。
SCAN_DIRS="skills bin hooks .github"

# 掃描根目錄必須全部存在，缺一即 fail-fast。
# 沒有這段的話：grep 對不存在的路徑 exit 2 但 stdout 為空，而呼叫端只看 stdout，
# 於是「目錄打錯」與「0 命中」無法區分。實測把 SCAN_DIRS 全部改成不存在的名字，
# 腳本照樣印「45 條絆線全部未觸發」並 exit 0——整支絆線變成本檔開頭批評的那種
# 「永遠不會紅的絆線」。目錄改名、typo、CI checkout 缺檔都會觸發這條路徑。
for _d in $SCAN_DIRS; do
  [ -d "$_d" ] || {
    printf 'FAIL  掃描目錄不存在：%s（SCAN_DIRS=%s）\n' "$_d" "$SCAN_DIRS" >&2
    printf '      目錄缺席與 0 命中在 grep 的 stdout 上無法區分，因此這裡直接失敗。\n' >&2
    exit 1
  }
done
unset _d

grep_for() {  # $1=mode  $2=pattern  $3.. = 一個或多個掃描根目錄
  # 用 "$@" 而非 "$3"：掃描範圍改成多目錄之後，只取 $3 會讓第二個之後的目錄整個
  # 被丟掉，而輸出仍是「N 條絆線全部未觸發」——一個看起來正常的假綠。實作時真的
  # 踩到（2026-08-02），植入死寫法到 hooks/ 也抓不出來才發現。
  local mode="$1" pat="$2"
  shift 2
  case "$mode" in
    F) grep -rnF -e "$pat" "$@" 2>/dev/null ;;
    *) grep -rnE -e "$pat" "$@" 2>/dev/null ;;
  esac
}

# ── --selftest：對基準線斷言每條絆線都真的會觸發 ──────────────
# 一條在基準線也 0 命中的絆線，代表 pattern 已經寫壞（或當初就是猜的），
# 它會安靜地永遠通過。這個模式讓那種腐化變成紅燈。
if [ "${1:-}" = "--selftest" ]; then
  if ! git rev-parse --verify "$BASE_COMMIT^{commit}" >/dev/null 2>&1; then
    echo "SKIP  基準線 $BASE_COMMIT 不在本地（CI 需 fetch-depth: 0）"; exit 0
  fi
  tmp=$(mktemp -d) || exit 1
  # 逐一 archive 並容忍個別失敗，至少要成功一個。
  # 這是為未來的 SCAN_DIRS 增修留的：今天四個目錄在 8d701ca 都存在（git ls-tree 可驗），
  # 所以這個容忍分支目前不會走到。日後若加入基準線當時還沒有的目錄，沒有它會整支 exit 1
  # ——而那不是絆線腐化，是 corpus 不存在，兩者不該用同一種失敗表示。
  # （初版註解寫「.github 是後來才加的」，那是編造的理由，實測推翻。）
  got=0
  for d in $SCAN_DIRS; do
    git archive "$BASE_COMMIT" "$d" 2>/dev/null | tar -x -C "$tmp" 2>/dev/null && got=1
  done
  [ "$got" = 1 ] || { echo "FAIL  基準線 $BASE_COMMIT 沒有任何掃描目錄"; exit 1; }
  scan_roots=""
  for d in $SCAN_DIRS; do [ -d "$tmp/$d" ] && scan_roots="$scan_roots $tmp/$d"; done
  st_pass=0; st_fail=0
  while IFS=$'\t' read -r mode pat why; do
    [ -n "${mode:-}" ] || continue
    if [ -n "$(grep_for "$mode" "$pat" $scan_roots)" ]; then
      st_pass=$((st_pass+1))
    else
      st_fail=$((st_fail+1))
      printf 'DEAD  絆線在基準線也 0 命中（pattern 已腐化或當初即為猜測）:\n      [-%s] %s\n' "$mode" "$pat"
    fi
  done <<'TRIPWIRES'
E	: z\.string\(\)\.(email|url|uuid)\(	Zod 4 把 string format 檢核搬到 top-level 函式，method 形式全標 @deprecated，v3 API
E	AnyZodObject[;,]	Zod 4 主入口已不匯出 AnyZodObject；`import { AnyZodObject } from 'zod'` 是 TS23
E	req\.query = [A-Za-z_]	Express 5（現行 stable）把 req.query 定義為 getter-only，指派丟 `TypeError: Cannot
E	vi\.mock\([[:space:]]*['"]node-fetch['"][[:space:]]*,	Node 18+ 內建 global fetch；受測程式呼叫 global fetch 時 `vi.mock('node-fetch', 
E	^[[:space:]]*node-version: 20	Node 20 "Iron" 已於 2026-04 結束 Maintenance（Node 18 於 2025-04）
F	Until Express 5 is stable	Express 5 自 2024-09 起為 stable（現 5.2.x），其 router 會把 async handler 回傳的 r
F	Express 5 (currently in beta)	版本狀態宣稱：Express 5 早已 GA
E	^[[:space:]]*"nuxt":[[:space:]]*"\^3\.	`^3.0.0` 是 caret range，永遠不會裝到 Nuxt 4——module / layer 範本這樣釘住，等於作者永遠只在舊 
E	^[[:space:]]*provider: 'playwright'	Vitest 4 移除了字串名稱形式的 browser provider
F	@plugin "tailwindcss-animate"	`tailwindcss-animate` 是 Tailwind v3 時代套件；shadcn/ui 已不再產出它，且對 v4 無人維護
F	@variant dark (&	Tailwind v4 在 beta 期把 variant 的「定義」at-rule 從 `@variant` 改名為 `@custom-v
F	announcing-vite8-beta	Vite 8 已 GA；beta 公告 URL 正是讓該 skill 宣稱「Vite 7 stable / 8 beta」並把 Rolldo
E	^[[:space:]]*public[[:space:]]+(async[[:space:]]+)?Task[[:space:]]+DisposeAsync\(\)	xUnit v3（套件 xunit.v3 3.x）把 IAsyncLifetime 改為衍生自 IAsyncDisposable，其 Dis
E	^[[:space:]]*public[[:space:]]+(async[[:space:]]+)?Task[[:space:]]+InitializeAsync\(\)	同一根因：xUnit v3 的 IAsyncLifetime.InitializeAsync() 回傳 ValueTask 而非 Task
F	Oracle changed the support policy	MySQL 5.7 走的是與 5.6 / 8.0 / 8.4 相同的標準 5 年 Premier + 3 年 Extended 節奏（Pre
F	**Premier Support ended:** October 2023	MySQL 5.7 的 Premier Support 結束於 2020-10，不是 2023-10；2023-10 是 Extended 
F	Upgrade to MySQL 8.0 (or 8.4 LTS)	MySQL 8.0 已於 2026-04-30 EOL（Premier 2025-04、Extended 2026-04 結束），與 5.7
F	.NET Framework 4.6.1+, .NET 6/7/8/9	MySqlConnector 2.3.0 已 drop net461 與 netcoreapp3.1，2.5.0 加入 .NET 10 支援
F	ATTACH PARTITION CONCURRENTLY	PostgreSQL 的 ALTER TABLE ... ATTACH PARTITION 從 PG 14 到 18 都不接受 CONCURRENTLY；支援該選項的是 DETACH PARTITION。照抄會直接語法錯誤
F	PostgreSQL supports `STORED` generated columns only (no `VIRTUAL`)	PostgreSQL 18 加入 VIRTUAL generated column，且未指定時預設為 VIRTUAL（PG 17 及更早只有
F	Use this skill for Entity Framework 6 code in .NET Framework projects	EF 6.3+（2019-09）起 EF6 就能跑在 .NET Core 3.0 及之後；EF 6.5.2（2026-04）相容 .NET 
F	`System.Data.Entity` and targets .NET Framework	同一個 EF 6.3+ 跨平台事實，這條守 SKILL.md「When This Skill Applies」的判準句：舊文把「引用 Sys
F	EF6 (System.Data.Entity) data access on .NET Framework —	同一個 EF6 跨平台事實，這條守 frontmatter description
F	No `Include` in some EF versions	EF.CompileQuery / EF.CompileAsyncQuery 從 EF Core 5.0 到 10.0 一直有專屬的 IIn
F	gitleaks detect --source	gitleaks 的掃描目標是位置參數，`--source` flag 從不存在；`detect` / `protect` 子命令自 v8.
E	claude-opus-4\.7|gpt-5\.5|claude-sonnet-4\.6	init-project-docs 原本在 Copilot agent frontmatter 的 `model` 欄硬寫範例模型 id
E	^FROM golang:1\.24	Go 安全政策只支援最近兩個 major release；2026-07 當下為 1.26 / 1.25，pin 1.24 的 builde
F	Reference: OWASP A03:2021	OWASP Top 10:2025 已重排：Injection 由 A03:2021 變成 A05:2025
F	windows-container-tools/releases/download/v2.1.1	dotnet-framework 容器範本以「The correct LogMonitor.exe URL is:」斷言 + Dockerf
E	\| Package \| Vulnerable Versions \| Issue \| Safe Version \||curated watchlist	靜態 safe-version 表與 authoritative watchlist 會過期；dependency review 必須查 live advisory source
F	Requires `experimental.mcpServer: true`	Next.js 16 才支援 next-devtools-mcp；舊版沒有 experimental.mcpServer 開關
F	Turbopack is the default bundler in Next.js 15+	Turbopack 自 Next.js 16 才同時成為 next dev 與 next build 預設
F	<script src="https://polyfill.io	已知不應使用的 CDN 不得留在可複製的裸 code example
E	revalidateTag\('posts'\);	Next.js 16 的 revalidateTag 單參數形式已 deprecated 且會產生 TypeScript error
F	version: '3.8'	Compose Specification 已不需要頂層 version；保留會產生 obsolete warning
F	"@nuxt/ui": "^2.0.0"	Nuxt 4 reference 不得把 @nuxt/ui 釘在已淘汰的 v2 major
E	mockReset\(\).*(Clear history \+ implementation|restore original implementation)|mockRestore\(\).*Same reset; also restore spy descriptors	Vitest reset/restore 必須區分 vi.fn 與 vi.spyOn；restore 對 spy 會移除 wrapper
F	<PackageVersion Include="FluentValidation.AspNetCore" Version="11.3.0" />	FluentValidation.AspNetCore 已 deprecated；新 ASP.NET Core 專案應用 core package + manual validation
F	// Package: AutoFixture.Xunit2	xUnit v3 reference 不得繼續推薦 xUnit v2 integration package
F	services.AddScoped<NpgsqlConnection>	Npgsql current DI pattern 是 singleton NpgsqlDataSource + per-operation open connection
F	MSVC v17.9+ — adopt only	C23 feature matrix 不能宣稱 MSVC 17.9 完整支援該組功能
F	valgrind on Windows-only targets	Valgrind 不支援 Windows-only target
F	mysql_query("SELECT	PHP 7 已移除 mysql_query；current PHP injection example 應使用 PDO 或 mysqli
F	TelemetryConfiguration.Active	Application Insights 的 global active configuration 已淘汰；ASP.NET Core 應從 DI 取得 TelemetryConfiguration
E	Serilog\.Sinks\.Elasticsearch|^[[:space:]]*\[new Uri\("https://elastic\.example\.com"\)\],	community sink 已 archived；官方 sink 範例須同時相容本 skill 支援的 .NET 6 / C# 10
TRIPWIRES
  printf '\nselftest: %d 條會觸發 / %d 條已失效\n' "$st_pass" "$st_fail"
  [ "$st_fail" -eq 0 ] || exit 1
  exit 0
fi

# ── 主模式：現況掃描 ──────────────────────────────────────────
n=0; bad=0
while IFS=$'\t' read -r mode pat why; do
  [ -n "${mode:-}" ] || continue
  n=$((n+1))
  hits=$(grep_for "$mode" "$pat" $SCAN_DIRS)
  if [ -n "$hits" ]; then
    bad=$((bad+1))
    printf 'FAIL  %s\n      pattern [-%s]: %s\n' "$why" "$mode" "$pat"
    printf '%s\n' "$hits" | sed 's/^/      /'
  fi
done <<'TRIPWIRES'
E	: z\.string\(\)\.(email|url|uuid)\(	Zod 4 把 string format 檢核搬到 top-level 函式，method 形式全標 @deprecated，v3 API
E	AnyZodObject[;,]	Zod 4 主入口已不匯出 AnyZodObject；`import { AnyZodObject } from 'zod'` 是 TS23
E	req\.query = [A-Za-z_]	Express 5（現行 stable）把 req.query 定義為 getter-only，指派丟 `TypeError: Cannot
E	vi\.mock\([[:space:]]*['"]node-fetch['"][[:space:]]*,	Node 18+ 內建 global fetch；受測程式呼叫 global fetch 時 `vi.mock('node-fetch', 
E	^[[:space:]]*node-version: 20	Node 20 "Iron" 已於 2026-04 結束 Maintenance（Node 18 於 2025-04）
F	Until Express 5 is stable	Express 5 自 2024-09 起為 stable（現 5.2.x），其 router 會把 async handler 回傳的 r
F	Express 5 (currently in beta)	版本狀態宣稱：Express 5 早已 GA
E	^[[:space:]]*"nuxt":[[:space:]]*"\^3\.	`^3.0.0` 是 caret range，永遠不會裝到 Nuxt 4——module / layer 範本這樣釘住，等於作者永遠只在舊 
E	^[[:space:]]*provider: 'playwright'	Vitest 4 移除了字串名稱形式的 browser provider
F	@plugin "tailwindcss-animate"	`tailwindcss-animate` 是 Tailwind v3 時代套件；shadcn/ui 已不再產出它，且對 v4 無人維護
F	@variant dark (&	Tailwind v4 在 beta 期把 variant 的「定義」at-rule 從 `@variant` 改名為 `@custom-v
F	announcing-vite8-beta	Vite 8 已 GA；beta 公告 URL 正是讓該 skill 宣稱「Vite 7 stable / 8 beta」並把 Rolldo
E	^[[:space:]]*public[[:space:]]+(async[[:space:]]+)?Task[[:space:]]+DisposeAsync\(\)	xUnit v3（套件 xunit.v3 3.x）把 IAsyncLifetime 改為衍生自 IAsyncDisposable，其 Dis
E	^[[:space:]]*public[[:space:]]+(async[[:space:]]+)?Task[[:space:]]+InitializeAsync\(\)	同一根因：xUnit v3 的 IAsyncLifetime.InitializeAsync() 回傳 ValueTask 而非 Task
F	Oracle changed the support policy	MySQL 5.7 走的是與 5.6 / 8.0 / 8.4 相同的標準 5 年 Premier + 3 年 Extended 節奏（Pre
F	**Premier Support ended:** October 2023	MySQL 5.7 的 Premier Support 結束於 2020-10，不是 2023-10；2023-10 是 Extended 
F	Upgrade to MySQL 8.0 (or 8.4 LTS)	MySQL 8.0 已於 2026-04-30 EOL（Premier 2025-04、Extended 2026-04 結束），與 5.7
F	.NET Framework 4.6.1+, .NET 6/7/8/9	MySqlConnector 2.3.0 已 drop net461 與 netcoreapp3.1，2.5.0 加入 .NET 10 支援
F	ATTACH PARTITION CONCURRENTLY	PostgreSQL 的 ALTER TABLE ... ATTACH PARTITION 從 PG 14 到 18 都不接受 CONCURRENTLY；支援該選項的是 DETACH PARTITION。照抄會直接語法錯誤
F	PostgreSQL supports `STORED` generated columns only (no `VIRTUAL`)	PostgreSQL 18 加入 VIRTUAL generated column，且未指定時預設為 VIRTUAL（PG 17 及更早只有
F	Use this skill for Entity Framework 6 code in .NET Framework projects	EF 6.3+（2019-09）起 EF6 就能跑在 .NET Core 3.0 及之後；EF 6.5.2（2026-04）相容 .NET 
F	`System.Data.Entity` and targets .NET Framework	同一個 EF 6.3+ 跨平台事實，這條守 SKILL.md「When This Skill Applies」的判準句：舊文把「引用 Sys
F	EF6 (System.Data.Entity) data access on .NET Framework —	同一個 EF6 跨平台事實，這條守 frontmatter description
F	No `Include` in some EF versions	EF.CompileQuery / EF.CompileAsyncQuery 從 EF Core 5.0 到 10.0 一直有專屬的 IIn
F	gitleaks detect --source	gitleaks 的掃描目標是位置參數，`--source` flag 從不存在；`detect` / `protect` 子命令自 v8.
E	claude-opus-4\.7|gpt-5\.5|claude-sonnet-4\.6	init-project-docs 原本在 Copilot agent frontmatter 的 `model` 欄硬寫範例模型 id
E	^FROM golang:1\.24	Go 安全政策只支援最近兩個 major release；2026-07 當下為 1.26 / 1.25，pin 1.24 的 builde
F	Reference: OWASP A03:2021	OWASP Top 10:2025 已重排：Injection 由 A03:2021 變成 A05:2025
F	windows-container-tools/releases/download/v2.1.1	dotnet-framework 容器範本以「The correct LogMonitor.exe URL is:」斷言 + Dockerf
E	\| Package \| Vulnerable Versions \| Issue \| Safe Version \||curated watchlist	靜態 safe-version 表與 authoritative watchlist 會過期；dependency review 必須查 live advisory source
F	Requires `experimental.mcpServer: true`	Next.js 16 才支援 next-devtools-mcp；舊版沒有 experimental.mcpServer 開關
F	Turbopack is the default bundler in Next.js 15+	Turbopack 自 Next.js 16 才同時成為 next dev 與 next build 預設
F	<script src="https://polyfill.io	已知不應使用的 CDN 不得留在可複製的裸 code example
E	revalidateTag\('posts'\);	Next.js 16 的 revalidateTag 單參數形式已 deprecated 且會產生 TypeScript error
F	version: '3.8'	Compose Specification 已不需要頂層 version；保留會產生 obsolete warning
F	"@nuxt/ui": "^2.0.0"	Nuxt 4 reference 不得把 @nuxt/ui 釘在已淘汰的 v2 major
E	mockReset\(\).*(Clear history \+ implementation|restore original implementation)|mockRestore\(\).*Same reset; also restore spy descriptors	Vitest reset/restore 必須區分 vi.fn 與 vi.spyOn；restore 對 spy 會移除 wrapper
F	<PackageVersion Include="FluentValidation.AspNetCore" Version="11.3.0" />	FluentValidation.AspNetCore 已 deprecated；新 ASP.NET Core 專案應用 core package + manual validation
F	// Package: AutoFixture.Xunit2	xUnit v3 reference 不得繼續推薦 xUnit v2 integration package
F	services.AddScoped<NpgsqlConnection>	Npgsql current DI pattern 是 singleton NpgsqlDataSource + per-operation open connection
F	MSVC v17.9+ — adopt only	C23 feature matrix 不能宣稱 MSVC 17.9 完整支援該組功能
F	valgrind on Windows-only targets	Valgrind 不支援 Windows-only target
F	mysql_query("SELECT	PHP 7 已移除 mysql_query；current PHP injection example 應使用 PDO 或 mysqli
F	TelemetryConfiguration.Active	Application Insights 的 global active configuration 已淘汰；ASP.NET Core 應從 DI 取得 TelemetryConfiguration
E	Serilog\.Sinks\.Elasticsearch|^[[:space:]]*\[new Uri\("https://elastic\.example\.com"\)\],	community sink 已 archived；官方 sink 範例須同時相容本 skill 支援的 .NET 6 / C# 10
TRIPWIRES

if [ "$bad" -eq 0 ]; then
  printf '%d 條絆線全部未觸發 —— %s 無已知死寫法\n' "$n" "$SCAN_DIRS"
else
  printf '\n%d / %d 條絆線觸發。這些寫法已在 2026-07-26 稽核中判定為死：\n' "$bad" "$n"
  printf '照抄會編譯失敗、build 失敗或測試假綠。修法見 proposals/2026-07-26-doctor-skill-family/00-report.md\n'
fi
[ "$bad" -eq 0 ]

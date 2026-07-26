#!/usr/bin/env bash
#
# version-tripwire.sh — 版本回歸絆線（skills/ 專用）
#
# 這是回歸測試，不是預測。每一條都對應已用官方文件確認並修掉的版本缺陷；
# 初始 28 條來自 2026-07-26 稽核（commit 1b3d600 / 3370201 / f3bb004 /
# 6c8093a），後續 refresh 只在同樣有 live evidence 時加絆線。這些缺陷是
# 「skill 教了已死的 API 或版本」，照抄會編譯失敗、build 失敗、測試假綠，
# 或讓 security review 漏掉新 advisory。這支腳本讓已知缺陷的複發成本歸零。
#
# 三個設計決定，每個都有實測理由：
#
# 1. 只掃 skills/。~/.agents 的其他路徑本來就合法地含有這些死字串 ——
#    proposals/ 的稽核報告必須引用它們才能描述修了什麼，attic/ 有 348 個
#    歸檔的舊 skill 副本。repo-wide grep 會上線第一天全紅。
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
#   bash tests/version-tripwire.sh              掃描 skills/，有命中即 FAIL
#   bash tests/version-tripwire.sh --selftest   對基準線斷言每條都會觸發
#
# 要展示死寫法時的慣例：放進 `//` 或 `#` 註解裡，不要留成裸的一行。
# 全庫 41 個 skill 用 `❌ Wrong` 標記共 145 處，其形狀是註解行 + 下一行裸
# 壞碼 —— 行首錨點擋得住註解形，擋不住裸行。真的需要裸行時，逃生門是在
# 本檔加豁免，不是刪掉絆線。
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." || exit 1

BASE_COMMIT=8d701ca     # 2026-07-26 那輪修復之前的最後一個 commit
SCAN_DIR=skills

grep_for() {  # $1=mode  $2=pattern  $3=root
  case "$1" in
    F) grep -rnF -e "$2" "$3" 2>/dev/null ;;
    *) grep -rnE -e "$2" "$3" 2>/dev/null ;;
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
  git archive "$BASE_COMMIT" "$SCAN_DIR" | tar -x -C "$tmp" || exit 1
  st_pass=0; st_fail=0
  while IFS=$'\t' read -r mode pat why; do
    [ -n "${mode:-}" ] || continue
    if [ -n "$(grep_for "$mode" "$pat" "$tmp/$SCAN_DIR")" ]; then
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
F	| Package | Vulnerable Versions | Issue | Safe Version |	靜態 safe-version 表會在新 advisory 發布後立刻過期；dependency review 必須查 live advisory source
F	Requires `experimental.mcpServer: true`	Next.js 16 才支援 next-devtools-mcp；舊版沒有 experimental.mcpServer 開關
F	Turbopack is the default bundler in Next.js 15+	Turbopack 自 Next.js 16 才同時成為 next dev 與 next build 預設
F	<script src="https://polyfill.io	已知不應使用的 CDN 不得留在可複製的裸 code example
E	revalidateTag\('posts'\);	Next.js 16 的 revalidateTag 單參數形式已 deprecated 且會產生 TypeScript error
F	version: '3.8'	Compose Specification 已不需要頂層 version；保留會產生 obsolete warning
F	"@nuxt/ui": "^2.0.0"	Nuxt 4 reference 不得把 @nuxt/ui 釘在已淘汰的 v2 major
E	mockReset\(\).*Clear history \+ implementation	Vitest 4 mockReset 會重設到 original implementation，不是清掉 implementation
F	<PackageVersion Include="FluentValidation.AspNetCore" Version="11.3.0" />	FluentValidation.AspNetCore 已 deprecated；新 ASP.NET Core 專案應用 core package + manual validation
F	// Package: AutoFixture.Xunit2	xUnit v3 reference 不得繼續推薦 xUnit v2 integration package
F	services.AddScoped<NpgsqlConnection>	Npgsql current DI pattern 是 singleton NpgsqlDataSource + per-operation open connection
F	MSVC v17.9+ — adopt only	C23 feature matrix 不能宣稱 MSVC 17.9 完整支援該組功能
F	valgrind on Windows-only targets	Valgrind 不支援 Windows-only target
F	mysql_query("SELECT	PHP 7 已移除 mysql_query；current PHP injection example 應使用 PDO 或 mysqli
F	TelemetryConfiguration.Active	Application Insights 的 global active configuration 已淘汰；ASP.NET Core 應從 DI 取得 TelemetryConfiguration
F	Serilog.Sinks.Elasticsearch	community Elasticsearch sink 已 archived；Elastic 8+ 新案應使用官方 Elastic.Serilog.Sinks
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
  hits=$(grep_for "$mode" "$pat" "$SCAN_DIR")
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
F	| Package | Vulnerable Versions | Issue | Safe Version |	靜態 safe-version 表會在新 advisory 發布後立刻過期；dependency review 必須查 live advisory source
F	Requires `experimental.mcpServer: true`	Next.js 16 才支援 next-devtools-mcp；舊版沒有 experimental.mcpServer 開關
F	Turbopack is the default bundler in Next.js 15+	Turbopack 自 Next.js 16 才同時成為 next dev 與 next build 預設
F	<script src="https://polyfill.io	已知不應使用的 CDN 不得留在可複製的裸 code example
E	revalidateTag\('posts'\);	Next.js 16 的 revalidateTag 單參數形式已 deprecated 且會產生 TypeScript error
F	version: '3.8'	Compose Specification 已不需要頂層 version；保留會產生 obsolete warning
F	"@nuxt/ui": "^2.0.0"	Nuxt 4 reference 不得把 @nuxt/ui 釘在已淘汰的 v2 major
E	mockReset\(\).*Clear history \+ implementation	Vitest 4 mockReset 會重設到 original implementation，不是清掉 implementation
F	<PackageVersion Include="FluentValidation.AspNetCore" Version="11.3.0" />	FluentValidation.AspNetCore 已 deprecated；新 ASP.NET Core 專案應用 core package + manual validation
F	// Package: AutoFixture.Xunit2	xUnit v3 reference 不得繼續推薦 xUnit v2 integration package
F	services.AddScoped<NpgsqlConnection>	Npgsql current DI pattern 是 singleton NpgsqlDataSource + per-operation open connection
F	MSVC v17.9+ — adopt only	C23 feature matrix 不能宣稱 MSVC 17.9 完整支援該組功能
F	valgrind on Windows-only targets	Valgrind 不支援 Windows-only target
F	mysql_query("SELECT	PHP 7 已移除 mysql_query；current PHP injection example 應使用 PDO 或 mysqli
F	TelemetryConfiguration.Active	Application Insights 的 global active configuration 已淘汰；ASP.NET Core 應從 DI 取得 TelemetryConfiguration
F	Serilog.Sinks.Elasticsearch	community Elasticsearch sink 已 archived；Elastic 8+ 新案應使用官方 Elastic.Serilog.Sinks
TRIPWIRES

if [ "$bad" -eq 0 ]; then
  printf '%d 條絆線全部未觸發 —— skills/ 無已知死寫法\n' "$n"
else
  printf '\n%d / %d 條絆線觸發。這些寫法已在 2026-07-26 稽核中判定為死：\n' "$bad" "$n"
  printf '照抄會編譯失敗、build 失敗或測試假綠。修法見 proposals/2026-07-26-doctor-skill-family/00-report.md\n'
fi
[ "$bad" -eq 0 ]

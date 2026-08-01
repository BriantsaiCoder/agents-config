#!/usr/bin/env bash
# deps-check — 列出誰依賴指定的檔案（TypeScript/JavaScript 或 C#）
#
# Usage: deps-check.sh <file-path>
#
# TS/JS：優先 madge（若專案已安裝），否則 fallback 到 grep import/require。
# C#  ：抽出 target 檔的 public/internal 型別名，grep solution 找引用方。
#
# .NET 模式是「型別名 grep」啟發式：不解析 namespace、不做語意分析，
# 跨 namespace 同名型別可能誤判。當作事前的扇入指標，不是精確結果。

set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: deps-check.sh <file-path>" >&2
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  echo "deps-check: file not found: $TARGET" >&2
  echo "deps-check: UNKNOWN — 未執行任何扇入分析，不得推論為安全" >&2
  exit 2
fi

case "$TARGET" in
  *.ts|*.tsx|*.js|*.jsx|*.mts|*.cts) MODE="tsjs" ;;
  *.cs)                              MODE="dotnet" ;;
  *)
    # 刻意 exit 0：這是「不適用」不是「分析失敗」。掛 hook 時對 .md/.json 擋 Edit 是錯的。
    echo "deps-check: skipped (not a TS/JS or C# file)"
    exit 0
    ;;
esac

# ============================================================
# TS / JS
# ============================================================
if [[ "$MODE" == "tsjs" ]]; then
  ROOT="$(pwd)"
  while [[ "$ROOT" != "/" && ! -f "$ROOT/package.json" ]]; do
    ROOT="$(dirname "$ROOT")"
  done

  if [[ ! -f "$ROOT/package.json" ]]; then
    echo "deps-check: no package.json found — UNKNOWN，未執行扇入分析" >&2
    exit 2
  fi

  REL_TARGET="${TARGET#"$ROOT"/}"
  BASENAME="$(basename "$TARGET")"
  STEM="${BASENAME%.*}"

  echo "deps-check: analyzing $REL_TARGET"
  echo ""

  # --- Strategy 1: madge（若已安裝）
  if command -v madge >/dev/null 2>&1; then
    echo "→ using madge"
    if madge --reverse --ts-config "$ROOT/tsconfig.json" "$REL_TARGET" 2>/dev/null | sed '1d' | grep -v '^$' | head -50; then
      exit 0
    fi
    echo "(madge 無輸出，改用 grep fallback)"
  fi

  # --- Strategy 2: grep fallback
  echo "→ using grep fallback"
  echo ""

  SEARCH_DIRS=()
  for d in src app lib test tests __tests__ packages; do
    [[ -d "$ROOT/$d" ]] && SEARCH_DIRS+=("$ROOT/$d")
  done
  if [[ ${#SEARCH_DIRS[@]} -eq 0 ]]; then
    SEARCH_DIRS=("$ROOT")
  fi

  PATTERN="(from|import|require)[[:space:](]+['\"][^'\"]*/${STEM}(['\"]|/)"

  RESULTS=$(grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.mts' --include='*.cts' "$PATTERN" "${SEARCH_DIRS[@]}" 2>/dev/null | grep -v "^$TARGET:" || true)

  if [[ -z "$RESULTS" ]]; then
    echo "deps-check: 0 個 heuristic match（madge/grep 未找到 importer）"
    echo "→ 這不等於「安全」：dynamic import、re-export barrel、字串組出的路徑都掃不到"
    exit 0
  fi

  COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
  echo "found $COUNT importer line(s):"
  echo ""
  echo "$RESULTS" | head -50
  if [[ "$COUNT" -gt 50 ]]; then
    echo ""
    echo "(truncated, total $COUNT lines)"
  fi

  echo ""
  echo "→ 建議：修改前先 Read 上述依賴方，確認改動不會破壞它們"
  echo "→ 收尾：改完跑 npx tsc --noEmit 驗證"
  exit 0
fi

# ============================================================
# C# / .NET
# ============================================================
if [[ "$MODE" == "dotnet" ]]; then
  TARGET_DIR="$(cd "$(dirname "$TARGET")" && pwd)"

  # 找搜尋根：最近的 .sln；無則最近的 .csproj 所在目錄
  SEARCH_ROOT=""
  probe="$TARGET_DIR"
  while [[ "$probe" != "/" ]]; do
    if compgen -G "$probe/*.sln" >/dev/null 2>&1; then
      SEARCH_ROOT="$probe"
      break
    fi
    probe="$(dirname "$probe")"
  done
  if [[ -z "$SEARCH_ROOT" ]]; then
    probe="$TARGET_DIR"
    while [[ "$probe" != "/" ]]; do
      if compgen -G "$probe/*.csproj" >/dev/null 2>&1; then
        SEARCH_ROOT="$probe"
        break
      fi
      probe="$(dirname "$probe")"
    done
  fi

  if [[ -z "$SEARCH_ROOT" ]]; then
    echo "deps-check: no .sln or .csproj found — UNKNOWN，未執行扇入分析" >&2
    exit 2
  fi

  echo "deps-check: analyzing ${TARGET#"$SEARCH_ROOT"/}"
  echo "→ search root: $SEARCH_ROOT"
  echo ""

  # 抽出 target 檔宣告的 public/internal 型別名
  TYPES_A=$(grep -hoE '\b(class|interface|record|struct|enum)\b[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$TARGET" 2>/dev/null \
    | awk '{print $NF}' \
    | grep -vE '^(class|interface|record|struct|enum)$' || true)
  # 補 record struct / record class 組合（上一輪會抽到 struct/class，需單獨處理）
  TYPES_B=$(grep -hoE '\brecord[[:space:]]+(struct|class)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$TARGET" 2>/dev/null \
    | awk '{print $NF}' || true)

  TYPES=$(printf '%s\n%s\n' "$TYPES_A" "$TYPES_B" | grep -v '^$' | sort -u || true)

  if [[ -z "$TYPES" ]]; then
    echo "deps-check: 此檔未宣告 public/internal 型別（可能是 partial、internal helper 或純擴充方法）" >&2
    echo "→ UNKNOWN：無法用型別名做扇入分析；若改的是 public 成員，請手動 grep 成員名" >&2
    echo "→ 收尾：改完跑 dotnet build 驗證" >&2
    exit 2
  fi

  echo "target 宣告的型別：$(echo "$TYPES" | paste -sd ',' - | sed 's/,/, /g')"
  echo ""

  ALT=$(echo "$TYPES" | paste -sd '|' -)

  RESULTS=$(grep -rEnw --include='*.cs' "(${ALT})" "$SEARCH_ROOT" 2>/dev/null \
    | grep -v "^$TARGET:" \
    | grep -vE '/(bin|obj)/' || true)

  if [[ -z "$RESULTS" ]]; then
    echo "deps-check: 0 個 heuristic match（型別名 grep 未找到 reference）"
    echo "→ 這不等於「安全」：反射、DI 字串註冊、動態組出的型別名都掃不到"
    echo "→ 收尾：改完跑 dotnet build 驗證"
    exit 0
  fi

  FILE_COUNT=$(echo "$RESULTS" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
  LINE_COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
  echo "found $LINE_COUNT reference line(s) across $FILE_COUNT file(s):"
  echo ""
  echo "$RESULTS" | head -50
  if [[ "$LINE_COUNT" -gt 50 ]]; then
    echo ""
    echo "(truncated, total $LINE_COUNT lines)"
  fi

  echo ""
  echo "→ 注意：型別名 grep 啟發式，可能含跨 namespace 同名誤判，請判讀過濾"
  echo "→ 建議：修改前先 Read 上述引用方，確認改動不會破壞它們"
  echo "→ 收尾：改完跑 dotnet build 驗證"
  exit 0
fi

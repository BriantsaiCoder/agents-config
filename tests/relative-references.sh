#!/usr/bin/env bash
# Portable skill-reference validator regression tests.
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
ROOT=$(cd "$SELF_DIR/.." && pwd)
CHECK="$ROOT/skills/auditing-skill-folder/scripts/check-relative-references.sh"
PASS=0; FAIL=0

ok() { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }

if [ ! -x "$CHECK" ]; then
  bad "relative-reference checker exists and is executable"
  printf '\n%d PASS / %d FAIL\n' "$PASS" "$FAIL"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/relative-references.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/valid/references" "$TMP/broken/references" "$TMP/placeholders/references"
cat > "$TMP/valid/SKILL.md" <<'EOF'
---
name: valid
description: fixture
---
[Guide](references/guide.md), `references/guide.md`, and
`references/guide.md#heading`.
EOF
printf '# guide\n' > "$TMP/valid/references/guide.md"
printf '[Sibling](other.md)\n' > "$TMP/valid/references/index.md"
printf '# other\n' > "$TMP/valid/references/other.md"

cat > "$TMP/broken/SKILL.md" <<'EOF'
---
name: broken
description: fixture
---
[Missing](references/missing.md), `templates/task.md`, and
`.github/skills/broken/templates/design.md`.
EOF
cat > "$TMP/broken/references/index.md" <<'EOF'
[Nested missing](missing-nested.md)
Nested inline pointers: `core/missing-deep.md` and `core/missing-dir/`.
Nested directory pointer: `advanced/`.
For details, see `missing-sibling.md`.
EOF

cat > "$TMP/placeholders/SKILL.md" <<'EOF'
---
name: placeholders
description: fixture
---
Project examples such as [generated](./src/generated.md),
`assets/templates/*.md`, and `references/<topic>.md` are not payload pointers.
EOF
printf '### `assets/` Directory\n' > "$TMP/placeholders/references/project-layout.md"

if "$CHECK" "$TMP/valid" >/dev/null 2>&1; then
  ok "valid SKILL and nested reference links pass"
else
  bad "valid SKILL and nested reference links pass"
fi

OUT=$("$CHECK" "$TMP/broken" 2>&1); RC=$?
[ "$RC" -eq 1 ] && ok "missing payload references fail" || bad "missing payload references fail"
for expected in references/missing.md templates/task.md .github/skills/broken/templates/design.md \
                missing-nested.md core/missing-deep.md core/missing-dir/; do
  printf '%s\n' "$OUT" | grep -Fq "$expected" &&
    ok "reports $expected" || bad "reports $expected"
done
printf '%s\n' "$OUT" | grep -Fq $'\tmissing-sibling.md' &&
  ok "reports navigational sibling pointer" || bad "reports navigational sibling pointer"
printf '%s\n' "$OUT" | grep -Fq $'\tadvanced/' &&
  ok "reports advanced/ directory pointer" || bad "reports advanced/ directory pointer"

if "$CHECK" "$TMP/placeholders" >/dev/null 2>&1; then
  ok "project examples and placeholder paths are ignored"
else
  bad "project examples and placeholder paths are ignored"
fi

mkdir -p "$TMP/symlink-corpus" "$TMP/empty"
ln -s "$TMP/broken" "$TMP/symlink-corpus/broken"
"$CHECK" "$TMP/symlink-corpus" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "top-level symlink skills are scanned" || bad "top-level symlink skills are scanned"

"$CHECK" "$TMP/empty" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "empty corpus fails as scanned nothing" || bad "empty corpus fails as scanned nothing"

printf '\n%d PASS / %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

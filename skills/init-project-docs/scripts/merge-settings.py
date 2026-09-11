#!/usr/bin/env python3
"""
Union-merge JSON 設定檔（Claude Code `.claude/settings.json`；亦可用於
Copilot `.github/hooks/*.json` 等同形狀的 JSON）。Codex 為 TOML，不適用本腳本。

用法：
    python merge-settings.py <existing.json> <template.json> [-o output.json]

語意：
- `permissions.allow` / `permissions.deny` / `permissions.ask`：list 聯集去重（保序）
- `sandbox.network.allowedDomains`：list 聯集去重
- `hooks.<event>`：Claude-style wrapper 在 matcher 與其他 wrapper metadata 相同時聯集
  內層 `hooks`；metadata 不同時保留為獨立 wrapper。Copilot flat entry 以完整
  entry 聯集去重。
- 其他欄位：existing 存在則保留，template 補未設定項

若 existing 不存在，輸出即 template。
"""

import argparse
import copy
import json
import sys
from pathlib import Path


def dedupe_preserve_order(items):
    seen = set()
    out = []
    for item in items:
        key = json.dumps(item, sort_keys=True) if isinstance(item, (dict, list)) else item
        if key in seen:
            continue
        seen.add(key)
        out.append(copy.deepcopy(item))
    return out


def merge_lists(existing, template):
    return dedupe_preserve_order(list(existing or []) + list(template or []))


def merge_hooks(existing, template):
    if not existing:
        return copy.deepcopy(template or {})
    if not template:
        return copy.deepcopy(existing)

    merged = copy.deepcopy(existing)
    for event, entries in template.items():
        if event not in merged:
            merged[event] = copy.deepcopy(entries)
            continue

        for entry in entries:
            if isinstance(entry, dict) and isinstance(entry.get("hooks"), list):
                wrapper_metadata = {k: v for k, v in entry.items() if k != "hooks"}
                matching_wrapper = next(
                    (
                        candidate
                        for candidate in merged[event]
                        if isinstance(candidate, dict)
                        and isinstance(candidate.get("hooks"), list)
                        and {k: v for k, v in candidate.items() if k != "hooks"}
                        == wrapper_metadata
                    ),
                    None,
                )
                if matching_wrapper is not None:
                    matching_wrapper["hooks"] = dedupe_preserve_order(
                        matching_wrapper["hooks"] + entry["hooks"]
                    )
                else:
                    merged[event].append(copy.deepcopy(entry))
            elif entry not in merged[event]:
                # Copilot hooks are flat entries. Their complete object is the identity;
                # matcher-only dedupe would discard distinct commands that omit matcher.
                merged[event].append(copy.deepcopy(entry))
    return merged


def deep_merge(existing, template):
    if existing is None:
        return template
    if template is None:
        return existing

    if isinstance(existing, dict) and isinstance(template, dict):
        out = dict(existing)
        for k, v in template.items():
            if k == "hooks":
                out[k] = merge_hooks(existing.get(k), v)
            elif k == "permissions" and isinstance(v, dict):
                out[k] = deep_merge(existing.get(k, {}), v)
            elif k == "allowedDomains":
                out[k] = merge_lists(existing.get(k), v)
            elif k in ("allow", "deny", "ask"):
                out[k] = merge_lists(existing.get(k), v)
            elif isinstance(v, dict):
                out[k] = deep_merge(existing.get(k), v)
            elif isinstance(v, list):
                out[k] = merge_lists(existing.get(k), v)
            else:
                out[k] = existing.get(k, v)
        return out

    return existing


def main():
    parser = argparse.ArgumentParser(description="Union-merge settings.json")
    parser.add_argument("existing", help="既有 settings.json 路徑")
    parser.add_argument("template", help="模板 settings.json 路徑")
    parser.add_argument("-o", "--output", help="輸出路徑（預設 stdout）")
    args = parser.parse_args()

    existing_path = Path(args.existing)
    template_path = Path(args.template)

    existing = {}
    if existing_path.exists():
        with existing_path.open(encoding="utf-8") as f:
            existing = json.load(f)

    if not template_path.exists():
        print(f"Template not found: {template_path}", file=sys.stderr)
        sys.exit(1)
    with template_path.open(encoding="utf-8") as f:
        template = json.load(f)

    merged = deep_merge(existing, template)
    text = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"

    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()

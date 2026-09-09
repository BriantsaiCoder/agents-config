---
name: ui-ux-pro-max
description: "Use the offline design database when a UI needs design-system direction or a specific style, palette, typography, layout, or UX lookup."
---

# UI/UX Pro Max — Design Intelligence

Offline design intelligence: 84 styles, 192 palettes and product types, 74 font pairings, 161 reasoning rules, 25 chart types, UX guidance, and 22 stack-specific datasets.

## Boundary

- Use for a new UI or redesign without a visual target, or for a specific gap in an existing design system.
- Preserve a supplied URL, Figma file, screenshot, mockup, or repo design system as the source of truth.
- Do not use for implementation, CSS/responsive fixes, or rendered-page review. Stack skills, `css-ui-best-practices`, and `web-design-reviewer` own those layers.

## Workflow

1. Detect the product, audience, visual constraints, and stack from the request and project files. Never guess a stack when the repository identifies it.

2. For a new UI or redesign without a visual target, generate the baseline:

```bash
python3 -B "$HOME/.agents/skills/ui-ux-pro-max/scripts/search.py" \
  "<product> <industry> <tone>" --design-system -p "<project>"
```

Use the result to frame materially distinct visual directions only where comparison helps resolve the choice. Wait for the user to select one before implementation unless the user explicitly delegated the choice or already accepted a visual target. When the choice is explicitly delegated, select a concrete direction, state brief assumptions, and continue. If a visual target already exists, skip this ideation step.

3. Query only the unresolved dimension when more detail is needed:

```bash
python3 -B "$HOME/.agents/skills/ui-ux-pro-max/scripts/search.py" "<keywords>" --domain <domain>
python3 -B "$HOME/.agents/skills/ui-ux-pro-max/scripts/search.py" "<keywords>" --stack <stack>
```

Run the script with `--help` for supported domains, stacks, output formats, and design dials.

4. Persist an accepted design system only when cross-session reuse is useful:

```bash
python3 -B "$HOME/.agents/skills/ui-ux-pro-max/scripts/search.py" \
  "<query>" --design-system --persist -p "<project>" --output-dir "<project-root>"
```

Add `--page "<page>"` for an override. Existing Master and page files are preserved independently unless `--force` is explicit. Read `design-system/<project>/MASTER.md`, then apply `pages/<page>.md` when present.

5. Hand the selected direction to the host's stack implementation workflow. Finish with browser evidence and `web-design-reviewer`.

## Reliability

- Python 3 standard library only; no network or package install.
- On a search error, label the lookup `UNAVAILABLE` with the failing probe and stop only dependent work. Never invent a successful lookup or replace it with plausible defaults.
- On zero results, retry once with broader terms; if still empty, label any general guidance as a fallback.
- Read [quick-reference.md](references/quick-reference.md) for detailed UX rules and [pro-rules.md](references/pro-rules.md) for native/mobile pre-delivery checks only when relevant.

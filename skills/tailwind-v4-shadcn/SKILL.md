---
name: tailwind-v4-shadcn
description: "Set up, migrate, or fix Tailwind v4 + shadcn/ui token integration and dark mode."
---

# Tailwind v4 + shadcn/ui

Use this skill for Tailwind CSS v4 and shadcn/ui integration. The fragile part is CSS token wiring: Tailwind v4 does not use the old v3 theme config flow.

## Required Workflow

1. Check installed versions of `tailwindcss`, `@tailwindcss/vite`, and shadcn output before editing.
2. Use `@tailwindcss/vite` for Vite projects and import Tailwind from CSS with `@import "tailwindcss";`.
3. Set `components.json` for v4: empty Tailwind config path, CSS file path, `cssVariables: true`.
4. Define semantic CSS variables in `:root` and `.dark`.
5. Map every semantic variable in `@theme inline` so utilities such as `bg-background` and `text-primary` exist.
6. Apply base body styles with raw CSS variables, not `hsl(var(...))` double-wrapping.
7. Run the verification checklist below on the changed UI.

## Critical Rules

- Preserve complete valid project color values such as `oklch(...)` or `hsl(...)`; map semantic tokens with `var(...)` and convert formats only for an explicit color migration.
- Do not put `:root` or `.dark` inside `@layer base`.
- Do not use nested `.dark { @theme { ... } }`.
- Do not use `tailwind.config.ts` as the source of v4 theme tokens.
- Avoid `@apply` for semantic token plumbing.
- Use semantic utilities (`bg-background`, `text-foreground`) instead of `dark:` variants for theme colors.

## Reference Map

| Need | File |
|---|---|
| Full four-step architecture | `references/architecture.md` |
| Dark mode provider/toggle | `references/dark-mode.md`, `templates/theme-provider.tsx` |
| Common failures | `references/common-gotchas.md` |
| v3 to v4 migration | `references/migration-guide.md` |
| Copyable project files | `templates/index.css`, `templates/components.json`, `templates/vite.config.ts`, `templates/utils.ts` |
| Rule text for agents/tools | `rules/tailwind-v4-shadcn.md` |

## Verification Checklist

- `bg-background`, `text-foreground`, and primary/accent utilities render.
- Dark mode toggles by changing the `.dark` class on the root element.
- shadcn components read the configured CSS file.
- `npm run build` or the project build command succeeds.

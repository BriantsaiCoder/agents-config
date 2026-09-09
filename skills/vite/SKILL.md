---
name: vite
description: "Configure, review, or debug Vite builds, dev-server behavior, plugins, assets, and SSR. Test-runner concerns use vitest."
---

# Vite

> Vite 8 stable (Rolldown + Oxc default); 7 still common in lockfiles. Verify major version — config shape, plugin hooks, SSR API differ across 5→6→7→8.

## Workflow

1. Identify package/version, Vite config, and aliases relevant to the change; inspect environment key definitions through safe examples or schemas. Access secret-bearing `.env*` only when authorized and keep values out of output.
2. Identify **target mode**: dev / `vite build` / `build.lib` / SSR / test.
3. Prefer `vite.config.ts` + ESM unless project uses `.js` / `.mjs`.
4. Only `VITE_`-prefixed env vars reach client.
5. Match existing aliases / plugins / proxy / SSR conventions.
6. Verify via project scripts.

## Mode Selection

| Goal | Use | Key constraint |
|---|---|---|
| Standard SPA | `vite build` → `dist/` | Framework plugin handles SSR if needed |
| Library | `build.lib` + `rolldownOptions.external` (Vite ≤7: `rollupOptions`) | Externalize peers, emit `.d.ts` via `vite-plugin-dts` |
| Manual SSR | `vite build --ssr` + split entries | `ssr.noExternal` for ESM-only deps that must bundle |
| Static | `vite build` + `vite preview` | Check `base` for subpath deploys |
| Monorepo | one config per app + `mergeConfig` | One root config breaks `root` / `outDir` |

## Plugin Order

Top-down for transforms, bottom-up for `enforce: 'post'`.

1. `enforce: 'pre'` first (svgr, alias rewriters).
2. Framework plugin early (`@vitejs/plugin-vue` / `-react`).
3. Post-transform plugins (legacy polyfill, compression) via `enforce: 'post'`.
4. Don't mix Babel + SWC `@vitejs/plugin-react` — breaks HMR.

HMR broken after plugin add → suspect order first.

## Anti-Patterns

- Secrets in `VITE_*` — ships to browser; use server proxy / runtime config endpoint.
- Library CSS side-effect imports drop under tree-shake — set `sideEffects: ["**/*.css"]`.
- `process.env.X` in client — Vite doesn't shim; use `import.meta.env.VITE_X`.
- `server.proxy` + auth cookies missing `changeOrigin: true` + `cookieDomainRewrite` → cookies silently fail.
- `build.outDir` outside `root` without `emptyOutDir: true` → Vite refuses (avoids wiping files).
- CommonJS plugins in ESM config → wrap with `vite-plugin-commonjs` or upgrade.

## Rolldown (default in Vite 8)

Vite 8 = Rolldown + Oxc; compat layer auto-converts old config, so most projects upgrade directly. Plugin-heavy: try `rolldown-vite` on Vite 7 first. See `references/rolldown-migration.md`.

## Review Checklist

- Vite major matches plugin versions / config shape.
- Plugins ordered intentionally.
- Asset imports use `?raw` / `?url` / `?inline` / `import.meta.glob`.
- Library defines entry / formats / externals / `.d.ts`.
- SSR splits `ssr.external` from `ssr.noExternal`.
- `server.proxy` tested; `base` correct for subpath deploys.

## Reference Map

- `references/core-config.md` — `vite.config.*` knobs (root, base, alias, server, preview)
- `references/core-features.md` — assets, env, HMR, glob imports, JSON/CSS modules
- `references/core-plugin-api.md` — plugin hook authoring/debugging
- `references/build-and-ssr.md` — production build, library mode, SSR, manual chunking
- `references/environment-api.md` — Vite 6+ multi-env builds
- `references/rolldown-migration.md` — Rollup → Rolldown breakages + plugin compat

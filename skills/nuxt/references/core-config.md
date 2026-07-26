---
name: configuration
description: Nuxt configuration files including nuxt.config.ts, app.config.ts, and runtime configuration
---

# Nuxt Configuration

Nuxt uses configuration files to customize application behavior. The main configuration options are `nuxt.config.ts` for build-time settings and `app.config.ts` for runtime settings.

## nuxt.config.ts

The main configuration file at the root of your project:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  // Configuration options
  devtools: { enabled: true },
  modules: ['@nuxt/ui'],
})
```

### compatibilityDate

`compatibilityDate` pins the behavior of Nitro presets, Nuxt Image, and other modules to a point in time, letting them change defaults without a major bump. Scaffolded Nuxt 4 projects always include it; a hand-written config without it will silently drift when dependencies update. To adopt newer behavior, move the date forward and re-verify with `npm run build && npm run preview`.

### future.compatibilityVersion

Opt in to the *next* major's defaults ahead of time:

```ts
export default defineNuxtConfig({
  future: { compatibilityVersion: 5 },
})
```

Setting `5` on Nuxt 4 enables Nuxt v5 defaults and the Vite Environment API — when this key is present, the documented v4 defaults no longer describe the project. Read it before reasoning about any default.

### Environment Overrides

Configure environment-specific settings:

```ts
export default defineNuxtConfig({
  $production: {
    routeRules: {
      '/**': { isr: true },
    },
  },
  $development: {
    // Development-specific config
  },
  $env: {
    staging: {
      // Staging environment config
    },
  },
})
```

Use `--envName` flag to select environment: `nuxt build --envName staging`

## Runtime Config

For values that need to be overridden via environment variables:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    // Server-only keys
    apiSecret: '123',
    // Keys within public are exposed to client
    public: {
      apiBase: '/api',
    },
  },
})
```

Override with environment variables:

```ini
# .env
NUXT_API_SECRET=api_secret_token
NUXT_PUBLIC_API_BASE=https://api.example.com
```

Access in components/composables:

```vue
<script setup lang="ts">
const config = useRuntimeConfig()
// Server: config.apiSecret, config.public.apiBase
// Client: config.public.apiBase only
</script>
```

## App Config

For public tokens determined at build time (not overridable via env vars):

```ts
// app/app.config.ts
export default defineAppConfig({
  title: 'Hello Nuxt',
  theme: {
    dark: true,
    colors: {
      primary: '#ff0000',
    },
  },
})
```

Access in components:

```vue
<script setup lang="ts">
const appConfig = useAppConfig()
</script>
```

## runtimeConfig vs app.config

| Feature | runtimeConfig | app.config |
|---------|--------------|------------|
| Client-side | Hydrated | Bundled |
| Environment variables | Yes | No |
| Reactive | Yes | Yes |
| Hot module replacement | No | Yes |
| Non-primitive JS types | No | Yes |

**Use runtimeConfig** for secrets and values that change per environment.
**Use app.config** for public tokens, theme settings, and non-sensitive config.

## External Tool Configuration

Nuxt uses `nuxt.config.ts` as single source of truth. Configure external tools within it:

```ts
export default defineNuxtConfig({
  // Nitro configuration
  nitro: {
    // nitro options
  },
  // Vite configuration
  vite: {
    // vite options
    vue: {
      // @vitejs/plugin-vue options
    },
  },
  // PostCSS configuration
  postcss: {
    // postcss options
  },
})
```

## Vue Configuration

Since Vue 3.5, variables destructured from `defineProps()` are reactive on their own, and Nuxt 4 enables reactive props destructure by default — you do **not** need `vue.propsDestructure`. The key still exists, but it only matters when maintaining a project on Vue < 3.5:

```ts
export default defineNuxtConfig({
  vue: {
    propsDestructure: true, // only needed on Vue < 3.5
  },
})
```

Other `vue` sub-keys (e.g. shipping the Vue compiler into the runtime bundle) stay off by default to keep the bundle small.

<!-- 
Source references:
- https://nuxt.com/docs/getting-started/configuration
- https://nuxt.com/docs/guide/going-further/runtime-config
- https://nuxt.com/docs/api/nuxt-config
-->

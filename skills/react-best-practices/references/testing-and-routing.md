---
name: React Testing and Routing
---

# React Testing and Routing

## Table of Contents
- [Scope and companion skills](#scope-and-companion-skills)
- [React component test seams](#react-component-test-seams)
- [Hook Testing](#hook-testing)
- [MSW in React component tests](#msw-in-react-component-tests)
- [React Router v7+](#react-router-v7)
- [Next.js App Router](#nextjs-app-router)

---

## Scope and companion skills

This reference covers React-specific testing seams and routing patterns only.

- `testing-library-react-best-practices` owns query priority, `userEvent`, async UI assertions, form interactions, accessible-name assertions, and flaky component-test diagnosis.
- `vitest` owns Vitest runner config, `vi.mock`, timers, coverage, browser mode, and Vite-shared test setup.
- `jest-best-practices` owns Jest config, transforms, ESM/CJS mocking, fake timers, snapshots, and existing Jest suite triage.
- `react-router-framework-mode` owns React Router framework-mode loaders/actions, route modules, and data APIs in depth.
- `next-best-practices` owns Next.js App Router, Server Components, Server Actions, route handlers, cache boundaries, and metadata.

---

## React component test seams

Keep React component tests close to the production composition boundary. Create small render helpers only for providers the component genuinely requires.

```tsx
function renderWithProviders(ui: React.ReactElement, options?: { initialRoute?: string }) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[options?.initialRoute ?? '/']}>
        {ui}
      </MemoryRouter>
    </QueryClientProvider>
  );
}

renderWithProviders(<Dashboard />, { initialRoute: '/dashboard' });
```

Prefer one test helper per feature boundary over one global mega-helper. A global helper hides required dependencies and makes tests pass with providers production code does not use.

Use this reference when the problem is React-specific:

- Component requires `Context`, router state, or TanStack Query provider.
- Component suspends or renders through an Error Boundary.
- Custom hook needs provider wrappers or `rerender` semantics.
- Route component depends on React Router loader/action data.
- Next.js component crosses Server/Client Component boundaries.

---

## Hook Testing

Use `renderHook` for custom hooks that have observable return values or callbacks. If the hook only coordinates UI behavior, prefer testing the component that uses it.

```tsx
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('應該遞增和遞減', () => {
    const { result } = renderHook(() => useCounter(0));

    expect(result.current.count).toBe(0);

    act(() => result.current.increment());
    expect(result.current.count).toBe(1);

    act(() => result.current.decrement());
    expect(result.current.count).toBe(0);
  });

  it('應該在 initialValue 變更時重置', () => {
    const { result, rerender } = renderHook(
      ({ initial }) => useCounter(initial),
      { initialProps: { initial: 5 } }
    );
    expect(result.current.count).toBe(5);

    rerender({ initial: 10 });
    expect(result.current.count).toBe(10);
  });
});
```

When a hook needs context, pass a wrapper instead of mocking React internals:

```tsx
const wrapper = ({ children }: { children: React.ReactNode }) => (
  <AuthProvider user={testUser}>{children}</AuthProvider>
);

const { result } = renderHook(() => useCurrentUser(), { wrapper });
```

---

## MSW in React component tests

Use MSW when the user-visible behavior depends on network state. Keep the handler contract close to the real API shape so tests cover loading, success, empty, and error UI without mocking the component's data hook.

### Handlers

```ts
// src/test/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Alice', email: 'alice@test.com' });
  }),

  http.post('/api/login', async ({ request }) => {
    const body = await request.json() as { email: string; password: string };
    if (body.password === 'wrong') {
      return HttpResponse.json({ message: '密碼錯誤' }, { status: 401 });
    }
    return HttpResponse.json({ token: 'fake-jwt' });
  }),

  http.get('/api/products', ({ request }) => {
    const url = new URL(request.url);
    const page = Number(url.searchParams.get('page') ?? '1');
    return HttpResponse.json({
      items: [{ id: '1', name: `商品-${page}` }],
      nextPage: page < 3 ? page + 1 : null,
    });
  }),
];
```

### Server lifecycle

```ts
// src/test/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);

// src/test/setup.ts
import { server } from './server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Override handlers inside the individual test when testing a specific API state:

```tsx
import { server } from '../test/server';
import { http, HttpResponse } from 'msw';

it('應該在 API 錯誤時顯示錯誤訊息', async () => {
  server.use(
    http.get('/api/users/:id', () => HttpResponse.json({ message: '找不到使用者' }, { status: 404 }))
  );

  render(<UserProfile userId="999" />);
  expect(await screen.findByText('載入失敗')).toBeInTheDocument();
});
```

---

## React Router v7+

Use `react-router-framework-mode` for full framework-mode architecture. Keep this section as a React-specific reminder of what route modules expose to components.

React-specific checks:

- Route components should receive typed loader/action data instead of re-fetching the same data in `useEffect`.
- Keep route-level data writes in actions; keep local component state for transient UI only.
- Test route components through a router-aware render helper when loader data, navigation, or params affect visible behavior.
- Avoid duplicating framework-mode rules here; open `react-router-framework-mode` for route module conventions, generated `+types`, nested route config, and loader/action details.

---

## Next.js App Router

Use `next-best-practices` for full App Router guidance. Keep this section for React-level reminders that affect component boundaries.

React-specific checks:

- Layouts preserve state across navigation; do not put per-page reset logic in shared layouts.
- `loading.tsx` is a Suspense boundary and `error.tsx` is a client Error Boundary; keep recovery UI user-visible.
- Server Components cannot use hooks, browser APIs, or event handlers. Add `"use client"` at the smallest interactive boundary.
- Server Actions can replace small API routes, but validation, auth, and `revalidatePath` / `revalidateTag` remain explicit server concerns.
- Parallel routes and intercepting routes affect composition, not component state rules; open `next-best-practices` for file conventions and cache behavior.

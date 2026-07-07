# Jest — Deep Reference

Detail for items the SKILL.md compresses. Read when the symptom matches.

## Mocking — Full Rules

- Mock external boundaries: network, clock, storage, filesystem, browser APIs, router, process env, third-party SDKs.
- Do not mock the module under test or its nearest business logic just to make assertions easier.
- Manual mocks live in case-sensitive `__mocks__/` folders. Use them only for stable, shared fakes; keep them synchronized with the real module.
- Prefer partial mocks with `jest.requireActual()` when only one export needs replacement.
- Restore state between tests: `clearAllMocks` clears call history, `resetAllMocks` also resets implementations, `restoreAllMocks` restores spies/replaced properties.

## Hoisting (CJS / Babel-transformed)

- `jest.mock()` is hoisted by the Babel transform above all imports/requires in the same file.
- Keep it in the same scope as the import/require it affects.
- Variables referenced inside the factory must be prefixed `mock` or be lazily evaluated, or hoisting will fail with "ReferenceError: Cannot access ... before initialization".

## Native ESM Mocking

- Static imports run before `jest.mock()` setup — hoisting does not work the same way.
- Use `@jest/globals`, `jest.unstable_mockModule()`, and dynamic `import()` after registering the mock:

```js
import { jest } from '@jest/globals';
jest.unstable_mockModule('./service.js', () => ({
  fetchUser: jest.fn(),
}));
const { fetchUser } = await import('./service.js');
const { handler } = await import('./handler.js');
```

## Timers and Async

- Pair `jest.useFakeTimers()` with `jest.useRealTimers()` in cleanup unless the whole file intentionally owns fake timers.
- Use `runOnlyPendingTimers()` for recursive timers; avoid `runAllTimers()` when code schedules new timers repeatedly.
- Prefer async assertions from the UI/framework testing library over manual sleeps.

## Flake Triage Order

Do not raise global timeouts first. Check in this order:

1. Missing `await` on async expectations.
2. Leaked timers (`useFakeTimers` not restored).
3. Shared module state across tests.
4. Mocks set up after the import that captured the original module.
5. Environment mismatch (`node` vs `jsdom`).
6. Real network or filesystem access in unit tests.

## Common Mistakes (long form)

- **Migrating to Vitest because Jest config is annoying.** Don't, unless the user explicitly asks.
- **Assuming Babel TypeScript transform is typechecking.** It is not. Run `tsc --noEmit` separately.
- **Using jsdom for every test file.** Pure logic should run under `node` for speed.
- **Mocking a dependency after importing the module that already captured it.** The original reference is already bound.
- **Forgetting that native ESM mocking does not behave like hoisted CJS `jest.mock()`.**
- **Leaving fake timers, env vars, spies, or global DOM mocks active across tests.**
- **Replacing behavior assertions with large snapshots.** Snapshot only stable, small outputs.

## Validation Loop

1. Reproduce with the smallest targeted Jest command.
2. Identify whether failure is config, transform, environment, mock order, async/timer, or product behavior.
3. Fix the narrowest layer.
4. Rerun targeted test, then the relevant package/suite when shared config changed.
5. Report any remaining gaps: missing typecheck, untested browser behavior, skipped E2E, or flaky suite risk.

## Official Docs

- Jest configuration: https://jestjs.io/docs/configuration
- ECMAScript modules: https://jestjs.io/docs/ecmascript-modules
- Manual mocks: https://jestjs.io/docs/manual-mocks
- Timer mocks: https://jestjs.io/docs/timer-mocks
- Mock functions: https://jestjs.io/docs/mock-functions

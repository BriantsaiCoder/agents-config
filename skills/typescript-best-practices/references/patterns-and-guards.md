---
name: Patterns and Type Guards
---

# Patterns & Type Guards

建模複雜狀態、驗證外部資料、或寫 type guards 時讀取此檔案。涵蓋 Discriminated Unions、Type Guards、Exhaustive Checking、Branded Types、Zod/Valibot 驗證、Narrowing Patterns。

## Table of Contents
- [Discriminated Unions](#discriminated-unions)
- [Type Guards: typeof, instanceof, in](#type-guards-typeof-instanceof-in)
- [Custom Type Guards (is)](#custom-type-guards-is)
- [Assertion Functions (asserts)](#assertion-functions-asserts)
- [Narrowing Patterns](#narrowing-patterns)
- [Exhaustive Checking with never](#exhaustive-checking-with-never)
- [Branded Types](#branded-types)
- [Zod Schema Validation](#zod-schema-validation)
- [Valibot as Alternative](#valibot-as-alternative)

## Discriminated Unions

每個 variant 共享一個 literal 型別的 discriminant field，讓 TS 自動 narrow。

### 建模 API Responses

```typescript
type ApiResult<T> =
  | { status: 'success'; data: T; timestamp: Date }
  | { status: 'error'; error: Error; retryable: boolean }
  | { status: 'loading' };

function handleResult(result: ApiResult<User>) {
  switch (result.status) {
    case 'success':
      console.log(result.data.name); // ✅ data 存在
      break;
    case 'error':
      if (result.retryable) retry(); // ✅ retryable 存在
      break;
    case 'loading':
      showSpinner();
      break;
  }
}
```

### 建模 Form State

```typescript
type FormState =
  | { step: 'input'; values: Partial<FormValues> }
  | { step: 'validating'; values: FormValues }
  | { step: 'submitting'; values: FormValues; requestId: string }
  | { step: 'success'; result: SubmitResult }
  | { step: 'error'; values: FormValues; error: string };
```

### 建模 Auth State

```typescript
type AuthState =
  | { status: 'anonymous' }
  | { status: 'authenticating' }
  | { status: 'authenticated'; user: User; token: string }
  | { status: 'error'; error: string; lastAttempt: Date };

function getDisplayName(auth: AuthState): string {
  if (auth.status === 'authenticated') {
    return auth.user.name; // ✅ user 存在
  }
  return 'Guest';
}
```

### Discriminated Union vs Optional Fields

```typescript
// ❌ 允許不合法狀態 — data 和 error 可以同時存在
type BadModal = {
  isOpen: boolean;
  title?: string;
  onClose?: () => void;
};

// ✅ 每個狀態明確
type Modal =
  | { isOpen: false }
  | { isOpen: true; title: string; onClose: () => void };
```

## Type Guards: typeof, instanceof, in

### typeof — 適合 primitive 型別

```typescript
function format(value: string | number): string {
  if (typeof value === 'string') return value.toUpperCase();
  return value.toFixed(2); // TS 知道是 number
}
// typeof 支援：'string' | 'number' | 'boolean' | 'symbol' | 'undefined' | 'object' | 'function' | 'bigint'
```

### instanceof — 適合 class 實例

```typescript
function handleError(error: Error | string) {
  if (error instanceof TypeError) {
    console.log(error.message); // TypeError-specific
  } else if (error instanceof RangeError) {
    console.log(error.message); // RangeError-specific
  } else if (typeof error === 'string') {
    console.log(error);
  }
}
```

### in operator — 適合結構區分

```typescript
type Fish = { swim: () => void };
type Bird = { fly: () => void };

function move(animal: Fish | Bird) {
  if ('swim' in animal) {
    animal.swim(); // ✅ Fish
  } else {
    animal.fly();  // ✅ Bird
  }
}
```

## Custom Type Guards (is)

回傳 `x is T` 的函數，讓 TS 在 true branch 中 narrow 型別。

```typescript
interface User { id: string; name: string; email: string }

function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value &&
    typeof (value as User).id === 'string' &&
    typeof (value as User).name === 'string'
  );
}

function process(data: unknown) {
  if (isUser(data)) {
    console.log(data.name); // ✅ data is User
  }
}
```

### 搭配 Array.filter

```typescript
type MaybeUser = User | null | undefined;
const users: MaybeUser[] = [getUser(1), null, getUser(3)];

// ❌ filter(Boolean) 不會 narrow 型別
const bad = users.filter(Boolean); // still (User | null | undefined)[]

// ✅ 用 type guard
const good = users.filter((u): u is User => u != null); // User[]
```

## Assertion Functions (asserts)

不回傳值，在條件不滿足時 throw。之後的程式碼都被 narrow。

```typescript
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertDefined<T>(value: T | null | undefined, name: string): asserts value is T {
  if (value == null) throw new Error(`Expected ${name} to be defined`);
}

function assertUser(value: unknown): asserts value is User {
  if (!isUser(value)) {
    throw new Error(`Expected User, got: ${JSON.stringify(value)}`);
  }
}

// 使用
function processOrder(order: Order | null) {
  assertDefined(order, 'order');
  console.log(order.total); // ✅ order 是 Order
}
```

## Narrowing Patterns

### Truthiness narrowing

```typescript
function greet(name: string | null | undefined) {
  if (name) {
    console.log(name.toUpperCase()); // ✅ string
  }
}
// ⚠️ 空字串 '' 也是 falsy — 如果空字串合法，用 name != null
```

### Equality narrowing

```typescript
function handle(x: string | number, y: string | boolean) {
  if (x === y) {
    x.toUpperCase(); // ✅ 唯一共同型別是 string
  }
}
```

### 組合 narrowing

```typescript
type Shape =
  | { kind: 'circle'; radius: number }
  | { kind: 'rect'; width: number; height: number };

function area(shape: Shape): number {
  if (shape.kind === 'circle') {
    return Math.PI * shape.radius ** 2;
  }
  return shape.width * shape.height; // TS 知道是 rect
}
```

## Exhaustive Checking with never

### 基本模式

```typescript
type Status = 'active' | 'inactive' | 'pending';

function statusLabel(status: Status): string {
  switch (status) {
    case 'active': return 'Active';
    case 'inactive': return 'Inactive';
    case 'pending': return 'Pending';
    default: {
      const _exhaustive: never = status;
      return _exhaustive; // 忘記處理新 variant → 編譯錯誤
    }
  }
}
```

### Helper function

```typescript
function assertNever(value: never, message?: string): never {
  throw new Error(message ?? `Unexpected value: ${JSON.stringify(value)}`);
}

// 新增 'archived' 到 Status 後，所有 switch 都會報錯
function statusLabel(status: Status): string {
  switch (status) {
    case 'active': return 'Active';
    case 'inactive': return 'Inactive';
    case 'pending': return 'Pending';
    default: return assertNever(status);
  }
}
```

## Branded Types

防止語義上不同但結構相同的值互相混用。

### 基本 branded type

```typescript
type Brand<T, B extends string> = T & { readonly __brand: B };

type UserId = Brand<string, 'UserId'>;
type OrderId = Brand<string, 'OrderId'>;
type Email = Brand<string, 'Email'>;

// Factory functions
function UserId(value: string): UserId { return value as UserId; }
function OrderId(value: string): OrderId { return value as OrderId; }

// 使用
function getUser(id: UserId): User { /* ... */ }
function getOrder(id: OrderId): Order { /* ... */ }

const userId = UserId('user-123');
const orderId = OrderId('order-456');
getUser(userId);    // ✅
// getUser(orderId); // ❌ 編譯錯誤 — 防止 ID 混用
```

### 帶驗證的 branded type

```typescript
type PositiveInt = Brand<number, 'PositiveInt'>;

function PositiveInt(value: number): PositiveInt {
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`Expected positive integer, got ${value}`);
  }
  return value as PositiveInt;
}

type EmailAddress = Brand<string, 'EmailAddress'>;

function EmailAddress(value: string): EmailAddress {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new Error(`Invalid email: ${value}`);
  }
  return value as EmailAddress;
}
```

## Zod Schema Validation

### 基本用法

```typescript
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.coerce.date(),
});

// 從 schema 推斷型別 — 永遠同步
type User = z.infer<typeof UserSchema>;

// 驗證外部資料
async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  const data: unknown = await res.json();
  return UserSchema.parse(data); // throws ZodError if invalid
}

// 安全驗證（不 throw）
function safeParseUser(data: unknown): User | null {
  const result = UserSchema.safeParse(data);
  return result.success ? result.data : null;
}
```

### 進階 patterns

```typescript
// Discriminated union schema
const EventSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('click'), x: z.number(), y: z.number() }),
  z.object({ type: z.literal('keypress'), key: z.string() }),
  z.object({ type: z.literal('scroll'), delta: z.number() }),
]);

// 組合 schema
const CreateUserSchema = UserSchema.omit({ id: true, createdAt: true });
const UpdateUserSchema = CreateUserSchema.partial();

// 環境變數驗證
const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
});
export const env = EnvSchema.parse(process.env);
```

## Valibot as Alternative

Valibot 是 Zod 的輕量替代方案，支援 tree-shaking，bundle size 更小。

```typescript
import * as v from 'valibot';

const UserSchema = v.object({
  id: v.pipe(v.string(), v.uuid()),
  name: v.pipe(v.string(), v.minLength(1), v.maxLength(100)),
  email: v.pipe(v.string(), v.email()),
  role: v.picklist(['admin', 'user', 'guest']),
});

type User = v.InferOutput<typeof UserSchema>;

// 驗證
const user = v.parse(UserSchema, data);          // throws on invalid
const result = v.safeParse(UserSchema, data);     // { success, output/issues }

// 組合
const CreateUserSchema = v.omit(UserSchema, ['id']);
const UpdateUserSchema = v.partial(CreateUserSchema);
```

### Zod vs Valibot 選擇建議

| 考量 | Zod | Valibot |
|---|---|---|
| Bundle size | ~13KB min+gzip | ~1-2KB (tree-shaken) |
| API 風格 | Method chaining | Functional (pipe) |
| 生態系統 | 成熟，tRPC/React Hook Form 整合 | 較新，快速成長 |
| 建議場景 | 後端、全端框架 | 前端、bundle 敏感的專案 |

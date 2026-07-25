---
name: Design System Patterns (Tailwind v4 + shadcn/ui)
---

# Design System Patterns

補充 SKILL.md 以外，建立 production-grade 設計系統時會用到的進階 pattern。與 `references/tailwind.md` 搭配閱讀：tailwind.md 講語法，本檔講「如何把 tokens、variants、components 組裝成可維護的 design system」。

## 1. Token Hierarchy — Brand → Semantic → Component

Token 分三層，決不跨層直接用 raw value：

```
Brand Tokens (抽象原始色)
    └── Semantic Tokens (用途 / 意義)
        └── Component Tokens (具體元件用)

e.g.  oklch(45% 0.2 260)  →  --color-primary  →  bg-primary (Button)
```

規則：

- 元件 class 一律只寫 semantic token（`bg-primary`、`text-muted-foreground`），**不寫 raw palette**（`bg-blue-500`）。
- Dark mode 透過覆寫 semantic token 達成，元件不需 `dark:` 雙寫。
- 新增一個 brand color 前，先問：是否有現成 semantic token 可以覆用？

## 2. HSL CSS Variables — shadcn 相容風格（替代 OKLCH）

OKLCH vs HSL 取捨：OKLCH 色彩感知均勻、漸變自然，適合純自訂品牌系統；HSL + shadcn 相容性最好，沿用社群生態較省成本。

**token 接線的正本是 `tailwind-v4-shadcn`**（`templates/index.css` + `SKILL.md` 的 Critical Rules），本檔不重複。理由是 v3 與 v4 的 token 形式不相容，兩份並存會讓實作端挑錯版本：

| | v3（已過時） | v4（正本） |
|---|---|---|
| `:root` 位置 | 包在 `@layer base` 內 | **頂層**，不得放進 `@layer base` |
| 變數值 | 裸 triplet `--primary: 222.2 47.4% 11.2%` | 自帶函式 `--primary: hsl(221.2 83.2% 53.3%)` |
| 對應 utility | `@theme { --color-primary: hsl(var(--primary)) }` | `@theme inline` 純 var 映射 |

兩套混用會產出 `hsl(hsl(...))`，整站顏色靜默壞掉。實作 shadcn token 一律讀 `tailwind-v4-shadcn`。

## 3. `cn()` Utility — className 合併的標配

shadcn 社群慣例，合併 conditional Tailwind classes 並自動處理衝突（例：`px-2` 與 `px-4` 保留後者）：

```ts
// lib/utils.ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

使用：

```tsx
<Button className={cn("bg-primary", isDanger && "bg-destructive", className)}>
```

## 4. CVA (Class Variance Authority) — Type-safe Variants

元件 variant 用 CVA 取代手寫 `if/else` 或 className object，compile-time 型別安全：

```tsx
import { cva, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 px-3",
        lg: "h-11 px-8",
        icon: "size-10", // 用 v4 size-* 簡寫取代 h-10 w-10
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants>;

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
```

要點：

- `defaultVariants` 讓 `<Button>` 可以不帶 prop。
- `compoundVariants`（未示範）可定義「variant A + size B 時追加 class」。
- **React 19: `ref` 已是普通 prop，不再需要 `forwardRef`**。舊 shadcn 範例多數仍寫 `forwardRef`，新專案可省略。

## 5. Tailwind v4 — `size-*` 與 `@custom-variant`

```html
<!-- v4 新 shorthand：width === height 時用 size-* -->
<span class="size-10">...</span>  <!-- 取代 h-10 w-10 -->
<span class="size-full">...</span>
```

Dark mode class strategy（v4 語法，取代 config 檔 `darkMode: 'class'`）：

```css
/* 兩種寫法都支援，擇一 */
@custom-variant dark (&:where(.dark, .dark *));
/* 或 */
@variant dark (&:where(.dark, .dark *));
```

## 6. Compound Components — Card / Dialog 結構

多 sub-component 組合時，匯出扁平命名空間（Card + CardHeader + CardContent），不要巢狀 `Card.Header`：

```tsx
export { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter };

// usage
<Card>
  <CardHeader>
    <CardTitle>Account</CardTitle>
    <CardDescription>Manage your settings</CardDescription>
  </CardHeader>
  <CardContent>...</CardContent>
  <CardFooter><Button>Save</Button></CardFooter>
</Card>
```

理由：tree-shakable、命名空間與其他 libs 不衝突、TypeScript auto-import 友善。

## 7. tailwindcss-animate — Radix 動畫慣用

搭配 Radix (`data-[state=open]` / `data-[state=closed]`) 做 enter/exit 動畫：

```tsx
<DialogContent
  className={cn(
    "fixed left-1/2 top-1/2 z-50 w-full max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 border bg-background p-6 shadow-lg",
    "data-[state=open]:animate-in data-[state=closed]:animate-out",
    "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
    "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
    "sm:rounded-lg",
  )}
/>
```

安裝：`npm i tailwindcss-animate`，在 v4 用 `@plugin "tailwindcss-animate";`。

## 8. Design System Review Checklist（補充 SKILL.md）

- [ ] 所有色彩走 semantic token，沒有 raw palette（`bg-blue-500`）。
- [ ] `@theme` / `:root` 集中列出所有自訂 token；元件內不硬編碼。
- [ ] Dark mode variant 有定義，且所有 semantic token 都有 dark 覆寫。
- [ ] Variant 走 CVA，不用手寫 className switch。
- [ ] Focus ring `focus-visible:ring-2 focus-visible:ring-ring` 每個互動元件都有。
- [ ] Typography / spacing 用預定 scale，沒有 `text-[17px]` / `p-[15px]` 等 arbitrary value（除非刻意）。
- [ ] React 19 專案：沒有殘留的 `forwardRef`。
- [ ] v3 → v4 遷移：沒有 `tailwind.config.ts`、沒有 `@tailwind base/components/utilities` directive。
- [ ] WCAG 2.1 AA 對比（4.5:1 text / 3:1 UI）在 light 與 dark 兩套主題都驗過。

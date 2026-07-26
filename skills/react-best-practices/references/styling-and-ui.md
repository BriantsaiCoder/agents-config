---
name: React Styling and UI
---

# React Styling and UI

## Table of Contents
- [Tailwind CSS + React](#tailwind-css--react)
- [cn() Utility](#cn-utility)
- [shadcn/ui](#shadcnui)
- [CSS Modules](#css-modules)
- [Migration: CSS-in-JS to Tailwind](#migration-css-in-js-to-tailwind)
- [Design Tokens with Tailwind Theme](#design-tokens-with-tailwind-theme)

---

## Tailwind CSS + React

### className Prop 傳遞

建立可自訂樣式的元件時，接受外部 className 並與內部樣式合併。

```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}

const variantStyles = {
  primary: 'bg-blue-600 text-white hover:bg-blue-700',
  secondary: 'bg-gray-200 text-gray-800 hover:bg-gray-300',
  danger: 'bg-red-600 text-white hover:bg-red-700',
} as const;

const sizeStyles = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
} as const;

export function Button({ variant = 'primary', size = 'md', className, children, ...props }: ButtonProps) {
  return (
    <button
      className={cn('inline-flex items-center justify-center rounded-md font-medium transition-colors',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
        'disabled:pointer-events-none disabled:opacity-50',
        variantStyles[variant],
        sizeStyles[size],
        className // 外部 className 可覆蓋內部樣式
      )}
      {...props}
    >
      {children}
    </button>
  );
}
```

### 條件式 Class

```tsx
function NavLink({ href, isActive, children }: { href: string; isActive: boolean; children: React.ReactNode }) {
  return (
    <a
      href={href}
      className={cn(
        'px-3 py-2 rounded-md text-sm font-medium transition-colors',
        isActive
          ? 'bg-gray-900 text-white'
          : 'text-gray-300 hover:bg-gray-700 hover:text-white'
      )}
    >
      {children}
    </a>
  );
}
```

---

## cn() Utility

結合 `clsx`（條件式 class）和 `tailwind-merge`（解決 Tailwind class 衝突）。這是 shadcn/ui 的基礎工具。

### 實作

```ts
// lib/utils.ts
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### 為何需要 tailwind-merge

```tsx
// 沒有 twMerge：兩個 padding 同時存在，結果不可預測
clsx('px-4 py-2', 'px-6') // => 'px-4 py-2 px-6' (衝突！)

// 有 twMerge：後者覆蓋前者
cn('px-4 py-2', 'px-6')   // => 'py-2 px-6' (正確覆蓋)
```

### 使用範例

```tsx
// 布林條件
cn('text-base', isLarge && 'text-lg')

// 物件語法
cn('flex', { 'flex-col': vertical, 'items-center': centered })

// 陣列
cn(['rounded-md', 'border', className])

// 混合使用
cn(
  'base-class',
  variant === 'outline' && 'border-2 bg-transparent',
  disabled && 'opacity-50 cursor-not-allowed',
  className
)
```

---

## shadcn/ui

不是 npm 套件，而是**可複製貼上的元件集合**。元件原始碼直接存在專案中，可完全自訂。

### 安裝

```bash
# 初始化專案（選擇主題、樣式）
npx shadcn@latest init

# 安裝個別元件
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form
```

安裝後元件會出現在 `components/ui/` 目錄，可自由修改。

### 元件自訂

```tsx
// components/ui/button.tsx（由 shadcn 產生，可直接修改）
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  ref?: React.Ref<HTMLButtonElement>; // React 19+：ref 是一般 prop
}

// React 19+：不需 forwardRef
const Button = ({ className, variant, size, ref, ...props }: ButtonProps) => (
  <button className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />
);

// React 18 專案：拿掉上面的 ref prop，改用
// const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
//   ({ className, variant, size, ...props }, ref) => (...)
// );
```

### 擴充元件

在 shadcn 元件基礎上加入業務邏輯。

```tsx
// components/confirm-dialog.tsx（基於 shadcn Dialog 擴充）
import {
  Dialog, DialogContent, DialogDescription,
  DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  onConfirm: () => void;
  confirmText?: string;
  variant?: 'default' | 'destructive';
}

export function ConfirmDialog({
  open, onOpenChange, title, description, onConfirm, confirmText = '確認', variant = 'default',
}: ConfirmDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>取消</Button>
          <Button variant={variant} onClick={() => { onConfirm(); onOpenChange(false); }}>
            {confirmText}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

---

## CSS Modules

### 基本用法

CSS Modules 在 Vite / Next.js / CRA 中開箱即用，檔名以 `.module.css` 結尾。

```css
/* components/Card.module.css */
.card {
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.title {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 8px;
}

.card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}
```

```tsx
// components/Card.tsx
import styles from './Card.module.css';

export function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className={styles.card}>
      <h3 className={styles.title}>{title}</h3>
      {children}
    </div>
  );
}
```

### TypeScript Typed Modules

讓 TypeScript 認識 CSS Module 的 import。

```ts
// src/types/css.d.ts
declare module '*.module.css' {
  const classes: { readonly [key: string]: string };
  export default classes;
}

declare module '*.module.scss' {
  const classes: { readonly [key: string]: string };
  export default classes;
}
```

若需要更嚴格的型別檢查（確認 class name 存在），可使用 `typed-css-modules` 或 `vite-plugin-css-modules-typescript`。

### 搭配條件式 Class

```tsx
import styles from './Tab.module.css';

function Tab({ isActive, children }: { isActive: boolean; children: React.ReactNode }) {
  return (
    <button className={`${styles.tab} ${isActive ? styles.active : ''}`}>
      {children}
    </button>
  );
}

// 或搭配 clsx
import clsx from 'clsx';
<button className={clsx(styles.tab, { [styles.active]: isActive })}>{children}</button>
```

---

## Migration: CSS-in-JS to Tailwind

### styled-components / Emotion 遷移對照

將 CSS-in-JS 的動態樣式轉換為 Tailwind utility classes。

```tsx
// Before: styled-components
const Card = styled.div<{ $elevated: boolean }>`
  padding: 16px;
  border-radius: 8px;
  background: white;
  box-shadow: ${(p) => (p.$elevated ? '0 4px 12px rgba(0,0,0,0.15)' : 'none')};
  &:hover { transform: translateY(-2px); }
`;

// After: Tailwind
function Card({ elevated, children }: { elevated?: boolean; children: React.ReactNode }) {
  return (
    <div className={cn(
      'p-4 rounded-lg bg-white hover:-translate-y-0.5 transition-transform',
      elevated ? 'shadow-lg' : 'shadow-none'
    )}>
      {children}
    </div>
  );
}
```

### 遷移策略

1. **漸進式遷移**：Tailwind 和 CSS-in-JS 可共存，不需一次全部轉換
2. **從葉節點開始**：先遷移小型、獨立的元件（Button、Badge、Icon）
3. **建立對照表**：記錄常用的 styled 元件對應的 Tailwind class
4. **保留全域主題**：用 CSS 變數橋接，同時供 CSS-in-JS 和 Tailwind 使用

```tsx
// 過渡期：CSS 變數作為橋樑
// globals.css
:root {
  --color-primary: theme('colors.blue.600');
  --spacing-md: theme('spacing.4');
}

// styled-components 仍可使用
const Legacy = styled.div`color: var(--color-primary);`;

// Tailwind 也使用同一套變數
<div className="text-[var(--color-primary)]">...</div>
```

---

## Design Tokens with Tailwind Theme

### 定義 Design Tokens

在 `tailwind.config.ts` 中以語意化名稱定義 token，避免到處寫 hex color。

```ts
// tailwind.config.ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // 語意化 token（搭配 CSS 變數支援 dark mode）
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        border: 'hsl(var(--border))',
        ring: 'hsl(var(--ring))',
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      fontSize: {
        'heading-1': ['2.25rem', { lineHeight: '2.5rem', fontWeight: '700' }],
        'heading-2': ['1.5rem', { lineHeight: '2rem', fontWeight: '600' }],
        'body': ['1rem', { lineHeight: '1.75rem' }],
        'caption': ['0.875rem', { lineHeight: '1.25rem' }],
      },
    },
  },
} satisfies Config;
```

### CSS 變數定義（支援 Light / Dark Mode）

```css
/* globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222 84% 5%;
    --primary: 222 47% 11%;
    --primary-foreground: 210 40% 98%;
    --muted: 210 40% 96%;
    --muted-foreground: 215 16% 47%;
    --destructive: 0 84% 60%;
    --destructive-foreground: 210 40% 98%;
    --border: 214 32% 91%;
    --ring: 222 47% 11%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222 84% 5%;
    --foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222 47% 11%;
    --muted: 217 33% 17%;
    --muted-foreground: 215 20% 65%;
    --destructive: 0 63% 31%;
    --destructive-foreground: 210 40% 98%;
    --border: 217 33% 17%;
    --ring: 212 27% 84%;
  }
}
```

### 使用語意化 Token

```tsx
// 元件直接使用語意化名稱，切換主題時自動變色
function Alert({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-lg border border-border bg-background p-4 text-foreground">
      {children}
    </div>
  );
}

function DestructiveAlert({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-lg bg-destructive p-4 text-destructive-foreground">
      {children}
    </div>
  );
}

// 排版使用自訂 fontSize token
function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <header>
      <h1 className="text-heading-1 text-foreground">{title}</h1>
      {subtitle && <p className="text-body text-muted-foreground mt-2">{subtitle}</p>}
    </header>
  );
}
```

**好處**：設計變更時只需修改 CSS 變數或 Tailwind config，不需逐一更新元件。

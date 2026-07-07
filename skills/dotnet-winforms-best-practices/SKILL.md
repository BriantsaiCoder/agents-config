---
name: dotnet-winforms-best-practices
description: 'Use when writing or reviewing WinForms code — System.Windows.Forms Form/UserControl, Designer.cs hand-edits, BindingSource/DataGridView wiring, BackgroundWorker/Task UI-thread marshaling, GDI+ resource disposal, high-DPI scaling, or MDI parenting. Apply even when user just says "add a form", "fix this DataGridView", or "this hangs the UI thread" without naming this skill.'
---

# Windows Forms (WinForms) Best Practices

Three pillars: UI-thread affinity, resource disposal, Designer code generation. Violating any → crashes, leaks, broken visual editing. Covers .NET Framework + .NET 8+ (Windows-only). Not for WPF / MAUI / Avalonia / web. Cross-ref: `dotnet-framework-best-practices`, `dotnet-core-best-practices`, `ef6/ef-core/dapper-best-practices`.

## 12 Golden Rules

1. **Never access UI controls from background threads.** Cross-thread → `InvalidOperationException`. Prefer `async/await`; fallback `control.Invoke(() => ...)`.
2. **`async void` only in event handlers.** Wrap in try/catch — unhandled exceptions crash process. All other async → `async Task`.
3. **Never manually edit `.Designer.cs`.** Regenerates on save; edits wiped or break parser. Custom logic in main `.cs`. Rename via Designer Name property only.
4. **Dispose GDI+ — Pen / Brush / Bitmap / Font / Graphics.** Each holds unmanaged handle; leaks hit 10k-process limit → `Win32Exception`. `using` for short-lived; cache long-lived + dispose in `Dispose(bool)`.
5. **`BindingSource` for data binding.** Handles currency, sorting, filtering, auto-sync.
6. **`Task.Run` + `IProgress<T>`, not `BackgroundWorker`.** Predates async/await, doesn't compose. Legacy may stay.
7. **Enable high-DPI.** Without it: blurry text, misaligned controls. `PerMonitorV2` via `Application.SetHighDpiMode()` (.NET 8+) or `App.config` (.NET Framework 4.7+). `AutoScaleMode.Dpi` + `TableLayoutPanel`.
8. **Form disposal — unsubscribe events, dispose owned resources.** Long-lived subscriptions block GC; closed forms get `ObjectDisposedException`. Override `OnFormClosed`.
9. **`ApplicationContext` for multi-form / tray apps.** `Application.Run(MainForm)` exits when MainForm closes.
10. **`FormClosing` for unsaved changes.** Track dirty, prompt `YesNoCancel`, set `e.Cancel = true`.
11. **`TableLayoutPanel` over absolute positioning.** Hardcoded `Location`/`Size` break on resize / DPI / font. Priority: TableLayout / FlowLayout → `Dock`+`Anchor` → `SplitContainer` → absolute (fixed dialogs only).
12. **`SuspendLayout`/`ResumeLayout` for bulk updates.** Each prop change triggers layout pass; 20 additions = 20 recalcs + flicker. `DoubleBuffered = true` for custom painting.

## Review Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | UI controls accessed from background without `Invoke`? | R1 |
| Critical | GDI+ resources never disposed? | R4 |
| High | `async void` outside event handlers? | R2 |
| High | `.Designer.cs` manually edited? | R3 |
| High | Long-lived event subscriptions never unsubscribed? | R8 |
| Medium | Manual loop instead of `BindingSource`? | R5 |
| Medium | `BackgroundWorker` in new code? | R6 |
| Medium | High-DPI missing or `DpiUnaware`? | R7 |
| Low | Absolute positioning instead of layout panels? | R11 |
| Low | Bulk updates without `SuspendLayout`? | R12 |

## Reference Navigation

- `references/code-patterns.md` — R2, 6–10 + .NET Framework vs .NET 8+ + DI setup
- `references/data-binding-patterns.md` — `BindingSource` / `BindingList<T>` / `DataGridView` / master-detail / `INotifyPropertyChanged`
- `references/threading-and-resources.md` — UI threading, `Task.Run`, GDI+, timers, double buffering, custom painting

---
name: dotnet-winforms-best-practices
description: 'Use when writing or reviewing WinForms code — System.Windows.Forms Form/UserControl, Designer.cs / InitializeComponent generation, custom control serialization (DefaultValue / ShouldSerialize), BindingSource/DataGridView wiring, MVVM DataContext + Command binding, BackgroundWorker/Task UI-thread marshaling, InvokeAsync, GDI+ resource disposal, TableLayoutPanel layout, dark mode, high-DPI scaling, or VB.NET WinForms. Apply even when user just says "add a form", "fix this DataGridView", or "this hangs the UI thread" without naming this skill.'
---

# Windows Forms (WinForms) Best Practices

Three pillars: UI-thread affinity, resource disposal, Designer code generation. Violating any → crashes, leaks, broken visual editing. Covers .NET Framework + .NET 8+ (Windows-only). Not for WPF / MAUI / Avalonia / web. Cross-ref: `dotnet-framework-best-practices`, `dotnet-core-best-practices`, `ef6/ef-core/dapper-best-practices`.

## 16 Golden Rules

1. **Never access UI controls from background threads.** Cross-thread → `InvalidOperationException`. Prefer `async/await`; fallback `control.Invoke(() => ...)`.
2. **`async void` only in event handlers.** Wrap in try/catch — unhandled exceptions crash process. All other async → `async Task`.
3. **Never hand-edit `.Designer.cs` casually.** Regenerates on save; edits wiped or break parser. Custom logic in main `.cs`. Rename via Designer Name property only. When you *must* generate designer code (no IDE available), obey R13.
4. **Dispose GDI+ — Pen / Brush / Bitmap / Font / Graphics.** Each holds unmanaged handle; leaks hit 10k-process limit → `Win32Exception`. `using` for short-lived; cache long-lived + dispose in `Dispose(bool)`.
5. **`BindingSource` for data binding.** Handles currency, sorting, filtering, auto-sync.
6. **`Task.Run` + `IProgress<T>`, not `BackgroundWorker`.** Predates async/await, doesn't compose. Legacy may stay.
7. **Enable high-DPI.** Without it: blurry text, misaligned controls. `PerMonitorV2` via `Application.SetHighDpiMode()` (.NET 8+) or `App.config` (.NET Framework 4.7+). `AutoScaleMode.Dpi` + `TableLayoutPanel`.
8. **Form disposal — unsubscribe events, dispose owned resources.** Long-lived subscriptions block GC; closed forms get `ObjectDisposedException`. Override `OnFormClosed`.
9. **`ApplicationContext` for multi-form / tray apps.** `Application.Run(MainForm)` exits when MainForm closes.
10. **`FormClosing` for unsaved changes.** Track dirty, prompt `YesNoCancel`, set `e.Cancel = true`.
11. **`TableLayoutPanel` over absolute positioning.** Hardcoded `Location`/`Size` break on resize / DPI / font. Priority: TableLayout / FlowLayout → `Dock`+`Anchor` → `SplitContainer` → absolute (fixed dialogs only).
12. **`SuspendLayout`/`ResumeLayout` for bulk updates.** Each prop change triggers layout pass; 20 additions = 20 recalcs + flicker. `DoubleBuffered = true` for custom painting.
13. **`InitializeComponent` is a serialization format, not C#.** Two code contexts, two rule sets. Inside it: no control flow, no `?:`/`??`/`?.`/`nameof`, no lambdas (including event wiring), no collection expressions, no locals added to control collections, no NRT annotations. Fixed statement order; backing fields at EOF. Modern C# only in regular `.cs` files.
14. **Control CodeDOM serialization on custom `Control`/`Component` properties.** Exactly one of `[DefaultValue]`, `[DesignerSerializationVisibility(Hidden)]`, or `ShouldSerializeX()`+`ResetX()` per property — otherwise the Designer writes garbage or drops state. Related trap: `=> new SolidBrush(...)` expression-bodied properties allocate per access.
15. **Use the modern binding/async APIs on .NET 8+/9+.** ViewModels are data sources: `Control.DataContext` (cascades), `ButtonBase`/`ToolStripItem.Command` + `CommandParameter`, `.datasource` files for Designer visibility, `Binding.Format`/`Parse` instead of `IValueConverter`. .NET 9+: `Control.InvokeAsync` (pick the `Func<CT, ValueTask>` overload — sync overloads swallow inner tasks), `Form.ShowAsync`/`ShowDialogAsync`, `Application.SetColorMode` + `IsDarkModeEnabled`.
16. **Handle exceptions at application scope.** `Application.ThreadException` (UI thread, recoverable) vs `AppDomain.UnhandledException` (any thread, log-only). Never call `Application.OnThreadException` from a background thread. Use `ExceptionDispatchInfo.Capture(ex).Throw()` to preserve async stack traces.

## Review Severity Checklist

| Severity | Check | Rule |
|---|---|---|
| Critical | UI controls accessed from background without `Invoke`? | R1 |
| Critical | GDI+ resources never disposed? | R4 |
| Critical | Prohibited constructs (lambda / ternary / `??` / control flow / NRT) in `InitializeComponent`? | R13 |
| High | `async void` outside event handlers, or without try/catch? | R2 |
| High | `.Designer.cs` manually edited? | R3 |
| High | Long-lived event subscriptions never unsubscribed? | R8 |
| High | Custom control property with no serialization control, or two conflicting mechanisms? | R14 |
| High | `=> new GdiType(...)` expression-bodied property (per-access allocation)? | R14 |
| Medium | Manual loop instead of `BindingSource`? | R5 |
| Medium | `BackgroundWorker` in new code? | R6 |
| Medium | High-DPI missing or `DpiUnaware`? | R7 |
| Medium | `InvokeAsync` sync overload wrapping an async lambda (fire-and-forget)? | R15 |
| Medium | No `Application.ThreadException` / `UnhandledException` handler? | R16 |
| Low | Absolute positioning instead of layout panels? | R11 |
| Low | Bulk updates without `SuspendLayout`? | R12 |
| Low | Missing `AccessibleName` on actionable controls? | R11 |

## Reference Navigation

- `references/code-patterns.md` — R2, 6–10 + .NET Framework vs .NET 8+ + DI setup
- `references/data-binding-patterns.md` — `BindingSource` / `BindingList<T>` / `DataGridView` / master-detail / `INotifyPropertyChanged`
- `references/threading-and-resources.md` — UI threading, `Task.Run`, GDI+, timers, double buffering, custom painting
- `references/designer-and-serialization.md` — R13/R14: two code contexts, `InitializeComponent` contract + template, CodeDOM serialization attributes, property-pattern traps, regular-code style, VB.NET App Framework, new-project defaults
- `references/mvvm-and-modern-apis.md` — R15/R16: MVVM binding on .NET 8+, `.datasource` files, `DataContext`/`Command`, `InvokeAsync` overloads, `ShowAsync`, dark mode, application-level exception handling
- `references/layout-design.md` — R11 depth: TLP cell sizing, container clipping, dialog button placement, layout recipes, accessibility, TreeView/ListView/DataGridView, localization

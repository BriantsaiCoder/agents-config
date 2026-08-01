---
name: dotnet-winforms-best-practices
description: 'Use when writing or reviewing WinForms/VB.NET — System.Windows.Forms Form/UserControl, Designer.cs/InitializeComponent, custom control serialization (DefaultValue/ShouldSerialize), BindingSource/DataGridView, MVVM DataContext/Command binding, BackgroundWorker/Task UI-thread marshaling, InvokeAsync, GDI+ disposal, TableLayoutPanel, dark mode, high-DPI scaling, "add a form", "hangs the UI thread".'
---

# Windows Forms (WinForms) Best Practices

Core boundaries: UI-thread affinity, resource disposal, and Designer code generation. Covers .NET Framework and modern .NET (Windows-only); not WPF, MAUI, Avalonia, or web. Cross-ref: `dotnet-framework-best-practices`, `dotnet-core-best-practices`, `ef6/ef-core/dapper-best-practices`.

## 16 Golden Rules

1. **UI controls stay on the UI thread.** Prefer `async/await`; otherwise marshal with `Invoke`/`InvokeAsync`.
2. **`async void` only for event handlers.** Catch failures there; every other async method returns `Task`.
3. **Treat `.Designer.cs` as generated code.** Keep custom logic in the main file, rename through the Designer's Name property, and obey R13 when generation is unavoidable.
4. **Dispose owned GDI+ objects.** Use `using` for short-lived objects; dispose cached resources from `Dispose(bool)`.
5. **Use `BindingSource` for WinForms data binding.**
6. **Prefer `Task.Run` + `IProgress<T>` for new background work.** Existing `BackgroundWorker` code may stay.
7. **Enable high-DPI.** Use `PerMonitorV2`, `AutoScaleMode.Dpi`, and responsive layout containers.
8. **On form disposal, unsubscribe external events and dispose owned resources.**
9. **`ApplicationContext` for multi-form / tray apps.** `Application.Run(MainForm)` exits when MainForm closes.
10. **`FormClosing` for unsaved changes.** Track dirty, prompt `YesNoCancel`, set `e.Cancel = true`.
11. **Prefer DPI-responsive layout containers over absolute positioning.**
12. **Batch layout updates with `SuspendLayout`/`ResumeLayout`; double-buffer custom painting.**
13. **Treat `InitializeComponent` as a serialization format.** No control flow, modern operators, lambdas, collection expressions, local controls, or NRT annotations; keep stable statement order and backing fields at EOF.
14. **Give each custom `Control`/`Component` property one serialization policy:** `[DefaultValue]`, `[DesignerSerializationVisibility(Hidden)]`, or `ShouldSerializeX()` + `ResetX()`.
15. **Use version-appropriate modern APIs.** Details for `DataContext`/commands, `InvokeAsync`, async forms, dark mode, and .NET 9 warning IDs live in the modern-API reference.
16. **Handle application-scope exceptions deliberately.** `Application.ThreadException` is recoverable UI handling; `AppDomain.UnhandledException` is log-only. Never route background failures through `Application.OnThreadException` without marshaling.

Review in this order: cross-thread access, GDI+/Designer violations, async/disposal/serialization failures, then DPI/layout/accessibility issues.
Severity: Critical = cross-thread, GDI+, or Designer corruption; High = async/disposal/serialization failures; Medium = binding/background/DPI/modern-API defects; Low = layout/accessibility.

## Reference Navigation

- `references/code-patterns.md` — R2, 6–10 + .NET Framework vs .NET 8+ + DI setup
- `references/data-binding-patterns.md` — `BindingSource` / `BindingList<T>` / `DataGridView` / master-detail / `INotifyPropertyChanged`
- `references/threading-and-resources.md` — UI threading, `Task.Run`, GDI+, timers, double buffering, custom painting
- `references/designer-and-serialization.md` — R13/R14: two code contexts, `InitializeComponent` contract + template, CodeDOM serialization attributes, property-pattern traps, regular-code style, VB.NET App Framework, new-project defaults
- `references/mvvm-and-modern-apis.md` — R15/R16: MVVM binding on .NET 8+, `.datasource` files, `DataContext`/`Command`, `InvokeAsync` overloads, `ShowAsync`, dark mode, application-level exception handling
- `references/layout-design.md` — R11 depth: TLP cell sizing, container clipping, dialog button placement, layout recipes, accessibility, TreeView/ListView/DataGridView, localization

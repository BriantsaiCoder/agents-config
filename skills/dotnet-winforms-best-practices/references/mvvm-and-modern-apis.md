# Modern WinForms APIs — MVVM, Async, Dark Mode, Exceptions (.NET 8+ / 9 / 10+)

Covers R15 (modern .NET WinForms APIs) and application-level exception handling. For classic binding mechanics see `data-binding-patterns.md`; for threading see `threading-and-resources.md`.

## MVVM Data Binding (.NET 8+)

### Breaking changes vs .NET Framework

| Feature | .NET Framework ≤ 4.8.1 | .NET 8+ |
|---|---|---|
| Typed DataSets | Designer supported | Code-only, not recommended |
| Object binding | Supported | Enhanced UI, fully supported |
| Data Sources window | Available | Not available |

### Binding rules

- Object data sources need `INotifyPropertyChanged`; collections need `BindingList<T>`. Prefer `ObservableObject` from the MVVM CommunityToolkit.
- `ObservableCollection<T>` is **not** directly bindable — it needs a `BindingList<T>` adapter merging both change-notification models. Write one if the project lacks it.
- One-way-to-source binding is unsupported in WinForms. Workaround: a dedicated VM property with a no-op setter.

### Registering a ViewModel as a Designer data source

Treat ViewModels as data sources. Create a `.datasource` file under `Properties\DataSources\` so the Designer can see the type:

```xml
<?xml version="1.0" encoding="utf-8"?>
<GenericObjectDataSource DisplayName="MainViewModel" Version="1.0"
    xmlns="urn:schemas-microsoft-com:xml-msdatasource">
  <TypeInfo>MyApp.ViewModels.MainViewModel, MyApp.ViewModels, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null</TypeInfo>
</GenericObjectDataSource>
```

Then use a `BindingSource` in the Form/UserControl as mediator between view and ViewModel (classic binding approach).

### Command binding APIs

| API | Description | Cascades down hierarchy |
|---|---|---|
| `Control.DataContext` | Ambient MVVM property | Yes |
| `ButtonBase.Command` | `ICommand` binding | No |
| `ToolStripItem.Command` | `ICommand` binding | No |
| `*.CommandParameter` | Passed to the command | No |

`ToolStripItem` now derives from `BindableComponent`.

```csharp
// In InitializeComponent — plain, designer-parsable statements only
components = new Container();
mainViewModelBindingSource = new BindingSource(components);
mainViewModelBindingSource.DataSource = typeof(MyApp.ViewModels.MainViewModel);

// Bind properties
_txtDataField.DataBindings.Add(new Binding("Text", mainViewModelBindingSource, "PropertyName", true));

// Bind commands — ViewModels are data sources too
_tsmFile.DataBindings.Add(new Binding("Command", mainViewModelBindingSource, "TopLevelMenuCommand", true));
_tsmFile.CommandParameter = "File";
```

### Applying MVVM to a WinForms project

- Put ViewModels in a dedicated class library based on the MVVM CommunityToolkit; reference it from the WinForms project.
- Import ViewModels via object data sources as above.
- Use `Control.DataContext` to pass the ViewModel down nested Form/UserControl hierarchies.
- Use `Form.DataContext` to pass and return modal dialog data objects.
- There is no `IValueConverter`. Use `Binding.Format` / `Binding.Parse` for custom conversions:

```csharp
Binding b = _txtAmount.DataBindings["Text"];
b.Format += DecimalToCurrencyString;
b.Parse += CurrencyStringToDecimal;
```

## Async APIs (.NET 9+ — async forms need WFO5002 on .NET 9, stable from .NET 10)

### `Control.InvokeAsync` overload selection

| Your code | Overload | Scenario |
|---|---|---|
| Sync action, no return | `InvokeAsync(Action)` | Update `label.Text` |
| Async operation, no return | `InvokeAsync(Func<CancellationToken, ValueTask>)` | Load data then update UI |
| Sync function returning T | `InvokeAsync<T>(Func<T>)` | Read a control value |
| Async operation returning T | `InvokeAsync<T>(Func<CancellationToken, ValueTask<T>>)` | Async work with result |

```csharp
// ❌ Fire-and-forget — the inner task is not awaited (analyzer violation)
await InvokeAsync<string>(() => await LoadDataAsync());

// ✅ Use the async overload and flow the token
await InvokeAsync<string>(async ct => await LoadDataAsync(ct), outerCancellationToken);
```

### Async form display (.NET 9 experimental — WFO5002 / .NET 10+ stable)

- `ShowAsync()` — completes when the form closes. The returned task's async state holds a **weak** reference to the form for lookup.
- `ShowDialogAsync()` — modal, with its own message queue.
- **.NET 10+**: no suppression needed — these APIs are no longer experimental.
- **.NET 9 only**: both are `[Experimental]` and emit **compiler error WFO5002**; the build fails unless you suppress it — `#pragma warning disable WFO5002`, `<NoWarn>$(NoWarn);WFO5002</NoWarn>`, or `dotnet_diagnostic.WFO5002.severity = none` in `.editorconfig`.
- Not available on .NET Framework. `Control.InvokeAsync` above is .NET 9+ and is **not** experimental — it never needs suppression.

### Async event handlers

Applies equally to `async void` handlers and to overridden `async void OnLoad` / `OnClick`:

- `async void` is the correct pattern for WinForms UI events (see R2).
- **Always** wrap `await` calls in try/catch inside them — an unhandled exception crashes the process.

## Dark Mode (.NET 9 experimental / .NET 10+ stable)

- **.NET 10+**: `Application.SetColorMode(SystemColorMode.System);` at startup (also `Dark`, `Classic`). No suppression needed — the API is no longer experimental.
- **.NET 9 only**: `SetColorMode` / `IsDarkModeEnabled` are `[Experimental]` and emit **compiler error WFO5001**; the build fails unless you suppress it — `#pragma warning disable WFO5001` around the call, `<NoWarn>$(NoWarn);WFO5001</NoWarn>` in the project file, or `dotnet_diagnostic.WFO5001.severity = none` in `.editorconfig`.
- Query current state with `Application.IsDarkModeEnabled`.
- Only `SystemColors` values flip automatically. Owner-drawn controls, custom painting, and DataGridView theming use absolute colors and must be adjusted explicitly.

## Application-Level Exception Handling

| Mechanism | Scope | Can prevent termination | Use for |
|---|---|---|---|
| `AppDomain.CurrentDomain.UnhandledException` | Any thread in the AppDomain | No | Logging critical errors before shutdown |
| `Application.ThreadException` | UI thread only | Yes | Graceful recovery in UI operations |

- `Application.OnThreadException` routes to the UI thread handler and raises `Application.ThreadException`. Never call it from a background thread — marshal to the UI thread first.
- To make unhandled exceptions terminate the process instead, call `Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException)` at startup.

Preserve stack traces when re-throwing in async contexts:

```csharp
try
{
    await SomeAsyncOperation();
}
catch (OperationCanceledException)
{
    // handle cancellation
}
catch (Exception ex)
{
    ExceptionDispatchInfo.Capture(ex).Throw();
}
```

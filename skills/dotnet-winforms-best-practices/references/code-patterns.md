# WinForms Code Patterns per Golden Rule

Complete code examples for Rules 2, 6–10 plus .NET Framework vs .NET 8+ comparison and DI setup. For Rules 1, 4, 12 (UI threading, GDI+, double buffering) see `threading-and-resources.md`. For Rule 5 (BindingSource) see `data-binding-patterns.md`.

## Rule 1 — UI threading (complete examples)

```csharp
// ❌ Wrong — cross-thread access
Task.Run(() =>
{
    lblStatus.Text = "Done"; // InvalidOperationException
});

// ✅ Correct — marshal to UI thread
Task.Run(() =>
{
    lblStatus.Invoke(() => lblStatus.Text = "Done");        // .NET 8+
    // or for .NET Framework:
    lblStatus.Invoke(new Action(() => lblStatus.Text = "Done"));
});

// ✅ Best — use async/await which returns to UI thread automatically
private async void btnProcess_Click(object sender, EventArgs e)
{
    btnProcess.Enabled = false;
    var result = await Task.Run(() => HeavyComputation());
    lblStatus.Text = $"Result: {result}";  // back on UI thread
    btnProcess.Enabled = true;
}
```

## Rule 2 — `async void` only in event handlers

```csharp
// ✅ Correct — event handler must be async void
private async void btnSave_Click(object sender, EventArgs e)
{
    try
    {
        await _service.SaveAsync();
    }
    catch (Exception ex)
    {
        MessageBox.Show(ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}

// ❌ Wrong — non-event-handler method using async void
private async void ProcessData() { /* ... */ }  // unhandled exceptions crash process

// ✅ Correct — return Task for non-event methods
private async Task ProcessDataAsync() { /* ... */ }
```

## Rule 4 — Dispose GDI+ resources (full examples)

```csharp
// ❌ Wrong — leaked resources
protected override void OnPaint(PaintEventArgs e)
{
    var pen = new Pen(Color.Red, 2);      // leaked
    var brush = new SolidBrush(Color.Blue); // leaked
    e.Graphics.DrawRectangle(pen, 10, 10, 100, 50);
    e.Graphics.FillEllipse(brush, 120, 10, 50, 50);
}

// ✅ Correct — using statements
protected override void OnPaint(PaintEventArgs e)
{
    using var pen = new Pen(Color.Red, 2);
    using var brush = new SolidBrush(Color.Blue);
    e.Graphics.DrawRectangle(pen, 10, 10, 100, 50);
    e.Graphics.FillEllipse(brush, 120, 10, 50, 50);
}

// ✅ Better for frequently used resources — cache as class fields
private readonly Pen _borderPen = new Pen(Color.Red, 2);
private readonly SolidBrush _fillBrush = new SolidBrush(Color.Blue);

protected override void Dispose(bool disposing)
{
    if (disposing)
    {
        _borderPen.Dispose();
        _fillBrush.Dispose();
        components?.Dispose();
    }
    base.Dispose(disposing);
}
```

## Rule 5 — BindingSource (data binding setup)

```csharp
private readonly BindingSource _orderBindingSource = new BindingSource();

private void MainForm_Load(object sender, EventArgs e)
{
    _orderBindingSource.DataSource = typeof(Order);
    dgvOrders.DataSource = _orderBindingSource;

    // Bind individual controls to current record
    txtOrderId.DataBindings.Add("Text", _orderBindingSource, "Id");
    txtCustomer.DataBindings.Add("Text", _orderBindingSource, "CustomerName");
}

// Update data — UI refreshes automatically
private async void btnRefresh_Click(object sender, EventArgs e)
{
    var orders = await _orderService.GetAllAsync();
    _orderBindingSource.DataSource = new BindingList<Order>(orders);
}
```

## Rule 6 — Task.Run + IProgress<T>

```csharp
private async void btnImport_Click(object sender, EventArgs e)
{
    btnImport.Enabled = false;
    var progress = new Progress<int>(percent =>
    {
        progressBar.Value = percent;
        lblStatus.Text = $"Processing... {percent}%";
    });

    await Task.Run(() => ImportData(progress, _cts.Token));

    lblStatus.Text = "Import complete.";
    btnImport.Enabled = true;
}

private void ImportData(IProgress<int> progress, CancellationToken ct)
{
    for (int i = 0; i < totalItems; i++)
    {
        ct.ThrowIfCancellationRequested();
        ProcessItem(items[i]);
        progress.Report((i + 1) * 100 / totalItems);
    }
}
```

`BackgroundWorker` is acceptable for existing code — don't rewrite working code purely for modernization.

## Rule 7 — High DPI support

**.NET Framework 4.7+**:
```xml
<!-- App.config -->
<configuration>
  <System.Windows.Forms.ApplicationConfigurationSection>
    <add key="DpiAwareness" value="PerMonitorV2" />
  </System.Windows.Forms.ApplicationConfigurationSection>
</configuration>
```

**.NET 8+**:
```csharp
// Program.cs (before Application.Run)
Application.EnableVisualStyles();
Application.SetCompatibleTextRenderingDefault(false);
Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
Application.Run(new MainForm());
```

**Design guidelines**:
- Set `AutoScaleMode = AutoScaleMode.Dpi` on forms (not `Font` or `None`)
- Use `TableLayoutPanel` / `FlowLayoutPanel` for resizable layouts
- Avoid hardcoded pixel sizes; use `LogicalToDeviceUnits()` for custom drawing

## Rule 8 — Proper form disposal

```csharp
public partial class DashboardForm : Form
{
    private readonly INotificationService _notifications;

    public DashboardForm(INotificationService notifications)
    {
        InitializeComponent();
        _notifications = notifications;
        _notifications.OrderReceived += OnOrderReceived;
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _notifications.OrderReceived -= OnOrderReceived; // prevent memory leak
        base.OnFormClosed(e);
    }
}
```

## Rule 9 — ApplicationContext for multi-form apps

```csharp
class AppContext : ApplicationContext
{
    private readonly NotifyIcon _trayIcon;

    public AppContext()
    {
        _trayIcon = new NotifyIcon
        {
            Icon = Resources.AppIcon,
            Visible = true,
            ContextMenuStrip = BuildMenu()
        };
        _trayIcon.DoubleClick += (_, _) => ShowMainForm();
    }

    private void ShowMainForm()
    {
        var form = new MainForm();
        form.Show();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _trayIcon.Dispose();
        base.Dispose(disposing);
    }
}

// Program.cs
Application.Run(new AppContext());
```

## Rule 10 — FormClosing confirmation

```csharp
private bool _isDirty;

private void OnDataChanged(object sender, EventArgs e) => _isDirty = true;

protected override void OnFormClosing(FormClosingEventArgs e)
{
    if (_isDirty)
    {
        var result = MessageBox.Show(
            "You have unsaved changes. Save before closing?",
            "Confirm",
            MessageBoxButtons.YesNoCancel,
            MessageBoxIcon.Warning);

        switch (result)
        {
            case DialogResult.Yes:
                Save();
                break;
            case DialogResult.Cancel:
                e.Cancel = true;
                return;
        }
    }
    base.OnFormClosing(e);
}
```

## Rule 12 — SuspendLayout for bulk updates

```csharp
// Batch UI updates
panel.SuspendLayout();
try
{
    foreach (var item in items)
    {
        var label = new Label { Text = item.Name, Dock = DockStyle.Top };
        panel.Controls.Add(label);
    }
}
finally
{
    panel.ResumeLayout(performLayout: true);
}

// For custom painting — use double buffering
public class BufferedPanel : Panel
{
    public BufferedPanel()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer, true);
    }
}
```

## .NET Framework vs .NET 8+ WinForms

| Aspect | .NET Framework 4.x | .NET 8+/9+/10+ |
|--------|-------------------|----------------|
| DI | Manual (Unity, Autofac) | Built-in `Host.CreateDefaultBuilder` |
| High DPI | App.config + manifest | `Application.SetHighDpiMode()` |
| Designer | Full support | Full support (restored in .NET 8+) |
| `Control.Invoke` | Requires `new Action(...)` delegate | Lambda-friendly overload |
| Nullable | No nullable reference types | Nullable annotations available |
| Deployment | .NET Framework pre-installed on Windows | Self-contained publish or framework-dependent |
| `async void` in events | Same behavior | Same behavior |
| `Task.Run` | Available (.NET 4.5+) | Available |
| `BackgroundWorker` | Available (legacy) | Available but deprecated pattern |
| Clipboard / drag-drop of custom types | `BinaryFormatter`-backed `SetData`/`GetData` | `BinaryFormatter` removed from the runtime in **.NET 9** — `SetData` silently fails to serialize custom types. **.NET 10** restores it via `Clipboard.SetDataAsJson<T>` + `Clipboard.TryGetData<T>` / `DataObject.TryGetData<T>` (JSON-backed); `GetData` is obsolete (**WFDEV005**) |
| Legacy `BinaryFormatter` clipboard payloads | Implicit | Opt back in only as a migration bridge: reference `System.Runtime.Serialization.Formatters`, set the `EnableUnsafeBinaryFormatterSerialization` runtime switch and the WinForms `Windows.ClipboardDragDrop.EnableUnsafeBinaryFormatterSerialization` app-context switch in `runtimeconfig.json` |
| Screen-capture exclusion | n/a | `ScreenCaptureMode` API (.NET 10) |

## DI in .NET 8+ WinForms

```csharp
// Program.cs — .NET 8+ WinForms with built-in DI
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddTransient<MainForm>();
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddSingleton<ILogger, SerilogLogger>();

var host = builder.Build();

Application.EnableVisualStyles();
Application.SetCompatibleTextRenderingDefault(false);
Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);

var mainForm = host.Services.GetRequiredService<MainForm>();
Application.Run(mainForm);
```

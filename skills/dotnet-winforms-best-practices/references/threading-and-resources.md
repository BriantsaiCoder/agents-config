# WinForms Threading and Resource Management Reference

## Control.Invoke vs Control.BeginInvoke

WinForms controls have thread affinity -- they must be accessed from the thread that created them (the UI thread). `Invoke` and `BeginInvoke` marshal calls to that thread.

### Control.Invoke (Synchronous)

Blocks the calling thread until the delegate executes on the UI thread.

```csharp
// From a background thread:
this.Invoke((Action)(() =>
{
    lblStatus.Text = "Processing complete.";
    progressBar1.Value = 100;
}));
// Execution continues here only after the UI update runs.

// Retrieve a value from the UI thread:
string text = (string)textBox.Invoke(new Func<string>(() => textBox.Text));
```

### Control.BeginInvoke (Asynchronous)

Queues the delegate to the UI thread and returns immediately. The calling thread does not block.

```csharp
this.BeginInvoke((Action)(() =>
{
    lblStatus.Text = $"Processed {count} items...";
}));
// Execution continues immediately without waiting for UI update.
```

### When to Use Each

| Scenario | Use |
|---|---|
| Background thread needs result from UI | `Invoke` |
| Fire-and-forget progress update | `BeginInvoke` |
| Final completion notification | `Invoke` (ensures ordering) |
| Tight loop sending many updates | `BeginInvoke` (avoid blocking the worker) |

### Deadlock Scenario with Invoke

```csharp
// DEADLOCK: UI thread waits for background task, background task waits for UI thread
private void btnStart_Click(object sender, EventArgs e)
{
    var task = Task.Run(() =>
    {
        // This Invoke blocks waiting for the UI thread...
        this.Invoke((Action)(() => lblStatus.Text = "Working..."));
    });

    task.Wait(); // ...but the UI thread is blocked here waiting for the task!
}

// FIX: use async/await instead of .Wait()
private async void btnStart_Click(object sender, EventArgs e)
{
    await Task.Run(() =>
    {
        this.BeginInvoke((Action)(() => lblStatus.Text = "Working..."));
    });
}
```

### Guard Against Disposed Controls

```csharp
// The form may close while background work is still running
if (!this.IsDisposed && this.IsHandleCreated)
{
    this.BeginInvoke((Action)(() => lblStatus.Text = "Done"));
}
```

---

## SynchronizationContext in WinForms

`WindowsFormsSynchronizationContext` is installed automatically when a WinForms message loop starts. It ensures that `await` continuations run on the UI thread.

```csharp
private async void btnLoad_Click(object sender, EventArgs e)
{
    lblStatus.Text = "Loading...";  // UI thread

    var data = await Task.Run(() => repository.LoadAll()); // background

    // Back on UI thread automatically (SynchronizationContext captured by await)
    dataGridView1.DataSource = data;
    lblStatus.Text = $"Loaded {data.Count} records.";
}
```

### Explicit Capture for Non-Async Callbacks

```csharp
// Capture context for use in non-async callbacks
var uiContext = SynchronizationContext.Current;

Task.Run(() =>
{
    var result = HeavyComputation();
    uiContext.Post(_ =>           // Post = async (like BeginInvoke)
    {
        lblResult.Text = result.ToString();
    }, null);
    // uiContext.Send(...)        // Send = sync (like Invoke)
});
```

### Key Rules for async/await in WinForms

- `async void` is acceptable ONLY for event handlers. All other async methods should return `Task` or `Task<T>`.
- Do NOT use `.Result` or `.Wait()` on the UI thread -- it will deadlock because the continuation needs the UI thread which is blocked.
- Do NOT use `ConfigureAwait(false)` in UI event handlers. You need the UI context for control access after await.

---

## Task.Run + IProgress<T> Pattern (Complete Example)

The recommended modern pattern for background work with progress reporting.

```csharp
private CancellationTokenSource _cts;

private async void btnProcess_Click(object sender, EventArgs e)
{
    _cts = new CancellationTokenSource();
    btnProcess.Enabled = false;
    btnCancel.Enabled = true;

    // Create Progress<T> on the UI thread -- it captures WindowsFormsSynchronizationContext
    var progress = new Progress<ProgressInfo>(info =>
    {
        // This callback runs on the UI thread automatically
        progressBar1.Value = info.PercentComplete;
        lblStatus.Text = info.Message;
    });

    try
    {
        var result = await Task.Run(
            () => ProcessData(progress, _cts.Token),
            _cts.Token);

        lblStatus.Text = $"Done. Processed {result.Count} items.";
    }
    catch (OperationCanceledException)
    {
        lblStatus.Text = "Cancelled.";
    }
    catch (Exception ex)
    {
        MessageBox.Show($"Error: {ex.Message}", "Error",
            MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
    finally
    {
        btnProcess.Enabled = true;
        btnCancel.Enabled = false;
        _cts.Dispose();
        _cts = null;
    }
}

private void btnCancel_Click(object sender, EventArgs e)
{
    _cts?.Cancel();
}

// This runs on a thread pool thread
private List<Result> ProcessData(IProgress<ProgressInfo> progress, CancellationToken ct)
{
    var results = new List<Result>();
    var items = LoadItems();

    for (int i = 0; i < items.Count; i++)
    {
        ct.ThrowIfCancellationRequested();

        results.Add(ProcessItem(items[i]));

        progress?.Report(new ProgressInfo
        {
            PercentComplete = (i + 1) * 100 / items.Count,
            Message = $"Processing item {i + 1} of {items.Count}..."
        });
    }
    return results;
}

public class ProgressInfo
{
    public int PercentComplete { get; set; }
    public string Message { get; set; }
}
```

**Caveat**: `Progress<T>.Report` posts asynchronously. If the background thread reports faster than the UI can process, messages queue up. Throttle reports if needed (e.g., report only when percentage changes).

---

## BackgroundWorker (Legacy Pattern)

Still widely used in .NET Framework codebases. Not recommended for new code on .NET 8+.

```csharp
private BackgroundWorker _worker;

private void InitializeWorker()
{
    _worker = new BackgroundWorker
    {
        WorkerReportsProgress = true,
        WorkerSupportsCancellation = true
    };

    _worker.DoWork += (s, e) =>
    {
        var items = (List<Item>)e.Argument;
        var results = new List<Result>();

        for (int i = 0; i < items.Count; i++)
        {
            if (_worker.CancellationPending)
            {
                e.Cancel = true;
                return;
            }

            results.Add(ProcessItem(items[i]));
            _worker.ReportProgress((i + 1) * 100 / items.Count);
        }
        e.Result = results;
    };

    _worker.ProgressChanged += (s, e) =>
    {
        // Runs on UI thread
        progressBar1.Value = e.ProgressPercentage;
    };

    _worker.RunWorkerCompleted += (s, e) =>
    {
        // Runs on UI thread
        if (e.Cancelled)
            lblStatus.Text = "Cancelled.";
        else if (e.Error != null)
            lblStatus.Text = $"Error: {e.Error.Message}";
        else
            lblStatus.Text = $"Done. {((List<Result>)e.Result).Count} items.";

        btnProcess.Enabled = true;
    };
}

private void btnProcess_Click(object sender, EventArgs e)
{
    btnProcess.Enabled = false;
    _worker.RunWorkerAsync(argument: itemsList);
}

private void btnCancel_Click(object sender, EventArgs e)
{
    _worker.CancelAsync();
}
```

---

## CancellationToken Integration

### Token Linked to Form Closing

```csharp
private CancellationTokenSource _formCts = new CancellationTokenSource();

protected override void OnFormClosing(FormClosingEventArgs e)
{
    _formCts.Cancel(); // signal all background work to stop
    base.OnFormClosing(e);
}

private async void btnLoad_Click(object sender, EventArgs e)
{
    // Link button-specific cancellation with form-level cancellation
    using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(_formCts.Token);
    linkedCts.CancelAfter(TimeSpan.FromSeconds(30)); // timeout

    try
    {
        var data = await Task.Run(() => LoadData(linkedCts.Token), linkedCts.Token);
        dataGridView1.DataSource = data;
    }
    catch (OperationCanceledException) when (_formCts.IsCancellationRequested)
    {
        // Form is closing, silently ignore
    }
    catch (OperationCanceledException)
    {
        lblStatus.Text = "Operation timed out or was cancelled.";
    }
}
```

### Graceful Shutdown on Form Close

```csharp
private Task _runningTask;
private CancellationTokenSource _cts;

protected override async void OnFormClosing(FormClosingEventArgs e)
{
    if (_cts != null && !_cts.IsCancellationRequested)
    {
        e.Cancel = true;          // prevent immediate close
        _cts.Cancel();            // signal cancellation
        await _runningTask;       // wait for clean shutdown
        Close();                  // now actually close
    }
    base.OnFormClosing(e);
}
```

---

## GDI+ Resource Management

GDI+ objects (`Pen`, `Brush`, `Font`, `Image`, `Graphics`, `Bitmap`, `Icon`, `Region`, `GraphicsPath`, `Matrix`) wrap native handles. Failing to dispose them leaks GDI handles, eventually crashing the application (the per-process limit is 10,000 GDI objects on Windows).

### Using Statement Patterns in Paint Events

```csharp
protected override void OnPaint(PaintEventArgs e)
{
    base.OnPaint(e);
    var g = e.Graphics; // do NOT dispose this -- it is owned by the framework

    // Temporary resources: create and dispose within the event
    using (var pen = new Pen(Color.Navy, 2f))
    using (var brush = new SolidBrush(Color.LightBlue))
    using (var font = new Font("Segoe UI", 12f, FontStyle.Bold))
    {
        g.FillRectangle(brush, new Rectangle(10, 10, 200, 100));
        g.DrawRectangle(pen, new Rectangle(10, 10, 200, 100));
        g.DrawString("Hello", font, Brushes.Black, 20, 40);
    }
}
```

### Reusable Resources as Fields (Disposed in Dispose)

For resources used on every paint, create them once and dispose in the form/control's `Dispose`.

```csharp
public class ChartControl : Control
{
    private readonly Pen _gridPen = new Pen(Color.LightGray, 1f);
    private readonly Pen _axisPen = new Pen(Color.Black, 2f);
    private readonly Font _labelFont = new Font("Segoe UI", 9f);
    private readonly SolidBrush _labelBrush = new SolidBrush(Color.DarkGray);

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        // Use cached objects -- no allocation per paint
        e.Graphics.DrawLine(_axisPen, 0, Height - 20, Width, Height - 20);
        e.Graphics.DrawString("Label", _labelFont, _labelBrush, 10, 10);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _gridPen.Dispose();
            _axisPen.Dispose();
            _labelFont.Dispose();
            _labelBrush.Dispose();
        }
        base.Dispose(disposing);
    }
}
```

### Static System Resources (Never Dispose)

```csharp
// These are shared singletons -- NEVER dispose them
g.FillRectangle(Brushes.Red, rect);        // OK
g.DrawRectangle(Pens.Black, rect);          // OK
g.DrawString("X", SystemFonts.DefaultFont, Brushes.Black, 0, 0); // OK

// BAD: disposing a system resource corrupts other controls
// Brushes.Red.Dispose(); // NEVER do this
```

### Image and Bitmap Notes

```csharp
// Bitmaps consume significant memory (width x height x 4 bytes for 32bpp)
// A 4000x3000 image uses ~48 MB

// File locking pitfall: new Bitmap(filePath) locks the file until disposed
// Load without locking:
Bitmap LoadWithoutLocking(string path)
{
    using var stream = new MemoryStream(File.ReadAllBytes(path));
    return new Bitmap(stream);
}

// PictureBox.Image assignment does NOT dispose the previous image
var old = pictureBox.Image;
pictureBox.Image = newBitmap;
old?.Dispose();
```

---

## Custom Control Double Buffering

Reduces flicker when custom-painting controls.

```csharp
public class DoubleBufferedPanel : Panel
{
    public DoubleBufferedPanel()
    {
        // Enable double buffering via control styles
        this.SetStyle(
            ControlStyles.AllPaintingInWmPaint |  // suppress WM_ERASEBKGND
            ControlStyles.UserPaint |              // control paints itself
            ControlStyles.OptimizedDoubleBuffer,   // offscreen buffer
            true);
        this.UpdateStyles();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        // All drawing here is rendered to an offscreen buffer first,
        // then blitted to the screen in a single operation.
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        // ... custom drawing ...
    }
}
```

### Enabling DoubleBuffered on DataGridView

The `DoubleBuffered` property is protected on `DataGridView`. Use reflection:

```csharp
public static void EnableDoubleBuffering(this DataGridView dgv)
{
    typeof(DataGridView)
        .GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic)
        .SetValue(dgv, true);
}
```

### Manual Double Buffering

```csharp
protected override void OnPaint(PaintEventArgs e)
{
    using var buffer = new Bitmap(Width, Height);
    using var g = Graphics.FromImage(buffer);
    g.SmoothingMode = SmoothingMode.AntiAlias;

    DrawBackground(g);
    DrawChart(g);
    DrawOverlays(g);

    e.Graphics.DrawImageUnscaled(buffer, 0, 0);
}
// Performance tip: cache the back buffer bitmap and recreate only on Resize.
```

---

## Memory Leak Patterns

### 1. Event Handler Leaks

The most common WinForms memory leak. Subscribing to an event creates a strong reference from the publisher to the subscriber.

```csharp
// LEAK: the form subscribes to a long-lived service's event
public class DataForm : Form
{
    private readonly DataService _service;

    public DataForm(DataService service)
    {
        _service = service;
        _service.DataChanged += Service_DataChanged; // strong reference
    }

    // If the form closes but DataService lives on,
    // the form is never garbage collected.

    // FIX: unsubscribe when the form closes
    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _service.DataChanged -= Service_DataChanged;
        base.OnFormClosed(e);
    }
}
```

### 2. Timer Leaks

`System.Windows.Forms.Timer` is tied to the form's lifecycle and stops on dispose. But `System.Timers.Timer` and `System.Threading.Timer` do not -- they must be disposed explicitly.

```csharp
// LEAK: System.Timers.Timer keeps running after form closes
private System.Timers.Timer _pollingTimer;

private void StartPolling()
{
    _pollingTimer = new System.Timers.Timer(5000);
    _pollingTimer.Elapsed += (s, e) => PollForUpdates();
    _pollingTimer.Start();
}

// FIX: stop and dispose the timer
protected override void Dispose(bool disposing)
{
    if (disposing)
    {
        _pollingTimer?.Stop();
        _pollingTimer?.Dispose();
        components?.Dispose();
    }
    base.Dispose(disposing);
}
```

### Timer Type Comparison

| Property | Forms.Timer | Timers.Timer | Threading.Timer |
|----------|-------------|--------------|-----------------|
| Thread | UI thread (WM_TIMER) | ThreadPool | ThreadPool |
| Precision | Low (~15ms min) | Higher | Higher |
| Re-entrant | No | Yes (unless SynchronizingObject set) | Yes |
| Auto-disposed with form | Yes (if added to components) | No | No |
| Best for | UI updates | Server-side periodic work | Low-level scheduling |

### 3. GDI Handle Leaks

```csharp
// LEAK: creating GDI objects in Paint event without disposing
protected override void OnPaint(PaintEventArgs e)
{
    // BAD: new Pen every paint, never disposed
    var pen = new Pen(Color.Red, 2f);
    e.Graphics.DrawLine(pen, 0, 0, Width, Height);
    // pen is abandoned here -- GDI handle leaked
}

// FIX: use `using` or cache as a field
protected override void OnPaint(PaintEventArgs e)
{
    using var pen = new Pen(Color.Red, 2f);
    e.Graphics.DrawLine(pen, 0, 0, Width, Height);
}
```

---

## Diagnosing GDI Handle Leaks

### Task Manager

1. Open Task Manager, go to Details tab.
2. Right-click column headers, choose "Select columns."
3. Enable "GDI objects" column.
4. Watch the count for your process. Normal apps use 200-500. Leaking apps climb steadily toward 10,000.

### Programmatic Check

```csharp
// Query GDI object count at runtime (Windows only, P/Invoke)
[DllImport("user32.dll")]
static extern int GetGuiResources(IntPtr hProcess, int uiFlags);

public static int GetGdiObjectCount()
{
    // uiFlags: 0 = GR_GDIOBJECTS, 1 = GR_USEROBJECTS
    return GetGuiResources(Process.GetCurrentProcess().Handle, 0);
}

// Log periodically during development
Debug.WriteLine($"GDI Objects: {GetGdiObjectCount()}");
```

### Profiling Tools

For production issues, use:
- **dotMemory** (JetBrains): tracks .NET allocations and GDI wrappers.
- **PerfView**: lightweight ETW-based tracing.
- **WinDbg + SOS**: `!gcroot` to find what holds references to undisposed GDI wrappers.
- **GDIView** (NirSoft): free utility showing per-process GDI handle breakdown by type.

---

## Dispose Pattern for Forms and User Controls

### Designer-Generated components Container

The WinForms designer generates a `components` field (`IContainer`) that collects `IDisposable` objects. Controls added to the form are automatically disposed. Non-visual components added via the designer (timers, BindingSource, ErrorProvider) are added to `components`.

```csharp
// Designer-generated code (FormName.Designer.cs)
private System.ComponentModel.IContainer components = null;

protected override void Dispose(bool disposing)
{
    if (disposing && (components != null))
    {
        components.Dispose(); // disposes all tracked components
    }
    base.Dispose(disposing);
}
```

### Adding Custom Resources to the Container

```csharp
// In constructor or InitializeComponent, add disposable objects to components
public MyForm()
{
    InitializeComponent();

    // Ensure components is initialized
    components ??= new System.ComponentModel.Container();

    // Timer created in code (not designer) -- add to components for auto-dispose
    var timer = new System.Windows.Forms.Timer(components);
    timer.Interval = 1000;
    timer.Tick += Timer_Tick;
    timer.Start();
}
```

### Full Custom Dispose for User Controls

```csharp
public class CustomerPanel : UserControl
{
    private Font _headerFont;
    private Bitmap _logo;
    private DataService _dataService;
    private CancellationTokenSource _cts;

    public CustomerPanel(DataService dataService)
    {
        InitializeComponent();
        _headerFont = new Font("Segoe UI", 16f, FontStyle.Bold);
        _logo = new Bitmap("logo.png");
        _dataService = dataService;
        _dataService.DataChanged += OnDataChanged;
        _cts = new CancellationTokenSource();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            // 1. Unsubscribe from external events (prevents callbacks during teardown)
            if (_dataService != null)
                _dataService.DataChanged -= OnDataChanged;

            // 2. Cancel and dispose background work
            _cts?.Cancel();
            _cts?.Dispose();

            // 3. Dispose owned GDI+ / unmanaged resources
            _headerFont?.Dispose();
            _logo?.Dispose();

            // 4. Dispose designer components (non-visual: timers, binding sources, etc.)
            components?.Dispose();
        }
        // 5. base.Dispose last (disposes child controls)
        base.Dispose(disposing);
    }
}
```

### Disposal Order Best Practice

1. Unsubscribe from external events (prevents callbacks during teardown).
2. Cancel and dispose background work (`CancellationTokenSource`, timers).
3. Dispose owned unmanaged/GDI+ resources.
4. Dispose `components` container (handles designer-tracked non-visual components).
5. Call `base.Dispose(disposing)` last (disposes child controls).

---

## .NET Framework vs .NET 8+ Notes

- **async/await**: Available in .NET Framework 4.5+ and all .NET 8+ versions. In .NET Framework 4.0, the `Microsoft.Bcl.Async` NuGet package was required.
- **IProgress<T>**: Available in both. No behavioral differences.
- **BackgroundWorker**: Available in both but considered legacy. On .NET 8+, prefer `Task.Run` + `IProgress<T>`.
- **Control.Invoke/BeginInvoke**: Identical behavior across frameworks. .NET 6+ added an `Action` overload so you no longer need the `(Action)(()=>...)` cast:

```csharp
// .NET 6+ / .NET 8+: cleaner Invoke syntax
this.Invoke(() => lblStatus.Text = "Done");

// .NET Framework 4.x: requires cast
this.Invoke((Action)(() => lblStatus.Text = "Done"));
```

- **GDI+ APIs**: Identical. The 10,000 GDI handle limit is a Windows OS constraint, not .NET-specific.
- **Double buffering**: `SetStyle` approach works identically. .NET 8+ adds better per-monitor DPI awareness but does not change the buffering model.
- **SynchronizationContext**: `WindowsFormsSynchronizationContext` behavior is the same across frameworks. `ConfigureAwait(false)` in library code still requires marshaling back to the UI thread for control access.
- **Dispose pattern**: Identical. The designer generates the same `components` container pattern in both frameworks.

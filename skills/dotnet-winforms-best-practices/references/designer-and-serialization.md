# Designer Code and CodeDOM Serialization Reference

Covers R3 (never hand-edit `.Designer.cs`) and R13 (when you *must* generate designer code, obey the serialization contract).

## Two Code Contexts

| Context | Files / location | Language level | Key rule |
|---|---|---|---|
| **Designer code** | `*.Designer.cs`, inside `InitializeComponent` | Serialization-centric — assume C# 2.0 | Simple, predictable, parsable |
| **Regular code** | `*.cs` — event handlers, business logic | Modern C# | Use modern features freely |

Decision: inside `.Designer.cs` / `InitializeComponent` → designer rules. Everywhere else → modern C# rules.

`InitializeComponent` is a **serialization format that happens to be valid C#** — closer to XML than to a method. The Designer round-trips it through a CodeDOM parser; anything the parser can't model is silently dropped or breaks visual editing.

## Prohibited inside `InitializeComponent`

| Category | Prohibited | Why |
|---|---|---|
| Control flow | `if`, `for`, `foreach`, `while`, `switch`, `goto`, `try`/`catch`, `lock`, `await`, VB `On Error`/`Resume` | Designer cannot parse |
| Operators | `?:`, `??`, `?.`, `?[]`, `nameof()` | Not in the serialization format |
| Functions | Lambdas, local functions, collection expressions (`= []`, `= [1, 2, 3]`) | Breaks the Designer parser |
| Fields | Only **class-scope fields** may be added to control collections — never locals | Designer cannot track locals |

Allowed method calls: Designer-supporting infrastructure only — `SuspendLayout`, `ResumeLayout`, `PerformLayout`, `BeginInit`, `EndInit`.

## Prohibited anywhere in `*.Designer.cs`

- Method definitions other than `InitializeComponent` / `Dispose` (preserve existing extra constructors)
- Properties
- Lambdas — including `button.Click += (s, e) => ...` event wiring
- Complex logic
- `??` / `?.` / `?[]` / `nameof()`
- Collection expressions
- **NRT annotations** — designer files never use nullable reference type annotations

Allowed and preferred: file-scoped namespace declarations.

## Required `InitializeComponent` structure

| Order | Step | Example |
|---|---|---|
| 1 | Instantiate controls | `_btnOK = new Button();` |
| 2 | Create components container | `components = new Container();` |
| 3 | Suspend layout / `BeginInit` | `SuspendLayout();` |
| 4 | Configure controls | Per-control property assignment |
| 5 | Configure Form/UserControl **last** | `ClientSize`, `Controls.Add()`, `Name`, `EndInit` |
| 6 | Resume layout | `ResumeLayout(false); PerformLayout();` |
| 7 | Backing fields at EOF | After the last `#endregion`. C# `private`; VB `Friend WithEvents` |

```csharp
private void InitializeComponent()
{
    // 1. Instantiate
    _picPhoto = new PictureBox();
    _btnAdopt = new Button();

    // 2. Components container
    components = new Container();

    // 3. Suspend
    ((ISupportInitialize)_picPhoto).BeginInit();
    SuspendLayout();

    // 4. Configure controls
    _picPhoto.Location = new Point(12, 12);
    _picPhoto.Name = "_picPhoto";
    _picPhoto.Size = new Size(380, 285);
    _picPhoto.SizeMode = PictureBoxSizeMode.Zoom;

    _btnAdopt.Location = new Point(93, 340);
    _btnAdopt.Name = "_btnAdopt";
    _btnAdopt.Text = "Adopt!";

    // OK — handler is a named method in the main .cs file
    _btnAdopt.Click += BtnAdopt_Click;

    // NOT OK — lambdas must never appear in InitializeComponent
    // _btnAdopt.Click += (s, e) => Close();

    // 5. Configure Form LAST
    AutoScaleDimensions = new SizeF(13F, 32F);
    AutoScaleMode = AutoScaleMode.Font;
    ClientSize = new Size(420, 450);
    Controls.Add(_picPhoto);
    Controls.Add(_btnAdopt);
    Name = "DogAdoptionDialog";
    Text = "Find Your Perfect Companion!";
    ((ISupportInitialize)_picPhoto).EndInit();

    // 6. Resume
    ResumeLayout(false);
    PerformLayout();
}

#endregion

// 7. Backing fields at EOF
private PictureBox _picPhoto;
private Button _btnAdopt;
```

Complex UI configuration logic belongs in the main `.cs` file, never in `.Designer.cs`.

## CodeDOM Serialization Control (R14)

For properties on types derived from `Component` or `Control`, tell the Designer whether/when to serialize. Use **exactly one** approach per property.

| Approach | Attribute / member | Use case |
|---|---|---|
| Default value | `[DefaultValue]` | Simple types; skipped when value matches default |
| Hidden | `[DesignerSerializationVisibility(Hidden)]` | Runtime-only data — collections, calculated properties |
| Conditional | `ShouldSerializeX()` + `ResetX()` | Complex conditions — custom fonts, optional settings |

```csharp
public class CustomControl : Control
{
    private Font? _customFont;

    [DefaultValue(typeof(Color), "Yellow")]
    public Color HighlightColor { get; set; } = Color.Yellow;

    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public List<string> RuntimeData { get; set; } = [];

    public Font? CustomFont
    {
        get => _customFont ?? Font;
        set => _customFont = value;
    }

    private bool ShouldSerializeCustomFont()
        => _customFont is not null && _customFont.Size != 9.0f;

    private void ResetCustomFont() => _customFont = null;
}
```

## Property Patterns — common leak source

| Pattern | Behavior | Use for |
|---|---|---|
| `=> new Type()` | New instance on **every** access | ⚠️ Almost always a leak with GDI+ types |
| `{ get; } = new()` | Constructed once | Cached / constant |
| `=> _field ?? Default` | Computed | Calculated property |

```csharp
public Brush BackgroundBrush => new SolidBrush(BackColor);          // ❌ leaks per access
public Brush BackgroundBrush { get; } = new SolidBrush(Color.White); // ✅ cached (dispose in Dispose)
public Font CurrentFont => _customFont ?? DefaultFont;               // ✅ dynamic, no allocation
```

Never "refactor" one form into another without understanding the semantic difference.

## Style in regular (non-designer) code

| Category | Rule |
|---|---|
| Using directives | Assume global usings for `System.Windows.Forms`, `System.Drawing`, `System.ComponentModel` |
| Primitives | `int` / `string`, not `Int32` / `String` |
| Instantiation | Target-typed — `Button button = new();` |
| `var` | Prefer explicit types; `var` only when the type is obvious or the name is unwieldy |
| Event handlers | Nullable sender — `void Handler(object? sender, EventArgs e)` |
| Events | Nullable — `public event EventHandler? MyEvent;` |
| `this` qualifier | Avoid except for disambiguation / extension methods (always required in .NET Framework style) |
| Argument validation | Always; throw helpers on .NET 8+ — `ArgumentNullException.ThrowIfNull(control);` |
| Modal dialogs | `using FrmOptions dlg = new();` — always dispose modal forms |
| Branching | Prefer switch expressions over if-else chains; pattern-match `sender is not Button b` guards |

## VB.NET Specifics

- Use the **VB Application Framework** — do not create `Program.vb`.
- Put app-wide defaults in `ApplicationEvents.vb`, handling `ApplyApplicationDefaults` and setting the `EventArgs` properties:

  | Property | Type | Purpose |
  |---|---|---|
  | `ColorMode` | `SystemColorMode` | Dark mode; prefer `System`. Also `Dark`, `Classic` |
  | `Font` | `Font` | Application-wide default font |
  | `HighDpiMode` | `HighDpiMode` | `SystemAware` default; `PerMonitorV2` for multi-monitor DPI |

- Forms/UserControls get no explicit constructor by default (the compiler generates one calling `InitializeComponent`). If you add one, keep that call.
- Control backing fields must be `Friend WithEvents controlName As ControlType`.
- Prefer handler `Sub`s with a `Handles` clause in the main file over `AddHandler` in `InitializeComponent`.
- VB cannot `Await` inside a `Catch` block — restructure or use a state-machine workaround.

## New Project Defaults

- Prefer the latest .NET (MVVM binding requires .NET 8+; `Control.InvokeAsync` requires .NET 9+ and is not experimental; dark mode and `Form.ShowAsync`/`ShowDialogAsync` both ship on .NET 9 behind **WFO5001** / **WFO5002** respectively and are stable from .NET 10).
- Enable the Windows API projection by default: `<TargetFramework>net10.0-windows10.0.22000.0</TargetFramework>` — on this TFM neither suppression above is needed.
- `app.config` is discouraged on modern .NET — set high DPI in code via `Application.SetHighDpiMode(...)` at startup, not via config or manifest.
- NuGet: prefer well-known stable packages compatible with the project TFM; pin to the latest stable major with a floating range, e.g. `[2.*,)`.

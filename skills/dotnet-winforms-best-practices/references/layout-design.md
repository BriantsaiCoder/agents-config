# WinForms Layout and UI Design Reference

Depth behind R11 (layout panels over absolute positioning) and R16 (layout/accessibility design rules). For DPI setup code see `code-patterns.md` Rule 7.

## Scaling and DPI

- Use adequate margins/padding; prefer `TableLayoutPanel` (TLP) / `FlowLayoutPanel` (FLP) over absolute positioning.
- New Forms/UserControls: author at 96 DPI / 100% for `AutoScaleMode` and scaling.
- Existing Forms: leave `AutoScaleMode` as-is, but account for scaling in coordinate-related properties.

## TLP Cell Sizing Fundamentals

Sizing-mode priority for both rows and columns: **AutoSize > Percent > Absolute**.

- **Columns**
  - `AutoSize` for caption columns, with `Anchor = Left | Right`.
  - `Percent` for content columns; use `Anchor` or `Dock` to match the intended resize behavior.
  - Avoid `Absolute` except for unavoidable fixed-size content (icons, buttons).
- **Rows**
  - `AutoSize` for single-line content (entry fields, captions, checkboxes).
  - `Percent` for multi-line TextBoxes, rendering areas, and filler rows that push a bottom button row down.
  - Avoid `Absolute` even more strongly than for columns.
- Set `Margin` on controls (3px minimum default). `Padding` has **no effect** in TLP cells.

## Layout Strategy

**Divide and conquer**

- Use multiple or nested TLPs for logical sections — don't cram everything into one mega-grid.
- Main form: a `SplitContainer`, or an outer TLP with Percent/AutoSize rows and columns for major sections.
- Each UI section gets its own nested TLP, or a dedicated UserControl in complex scenarios.

**Keep it simple**

- Individual TLPs: 2–4 columns max.
- Use GroupBoxes with nested TLPs for clear visual grouping.
- RadioButton clusters: single-column, auto-size-cell TLP inside an auto-growing GroupBox.
- Large scrollable content: nested panel controls with `AutoScroll` enabled.

## Common Layout Patterns

### Single-line TextBox (2-column TLP) — most common data entry pattern

- Label column: AutoSize width; label `Anchor = Left | Right` (vertically centers with the TextBox).
- TextBox column: 100% Percent width; TextBox `Dock = Fill` plus `Margin`.

### Multi-line TextBox / larger custom content

- **Option A (2-column TLP):** label in the same row, `Anchor = Top | Left`; TextBox `Dock = Fill` with `Margin`; row AutoSize or Percent.
- **Option B (1-column TLP):** label in its own row above (`Dock = Fill` or `Anchor = Left`); TextBox in the next row, `Dock = Fill` with `Margin`; row AutoSize or Percent.

For multi-line TextBoxes the **cell** defines the size, not the TextBox content.

## Container Sizing — prevents clipping

For a GroupBox/Panel inside a TLP cell:

- **Must** set `AutoSize = true` and `AutoSizeMode = GrowOnly`.
- Should `Dock = Fill` in its cell.
- Parent TLP row should be AutoSize.
- Inner content uses a nested TLP or FLP.

Why: a fixed-height container reports its fixed size and breaks the sizing chain, clipping content even when the parent row is AutoSize.

## Modal Dialog Button Placement

| Pattern | Layout | Use for |
|---|---|---|
| **A — bottom-right** | Buttons in an FLP with `FlowDirection = RightToLeft`, placed in the bottom row of the main TLP; keep a Percent filler row above. Visual order: `[OK]` left, `[Cancel]` right | Data entry dialogs, settings, confirmations |
| **B — top-right stacked** | Buttons in an FLP with `FlowDirection = TopDown`, in a dedicated AutoSize rightmost column; FLP `Anchor = Top | Right`. Order: `[OK]` above `[Cancel]` | Multi-step wizards, navigation-heavy dialogs |

## Modal Dialog Behavior

| Aspect | Rule |
|---|---|
| Buttons | Primary (OK) → `AcceptButton` + `DialogResult.OK`; secondary (Cancel) → `CancelButton` + `DialogResult.Cancel` |
| Close strategy | `DialogResult` closes the form implicitly — no extra code needed |
| Validation | Validate at **form** scope, not field scope. Never block focus change with `CancelEventArgs.Cancel = true` |
| Data transfer | Use `Form.DataContext` (.NET 8+) to pass and return modal data objects |

## Layout Recipes

| Form type | Structure |
|---|---|
| MainForm | MenuStrip, optional ToolStrip, content area, StatusStrip |
| Simple entry form | Data entry fields on the left, button column on the right; set a meaningful `MinimumSize` for modals |
| Tabs | Only for distinct tasks; keep the count low and labels short |

For complex layouts, extract logical sections into UserControls, nest them in the outer TLP, and pass data via `DataContext`. One UserControl per TabPage keeps designer code manageable.

## Accessibility

- Set `AccessibleName` and `AccessibleDescription` on actionable controls.
- Maintain logical tab order via `TabIndex` — accessibility follows control addition order otherwise.
- Verify keyboard-only navigation, unambiguous mnemonics, and screen reader compatibility.

## TreeView, ListView, DataGridView

| Control | Rules |
|---|---|
| TreeView | Must have a visible, default-expanded root node |
| ListView | Prefer over DataGridView for small lists with few columns |
| Content setup | Populate in code, not in designer code-behind |
| ListView columns | Set width to `-1` (fit longest content) or `-2` (fit header) **after** populating |
| SplitContainer | Use for resizable panes hosting TreeView/ListView |
| DataGridView | Prefer a derived class with double buffering enabled; theme colors explicitly for dark mode; page or virtualize large data (`VirtualMode = true` with `CellValueNeeded`) |

## Resources and Localization

- UI-facing string literals belong in resource files.
- Design layouts to tolerate localized captions of differing lengths.

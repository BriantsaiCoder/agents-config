# WinForms Data Binding Patterns Reference

## BindingSource Deep Dive

### Basic Setup

`BindingSource` is the central mediator between data and UI controls in WinForms.

```csharp
// Typical setup in form constructor or Load event
var bindingSource = new BindingSource();
bindingSource.DataSource = typeof(Customer); // design-time hint
bindingSource.DataSource = customerList;     // runtime assignment

// Bind controls
txtName.DataBindings.Add("Text", bindingSource, "Name",
    true, DataSourceUpdateMode.OnPropertyChanged);
txtEmail.DataBindings.Add("Text", bindingSource, "Email",
    true, DataSourceUpdateMode.OnValidation);
```

### Currency Manager and Position Tracking

`BindingSource` wraps a `CurrencyManager` internally, tracking which record is "current."

```csharp
// Navigate records
bindingSource.Position = 0;              // first record
bindingSource.MoveNext();
bindingSource.MoveLast();

// React to position changes
bindingSource.PositionChanged += (s, e) =>
{
    var current = (Customer)bindingSource.Current;
    lblStatus.Text = $"Record {bindingSource.Position + 1} of {bindingSource.Count}";
};

// Programmatically find and select
int idx = bindingSource.Find("Name", "Alice");
if (idx >= 0)
    bindingSource.Position = idx;
```

### Adding, Removing, and Editing

```csharp
// Add new record (creates default instance via parameterless constructor)
bindingSource.AddNew();

// Remove current record
bindingSource.RemoveCurrent();

// Commit or cancel pending edits
bindingSource.EndEdit();
bindingSource.CancelEdit();
```

### Sorting and Filtering

Sorting requires the underlying list to implement `IBindingList` with `SupportsSorting = true`. A plain `List<T>` does NOT support sorting through BindingSource.

```csharp
// Works with DataTable-backed sources
bindingSource.Sort = "LastName ASC, FirstName ASC";

// Filtering requires IBindingListView (DataView supports it natively)
bindingSource.DataSource = customersTable;
bindingSource.Filter = "Country = 'US' AND Revenue > 1000";
bindingSource.RemoveFilter();
```

---

## BindingList<T> vs ObservableCollection<T> vs List<T>

| Feature | `List<T>` | `BindingList<T>` | `ObservableCollection<T>` |
|---|---|---|---|
| Change notifications | None | Yes (ListChanged) | Yes (CollectionChanged) |
| WinForms binding support | Partial (no auto-refresh) | Full | Partial (designed for WPF) |
| Item change notification | No | Yes (if T implements INPC) | No (collection changes only) |
| Sorting/searching built-in | No | No (override required) | No |
| AddNew support (ICancelAddNew) | No | Yes | No |
| RaiseListChangedEvents toggle | N/A | Yes (can suppress bulk changes) | No equivalent |
| Recommended for WinForms | No | **Yes** | No |

```csharp
// Preferred: BindingList<T> for WinForms
var customers = new BindingList<Customer>(repository.GetAll().ToList());
customers.AllowNew = true;
customers.AllowEdit = true;
customers.AllowRemove = true;

// Suppress notifications during bulk updates
customers.RaiseListChangedEvents = false;
foreach (var c in bulkData)
    customers.Add(c);
customers.RaiseListChangedEvents = true;
customers.ResetBindings(); // Single notification after bulk load

// React to list changes
customers.ListChanged += (s, e) =>
{
    if (e.ListChangedType == ListChangedType.ItemChanged)
        Console.WriteLine($"Item at index {e.NewIndex} changed.");
};

bindingSource.DataSource = customers;
```

**Pitfall**: If you bind a plain `List<T>`, the UI will not update when items are added or removed. You must call `bindingSource.ResetBindings(false)` manually -- prefer `BindingList<T>` instead.

---

## INotifyPropertyChanged for Two-Way Binding

For property-level change notifications (cell/field updates), the model must implement `INotifyPropertyChanged`.

```csharp
public class Customer : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;

    private string _name;
    public string Name
    {
        get => _name;
        set
        {
            if (_name == value) return;
            _name = value;
            OnPropertyChanged(nameof(Name));
        }
    }

    private decimal _balance;
    public decimal Balance
    {
        get => _balance;
        set
        {
            if (_balance == value) return;
            _balance = value;
            OnPropertyChanged(nameof(Balance));
        }
    }

    protected virtual void OnPropertyChanged(string propertyName)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
```

When using `BindingList<T>`, item-level property changes automatically translate into `ListChanged` events with `ListChangedType.ItemChanged`, keeping DataGridView rows in sync.

Without `INotifyPropertyChanged`, changing a property in code will not update the bound control until the user navigates away and back.

---

## DataGridView Binding Patterns

### Basic DataSource Binding

```csharp
// Auto-generate columns from properties
dataGridView1.AutoGenerateColumns = true;
dataGridView1.DataSource = bindingSource;

// Or use explicit columns for control over display
dataGridView1.AutoGenerateColumns = false;
dataGridView1.Columns.AddRange(
    new DataGridViewTextBoxColumn
    {
        DataPropertyName = "Name",
        HeaderText = "Customer Name",
        Width = 200
    },
    new DataGridViewTextBoxColumn
    {
        DataPropertyName = "Balance",
        HeaderText = "Balance",
        DefaultCellStyle = { Format = "C2", Alignment = DataGridViewContentAlignment.MiddleRight }
    },
    new DataGridViewCheckBoxColumn
    {
        DataPropertyName = "IsActive",
        HeaderText = "Active"
    }
);
dataGridView1.DataSource = bindingSource;
```

### Cell Formatting

```csharp
dataGridView1.CellFormatting += (s, e) =>
{
    if (e.ColumnIndex == balanceColumn.Index && e.Value is decimal balance)
    {
        e.CellStyle.ForeColor = balance < 0 ? Color.Red : Color.Black;
    }
};
```

### Cell-Level Validation

```csharp
dataGridView1.CellValidating += (s, e) =>
{
    if (dataGridView1.Columns[e.ColumnIndex].DataPropertyName == "Email")
    {
        var value = e.FormattedValue?.ToString();
        if (!string.IsNullOrEmpty(value) && !value.Contains('@'))
        {
            e.Cancel = true; // keeps cell in edit mode
            dataGridView1.Rows[e.RowIndex].ErrorText = "Invalid email address.";
        }
    }
};

dataGridView1.CellEndEdit += (s, e) =>
{
    dataGridView1.Rows[e.RowIndex].ErrorText = string.Empty;
};
```

### Handling DataError

```csharp
// Prevent unhandled exception dialogs on invalid input
dataGridView1.DataError += (s, e) =>
{
    if (e.Context.HasFlag(DataGridViewDataErrorContexts.Commit))
    {
        MessageBox.Show("Invalid value entered.");
        e.Cancel = true; // stay in edit mode
    }
};
```

---

## ComboBox and ListBox Binding

### DisplayMember and ValueMember

```csharp
var categories = new BindingList<Category>
{
    new Category { Id = 1, Name = "Electronics" },
    new Category { Id = 2, Name = "Books" },
    new Category { Id = 3, Name = "Clothing" }
};

cboCategory.DataSource = categories;
cboCategory.DisplayMember = "Name";   // what the user sees
cboCategory.ValueMember = "Id";       // what SelectedValue returns
```

### Binding SelectedValue to Another BindingSource

```csharp
// Bind the combo's selected value to the product's CategoryId
cboCategory.DataBindings.Add("SelectedValue", productBindingSource, "CategoryId",
    true, DataSourceUpdateMode.OnPropertyChanged);
```

### Safe Property Assignment Order

```csharp
// SAFE: set members before data source to avoid premature SelectedIndexChanged
cboCountry.DisplayMember = "Name";
cboCountry.ValueMember = "Id";
cboCountry.DataSource = countries;
```

**Pitfall**: Setting `DataSource` before `DisplayMember`/`ValueMember` triggers premature `SelectedIndexChanged` events with stale values.

**Pitfall**: Binding a ComboBox to the same BindingSource as a grid causes them to share the same currency (position). Use a separate BindingSource for lookup lists.

---

## Master-Detail Binding

### Using DataSet Relations

```csharp
// Classic approach with DataSet / DataRelation
var ds = new DataSet();
ds.Tables.Add(ordersTable);
ds.Tables.Add(orderDetailsTable);
ds.Relations.Add("OrderDetails",
    ordersTable.Columns["OrderId"],
    orderDetailsTable.Columns["OrderId"]);

masterBindingSource.DataSource = ds;
masterBindingSource.DataMember = "Orders";

detailBindingSource.DataSource = masterBindingSource;
detailBindingSource.DataMember = "OrderDetails"; // relation name

dgvOrders.DataSource = masterBindingSource;
dgvOrderDetails.DataSource = detailBindingSource;
// Selecting a row in dgvOrders automatically filters dgvOrderDetails
```

### Using Object Collections

```csharp
// Model
public class Order
{
    public int OrderId { get; set; }
    public DateTime OrderDate { get; set; }
    public BindingList<OrderDetail> Details { get; set; } = new();
}

// Bind master
masterBindingSource.DataSource = new BindingList<Order>(orders);
dgvOrders.DataSource = masterBindingSource;

// Bind detail to the "Details" property of the current master
detailBindingSource.DataSource = masterBindingSource;
detailBindingSource.DataMember = "Details";
dgvOrderDetails.DataSource = detailBindingSource;
```

### Manual Master-Detail via CurrentChanged

```csharp
// Alternative when the child list is not a property of the parent
var masterBS = new BindingSource { DataSource = orders };
var detailBS = new BindingSource();

masterBS.CurrentChanged += (s, e) =>
{
    if (masterBS.Current is Order order)
        detailBS.DataSource = orderDetailRepo.GetByOrderId(order.OrderId);
};

dgvOrders.DataSource = masterBS;
dgvDetails.DataSource = detailBS;
```

When the user selects a different row in the master grid, the detail grid updates automatically because `BindingSource` tracks the current position and resolves the child list.

---

## BindingNavigator Usage

`BindingNavigator` is a toolbar-style control that provides record navigation, add, and delete buttons.

```csharp
// Wire up in designer or code
bindingNavigator1.BindingSource = bindingSource;

// It automatically provides: MoveFirst, MovePrevious, PositionItem,
// MoveNext, MoveLast, AddNew, Delete, CountItem

// Customize: add a Save button
var btnSave = new ToolStripButton("Save");
btnSave.Click += (s, e) =>
{
    bindingSource.EndEdit();
    repository.SaveAll((BindingList<Customer>)bindingSource.DataSource);
};
bindingNavigator1.Items.Add(btnSave);
```

---

## ErrorProvider Integration with IDataErrorInfo

### Model Implementation

```csharp
public class Customer : INotifyPropertyChanged, IDataErrorInfo
{
    // ... properties with INPC as shown above ...

    public string Error => null; // summary error (rarely used)

    public string this[string columnName]
    {
        get
        {
            switch (columnName)
            {
                case nameof(Name):
                    if (string.IsNullOrWhiteSpace(Name))
                        return "Name is required.";
                    break;
                case nameof(Balance):
                    if (Balance < 0)
                        return "Balance cannot be negative.";
                    break;
            }
            return null;
        }
    }
}
```

### ErrorProvider Binding

```csharp
// The ErrorProvider can bind to the same BindingSource
errorProvider1.DataSource = bindingSource;

// It automatically reads IDataErrorInfo[columnName] for each bound control
// and shows the error icon next to controls whose DataMember matches.
```

No additional wiring is needed per-control when using `IDataErrorInfo` -- the `ErrorProvider` iterates over all controls bound to the `BindingSource` and queries the model.

---

## DataGridView Virtual Mode (Large Datasets)

Virtual mode avoids loading all rows into memory. The grid requests data on demand.

```csharp
dataGridView1.VirtualMode = true;
dataGridView1.RowCount = totalRecordCount; // set from DB count query

dataGridView1.CellValueNeeded += (s, e) =>
{
    // Fetch or cache the row data
    var row = dataCache.GetRow(e.RowIndex);
    switch (e.ColumnIndex)
    {
        case 0: e.Value = row.Id; break;
        case 1: e.Value = row.Name; break;
        case 2: e.Value = row.Balance; break;
    }
};

// For editable virtual mode, also handle CellValuePushed
dataGridView1.CellValuePushed += (s, e) =>
{
    var row = dataCache.GetRow(e.RowIndex);
    switch (e.ColumnIndex)
    {
        case 1: row.Name = (string)e.Value; break;
        case 2: row.Balance = (decimal)e.Value; break;
    }
};
```

### Page-Based Cache Strategy

```csharp
public class DataPageCache
{
    private readonly Dictionary<int, List<Customer>> _pages = new();
    private const int PageSize = 100;

    public Customer GetRow(int rowIndex)
    {
        int pageIndex = rowIndex / PageSize;
        if (!_pages.ContainsKey(pageIndex))
            _pages[pageIndex] = LoadPage(pageIndex);

        return _pages[pageIndex][rowIndex % PageSize];
    }

    private List<Customer> LoadPage(int pageIndex)
    {
        int offset = pageIndex * PageSize;
        return _repository.GetPage(offset, PageSize);
    }
}
```

**Important**: When `VirtualMode = true`, the DataGridView does NOT use `DataSource`. Do not mix virtual mode with data binding -- handle `CellValueNeeded`/`CellValuePushed` instead.

---

## Simple Binding Options

### DataSourceUpdateMode

- `OnPropertyChanged` -- pushes value to source on every keystroke.
- `OnValidation` (default) -- pushes value when control loses focus and Validating succeeds.
- `Never` -- read-only binding.

```csharp
txtPrice.DataBindings.Add("Text", bindingSource, "Price",
    formattingEnabled: true,
    updateMode: DataSourceUpdateMode.OnPropertyChanged,
    nullValue: "0.00",            // displayed when source value is null/DBNull
    formatString: "C2");          // currency format
```

### Detecting Binding Errors

```csharp
// Silent binding failures (e.g., misspelled property names) produce no exception.
// Subscribe to BindingComplete for diagnostics:
bindingSource.BindingComplete += (s, e) =>
{
    if (e.BindingCompleteState != BindingCompleteState.Success)
        Debug.WriteLine($"Binding error: {e.ErrorText}");
};
```

---

## Common Pitfalls

### 1. Binding to Null DataSource

```csharp
// BAD: throws or silently fails
bindingSource.DataSource = null;
txtName.DataBindings.Add("Text", bindingSource, "Name");

// GOOD: use typeof(T) as placeholder when no data is available
bindingSource.DataSource = typeof(Customer);
// Then assign actual data later:
bindingSource.DataSource = customerList;
```

### 2. Cross-Thread Binding Updates

```csharp
// BAD: updating bound data from a background thread
Task.Run(() =>
{
    var data = LoadData();
    bindingSource.DataSource = data; // InvalidOperationException
});

// GOOD: marshal back to UI thread
Task.Run(() =>
{
    var data = LoadData();
    this.Invoke((Action)(() =>
    {
        bindingSource.DataSource = data;
    }));
});

// BETTER (.NET 4.5+ / .NET 8+): async/await preserves SynchronizationContext
private async void btnLoad_Click(object sender, EventArgs e)
{
    var data = await Task.Run(() => LoadData());
    bindingSource.DataSource = data; // safe, back on UI thread
}
```

### 3. Forgetting EndEdit Before Saving

```csharp
// BAD: saves stale data because the current edit is still pending
void btnSave_Click(object sender, EventArgs e)
{
    repository.Save(bindingSource.List);
}

// GOOD: commit pending edits first
void btnSave_Click(object sender, EventArgs e)
{
    bindingSource.EndEdit();   // commits current cell/row edit
    this.Validate();           // triggers validation on focused control
    repository.Save(bindingSource.List);
}
```

### 4. Shared BindingSource for Lookup and Edit

```csharp
// BAD: ComboBox lookup and DataGridView share the same BindingSource,
// causing selection in one to move position in the other.
cboCategory.DataSource = categoryBindingSource;
dgvProducts.Columns["Category"].DataSource = categoryBindingSource; // oops

// GOOD: use separate BindingSource instances for lookups
var lookupSource = new BindingSource { DataSource = categories };
((DataGridViewComboBoxColumn)dgvProducts.Columns["Category"]).DataSource = lookupSource;
```

### 5. BindingList<T> and AddNew Without Parameterless Constructor

```csharp
// BAD: BindingList<T>.AddNew() requires a parameterless constructor
// If T has no parameterless constructor, AddNew throws InvalidOperationException.

// FIX: handle the AddingNew event to supply a custom instance
bindingList.AddingNew += (s, e) =>
{
    e.NewObject = new Customer(defaultRegion, DateTime.Now);
};
```

### 6. Stale BindingSource After Replacing DataSource

After setting `bindingSource.DataSource = newList`, existing `DataBindings` on controls remain valid, but events may not re-fire. Call `bindingSource.ResetBindings(false)` to force a refresh if controls do not update.

---

## .NET Framework vs .NET 8+ Notes

- **Binding behavior is largely identical** between .NET Framework 4.x and .NET 8+ WinForms. The same `BindingSource`, `DataGridView`, and `ErrorProvider` patterns apply.
- **.NET 8+ WinForms** adds nullable reference type annotations on binding APIs, which can surface new warnings when `DataSource` is typed as `object?`.
- **DataGridView in .NET 8+** has improved high-DPI rendering, but the binding model is unchanged.
- `IDataErrorInfo` works in both. .NET 8+ also supports `INotifyDataErrorInfo` (originally WPF-only), allowing async validation and multiple errors per property -- but `ErrorProvider` does not consume it automatically; you must wire it manually.
- `BindingList<T>` behavior is identical across frameworks. No API changes affect usage patterns.

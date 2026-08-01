# Python Playwright + Server Lifecycle Management

Testing local web applications with Python Playwright, including server lifecycle automation for dev servers. Use when writing Python automation scripts against local apps (Flask, FastAPI, Django, Vite, Next.js etc.) that need a running backend before browser interaction.

> Merged from: `webapp-testing` (originally Python Playwright specific).

## Decision Tree: Choosing Your Approach

```
User task → Is it static HTML?
    ├─ Yes → Read HTML file directly to identify selectors
    │         ├─ Success → Write Playwright script using selectors
    │         └─ Fails/Incomplete → Treat as dynamic (below)
    │
    └─ No (dynamic webapp) → Is the server already running?
        ├─ No → Use a server lifecycle helper script
        │        Then write simplified Playwright automation
        │
        └─ Yes → Reconnaissance-then-action:
            1. Navigate and wait for networkidle
            2. Take screenshot or inspect DOM
            3. Identify selectors from rendered state
            4. Execute actions with discovered selectors
```

## Server Lifecycle Helper Pattern

For dynamic webapps, you need the server running before Playwright can connect. A well-designed helper script:

1. Starts the dev server as a child process
2. Polls a port until it's accepting connections
3. Runs your Playwright automation as a subprocess
4. Terminates the server cleanly on exit (even on failure)

**Single server**:
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- python your_automation.py
```

**Multiple servers** (backend + frontend):
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- python your_automation.py
```

The helper ensures both servers are up before your automation runs, and both are torn down when done.

**Black-box principle**: Treat the helper script as a black box. Run `--help` first, don't read the source unless you need to customize — reading large helper scripts pollutes your LLM context without adding value.

## Basic Playwright Automation Script

Once the server is managed separately, your automation script stays focused on browser logic only:

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)  # Always headless in automation
    page = browser.new_page()
    page.goto('http://localhost:5173')
    page.wait_for_load_state('networkidle')  # CRITICAL: wait for JS execution

    # ... your automation logic
    page.locator('button', has_text='Login').click()
    page.locator('input[name="email"]').fill('test@example.com')

    browser.close()
```

## Reconnaissance-Then-Action Pattern

When you don't know the exact selectors in a dynamic app:

### Step 1 — Inspect rendered DOM

```python
page.screenshot(path='/tmp/inspect.png', full_page=True)
content = page.content()  # Full HTML after JS execution

# Enumerate common interactive elements
buttons = page.locator('button').all()
links = page.locator('a').all()
inputs = page.locator('input').all()

for btn in buttons:
    print(btn.text_content(), btn.get_attribute('data-testid'))
```

### Step 2 — Identify selectors

From screenshot + HTML + element enumeration, choose:
- `data-testid` if present
- `role=` + accessible name (`page.get_by_role('button', name='Login')`)
- `text=` for unique labels
- Last resort: CSS selectors

### Step 3 — Execute actions

```python
page.get_by_role('button', name='Login').click()
page.get_by_label('Email').fill('user@example.com')
page.wait_for_url('**/dashboard')
```

## Critical Pitfall: Don't Inspect Before `networkidle`

```python
# ❌ Wrong — JS still loading, DOM incomplete
page.goto('http://localhost:5173')
print(page.content())  # Missing dynamic content

# ✅ Correct — wait for JS to settle
page.goto('http://localhost:5173')
page.wait_for_load_state('networkidle')
print(page.content())
```

For SPAs with streaming SSR or long-running client effects, `networkidle` may not be enough. Use explicit waits:

```python
page.wait_for_selector('[data-testid="app-ready"]')
# or
page.wait_for_function('() => window.__APP_READY__ === true')
```

## Console Logging Capture

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()

    # Capture all console messages
    console_messages = []
    page.on('console', lambda msg: console_messages.append({
        'type': msg.type,
        'text': msg.text,
        'location': msg.location,
    }))

    # Capture uncaught errors
    errors = []
    page.on('pageerror', lambda err: errors.append(str(err)))

    page.goto('http://localhost:5173')
    page.wait_for_load_state('networkidle')

    # Interact...
    page.locator('button', has_text='Submit').click()

    # Check for errors
    if errors:
        print(f"Page errors: {errors}")
    for msg in console_messages:
        if msg['type'] in ('error', 'warning'):
            print(f"[{msg['type']}] {msg['text']}")

    browser.close()
```

## Element Discovery Helper

Generic utility for finding interactive elements on an unknown page:

```python
from playwright.sync_api import Page

def discover_elements(page: Page):
    """Return all user-interactable elements with their labels/selectors."""
    elements = {'buttons': [], 'links': [], 'inputs': []}

    for btn in page.locator('button, [role="button"]').all():
        label = (
            btn.get_attribute('aria-label')
            or btn.text_content()
            or btn.get_attribute('data-testid')
            or 'unnamed'
        )
        elements['buttons'].append({'label': label.strip(), 'visible': btn.is_visible()})

    for link in page.locator('a[href]').all():
        elements['links'].append({
            'text': (link.text_content() or '').strip(),
            'href': link.get_attribute('href'),
        })

    for inp in page.locator('input, textarea, select').all():
        elements['inputs'].append({
            'type': inp.get_attribute('type') or 'text',
            'name': inp.get_attribute('name'),
            'placeholder': inp.get_attribute('placeholder'),
            'label': inp.get_attribute('aria-label'),
        })

    return elements

# Usage
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto('http://localhost:5173')
    page.wait_for_load_state('networkidle')

    discovered = discover_elements(page)
    print("Buttons:", discovered['buttons'])
    print("Inputs:", discovered['inputs'])

    browser.close()
```

## Static HTML Automation (no server)

```python
from pathlib import Path
from playwright.sync_api import sync_playwright

html_file = Path('path/to/local.html').absolute()
file_url = html_file.as_uri()  # file:///absolute/path/to/local.html

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto(file_url)

    # Interact with the static page
    page.locator('button').first.click()
    page.screenshot(path='result.png')

    browser.close()
```

## Best Practices (Python-specific)

- **Always `headless=True`** in automation — no need for visible browser
- **Use `sync_playwright()` for automation scripts** — async only when you need concurrency
- **Always close the browser** — wrap in `try/finally` or use context manager
- **Use descriptive selectors**: `page.get_by_role()`, `page.get_by_label()`, `page.get_by_test_id()` — avoid CSS selectors when possible
- **Add appropriate waits**: `page.wait_for_selector()`, `page.wait_for_load_state('networkidle')`, `page.wait_for_url()`
- **Use server lifecycle helpers as black boxes** — run `--help`, don't read source unless customizing
- **Capture console and page errors** — many "mysterious test failures" are silent JS errors

## Relationship to Playwright TypeScript

The patterns in this reference are Python-specific, but the concepts (locators, waiting, network mocking, fixtures) are identical across language bindings.

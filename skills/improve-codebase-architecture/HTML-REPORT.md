# HTML Report Format

架構審查輸出為 OS temp directory 中的一個 self-contained HTML file，並遵循 [SKILL.md](SKILL.md) 的 language contract。Tailwind 與 Mermaid 都從 CDN 載入；Mermaid 負責 graph-shaped diagrams，hand-built divs 與 inline SVG 負責較具編輯感的 visuals（mass diagrams、cross-sections）。混合使用兩者，不要讓所有內容都依賴 Mermaid 而顯得制式。

## Scaffold

```html
<!doctype html>
<html lang="zh-TW">
  <head>
    <meta charset="utf-8" />
    <title>架構審查 — {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
    </script>
    <style>
      /* small custom layer for things Tailwind doesn't cover cleanly:
         dashed seam lines, hand-drawn-feeling arrow heads, etc. */
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      .deep { background: linear-gradient(135deg, #0f172a, #1e293b); }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## Header

Repo name, date, and a compact legend: solid box = module, dashed line = seam, red arrow = leakage, thick dark box = deep module. No introduction paragraph — straight into the candidates.

## Candidate card

The diagrams carry the weight. Prose is sparse, plain, and uses the glossary terms (from the `/codebase-design` skill) without ceremony.

Each candidate is one `<article>`:

- **標題** — 簡短命名 deepening，例如「收攏 Order intake pipeline」。
- **Badge row** — recommendation strength 使用 `強烈建議`（emerald）、`值得探索`（amber）或 `推測性`（slate），再加上 dependency category tag（`in-process`、`local-substitutable`、`ports & adapters`、`mock`）。
- **檔案** — 使用 `font-mono text-sm` 的 monospaced list。
- **修改前 / 修改後圖** — 核心視覺；兩欄並排，diagram patterns 見下文。
- **問題** — 一句話說明阻力。
- **方案** — 一句話說明變更。
- **效益** — 每個 bullet ≤6 words，例如「tests 只打到一個 interface」、「Pricing logic 不再跨 seam 洩漏」、「刪除 4 個 shallow module」。
- **ADR 提示**（如適用）— amber-tinted box 中的一行提示。

No paragraphs of explanation. If the diagram needs a paragraph to be understood, redraw the diagram.

## Diagram patterns

Pick the pattern that fits the candidate. Mix them. Don't make every diagram look the same — variety is part of the point.

### Mermaid graph (the workhorse for dependencies / call flow)

Use a Mermaid `flowchart` or `graph` when the point is "X calls Y calls Z, and look at the mess." Wrap it in a Tailwind-styled card so it doesn't feel parachuted in. Style with classDef to colour leakage edges red and the deep module dark. Sequence diagrams work well for "before: 6 round-trips; after: 1."

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A[OrderHandler] --> B[OrderValidator]
      B --> C[OrderRepo]
      C -.leak.-> D[PricingClient]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

### Hand-built boxes-and-arrows (when Mermaid's layout fights you)

Modules as `<div>`s with borders and labels. Arrows as inline SVG `<line>` or `<path>` elements positioned absolutely over a relative container. Reach for this when you want the "after" diagram to feel like one thick-bordered deep module with greyed-out internals — Mermaid won't render that with the right weight.

### Cross-section (good for layered shallowness)

Stack horizontal bands (`h-12 border-l-4`) to show layers a call passes through. Before: 6 thin layers each doing nothing. After: 1 thick band labelled with the consolidated responsibility.

### Mass diagram (good for "interface as wide as implementation")

Two rectangles per module — one for interface surface area, one for implementation. Before: interface rectangle is nearly as tall as the implementation rectangle (shallow). After: interface rectangle is short, implementation rectangle is tall (deep).

### Call-graph collapse

Before: a tree of function calls rendered as nested boxes. After: the same tree collapsed into one box, with the now-internal calls shown faded inside it.

## Style guidance

- Lean editorial, not corporate-dashboard. Generous whitespace. Serif optional for headings (`font-serif` works well with stone/slate).
- Colour sparingly: one accent (emerald or indigo) plus red for leakage and amber for warnings.
- Keep diagrams ~320px tall so before/after sits comfortably side by side without scrolling.
- Use `text-xs uppercase tracking-wider` for module labels inside diagrams — they should read as schematic, not as UI.
- The only scripts are the Tailwind CDN and the Mermaid ESM import. The report is otherwise static — no app code, no interactivity beyond Mermaid's own rendering.

## 首要建議

使用一張較大的 card：candidate name、一句理由，以及連回該 card 的 anchor link。僅此而已。

## Tone

遵循 [SKILL.md](SKILL.md) 的 `Language` section；本 scaffold 只定義 report tone。文字保持精簡直接，但不得偏離 `/codebase-design` vocabulary。

**Use exactly:** module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality.

**Never substitute:** component, service, unit (for module) · API, signature (for interface) · boundary (for seam) · layer, wrapper (for module, when you mean module).

**Phrasings that fit the style:**

- "Order intake module 過於 shallow：interface 幾乎和 implementation 一樣複雜。"
- "Pricing 跨越 seam 洩漏。"
- "Deepen：一個 interface，一個測試位置。"
- "兩個 adapter 才足以支持 seam：production 使用 HTTP，tests 使用 in-memory。"

**效益 bullets** 使用 glossary terms 指名 gain：*「locality：bug 集中在一個 module」*、*「leverage：一個 interface，N 個 call sites」*、*「interface 縮小；implementation 吸收 shallow module」*。不要寫 *「更容易維護」* 或 *「更乾淨的程式碼」*；這些詞不在 glossary 中。

No hedging, no throat-clearing, no "it's worth noting that…". If a sentence could be a bullet, make it a bullet. If a bullet could be cut, cut it. If a term isn't in the `/codebase-design` glossary, reach for one that is before inventing a new one.

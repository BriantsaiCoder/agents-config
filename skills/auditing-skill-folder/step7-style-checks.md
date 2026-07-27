# Step 7 (optional) — Style & structural spot-check

Checks Steps 1–6 do not catch. Run after the six-step protocol to surface lower-priority defects. Findings are tag-and-fix, not restart-gating; never promote Style → Delete (deletion belongs to Step 6).

## Checks

| Check | Flag | Authoritative rule (`superpowers:writing-skills`) |
|---|---|---|
| Naming | non-`[a-z0-9-]` chars; passive voice; processes not in gerund (-ing) form | "letters, numbers, and hyphens only"; "active voice, verb-first"; "Gerunds (-ing) work well for processes" |
| Frontmatter | missing `name` or `description`; YAML > 1024 chars; first-person voice; description without "Use when…" prefix; **description > 500 chars** | "Two required fields: name and description"; "Max 1024 characters total"; "Write in third person"; "Start with 'Use when…'"; "Keep under 500 characters if possible" |
| Cross-reference | `@skills/…` or `@path/…` force-loads; cross-skill mentions without `**REQUIRED SUB-SKILL:**` / `**REQUIRED BACKGROUND:**` markers | "Use skill name only, with explicit requirement markers"; "no @ links — force-loads files immediately, consuming 200k+ context" |
| Structure sections | missing required SKILL.md sections: Overview / When to Use / Quick Reference / Common Mistakes (technique / pattern / discipline skills) | "SKILL.md Structure" template requires Overview + When to Use + Quick Reference + Common Mistakes |
| Keyword coverage | description and body lack searchable terms — concrete error messages, symptoms, synonyms (`timeout/hang/freeze`), tool / library names | "Use words Claude would search for: error messages, symptoms, synonyms, tools" |
| Flowchart misuse | graphviz used for reference tables, linear instructions, code examples, or generic labels (`step1`, `helper2`) | "Use flowcharts ONLY for non-obvious decision points"; never for reference / code / linear / generic labels |
| Code example quality | multi-language dilution (`example-js.js` + `example-py.py`); contrived / generic fill-in-the-blank templates; non-runnable snippets | "One excellent example beats many mediocre ones"; "Complete and runnable"; not "fill-in-the-blank templates" |
| Narrative | "In session 2025-XX-XX we found…" anecdotes; generic placeholder labels | Anti-patterns: Narrative Example, Generic Labels |
| Bulletproofing (discipline skills only) | discipline-enforcing skill missing **(a)** rationalization table / Red Flags / Iron Law, **(b)** explicit loophole closure (each rule paired with "No exceptions" or forbidden-workaround list), or **(c)** "Spirit vs Letter" foundational principle | "Skills that enforce discipline need to resist rationalization"; "Close every loophole explicitly"; "Address 'Spirit vs Letter' Arguments"; "Build Rationalization Table"; "Create Red Flags List"; Iron Law |

## Verdict augmentation

Append to existing verdict block per skill:

- `Style:fix-naming`
- `Style:fix-frontmatter`
- `Style:fix-cross-reference`
- `Style:add-sections`
- `Style:add-keywords`
- `Style:remove-flowchart`
- `Style:fix-code-example`
- `Style:remove-narrative`
- `Style:add-bulletproofing` (discipline skills only)

Multiple tags allowed. Style findings stack with the Step 1–6 verdict (Keep / Trim / Move / Hook / Split / Delete) but never override it.

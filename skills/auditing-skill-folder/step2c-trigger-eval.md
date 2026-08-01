# Step 2c — Trigger accuracy eval

Externalized from SKILL.md, which is already over its 500-word budget (1016 before this step existed). Read this only when running 2c.

## What it measures, and what it does not

Step 2 reads a description and infers from regex whether it is written as a trigger. That is a proxy. Step 2c measures the thing the proxy stands in for: given a prompt a user would actually type, **does the skill fire?**

It does **not** judge whether the skill's body then did good work. Output quality is a separate rubric; conflating the two produces a number that cannot be acted on — a skill can fire perfectly and give bad advice, or never fire while its body is excellent, and those need opposite fixes.

## Why it is worth the money

Step 2b (trigger collision) is otherwise a human reading the lint table across rows and arguing about which of two descriptions owns a prompt. Here every competing skill is loaded at once and the transcript **names the winner**. The argument becomes an observation.

Baseline, 2026-08-01, collision arm, 95 skills loaded, 6 cases (3 documented routing pairs), 6/6 PASS — TP=3, TN=3, FN=0, FP=0. Each `quiet` case yielded its prompt to exactly the skill its own description names: `security-review` → `dependency-security-scan` (CI/pre-commit), `jest-best-practices` → `testing-library-react-best-practices` (RTL), `css-ui-best-practices` → `tailwind-v4-shadcn` (Tailwind tokens). Those three routing rules are measured, not asserted. Re-run after editing any description in a documented pair.

The numbers held across three measurements, but only the last one is evidence. Run 1 scored `quiet` on the first tool call alone, which cannot distinguish "the target stayed out of it" from "the target fired second" — the numbers matched, the evidence did not support the claim. Run 2 followed `skill_ever_fired`, so a passing `quiet` row means the target appears **nowhere** in the transcript. Run 3 followed the parser becoming shape-agnostic: a wider filter can only find *more* Skill calls, and finding more is exactly what would flip a passing `quiet` row to FAIL, so the baseline was re-taken rather than reasoned about. **Re-measure after any change to the scorer or the parser** — a baseline inherited across a scoring change is not a measurement.

## Running it

```
scripts/eval-triggers.sh --runner claude                  # collision arm (default): all skills loaded
scripts/eval-triggers.sh --runner claude --isolate        # each description alone, no collision pressure
scripts/eval-triggers.sh --runner claude --max-cases 5    # while iterating
scripts/eval-triggers.sh --runner mock                    # offline; canned data, NEVER an audit number
```

`--runner` has no default on purpose: one arm spends real rate-limit budget, the other returns canned data, and defaulting to either is a way to be silently wrong.

Run **both** arms when a case fails. `--isolate` PASS + collision-arm FAIL is a collision (fix the disambiguator). Failing in both is a description defect (fix the trigger wording, via `writing-great-skills`).

## Reading the output

| Signal | Meaning |
|---|---|
| `FAIL collision — won by X` | X's description claims this trigger space too. A Step 2b Collision verdict, now with evidence |
| `FAIL no skill fired` | Description never reaches the model's threshold on a prompt it should own |
| `FAIL fired when it should not` | Over-broad trigger. Costs listing budget and steals other skills' prompts |
| `SKIP user-invoked only` | `disable-model-invocation: true`. Not a miss — the frontmatter asked for this |
| `ERR ...` | **Unmeasured, not passed.** Errored cases are excluded from recall/precision |
| `TRUNCATED` | `--max-cases` cut the run. Partial coverage must not be reported as full |

## Cost and contamination, both measured

Runner flags are documented in `evals/runners.json`, which records the probe that chose each one. Three findings worth repeating here:

1. **`--setting-sources ''` is the isolation flag.** A control run without it quoted the host's own `~/.claude/CLAUDE.md` verbatim and obeyed a sentinel `CLAUDE.md` planted in cwd. Drop it and the eval measures your config, not the skill.
2. **`CLAUDE_CONFIG_DIR=<empty dir>` and `--bare` break auth on an OAuth host** (`Not logged in`). They are viable only where `ANTHROPIC_API_KEY` is set.
3. **Built-in skills stay loaded** (18 observed: `code-review`, `debug`, `verify`, `simplify`, …). A built-in winning a contested prompt is a real collision your users will hit, so it is reported, never filtered out.

One case is one full model turn against the 5-hour window. The 23-case suite is not free — budget it, or use `--max-cases`.

## Claude only, and why

There is no codex arm. Probed 2026-08-01 (codex-cli 0.146.0): codex loads a skill without emitting any event that names it — an explicit `$skill` invocation produced only `agent_message`, while the agent itself confirmed the skill was loaded. With no ground truth, a codex runner would score every case `quiet` and report a clean sheet.

Two findings from that probe are recorded in `runners.json` and matter beyond this step: upstream's `--ephemeral --ignore-user-config` does **not** isolate `~/.codex/AGENTS.md` (control group quoted `[T0-3]` verbatim), and what does work is `CODEX_HOME` at a temp dir with `auth.json` symlinked in.

So a green 2c run says the trigger holds **on Claude**. Codex reads `agents/openai.yaml` and Copilot ignores invocation policy entirely, so neither is covered by this number — do not report it as a cross-host result.

## Adding cases

`evals/cases.jsonl`, one JSON object per line: `{id, skill, prompt, expect: "fire"|"quiet", why}`.

Pair every `fire` case with the `quiet` case its own description implies. A description that says "X → other-skill" is a testable claim in both directions; asserting only the `fire` half lets an over-broad trigger score a perfect run.

`tests/trigger-eval.sh` re-validates that every `skill` named here still exists, so a renamed skill fails in CI rather than silently scoring `ERR` during an audit.

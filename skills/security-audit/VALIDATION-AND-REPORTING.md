# Validation, Reporting, and Verification

### Phase 3: Validate findings

Collect all findings from Phase 2 and **consolidate duplicates first**. Overlapping scopes can report the same issue more than once — merge findings that share a root cause before validating.

Before independent validation, the coordinator MUST prepare one complete candidate record with every confirmed-finding field from `report-schema.json`; do not invent missing report or remediation content in a later phase. Read the schema now. The candidate includes `title`, `description`, `root_cause`, `intended_behavior`, the complete source `trace`, every factual `condition`, the full `execution` (`attacker_perspective`, `payloads`, `instructions`, and `expected_result`), the proposed `remediation` including every intended `code_changes` entry, `severity`, and `confidence`. If evidence is insufficient for any substantive field, investigate it before validation or reject the candidate.

Each complete candidate needs an independent read-only validation that tries to disprove it; this task-specific security gate is distinct from a generic self-check. Use a separate `research` validator when the host supports it, or its documented independent-review fallback. If neither is available, record the gate as `UNAVAILABLE` and do not promote the candidate to confirmed.

Batch findings from the same attack surface into one validator. Apply shared INT-4 to scheduling and count; parallelize only independent, substantial validation scopes.

Each validation agent prompt should:
1. Include the complete candidate record without omitting proposed report or remediation fields.
2. Ask the agent to read the exact code paths and verify each step of the trace.
3. The validator MUST cover the trace, conditions, execution and payloads, remediation and every `code_changes` entry, severity, and confidence before confirming the record.
4. Ask it to apply these tests:

**Validation tests:**
1. **Exploitation test**: Read the actual code at each step of the trace. Does the data flow work as claimed? Can you construct the exact input (HTTP request, CLI invocation, API call, crafted file, etc.) that triggers this?
2. **Impact test**: What does the attacker actually get? If the answer is "they learn field names" or "they cause an error", that's LOW at best.
3. **Baseline test**: Does the identified comparable have the same pattern? If yes, has it been exploited? If never exploited in years of production use, understand why before reporting.
4. **Mitigation test**: Is there another layer that prevents exploitation? Check middleware, database constraints, framework defaults.
5. **Parser/runtime behavior test**: If the exploit depends on how a parser or runtime handles specific input, verify against the actual spec or implementation — do not reason from intuition.

Tell each validation agent:

```
Your job is to DISPROVE this complete candidate record. Read the actual source code at every step and test every substantive field, including the proposed remediation. Return one of:
- "CONFIRMED": the complete validated record plus field-specific evidence
- "REJECTED": which factual claim is wrong, with code evidence
- "REVISION_REQUIRED": exact field corrections and the evidence for each
```

For any substantive correction, the coordinator MUST revise from cited evidence without inventing content, then send it to a fresh independent validator as a complete record. One fresh pass is sufficient when it confirms the record; repeat only after another substantive correction. A purely structural serialization change that preserves all validated facts and remediation content can proceed without another validation pass.

**Kill false positives aggressively, but don't kill real findings.** A short report with 3 real findings is worth more than a long report with 30 theoretical ones. An honest "nothing found" is valid — but push hard before reaching that conclusion.

### Phase 4: Report

Write the report to the output directory established in Setup. Derive every finding and recommendation from its validated Phase 3 record; Phase 4 must not add a new condition, execution step, payload, impact claim, or remediation detail.

**Output files:**

1. `REPORT.md` -- Main report with:
   - One-paragraph executive summary (honest assessment of security posture)
   - Identified baseline and how this application compares
   - Findings table (severity, title, one-line description)
   - Each finding with: file path, concrete attack scenario, impact, recommended fix
   - Hardening notes section (defense-in-depth suggestions, NOT findings)
   - Positive patterns section (what the codebase does well -- this calibrates trust in the audit)

2. `FINDINGS-DETAIL.md` -- For each finding rated MEDIUM or above:
   - Complete data flow from input to sink with file:line references
   - Exact HTTP request(s) to trigger
   - What the attacker gets
   - How the baseline comparable handles the same scenario

Keep it short. If the report is longer than the codebase deserves, you're padding.

### Phase 5: Structured output, schema check, and reconciliation

Phase 5 MUST serialize each validated Phase 3 record into `findings.json` and MUST NOT add new factual claims, conditions, execution details, or remediation content. The output conforms to `report-schema.json` in this skill directory.

The schema supports two verdict types via `oneOf`:
- **`confirmed`** — a validated vulnerability with full trace, execution, and remediation
- **`rejected`** — a finding that was investigated and determined to be factually incorrect

**Before writing `findings.json`:**

1. Reuse the `report-schema.json` version loaded before Phase 3; reload it only if it is missing from context or changed. Follow it exactly — `additionalProperties: false` is enforced.
2. Copy the validated fields into the corresponding schema fields. Missing factual or remediation content is not a formatting gap: return the complete record to coordinator correction and fresh independent validation, or reject it.
3. Run `node <skill-dir>/validate-findings.cjs <output-dir>/findings.json`. It checks required fields, enum values, structural constraints, and `additionalProperties`; it does not validate facts.
4. Correct purely structural failures without changing validated meaning. Send every substantive change through fresh independent validation before rerunning the schema check.
5. Reconcile `REPORT.md` and `FINDINGS-DETAIL.md` with the final independently validated `findings.json`. Remove or amend anything rejected or corrected in Phase 3 so the human-readable and machine-readable outputs agree.

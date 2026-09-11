# Validation, Reporting, and Verification

### Phase 3: Validate findings

Collect all findings from Phase 2 and **consolidate duplicates first**. Overlapping scopes can report the same issue more than once — merge findings that share a root cause before validating.

Before independent validation, the coordinator MUST prepare one complete candidate record with every confirmed-finding field from `report-schema.json`; do not invent missing report or remediation content in a later phase. Read the schema now. The candidate includes `title`, `description`, `root_cause`, `intended_behavior`, the complete source `trace`, every factual `condition`, the full `execution` (`attacker_perspective`, `payloads`, `instructions`, and `expected_result`), the proposed `remediation` including every intended `code_changes` entry, `severity`, and `confidence`. If evidence is insufficient for any substantive field, investigate it before validation or reject the candidate.

Before either validation path runs, bind the candidate to the exact reviewed source identity defined for retained candidates below; give both the separate research validator and the fresh-context fallback that same identity together with the complete candidate. Provide access to the corresponding exact source, including the reviewed dirty diff or non-Git snapshot; either validator MUST verify the identity it actually reads before confirming. On mismatch, refresh the complete candidate and perform fresh independent validation. Each complete candidate needs an independent read-only validation that tries to disprove it; this task-specific security gate is distinct from a generic self-check. Use a separate `research` validator when the host supports it. The only fallback is a fresh-context, read-only reviewer distinct from the candidate author and coordinator: give it the exact source SHA or snapshot identity and complete candidate, require field-specific evidence for the same complete-field gate below, and record reviewer identity, mechanism, source identity, verdict, and evidence. An ordinary same-context second pass does not qualify. If neither mechanism is available, record the missing mechanism as `UNAVAILABLE` and retain the candidate as described next.

The complete field-preserving redacted record is the only record allowed to cross a source-context boundary or enter any displayed or persisted output from Phase 2 through Phase 5. This invariant covers validator prompts; returned `CONFIRMED`, `REJECTED`, and `REVISION_REQUIRED` results; and later corrections. Because a validator can read the raw source, the coordinator MUST reapply and verify the same redaction before using any validator response: serialize every schema field, replace credential values and other sensitive literals with `[REDACTED]`, and preserve non-sensitive structure, source locations, and relevant set/unset evidence without the value. Keep the redaction note for every affected field path in an existing evidence or validation-provenance surface without copying the raw literal; do not add a field that `report-schema.json` does not define. Apply and verify this record again for every Phase 4 `REPORT.md` or `FINDINGS-DETAIL.md` display or write and for Phase 5 `findings.json` before running `validate-findings.cjs`.

Before storing a retained candidate in `<output-dir>/UNCONFIRMED-CANDIDATES.md`, serialize every field with credential values and other sensitive literals replaced by `[REDACTED]`, preserve non-sensitive structure and each source location, and attach the applicable field-path redaction note to its source evidence without the raw literal. The retained candidate must include that complete redacted record, its source evidence, the `UNAVAILABLE` reason, and the missing validation mechanism, while remaining excluded from `findings.json`, the findings table, and remediation recommendations. Record the gate and retained-candidate count in the report limitations. When independent validation becomes available, resume at Phase 3 before promoting or rejecting the candidate.

A retained candidate MUST store its exact reviewed source identity: for a clean Git checkout, store the pinned commit SHA; for a dirty Git checkout, store the commit SHA plus a reviewed diff SHA (or snapshot SHA); for non-Git source, store a reviewed snapshot SHA. On resume, confirm the same source identity; when source drift is present, refresh the source evidence and revalidate the complete record. A drifted candidate MUST NOT directly promote to a finding.

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

Keep every `[REDACTED]` placeholder and its field-path evidence note in the return. When the exact source contains a credential value or other sensitive literal, report only its location and relevant set/unset state; never copy the raw literal into the response.
```

For any substantive correction, the coordinator MUST revise from cited evidence without inventing content, then send it to a fresh independent validator as a complete record. One fresh pass is sufficient when it confirms the record; repeat only after another substantive correction. A purely structural serialization change that preserves all validated facts and remediation content can proceed without another validation pass.

**Kill false positives aggressively, but don't kill real findings.** A short report with 3 real findings is worth more than a long report with 30 theoretical ones. An honest "nothing found" is valid — but push hard before reaching that conclusion.

### Phase 4: Report

Write the report to the output directory established in Setup. Derive every vulnerability finding and remediation recommendation from its redacted, validated Phase 3 record; Phase 4 must not add a new condition, execution step, payload, impact claim, or remediation detail. Immediately before displaying or writing `REPORT.md` or `FINDINGS-DETAIL.md`, reapply and verify the redaction invariant above across the complete record and its validation provenance.

Hardening notes are optional and remain outside `findings.json`. If included, each note must cite the source evidence for the missing defense layer and be labeled as a non-finding; it MUST NOT claim exploitability, attacker impact, or severity, and must not appear in the findings table. Omit the section when no note meets that evidence boundary.

**Output files:**

1. `REPORT.md` -- Main report with:
   - One-paragraph executive summary (honest assessment of security posture)
   - Identified baseline and how this application compares
   - Findings table (severity, title, one-line description)
   - Each finding with: file path, concrete attack scenario, impact, recommended fix
   - Validation provenance for every candidate: reviewer identity, validation mechanism, pinned source identity (commit SHA plus any applicable reviewed diff or snapshot SHA), verdict, and field-specific evidence; Phase 5 reconciliation MUST keep this section consistent with the final candidate records
   - Optional hardening notes section under the evidence boundary above
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
3. Reapply and verify the redaction invariant across every copied field before writing the file. `findings.json` MUST contain only the redacted record; a redaction note stays in an existing schema field or the report's validation provenance rather than adding a schema property.
4. Run `node <skill-dir>/validate-findings.cjs <output-dir>/findings.json` only after that redacted file is written. It checks required fields, enum values, structural constraints, and `additionalProperties`; it does not validate facts or detect sensitive literals.
5. Correct purely structural failures without changing validated meaning. Send every substantive change through fresh independent validation before rerunning the schema check, then reapply and verify redaction on the returned record.
6. Reconcile `REPORT.md`, including its validation provenance, and `FINDINGS-DETAIL.md` with the final redacted Phase 3 candidate records, the independently validated and redacted `findings.json`, and any retained candidates. Remove or amend anything rejected or corrected in Phase 3, reapply and verify redaction before every display or persisted write, and verify that reviewer identity, mechanism, pinned source identity, verdict, and evidence agree across their applicable outputs.

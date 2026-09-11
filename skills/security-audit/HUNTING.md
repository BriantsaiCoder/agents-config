# Vulnerability Hunting

### Phase 2: Hunt for vulnerabilities

Select attack-class and subsystem tracks from Phase 1, then apply shared `dev-workflow` INT-4. Keep small or tightly coupled hunts in the main context. Delegate only substantial independent tracks, use one `general` agent when it can cover the scope, and add another only when a distinct track materially improves coverage or wall-clock time. Hunters return deeper follow-up needs to the coordinator instead of spawning nested agents for context offload.

Each delegated track gets the relevant architecture excerpt from Phase 1 plus the hunting methodology and validation rules. Run independent tracks concurrently when INT-4 selects delegation; sequence overlapping tracks.

**How many agents?** Use the smallest useful count allowed by the runtime and any user-authored limit. Distinct attack classes do not by themselves require distinct agents; split only when the work is independently substantial.

Every delegated track prompt MUST include:
1. The relevant scoped excerpt from the Phase 1 architecture summary (copy it in verbatim)
2. The specific attack class and scope to investigate
3. Relevant file paths from Phase 1 as starting points
4. The hunting methodology (below)
5. The validation rules (below)

#### Hunting methodology — include in every Phase 2 agent prompt

Tell each agent to think like an attacker, not a code reviewer:

```
## How to hunt

Don't just check if defenses exist. Try to break them.

READ THE CODE AT DEPTH. Don't stop at the first function. Follow the data through
every layer — from the entry point through validation, transformation, storage, retrieval,
and output. Bugs live in the gaps between layers.

Think about these angles:

1. THE HAPPY PATH IS DEFENDED. ATTACK THE SAD PATH.
   Error handlers, fallback branches, catch blocks, default cases, timeout paths,
   retry logic, cleanup routines. What happens when things fail? Are errors handled
   with the same rigor as success? Does a failed validation leave state half-modified?

2. WHAT HAPPENS AT BOUNDARIES?
   Empty input. Maximum-length input. Null vs undefined vs missing. Zero. Negative numbers.
   Unicode edge cases. The first item and the last item. One more than the maximum. Exactly
   at the rate limit. The moment a token expires.

3. WHAT DO COMPONENTS ASSUME ABOUT EACH OTHER?
   Does the database layer assume the API layer validated input? Does the renderer assume
   content was sanitized on write? Does the auth middleware assume routes register themselves
   correctly? Find where trust is implicit and test whether it's justified.

4. WHAT IF OPERATIONS HAPPEN IN THE WRONG ORDER?
   Call step 3 before step 1. Call delete during create. Send the callback before the request.
   Hit the confirmation endpoint without starting the flow. Replay a completed flow.

5. WHAT IF TWO THINGS HAPPEN AT ONCE?
   Two requests to the same resource. Modify while reading. Delete while iterating.
   Publish while someone else is editing. Two users claiming the same unique resource.

6. WHERE DO TWO PARSERS OR VALIDATORS DISAGREE?
   Input accepted by the schema but rejected by the database. URL parsed differently by
   the router vs the application code. Content-type header says one thing, body is another.
   Filename extension vs MIME type vs magic bytes.

7. WHAT SURVIVES A ROUND TRIP?
   Data stored then retrieved — is it the same? Does encoding change? Does escaping
   double-up? Is a relative path resolved differently on read vs write? Does serialization
   lose type information?

8. WHAT DOES THE CONFIGURATION CONTROL?
   What happens when config is missing or default? Can an environment variable override a
   security control? Does a feature flag disable validation? What's the security posture
   during setup/first-run before config is complete?

9. FOLLOW THE MONEY (OR THE PRIVILEGE).
   For every operation that changes state, ask: who authorized this? Trace back to the
   permission check. Is it checking the right permission? Is it checking against the right
   resource? Is there a parallel path to the same state change that checks differently
   or not at all?

10. LOOK FOR LEAKED CONTEXT.
    Error messages that reveal internal paths. Stack traces in production. Timing differences
    that reveal whether a record exists. Response size differences. HTTP headers that
    disclose versions. Debug endpoints that survived into production.

If a subsystem needs deeper investigation, return the exact gap and relevant paths to the
coordinator. The coordinator decides whether to investigate directly or delegate a new,
independent track under shared INT-4.

11. WHAT PARAMETERS OVERRIDE SECURITY-RELEVANT DEFAULTS?
    Where a default is safe but a user-supplied parameter can change it. Look for
    every input that overrides a security-relevant default and check if the override
    is gated by appropriate permissions.

12. WHERE DO UNVERIFIED CLAIMS DRIVE TRUST DECISIONS?
    Anywhere self-declared identity, capability, or metadata influences an access
    or trust decision without independent verification.

YOUR SCOPE IS YOUR PRIMARY FOCUS, NOT A BOUNDARY.
If while investigating your assigned area you notice something wrong in a different
category — a permission issue while tracing injection, a race condition while reviewing
auth — report it. Don't ignore a bug because it's "not your area." Attackers don't
respect category boundaries.

## Validation rules — apply before reporting ANY finding
1. You MUST construct a concrete attack (exact inputs, requests, or action sequence)
2. The attack MUST achieve meaningful impact (not just "learn field names" or "cause an error")
3. Check if another layer already prevents exploitation — if so, it's a hardening note, not a finding
4. If the baseline comparable has the same pattern, note whether it's been exploited there
5. If your exploit depends on parser/runtime behavior, verify against the relevant spec or implementation — do not reason from intuition.
6. For every surviving finding, return one candidate packet with every substantive confirmed-finding field from `report-schema.json`: `title`, `description`, `root_cause`, `intended_behavior`, the complete `trace` and `conditions`, the full `execution` (`attacker_perspective`, `payloads`, `instructions`, and `expected_result`), the proposed `remediation` including every intended `code_changes` entry, `severity`, and `confidence`; otherwise return "No exploitable vulnerabilities found" if that's honest. Phase 3 owns independent confirmation of the complete record.
```

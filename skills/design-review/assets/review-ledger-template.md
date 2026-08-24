# Review Issue Log

> **Memory across sessions. Read this file first, every round.** A `REJECTED_*` / `DEFERRED` / `ACCEPTED_RISK` entry **stays closed** unless its `reopen_condition` is met.
> Severity P0–P3. `status ∈ {ACCEPTED_BLOCKING, ACCEPTED_NON_BLOCKING, DEFERRED, ACCEPTED_RISK, DUPLICATE, REJECTED_OUT_OF_SCOPE, REJECTED_UNSUPPORTED, CLOSED}` (CLOSED = the fix landed, or the reopen condition came true and was handled).
> On close, add `resolution` (which document and section changed) and keep `previous_status`; Git holds the closed history.
> This log is a working file for the review period. At release, migrate the still-open entries into **the target repository's known-issues file** (its path follows that repository's own documentation convention) and delete this one — Git keeps the history. See "Issue log lifecycle" in the design-review SKILL.

## Frozen inputs (updated each round)

- Requirements version: `<full PRD commit / the prd.md version of the created task>`
- Design version: `design v0.1` / `plan v0.1`
- Engineering baseline: `<starter / repository baseline / commit>`
- Reviewer set: `<track-specific reviewer path>`
- In scope: `<all / slices B1–B2>`
- Out of scope: `<multi-region / offline / SSO / ...>`
- Rounds:
  - R1 @`<YYYY-MM-DD>`: found P0×_ P1×_ P2×_ P3×_; adjudication `<summary>`
  - R2 @`<YYYY-MM-DD>`: new Accepted P0/P1 = _ (0 → the stopping rule holds)

---

## Accepted · in progress / to do

```yaml
- id: FINDING-001
  category: authorization             # authorization/concurrency/data-model/coverage/contract/...
  severity: P0                        # P0/P1/P2
  evidence: "Design §3.2 does not define write authorization for the protected resource"
  trigger: "A caller submits a resource id it does not own"
  impact: "Another subject's data can be modified"
  affected_requirement: "<task prd.md section / slice table row>"
  blocking_reason: "Breaks the authorization boundary"
  status: ACCEPTED_BLOCKING
  resolution: ""                      # on close: which document, which section changed
  reopen_condition: ""
```

## Deferred / rejected / risk accepted (not re-raised from here on, unless the reopen condition is met)

```yaml
- id: FINDING-008
  category: scalability
  severity: P3
  evidence: "The design does not describe conflict resolution for multi-region deployment"
  trigger: "Not reachable in the current single-region scope"
  impact: "No impact within the current scope"
  affected_requirement: "Out of scope: multi-region deployment"
  blocking_reason: "Does not block: requirements exclude it explicitly"
  status: REJECTED_OUT_OF_SCOPE
  reason: "Single-region deployment today, no multi-region requirement"
  reopen_condition: "Requirements add cross-region failover"

- id: FINDING-012
  category: concurrency
  severity: P2
  evidence: "The lock implementation for concurrency control is not specified"
  trigger: "Reached when the slice is coded and a concrete concurrency approach is chosen"
  impact: "Correctness cannot be proven on paper at design time"
  affected_requirement: "The concurrency invariant in the design"
  blocking_reason: "Does not block: a coding and testing detail"
  status: DEFERRED
  reason: "Implementation-level; decided at coding time and proven by a concurrency test (deferred by altitude)"
  reopen_condition: "Slice implementation shows the business invariant can be broken by concurrency"
```

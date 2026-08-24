# Review Convergence Discipline (authoritative)

> **This file treats one disease**: reviewing the same artifact across sessions and agents, every pass turning up fresh opinions, the fix list growing rather than shrinking, no way to say when it is done — **runaway auditing**.
>
> It is the authoritative statement of the review protocol. `SKILL.md` carries a summary; on a conflict this file wins.
>
> **Why the protocol lives inside the skill**: a skill is symlinked into `~/.claude/skills/`, where this repository's `specs/` cannot be reached. A skill that points across directories arrives there missing its core rules, and the review degrades into whatever the model fills in.
>
> Two rules every session needs are deliberately elsewhere — the four-field finding recorded while coding, and lightweight convergence during requirements discovery. They live in `specs/universal/guides/review-adjudication.md`, injected by Trellis. Different subjects, not two copies of one text.

## Why open-ended review diverges

Different sessions sample different implicit assumptions, so **something new always turns up**. That is not the design getting worse; the activity simply has no end state.

The cost is not only time. It destroys your ability to say when building can start, and both available endings — never starting, or skipping review — are worse than a bounded review. So the target is not "no problems remain":

> **Converge on "no new, well-evidenced blocking problems".**

## The ten disciplines

1. **Freeze the input set.** Fix, before each round: requirements version, load-bearing decisions version, engineering baseline version, in scope, out of scope, the log's path. **Enter no review before this is frozen** — a review whose scope can drift will diverge.
2. **Keep an issue log.** Ten fields per entry: `id / category / evidence / trigger / impact / affected_requirement / severity / blocking_reason / status / reopen_condition`, with `status ∈ {ACCEPTED_BLOCKING, ACCEPTED_NON_BLOCKING, DEFERRED, DUPLICATE, REJECTED_OUT_OF_SCOPE, REJECTED_UNSUPPORTED, ACCEPTED_RISK, CLOSED}`. The log is **memory across sessions**; without it every new session starts from zero, so commit it.
3. **Read before reviewing.** Read the whole log first. A `REJECTED_*`, `DEFERRED` or `ACCEPTED_RISK` entry whose `reopen_condition` is unmet **stays closed**; only a diff against the log proves an entry is new.
4. **Hold the evidence threshold.** A finding without a locatable design basis, a trigger, a consequence and an affected requirement **cannot block**, and caps at P3. "There might be a scalability problem" is not a finding.
5. **Gate on severity.** P0–P3 below. Clear every P0 before coding; give every P1 an explicit disposition — fix, defer with a `reopen_condition`, or accept the risk with the reason recorded. No choice means no disposition.
6. **Reporting is not deciding.** A reviewer **reports** against a fixed checklist; the main agent or a human adjudicator merges, de-duplicates, re-verifies and **decides**. **Never fix the union of several reviewers' findings**, and never settle true-versus-false by majority vote. Budget an AI reviewer's false-positive rate at around one in three, and re-open the source text for every blocking finding.
7. **Escalate within bounds.** One agent and two rounds by default. Escalate to independent reviewers only for authorization, data migration, irreversible operations, money, or cross-system consistency. After escalating, three things hold unchanged: the two-round budget, the evidence threshold, and **exactly one adjudication point**. More reviewers buy recall and nothing else.
8. **Stop on the rule, not on exhaustion.** Two rounds of pure design review, maximum; **re-verifying a fix does not spend one**. Build when **three** things hold: Accepted P0 is empty, every Accepted P1 has a disposition, and at least one vertical slice is implementable. A full round producing **no new Accepted P0/P1** is the converged exit and the better one — but it is **not a fourth condition**: a P1 first raised in the last round is closed by its disposition, not by another round, and treating it as a gate is how a bounded review becomes an unbounded one. Name the exit in the report. Past the budget, route feedback into slice implementation and tests — cheaper feedback, and truer.
9. **Hold the altitude.** Design locks data ownership, permission and trust boundaries, the shape of the key models, module and slice boundaries, long-term contracts, consistency requirements, and the migration and deletion strategy. Everything below that line goes to coding time; the worked comparison is the altitude table in [`reviewer-checklist.md`](reviewer-checklist.md). The inverse earns a real P0/P1: a load-bearing decision missing or vague.
10. **Converge at release.** Open risks and deferred items move, with their `reopen_condition`, into the target repository's known-issues file; Git keeps the history of what was closed and rejected; the log is deleted or archived on that repository's documentation lifecycle.

## Status values

Discipline 2's enum, with what each one means. Pick from these and nothing else — a log whose statuses drift is memory that drifts.

| status | Meaning |
|---|---|
| `ACCEPTED_BLOCKING` | P0/P1, blocks building |
| `ACCEPTED_NON_BLOCKING` | P2, goes to the backlog. **This, not `DEFERRED`, is where an accepted P2 lands** — `DEFERRED` is for a decision postponed, not for work queued |
| `DEFERRED` | The decision itself is postponed. **Requires an objective `reopen_condition`** |
| `ACCEPTED_RISK` | Knowingly accepted; record the reason |
| `DUPLICATE` | Same as an existing id |
| `REJECTED_OUT_OF_SCOPE` | Outside the scope frozen in Step 0 |
| `REJECTED_UNSUPPORTED` | No evidence, or no path that triggers it |
| `CLOSED` | The fix landed, or the reopen condition came true and was handled. Record `resolution` — which document or which piece of implementation did it |

**A `reopen_condition` has to be decidable.** "Requirements add cross-region failover" and "a measured run shows concurrency can break the business invariant" both work; "revisit later" does not. Discipline 3 keeps a deferred entry closed until its condition is met, so **an undecidable condition is a permanent close wearing a postponement's clothes** — which is the exact failure the log exists to prevent.

## Severity

| Level | Definition | Disposition |
|---|---|---|
| **P0** | A security hole, data corruption, or a core approach that cannot work | Clear before coding |
| **P1** | A main-path error, or large-scale rework | Must have an explicit disposition |
| **P2** | A local defect a refactor can fix | Backlog |
| **P3** | Style, preference, or theoretical extensibility with no evidence | Does not block |

## Evidence format

Every finding carries at least **eight fields**. Missing any of `evidence`, `trigger` or `impact`, it cannot block.

```yaml
id: FINDING-012
category: concurrency
severity: P1
evidence: "Design §3.3 counts active rows, then inserts"   # a locatable position in the source
trigger: "Two tabs act on the same object at once"
impact: "The concurrency quota can be exceeded; the action can run twice"
affected_requirement: "requirement id or section"
blocking_reason: "Breaks core data correctness"            # if it does not block, write the why-not
```

> **Two field sets — do not conflate them.** These **eight** are the minimum a finding must state. Discipline 2's **ten** are those plus `status` and `reopen_condition`, which only exist after adjudication. Wherever this framework contrasts the heavy format against the lightweight four-field one, it means the eight: the two lightweight occasions never reach adjudication.

## Where the eight fields do not apply

A finding recorded **while coding**, and convergence **during requirements discovery**, both use four fields. Their rules live in `specs/universal/guides/review-adjudication.md`.

The reason is **altitude**: the eight fields demand a locatable design basis, a trigger and the affected requirements, while those two occasions produce "when I ran it I hit X" and "this step is convoluted". Demand a case file for every hands-on observation and you get either nothing recorded, or an AI inventing evidence to fill the shape — both worse than having no format.

> **Question rounds are not bounded here — do not add a rule for them.** Trellis's `trellis-brainstorm` enforces one question per message during planning, and a second cap on batched questions would work against it. What is bounded is walkthrough rounds and option selection.

## Common misuses

| Misuse | Why it is wrong |
|---|---|
| Fixing the union of several reviewers' findings | Recall is not adjudication. Fixing everything lets false positives drive the design |
| Settling whether a finding is real by majority vote | Three reviewers making the same mistake is common — they read the same text |
| Re-reviewing from scratch in each new session | No log read means no memory across sessions, the standard opening move of runaway auditing |
| Reporting an implementation detail as P0 | Locking, retries and algorithms belong to coding time. A real P0 is a missing load-bearing decision |
| Refusing to start because problems can still be found | Problems can always be found. The test is whether a **new, well-evidenced** blocking problem exists |
| Applying the eight fields during requirements or coding | See the section above |

## Two questions this raises

**A different agent still produces new opinions — has the mechanism failed?** No. It controls which new opinions are **strong enough to block**, not whether they appear. They will; the question is whether they clear the evidence threshold.

**When is a full redesign warranted?** Only when requirements change or implementation evidence falsifies a load-bearing assumption. **A fresh batch of preference-level opinions is not a reason to restart** — that is runaway auditing relapsing.

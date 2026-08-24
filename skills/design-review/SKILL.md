---
name: design-review
description: A bounded admission review that answers whether building can safely start.
disable-model-invocation: true
---

# Design-Admission Review

A **convergent admission review** of load-bearing decisions and the slice plan. It answers "can building start at an acceptable risk", not "is the design free of problems".

> **The discipline itself is not in this file.** The authoritative source is [`references/review-adjudication.md`](references/review-adjudication.md) — ten disciplines, severity, evidence format. **This file defines when to trigger, in what order to operate, and which templates to use.** Change the discipline there, not here.
>
> Keeping the protocol inside the skill is deliberate: this skill is symlinked into `~/.claude/skills/`, where the repository's `specs/` cannot be reached. **A skill has to be self-contained.**

## When to use it

> **This section is the authoritative source for the trigger conditions.** The manual and the checkpoint point here — a second, shorter list elsewhere will eventually miss a case.

Four occasions; any one is worth calling it:

| # | When | The test |
|---|---|---|
| 1 | **Load-bearing decisions just settled, before the first tasks exist** | Data ownership, permission and trust boundaries, module boundaries, long-term contracts — decisions expensive to change earn one round before building starts |
| 2 | **You are already stuck in "the review never ends"** | Several sessions or agents have reviewed the same artifact, the fix list keeps growing, and you cannot say when it would be done |
| 3 | **A checkpoint shows a load-bearing decision has stopped holding** | The test: would fixing it mean changing **several slices already finished**? The signal is two consecutive slices working around the same thing — a load-bearing problem, not two badly built slices. Recording a finding will not resolve it |
| 4 | **After a high-risk scope change** | Authorization, data migration, irreversible operations, money |

Case 2 is what it is really for: **it treats not being able to stop, not reviewing too shallowly.**

**How it fires**: you type it. Nothing in the slice-by-slice flow invokes it, which is why it carries `disable-model-invocation: true` — an escape hatch is pulled by a person.

**When not to use it:**

- Requirements have not converged. That belongs to the full PRD and the prototype walkthrough; this skill does not review requirements.
- Implementation correctness of one task. That belongs to Trellis's check phase and to code review.
- **A "this rule is wrong" found while coding** — that goes to a four-field finding, not a review. See `specs/universal/guides/review-adjudication.md`.

Most slices need no admission review at all: Trellis's planning-summary gate is enough. Outside the four occasions above, do not open one.

## What the caller supplies

This skill is the **track-independent convergence mechanism**. [`references/reviewer-checklist.md`](references/reviewer-checklist.md) holds the entire check surface — both rounds' checks, the altitude table, and the output format. **Read it before Step 1**, with or without an overlay; the steps below name each round's scope but not what to look for.

What a **track overlay** adds on top is that track's hard constraints — its data isolation mechanism, data-access paths, credential boundaries, build and migration conventions. It comes from the target repository. Running without one is fine; say so in the report, so the reader knows the coverage was generic. **Keep any one track's hard constraints out of this repository** — that is drift.

Paths follow the target repository's conventions: slice order is the slice table in `docs/discovery/slices.md`, and load-bearing decisions live wherever that repository puts them. **Trellis's `.trellis/spec/` holds coding rules only** — not load-bearing decisions, so do not look there.

**The requirements basis depends on which occasion fired.** Occasion 1 runs before the first task exists, so there is no task `prd.md` yet — the basis is the full PRD. The checklist's input section carries the split; assemble the inputs from there rather than asking for a file the stage has not produced.

## The protocol

### Step 0 · Freeze the inputs, then read or create the log

Record: requirements version, load-bearing decisions version, engineering baseline version, in scope, out of scope, the reviewer set for this round, the log's path.

Read the existing log first; where there is none, create one from [`assets/review-ledger-template.md`](assets/review-ledger-template.md).

**Enter no review before the inputs are frozen and the log is read or created** — a hard checkpoint, not advice. (In this framework "gate" is reserved for Trellis's planning-summary approval, the one thing that can stop `task.py start`. This step stops entry into the review.)

### Step 1 · Round 1, structure

Work Round 1 of [`references/reviewer-checklist.md`](references/reviewer-checklist.md): requirement coverage, module responsibilities, data and state flow, contract consistency, slice independence, repository constraints, obvious architectural contradictions. **Keep it from expanding into a general "full review".**

### Step 2 · Round 2, failure modes and data risk

Work Round 2 of the same checklist — what would block implementation: transactions, idempotency, concurrency, consistency, data corruption, migration and deletion, an unavailable external dependency, identity and permissions, credential boundaries, recovery paths.

**Dispatching a subagent for either round means handing it three things**: `references/reviewer-checklist.md`, `references/review-adjudication.md` (the checklist points at it for severity and the eight-field format, and a subagent cannot follow that pointer for itself), and the track overlay if there is one. Hand over one file and the subagent invents the missing half — the same failure this skill avoids by keeping its protocol out of `specs/`, one level down.

### Step 3 · Merge, de-duplicate, adjudicate

Merge and de-duplicate what the rounds or reviewers produced. The main agent **re-opens the source text to verify each finding** before writing it into the log with a `status`. Adjudication happens in exactly one place — discipline 6 and 7 govern.

### Step 4 · Decide whether to stop

All five, and admission is granted:

1. Every Accepted P0 is closed.
2. Every Accepted P1 is closed or has an explicit disposition.
3. **One full round has produced no new Accepted P0/P1.**
4. New findings are only P2/P3, duplicates, unevidenced, or out of scope.
5. At least one vertical slice can be implemented and verified end to end.

**Two rounds of pure design review, maximum.** The budget counts **rounds of the checklist**: Round 1 and Round 2 are the two, and **re-verifying a fix does not spend a round** — adjudicating a finding you already accepted is Step 3, not a new review.

**What condition 3 means against a two-round budget.** The two rounds check different surfaces, so a P1 first raised in Round 2 leaves condition 3 unmet with the budget spent. That is the expected ending, not a failure — and it does **not** withhold admission:

- **Every P0 still blocks.** Fix it, re-verify, and if the fix itself raises a new P0, that is the one case worth a further pass — say so explicitly in the report.
- **A P1 the budget did not clear is closed by disposition, not by another round.** Record it as `ACCEPTED_RISK` or `DEFERRED` with a `reopen_condition`, name who carries it, and grant admission. Condition 2 is satisfied by an explicit disposition; condition 3 describes the ideal exit, not a gate.
- **Say in the report which of the two exits this was** — converged, or budget-exhausted with N dispositions. A reader deciding whether to build needs to know which one they are being handed.

Past the budget, route remaining feedback into slice implementation and tests, where the evidence is cheaper and more direct. **Opening a third round is the failure this skill exists to prevent**, and "the last round found something" is exactly the argument that makes a review never end.

## Output

An admission report in the conversation, following [`assets/review-report-template.md`](assets/review-report-template.md). **That template is in Chinese**, because the report is conversational output for the person deciding whether to build — unlike the reviewer's own output format, which is machine-facing and English.

Then update the log with every finding's final status and `reopen_condition`.

## Constraints

- Treat an open technical choice as a choice, not a problem.
- Leave an adjudicated item closed while its `reopen_condition` is unmet.
- Make every finding something the main agent can re-verify by opening the source.

## Issue log lifecycle

The log is a working file for the review period. At release, open `ACCEPTED_RISK` / `DEFERRED` / backlog entries move, with their `reopen_condition`, into the target repository's known-issues file; Git keeps the closed and rejected history; the log is deleted or archived on that repository's documentation lifecycle. Create a fresh one when the next large iteration needs admission.

## Files

| File | Purpose |
|---|---|
| [`references/review-adjudication.md`](references/review-adjudication.md) | **The authoritative discipline** — ten disciplines, severity, evidence format, misuses |
| [`references/reviewer-checklist.md`](references/reviewer-checklist.md) | Track-independent reviewer skeleton, altitude table, output format |
| [`assets/review-report-template.md`](assets/review-report-template.md) | The admission report template. **Chinese** — it produces conversational output for a person |
| [`assets/review-ledger-template.md`](assets/review-ledger-template.md) | The issue log template |

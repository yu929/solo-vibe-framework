# Reporting Is Not Deciding

> **One principle, two occasions.**
>
> The principle: **whoever finds something does not also get to decide it.** The AI reports — what it observed. The human decides — which observations are worth becoming long-term rules, and what should change. Let the finder also decide, and untested conclusions will fill the spec within weeks.
>
> This file covers the two occasions you hit **every day**: findings during coding, and converging during requirements discovery.
>
> **The formal design-admission review** — ten disciplines, P0–P3, the eight-field evidence format, stopping rules — is not here. It lives in the `design-review` skill's own `references/review-adjudication.md` and loads only when a review is triggered. The two cover different things; they are not two copies of one text.

## 1. Findings during coding

While coding and debugging, an AI turns up a particular kind of observation: "this rule is actually wrong", "there is a trap here the spec never mentioned".

**The rule: record a finding first, promote it into the spec only after confirmation. An AI never edits the spec directly.**

Trellis's `trellis-update-spec` promotes this task's lessons into `.trellis/spec/` during Phase 3 — that step is **the promotion**, and it assumes the lesson has already been confirmed by you. Skip the confirmation and write straight through, and the spec becomes a pile of provisional conclusions nobody verified.

**Four fields, no more:**

```markdown
## F-<date>-<number>: <one line>

- **Observed**: what you saw (not what you concluded)
- **Evidence**: how to reproduce it / where you saw it
- **Which spec should change**: the specific file; write "undecided" when you do not know
- **Status**: open / promoted into the spec / rejected (with the reason)
```

**Why only four fields.** These observations have the shape "while running it I found X", not "design doc §3.3 specifies Y, which causes Z". Imposing the eight-field format used for design admission would demand a case file for every hands-on observation — which leads either to nobody recording anything, or to an AI inventing evidence to fill the shape.

**The test — is it worth recording?** Would another session hit the same thing again *because the spec does not say so*? If yes, record it. **Most bugs do not need recording**: a bug means the code failed to meet a rule that already exists; the rule itself has not changed.

**Where findings live**: in the project's own `findings/` directory or its known-issues file, following that repository's conventions.

**Where a lesson gets promoted to depends on how far it applies.** Classify first, then decide when:

| The test: would this still hold on a different project on the same track? | Promote to | When |
|---|---|---|
| Yes | The spec's **source of truth** — when the spec was installed from a registry, that is the template's source repository, not the installed copy inside the project | **In a batch, at the end of a phase** — not per task |
| No, but later tasks in this project will still need it | This project's own `.trellis/spec/`, in the matching layer | Right away |
| No, and it was a one-off | Leave it in `findings/`, status `open` | Right away |

**Ask the test as written; do not swap it for "will this be reused across tasks".** Cross-task reuse only shows the lesson belongs in a spec — it does not show it belongs in the source of truth, which is the second row. The test asks whether it **still holds on a different project**.

**Why the first row waits until the end of a phase.** A lesson that has been through exactly one situation gives you no way to tell whether it is general or specific to that one time. Writing back one at a time is the finder also deciding — the thing this file opens by ruling out. Collect them to the end of a phase and look at them together; with several side by side, you can finally tell which are one pattern and which merely coincided.

**Inside a task, a first-row finding is recorded in `findings/` and stops there.** Do not touch the source of truth. `trellis-update-spec` does not know whether a spec was installed from somewhere — it only writes the project's `.trellis/spec/`. Carrying a lesson back to the template's source repository and reinstalling it is **an end-of-phase operation**, never an in-task one.

**Writing a second-row lesson into `.trellis/spec/` is acceptable**, even though that directory holds registry-installed files: `trellis update` handles locally modified files with a per-file "Modified by you" confirmation, so nothing is silently overwritten. A rule that only holds for this project never belonged in the source of truth anyway.

Once promoted, set the finding's status to promoted and leave a link to the spec rule.

### Before proposing a compatibility path, confirm something needs it

Before keeping an old field, an old enum value, an old endpoint or a compatibility branch, there must be at least one real thing to be compatible **with**: released data that needs migrating, an external caller still in use, or an explicitly promised backward-compatibility boundary. Local development data, an unreleased implementation, or old code in the current working tree **are not compatibility commitments**.

If the project is still unreleased and none of those exist, delete the obsolete contract and implementation outright; clean up development data with a forward migration if you have to. Do not keep read branches, deprecated endpoints or old enum values for a history that never happened. When it is unclear whether anything needs the compatibility, record it as a finding awaiting a decision rather than letting the AI assume.

## 2. Lightweight convergence during requirements discovery

Writing a PRD, walking through a prototype, choosing between slicing options — all of these use the lightweight version:

| Item | Rule |
|---|---|
| Walkthroughs | Two rounds at most. After the second, a disagreement is recorded as "pending" or "moved to a later slice" |
| Options | Two or three, and they must be structurally distinct; **one sign-off**, with anything worth keeping from the losing options folded into the decision on the spot |
| Issue records | Four fields only — observed / decision / action / where it lands — where decision ∈ {change the PRD, change the prototype, move to a later slice, pending} |
| Slice-size alarm | When one slice maps to more than six screens or interaction sequences, raise "is this slice too big?"; record the conclusion, **do not block on it** |

**The absence of a "question rounds" row is deliberate.** Trellis's `trellis-brainstorm` enforces "one question per message" during planning, and a second cap on batched questions would only work against it. **Do not add question rounds back to this table** — what is bounded here is walkthroughs and option selection, not questioning.

**Convergence pressure goes on rounds and sign-off, never on coverage.** Runaway auditing looks like reviewing the same artifact over and over, unable to stop; **walking through everything that was declared is not runaway auditing**. What actually runs away is oscillating between options, so the discipline lands on the choosing.

The coverage rule is separate, and points the other way: the approved prototype must cover every screen **or interaction sequence** the PRD declares — it is the structural basis for implementation, and covering less than the implementation hands the gap to the AI to fill freely. The two do not conflict: one bounds rounds, the other fixes scope.

## 3. When to escalate to the full review protocol

Signals that the two sections above are not enough and `design-review` is needed:

- the question is "can we safely start building", not merely "is this worth recording"
- the review has run more than two rounds and new issues keep appearing
- a new session produced another batch of opinions
- findings from several reviewers need merging and de-duplicating

Use the `design-review` skill then. It brings frozen inputs, an issue log, an evidence threshold and stopping rules. **Do not restate any of that here** — it is much heavier, and applying it to everyday work adds exactly the audit burden that discipline exists to cure.

# Standing Decisions

Choices already made here, with the reason that makes each one stick. A rule without its reason gets re-derived away, and every one of these has been re-derived away at least once.

## No approval fields

Nothing under `docs/discovery/` — not the complete PRD, not `slices.md` — carries frontmatter, an `approved` field or a status bit.

The reason is mechanical: **nothing reads them.** This repository ships no workflow; Trellis's `--registry` installs specs only; and the workflow-state hook is parser-only, *"reads whatever you put in the block"*. A gate in this flow can therefore only ever be a suggestion, never an adjudication. A status bit nobody reads is a second, permanently stale account of reality.

**The one real gate on this path is the one Trellis already has**: `trellis-brainstorm` forbids `task.py start` without the user's explicit approval of the planning summary. Hang anything that must happen before work starts there.

Say **checkpoint** rather than gate everywhere except when naming Trellis's.

Three fields once existed here — `brief_approved`, `prototype_required`, `prototype_approved` — along with a set of invalidation rules. They produced two real defects: a shortcut that allowed re-approval without updating the prototype, and a rule that unconditionally exempted "technical constraints affecting interaction" from invalidation. **Deleting the fields removed both.** Do not add them back, and do not add an equivalent one to the complete PRD under another name.

## Requirements in full, implementation slice by slice

The split is deliberate, because doing each one all at once costs entirely different things:

| | Cost of doing it all at once | Verdict |
|---|---|---|
| Complete PRD + full hi-fi | One slower round up front — but that round has to happen anyway, since slicing needs something converged to cut | All at once |
| Implementation | Months with nothing verifiable | Slice by slice |

The invariant **prototype coverage ≥ implementation coverage** then holds automatically: the full set is ≥ any one slice of it. It needs no "current slice" qualifier; that phrasing belongs to the older flow.

**One precondition carries this whole arrangement:**

> **The PRD must already be converged to field level before the hi-fi is finalized.**

Drawing the full hi-fi first otherwise means guessing the structure of requirements nobody has converged yet — and a guess drawn at high fidelity is treated as settled, so every later slice is built against it. Two PRD-phase steps prevent that: **a throwaway prototype to test the fields** (the LOGIC branch of `prototype`, pushing the state machine through cases that cannot be reasoned about on paper) and **writing the result back into the PRD**. Skip or rush either one and the hi-fi is guessing, with nothing to tell you.

Two things still have to be handled by hand:

1. **This slice's finalized screens must be listed in `implement.jsonl`.** An implementation sub-agent in a fresh context sees only the files that file names; a path written into `prd.md` does not reach it. This has actually happened. The landing place is the fourth column of the `slices.md` slice table, and `vertical-slicing` lists it as a required step. **List only this slice's screens** — the full set overflows the sub-agent.
2. **Look back every three to five slices.** A finalized hi-fi guarantees structural agreement, not that the implementation stayed with it.

Missing the first has no symptom at all: the result is structurally wrong and reads like carelessness. Missing the second surfaces a dozen slices later.

## Review discipline lives at two altitudes

Split by reader, not as two copies of one text:

| Where | Covers | Read by |
|---|---|---|
| [`../specs/universal/guides/review-adjudication.md`](../specs/universal/guides/review-adjudication.md) | The four-field finding while coding; lightweight convergence during requirements discovery | Every session, injected by Trellis |
| `skills/design-review/references/review-adjudication.md` | The full protocol: ten disciplines, P0–P3, the eight-field evidence format, stopping rules | Only when a review is triggered |

**The protocol text has to live inside the skill.** A skill is symlinked or copied into `~/.claude/skills/`, where this repository's `specs/` cannot be reached.

When changing the discipline, decide which altitude it belongs to, change that one, then check whether `design-review/SKILL.md`'s summary still holds.

### Requirements discovery uses lightweight convergence

The full issue log serves design admission and everything after it. During requirements discovery:

| Item | Rule |
|---|---|
| Walkthroughs | At most two rounds. After the second, a disagreement is recorded as "to confirm" or "moved to a later slice" |
| Options | Two or three, with real structural difference; **decided once**, and the useful parts of the losing options merge into the decision on the spot |
| Issue record | Four fields only — observation, judgment, action, landing place — with judgment ∈ {change the PRD, change the prototype, move to a later slice, to confirm} |
| Slice size warning | More than six screens or interaction sequences in one slice prompts "is this slice too big?"; the answer is recorded and **does not block** |

Two reasons this is not the heavy format:

1. **The eight-field evidence format is a much heavier instrument** (the full log adds `status` and `reopen_condition` on top, for ten). It asks for a locatable design basis, a trigger condition and the affected requirements; what a walkthrough produces is "this step is convoluted" and "when it failed I didn't know what to do". Demanding a case file for every hands-on reaction produces either nothing recorded, or invented evidence.
2. **Convergence pressure belongs on rounds and on deciding, not on coverage.** The finalized prototype must cover everything the PRD declares — it is the structural basis for implementation, so covering less than the implementation hands the gap to the AI. What actually runs away is oscillating between options, so the discipline sits there.

**Question cadence is not this repository's to set.** Trellis's `trellis-brainstorm` enforces one question per message and is mandatory during planning; a competing "batch it into two rounds" rule here would only fight it. Where the two disciplines collide — one question at a time vs. `grilling`'s ask-the-whole-frontier — Trellis wins.

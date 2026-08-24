---
name: vertical-slicing
description: Cut a converged PRD into deliverable vertical slices and write docs/discovery/slices.md.
disable-model-invocation: true
---

# Vertical Slicing

Cut the full PRD into a series of slices that can be delivered one at a time, and write them into `docs/discovery/slices.md`.

## Why this step exists

Trellis owns a task's lifecycle but explicitly does not own order — its own words are *"Parent/child structure is not a dependency system"*. A parent/child tree expresses no dependency, so "which slice comes first, and which one is waiting on what" has no host. `slices.md` is that host.

Slicing is not about dividing up effort. It is about **delivering a complete, verifiable path over and over**. Cut horizontally — all the tables, then all the endpoints, then all the pages — and no layer verifies anything when it finishes; the misunderstanding surfaces at the last one. Cut vertically and every slice ends with something a user can actually do.

## When to use it

It runs outside any task, as the last step before Trellis:

```
Full PRD → verify fields → hi-fi approved
  → [HERE] slice + blocking edges → docs/discovery/slices.md
  ─────── one round per slice from here ───────
  → task.py create → brainstorm writes prd/design/implement
  → you approve the planning summary (Trellis's own gate) → task.py start
```

Check the inputs first, in order, stopping at the first match:

| Situation | What to do |
|---|---|
| No full PRD | Stop. Slicing reorganizes **converged requirements**; without the PRD what comes out is guesswork |
| There is UI, but the hi-fi is not approved | Stop. Produce only a rough draft from what the PRD shows, and say it cannot enter `slices.md` yet — a list whose fourth column is empty means an implementation sub-agent improvising |
| `slices.md` exists and one slice is being added | Skip to "Settle it with the user"; do the increment only, and leave the rest of the table alone |
| None of the above | Continue |

## What to read

- **The full PRD**: the feature list, what is explicitly excluded, the acceptance criteria.
- **The approved hi-fi**: enumerate every screen and interaction sequence — the fourth column comes from here.
- **`CONTEXT.md`** (the glossary, where there is one): use its words, and coin no synonyms.
- **`docs/adr/`** (where there is one): load-bearing decisions constrain how you can cut. "Monolith first, split into services later" directly changes how the shared foundation is spread.
- **An existing `slices.md`**: this round is an increment, not a restart.

## How to cut

Four columns per slice. A slice that cannot fill all four is usually not a slice.

| Column | Content |
|---|---|
| Slice | A short title |
| Blocking edges | Which slices must finish first |
| What it verifies end to end | One sentence, from the user's point of view |
| Screens in the approved hi-fi | The concrete paths |

The criteria, the size anchor, how to spread the shared foundation, and how to pick the first slice are all in [`references/slicing-criteria.md`](references/slicing-criteria.md). Read it before cutting.

Three signals you can apply on the spot:

- **You cannot say "when this slice is done, here is one thing a user can actually do"** → not a slice. "Build the tables first" and "set up the skeleton" verify nothing; break them into the slices that need them.
- **The title contains a conjunction** — "and", "和", "与" → two slices. Split them. (Slice titles are written in the template's language, so test for the conjunction in that language.)
- **It does not fit in one fresh context window** → too big. Implementation happens in a sub-agent's fresh context, and that window is the natural size ceiling.

**Write only the blocking edges that genuinely block.** Order is not dependency — writing "happens to come earlier" into the blocking edges makes every later slice look serial when some could start at any time.

**A wide refactor is not cut into vertical slices, but its tickets still go in this table.** Changing a shared symbol's type, renaming a field used everywhere — the blast radius covers the repository, and forcing it into vertical slices makes every slice red, because the intermediate state does not compile. It goes through expand–contract instead, and **those tickets are listed here**: the blocking edges are the whole point of the sequence, and this table is the only host for them. Their third column states a technically observable result rather than a user capability, and their fourth is normally empty. The sequence, the batching rule and a worked table are in [`references/wide-refactor.md`](references/wide-refactor.md).

## Settle it with the user

List the draft with numbers and ask three questions, iterating to approval:

1. Is the granularity right — too coarse, or too fine?
2. Are the blocking edges right — does each slice depend only on what genuinely blocks it?
3. Is anything worth merging, or worth splitting further?

**Decide once.** Fold whatever is worth keeping from a rejected cut into the approved one on the spot, and leave nothing as "let's see". This is the one step here that genuinely runs away, and the runaway shape is not cutting too much — it is oscillating between two or three ways to cut.

Two rounds, maximum. Record whatever is still disputed after the second round as "to confirm", and do not open a third.

Where a slice maps to more than six screens, say once that it may be cut too large and leave the conclusion on the record — but **do not block**. Some slices are simply large, and the judgement is the user's.

## Write slices.md

Follow `assets/slices-template.md` (it is in Chinese, matching its output) for the three sections: the phase goal, the slice list, the frontier.

**Compute the frontier; do not copy the order.** The frontier is every slice whose blocking edges are all complete. It answers "what comes next"; counting down the table from the top misses the slices that could have started long ago.

**Fill in the fourth column.** An empty cell means this slice has no matching structure in the hi-fi — either go back and complete the hi-fi, or this slice is cut wrong. It is not decoration: it is the value range for the jsonl step below. **The one exception is a wide-refactor ticket**, which changes no interface and therefore maps to no screen.

**As each slice becomes a task, its screens go into `implement.jsonl`.** That rule and its failure mode belong to `specs/universal/guides/task-artifacts.md`, which Trellis injects when task files are edited; the fourth column exists to give that step an accurate value range. **List only this slice's screens** — the full hi-fi overflows the sub-agent's context.

## Boundaries

- **Define no requirements, and change no hi-fi.** Where the PRD or the hi-fi turns out to be wrong, go back and change it there, saying why — writing a missing requirement into the slice list decides requirements under another name. Which artifact is authoritative at each stage, and how to write the change back as a delta, are in `specs/universal/guides/source-of-truth.md`, injected when `docs/discovery/**` is edited.
- **Write no `prd.md` / `design.md` / `implement.md`.** Those three are `trellis-brainstorm`'s output inside a task and cover "how this slice gets built"; this step answers only "how big, who blocks whom, and which screens".
- **Set no approval flags.** The output is material feeding the approval that brainstorm asks for; the one thing on this chain that can actually stop work is Trellis's planning-summary gate.

## Files

| File | When to read it |
|---|---|
| [`references/slicing-criteria.md`](references/slicing-criteria.md) | Before cutting. Criteria, the size anchor, the shared foundation, picking the first slice |
| [`references/wide-refactor.md`](references/wide-refactor.md) | When a mechanical change covers the whole repository |
| [`assets/slices-template.md`](assets/slices-template.md) | When writing `slices.md`. **In Chinese**, matching the document it produces |

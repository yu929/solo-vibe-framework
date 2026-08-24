# Slicing Criteria

Read this before cutting. `SKILL.md` gives the process; this gives the judgement.

## Contents

- [What a slice actually is](#what-a-slice-actually-is)
- [The size anchor: one fresh context window](#the-size-anchor-one-fresh-context-window)
- [Spreading the shared foundation](#spreading-the-shared-foundation)
- [Picking the first slice](#picking-the-first-slice)
- [Things that look like slices and are not](#things-that-look-like-slices-and-are-not)
- [Blocking edges and the frontier](#blocking-edges-and-the-frontier)

## What a slice actually is

A slice is **one narrow but complete path through every layer**. Not a segment of one layer.

Cut horizontally, and no layer verifies anything when it finishes:

```
Slice 1: all the tables built
Slice 2: all the endpoints written
Slice 3: all the pages assembled
Slice 4: wire it together
```

Cut vertically, and each one ends with something somebody can do:

```
Slice 1: a user can sign in           (session table + sign-in endpoint + sign-in page)
Slice 2: a user can create a record   (record table + create endpoint + form page)
Slice 3: a user can see their records (query + list endpoint + list page)
```

The test is one sentence: **when this slice is done, what is one thing a user can actually do?** No answer, no slice.

Note what the test asks — what becomes possible, not how much got built. "Finish the user module" sounds like delivery, but it answers effort, not capability.

## The size anchor: one fresh context window

**A slice must fit in one fresh context window.**

The anchor is not a metaphor. Implementation happens in a sub-agent's clean context: it receives this slice's `prd.md` / `design.md` / `implement.md`, a few specs, a few approved screens, and starts writing. Overflow it and the constraints from the first half fall out mid-way — and what falls out raises no error, it just produces an implementation that looks reasonable and violates its premises.

**Do not anchor on file count or hours.** A genuine vertical slice naturally touches five or more files — table, migration, service, route, page. Judged by file count, a normal slice reads as "too big", which pushes you toward horizontal slicing: exactly the direction to avoid.

Signals it will not fit:

- The acceptance criteria do not fit in three bullets.
- The title contains a conjunction — "and", "和", "与" — two slices, split them.
- It touches two unrelated subsystems at once (authentication and billing, say).
- Describing it requires a paragraph of background first.

## Spreading the shared foundation

Authentication, the navigation shell, error handling, the database connection — every later slice needs these, but none of them is a slice on its own, because no user can do anything as a result.

**Spread each one into the first slice that needs it, rather than making it a slice.**

Slice 1, "a user can sign in", contains the session table, CSRF handling and the first version of error display. Slice 2, "a user can create a record", reuses them and adds only what it needs. By slice 3 the foundation is mostly there and the later slices get thinner — **that curve is normal, not evidence the early ones were too big**.

Two exceptions, both stated explicitly in the slice list:

- **The foundation itself is being replaced** (a new auth scheme, a different database) → that is a wide refactor; see [`wide-refactor.md`](wide-refactor.md).
- **One part of the foundation is complex enough to verify on its own** ("an admin can create an account for someone else and assign a role") → it was a slice all along, because there is something a user can do.

**Do not invent a slice zero to "get the foundation right first".** That is horizontal cutting in vertical clothing: nothing is verifiable when it finishes, and the structure it fixes has been tested against no real use case.

## Picking the first slice

The test is not "which matters most". It is **which one falsifies your assumptions most cheaply**.

The first slice fixes a set of things every later slice inherits: what a list looks like, how errors are expressed, how data is organized, how authentication works. It is worth one extra round of thought.

Ask in this order:

1. In this PRD, **which assumption is most expensive to have wrong**? ("the external API can supply this data", "this volume holds up", "users will follow this flow")
2. Which slice reaches that assumption fastest?
3. Can that slice run end to end on its own?

Where all three point at one slice, take it. Where they point at different ones, take the answer to question 2 — hitting the wall early is cheaper than hitting it late.

## Things that look like slices and are not

| What it looks like | Why it is not one | Instead |
|---|---|---|
| "Set up the project skeleton" | Nothing is verifiable when it is done | Spread it into the first slice |
| "Build all the tables" | Horizontal | Each slice builds the tables it needs |
| "Finish module X" | Answers effort, not capability | Re-cut by "what can a user do" |
| "Optimize performance" | No boundary, and no way to say what done looks like | Set an observable target first; then it can be a slice |
| "Change that field's type everywhere" | The blast radius covers the repository | See [`wide-refactor.md`](wide-refactor.md) |
| "Establish the visual language" | Users could already do those things; they just look better now | A one-off fork, not a row in the slice list |

## Blocking edges and the frontier

**A blocking edge means: without that slice finished, this one cannot start.** Not "conventionally comes first", and not "would be more convenient afterwards".

Writing them too wide has a concrete consequence: every slice looks serial, so you work down the table in order while several slices could already have started — which matters most exactly when you want to parallelize, or to skip ahead and test a later assumption.

**The frontier is every slice whose blocking edges are all complete.** It answers "what comes next".

A single chain A → B → C has a frontier of one, which is fine. But where the frontier stays at one across a dozen slices, go back and check whether the edges were written too wide — real dependencies are usually far sparser than intuition suggests.

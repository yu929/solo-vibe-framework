# Wide Refactor: the exception to vertical slicing

## What counts as one

**A mechanical change whose blast radius covers the repository.** Changing a shared symbol's type, renaming a field used everywhere, replacing a utility function with hundreds of callers.

Its signature: the change itself is simple, but **one edit breaks hundreds of call sites at once**, with no green state in between.

This kind of change **cannot be cut into vertical slices**. Force it and every slice goes red, because the intermediate state — half the call sites on the new form, half on the old — does not compile. The slicing test fails on it too: nothing a user can do has changed, which is the definition of a refactor.

**Do not force it.** Switch to the sequence below.

## expand–contract

Three stages, green between each.

### 1. expand — the new form and the old coexist

Add the new thing first and change no call site. The old form is still there, so nothing is broken.

Add a field rather than changing a type; add a function rather than changing a signature; add a column rather than redefining one.

**This stage is a ticket of its own**, and every migration ticket is blocked by it.

### 2. migrate — move the call sites in batches

Switch the call sites to the new form batch by batch. **Draw the batches along the blast radius** — usually by package, by directory or by module, never by an arbitrary "twenty files at a time".

One ticket per batch, each blocked by expand, and **the batches do not block each other** — they can run in parallel or in any order.

The point is that **every batch ends green**, because the old form is still there and the unmigrated call sites keep working.

### 3. contract — delete the old form

Once every call site has moved, delete the old form. **This ticket is blocked by all the migration tickets.**

Confirm there really are no call sites left before deleting — use the compiler or a repository-wide search, not memory.

## When even a batch cannot stay green

Some changes cannot run green in a single batch — a protocol whose two ends must change together, for instance.

Keep the same sequence, but give those tickets a **shared integration branch**, and have them all block one final "integration verification" ticket. Green is promised only on that ticket.

**This is a concession, not the normal path.** It means that for a stretch, that part of the trunk is unverifiable — so keep the batches few, put the integration ticket early, and state the arrangement plainly in the slice list, so nobody later assumes those tickets ship independently.

## How it looks in slices.md

**The refactor itself is not a slice; its tickets are still rows.** Keeping them out of the table would leave the expand–contract sequence's blocking edges with no host — and those edges are the entire discipline. So they go in, filling the same four columns, with the third one stating a **technically observable result** rather than a user capability:

| Slice | Blocking edges | What it verifies end to end | Screens in the approved hi-fi |
|---|---|---|---|
| expand: add `status_v2` and dual-write | none | Old and new columns agree after a write; the old read path is unchanged | — (no interface change) |
| migrate: orders module to `status_v2` | expand | Order tests green, other modules unaffected | — |
| migrate: reporting module to `status_v2` | expand | Reporting tests green | — |
| contract: drop the old `status` column | both migrations | No `status` references remain; the full suite is green | — |

**An empty fourth column is normal here**, because these tickets usually do not touch the interface. One that does is not a pure wide refactor — cut the interface part out as an ordinary vertical slice.

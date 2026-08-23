# Cross-Layer Work

> **The more layers a feature crosses, the easier it becomes for every layer to be right on its own and the whole to be wrong.**

## Why cross-layer bugs are expensive

What they have in common is that **each layer reads correctly in isolation**.

- the service layer returns `null` for "absent"; the UI layer reads `null` as "not loaded yet"
- storage holds UTC, the display layer interprets it as local time, and the layer between passes it through untouched
- an external API returns an optional field, and some layer adds an `as` assertion that treats it as required

These cost so much because **the place that reveals the bug is far from the place that caused it**. Locating it costs far more than fixing it.

## Three steps before you start

### Step 1 · Draw the data flow

Write out every hop from origin to final display:

```
external API → storage → service layer → UI layer
```

Annotate each hop with **three things**:

1. what the data looks like (its shape)
2. what this hop transforms
3. what this hop returns when it fails

The third is the one that gets skipped, and the one that bites.

### Step 2 · Find the boundaries

**A boundary is where data changes hands.** At each one, ask:

- does "no data" mean the same thing on both sides?
- do null, empty array and empty string mean the same thing on both sides?
- who validates? (The answer cannot be "both", and it cannot be "each assumed the other did".)

### Step 3 · Write the contract down

A boundary's contract is **explicit**, not something each side assumes:

- the type definition lives in a shared place and both sides import it — neither writes its own "it should look like this"
- how errors are expressed: thrown? returned as a value? Mixing the two is a disaster
- which **side** decides the default behaviour for an optional field

## Four common mistakes

### Mistake 1 · An implicit format assumption

One layer produces `2026-08-12`, another expects an ISO timestamp, and nobody in between declares a format.

**Symptom**: fine locally, explodes on a different timezone or a different row.
**Fix**: put the format in the type or the contract, not in "everyone knows".

### Mistake 2 · Validation scattered across layers

Every layer validates a little, and the sum has both duplication and gaps.

**Fix**: split by **responsibility**, not by layer count. These two categories must be handled separately; conflating them produces dangerous conclusions:

| Category | Rule | Examples |
|---|---|---|
| **Parsing, normalization, defaults** | **May have a single owner**; other layers consume its output | how a date string is parsed, what a missing field defaults to, how case and whitespace are normalized |
| **Trust boundaries and invariants** | **Every boundary enforces its own, with no exceptions** | validating untrusted input as it crosses a boundary, server-side authorization, uniqueness and referential integrity in storage |

**Do not stretch "don't parse it twice" into "only validate in one layer".** Three specifics:

- **Client validation does not substitute for server-side authorization.** The first is experience, the second is security. Bypassing the UI and calling the API directly is the most basic attack there is.
- **Entry-point validation does not substitute for storage constraints.** Concurrent requests, background jobs, data-repair scripts and a second write path all skip that "single validating layer". Uniqueness, foreign keys, non-null and state-machine legality are backstopped by storage.
- **Validated upstream does not mean unconditionally trusted downstream** — least of all across processes, across services, or across time (an old message sitting in a queue).

**How to cut duplication without giving up defence**: share the schema or the validation function so several layers reference one definition. What repeats is the **enforcement**, not the **definition**. Enforcing many times is correct; defining many times is the mistake.

### Mistake 3 · A leaky abstraction

An upper layer contains a lower layer's implementation details — the UI layer knowing database column names, the service layer assembling display strings for the UI.

**Symptom**: changing the implementation spreads edits into layers that should not have moved.
**Fix**: each layer exposes only its own concepts.

### Mistake 4 · Every consumer parsing the same payload

See Pattern 4 in [`code-reuse.md`](code-reuse.md). It is a reuse problem and a cross-layer problem at once — **contract logic has been copied**.

## Checklist for adding a field

When you **add a field** to an event, a message, a config or an external response — the case that is missed most often:

- [ ] the type definition is updated
- [ ] every consumer handles the field being absent (old data does not have it)
- [ ] persisted data is migrated, or explicitly does not need to be
- [ ] nothing elsewhere uses an `as` assertion to slip past type checking (it will not error there; it will silently produce `undefined`)
- [ ] `grep` the field name afterwards and confirm no consumer was missed

**Removing a field is the same, and more dangerous** — deletion produces no compile error telling you who still reads it, if that reader used `as`.

## Deciding which layer logic belongs in

Decide by **what it depends on**, never by what it resembles:

| This logic depends on | It goes in |
|---|---|
| its input arguments only | the shared pure-function layer |
| the storage schema | the data access layer |
| business rules | the service layer |
| display context (what the current user is looking at) | the UI layer |

**Logic whose dependencies you cannot state is usually doing two things.** Split it and ask again.

## When a diagram is worth drawing

Do not draw one for every feature. It is worth drawing when the feature:

- crosses three or more layers, **and**
- has asynchrony or retry on failure, **or**
- has several consumers, **or**
- you are explaining it to someone — or to an AI — for the second time

Inline the diagram in the document it belongs to. **Never give it its own file**: two places maintaining one flow will drift, and it is only a matter of time.

---

<sub>The question framework is adapted from the cross-layer thinking guide in [Trellis](https://github.com/mindfold-ai/Trellis)'s (AGPL-3.0) built-in spec template; the content is rewritten (the original carries a great deal of Trellis's own project checklists, which do not apply to this framework).</sub>

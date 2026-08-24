# Thinking Guides

> **What these are for:** widening what you consider *before* you start, so the "didn't think of that" problems land here instead of in the code.
>
> Most bugs and most technical debt do not come from lack of skill. They come from **not having thought of it** — not thinking about the format assumption between two layers, not noticing this pattern has already appeared three times, not seeing that this change reaches somewhere else.
>
> These guides do not tell you how to write code. They help you **ask the right question** before you write it.

## Scope of this layer

Track-independent ways of thinking, plus the discipline for converging. **No stack conventions of any kind** — those are the **track spec**, installed under `.trellis/spec/` alongside this directory in sibling folders such as `frontend/`, `backend/` and `database/` (the exact layering varies by track).

## Files

| File | Covers | Read it |
|---|---|---|
| [`code-reuse.md`](code-reuse.md) | Confirming something does not already exist before you write it | **Before writing** |
| [`cross-layer.md`](cross-layer.md) | Data flow, boundaries and contracts for features that cross layers | **Before writing** |
| [`review-adjudication.md`](review-adjudication.md) | **Reporting is not deciding** — the four-field finding while coding, and lightweight convergence during requirements discovery | On a finding |
| [`task-artifacts.md`](task-artifacts.md) | What belongs in a task's `design.md` and `implement.md` (**injected by path**) | Writing task artifacts |
| [`source-of-truth.md`](source-of-truth.md) | Which artifact is authoritative at each stage, and writing back as a delta rather than an append (**injected by path**) | Documents disagree |

## Quick navigation by trigger

When you are unsure whether a guide applies, check its triggers.

### Read [`code-reuse.md`](code-reuse.md) when

- [ ] you are about to write something that resembles code that exists
- [ ] you are seeing the same pattern for the third time
- [ ] you are adding the same field in several places
- [ ] **you are about to change any constant or config value**
- [ ] **you are about to create a utility or helper** ← search first
- [ ] two files are each parsing the same data structure

### Read [`cross-layer.md`](cross-layer.md) when

- [ ] this feature crosses three or more layers (UI, service, storage, external API)
- [ ] data changes format between layers
- [ ] several consumers need the same data
- [ ] you are unsure which layer a piece of logic belongs in
- [ ] you are adding a field to an event, a message or a config

### Read [`review-adjudication.md`](review-adjudication.md) when

- [ ] **while coding or debugging you found that "this rule is actually wrong" or "there is a trap here the spec never mentioned"** ← the most common trigger by far
- [ ] you are deciding whether a lesson is worth promoting into `.trellis/spec/`
- [ ] a prototype walkthrough or a choice between options needs to converge
- [ ] you want to know when to escalate to the full review protocol

**It does not contain the full review protocol** — ten disciplines, P0–P3, the eight-field evidence format, stopping rules. Those live in the `design-review` skill, which the user invokes by hand. This file holds the two you need every day.

### Read [`task-artifacts.md`](task-artifacts.md) when

- [ ] you are about to write this task's `design.md` or `implement.md`
- [ ] you are unsure whether something belongs in `prd.md`, `design.md` or `implement.md`
- [ ] you are deciding whether this task needs a `design.md` at all (a lightweight task with only `prd.md` is legitimate)

**This one carries `paths: [".trellis/tasks/**"]`**, so it is injected automatically when you touch files in a task directory. You do not have to remember to read it.

### Read [`source-of-truth.md`](source-of-truth.md) when

- [ ] the PRD and the prototype disagree and you do not know which to change
- [ ] a spike or a walkthrough produced a new conclusion that has to go back upstream
- [ ] the same fact is written in two files and you are unsure which is current
- [ ] you are about to append "the section above is obsolete" to a document ← **that is the exact thing it prevents**

**This one carries `paths: ["docs/discovery/**"]`**, so it is injected automatically when you touch requirements-discovery artifacts.

## Quality gate for this layer

These guides are not themselves a quality gate — the concrete typecheck, lint, test and build commands live in each repository's own conventions.

This layer has exactly one universal gate:

> **Search before you change any value.**
>
> ```bash
> grep -rn "the value you are changing" .
> ```
>
> This single habit prevents most of the "forgot to update X" class of bug.

## Maintaining these files

- **After hitting a new trap**, come back and add it to the matching guide. The value of these files comes entirely from real lessons, never from generic best practice.
- Before adding, ask: **is this track-independent?** It belongs here only if it still holds on a different stack. Anything involving a specific framework, database or build tool belongs in the sibling track spec directories (`frontend/`, `backend/` and so on).
- **Edit these files in the framework repository's `specs/universal/guides/`, which is the source of truth.** The copies inside each track template are generated; editing one directly will be overwritten at the next sync.

---

<sub>The question frameworks in `code-reuse.md` and `cross-layer.md` are adapted from the thinking guides in [Trellis](https://github.com/mindfold-ai/Trellis)'s (AGPL-3.0) built-in spec template; the content is rewritten for this framework rather than copied.</sub>

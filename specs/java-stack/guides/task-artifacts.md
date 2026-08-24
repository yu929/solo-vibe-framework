---
name: task-artifacts
description: What goes in a task's design.md and implement.md, and what does not
paths:
  - .trellis/tasks/**
---

# Task Artifacts: design.md and implement.md

> Trellis requires a complex task to have `prd.md`, `design.md` and `implement.md` before `task.py start`, but generates a skeleton only for `prd.md`. The shape of the other two is defined here.

## What each one answers

Putting something in the wrong file costs more than leaving it out — one fact in two files means an edit reaches only one.

| File | Answers | Does not contain |
|---|---|---|
| `prd.md` | **What** this slice needs, and how you know it is right | Technical approach, implementation steps |
| `design.md` | **How it is designed** — boundaries, contracts, trade-offs | Requirements, step-by-step lists |
| `implement.md` | **In what order** to build it, and how to verify | Requirements, design rationale |

A lightweight task needs only `prd.md`. **The test is not the size of the change, it is whether the implementer has to make a decision first** — if so, add `design.md`.

## design.md

```markdown
## Boundaries and responsibilities
## Contracts and data flow
## Compatibility and migration
## Trade-offs
## Rollback shape
```

**Boundaries and responsibilities**: which modules this change touches, what each is responsible for, and who is not allowed to know about whom. State the boundaries and an implementation sub-agent will not casually put logic in the wrong layer.

**Contracts and data flow**: interface shapes, where data comes from and goes to, who holds state. **A type, a schema or a state machine says this more precisely than prose** — these are the places worth pasting a concrete fragment. Everywhere else, do not paste code; it goes stale.

**Compatibility and migration**: what happens to old data, what happens to old callers, whether this ships in two steps. When there is no compatibility concern, write one line saying so. Do not leave it blank — blank does not distinguish "none" from "never considered".

**Trade-offs**: **write down the options you rejected, with the reason you rejected them.** This is the section most often skipped and the most valuable of the three files — six months later, if nobody remembers why the simpler approach was not used, somebody will implement it again.

**Rollback shape**: how to back out when it goes wrong. Mandatory when the change touches the database or an external contract.

## implement.md

```markdown
## Implementation order
## Verification commands
## Risky files and rollback points
## Pre-start review
```

**Implementation order**: an ordered list, one thing per step. **Every step must be independently verifiable** — change eight files and then run the tests, and a red result tells you nothing about which step caused it.

**Verification commands**: commands that can be copied and run, not "run the tests". Write them out concretely enough to paste into a terminal, because an implementation sub-agent will run them as written.

**Risky files and rollback points**: which files, when touched, tend to drag in others, and at which step the cost of rolling back jumps.

**Pre-start review**: what to confirm before `task.py start`. **Are this slice's structural references — the approved screens, the contract files — in `implement.jsonl`?** This is the one most often missed, and missing it has no symptom: a sub-agent in a fresh context sees only the files that jsonl lists, and a path written into `prd.md` does not count. **List the governing rules the same way**: the `index.md` of every layer this slice touches, plus the sibling files that index's own table sends you to for this change. A sub-agent's context is assembled from the jsonl *before* it starts, while path-glob injection reaches it only after it has already written something.

## Two rules that apply to both

**Do not write out specific file paths or code fragments** — they go stale faster than the document. The exception is anything **more precise than prose**: schemas, state machines, type shapes, error-code tables. Pasting those reduces ambiguity rather than adding it.

**Do not restate requirements `prd.md` already covers.** Point at it when you need to refer to one. One requirement stored in two places means an edit will reach only one.

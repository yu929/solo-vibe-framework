---
name: source-of-truth
description: Which artifact is authoritative at each stage, which direction updates flow, and how to write a delta
paths:
  - docs/discovery/**
---

# Source of Truth

> **When one fact is stored in two places, an edit will reach only one of them.** This guide answers a single question: which one is authoritative right now?

## By subject

Four subjects, one host each, no overlap:

| Subject | Host |
|---|---|
| Requirements and acceptance | The full PRD; once slicing starts, that slice's task `prd.md` |
| Terminology | `CONTEXT.md` |
| Decisions with a trade-off | `docs/adr/` |
| Interface and interaction structure | The approved hi-fi in `design-system/screens/`, plus `design-system/MASTER.md` |

**Do not keep a convenience copy anywhere else.** When the PRD needs to talk about terminology, point at `CONTEXT.md`; when it needs to say why something was decided, point at the ADR.

## By stage

A stage never moves a subject to a different host. What it changes is **which version of that subject's host is authoritative**, and which side yields on a conflict:

| Stage | Requirements and acceptance | Interface and interaction structure |
|---|---|---|
| Requirements discovery, before the hi-fi is approved | The full PRD | Not settled. The prototype is a spike — on a conflict, change the prototype |
| Hi-fi approved, before slicing starts | Still the full PRD, now carrying the one formal write-back: the fields, states and edge cases the prototype exposed | The approved hi-fi plus `design-system/MASTER.md` |
| After slice implementation starts | That slice's task `prd.md`; the full PRD is frozen as background, updated by delta as each slice finishes | This slice's approved screens |

Terminology and trade-offs are not in this table because **no stage moves them**: `CONTEXT.md` and `docs/adr/` are authoritative throughout.

**Approving the hi-fi does not make it authoritative over requirements.** It becomes authoritative over structure — which screens exist, what is on each, how they connect — and over nothing else. A screen implying a rule the PRD does not carry is a **finding against the hi-fi**, not a new requirement: take it back to the PRD, decide it there, and let the change flow outward. Reading a requirement off a mockup is how a drawing decision silently becomes a product decision.

**The write-back happens once, at a stage boundary.** Editing the PRD every time a spike finishes turns it into a transcript of the conversation — and then finding the current state means reading it from the top.

## Write back as a delta, never as an append

Fold findings back using three markers, **editing the body directly**:

```markdown
## ADDED
### Two-factor authentication
The system supports TOTP-based two-factor authentication.

## MODIFIED
### Session expiry
Expires after 15 minutes of inactivity. (Was 30 minutes.)

## REMOVED
### Remember me
Superseded by two-factor authentication.
```

When archiving, merge the delta back into the main document. The main document **only ever describes the current state**.

**Why this deserves its own rule:** appending edits grows things like this —

> ~~Note: the section above is obsolete, do not follow it.~~
> ~~Addendum: option C changed, we actually use D.~~

What they have in common is that **an append was used where a MODIFIED or a REMOVED belonged**. After a few rounds the document stops describing what the thing *is* and starts describing how many times it has been changed, leaving the reader to reconstruct the current state — which is precisely what the document was supposed to do for them.

## Resolving a conflict

Name the subject in dispute first, then read the stage table's row for where you are and its column for that subject. Change the other side.

**If the change belongs on the authoritative side**, you have found a real problem. Make the change — but say why, and check whether it drags in anything already approved. It is two orders of magnitude cheaper here than after implementation.

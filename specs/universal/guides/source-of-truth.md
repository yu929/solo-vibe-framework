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
| Interface and interaction structure | The approved hi-fi plus `master.md` |

**Do not keep a convenience copy anywhere else.** When the PRD needs to talk about terminology, point at `CONTEXT.md`; when it needs to say why something was decided, point at the ADR.

## By stage

The same artifact carries different authority at different stages:

```
Requirements discovery → before the hi-fi is approved
    Source of truth = the full PRD
    The prototype is a spike; on a conflict, change the prototype

Hi-fi approved → before slicing starts
    Source of truth = the hi-fi plus master.md
    The one formal write-back: fold the fields, states and edge cases the
    prototype exposed back into the PRD

After slice implementation starts
    Source of truth = that slice's task prd.md plus this slice's approved screens
    The full PRD is frozen as background, updated by delta as each slice finishes
```

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

Find the current source of truth in the stage table above, and change the other side.

**If the change belongs on the authoritative side**, you have found a real problem. Make the change — but say why, and check whether it drags in anything already approved. It is two orders of magnitude cheaper here than after implementation.

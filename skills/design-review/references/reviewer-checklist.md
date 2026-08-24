# Reviewer Checklist (track-independent)

Read-only review for `design-review`. Find problems against this checklist and state evidence and severity for each. Change no files, add no requirements, run no open-ended "full review".

> **This is also the main agent's own checklist** when it reviews directly instead of dispatching subagents. Dispatched as a subagent, you are told to play **Reviewer A**, **Reviewer B**, or both.
>
> Severity levels and the eight-field evidence format are in [`review-adjudication.md`](review-adjudication.md). Use them as written.

## Inputs the main agent provides

- **The frozen input set**: requirements version, load-bearing decisions version, engineering baseline version, in scope, out of scope.
- **The issue log** (required reading): a `REJECTED_*`, `DEFERRED` or `ACCEPTED_RISK` entry stays closed unless its `reopen_condition` is met.
- **The material under review**: the load-bearing decisions document (its path follows the target repository's own convention — `docs/adr/`, `docs/architecture/`, or elsewhere; **not `.trellis/spec/`, which holds coding rules only**). Where there is none, report that there was nothing to review rather than inferring one. Plus the slice order (the slice table in `docs/discovery/slices.md`) and the target repository's `AGENTS.md`.
- **The requirements basis, which differs by when the review fires.** The most common trigger is occasion 1 — load-bearing decisions just settled, **before the first task exists** — and at that point there is no task `prd.md` to read, by design: the slicing step is forbidden to write one. Take the basis from wherever the stage actually keeps it:

  | Review fires | Requirements basis |
  |---|---|
  | Before the first task exists (occasion 1) | The **full PRD**, plus `docs/adr/` and the slice table in `docs/discovery/slices.md` |
  | Inside or after a task (occasions 2–4) | That task's `prd.md`, with the full PRD as background |

  **Do not ask for an artifact the current stage has not produced**, and do not treat its absence as a finding. Missing the artifact the stage *should* have — no full PRD before slicing, no slice table — is a finding.
- **The track overlay**, if there is one. It carries that track's hard constraints — its data isolation mechanism, data-access paths, credential boundaries, build and migration conventions. **Use only the overlay you were given**; another track's rules do not apply. Without one, run the generic surface and say so in the report.

Where the context is not enough to judge something, mark it **"for the main agent to verify"** and state what context is missing.

## Round 1 · Structure

**Reviewer B — implementability and process:**

- **Requirement coverage**: every agreed capability and screen is covered by some slice, and nothing is invented — no feature, module or table the requirements do not carry.
- **Slices are independently deliverable**: self-contained, dependencies acyclic and ordered, and sized to one fresh context window. Check each against the four columns the slice table actually carries — a title, the blocking edges, **one end-to-end result a user can verify**, and the approved screens it maps to. A slice whose third column states a layer built rather than something a user can do is cut horizontally. **The per-slice goal, task list and acceptance are written later, by the task's own planning step** — their absence here is correct, not a gap.
- **Dependency order is explicit**: precedence between slices is written into the artifacts, not implied by a parent/child structure.
- **Interfaces and contracts line up**: entry points ↔ capabilities ↔ internal contracts ↔ external contracts agree; numbering, naming and terminology are consistent across documents (a `CONTEXT.md` glossary, where it exists, governs).
- **Repository conventions hold**: nothing violates the target repository's `AGENTS.md` or the overlay's hard constraints.
- **Interaction states are complete**: the key screens account for loading, empty, error and in-progress. Detail belongs to the visual stage; check only that no whole class of state is missing.
- **The structure is self-consistent**: module responsibilities clear, data flow closed, no obvious architectural contradiction, and the key non-functional requirements (permissions, auditing, real-time, deployment) present.

## Round 2 · Failure modes and data risk

**Reviewer A — correctness and data risk** (where the real P0/P1s come from):

- **Data model**: key entities, relationships and constraints complete; uniqueness, foreign keys and cascading deletes explicit.
- **Permissions and trust boundaries**: who reads and writes what, how cross-subject access is controlled, which roles cannot read the ciphertext, whether any path allows privilege escalation. **Check the isolation mechanism itself against the overlay.**
- **Transactions, consistency, idempotency**: whether a cross-table write needs a transaction; whether a repeated request is idempotent; whether the state machine closes and whether it can roll backwards illegally.
- **Failure and recovery**: the state data is left in after each external call or async job fails; whether it can be retried or rolled back; the degraded path when an external dependency is unavailable.
- **Data loss and migration**: whether delete and cleanup paths cover related data and external storage; whether the migration is reversible.
- **Credential boundaries**: where keys, tokens and connection credentials live and what they are exposed to; whether any can reach a log, a response or an exception trace.

## Cross-cutting · Altitude

Mark **implementation detail locked into the design too early** as P2/P3 with "defer to coding, verify with a test" — concurrency locks and CAS, retry strategy, specific algorithms, branches a type or a test would catch, index tuning, performance micro-optimization. These are not P0/P1.

Mark the inverse as the real P0/P1: a **load-bearing decision** missing or vague.

| Must be decided now | Deferred to coding |
|---|---|
| Data ownership and the permission model | Internal class structure and helper modules |
| The shape of the key models, relations and constraints | Most design patterns, and how far to generalize |
| Trust boundaries, authorization principles, credential boundaries | The concrete lock, CAS or retry implementation |
| External boundaries and the shape of long-term contracts | Index tuning and non-bottleneck optimization |
| Consistency requirements | Ordinary algorithms and local branching |
| Migration, deletion and compatibility strategy | Secondary error copy |

- ✅ "One business identity can have at most one active object at a time" — a verifiable invariant.
- ❌ A specific lock key, CAS statement and backoff curve in the design. Write instead: the implementation is chosen at coding time and the invariant is proven by a concurrency test.
- ✅ "The external contract carries no credential values, and error responses return stable error codes only" — a boundary plus its acceptance basis.
- ❌ A general event bus or plugin framework with no consumer yet.

## Output format

Output the findings list and no long summary. Group by severity, with these columns:

```markdown
## P0 must fix (clear before coding)
| id | document · section | problem | evidence | trigger/impact | suggestion |

## P1 needs an explicit decision
(same columns)

## P2 backlog
| id | document · section | problem | evidence | suggestion |

## P3 / altitude too low (suggest deferring to coding)
| id | document · section | problem | suggestion |

## For the main agent to verify
| id | document · section | doubt | context needed |
```

## Constraints

- Change no files and add no requirements.
- Treat an open design choice or a style preference as a problem only where it violates the target repository's `AGENTS.md` or an explicit overlay constraint.
- Report one representative of a repeated problem: two or three examples plus the extent of the impact.
- Where the design already declared something a coding-time decision, treat it as decided, not as a missing detail.
- Give locatable evidence in preference to a general conclusion.

# Code Reuse

> **Stop before you write new code: does it already exist?**

## Why this one comes first

**Duplicated code is the leading source of inconsistency bugs.** Once a piece of logic has been copied or rewritten:

- a bug gets fixed in one copy while the other keeps being wrong
- the two implementations drift apart over time, until nobody knows which is correct
- a newcomer — including the AI in the next session — cannot tell which one to change

For solo work with an AI, the problem is sharper: **an AI defaults to building rather than reusing.** It cannot see the whole repository, and writing a new function is always easier than finding and understanding the existing one. So this checklist is mainly a constraint on the AI, not a reminder for the human.

## Before writing new code

### Step 1: search

```bash
# similar function names
grep -rn "functionName" .

# keywords from the logic itself
grep -rn "keyword" .
```

**There is no exception to this step.** "I'm sure there isn't one" does not hold in a repository you have not read end to end.

### Step 2: ask these four questions

| Question | If yes |
|---|---|
| Is there a function that does something similar? | Use it, or extend it |
| Has this pattern been used elsewhere? | Follow what exists; do not invent a second way |
| Should this logic be a shared utility? | Build it in the right place, once |
| Am I copying code out of another file? | **Stop** — extract it and share it |

## Common shapes of duplication

### Pattern 1 · A copied function

**Bad**: copying a validation function into another file.
**Good**: extract it to a shared location and import it from both.

### Pattern 2 · A near-identical component

**Bad**: building a new component that is 80% the same as one that exists.
**Good**: add a prop or a variant to the existing one.

**The test**: if the difference between the two components can be expressed as one boolean or one enum, they are the same component.

### Pattern 3 · A duplicated constant

**Bad**: the same constant defined separately in several files.
**Good**: one source of truth; everything else imports it.

This is the shape **most likely to break during a change**: you edit one copy, the rest silently keep the old value, and type checking sees nothing at all.

### Pattern 4 · Every consumer parsing the same payload

**Bad**:

```ts
// a.ts
const desc = (payload as { description?: string }).description;
// b.ts
const desc = (payload as { description?: string }).description;
```

Two lines each, and still **duplicated contract logic**. Change the field and both have to change — and the `as` assertion keeps type checking out of it.

**Good**: define the type and the parsing in one place; everything else consumes that.

### Pattern 5 · The same derived state recomputed in several branches

When several branches update the same derived state off one `kind` or `action`, adding a new value is guaranteed to miss one of them. Extract a map or a function.

## The reverse: when *not* to abstract

Reuse discipline has a symmetric failure mode — **abstracting too early for the sake of reuse**:

- it appears twice, with no reason to expect a third → leave it duplicated and extract on the third
- two pieces look alike but **change for different reasons** → do not merge them; they will evolve apart
- the extracted thing needs more than three parameters to cover two call sites → they are not the same thing

**The test is not "do they look alike", it is "will they change together for the same reason".** If yes, extract. If no, let them stay duplicated.

## The one that gets forgotten most

> **Before changing any value, search for everywhere it appears.**

```bash
grep -rn "the value you are changing" .
```

Config keys, constants, enums, environment variable names, file paths, magic strings — this single habit prevents more bugs than every other checklist here combined.

---

<sub>The question framework is adapted from the code-reuse thinking guide in [Trellis](https://github.com/mindfold-ai/Trellis)'s (AGPL-3.0) built-in spec template; the content is rewritten.</sub>

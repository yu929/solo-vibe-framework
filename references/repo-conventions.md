# Repository Conventions

The playbook's genre, the skill layout, and the writing rules that need more than a line.

## The playbook is for people, not a command file

This is the easiest thing in the repository to get wrong.

The playbook's reader is **somebody still learning this workflow**, and its product is a checklist they follow. It is not a draft of a command or an agent instruction file.

The reason is sequence, not taste. A command's reader is an AI; a manual's reader is a person learning the process. They are not two forms of one thing — they are two **steps**: the manual records what you actually did, and only the parts that survive a real run are worth freezing into a command. Writing the command first freezes a process nobody has run.

## Two scenarios, two layers

`playbook/` holds exactly two scenarios, one directory each: **`setup/`** (one-off installation) and **`build/`** (everything after it). There is no separate scenario for adding a feature or fixing a bug — both walk the same path as a new product and differ only in where they enter, so they are entries in `build/06-off-path.md` rather than scenarios of their own.

The sections are split across two layers, so nothing is written twice:

```
<scenario>/README.md
  ## 什么时候用这个场景   criteria, not description
  ## 开始之前             what must already exist
  ## <the whole picture>  the flow, the decision points, the things that recur

<scenario>/NN-*.md
  ## 步骤                 per step: what to type, what comes back, how you know it worked
  ## 我该在哪停下来看     the decision points of this step
  ## 常见卡点             traps, and how to get around them
```

**Use the sections a file actually needs; do not write an empty heading to complete the set.** Installation has no product decisions, so `setup/`'s numbered files carry steps and traps and skip the middle section.

**The full flow diagram and the table of decision points exist exactly once**, in `build/README.md`. The root `README.md` carries a one-line summary and a pointer — two diagrams at the same level of detail is how the previous version came to hold two mutually contradictory flows.

**Prompts sit inline, at the step that uses them, and every one is marked run or not run.** There is no separate cheat-sheet section: the same sentence stored twice drifts, and an empty "fill in after a real run" table carries no information the inline marker does not already carry. Inventing a prompt for a step nobody has done is precisely what this framework exists to prevent.

**Scope**: the playbook explains the *difference* between the Trellis default flow and what this framework adds. It does not restate Trellis. Day to day you just use Trellis; the manual covers only when you cannot go straight into Trellis, how to answer when Trellis asks whether to create a task, and where the decision points are.

**Stack commands stay out of it** — `pnpm`, `supabase`, `docker` and deploy commands belong in `specs/<track>/` and in each starter's own manual. The one exception is [`playbook/setup/`](../playbook/setup/README.md), whose whole subject is installing this thing, so `npm`, `trellis` and `ln -s` are its topic.

**Measured installer output and the source lines behind it belong in [`install-mechanics.md`](install-mechanics.md)**, not in `setup/`. The manual says what to do and what the failure looks like; the reference says why the machine behaves that way. Mixing them means re-reading a whole file to re-verify one line.

**Whenever you have to stop and ask "what am I supposed to do at this step?", that is a bug in the manual.** Add it to that file's 常见卡点 section while you still remember.

## Skill layout

```text
skills/<name>/
  SKILL.md                  # frontmatter + the main flow
  references/*.md           # full detail, loaded on demand
  assets/*                  # output templates
```

Three directories, matching the official `skill-creator` anatomy. A reviewer prompt is `references/`, not a fourth directory: it is read as a checklist as often as it is dispatched.

- Keep `SKILL.md` short and push detail into `references/`.
- **One rule, one definition.** Everywhere else points at it. Change the authoritative copy first.
- **A skill must not reference `](../../`.** Skills are symlinked or copied into `~/.claude/skills/`, where this repository's `specs/` is unreachable — a cross-directory reference arrives there as a dead link, and the skill degrades into a shell whose core rules the model fills in for itself. [`../scripts/test-skill-links.sh`](../scripts/test-skill-links.sh) enforces this, and that every other relative link resolves.
- Frontmatter limits are `name` ≤ 64 characters and `description` ≤ 1024, from `skill-creator`'s `scripts/quick_validate.py`. That script needs PyYAML, which the system `python3` here does not have — check the two lengths directly rather than installing a dependency for two numbers.

### Both of this repository's skills are user-invoked

`vertical-slicing` and `design-review` both carry `disable-model-invocation: true`, so their descriptions leave the model's context entirely and only a person can fire them. The reason is the same for each: **each runs about once per project, at a moment the person already knows they are at.** `design-review` is an escape hatch, and `vertical-slicing` sits at a fixed point in the 0-to-1 flow the manual walks you through.

The cost is that no agent can reach either one. That shapes how they are referenced: `specs/universal/guides/review-adjudication.md` §3 tells the agent to **name the signal and let the user pull the skill**, rather than reaching for it. Nothing in `specs/` points at `vertical-slicing` at all, so it needed no such change.

### A template's language follows its output

An asset is a template, and a template belongs to the document it produces. **The test is who reads the output and which repository it lands in**, never which skill the asset sits in.

| Asset | Output | Language |
|---|---|---|
| `vertical-slicing/assets/slices-template.md` | `docs/discovery/slices.md` in a project repository, read by the person deciding what to build next — product planning | **Chinese** |
| `design-review/assets/review-ledger-template.md` | An issue log carried across sessions, whose fields are English enum values (`ACCEPTED_BLOCKING`, `reopen_condition`) | **English** |
| `design-review/assets/review-report-template.md` | Conversational output: the admission verdict, read by the person deciding whether to build | **Chinese** |

Each file stays uniform inside itself, so `AGENTS.md`'s one-language-per-file rule is untouched. Mark the exception in the skill's own file table, so a reader following the pointer is not surprised.

**Conversational output counts as output.** The criterion asks who reads it, not whether it lands in a file — so a template producing text for a Chinese-speaking person is Chinese even though nothing is written to disk. That is also why such a template cannot be inlined into an English `SKILL.md`: a Chinese block inside an English file is the drift `AGENTS.md` forbids, so **the template earns a separate file on language grounds alone**, whatever its size.

The same skill can hold both languages in different assets, because the test is per output, not per skill: `design-review`'s report is Chinese while its log is English, and the reviewer's output format — a subagent handing findings to the main agent — stays English inside `references/reviewer-checklist.md` because its reader is another agent.

## Writing

**Language is uniform per file, not per directory.** An English paragraph inside a Chinese document is drift. Switching a whole file is a decision, after which the other set of rules applies to it.

Two writing skills divide by the **file's** language. Their trigger surfaces are fixed by their own descriptions and cannot be changed here:

| File | Skill | Triggers by itself |
|---|---|---|
| Chinese document | `tech-doc-style-chinese` (Fenng, MIT, installed in `~/.claude/skills/`, **not** vendored) | Yes, on branches like 中文技术文档 / Markdown 文档 / 操作手册 |
| English document an agent reads | `writing-for-agents` (vendored) | Only on skills, `AGENTS.md`, `CLAUDE.md` |

**Neither fires when you edit an English spec** — Fenng's branches are Chinese-only, and `writing-for-agents` does not list specs. Name `writing-for-agents` explicitly. Its description cannot be widened, because `vendor/` is read-only.

Three rules hold regardless of language:

- **Quotation marks inside code, commands, field names and annotation arguments stay exactly as they are.** `owner_id`, `@CrossUserQuery("理由")` and `"5432:5432"` are machine-readable content.
- **`id` and `owner_id` are field names.** They do not become `ID`.
- **Specs address the developer in the second person.** Keep it.

Chinese documents use `「」` for quotation. English documents use `"`, and a Chinese document quoting English text keeps the original punctuation.

### Fenng's linter runs per file, never over a directory

`~/.claude/skills/tech-doc-style-chinese/scripts/lint_copy_rules.py` has **no language detection**: it reports every visible `"` as needing a corner bracket. On an English file the output is entirely noise, so feed it Chinese Markdown only.

Four known false positives on Chinese files — **reported, and correct as they stand**:

| Reported | Why it is correct |
|---|---|
| `id` → `ID` | It is a field name; changing it changes code |
| Addressing the reader as 你 | Specs address the developer directly on purpose, and the skill says a project convention may override this |
| Quotes inside a bash fence nested in a blockquote | Its fence detection misses fences prefixed with `>` and reads the command line as prose |
| ASCII double quotes around an English verbatim quotation | A Chinese document quoting English keeps the original punctuation — Trellis's own wording, an upstream README, a spec's section name |

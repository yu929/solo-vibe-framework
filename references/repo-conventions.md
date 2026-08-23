# Repository Conventions

The playbook's genre, the skill layout, and the writing rules that need more than a line.

## The playbook is for people, not a command file

This is the easiest thing in the repository to get wrong.

The playbook's reader is **somebody still learning this workflow**, and its product is a checklist they follow. It is not a draft of a command or an agent instruction file.

The reason is sequence, not taste. A command's reader is an AI; a manual's reader is a person learning the process. They are not two forms of one thing — they are two **steps**: the manual records what you actually did, and only the parts that survive a real run are worth freezing into a command. Writing the command first freezes a process nobody has run.

Every scenario file has the same six sections:

```
## 什么时候用这个场景   criteria, not description
## 开始之前             what must already exist
## 步骤                 per step: what I type / what the AI produces / how I know it worked
## 我该在哪停下来看     the decision points
## 常见卡点             traps, and how to get around them
## 对 AI 说什么 · 速查  prompts, verbatim and copyable
```

**The last section holds only prompts that have actually been run.** Inventing a prompt for a step nobody has done is precisely what this framework exists to prevent; mark it "fill in after a real run" instead. A gap is honest.

**Scope**: the playbook explains the *difference* between the Trellis default flow and what this framework adds. It does not restate Trellis. Day to day you just use Trellis; the manual covers only when you cannot go straight into Trellis, how to answer when Trellis asks whether to create a task, and where the decision points are.

**Stack commands stay out of it** — `pnpm`, `supabase`, `docker` and deploy commands belong in `specs/<track>/` and in each starter's own manual. The one exception is [`playbook/00-setup.md`](../playbook/00-setup.md), whose whole subject is installing this thing, so `npm`, `trellis` and `ln -s` are its topic.

**Whenever you have to stop and ask "what am I supposed to do at this step?", that is a bug in the manual.** Add it to that file's 常见卡点 section while you still remember.

## Skill layout

```text
skills/<name>/
  SKILL.md                  # frontmatter (name/description) + the main flow
  references/*.md           # full detail, loaded on demand
  assets/*                  # output templates
  agents/<role>.md          # optional: a read-only reviewer prompt
```

- Keep `SKILL.md` short and push detail into `references/`.
- **One rule, one definition.** Everywhere else points at it. Change the authoritative copy first.
- Validate frontmatter and relative links with `skill-creator` after adding or substantially changing a skill.
- **A skill must not reference `](../../`.** Skills are symlinked or copied into `~/.claude/skills/`, where this repository's `specs/` is unreachable — a cross-directory reference arrives there as a dead link, and the skill degrades into a shell whose core rules the model fills in for itself. No check enforces this yet; it is listed in [`check-design.md`](check-design.md).

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

Three known false positives on Chinese files — **reported, and correct as they stand**:

| Reported | Why it is correct |
|---|---|
| `id` → `ID` | It is a field name; changing it changes code |
| Addressing the reader as 你 | Specs address the developer directly on purpose, and the skill says a project convention may override this |
| Quotes inside a bash fence nested in a blockquote | Its fence detection misses fences prefixed with `>` and reads the command line as prose |

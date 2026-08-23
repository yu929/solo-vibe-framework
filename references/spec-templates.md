# Spec Templates

Why the registry is shaped the way it is, and the mechanics behind each rule in `AGENTS.md`. Every claim here was measured against **Trellis v0.7.0-beta.3**; the version is pinned in `scripts/test-spec-injection.sh` and in `checks.yml`.

## A project installs exactly one template

`.trellis/config.yaml`'s `registry.spec.template` is a **single-valued** field. A second `init` replaces the whole line (`dist/utils/registry-config.js:121-126`), and from then on `trellis update` only refreshes whichever template was installed last (`dist/commands/update.js:469`).

**Nothing reports the loss.** The update succeeds, prints green, and silently stops refreshing half of what the project depends on.

That is why every track template ships its own `guides/`:

| Directory | What it is |
|---|---|
| `specs/universal/guides/` | The source of truth, and also the standalone `universal-guides` template for a project with no track spec yet |
| `specs/<track>/guides/` | A generated copy, produced by `scripts/sync-spec-guides.sh` |

**Edit the source of truth.** A direct edit to a generated copy is overwritten at the next sync, and `scripts/test-spec-templates.sh` reports it first.

## Coding rules live here, not in the starter

A track's rules follow its stack — which reads like an argument for keeping them in that stack's starter. It is not: rules that follow a stack are still **shared across every project on that stack**, so one copy per starter means N copies to keep in step.

The line falls between kinds of artifact, not between kinds of subject:

| Belongs here | Belongs in the starter |
|---|---|
| Coding rules, patterns, prohibitions, quality gates | Deploy scripts, CI config, the Dockerfile itself |

## Adding a track

1. Create `specs/<track>/` and write the rules — `frontend/`, `backend/`, whatever layering that track actually has.
2. Register one `type: spec` entry in `index.json`. Trellis returns a hard failure for any other type (`dist/utils/template-fetcher.js:828`), so registering one guarantees a failing entry on every `init`.
3. Run `scripts/sync-spec-guides.sh`. It derives the track list from `specs/` and needs no edit.
4. Run `scripts/test-spec-templates.sh` and `scripts/test-spec-injection.sh`.

## The injection budget, and what it does to a long spec

Injection is budgeted in **characters**, not bytes: 9,400 per spec and 9,500 per event (`dist/templates/shared-hooks/inject-spec-context.py:132-133`), sized under Claude Code's documented 10,000-character ceiling on hook output. Above that ceiling Claude Code replaces the whole payload with a preview and a file path, so **raising the budget makes delivery worse, not better**.

What happens to an over-budget spec is a **head cut**: the body is sliced to the cap and a line is appended saying it was truncated. That line does not say what is missing — and what is missing is the end of the file, where the `Pre-Development Checklist` and `Quality Check` sit.

Two consequences drive the layout rules:

- **Translation from Chinese roughly doubles the character count** while adding only ~20% bytes, because one Chinese character is one character and three bytes. Rewriting a spec in English can push it over the budget without looking any longer.
- **A truncated spec is re-taught in full forever** (`spec_inject.py:107`): the record is marked incomplete, so after the refresh window it competes for the budget again rather than settling into a one-line ticket.

## Which spec wins when several match

Matches are ordered by glob specificity and the budget is spent in that order. The sort key is `(exact?, -literal_segments, wildcard_count, -literal_length)` (`spec_match.py:373-378`), and **literal segment count is compared before wildcard count**. That produces one result worth knowing before designing globs:

```
(1, -5, 4, -30)   backend/src/main/java/**/config/**            ← directory narrowing wins
(1, -4, 2, -22)   backend/src/main/java/**                      ← the catch-all
(1, -4, 3, -38)   backend/src/main/java/**/*Repository.java     ← suffix narrowing loses
```

A suffix glob has the same literal-segment count as the catch-all above it and more wildcards, so **the catch-all takes the body and the narrow spec degrades to an index line**. Narrowing by directory works; narrowing by filename suffix does not.

Only the **first** matching glob in a spec's `paths:` list is scored, so the order of that list changes the outcome.

This is also why one layer declares `paths:` on exactly one file. Two specs matching the same edit share one 9,500-character budget, and the assembler truncates the second to whatever is left rather than dropping it — so "both arrived" is true while one of them is a fragment. `test-spec-injection.sh` asserts the match count instead, which is a structural fact rather than an arithmetic one that drifts as content grows.

## Links have to be verified against the install tree

Installation **flattens** the `specs/<id>/` level: `specs/web-fullstack/backend/index.md` becomes `.trellis/spec/backend/index.md`. So `../../universal/guides/x.md` resolves in the source tree and breaks once installed, and no ordinary link checker run in this repository will see it. `test-spec-templates.sh` case 1 maps each template into a temporary `.trellis/spec/` before checking, which is the only way to catch it.

The same flattening is why `](../../` is banned outright: a project installs one template, so a link that leaves the template can never resolve.

## Section numbering

Section numbers belong to the **layer**, not the file. When a section moves out of `index.md` into a sibling it keeps its number, so every existing `§N` reference still means the same thing — and the reference only has to gain a file designator.

`test-spec-templates.sh` case 4 resolves a `§N` by the nearest preceding `.md` designator, falling back to the same file. A bare `§4.2` in a file that no longer contains §4.2 therefore fails the check, which is what makes the designator requirement enforceable rather than a convention.

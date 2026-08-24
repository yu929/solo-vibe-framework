# Solo Vibe Framework — AGENTS

> Policy, router and execution contract for this repository — read it before changing anything here. It stays under 8,000 characters: anything longer than a rule plus its reason belongs in `references/`. The process itself is written for humans in [`README.md`](README.md).

## What this repo is

The **track-independent layer** of a Trellis workflow: a spec registry, general-purpose skills, and a playbook people follow. Trellis owns the task lifecycle, spec injection and the journal — point at those rather than rebuild them; [`references/third-party.md`](references/third-party.md) lists what it has.

Specs and process both belong here. One project's product content does not: its requirements, modules and rules live in that project's repository.

## Where things live

| Path | Reader | Holds |
|---|---|---|
| `specs/universal/` | agent, injected | Track-independent thinking guides — **the source of truth**; each track's `guides/` is generated from it |
| `specs/<track>/` | agent, injected | That track's coding rules, plus its generated `guides/` |
| `skills/` | agent | This repo's own skills |
| `vendor/` | agent | Read-only third-party skill copies |
| `playbook/` | **people** | Two scenarios — `setup/` and `build/` — as checklists to follow; templates ship with their skill |
| `references/` | people, agents via pointer | Background a rule cannot carry |
| `scripts/` | people | Install, sync, guides distribution, five `test-*.sh` |
| `.github/workflows/` | CI | The five checks, plus the nightly vendor-drift PR |
| `index.json` | Trellis CLI | Registry manifest |

## Spec templates

A project installs **exactly one** template: `registry.spec.template` is single-valued, a second `init` replaces it, and nothing reports the loss. Hence the generated `guides/` per track.

- **Declare `paths:` so that any one edited file matches exactly one spec.** For a layer governing a single source tree that means the globs live on its `index.md` alone; where globs genuinely cannot overlap, as in `guides/`, separate files may each carry their own. Two specs matched by one edit share a single per-event budget, and the loser is truncated rather than dropped.
- **Give every track an `ops/` layer.** Source-tree globs leave `application.yml`, compose, `Dockerfile`, build config and release workflows matching no spec, while the rules governing them sit inside other layers — reachable only by someone already reading those. `ops/index.md` owns those paths and points back at each rule's other half.
- **Give a sibling that declares no `paths:` no frontmatter at all.** Trellis skips a spec without `paths`, so a `name`/`description`-only block does nothing while looking like it does.
- **Keep every `index.md` under 9,000 characters.** Injection budgets by character, and an over-budget spec is head-truncated: the checklists at its end never arrive, and nothing errors.
- **Extract the largest section first and stop when the core fits.** Going further buys a pointer and a jump for nothing.
- **Name the file in every reference that crosses a file** — a bare `§N` resolves to its own file. Sections split out of one `index.md` keep that layer's numbering (`backend/` runs §1–§10 across five files); files that were always separate number from §1 each (`frontend/`'s three do). Say which one the layer uses, in its `index.md`.
- **Link only within a template.** `](../../` breaks on install: `specs/<id>/` is flattened away.
- **Register `type: spec` and nothing else.** Trellis fails outright on other types.

Adding a track: create `specs/<track>/`, register one entry, run `scripts/sync-spec-guides.sh`, then the two spec checks. Budgets and glob ranking: [`references/spec-templates.md`](references/spec-templates.md).

## Writing

- **Keep each file in one language throughout.** Chinese for product requirements, business rules, manuals and the root `README.md`; English for agent instructions, specs, workflows and conventions. A whole-file switch is a decision; one paragraph in the other language is drift. **A template follows the language of the document it produces, not of the skill it sits in** — so a Chinese asset inside an English skill is correct.
- **Name `writing-for-agents` explicitly when editing an English spec** — no writing skill triggers there by itself.
- **Write the playbook as a checklist a person follows**, in two layers: a scenario `README.md` carries when to use it, what must exist first, and the whole picture; each numbered file carries steps, decision points and traps. **Mark every prompt as run or not run** — an invented prompt is the thing this framework exists to prevent. That layering, the skill layout and the Chinese linter's false positives: [`references/repo-conventions.md`](references/repo-conventions.md).
- **Keep install mechanics out of the playbook** — measured installer output and the source lines behind it go to [`references/install-mechanics.md`](references/install-mechanics.md); `playbook/setup/` keeps what to do and what the failure looks like.

## Third-party code

- **Treat `vendor/` as read-only** — a local edit makes the upstream diff meaningless, and this repo's skill conventions do not apply.
- **Keep the upstream `LICENSE`.** MIT requires it in a redistributed copy, which `vendor/` is.
- **Read the diff before following upstream** — `scripts/sync-vendor.sh` reports, `--pull` applies.
- **Retiring or reinstating a vendored skill touches several files at once** — most quietly `sync-vendor.sh`'s `SKILLS` array, which is how drift detection enumerates what it watches. Both lists: [`references/third-party.md`](references/third-party.md).

## Four sources of truth

| Subject | Home |
|---|---|
| Requirements and acceptance | the complete PRD, then the slice's `prd.md` |
| Terminology | `CONTEXT.md` |
| Decisions with a trade-off | `docs/adr/` |
| Interface and interaction structure | the approved hi-fi in `design-system/screens/`, plus `design-system/MASTER.md` |

- **Write back at a phase boundary only, as a delta** — ADDED / MODIFIED / REMOVED, edited into the prose. Appending "the section above is obsolete" turns a description into a changelog.
- **Keep track vocabulary out of the track-independent layer.** RLS, Server Actions, Maven and DDD belong in `specs/<track>/`; `playbook/`, `skills/` and `specs/universal/` hold on any stack.
- **Change a project's own `.trellis/workflow.md` to change its process** — a paragraph, not a fork, never a `type: workflow` template.
- **Leave `docs/discovery/` free of approval fields.** Nothing reads them, so they are decoration; the real gate is the Trellis one.
- **Do requirements and the prototype in full; deliver implementation slice by slice.** That trade-off and the review split: [`references/decisions.md`](references/decisions.md).

## Checks

| Script | Guards |
|---|---|
| `test-install-skills.sh` | Retirement removes symlinks, and only ones this framework installed |
| `test-sync-vendor.sh` | Vendored content equals the pinned upstream, by offline checksum |
| `test-spec-templates.sh` | Install-tree links, guides match source, `§N` hits a real section, frontmatter has `paths` or nothing |
| `test-spec-injection.sh` | What an edit delivers: the expected core ranks first, whole and alone |
| `test-skill-links.sh` | No `](../../` inside a skill, and every relative link resolves |

**Add a check alongside any new cross-file rule, inject a matching bug to prove it goes red, and wire the script into `checks.yml`** — a green run against the real repo proves nothing on its own, and a check nobody runs is the defect it was written to prevent. Traps, and the two checks still to build: [`references/check-design.md`](references/check-design.md).

**Write shell for bash 3.2**: no `readarray`, `mapfile`, `declare -A`. Reach for `python3` on multi-byte text, where BSD and GNU `grep` disagree.

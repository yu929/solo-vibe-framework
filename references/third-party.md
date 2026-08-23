# Third-Party Dependencies

> **What we do not install matters as much as what we do.** Every "not installed" entry carries its reason — a ban with no reason gets overturned by its own author six months later, who then walks into the same trap again.
>
> Verified 2026-08-21 (the vendor decisions and the table of measured facts). When upstream changes, come back and fix this file rather than patching around it elsewhere.

## The foundation: Trellis

```bash
npm install -g @mindfoldhq/trellis@latest
trellis init -u <your-name>
```

Requires Node ≥ 18 and Python ≥ 3.9. Licensed **AGPL-3.0**.

### We do not fork it

Trellis officially recognizes four reasons to fork: sending it a PR, changing what the npm package publishes, changing what `trellis init/update` generates, or explicitly wanting a fork. None applies.

Every customization lands locally, with no fork needed:

| What you want to change | Where it lands |
|---|---|
| Phases, next-step prompts, whether to create a task, skill routing, custom states | The target project's `.trellis/workflow.md` (one file; no rebuild, effective next session) |
| Coding conventions | `.trellis/spec/` |
| Runtime scripts such as `task.py` | They are generated into the project — edit them directly |

What a fork actually costs: Trellis is a pnpm monorepo (`packages/cli` + `packages/core` + two submodules + husky + pyright). Forking means maintaining a mixed TS/Python build, and **you can no longer take upstream updates with `npm install -g`**.

**This repository does not publish a `type: workflow` template.** Running it showed that such a template replaces `.trellis/workflow.md` wholesale — the official marketplace entry is literally `path: workflows/native/workflow.md` — which means taking over the entire Plan/Execute/Finish text. The reason is not that the cost is unacceptable: `trellis workflow create <id>` **derives from native** (`dist/cli/index.js:224-227`, written to `.trellis/workflows/<id>.md`), and `trellis workflow -s <id>` can store a template in that library without touching the active workflow, so merging later is less painful than it sounds. The reason is that **this flow has never been run even once**, and writing it now would freeze a guess.

> Do not confuse `-s/--save <id>` with `-n/--create-new`: the first writes `.trellis/workflows/<id>.md` (the per-task template library), the second writes `.trellis/workflow.md.new` (a pending-merge copy of the active workflow). Run it once to learn where it should be gated, then decide.

#### Workflow variants: measured (2026-08-13, v0.7.0-beta.3)

**"Merging later is less painful than it sounds" turned out to be wrong, and this is the correction**: what `trellis workflow create <id>` produces is a **verbatim full copy** of the native `workflow.md` — 709 lines, 38 KB, `diff` reports no difference — not a difference layer. Creating one takes over the whole Plan/Execute/Finish text, and every upstream change from then on has to be diffed back by hand. **The conclusion is unchanged (still not published, still not created), but there are now two reasons**: the flow has never been run, and the cost is higher than first estimated.

Resolution order (from the docstring of `scripts/common/workflow_selection.py`, verified layer by layer):

| Layer | Where it lands | Committed |
|---|---|---|
| 1 | The active task's `workflow` field in `task.json` (`task.py create --workflow <id>` / `task.py workflow <id>`) | Yes |
| 2 | `workflow=<id>` in `.trellis/.developer` | **gitignored, per-person** |
| 3 | `default_workflow` in `.trellis/config.yaml` | Yes |
| 4 | `.trellis/workflow.md` | Yes |

**The measured conclusion that matters most here: during requirements discovery (`no_task`) layer 1 is unavailable, while layer 2 still works.** Both official documents lead with the per-task pin, but the brief stage **has no task**, so that layer does not participate in resolution at all. Measured: with the active task cleared and only `.developer`'s `workflow=` set, the per-turn breadcrumb reads that variant's `[workflow-state:no_task]` block.

So the only mechanism for "a custom flow during requirements discovery" is layer 2 — **and that is gitignored per-person configuration, not shared across projects**. This is the additional reason this repository does not go that way: the benefit of the customization lands somewhere undistributable.

When the brief stage genuinely needs extra rules for the agent, **reach for the two much lighter things below** before touching the workflow.

Until then, the needed prompt text is pasted by hand into `[workflow-state:no_task]` — see step 5 of [`../playbook/00-setup.md`](../playbook/00-setup.md).

### Measured: what it provides, and what it does not

> Local version **v0.7.0-beta.3**. Every row has a source; when upstream changes, come back and fix this.

| Fact | Source | Consequence here |
|---|---|---|
| `trellis-brainstorm` already converges requirements, and has a hard gate: no `task.py start` without explicit approval of the planning summary | `.agents/skills/trellis-brainstorm/SKILL.md` | **Do not invent a second gate**; attach the prototype ahead of it |
| Its precondition is that task-creation consent has been given — it runs `task.py create` first and asks afterwards | Same file, Preconditions | Before a task there is a vacuum: that is where the brief goes |
| *"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* | Same file | Trellis **deliberately** leaves the product layer to you |
| It enforces **one question per message** ("Ask only one question per message") | Same file, Question Rules | See "Two questioning disciplines collide" below |
| `.trellis/spec/` means *"Maintain coding standards"*, and its directories are only frontend, backend, unit-test and guides | `trellis-meta/references/core/specs.md` | **Coding rules only, zero product content**; there is no `architecture/` either |
| `finish-work` is four steps: `get_context.py --mode record` → `git status` → `task.py archive` → `add_session.py` | `.agents/skills/trellis-finish-work/SKILL.md` | Archiving plus a journal, **zero product questions**, and task-scoped |
| The workflow-state hook is **parser-only** (*"reads whatever you put in the block"*) | `trellis-meta/references/customize-local/change-workflow.md` | Any "gate" of your own is only prompt text |
| **`--registry` accepts `type: spec` only and returns failure for anything else** | `dist/utils/template-fetcher.js:828` | `index.json` registers that type alone |
| **`no-trellis` is a built-in escape hatch**: a prompt containing that standalone word (word-boundary match, so `no-trellisfoo` does not count) suppresses that turn's breadcrumb entirely; SessionStart and sub-agent injection are unaffected | `prompt_injection.skip_keyword` in `config.yaml`, **measured: injection was empty** | The right answer when writing a brief and being asked repeatedly whether to create a task — see the pitfalls in [`../playbook/01-new-product.md`](../playbook/01-new-product.md) |
| **Spec injection is triggered by the frontmatter `paths:` globs, and a glob is not restricted to code paths** | Measured: a spec with `paths: ["docs/discovery/**"]` is matched by `get_context.py --mode spec --file docs/discovery/slices.md`; the control case `src/a.ts` is not | For adding rules to requirements discovery, this is **an order of magnitude lighter than a workflow variant**: one file, distributed with the registry, shared across projects |
| **`paths: [".trellis/tasks/**"]` matches too** — a glob can point at Trellis's own artifact directory | Measured 2026-08-21: in a temporary project, after `task.py create`, `get_context.py --mode spec --file .trellis/tasks/08-21-probe/prd.md` matched that spec; `src/a.ts` did not | This is how `specs/universal/guides/task-artifacts.md` is injected automatically when an agent touches task artifacts |
| **A spec with no `paths:` does not take part in path routing** — it is reached through the `guides/index.md` pointer instead | `scripts/common/spec_match.py` accepts only files whose first line is `---`; `spec_inject.py` handles only a `SpecMatch` | Two delivery channels coexist: **what must appear at a specific moment** gets `paths:`, **what is consulted on demand** stays in the index |
| **On the Claude Code side the injection is PostToolUse** (on Codex it is PreToolUse, with a deny-once that makes the model re-read) | The Triggers section of `shared-hooks/inject-spec-context.py` | "Read before writing" is **not guaranteed** on Claude Code — which is why `task-artifacts.md` also has a `workflow.md` prompt as a backstop |

The five rows below come from the **first complete run** (2026-08-16: one slice taken through Plan/Execute/Finish and archived):

| Fact | Source | Consequence here |
|---|---|---|
| **`trellis-update-spec` does not know whether a spec was installed from somewhere.** The whole file never mentions a registry, a source repository or upstream; it only writes `.trellis/spec/` | That SKILL.md in full (357 lines) | For a registry-installed spec, **nothing enforces writing back to the source of truth** — the rule can only live in the table in [`../specs/universal/guides/review-adjudication.md`](../specs/universal/guides/review-adjudication.md) |
| **Phase 2 runs straight into Phase 3.** The only stop for user input is the commit plan in 3.4 (*"Present the plan once, ask for one-shot confirmation"*) | `workflow.md` 3.4 step 5 | **There is no slot for human acceptance**; it has to be inserted by hand after the checks. That is where sign-off 5 comes from |
| **3.4's dirty-file classification depends on session memory**: it splits them into "AI-edited **this session**" and "Unrecognized" | `workflow.md` 3.4 step 3 | **Do not switch sessions between implementing and committing** — after a switch every file becomes "unrecognized" and that commit plan is worthless |
| **Switching sessions is resumed through a single-file fallback**: `.trellis/.runtime/sessions/` must contain **exactly one** file; zero or two or more returns "no active task" (the source comment says it *refuses to guess across windows*) | `scripts/common/active_task.py:599-621` | Serial work in one window is seamless; **two windows open on the same repository loses the active task on a session switch** |
| **`task.py start` validates no artifacts** — it resolves paths, writes a pointer and flips state, without checking whether `prd.md` exists or whether the jsonl was filled in | `scripts/task.py`, `cmd_start` | It follows that **`start` is not the way to repair a missing pointer**: it also flips `planning` to `in_progress`, skipping the start gate without reporting anything |

**It follows that Trellis alone never shows the product as a whole.** After fifty tasks you have a pile of coding rules, a pile of archived one-off changes and one timeline, and nowhere that answers "what is this product, overall, right now". So the full PRD and `docs/discovery/slices.md` **are not consumables** — they are the only hosts at that level, updated with the phase goal and never deleted at a release.

### Four distribution mechanisms (the easiest thing here to get wrong)

They all look like "install something", and their destinations and mechanisms are entirely different:

| What is installed | Installed by | Lands in |
|---|---|---|
| **One** `specs/<track>` (which brings its own guides) | `trellis init --registry ... --template <id>` | The project's `.trellis/spec/` |
| **This repository's own skills plus the vendored ones** | **`scripts/install-skills.sh`** (global symlinks) | `~/.claude/skills/` |
| Trellis's bundled skills | `trellis init --claude` | The project's `.claude/skills/` |
| Workflow templates | `--workflow` / `--workflow-source` / `trellis workflow` | The project's `.trellis/workflow.md` |

**A registry template's path layer is flattened**: the **contents** of `specs/<id>/` are copied into `.trellis/spec/`, and the `<id>/` layer is not preserved. So `specs/web-fullstack/frontend/index.md` becomes `.trellis/spec/frontend/index.md` — which happens to be Trellis's own directory convention — and **not** `.trellis/spec/web-fullstack/frontend/index.md`.

#### A project can install only one spec template

**Running init a second time to append a template silently cuts off updates to the first one.** The source evidence:

| Fact | Source |
|---|---|
| `registry.spec` in `.trellis/config.yaml` has only a **singular** `template` field | `dist/utils/registry-config.js:12-18` |
| `writeSpecRegistryConfig` **replaces the whole line** when it finds an existing `template:` | Same file, `:121-126` |
| Every init carrying `--template` writes that config | `dist/commands/init.js:1384, 1512` |
| `trellis update` reads that **one** id from `config.template` to refresh | `dist/commands/update.js:469, 505, 510` |

So after installing the track spec and then `universal-guides`, `trellis update` refreshes only the guides from then on, and **the track spec — the one with the security rules — never receives another fix**. Meanwhile the update command still succeeds and still prints in green, which is how it stays hidden.

**The approach: the track template brings its own guides, and init runs once.** `specs/<track>/guides/` is a generated copy of `specs/universal/guides/`, synced by `scripts/sync-spec-guides.sh` and held against drift by `scripts/test-spec-templates.sh`. The `universal-guides` template still exists, but its purpose narrowed: **it is installed only by projects that have no track spec**, and never alongside a track template.

That also fixed a broken link that only appeared once installed: with `<id>/` flattened, `../../universal/guides/x.md` resolves to `.trellis/universal/guides/x.md`, which does not exist. With guides as a sibling of the track rules, `../guides/x.md` **means the same thing in the source tree and in the installed tree**. Any ordinary link check run inside the repository is green against this class of defect, which is why it has to be checked against the installed tree — that is what case 1 of `test-spec-templates.sh` does.

**Why the registry cannot install a skill** — `dist/utils/template-fetcher.js:828`:

```js
// Only support spec type in MVP
if (resolved.type !== "spec") {
    return { success: false,
      message: `Template type "${resolved.type}" is not supported yet (only "spec" is supported)` };
}
```

`INSTALL_PATHS` at `:18` in the same file does contain `skill: ".agents/skills"`, but the type gate comes first, so that line is dead code. Even if upstream opened it up, the destination would be the **project's** `.agents/skills`, not `~/.claude/skills/` — a skill shared across projects would still need a symlink. `dist/configurators/claude.js:96` writes to the project's `.claude/skills/`, but installs only Trellis's own bundled skills.

**So `index.json` registers `type: spec` only** — currently three entries: `universal-guides`, `web-fullstack` and `java-stack`. Adding skills becomes possible only once upstream supports non-spec types.

### Two questioning disciplines collide

| Source | Rhythm | Stopping rule |
|---|---|---|
| Trellis `trellis-brainstorm` | **One question at a time** | The user explicitly approves the planning summary |
| mattpocock `grilling` | The whole frontier in one round | The frontier is empty (unbounded) |

**This repository takes Trellis's**, because it is mandatory during planning and a second discipline would only work against it. `grilling` is still useful — during **writing the brief**, before a task exists and before brainstorm is in play, where the frontier makes one round more complete.

The bet is that **every question brainstorm asks is one the brief was missing, so filling the brief makes the next slice noticeably shorter** — its Evidence Rule already requires not asking the user what the repository's documents can answer. **This is a prediction; come back and correct it after a real run.**

### `trellis update` cuts both ways

`.trellis/.template-hashes.json` records each generated file's SHA256, and `update` uses it to recognize local changes and **not overwrite files you have edited**.

The other side: **upstream improvements to a file you have edited never reach you either.** So a periodic diff review is needed, scoped to `workflow.md` and `spec/guides/` — not the whole tree.

To keep an escape route, fork a **read-only mirror** — never edited, never published — purely for diffing and reading source. Zero maintenance.

## mattpocock/skills — six of them, already vendored

### Installed

| Skill | What we take from it | Dependencies |
|---|---|---|
| `grilling` | Design tree plus frontier-based batched questioning: one round covers the whole frontier, questions are numbered and **each carries a recommended answer**, anything blocked on an open question moves to the next round, and "Finding facts is your job, never the user's" (environment facts are looked up by a sub-agent, never asked of the user) | None |
| `grill-me` | A thin user-invocable shell (`disable-model-invocation: true` plus one line, `Run a /grilling session`) | Depends on `grilling` |
| `grill-with-docs` | Grilling while writing terminology and decisions to disk. **The whole file is one line**: `Call the Skill tool twice, for "grilling" and "domain-modeling"` | **Hard dependency on `domain-modeling`**; without it the second call points at nothing |
| `domain-modeling` | The `CONTEXT.md` glossary (*"a glossary and nothing else"*), `docs/adr/`, and **the original text of the three ADR criteria** | None |
| `prototype` | **The LOGIC branch only**: build a single shareable HTML file to answer "is this logic or state model right", pushing the state machine through cases that cannot be reasoned about on paper, drivable by a non-developer | None |
| `writing-for-agents` | The meta-rules for documents an agent reads: a context pointer's wording decides how reliably it fires, the two load budgets, the information hierarchy and progressive disclosure, a completion criterion's clarity and demand, leading words | A sibling `SKILL-MECHANICS.md` |

**Its stopping condition is "the frontier is empty", which is unbounded.** This repository puts no round cap on questioning.

**So what makes it converge during the PRD stage?** Its own two rules: stop when the frontier is empty, and *"Finding facts is your job, never the user's"*. That step is outside any task, before Trellis's brainstorm is in play, so there genuinely is no external gate — **and that is accepted deliberately**: questions not asked during requirements get paid for again in every slice that follows. What genuinely needs bounding is walkthrough rounds and option selection, and those two disciplines now live in `skills/vertical-slicing/` and in the conventions for using `ui-ux-pro-max`.

**The three ADR criteria** — hard to reverse, confusing without context, and a genuine trade-off; all three must hold before writing one — **live in the upstream original**, `vendor/mattpocock-skills/domain-modeling/SKILL.md`. This repository once maintained a transcription (`playbook/assets/decisions-template.md`), deleted on 2026-08-21 along with reinstalling `domain-modeling`: **one set of criteria in two places will diverge**. Changing the criteria means changing how they are used, never the original, because `vendor/` is read-only.

### Explicitly not installed

| Not installed | Reason |
|---|---|
| **`setup-matt-pocock-skills`** | What it configures is exactly the issue tracker and its label vocabulary. **The upstream README says to install it; we must not** |
| **`to-spec` itself** | Step 3 of its SKILL.md requires publishing to an issue tracker and applying a `ready-for-agent` label, and requires `setup-matt-pocock-skills` to have run first |
| **`to-tickets`** | **Criteria updated 2026-08-21**: upstream now has a local-file mode (`.scratch/<feature>/issues/<NN>-<slug>.md`) and `disable-model-invocation: true`, so only the user can invoke it and it never grabs control on its own. The conflict is **reduced but not gone** — `.scratch/.../issues/` and `.trellis/tasks/` are still two task systems. **The conclusion is unchanged; the reason has been replaced.** Its four disciplines are borrowed below |
| `tdd` / `code-review` / `triage` | All built on the issue-tracker workflow |
| **`planning-and-task-breakdown` from `addyosmani/agent-skills`** (MIT, 2026-08-14) | Three reasons: ① `tasks/plan.md` plus `tasks/todo.md` is a second task system, and it states outright that `/build` and downstream tools expect that path ② **its granularity is anchored on file count** (≤5 files), while a genuine vertical slice — table, migration, service, route, page — starts at five files, so its table judges one M or L and pushes you toward horizontal slicing ③ its `## See Also` references `../../references/definition-of-done.md`, and **a cross-directory reference breaks once installed into `~/.claude/skills/`** |

**Their disciplines are still worth borrowing**, just not their code.

**Two from `to-spec`**, which still hold for writing `prd.md` and `design.md`:

- Do not write out specific file paths or code fragments; they go stale quickly. The exception is anything more precise than prose: a schema, a state machine, a type shape.
- Synthesize only what is already agreed; do not raise new questions — those were asked during grilling.

**Four from `to-tickets`**, all of which landed in this repository's `skills/vertical-slicing/`:

| Borrowed | Why it is valuable |
|---|---|
| **The size anchor is one fresh context window** (*"sized to fit in a single fresh context window"*) | The criteria this repository already had answer "is this a slice", not "is it the right size". This anchor is better than file count or hours — Trellis's implementation really is a sub-agent running in a fresh context |
| **A wide refactor is an explicit exception to vertical slicing, handled with expand–contract** | A mechanical change spread across the whole repository cannot be cut into vertical slices, and forcing it makes every slice red. The criteria this repository already had judge it "not a slice" and then **say nothing further** |
| **Blocking edges plus a frontier, instead of an ordered list** | Each slice declares what blocks it, and the frontier is every slice whose blockers are all complete. More precise than a "dependencies" column, and it fills exactly the hole Trellis leaves (*"Parent/child structure is not a dependency system"*) |
| **Step 4, "Quiz the user"** | A numbered list, three questions — granularity, blocking edges, merge or split — iterated to approval. That is precisely the shape sign-off takes here |

**One from `addyosmani`**: **a title containing "and" describes two tasks** — a zero-cost, decidable signal for splitting. Its size table is not borrowed; that anchor is wrong.

**What is not borrowed is the publishing step**: the publishing targets here are `docs/discovery/slices.md` (the slice map) and `.trellis/tasks/<task>/prd.md`, not an issue tracker and not `tasks/todo.md`.

### How they are installed: vendored here, not through the upstream installer

**All six skills already sit in [`../vendor/mattpocock-skills/`](../vendor/mattpocock-skills/)**, and `scripts/install-skills.sh` symlinks them into `~/.claude/skills/` along with this repository's own. There is no need to run `npx skills add`.

**Why vendor rather than install a copy per project:**

| | The upstream installer | Vendored here |
|---|---|---|
| Destination | **The project repository** (upstream README: *"It writes the skills into your repo"*) | `~/.claude/skills/`, one global copy |
| With N projects | N copies, N runs of `npx skills update` | One |
| Chances to get it wrong | Two picked out of forty, with **the installer explicitly telling you `setup-matt-pocock-skills` is required** (*"make sure `setup-matt-pocock-skills` is one of them"*) — and we must leave it unchecked | Zero |
| Consistency with this repository's own skills | Inconsistent: half in the project, half global | Consistent |

These follow the **process**, not the tech stack, so they belong across projects to begin with. The tree is about 96 KB across 20 files, so the diff cost is negligible.

**The rules:**

- `vendor/` is a **read-only** copy; edit it and it can no longer be diffed against upstream. The version is pinned in `vendor/mattpocock-skills/.upstream-sha`.
- **`.upstream-manifest` is what detects drift** — one sha256 line per managed file. Why comparing `.upstream-sha` alone is not enough: that sha does not change by a single character when a file is edited by mistake, deleted by mistake, or when a new file is dropped in, so watching it alone reports drift as "already up to date". The manifest makes this check **offline**, which is what makes it testable in regression (`scripts/test-sync-vendor.sh`) — a check that depends on the network is flaky and cannot be a test.
- **The upstream LICENSE must be kept** (`vendor/mattpocock-skills/LICENSE`, MIT). This is not a courtesy but a redistribution condition: MIT requires that copies and substantial portions retain the copyright and licence notice, and `vendor/` is a copy. `scripts/sync-vendor.sh` hard-asserts that the file exists at startup and exits 1 without it — remembering is not enough.
- When upstream changes the LICENSE, the sync script prints the diff. **That diff gets read separately**: changed licence terms can mean vendoring is no longer permitted, which is not an ordinary content change.

**Following upstream:**

```bash
scripts/sync-vendor.sh --verify   # local drift only, fully offline (this is what CI and the tests run)
scripts/sync-vendor.sh            # drift plus a report of upstream differences; changes nothing
scripts/sync-vendor.sh --pull     # update only after reading the diff and deciding to follow (also rebuilds the checksum manifest)
```

**Drift is checked before upstream, and the order cannot be reversed.** "Someone changed this locally" and "upstream moved forward" are two different things, and mixing them into one diff makes neither readable — so read-only mode stops outright while drift exists, and does not compare against upstream.

Read-only by default is deliberate: automatically following upstream lets somebody else's changes alter your workflow without your knowing. **The nightly GitHub workflow holds the same line** — it only opens a PR and never merges; see "Following upstream" at the end of this file.

**The two upstream installation methods cannot be combined either** (upstream README: *"Pick one — installing both leaves you with every skill twice."*). If you installed one previously, remove it before running this repository's script:

```bash
# claude plugins install mattpocock-skills   ← managed, read-only, all of them, no way to pick
# npx skills@latest add mattpocock/skills    ← copies into the project repository, per-repo
```

**Whether `grilling` is still needed has not been settled by a real run.** This repository has decided to take Trellis's questioning discipline (see "Two questioning disciplines collide" above), and Trellis's brainstorm already has two of grilling's core ideas — the Evidence Rule, and a recommended answer per question — leaving only frontier batching versus one question at a time. So grilling's net addition is down to **batched questioning during the step that produces the full PRD, before brainstorm is in play** — real, but narrow.

**Under the current flow that net addition grew slightly**: the first four steps of 0-to-1 — discussing requirements, the full PRD, verifying fields, writing back — are all outside any task, and `grill-with-docs` has no competitor there. Decide whether to keep it after running one full PRD for real. If it is not needed, delete `vendor/mattpocock-skills/<name>/`, remove it from the `VENDORED` array in `scripts/install-skills.sh`, **and add it to the `RETIRED` array** (otherwise the existing symlink stays and keeps being triggered), and remove it from the `SKILLS` array in `scripts/sync-vendor.sh`.

### `domain-modeling`: retired once, reinstalled 2026-08-21

**It was deleted outright at one point**, because it requires maintaining `CONTEXT.md` as the source of truth for terminology, while this repository's terminology conclusions then lived in the product brief. Both claimed to be authoritative, so one ordinary discussion about terminology could produce two mutually drifting sources of truth.

**It came back because `grill-with-docs` depends on it**: that upstream skill is one line, `Call the Skill tool twice, for "grilling" and "domain-modeling"`, and without it the second call points at nothing.

There are now **two** conflicts, where the original record listed one:

| What it produces | What this repository once had | Conflict |
|---|---|---|
| `CONTEXT.md`, with terminology required to be updated **immediately** on a decision rather than batched | §5 "Wording" in the brief | Two sources of truth for terminology |
| `docs/adr/` plus the three criteria | `docs/discovery/decisions.md` plus **the same three criteria**, transcribed from it | Two homes for decisions, plus a transcription |

**The resolution: this repository yields.** The reason is mechanical rather than "upstream is better" — when it was first judged, three paths were listed, and "edit the vendor original so it writes somewhere else" was rejected for **violating vendor read-only**. That reason holds unchanged today. Since it is being installed, its destinations have to be accepted.

- **Terminology's source of truth is `CONTEXT.md`.** The full PRD's terminology section **points at it** rather than keeping its own copy.
- **Decisions' source of truth is `docs/adr/`.** `docs/discovery/decisions.md` and `playbook/assets/decisions-template.md` **have been deleted**, and the three ADR criteria — hard to reverse, confusing without context, a genuine trade-off, all three required — go back to the upstream original at `vendor/mattpocock-skills/domain-modeling/SKILL.md`. This repository no longer maintains a transcription.

**The cost, stated plainly**: `decisions.md` was added on 2026-08-13, because measurement confirmed that none of Trellis's four candidate hosts records "what was rejected and why". Switching to `docs/adr/` **still satisfies that need** — an ADR is exactly what records it — with the host and the format now upstream's. **The need survives, the host changes**, and there is one fewer source of drift.

**To retire it again**: first settle what happens to `grill-with-docs` (retire it too, or write a shell that calls `grilling` only), then follow "retiring a vendor skill touches four places".

### `prototype`: the LOGIC branch only

This upstream skill has two branches, and **its first step is "Pick a branch"**:

| Branch | Output | Here |
|---|---|---|
| **LOGIC** (*"Does this logic / state model feel right?"*) | One shareable HTML file, a free-play button plus a paginated guided walkthrough, pushing the state machine through cases that cannot be reasoned about on paper | **Used** — it is the 0-to-1 step "throw a prototype at each module to verify fields" |
| UI (*"What should this look like?"*) | Several variants on real project routes, switched by a URL search param | **Not used** — that belongs to `ui-ux-pro-max`. Both answer "what should this look like", but one opens variants inside the real project while the other produces full hi-fi plus a design system, and mixing them grows two sources of visual truth |

**This discipline is prompt text, not an enforcement.** The skill is installed whole, and no mechanism stops it choosing the UI branch. When it does, pull it back on the spot and record how it actually behaved here.

**Its rule 1 and rule 6 once collided with this repository's exploration discipline** (*"Locate the prototype code close to where it will actually be used"* and *"commit it to a throwaway branch"*, against "never in `src/`, delete it once verified"). **Under the current flow that conflict is gone**: field verification happens at step 3 of the 0-to-1 flow, before step 6 picks the backend track — at which point there is no `src/` yet.

## spec-anchor — not installed at all

[`linziyanleo/spec-anchor`](https://github.com/linziyanleo/spec-anchor): 375 files, 7.2 MB, 23 shell scripts, 12+ commands, 82 tests, 54 reference documents.

It is **a competitor to Trellis, not a complement**. Two spec systems means two sets of commands, two documentation trees and two places tasks are recorded — unmaintainable solo.

It is not badly built; it is considerably more rigorous than Trellis, with schema validation and tests. The problem is that **it is built for a much larger scale**: several people, several modules, long-term evolution. Two pieces of evidence from **its own repository**:

1. Its `.specanchor/module-index.md` shows both of its own modules as `DRIFTED` — drift detection works correctly, reporting the drift accurately, and nobody fixed it. For solo work, installing a dashboard whose warning light is permanently on is negative value: either you fix it (a cost) or you learn to ignore it (and then it does nothing).
2. Its own finding `F-20260530-001` records that boot and assemble re-emit the global summary on every call, so several activations in one session **grow the context linearly**. A system for managing context, producing context bloat.

### But two concepts are borrowed (the concepts only, never the implementation)

| Concept | Where it lands | Restraint |
|---|---|---|
| **Layered findings**: a discovery made while coding becomes a finding first, and is promoted into the spec only after confirmation; an AI never edits the spec directly | `specs/universal/guides/review-adjudication.md` | **Four fields only** — observed, evidence, which spec should change, status. The original has 11 frontmatter fields plus 6 sections, which is a much larger scale |
| **A module coverage index**: which modules have a spec, which do not, and when each was last synced | Undecided; **it has no host yet** | When it lands it is a hand-maintained three-column table, **not those 23 scripts** |

## Retired (their symlinks need removing)

These skills from the old `~/Developer/skills` repository are retired. **A leftover symlink in `~/.claude/skills/` keeps triggering them** — the classic consequence is describing a requirement and having the old PRD skill pick it up and run an abandoned flow.

| Retired | Where its capability went |
|---|---|
| `product-brief` | Downgraded to [`skills/vertical-slicing/assets/slices-template.md`](../skills/vertical-slicing/assets/slices-template.md), a template rather than a skill. It has three sections left: the phase goal, the slice list and the frontier |
| `prd-generator` / `-noweb` | Field-level requirements are no longer enumerated up front; they are defined near the work, in each task's `prd.md`. Trellis's `task.py create` ships that template, and this repository **no longer provides** a task-level PRD template |
| `system-design` / `design-system-java` | Load-bearing decisions go to `docs/adr/` (maintained by `domain-modeling`); slice ordering goes to `docs/discovery/slices.md` |
| **`lofi-prototype`** (this repository's own, retired 2026-08-21) | Under the current flow the full hi-fi is approved **before** slicing, so producing lo-fi again inside a task creates a second structural source of truth beside the approved one. The measured conclusion it carried — **the approved screens must go into `implement.jsonl`** — is now carried by `vertical-slicing` (the fourth column of the slice list in `slices.md`, filled into the jsonl as each slice becomes a task). Its fidelity red lines and walkthrough round caps are void with it |

The cleanup commands are in step 2 of [`../playbook/00-setup.md`](../playbook/00-setup.md). **The script removes symlinks only**: when a retired name is a real directory under `~/.claude/skills/` — possibly your own skill of the same name — it errors out rather than deleting. Case 1 of `scripts/test-install-skills.sh` holds this.

## Other third parties still in use

| Skill | When | Boundary |
|---|---|---|
| `ui-ux-pro-max` | Full hi-fi and the design system, once the PRD has converged to field level | **Never before the PRD converges** — drawing early means guessing structure for requirements that are not settled, and once a guessed structure becomes the approved design, every slice implements against it. Component APIs are not its job; they belong to the shadcn skill / MCP |
| `code-review-skill` (awesome) | General code correctness and readability review | Track invariants are governed by the Pre-Development Checklist and Quality Check in `specs/<track>/`; the two are not mixed |
| `skill-creator` | Validating frontmatter and relative links after editing a skill | — |
| The official `shadcn/ui` skill plus the shadcn MCP | Writing frontend components on either track | **Installed per project; this repository does not distribute them** and only says how to use them — see below |

### The official shadcn skill and MCP: not distributed here, only governed

Both are installed **per project**, so neither of this repository's two distribution mechanisms reaches them:

| Thing | Installed to | Why this repository cannot manage it |
|---|---|---|
| The official skill (`skills add shadcn/ui`) | **The project repository's** `.claude/skills/` | Same installer as mattpocock's; upstream's words are *"writes the skills into your repo"*. `scripts/install-skills.sh` manages only the global symlink layer under `~/.claude/skills/` |
| The MCP (`shadcn@latest mcp init --client claude`) | The **project root's** `.mcp.json` | It is executable configuration, which belongs to the starter under `AGENTS.md`'s placement table |

`index.json` cannot hold them either — the registry accepts `type: spec` only.

So this repository does exactly one thing: **each track's `frontend/index.md` states how to use them, and what to do instead when they are not installed**. The installation steps are in step 4.2 of [`../playbook/00-setup.md`](../playbook/00-setup.md).

**Why it is worth wiring up**: the web-fullstack track's `components.json` is `style: base-nova`, the Base UI kernel, while almost every shadcn example in public material is from the Radix era. The track rules banned `@radix-ui/*` long ago, but that is a prohibition — it says what may not be written, not where correct usage comes from. The official skill reads `components.json`, so it knows which kernel this is, and that is the half it supplies.

**It does not replace `ui-ux-pro-max`, and must not be replaced by it**: that skill's description claims shadcn MCP integration, but its body makes no MCP call — it reads a bundled `data/stacks/shadcn.csv`, a static snapshot. Visual design belongs to `ui-ux-pro-max`, component APIs belong to the shadcn skill / MCP, and that boundary is written into both tracks' rules for the same reason `prototype` uses the LOGIC branch only: two sources answering one question grow two sources of truth.

**No machine enforces this rule.** "Did you consult the MCP first" is not decidable; it is a checkpoint, not a gate. The decidable half — never hand-edit `components/ui/*` — is already in the rules.

## Following upstream

Two halves, in **different states**:

### Vendored skills — built (`.github/workflows/sync-vendor.yml`)

It runs `scripts/sync-vendor.sh --pull` nightly at 03:00 Asia/Shanghai, and **opens a PR only when a skill's content or the LICENSE genuinely changed**. It never merges automatically. You read the diff in the PR and decide whether to follow.

Three design trade-offs, none of them casual:

| Trade-off | Why |
|---|---|
| **Open a PR rather than commit to main** | Automatically following upstream lets somebody else's changes alter your workflow without your knowing. A PR preserves the act of reading the diff before deciding, and merely delivers the diff to you |
| **Open a PR only when content changed** (`.upstream-sha` is excluded from the criteria, and the whole vendor tree is then rolled back) | When upstream commits elsewhere, `--pull` only bumps the sha, and that PR is pure noise. The cost is that the sha sits at an old value and the fetch repeats nightly — **worth it for zero noise** |
| **A fixed branch name, `chore/sync-vendor`** | The same PR is reused nightly instead of accumulating a stack |

Two runtime notes: GitHub's scheduled jobs are **delayed** at peak times on the hour, so do not treat it as a punctual alarm; and **60 consecutive days without commit activity makes GitHub disable the schedule automatically**, after which it needs a manual `workflow_dispatch` or a re-enable from the Actions page.

**⚠️ Not yet verified by a real run**: this workflow was written before the repository had a GitHub remote, and has never executed. After the first push, trigger it once with `workflow_dispatch` and fix whatever does not line up.

### Trellis itself — still not built (deliberately)

Trellis updates frequently, 1300+ commits. The eventual shape is the same: a scheduled GitHub Action diffing upstream, opening a PR automatically, with a human deciding whether to follow.

**The scope is only two things**: `.trellis/workflow.md` and Trellis's built-in `spec/guides/`. There is no need to track the whole tree — `.template-hashes.json` already protects files you have edited, and all you need to know is what upstream changed in those particular files.

**Not building it yet**, until this flow has been run for real — right now it is not clear what to watch. That is the difference from the vendored half: vendoring is a literal diff of a fixed set of files, so what to watch is settled; the Trellis half watches "what upstream changed in the files I edited", and **nothing has been edited yet**, so building it now would build a job that reports nothing forever.

# Install Mechanics

> **How the installers behave while you install** — the measured outputs, the source lines behind them, and the four failures that print green and exit 0.
>
> [`third-party.md`](third-party.md) decides *what* to install and what to leave out. This file is the other half: once that is decided, what the machine actually does. Measured against `@mindfoldhq/trellis` v0.7.0-beta.3 on 2026-08-21 unless a line says otherwise.

Two mechanics live in `third-party.md` because the decision and the mechanism are the same paragraph there, and are not repeated here:

- **`--registry` accepts `type: spec` only**, and `INSTALL_PATHS`' `skill:` entry sits behind the type gate as dead code — `third-party.md`, "Four distribution mechanisms".
- **`registry.spec.template` is a singular field**, so a second `init` cuts updates to the first template — same section.

## `trellis init` over an existing `.trellis/spec/`

### Without `--overwrite`, the download is skipped and the command still succeeds

Measured output:

```
📦 Downloading template "java-stack"...
   Skipped: .../.trellis/spec already exists
📋 Tracking 35 template files for updates
```

Green, exit 0, and `.trellis/spec/` unchanged. The tracking line is printed either way, so nothing in the output distinguishes a real install from a skipped one. The symptom arrives weeks later, as an agent working from the placeholder scaffold.

### `--append` fills in only the missing files

It reads as the safer flag and is not. `database/` and `testing/` arrive while `backend/` and `frontend/` stay on the placeholder scaffold — half a track spec and half a scaffold, which is harder to diagnose than nothing installed at all.

### `--template` suppresses the default spec entirely

With `--template`, `.trellis/spec/` holds the template's content and nothing else: no Trellis-supplied `frontend/`, `backend/` or `guides/`. This is correct — a track spec is meant to replace the defaults — and it is the second half of why **a track template has to ship its own guides**.

### The `<id>/` layer is flattened away

`specs/universal/guides/index.md` installs to `.trellis/spec/guides/index.md`. There is no `.trellis/spec/universal/`, and a link written as `](../../` breaks on arrival — which is what `scripts/test-spec-templates.sh` guards.

### Local edits under `.trellis/spec/` survive an update

`.trellis/.template-hashes.json` records each generated file's SHA256, and `update` uses it to recognize edited files and leave them alone. Full detail in `third-party.md`, "`trellis update` cuts both ways".

## `--registry` fetches the literal string `main`

`dist/utils/template-fetcher.js:201` hard-codes `main`. It is **not** "this repository's default branch" — a repository whose default branch is named something else is not followed there, it simply fails to resolve.

So the normal path is: change the track spec in the framework repository, merge to `main`, then install. To verify a branch **before** merging, point at it explicitly:

```bash
trellis init --claude --yes --registry gh:<owner>/solo-vibe-framework#<branch> \
             --template java-stack --overwrite
```

**Use the `gh:` prefix form.** The browser URL `https://github.com/<owner>/<repo>/tree/<branch>` is also accepted, but that code path parses the branch name with `[^/]+`, so a branch containing a slash is cut at the slash: `feat/workflow` becomes branch `feat` plus subdirectory `workflow`, and the resulting error mentions neither. After `gh:`, the `#` takes the entire remainder, so slashes survive.

## The shadcn MCP is per project, and `.mcp.json` has no working-directory field

### `mcp init` writes into the directory you ran it from

`shadcn mcp init` writes `.mcp.json` into the current working directory. Run it in `~/.claude` and it lands there — which is **not** a global configuration. Claude Code's MCP configuration has three tiers: `local` and `user` both store in `~/.claude.json`, while `.mcp.json` is read **only from a project root**. A `~/.claude/.mcp.json` therefore takes effect only when `~/.claude` itself is opened as the project, which is to say never.

The same run also leaves `package.json`, `package-lock.json` and a `node_modules` of tens of megabytes in that directory, because the dependency install goes through npm. Remove all four and re-run from the project root.

### A frontend in a subdirectory needs shadcn's own `--cwd`

`.mcp.json` has no field for the server's working directory. Claude Code derives it from where the configuration file sits, and since the session starts at the repository root, the server lands at the root — where there is no `components.json`. Pass the path to shadcn instead:

```json
{ "mcpServers": { "shadcn": { "command": "npx", "args": ["shadcn@latest", "mcp", "--cwd", "frontend"] } } }
```

### One command decides whether a project is eligible at all

```bash
pnpm dlx shadcn@latest info --cwd frontend
```

It does not need Claude Code and answers immediately. Two lines decide it:

| Line | Required value |
|---|---|
| `framework` | A real framework — `Next.js` or `Vite`, not `Manual` |
| `Configuration` | Non-empty, not `No components.json found` |

Fail either one and the MCP installs but only ever performs generic registry search: it cannot reach the project's kernel, aliases or installed components, which is the entire reason to install it.

**Measured 2026-08-21: the java-stack starter is not yet eligible.** Its `frontend/` is recognized as Vite, but there is no `components.json` and no Tailwind is detected. Fix the skeleton with `shadcn init` first; installing the MCP before that is wasted.

### Why not install it at user level

An MCP server's tool definitions consume context in **every** session, and only frontend work benefits. Install it per project and let each starter carry its own `.mcp.json`, and a new project costs nothing.

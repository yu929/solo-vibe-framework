---
name: ops
description: Project configuration, the local Supabase stack, compose, the image and the release tag — the settings that reach a deployment silently, or not at all
paths:
  - docker-compose*.yml
  - Dockerfile
  - .env.example
  - package.json
  - next.config.*
  - tsconfig*.json
  - eslint.config.*
  - supabase/config.toml
  - services/*/pyproject.toml
  - scripts/**
  - .github/workflows/**
---

# Configuration, Containers and Releases · Web Fullstack

> What you get on every edit to a configuration, compose, build or workflow file: the settings that fail silently, and the two checklists. **A config file is usually the other half of a rule that lives with the code it configures** — the table at the end names each one.
>
> Track overview: [`../README.md`](../README.md). Section numbers are per file here, so a reference always names its file.

## Quick reference

| Operation | The one way |
|---|---|
| Starting a new project from this template | `pnpm init:project <project-name>` **first** — it clears every leftover template name in one pass ([`../database/index.md`](../database/index.md) §5) |
| `supabase/config.toml`'s `project_id` | Unique per project. Sharing it means sharing one local stack, and one `db:reset` drops the other project's tables ([`../database/index.md`](../database/index.md) §5) |
| The auth cookie name | Set explicitly, never derived from the URL ([`../backend/index.md`](../backend/index.md) §3) |
| The Supabase key in `.env.example` | The **publishable** key, in both browser and server variables ([`../backend/index.md`](../backend/index.md) §1) |
| `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` | **Stable across rebuilds.** Regenerating it invalidates every in-flight server action |
| `NEXT_DEPLOYMENT_ID` | Changes on every release |
| A service-role key | Server-side only, and never in a variable prefixed `NEXT_PUBLIC_` |
| Cutting a release | A `vX.Y.Z` tag, with `package.json` — and every `services/*/pyproject.toml` — already bumped |

## The `NEXT_PUBLIC_` prefix is the whole boundary

Everything prefixed `NEXT_PUBLIC_` is **inlined into the browser bundle at build time**. There is no runtime check and no warning: a service-role key given that prefix ships to every visitor, and the build stays green.

The failure is also **not reversible by rotating the variable alone** — the value is baked into an artifact that may already be deployed or cached. Treat a `NEXT_PUBLIC_` addition as a decision about what becomes public, made at the moment you type the prefix.

## The two deployment modes

```bash
docker compose up -d --build                          # personal or cloud
docker compose -f docker-compose.yml \
  -f docker-compose.selfhost.yml up -d --build        # self-hosted on an internal network
```

**Self-hosting splits the Supabase URL in two**: the server reaches it over `SUPABASE_INTERNAL_URL` while the browser uses the public one. That split is exactly what makes the explicit auth cookie name mandatory ([`../backend/index.md`](../backend/index.md) §3) — leave it derived and the two entry points disagree about which cookie to read.

## The local stack

```bash
pnpm db:start        # Docker or OrbStack must be running
supabase status      # check status and keys
```

## Cutting a release

Releases go through a `vX.Y.Z` or `vX.Y.Z-rc.N` tag:

1. Update the version in `package.json` first, including `services/*/pyproject.toml` where those exist
2. `pnpm release:validate <tag>`
3. Pushing the tag triggers the release quality gates in `.github/workflows/release.yml`

## Where the rest of it lives

A configuration file is one end of a rule whose other end is code. Open the file that owns the rule you are about to change:

| File | Which of these settings it governs | Open it when |
|---|---|---|
| [`../backend/index.md`](../backend/index.md) | The auth cookie name and what breaks without it (§3), which Supabase key goes where (§1), the signup toggle (§4) | Changing an auth, key or cookie setting |
| [`../database/index.md`](../database/index.md) | `project_id`, the local stack's shared-volume trap, and what `pnpm init:project` clears (§5) | Touching `supabase/config.toml` or the local stack |
| [`../backend/sub-services.md`](../backend/sub-services.md) | The trust boundary a service-role worker must respect, and the shared Bearer token (§6.1) | Adding or configuring a service under `services/` |
| [`../testing/index.md`](../testing/index.md) | The required checks the release gates run | Changing what a workflow runs, or `playwright.config.*` |

## Pre-Development Checklist

- [ ] Adding an environment variable? Does it need to be public? **`NEXT_PUBLIC_` is a one-way decision baked into the artifact**
- [ ] Is it in `.env.example` too, so the next machine knows it exists?
- [ ] New project from this template? Has `pnpm init:project` run, and is `project_id` unique?
- [ ] Bumping the version? Are `package.json` and every `services/*/pyproject.toml` all changed?
- [ ] Adding a service under `services/`? Does it get its own compose file rather than lines in the base one?

## Quality Check

- [ ] Started the container and confirmed the new setting actually took effect — reading it back from the running app, not inferring it from `.env`
- [ ] Both deployment modes still start: default, and self-hosted
- [ ] No service-role key or other secret carries a `NEXT_PUBLIC_` prefix, and none is in a committed file
- [ ] Required checks green ([`../testing/index.md`](../testing/index.md))

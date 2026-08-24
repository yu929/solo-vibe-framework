---
name: ops
description: Application settings, compose files, the packaged image and the release tag — the configuration that reaches a container silently, or not at all
paths:
  - backend/src/main/resources/*.yml
  - docker-compose*.yml
  - Dockerfile
  - .env.example
  - gradle.properties
  - build.gradle*
  - settings.gradle*
  - gradle/**
  - scripts/**
  - frontend/package.json
  - frontend/vite.config.*
  - frontend/tsconfig*.json
  - frontend/eslint.config.*
  - .github/workflows/**
---

# Configuration, Containers and Releases · Java Stack

> What you get on every edit to a settings, compose, build or workflow file: the configuration that fails silently, and the two checklists. **A config file is usually the other half of a rule that lives with the code it configures** — the table at the end names each one.
>
> Track overview and the Never list: [`../README.md`](../README.md). Section numbers are per file here, so a reference always names its file.

## Quick reference

| Operation | The one way |
|---|---|
| Adding an application setting | Add it to `application.yml` **and** to compose's `environment:` block in the same change |
| A setting that only one deployment mode needs | Put it in **that mode's own compose file**, never in the base file |
| Publishing the development database | `"127.0.0.1:5432:5432"`, never `"5432:5432"` ([`../database/local-database.md`](../database/local-database.md) §5.2) |
| A database password default | There is none, not even a development-looking one ([`../database/local-database.md`](../database/local-database.md) §5.3) |
| `ddl-auto` | Always `validate`; schema changes are Flyway migrations ([`../backend/platform.md`](../backend/platform.md) §7) |
| `open-in-view` | Always `false` ([`../backend/platform.md`](../backend/platform.md) §7) |
| Pinning a backend version | `gradle/libs.versions.toml`, the only place. **Flyway, Testcontainers, the Postgres driver and Spring Session are deliberately absent** — the Boot BOM manages them, and adding them to the catalog silently detaches them from the Boot version you are on ([`../README.md`](../README.md), "Locked stack") |
| `react-router` and `react-router-dom` | Both direct dependencies at **exactly** the same version. Pin one and pnpm resolves the other differently; two Router contexts then fail to recognize each other **while typecheck and build stay green** |
| Renaming a new project | `scripts/init-project.sh <name>` **before anything else** — it sets the compose project name and the session cookie name in one pass ([`../database/local-database.md`](../database/local-database.md) §5.1) |
| A script that modifies the tree | Preflight, bash 3.2, permission bits — the project's own `scripts/README.md` is the host, and this spec does not restate it |
| Cutting a release | A `vX.Y.Z` tag, with `gradle.properties` and `frontend/package.json` already matching |
| Production settings | `APP_API_DOCS_ENABLED=false`, and `APP_COOKIE_SECURE=true` behind TLS |

## Two compose traps, neither with a symptom

**A variable not listed in the `environment:` block never reaches the container.** It is in `.env`, compose can read it, and that is where it stops. It shows up as "I set the parameter and the container is still using the default". **Every new application setting is added to compose's `environment:` at the same time.**

**Compose interpolates each file first, then merges**, so a `${X:?...}` in the base file fires in **every** mode, including modes that never start the service it belongs to. Put a variable that is mandatory for only one mode into that mode's own file. `deploy: replicas: 0` does not solve it — interpolation happens well before that takes effect.

## Local dependencies

```bash
docker compose -f docker-compose.dev.yml up -d    # Postgres (Testcontainers starts its own)
pnpm -C frontend install
```

## The two deployment modes

```bash
cp .env.example .env                                  # A needs at least POSTGRES_PASSWORD; B needs APP_DB_*

# A) Bundled database: pass no -f, and compose loads docker-compose.override.yml automatically
docker compose up -d --build

# B) External or managed Postgres: passing -f explicitly also suppresses that override, so the bundled database is out entirely
docker compose -f docker-compose.yml \
  -f docker-compose.external-db.yml up -d --build
```

**The image is environment-independent** — the frontend calls the relative `/api` only, with no address baked in at build time — so one build deploys to any environment.

## Cutting a release

Releases go through a `vX.Y.Z` or `vX.Y.Z-rc.N` tag:

1. Update `version` in `gradle.properties` **and** in `frontend/package.json` (the two must match)
2. `./gradlew validateReleaseTag -Ptag=vX.Y.Z`
3. Pushing the tag triggers the release quality gates and image-metadata verification in `.github/workflows/release.yml`

## Where the rest of it lives

A configuration file is one end of a rule whose other end is code. Open the file that owns the rule you are about to change:

| File | Which of these settings it governs | Open it when |
|---|---|---|
| [`../backend/platform.md`](../backend/platform.md) | `ddl-auto`, `open-in-view` and the rest of the JPA prohibitions (§7); the backend path prefixes the SPA fallback must exclude (§6) | Changing a JPA setting, or adding a backend path |
| [`../database/local-database.md`](../database/local-database.md) | The compose project name and its shared-volume trap, the loopback bind, the password with no default (§5) | Touching the development database's compose service or its credentials |
| [`../backend/auth-sessions.md`](../backend/auth-sessions.md) | What `APP_COOKIE_SECURE` and the session settings are protecting (§4) | Changing a cookie or session setting |
| [`../testing/index.md`](../testing/index.md) | The required checks the release gates run, and why E2E runs against the packaged jar | Changing what a workflow runs, or `frontend/playwright.config.*` |
| [`../README.md`](../README.md) | The locked stack, the five version decisions intuition gets wrong, and the initial-chunk gzip bar the Vite build is measured against | Bumping a version, or changing `vite.config.*` chunking |

## Pre-Development Checklist

- [ ] Adding an application setting? Is it in **both** `application.yml` and compose's `environment:` block?
- [ ] Is this setting mandatory for only one deployment mode? Then it belongs in that mode's own compose file, not the base one
- [ ] Publishing a port? Is it bound to `127.0.0.1` unless it genuinely has to be reachable from another machine?
- [ ] Adding a credential? Does it have **no default at all**, and is its only local source an uncommitted `.env`?
- [ ] Bumping the version? Are `gradle.properties` and `frontend/package.json` both changed?
- [ ] Adding a backend dependency? Is it in `gradle/libs.versions.toml` — and is it one the Boot BOM already manages, in which case it must **not** be?
- [ ] Splitting a chunk in `vite.config.*`? Is the initial chunk actually over the **gzip** bar, or only over Vite's uncompressed warning?

## Quality Check

- [ ] Started the container and confirmed the new setting actually took effect — reading it back inside the container, not inferring it from `.env`
- [ ] Both deployment modes still start: bundled database, and external Postgres
- [ ] Required checks green ([`../testing/index.md`](../testing/index.md))
- [ ] Nothing in this change puts a secret value into a committed file

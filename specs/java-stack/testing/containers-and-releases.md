# Local Dependencies, Containers and Releases · Java Stack

> What has to be running to test locally, and how the packaged artifact is built and shipped.
>
> Part of the testing spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across the whole layer, so a
> section reference means the same thing wherever it is cited.

## Local dependencies

```bash
docker compose -f docker-compose.dev.yml up -d    # Postgres (Testcontainers starts its own)
pnpm -C frontend install
```

## Containers and releases

```bash
cp .env.example .env                                  # A needs at least POSTGRES_PASSWORD; B needs APP_DB_*

# A) Bundled database: pass no -f, and compose loads docker-compose.override.yml automatically
docker compose up -d --build

# B) External or managed Postgres: passing -f explicitly also suppresses that override, so the bundled database is out entirely
docker compose -f docker-compose.yml \
  -f docker-compose.external-db.yml up -d --build
```

**Two compose traps, neither with a symptom:**

- **A variable not listed in the `environment:` block never reaches the container.** It is in `.env`, compose can read it, and that is where it stops. It shows up as "I set the parameter and the container is still using the default". **Every new application setting is added to compose's `environment:` at the same time.**
- **Compose interpolates each file first, then merges**, so a `${X:?...}` in the base file fires in **every** mode, including modes that never start the service it belongs to. Put a variable that is mandatory for only one mode into that mode's own file. `deploy: replicas: 0` does not solve it — interpolation happens well before that takes effect.

Releases go through a `vX.Y.Z` or `vX.Y.Z-rc.N` tag:

1. Update `version` in `gradle.properties` **and** in `frontend/package.json` (the two must match)
2. `./gradlew validateReleaseTag -Ptag=vX.Y.Z`
3. Pushing the tag triggers the release quality gates and image-metadata verification in `.github/workflows/release.yml`

**The image is environment-independent** — the frontend calls the relative `/api` only, with no address baked in at build time — so one build deploys to any environment. In production, set `APP_API_DOCS_ENABLED=false`, and `APP_COOKIE_SECURE=true` behind TLS.

---

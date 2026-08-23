# Java Stack · Spec Overview

> This file is the spec root overview (the official template's `.trellis/spec/README.md`). Each layer's entry point is `<layer>/index.md`; the track-independent thinking guides are in `guides/`.

> Coding rules for the Spring Boot 4 + Postgres + React 19 / shadcn-admin-kit track. Once installed they sit in `.trellis/spec/` and Trellis injects them on demand.
>
> **This file is the source of truth for the rules this track locks.** Where it conflicts with the starter repository's `AGENTS.md`, this file wins — see "Relationship to the starter's AGENTS.md" at the end.

> ### This template is self-contained; install exactly one
>
> One command:
>
> ```bash
> trellis init --claude --registry <framework repo URL> --template java-stack
> ```
>
> **Do not install a second template.** `registry.spec.template` in `.trellis/config.yaml` is a **singular** field, and installing a second one replaces that line outright. From then on `trellis update` refreshes only the one installed last — **this track's rules, including the safety red lines below, stop receiving fixes, and nothing reports an error**.
>
> That is why `guides/` (the track-independent thinking guides) is already packaged here: you do not need to install `universal-guides` as well. That template exists only for projects that have **no track spec at all**.

## Data isolation is the heaviest section on this track

Per-user data isolation **has no database backstop**. The isolation *is* the `owner_id` predicate in the query, and it is **fail-open**: omit it and nothing errors — you get a 200 and somebody else's data, with nothing in the log.

So this track replaces a rule a human has to remember with three things a machine can check. The full definition is in [`backend/index.md`](backend/index.md) §2. Everything else here is ordinary engineering.

## Locked stack (substitutions need confirmation)

| Layer | Locked to |
|---|---|
| Language / runtime | **Java 25 LTS** (the Gradle toolchain downloads it for compilation) |
| Framework | **Spring Boot 4.1.x** (Spring Framework 7) |
| Build | **Gradle 9 + Kotlin DSL** with a version catalog (`gradle/libs.versions.toml`) |
| Database | **Postgres 17** + **Flyway** (plain SQL migrations) |
| ORM | **Spring Data JPA / Hibernate 7** |
| Auth | **Spring Security** + **Spring Session JDBC** (sessions stored in Postgres); **no JWT** |
| Auth rate limiting | **bucket4j** (`bucket4j_jdk17-core`) token buckets, in-process; separate budgets per client address and per account |
| API docs | **springdoc-openapi 3.x** → `/v3/api-docs` → frontend types |
| Frontend | **Vite 8 + React 19 + TypeScript 6 + Tailwind v4 + shadcn/ui + shadcn-admin-kit**; the shadcn kernel is locked to **Radix + new-york** (the single source for visuals is `globals.css`, see "Directory structure") |
| Frontend data layer | **ra-core 5.x** (shadcn-admin-kit's kernel): `dataProvider` / `authProvider` / `<Resource>`. **TanStack Query sits underneath it and is not used directly** |
| Frontend routing / forms | **React Router 7** (`react-router` and `react-router-dom` **both pinned, at exactly the same version**) + **React Hook Form** (ra-core ships the integration) |
| Package management | Gradle for the backend; **pnpm** for the frontend (host Node ≥ 24 plus corepack; **Gradle does not fetch a second pnpm**). The version in `packageManager` matches the one on PATH |
| Testing | **JUnit 5 + Testcontainers + ArchUnit**; **Vitest**; **Playwright** |
| Deployment | **A single container**: the SPA is packaged into the jar's `static/`, built by a three-stage Dockerfile with a layered jar |

**Five version decisions that intuition gets wrong:**

- **TypeScript stays on 6.0.x; do not move to 7.** TS 7 is released, but `typescript-eslint`'s peer range is `>=4.8.4 <6.1.0` — upgrade and `tsc` keeps working while **the lint chain breaks**. Confirm typescript-eslint supports it first.
- **Flyway, Testcontainers, the Postgres driver and Spring Session are not pinned in the version catalog**; the Spring Boot BOM manages them. Overriding them in the catalog quietly detaches them from the Boot version you are on. To upgrade them, upgrade Boot.
- **`react-router` and `react-router-dom` must both be direct dependencies at exactly the same version.** Pin only the first and pnpm installs a different version of the second to satisfy the peer range; two copies of the Router context then fail to recognize each other and the app reports "not a `<Route>` component" at runtime — while **typecheck and build are both green**. Verify with a deep-link E2E against the packaged jar.
- **The shadcn kernel is locked to Radix + new-york; do not switch to Base UI.** The admin kit's registry source uses the Radix/new-york component API, `asChild` composition included. Switching kernels is not an import change — it grows an adapter fork, and from then on the generated components no longer match upstream's docs.
- **`openapi-typescript` still declares a TypeScript 5 peer** while this project is on 6, and generation emits Springdoc/Jackson JsonSchema warnings. Both are **non-blocking**: `pnpm api:types` produces correct output. **Do not hand-edit the generated file to hide them** — converge the versions once upstream supports TS 6.

## Boot 4 package traps (copying Boot 3 code walks into these)

Boot 4 changed coordinates and package names substantially. The ones that fail at compile time are the kind ones; the Jackson row is the dangerous one:

| What you expect | What it actually is | Symptom |
|---|---|---|
| `spring-boot-starter-web` | **`spring-boot-starter-webmvc`** | Dependency resolution fails |
| `spring-boot-starter-test` | Split per module: **`-webmvc-test` / `-data-jpa-test` / `-security-test` / `-flyway-test`** | Test classes fail to compile |
| `com.fasterxml.jackson.databind.ObjectMapper` | **`tools.jackson.databind.ObjectMapper`** (Jackson 3) | ⚠️ **Compiles, then fails at runtime with `No qualifying bean of type ObjectMapper`** — Jackson 2 is still on the classpath as a transitive dependency, so the import is legal; there is simply no bean registered for that type |
| `o.s.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc` | **`o.s.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc`** | Compile failure |
| `org.testcontainers.containers.PostgreSQLContainer` | **`org.testcontainers.postgresql.PostgreSQLContainer`** (Testcontainers 2.x) | Compile failure |

**Look up the real coordinates when you are unsure** — generate a reference project on `start.spring.io`, or read the package paths inside the jar. Do not write them from memory.

## Never (most lethal first)

**Data isolation — this track's first red line:**

- **The only permitted parent interface for a repository is the bare `Repository<T, ID>`.** This is an allow-list, not a "anything except `JpaRepository`/`CrudRepository`" deny-list. A deny-list is guaranteed to leak: `PagingAndSortingRepository` has extended the bare `Repository` directly since Spring Data 3.0 and still hands out `findAll(Sort)` / `findAll(Pageable)`; `JpaSpecificationExecutor` and `QueryByExampleExecutor` are not `Repository` subtypes at all, and let a whole table be scooped up.
- **A hand-written method leaks exactly as much as an inherited one.** A `findById(UUID)` declared on a bare `Repository` carries no ownership predicate either. So every declared method either genuinely **filters** by `ownerId` in its derived query name, or carries `@CrossUserQuery("reason")` ([`backend/index.md`](backend/index.md) §2).
- **Both rules above apply to every repository, not only the ones for per-user entities.** A table with no ownership — a lookup table, reference data, configuration — carries `@OwnerlessTable("reason")` on the **interface**. Do not approximate it with `@CrossUserQuery` on each method; that drowns out the signal that says "this genuinely reads across users". It exempts the method-level ownership check only, **never the parent-interface allow-list**, and it is rejected outright when the entity does carry `ownerId` ([`backend/index.md`](backend/index.md) §2.4).
- Every per-user table has `owner_id uuid not null references app_user(id)`, an index on `owner_id`, and **one two-account negative test**.
- "Not yours" and "does not exist" both answer **404**, never 403 — a 403 confirms the record exists.
- Cross-user reads and writes go through an **explicitly registered, controlled exception** ([`backend/index.md`](backend/index.md) §2.4), annotated on the **method**. Never by adding a method or widening the parent interface.
- **The guards themselves have negative tests.** A broken guard and a guard with nothing to catch are both green, and nothing distinguishes them ([`testing/index.md`](testing/index.md)).

**Security:**

- **No secret goes into a `VITE_*` variable.** Vite inlines `VITE_`-prefixed values into the browser bundle, which is publication.
- **CSRF stays on**, and the `setCsrfRequestAttributeName(null)` line in `SecurityConfig` stays where it is (see [`backend/index.md`](backend/index.md) §3).
- Session credentials and tokens do not go in `localStorage`; the session is an httpOnly cookie.
- **No credentials in the session principal.** The session is serialized into Postgres, so carrying a password hash there copies it into a second table ([`backend/index.md`](backend/index.md) §4.1).
- `.env` is not committed, and passwords and keys do not go into `application.yml` or source. **The database password has no default of any kind**, not even one that looks like a development value — a startup path with the variable unset would otherwise succeed silently on a publicly known password. Note that "has no default" does not mean "will fail": a failed placeholder resolution **does not** abort Spring startup, so `main()` blocks it explicitly ([`database/index.md`](database/index.md) §5.3).
- **Development container ports bind to `127.0.0.1` only**, never `"5432:5432"`, which is 0.0.0.0.
- **Rate limiting on login and signup stays on** ([`backend/index.md`](backend/index.md) §4.2). BCrypt is deliberately slow, and signup has already hashed **before** the unique index adjudicates — without rate limiting, one machine resubmitting the same already-registered email saturates the CPU while the database sits idle.
- **The client address comes from `getRemoteAddr()` alone; `X-Forwarded-For` is never trusted** — the client writes that header, so trusting it hands an attacker unlimited identities. Behind a reverse proxy, set `server.forward-headers-strategy=native` and let Tomcat's valve rewrite `getRemoteAddr()`.
- **What the API accepts must be what the storage underneath can actually hold** ([`backend/index.md`](backend/index.md) §4.3). Under-validation fails *after* the write: half the record has landed and the user gets a 500.
- Authorization is server-side, always. A frontend route guard governs rendering and is not authorization.
- With TLS in front, set `APP_COOKIE_SECURE=true`; in production, `APP_API_DOCS_ENABLED=false`.

**Structure:**

- `spring.jpa.hibernate.ddl-auto` is **`validate`** and nothing else — never `update` or `create-drop`.
- `spring.jpa.open-in-view` stays **false**.
- SQL appears only in `backend/src/main/resources/db/migration/`.
- No `@ManyToMany` and no `FetchType.EAGER`; a controller returns DTO records, never entities.
- **No Lombok** (an annotation processor, plus long-running friction with records and JPA). DTOs are records; entities are plain classes.
- Generated files are not hand-edited: `V*__spring_session.sql` (copied from the jar) and `frontend/src/lib/api/schema.d.ts` (produced by `pnpm api:types`).
- **`components/admin/*` is a frozen snapshot of upstream source and is not hand-edited.** Record any genuinely necessary local modification, one at a time, in `THIRD_PARTY_NOTICES.md`, and diff against the source at the pinned commit rather than the registry address ([`frontend/index.md`](frontend/index.md) §6).
- **The project name is spelled once inside `frontend/src`** — `APP_NAME` in `lib/app-config.ts` — and distributed from there. Spread it across several places and the scaffold's rename step becomes impossible to follow; a missed rename means every generated project shares one Postgres volume and one session cookie ([`database/index.md`](database/index.md) §5.1).
- Every frontend call to the backend goes through ra-core's `dataProvider` / `authProvider`. **No bare `fetch` in a component**, and no `useQuery` pointed straight at an endpoint.
- Uniqueness is adjudicated by **a database constraint**, never by "check whether it exists, then insert" ([`backend/index.md`](backend/index.md) §5.1).
- Ask before introducing a new dependency, especially a heavy one.

**Tooling and scripts:**

- **A script that modifies the working tree — renaming, bulk rewriting, data migration — completes a full preflight first.** Not one byte is written until every check has passed. A half-failed run leaves a repository that is neither the original nor the target, which is far worse to recover from than an outright refusal. Note that "write first, then check whether it matched" is not a preflight; that is **validating as you write**.
- A script **never `rm -rf`s the target path** to make room. An existing target is a reason to refuse, not a reason to delete — it may be somebody else's code.
- **One policy gets one guard, in one layer.** Check the database password in both Gradle's `bootRun` and the application's `main()` and the two rules will drift: the application accepts `SPRING_DATASOURCE_PASSWORD` and Gradle does not, so running `bootRun` with that variable is rejected before the JVM even starts. **Keep the guard in the layer closest to the fact** — here, the application — and let the other layer only prepare the environment.
- **What a comment claims must be what the code does.** `node { download = false }` skips only the Node download; `pnpmSetup` still runs `npm install` for a pnpm that is outside version control. A comment saying "we use only the one on PATH" beside code that installs a second one is worse than no comment. Check what actually ran with `--info`.

> **How to write scripts like these is not in this spec.** The preflight checklist and its scope, how `perl -0ne` and `perl -pi` disagree about `^` and `$`, `trap ... EXIT` rewriting the exit code, `find ... 2>/dev/null` swallowing permission failures along with the errors, bash 3.2's limits, checking the **parent directory** for write plus execute rather than the file's `-w`, idempotent renaming being anchored on the **current** value — those are lessons about `scripts/init-project.sh`, an **executable artifact**. They travel with the artifact, in the starter repository's `scripts/README.md`. This page keeps only the rules above, which hold for any script.

## Directory structure (where new code goes)

```
backend/src/main/java/<pkg>/
  config/      SecurityConfig (CSRF / session / public prefixes) · SpaForwardConfig (deep links)
  auth/        AppUser · AppUserRepository · AppUserPrincipal · AppUserDetailsService
               CurrentUserService (≈ requireUser()) · AuthController · AuthProperties
  <feature>/   Entity · Repository (owner-scoped) · Service · Controller · Dtos (record)
  common/      ApiExceptionHandler (RFC 9457 ProblemDetail) · NotFoundException · ConflictException
               CrossUserQuery (method-level exception) · OwnerlessTable (interface-level: this table has no owner)
backend/src/main/resources/
  application.yml
  db/migration/V*.sql          # the only place SQL is written
backend/src/test/java/<pkg>/
  support/ApiIntegrationTest   # MockMvc base class carrying cookies, plus Testcontainers
  architecture/                # ArchUnit: the ownership rules
  <feature>/                   # includes *OwnershipIsolationTest (negative)
  TestcontainersConfiguration · DatabasePasswordGuardTest   # cross-module, so they sit at the package root
frontend/src/                  # load-bearing entries only; anything not listed goes wherever it is used
  lib/api/client.ts            # transport: CSRF header + problem+json normalization, under every backend call
  lib/api/schema.d.ts          # generated by pnpm api:types, not hand-edited
  providers/                   # dataProvider (the only path to data) · authProvider (the only path to auth)
  lib/app-config.ts            # APP_NAME: the single place the project name is spelled inside frontend/src
  components/admin/            # frozen shadcn-admin-kit source snapshot, not hand-edited (record changes in THIRD_PARTY_NOTICES.md)
  components/ui/               # shadcn output, not hand-edited (add with the CLI)
  components/{data,forms,app}/ # the pattern layer: resource CRUD screens do not need it; non-CRUD screens grow it
  routes/                      # pages
  app.tsx                      # <Admin> and <Resource>: where routing and data are bound together
  styles/globals.css           # the single source for visuals: values in :root, mapped by @theme inline
  assets/fonts/                # fonts are vendored; no CDN
design-system/MASTER.md        # the authority on the product's visual design
THIRD_PARTY_NOTICES.md         # third-party notices, plus the ledger of local changes to the frozen snapshot
CONTEXT.md                     # glossary (maintained by domain-modeling; the only host)
docs/
  adr/NNNN-*.md                # decisions with a trade-off (the only host)
  discovery/prd.md             # the full PRD (the only host for requirements and acceptance)
  discovery/slices.md          # the slice map: phase goal / slice list / frontier
  releases/vX.Y.Z.md           # per-release notes plus acceptance list
scripts/
  README.md                    # how to write scripts that modify the tree (preflight, bash 3.2, permission bits) — not repeated in this spec
  init-project.sh              # first step for a new project: rename it (otherwise the data volume is shared, see database §5)
  test-init-project.sh         # that script's refusal paths and its zero-write guarantee
gradle/libs.versions.toml      # the only place backend versions are pinned (what is deliberately unpinned is under "Locked stack")
Dockerfile
docker-compose.dev.yml         # local development database, bound to 127.0.0.1 only
docker-compose.yml             # the application only, no database
docker-compose.override.yml    # brings its own database; compose loads it automatically when no -f is given
docker-compose.external-db.yml # external database; passing -f explicitly also suppresses the override above
.github/workflows/{ci,release}.yml
```

> **Why the database is not in `docker-compose.yml`**: compose **interpolates each file first, then merges**. Put the bundled database's `${POSTGRES_PASSWORD:?…}` in the base file and the external-database path resolves it too — demanding a password for a database it never starts, and failing the whole deploy. Moving it into the override leaves each mode resolving only the variables it uses. Note that `deploy: replicas: 0` **does not fix this**: interpolation happens before any override takes effect.

> **How `lib/api/` and `providers/` divide the work**: the transport — CSRF header and `problem+json` normalization — is `lib/api/client.ts`; the two providers are built on it and live in `providers/`. Business components see the providers and never the transport.

> **Implementation specs do not go in `docs/`.** They travel with their task, in `.trellis/tasks/<task>/prd.md`. A single up-front document enumerating all of them is guaranteed to rot ahead of the code.

## Locked vs free

**Locked — ask before changing**: the stack, the directory layout, how ownership is scoped, auth and CSRF, how migrations work, the deployment shape.

**Free — just change it**: an individual page's layout, its copy, which components it uses, its business fields.

## Known trade-offs (this track's defaults, which a real project must judge for itself)

These are written down because **silence reads as endorsement**: whatever the default implementation lacks, the next person assumes this track does not need.

- **Writes are unconditional last-write-wins by default** — no version column, no `@Version`, no ETag, no conditional update. While an entity has a single owner, conflicts can only arise between two tabs belonging to the same user, and the default declines to pay for that. **The moment your entity can be edited by several people at once, optimistic locking becomes mandatory**: add a version column and `@Version`, carry the version on the request (or `If-Match`), answer 409/412 on a mismatch, and cover it with concurrent-transaction and stale-form tests. **Keeping the default** carries "the later writer silently overwrites" into a situation where it is no longer safe.
- **Rate limiting is in-process**, so two instances mean two budgets ([`backend/index.md`](backend/index.md) §4.2). On a single-instance deployment that is an honest trade — no extra Redis to run — but scaling horizontally means moving to a bucket in shared storage.
- **The first-load bundle is not split.** The admin stack has one entry point, and the build exceeds Vite's default 500 kB warning — but that warning measures **uncompressed** size, which is not what a user downloads. **The bar is the initial chunk's gzip size: 350 kB or less is within baseline**, and the build already prints that number. Over the bar, split by route or write down the reason. Under it, leave it alone: adding a lazy route or a custom chunk strategy because something "looks big" expands the architecture for a sample.
- **There is no second factor and no human challenge.** So per-account rate limiting carries a residual risk, written down in [`backend/index.md`](backend/index.md) §4.2. Do not pretend it is absent.

## Spec index

Every `<layer>/index.md` carries the **Pre-Development Checklist** and **Quality Check** sections Trellis expects (`workflow.md` reads them by that convention).

**Track-specific.** Every file in this table declares `paths:`, so it is injected when you touch the source files it governs.

| File | Covers | Read it when |
|---|---|---|
| [`backend/index.md`](backend/index.md) | Layering and data access, **owner-scoped queries**, auth and sessions, CSRF, JPA prohibitions, SPA deep links, heterogeneous sub-services | Writing a repository, controller or service, or touching Spring Security |
| [`database/index.md`](database/index.md) | Flyway workflow, **the three parts of a new table**, `ddl-auto=validate`, generated migrations, the local volume-name trap | Adding a table, writing a migration, changing a column type |
| [`frontend/index.md`](frontend/index.md) | The provider as the only path to the backend, reuse order, hooks, form wiring, theme tokens, routing and deep links | Calling the backend, adding a component, touching theme tokens |
| [`frontend/ui-structure.md`](frontend/ui-structure.md) | UI/UX rules (structure): precedence, page skeletons, button hierarchy, filters, tables, empty states, the pattern layer's role, accessibility invariants | Building a screen the approved hi-fi did not draw |
| [`frontend/ui-interaction.md`](frontend/ui-interaction.md) | UI/UX rules (behaviour): forms, validation, dialog vs route, feedback, loading, destructive actions, where a success lands | Building a form, a dialog, or any loading and failure state |
| [`testing/index.md`](testing/index.md) | Required checks, how to verify (including two negative tests), Testcontainers, why E2E runs against the packaged artifact | Before saying it is done |

**Track-independent** (holds on any stack; ships with this template):

| File | Covers | Read it when |
|---|---|---|
| [`guides/index.md`](guides/index.md) | Entry point for the guides | Unsure which guide applies |
| [`guides/code-reuse.md`](guides/code-reuse.md) | Where to look for an existing implementation before writing a new one | About to write something that resembles existing code |
| [`guides/cross-layer.md`](guides/cross-layer.md) | Criteria for splitting responsibility across layers, including "validation scattered across layers" | A feature crosses three or more layers |
| [`guides/review-adjudication.md`](guides/review-adjudication.md) | The four-field finding while coding; reporting is not deciding | You found a rule that is wrong, or a trap the spec never mentioned |
| [`guides/task-artifacts.md`](guides/task-artifacts.md) | What belongs in a task's `design.md` and `implement.md` | Writing task artifacts — **injected by path** |
| [`guides/source-of-truth.md`](guides/source-of-truth.md) | Which artifact is authoritative at each stage; writing back as a delta | Two documents disagree — **injected by path** |

> In the framework repository `guides/` is a **generated copy**; the source of truth is `specs/universal/guides/`, synced by `scripts/sync-spec-guides.sh`. **Edit the source of truth** — editing the copy here is overwritten at the next sync, and the framework repository's CI reports it first.

## Relationship to the starter's AGENTS.md

**The same rules currently exist in two places**: this directory, and the starter repository's `java-stack/AGENTS.md`. That is a temporary state.

- **This directory is the source of truth.** It is maintained in the framework repository and injected on demand by Trellis.
- The starter's `AGENTS.md` keeps only project information, a pointer to this spec, and the few most lethal red lines — and those must be a **strict subset** of the Never list on this page, grouped the same way (data isolation / security / structure). **The test for pushing a rule down**: a session that does not go through Trellis cannot see an on-demand spec, and breaking this rule causes a real incident. A rule that fails that test stays on this page.
- **Do not write that subset as a fixed enumeration.** Both lists will grow, and the moment an enumeration falls behind, a reader will judge the starter "out of scope" when it has merely pushed down one more equally lethal rule. Check it by **finding each starter rule's counterpart in the Never list on this page** — having no counterpart is the violation.
- **Change this directory first**, then sync back to the starter. Changing the other direction drifts.

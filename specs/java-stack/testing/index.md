---
name: testing
description: The required checks, what to add per kind of change, how to verify behaviour and data, and how to prove each guard actually goes red
paths:
  - backend/src/test/**
  - frontend/e2e/**
---

# Quality Gates and Verification · Java Stack

> Everything is green before you say it is done. The track overview is in [`../README.md`](../README.md).

## Required checks (every time)

```bash
./gradlew spotlessCheck check
pnpm -C frontend typecheck && pnpm -C frontend lint && pnpm -C frontend test && pnpm -C frontend build
```

`./gradlew check` covers Java compilation, unit and integration tests (Testcontainers starts a real Postgres), the ArchUnit ownership rules, and the frontend's Vitest suite.

> **Testcontainers needs Docker running.** With Docker down, `check` fails with a connection error that is easily mistaken for a broken environment — glance at `docker ps` first.

## Add these, by kind of change

| What you touched | Also run |
|---|---|
| Formatting | `pnpm -C frontend format` · `./gradlew spotlessApply` |
| A page, route or flow | `./gradlew :backend:bootJar && pnpm -C frontend test:e2e` |
| The DB schema | First `docker compose -f docker-compose.dev.yml down -v && up -d`, and confirm it replays from an empty database |
| A persisted closed enum | Insert every current enum value through Testcontainers, and assert that a retired value and a random unknown one are both rejected by the CHECK |
| The backend API contract | Regenerate with `pnpm -C frontend api:types`, then `pnpm -C frontend typecheck` to see what broke |
| A list endpoint | Backend: pagination, secondary-sort stability, **every allow-listed sort field × both directions**, out-of-range parameters rejected, search escaping, two-account search isolation. Frontend: the provider's parameter clamping ([`../backend/index.md`](../backend/index.md) §10) |

**After `pnpm format` or `spotlessApply`, check yourself**: run `git status`. **If files appear that this task never edited**, find out why first, and either revert them or split them into a separate formatting change.

## E2E runs against the packaged artifact

The webServer in `playwright.config.ts` starts **`backend/build/libs/app.jar`**, not `vite dev`. This is not a preference:

- the Vite dev server ships its own history fallback, so **the SPA deep-link 404 is permanently green under dev**;
- it also bypasses Spring's static-resource path, so `SpaForwardConfig`'s exclusion list is never executed at all.

Running E2E against the dev server excludes the class of defect this track produces most easily and can self-check least.

```bash
docker compose -f docker-compose.dev.yml up -d   # Postgres
./gradlew :backend:bootJar                        # the SPA is packaged into the jar
pnpm -C frontend test:e2e
```

> `java -jar` uses **the JDK on your PATH**, not the one the Gradle toolchain downloaded. Anything below 25 on PATH reports `UnsupportedClassVersionError` — the build succeeded and the run failed, which looks like a broken artifact.

## What tests which

| Level | Tool | Location | Covers |
|---|---|---|---|
| Architecture constraints | **ArchUnit** | `src/test/java/**/architecture/` | That owner-scoped access is not bypassed |
| **The guards' own tests** | **Plain JUnit** (no container) | `src/test/java/**/architecture/` | That the rules above **still bite** |
| Backend integration | **JUnit 5 + Testcontainers** | `src/test/java/**/<module>/` | A real Postgres, a real filter chain, a real session |
| **Concurrency invariants** | **Plain JUnit + a thread pool** | Beside the component itself | Properties that appear only when requests arrive together (rate limiting, caps) |
| Frontend logic | **Vitest** | `frontend/src/**/*.test.ts` | Pure functions and logic |
| End to end | **Playwright** | `frontend/e2e/*.spec.ts` | Real flows against the packaged artifact |

Backend integration tests carry the session in a cookie (the `ApiIntegrationTest` base class). **Do not take a shortcut past the filter chain with something like `@WithMockUser`** — that leaves CSRF, sessions and authorization all untested, and those three are the easiest to misconfigure.

Integration tests do **not** carry `@Transactional`: rolling back the test transaction hides problems that only surface on a real commit.

**Rate limiting is application state, not test state.** This ruins tests in two ways, both of which look like "green alone, red together":

- **Tests in one context consume each other's budget.** MockMvc reports every request's client address as `127.0.0.1`, so to the rate limiter the whole suite is one caller. Have the base class **give each test instance its own address** and stamp it on every request — tests are independent callers already; this just says so.
- **The buckets are not reset between tests.** A test that asserts a specific budget empties the limiter first (inject the component, call a package-private `reset()`), or it is asserting how many tests ran before it.

**A property that only holds under concurrency needs a concurrency test.** A sequential loop is completely green against a "check then charge" implementation — it issues one request at a time and never hits the window. The shape is: a `CountDownLatch` releasing N threads at once, counting **how many were admitted**, and asserting that equals the budget rather than N.

## Two disciplines for writing tests

Both come from real runs: the same repository whose required checks were entirely green also held a batch of real defects. **"All green" proves that the checks somebody wrote passed**, not that everything worth checking was checked.

**Before rewriting a test file, enumerate the invariants the old file covered, then confirm one by one that the new file still covers them.** A deleted test turns no command red — it simply disappears. This track's most expensive property, ownership isolation, deserves particular attention: one E2E rewrite once dropped both cross-account isolation and post-logout route protection, and the gates stayed green throughout.

**A new assertion's expected value must be distinguishable from the result when the thing under test does nothing.** A test claiming to cover every sort field, whose expected values happen to equal the default ordering, passes even with sorting hard-coded away — it is asserting the default behaviour, not the behaviour under test. Ask afterwards: **if the thing I am testing did not work at all, would this assertion go red?**

## How to verify (behaviour and data)

1. `./gradlew :backend:bootRun` → `localhost:8080`: sign up → sign in → create, edit and delete in one business module → sign out
2. **Data isolation (negative, the most expensive one on this track)**: create a record as account A, then `GET` / `PUT` / `DELETE` it **using account B's session** — **all three must answer 404**; B's list must be empty; **and confirm afterwards that A's data was not modified** — otherwise an implementation that answers 404 while actually deleting passes the earlier assertions
3. **The cross-user exception (only when there is an admin path)**: call that admin endpoint with an ordinary account — **it must be refused**
4. **Authentication rate limiting (negative)**: exhaust the per-account budget, then sign in with the **correct** password — it must still be **429**. That is the only externally observable evidence that BCrypt did not run; an implementation that verifies first and rewrites the 401 into a 429 answers 200 here ([`../backend/index.md`](../backend/index.md) §4.2)
5. **Switching accounts leaves no afterimage**: open two tabs in one browser and sign out in one — the other must go to the login page by itself and stop showing that data, while the tab that initiated it was **not** reloaded ([`../frontend/index.md`](../frontend/index.md) §3.1)
6. **Failure states and retry**: make the list, the edit and the delete each fail once, and assert that what renders is a classified error plus a working Retry, **without an empty state alongside it**; a failure inside an overlay does not close the overlay
7. **Deep links after packaging**: `./gradlew :backend:bootJar && java -jar backend/build/libs/app.jar`, then **paste** a sub-route URL into the browser and reload — it must render
8. Required checks all green; every migration replays from an empty database

Items 2, 3, 4 and 7 are the ones most often skipped and the most expensive to skip. **Written is not working.**

Items 2, 3 and 4 are all **negative tests**: they prove that what should be refused is refused. A fully green set of positive cases cannot prove that, because none of them ever crossed a boundary or exhausted a budget. So they have to exist separately, and cannot be picked up incidentally by "the feature works".

## Proving the tests themselves work (falsification)

Every new guard is confirmed to **go red**, or you have only added a decoration that is green forever:

| Guard | How to prove it works |
|---|---|
| ArchUnit · parent-interface allow-list | Change a repository to `extends JpaRepository<T, ID>` → must go red. Then try `PagingAndSortingRepository` and a mixed-in `JpaSpecificationExecutor` separately: **the old deny-list rule is green for both** |
| ArchUnit · methods filter by owner | Hand-write an `Optional<T> findById(UUID)` on a bare `Repository` → must go red |
| ArchUnit · `@OwnerlessTable` tells the truth | Put `@OwnerlessTable` on the repository of an entity that **does carry `ownerId`** → rule three must go red. **Proving the passing half is not enough** — delete rule three entirely and the lookup-table cases stay green, while that interface-level exemption stops being checked by anything |
| The guards' own tests | Make an ArchUnit rule always true (never `violated`) → the negative test must go red. **This is the only thing that can detect a broken guard**, because a broken guard is itself green |
| The two-account negative test | Swap `findByIdAndOwnerId` for `findById` in the service → must go red |
| Rate limiting · rejection precedes verification | Move the budget check to **after** `authenticate()` → "even the correct password cannot get a 200 once the budget is gone" must go red |
| Rate limiting · reservation, not check-then-charge | Replace the atomic `tryConsume` with a two-step "read the remainder, then decrement" → the **concurrency** test must go red (the sequential test stays green, which is the whole point) |
| Rate limiting · not account lockout | Make rejected requests record a failure too → "the budget refills on its own" must go red |
| The tracking table's cap | Move the cap check outside the lock → the concurrent-insert test must go red |
| Input bounds · password | Submit a 73-byte password → must be 400. Then replace the validation with `@Size(max=72)` and submit 19 emoji (38 characters, 76 bytes) → must go red |
| Input bounds · email | Sign up with a 150-character email, then **use the resulting session for another request and sign in again** → all must pass; asserting only that signup returned 201 passes even when the column is too narrow |
| Switching accounts leaves no afterimage | Put `invalidateQueries()` back in place of `clear()` after a successful sign-in → the first frame still shows the previous account's data. Turn the broadcast off → the two-tab case must go red |
| Deep-link E2E | Remove `@Configuration` from `SpaForwardConfig` → must go red |
| Contract drift | Rename a field in `schema.d.ts` → `pnpm typecheck` must go red |
| A closed enum's value domain | Remove the database CHECK, or add a new value to the Java enum only → the current-values and unknown-value migration tests must go red |
| No credentials in the session | Empty the body of `eraseCredentials()` — **keep the method**; deleting it produces a compile error rather than a red test → must go red |
| A write response's timestamp | Put `save` back in place of `saveAndFlush` → must go red |
| The password guard | `env -u APP_DB_PASSWORD java -jar app.jar` → it must refuse before any Hikari or Flyway log line |

> **A script that modifies the working tree, such as `scripts/init-project.sh`, has its own set of falsification cases** — refusal paths, zero writes, ancestor validation, idempotence, parent-directory permissions, manifest completeness. They travel with that executable artifact, in the starter repository's `scripts/README.md` and `scripts/test-init-project.sh`, not on this page. This page lists guards on product code only.

> **The parenthesis on the "no credentials in the session" row is a real lesson**: deleting the whole method just leaves the class one interface method short, so the build fails at **compile time**. It looks like the test went red when the test never ran at all. **Falsification injects a behaviour error, never a compile error.**

**Change it back afterwards and re-run until everything is green.**

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

## Pre-Development Checklist

- [ ] Which kind of test does this change need? Logic → Vitest; backend behaviour → JUnit + Testcontainers; a page or flow → Playwright
- [ ] Is this a bug fix? **Write a failing test first**, then fix it
- [ ] Adding a per-user table, or an endpoint that reads or writes one? **A two-account negative test is mandatory**
- [ ] Adding a route? Add a **cold load and reload** case to E2E
- [ ] Adding or removing a persisted enum value? Add the positive case over the full current set, the negative cases for retired and random unknown values, and the assertion that the migration ships before the application writes
- [ ] Does this property hold only under concurrency (rate limiting, caps, de-duplication)? A sequential test is green against it — add one that starts together
- [ ] For each new guard, have you proven it goes red? If you changed **a guard itself**, is its own negative test updated to match?

## Quality Check

See "Required checks" on this page. Both must be green before you say it is done, plus whatever the kind of change adds.

Then check by hand:

- [ ] Docker is running (otherwise a Testcontainers failure reads as a code problem)
- [ ] E2E ran against the `bootJar` artifact, not the dev server
- [ ] Formatting did not incidentally touch files unrelated to this task

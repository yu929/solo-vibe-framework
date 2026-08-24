---
name: testing
description: The required checks, what to add per kind of change, how to verify behaviour and data, and where the test matrix and falsification rules live
paths:
  - backend/src/test/**
  - frontend/e2e/**
---

# Quality Gates and Verification · Java Stack

> Everything is green before you say it is done. **The level-to-tool matrix and proving the guards still bite are in the two sibling files below** — open the one your change touches.
>
> Track overview: [`../README.md`](../README.md).

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
| A list endpoint | Backend: pagination, secondary-sort stability, **every allow-listed sort field × both directions**, out-of-range parameters rejected, search escaping, two-account search isolation. Frontend: the provider's parameter clamping ([`../backend/write-path.md`](../backend/write-path.md) §10) |

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

## Two disciplines for writing tests

Both come from real runs: the same repository whose required checks were entirely green also held a batch of real defects. **"All green" proves that the checks somebody wrote passed**, not that everything worth checking was checked.

**Before rewriting a test file, enumerate the invariants the old file covered, then confirm one by one that the new file still covers them.** A deleted test turns no command red — it simply disappears. This track's most expensive property, ownership isolation, deserves particular attention: one E2E rewrite once dropped both cross-account isolation and post-logout route protection, and the gates stayed green throughout.

**A new assertion's expected value must be distinguishable from the result when the thing under test does nothing.** A test claiming to cover every sort field, whose expected values happen to equal the default ordering, passes even with sorting hard-coded away — it is asserting the default behaviour, not the behaviour under test. Ask afterwards: **if the thing I am testing did not work at all, would this assertion go red?**

## How to verify (behaviour and data)

1. `./gradlew :backend:bootRun` → `localhost:8080`: sign up → sign in → create, edit and delete in one business module → sign out
2. **Data isolation (negative, the most expensive one on this track)**: create a record as account A, then `GET` / `PUT` / `DELETE` it **using account B's session** — **all three must answer 404**; B's list must be empty; **and confirm afterwards that A's data was not modified** — otherwise an implementation that answers 404 while actually deleting passes the earlier assertions
3. **The cross-user exception (only when there is an admin path)**: call that admin endpoint with an ordinary account — **it must be refused**
4. **Authentication rate limiting (negative)**: exhaust the per-account budget, then sign in with the **correct** password — it must still be **429**. That is the only externally observable evidence that BCrypt did not run; an implementation that verifies first and rewrites the 401 into a 429 answers 200 here ([`../backend/auth-sessions.md`](../backend/auth-sessions.md) §4.2)
5. **Switching accounts leaves no afterimage**: open two tabs in one browser and sign out in one — the other must go to the login page by itself and stop showing that data, while the tab that initiated it was **not** reloaded ([`../frontend/data-layer.md`](../frontend/data-layer.md) §3.1)
6. **Failure states and retry**: make the list, the edit and the delete each fail once, and assert that what renders is a classified error plus a working Retry, **without an empty state alongside it**; a failure inside an overlay does not close the overlay
7. **Deep links after packaging**: `./gradlew :backend:bootJar && java -jar backend/build/libs/app.jar`, then **paste** a sub-route URL into the browser and reload — it must render
8. Required checks all green; every migration replays from an empty database

Items 2, 3, 4 and 7 are the ones most often skipped and the most expensive to skip. **Written is not working.**

Items 2, 3 and 4 are all **negative tests**: they prove that what should be refused is refused. A fully green set of positive cases cannot prove that, because none of them ever crossed a boundary or exhausted a budget. So they have to exist separately, and cannot be picked up incidentally by "the feature works".

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`test-matrix.md`](test-matrix.md) | Which level uses which tool and where it lives, plus the application state that leaks between tests | You are unsure where a new test belongs, or tests pass alone and fail together |
| [`falsification.md`](falsification.md) | Proving each guard actually goes red — a guard that stopped biting looks exactly like one with nothing to catch | You wrote or changed a guard, an ArchUnit rule, or a negative test |
| [`../ops/index.md`](../ops/index.md) | Application settings, compose, the packaged image and the release tag | You run the stack locally, change a setting, or cut a release |

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

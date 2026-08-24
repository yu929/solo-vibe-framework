---
name: backend
description: The one way to do each backend thing, the rules that fail silently, and where the full text of each lives
paths:
  - backend/src/main/java/**
---

# Backend and Auth Rules · Java Stack

> What you get on every backend edit: the one way to do each thing, and the two checklists. **The reasoning, the code and the traps are in the four sibling files** — open the one your change touches. Section numbers are shared across all five.
>
> Track overview and the Never list: [`../README.md`](../README.md). Migrations and tables: [`../database/index.md`](../database/index.md).

## Quick reference

| Operation | The one way |
|---|---|
| Reading or writing user data | The service method's **first parameter is `ownerId`**, through a repository that exposes owner-scoped methods only (`owner-scoping.md` §2.1) |
| Repository parent interface | **The bare `Repository<T, ID>` and nothing else, for every repository** — an allow-list, so `PagingAndSortingRepository` and a mixed-in `JpaSpecificationExecutor` are rejected too (`owner-scoping.md` §2.2) |
| Repository methods | The name genuinely filters by `ownerId` — split on `Or` first, every branch must contain it — or the method carries `@CrossUserQuery("reason")`, **on the method, never the interface** (`owner-scoping.md` §2.2) |
| A table with no ownership column at all | `@OwnerlessTable("reason")` on the interface, **not** `@CrossUserQuery` on every method. `app_user` is **not** ownerless — the row *is* the person (`owner-scoping.md` §2.4) |
| "Not mine" | Answer **404**, never 403 |
| A public and expensive endpoint | Rate limit it: separate budgets per address and per account, reserved atomically **before** verification (`auth-sessions.md` §4.2) |
| The current user | `CurrentUserService.requireUserId()`, called once in the controller and passed down |
| Sessions | Spring Session JDBC (stored in Postgres), httpOnly cookie, **no JWT**. Every route authenticates by default; going public is an explicit line in `SecurityConfig` (`auth-sessions.md` §4) |
| Write endpoints | `@RestController` + DTO record + `@Valid`; `saveAndFlush` then map; errors go through `ProblemDetail` and field errors carry an `errors` map (`write-path.md` §8.1) |
| List endpoints | Return `{ items, total }`; page, page size, sort and search are **each validated**, sort against an allow-list plus a fixed `id ASC` secondary key (`write-path.md` §10) |
| Layering | `Controller` → `Service` → `Repository` → DB. Controllers never touch repositories; **entities never leave the service** (`platform.md` §1) |
| Schema changes | Add a Flyway migration; `ddl-auto` is always `validate` (`platform.md` §7) |

## Which of those are green when you get them wrong

Each rule above is stated once; this is the half a rule cannot carry on its own — **what a violation looks like**. None of these produces an exception, a log line or a failing test.

- **A query missing `ownerId`** — a 200, real data, a clean log, green tests, until somebody sees another account's things.
- **A deny-list instead of the parent-interface allow-list** — `PagingAndSortingRepository` extends the bare `Repository` directly, so it passes while handing over `findAll(Sort)`.
- **`@OwnerlessTable` on a table that does have owners** — mislabelling `app_user` reads exactly like correct usage.
- **An ArchUnit guard that has stopped biting** — indistinguishable from one with nothing to catch; both are green.
- **A principal that skips `CredentialsContainer`** — no error, and password hashes pile up in `spring_session_attributes`.
- **Rate limiting that checks then charges** — sequential tests pass; only concurrent arrivals show *n* tokens admitting more than *n* requests.
- **Mapping before the flush** — the feature works, and only the timestamp in the response is the pre-write one.
- **Timestamps left at nanosecond precision** — macOS has microsecond precision anyway, so it diverges only inside a Linux container.
- **A sort with no fixed secondary key** — rows repeat across pages or vanish, and it reads like a frontend caching bug.
- **An SPA fallback that swallows backend prefixes** — the Vite dev server has its own fallback, so this only appears in the packaged jar.

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`owner-scoping.md`](owner-scoping.md) | §2 — the repository choke point, the two annotations, the three ArchUnit rules, testing the guards | You touch any repository, entity or cross-user read |
| [`auth-sessions.md`](auth-sessions.md) | §3 CSRF · §4 sessions, login, rate limiting, and matching API limits to what storage holds | You touch `SecurityConfig`, the auth controller, the session principal, or add a public endpoint |
| [`write-path.md`](write-path.md) | §5 the write/response seam · §8 validation and the error shape · §10 the list-endpoint contract | You write an endpoint that creates, updates or lists |
| [`platform.md`](platform.md) | §1 layering · §6 SPA deep links · §7 JPA prohibitions · §9 heterogeneous sub-services | You add an entity, a backend path, or consider splitting out a service |

## Pre-Development Checklist

- [ ] The repository you are about to create — is the bare `Repository` its **only** parent? (`PagingAndSortingRepository` and a mixed-in `JpaSpecificationExecutor` are equally rejected — `owner-scoping.md` §2.2)
- [ ] Adding a field to the session principal? It is serialized into the database — no credentials, tokens or keys (`auth-sessions.md` §4.1)
- [ ] Any "check whether it exists, then insert"? Let the unique index adjudicate and translate it into a 409 (`write-path.md` §5.1)
- [ ] Does a write endpoint's response carry a timestamp or version? Did you flush before mapping (`write-path.md` §5.2)?
- [ ] For every new query method, is the `OwnerId` in the name genuinely **filtering**? (`OrderBy` starts ordering, `Not` inverts, `Or` widens — `owner-scoping.md` §2.2)
- [ ] Did you add `@Query` to a method? The name stops counting as evidence — does that JPQL bind `ownerId`?
- [ ] Does the "not yours" path answer **404** rather than 403?
- [ ] Need to read across users? **Not allowed by default** — a genuine exception carries `@CrossUserQuery("reason")` on the **method** (`owner-scoping.md` §2.4), with negative acceptance
- [ ] Does a row in this table have somebody it belongs to? If not — lookup table, reference data, configuration — put `@OwnerlessTable("reason")` on the interface rather than `@CrossUserQuery` on each method. **A table like `app_user`, where the row *is* the person, does not count as ownerless** (`owner-scoping.md` §2.4)
- [ ] Is the new endpoint public, or does it do something expensive (hashing, an external call)? Is it rate limited, and is the rejection **before** the expensive operation (`auth-sessions.md` §4.2)?
- [ ] Does a new field's length or format limit match what its column, and that database, can really hold (`auth-sessions.md` §4.3)?
- [ ] Adding a list endpoint? Does it return `{ items, total }`? Are page, page size, sort allow-list and search length all validated? Is the fixed secondary key there (`write-path.md` §10)?
- [ ] Changed the sort allow-list or a parameter bound? Did you change the frontend's clamp **in the same commit** (`write-path.md` §10)?
- [ ] Will a new validation answer 400? Does it carry the `errors` map? Does the query-parameter handler carry it too (`write-path.md` §8.1)?
- [ ] Should a new route be public? **Authentication is the default** — to go public, register it explicitly in `SecurityConfig` and write down what an anonymous caller can read (`auth-sessions.md` §4); public plus expensive means rate limiting is mandatory
- [ ] Added a backend path? Add it to the SPA fallback's exclusion list (`platform.md` §6)
- [ ] Changed the schema? Add a Flyway migration only; `ddl-auto` does not move
- [ ] Adding or removing a persisted enum value? Is the database CHECK in step, and does the migration ship before anything writes it (`../database/conventions.md` §4.1)?
- [ ] Copied Boot 3 code from the internet? Check it against the package-trap table in `../README.md` first, Jackson 3 especially
- [ ] Splitting out a heterogeneous sub-service? First ask whether it can be finished synchronously in a service (`platform.md` §9)

## Quality Check

```bash
./gradlew spotlessCheck check
```

Then check by hand:

- [ ] The three ArchUnit rules are still green (parent-interface allow-list, every method visibly filtering by owner, `@OwnerlessTable` entities genuinely ownerless)
- [ ] Did you touch those rules? Are the guards' negative tests (`owner-scoping.md` §2.5) updated to match?
- [ ] Every new per-user table has a **two-account negative test** asserting that the other account's data was not modified
- [ ] No entity is returned straight from a controller
- [ ] No new `@ManyToMany` or `EAGER`
- [ ] No secret appears in `application.yml`, in source, or in any `VITE_*` variable

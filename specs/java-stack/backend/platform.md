# Layering, Persistence and Deployment Shape · Java Stack

> Where code goes, what JPA may not do, how the packaged SPA resolves deep links, and when a separate service is worth its cost.
>
> Part of the backend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across all five files, so a
> section reference means the same thing wherever it is cited.

## 1. Layering

`Controller` (HTTP, resolves the current user) → `Service` (business logic, transactions) → `Repository` (owner-scoped) → DB.

- **Controllers do not touch repositories**, and services do not touch `HttpServletRequest`.
- **Entities do not leave the service.** Controllers send and receive DTO records. Returning an entity drags JPA's loading behaviour into serialization, and lets the API contract drift with the table.
- `@Transactional(readOnly = true)` on the class; write methods override it with `@Transactional`.

## 6. SPA deep links and backend paths

The SPA is packaged into the jar, so Spring provides the fallback for client-side routing: any unmatched non-backend path forwards to `index.html`.

**This trap can never be reproduced in development**: the Vite dev server ships its own history fallback, so deep links work perfectly there. Only in the packaged jar does refreshing `/notes/<id>/edit` return 404. That is why E2E runs against the packaged artifact ([`../testing/index.md`](../testing/index.md)).

**The reverse trap is equally real** and has been walked into: the fallback must **exclude the prefixes the backend owns** — `api/`, `actuator/`, `v3/api-docs`, `swagger-ui`. Otherwise a disabled or misspelled backend path returns **200 and a full page of HTML**: the tool fetching `/v3/api-docs` to generate frontend types downloads HTML and then explodes somewhere far from the cause. **Adding a backend path means adding a line to that exclusion list.**

## 7. JPA prohibitions (each one maps to a class of silent failure)

| Rule | What breaks without it |
|---|---|
| `ddl-auto: validate`; never `update` or `create-drop` | Hibernate quietly alters tables, the schema diverges from the migrations, and replaying migrations on another machine behaves differently |
| `open-in-view: false` | Lazy loading fires during rendering: fine locally, N+1 under load, with a stack far from the offending code |
| No `@ManyToMany` | Hides the join table, leaves nowhere to add a field, and makes cascade behaviour hard to reason about |
| No `FetchType.EAGER` | Every query drags a chain of associations along; one change affects everything |
| Read several fields through a DTO projection or `@Query` | Returning entities drags loading behaviour into serialization |
| The ownership column is `UUID ownerId`, not `@ManyToOne` | An association pulls the user out on every list read; this column is only a filter |
| An entity's `equals`/`hashCode` is not based on mutable fields | Behaviour becomes unpredictable once it is in a collection |

## 9. Heterogeneous sub-services

> **This whole section does not apply when the project has no `services/` directory** — the scaffold has none, and most projects will not. It is kept because the trust-boundary reasoning is expensive, and nobody should have to walk through it again when the split is genuinely needed.

**When it is needed**: the product has an execution-heavy side — SSH deployment, calling a target system's internal API, heavy computation — that does not belong inside the web process.

**When it is not**: anything that can be finished synchronously in a service should not be split out. The cost of splitting is another deployment, another trust boundary, and another version to keep aligned.

**The standard pattern**: `services/<svc>/` carries its own `AGENTS.md` and `CLAUDE.md` (the root `CLAUDE.md`'s imports do not reach into subdirectories); jobs are dispatched over HTTP with a Bearer token; it gets its own compose file.

**The trust boundary**: a shared Bearer token proves only that "the caller is one of our services". It **does not prove which user this call belongs to**. So the worker's only input is a job id; the job's ownership is fixed at creation time by a user-scoped path; and every user table the worker reads goes through a query that **checks ownership explicitly**, never fetching by a primary key handed in from outside. Acceptance is negative here too: using A's job to reach B's resource must be refused.

---

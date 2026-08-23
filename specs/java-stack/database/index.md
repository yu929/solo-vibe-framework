---
name: database
description: Flyway as the only way schema changes, the three parts of a per-user table, the copied session schema, and where the conventions and local-stack traps are written down
paths:
  - backend/src/main/resources/db/migration/**
---

# Database Rules · Java Stack

> SQL appears only in `backend/src/main/resources/db/migration/`. **Column conventions and the local stack are in the two sibling files below** — open them when your change touches either. Section numbers are shared across all three.
>
> Track overview and the Never list: [`../README.md`](../README.md).

## Quick reference

| Situation | What to do |
|---|---|
| Changing the schema | Add a `V<n>__<name>.sql`; **never edit a migration that has been committed** |
| Creating a per-user table | Three parts, all required: an `owner_id not null` foreign key, an index on `owner_id`, and an owner-scoped repository |
| Checking a migration replays cleanly | `docker compose -f docker-compose.dev.yml down -v && up -d`, then start the application |
| How the schema is produced | **Flyway alone.** `ddl-auto` is permanently `validate` |

## 1. Flyway is the only thing that changes the schema

`spring.jpa.hibernate.ddl-auto: validate`, and **never `update` or `create-drop`**.

The problem with `update` is not that it works badly, it is that **it has no symptom**: Hibernate infers a DDL from the entities and applies it, and from then on your database and your migration scripts have diverged. Everything is fine locally until CI or a new environment replays the migrations from zero and gets **a differently shaped database**. `validate` shouts about that divergence at startup.

**A committed migration is never edited.** Environments that already ran it will not re-run it, and the checksum will no longer match. To fix something, add the next version.

## 2. The three parts of a per-user table

A per-user table's isolation rests entirely on these three plus one test. Miss one and it leaks.

```sql
create table <name> (
    id         uuid        primary key,
    owner_id   uuid        not null references app_user (id) on delete cascade,  -- ①
    ...
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index <name>_owner_id_idx on <name> (owner_id);                            -- ②
```

**① The ownership column is not-null with a foreign key**, making "who this row belongs to" a database constraint rather than a field some service remembers to fill.
**② An index on `owner_id`**, because every read filters by it.
**③ An owner-scoped repository**: see [`../backend/owner-scoping.md`](../backend/owner-scoping.md) §2.1 — it does not extend `JpaRepository`, and declares only methods that carry `ownerId`.

**④ Add a two-account negative test** ([`../testing/index.md`](../testing/index.md)). The first three are "it was written"; the fourth is "it works".

> **A table that is not per-user** — a lookup table, reference data, static configuration — has no `owner_id`, naturally. That is a legitimate exception, but it has to be said out loud in two places, or the next person cannot tell "deliberate" from "forgotten": **write a comment** in the migration, and put **`@OwnerlessTable("reason")`** on the repository interface ([`../backend/owner-scoping.md`](../backend/owner-scoping.md) §2.4).
>
> **Do not approximate it with `@CrossUserQuery` on each method** — that annotation is for genuine cross-user reads, and once the exception list is padded with harmless lookup queries, nobody reviews it. Watch the other direction too: a table like `app_user`, where the row **is** the person, does **not** count as ownerless; it keeps using `@CrossUserQuery`.

## 3. The Spring Session tables are copied, not written

The session tables come from the spring-session-jdbc jar and are copied **verbatim** into the first migration. Do not rewrite them from memory:

```bash
unzip -p ~/.gradle/caches/**/spring-session-jdbc-<version>.jar \
  org/springframework/session/jdbc/schema-postgresql.sql
```

Pair that with `spring.session.jdbc.initialize-schema: never` — table creation happens in exactly one place, Flyway.

When upgrading Spring Session: diff the new jar's schema against the copy in the repository, and **add a new migration** for any difference rather than editing the old one.

### 3.1 A copied schema does not necessarily fit your data

"Do not edit a copied migration" is not the same as "the copied sizes are right". A vendor schema is written against the vendor's own general assumptions, and what you put into it is **your** data.

The one already walked into: `SPRING_SESSION.PRINCIPAL_NAME` is `VARCHAR(100)` in the vendor schema, while this track's principal name is the email, and `app_user.email` is unbounded `text`. So an address longer than 100 characters means:

1. the user row **inserts and commits**;
2. the request then hits the column width and explodes while writing the session.

The result is an account that **exists and can never be signed into**, failing with the same 500 on every attempt. It looks like an outage, it is an input-length problem, and the bad data is already in the database.

**How to handle it:**

- Add **a new migration** with `alter column ... type`; do not touch V1. Widen rather than truncating the input — widening also rescues accounts that already exist, while truncating locks them out permanently.
- **Write in that migration that this is a deliberate deviation from the vendor schema**, and that it needs re-confirming when Spring Session is upgraded. Otherwise the next person diffs, finds a difference, and assumes they copied it wrong.
- **The API's length validation and this column width are one decision**, changed together ([`../backend/auth-sessions.md`](../backend/auth-sessions.md) §4.3).

**And one general rule alongside it**: after adopting any third-party schema — sessions, a job queue, an audit table — walk through **what you will be putting into each of its columns**. What these mismatches have in common is that they explode in the **second half** of the write chain, after the first half has already committed.

## 6. Verifying a migration you just wrote

```bash
docker compose -f docker-compose.dev.yml down -v   # discard local data
docker compose -f docker-compose.dev.yml up -d
./gradlew :backend:bootRun                          # Flyway replays from zero, then JPA validates
```

Only a clean start shows the migration holds in a fresh environment. **"It worked" against a database with existing data proves nothing** — that run may have applied only the incremental step.

Integration tests use Testcontainers and get a fresh database every time, so `./gradlew check` covers "the migrations replay" naturally.

---

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`conventions.md`](conventions.md) | §4 — column types, closed enums constrained by a CHECK, and timestamp precision | You add or change a column, or persist an enum |
| [`local-database.md`](local-database.md) | §5 — bringing the local stack up, resetting it, and the traps that exist only on a developer machine | The local database misbehaves, or you reset it |

## Pre-Development Checklist

- [ ] Is the SQL only in `db/migration/`, with none in application code?
- [ ] Is the new migration a **new file**, leaving every committed migration untouched?
- [ ] Does the per-user table carry `owner_id not null references app_user(id)` and an index?
- [ ] For a table that is not per-user, is there a comment in the migration and `@OwnerlessTable("reason")` on the repository? (Not `@CrossUserQuery` on each method.)
- [ ] Are time columns `timestamptz`? Does case-insensitive uniqueness use an expression index?
- [ ] Does Java read a string column as a closed enum? Does the database have a CHECK over the same value domain, and does the forward migration for a new value ship before the application writes it?
- [ ] Has the new project run `scripts/init-project.sh <project-name>`? (Skipping it shares the local data volume, so `down -v` wipes the other project.)

## Quality Check

```bash
docker compose -f docker-compose.dev.yml down -v && docker compose -f docker-compose.dev.yml up -d
./gradlew check     # Testcontainers replays every migration on a fresh database
```

Then check by hand:

- [ ] The application starts from zero on an **empty database** (`validate` reports no schema mismatch)
- [ ] The new table has a two-account negative test, and **it has been proven to go red** — remove the ownership predicate once and watch
- [ ] The closed-enum constraint accepts every current value and rejects both a retired value and a random unknown one; with the CHECK removed, the negative test goes red
- [ ] `V*__spring_session.sql` has not been hand-edited

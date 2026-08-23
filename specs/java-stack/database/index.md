---
name: database
description: Flyway as the only way schema changes, the three parts of a per-user table, the copied session schema, closed enums constrained in the database, and the local volume-name trap
paths:
  - backend/src/main/resources/db/migration/**
---

# Database Rules · Java Stack

> SQL appears only in `backend/src/main/resources/db/migration/`. The track overview and the Never list are in [`../README.md`](../README.md).

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
**③ An owner-scoped repository**: see [`../backend/index.md`](../backend/index.md) §2.1 — it does not extend `JpaRepository`, and declares only methods that carry `ownerId`.

**④ Add a two-account negative test** ([`../testing/index.md`](../testing/index.md)). The first three are "it was written"; the fourth is "it works".

> **A table that is not per-user** — a lookup table, reference data, static configuration — has no `owner_id`, naturally. That is a legitimate exception, but it has to be said out loud in two places, or the next person cannot tell "deliberate" from "forgotten": **write a comment** in the migration, and put **`@OwnerlessTable("reason")`** on the repository interface ([`../backend/index.md`](../backend/index.md) §2.4).
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
- **The API's length validation and this column width are one decision**, changed together ([`../backend/index.md`](../backend/index.md) §4.3).

**And one general rule alongside it**: after adopting any third-party schema — sessions, a job queue, an audit table — walk through **what you will be putting into each of its columns**. What these mismatches have in common is that they explode in the **second half** of the write chain, after the first half has already committed.

## 4. Time and type conventions

- Time columns are always `timestamptz`, `Instant` on the application side, with `spring.jpa.properties.hibernate.jdbc.time_zone: UTC`.
- Primary keys are `uuid`, generated by Hibernate (`@GeneratedValue(strategy = GenerationType.UUID)`) — not auto-increment, so ids cannot be enumerated.
- Case-insensitive uniqueness (email) uses an **expression unique index**: `create unique index ... on app_user (lower(email))`, with queries going through `lower(...)` too. A `toLowerCase()` in the application layer alone does not stop a concurrent insert.

### 4.1 A closed enum's value domain is constrained in the database too

With an `enum` on the Java side and `@Enumerated(EnumType.STRING)` on the field, it is easy to feel the value domain is already under control. What is under control is **the one path that goes through the application's write entry point**. Migration scripts, manual SQL, data restores and instances of an older version still running can each write a string that enum does not know.

And it does not explode on the write side: the bad value lands, the transaction commits normally, and then some query reads that row and calls `Enum.valueOf` — **taking the whole list page down with it**, rather than degrading that one row. One dirty row flattens a whole screen, which is what makes it more expensive than ordinary dirty data.

So the column carries a CHECK whose value set matches the current Java enum:

```sql
-- Wrong: Java treats it as a closed set while the database accepts any string
event_type varchar(64) not null

-- Right: both sides share one explicit value domain
event_type varchar(64) not null
    constraint audit_event_type_check
    check (event_type in ('LOGIN', 'LOGOUT'))
```

**Changing the value domain has an order, and the two directions are not symmetric:**

- **Adding a value**: ship the migration that widens the CHECK first, then let the application write the new value. The other order fails the write outright (PostgreSQL `23514`) — that is a release-ordering mistake, and **the fix is not to loosen the constraint on the spot**.
- **Removing a value**: existing rows are adjudicated in **the same forward migration**, before the CHECK is tightened. If the existing rows have not been dealt with, let the migration fail rather than letting it through with a batch of rows that can no longer be read.

Both directions add new migrations only, never editing one that has run (§1).

**Fail closed on an unrecognized value.** For formal records such as audits and job status especially: adding an `UNKNOWN` fallback, or silently filtering out rows that will not parse, both translate "the data is corrupt" into "the data is gone" — the same class of false claim as [`../frontend/index.md`](../frontend/index.md) §1.2. What counts as a real thing to stay compatible with, worth keeping an old value for, is in [`../guides/review-adjudication.md`](../guides/review-adjudication.md).

**Prove it goes red**: after replaying the migrations on an empty database, insert every member of `Enum.values()` — all must succeed; then insert a retired value and a random string — both must be rejected. With the CHECK removed, that negative test must go red ([`../testing/index.md`](../testing/index.md)).

## 5. The local development database

Three separate traps: which volume it uses, which interface it listens on, and which password it starts with.

### 5.1 The project-name trap

The first thing a new project runs is `scripts/init-project.sh <project-name>`.

**Compose derives the volume name from the project name.** Skip this and every project generated from this template **shares one Postgres volume** — project A's `docker compose down -v` silently wipes project B's data.

The same script also changes the session cookie name: the default `JSESSIONID` is shared by every application on localhost, so two projects in development sign each other out.

### 5.2 The development database binds to loopback only

Writing `"5432:5432"` in compose means `0.0.0.0:5432` — **publishing the development database on every interface**. Combined with a fixed password committed to a public template repository, that is a database anybody can connect to from a café's wifi or a corporate network.

Always write **`"127.0.0.1:5432:5432"`**. Everything that connects to it — the application, an IDE, psql — runs on this machine, and none of it needs the database visible from outside.

### 5.3 The database password has no default, not even one that looks like a development value

`application.yml` **carries no default for the password**, not even one named `dev-only-not-a-secret`. The reason is not the naming, it is the **silent fallback**: any startup path with the variable unset — a bare `java -jar`, a systemd unit, a k8s manifest missing one env entry — **starts successfully** on that publicly known password.

The password's only source is an **uncommitted `.env`** (seeded from `.env.example`), which `bootRun` reads; deployments use environment variables.

#### But "no default" does not mean "it will fail" — two counter-intuitive traps

**Trap one: the variable name must not be the property's relaxed-binding form.**

```yaml
password: ${SPRING_DATASOURCE_PASSWORD}   # ← self-referential
```

`SPRING_DATASOURCE_PASSWORD` is precisely the environment-variable form of `spring.datasource.password`, so this asks the property to resolve itself. With the variable unset it collapses to an empty string instead of failing. **Use a name that is not an alias of the property**, such as `APP_DB_PASSWORD`.

**Trap two: a failed placeholder resolution does not abort startup either.**

Spring Boot **ignores unresolvable placeholders** when binding `@ConfigurationProperties`, and hands the literal string `${APP_DB_PASSWORD}` to the driver. Most servers answer `password authentication failed` — cryptic, but at least fatal. With Postgres configured for `trust` authentication, **any password passes**, and the application comes up normally on a credential nobody ever set. Another one with no symptom.

**So `main()` blocks it explicitly**, checking environment variables and system properties before `SpringApplication.run` and throwing when they are missing. That guard needs a unit test, with the environment lookup passed in as a parameter — a JVM cannot change its own environment variables.

> Both traps came out of running it: first the assumption that "removing the default will make it fail", which turned out to be `password authentication failed`; then a rename, which still did not fail. **"I assumed it would error" is not verification.**

## 6. Verifying a migration you just wrote

```bash
docker compose -f docker-compose.dev.yml down -v   # discard local data
docker compose -f docker-compose.dev.yml up -d
./gradlew :backend:bootRun                          # Flyway replays from zero, then JPA validates
```

Only a clean start shows the migration holds in a fresh environment. **"It worked" against a database with existing data proves nothing** — that run may have applied only the incremental step.

Integration tests use Testcontainers and get a fresh database every time, so `./gradlew check` covers "the migrations replay" naturally.

---

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

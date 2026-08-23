---
name: backend
description: Layering, owner-scoped data access, CSRF, auth and sessions, rate limiting, JPA prohibitions, SPA fallback and the list-endpoint contract
paths:
  - backend/src/main/java/**
---

# Backend and Auth Rules · Java Stack

> One way to do each thing. The track overview and the Never list are in [`../README.md`](../README.md); migrations and table creation are in [`../database/index.md`](../database/index.md).

## Quick reference

| Operation | The one way |
|---|---|
| Reading or writing user data | The service method's **first parameter is `ownerId`**, through a repository that exposes owner-scoped methods only |
| Repository parent interface | **The bare `Repository<T, ID>` and nothing else, for every repository** (an allow-list: every other parent is rejected, `PagingAndSortingRepository` and mixed-in `JpaSpecificationExecutor` included) |
| Repository methods | The name genuinely filters by `ownerId`, or the method carries `@CrossUserQuery("reason")` — **on the method, never the interface** |
| A table with no ownership column at all | `@OwnerlessTable("reason")` on the interface (§2.4), **not** `@CrossUserQuery` on every method |
| "Not mine" | Answer **404**, never 403 |
| A public and expensive endpoint | Rate limit it: separate budgets per address and per account, reserved atomically **before** verification (§4.2) |
| The current user | `CurrentUserService.requireUserId()`, called once in the controller and passed down |
| Sessions | Spring Session JDBC (stored in Postgres), httpOnly cookie, **no JWT** |
| Write endpoints | `@RestController` + DTO record + `@Valid`; errors go through `ProblemDetail`, field errors carry an `errors` map (§8.1) |
| List endpoints | Return `{ items, total }`; page, page size, sort and search are **each validated**, sort against an allow-list plus a fixed secondary key (§10) |
| Schema changes | Add a Flyway migration; `ddl-auto` is always `validate` |

## 1. Layering

`Controller` (HTTP, resolves the current user) → `Service` (business logic, transactions) → `Repository` (owner-scoped) → DB.

- **Controllers do not touch repositories**, and services do not touch `HttpServletRequest`.
- **Entities do not leave the service.** Controllers send and receive DTO records. Returning an entity drags JPA's loading behaviour into serialization, and lets the API contract drift with the table.
- `@Transactional(readOnly = true)` on the class; write methods override it with `@Transactional`.

## 2. Owner-scoped data access (the heaviest section on this track)

**Start with why this is needed.** Isolation on this track has no database backstop — it is the `owner_id = ?` in the query, and omitting it produces **no symptom at all**: a 200, real data, a clean log, green tests. It surfaces the day somebody notices they can see other people's things.

A rule a human has to remember every time is not a rule. So it is decomposed into things a machine checks: **the dangerous methods do not exist** (§2.1), **every build checks it** (§2.2), **two-account negative tests prove it actually holds** (§2.3), and **the guards themselves still bite** (§2.5).

### 2.1 Structural: the dangerous methods do not exist

**Every** repository **extends the bare `Repository<T, ID>`** — not only the ones for per-user entities; see the end of rule one in §2.2. On top of that, a per-user entity's repository declares only methods that carry `ownerId`:

```java
public interface NoteRepository extends Repository<Note, UUID> {
    List<Note> findAllByOwnerIdOrderByUpdatedAtDesc(UUID ownerId);
    Optional<Note> findByIdAndOwnerId(UUID id, UUID ownerId);
    @Transactional long deleteByIdAndOwnerId(UUID id, UUID ownerId);
    Note saveAndFlush(Note note);
}
```

`JpaRepository` hands you `findById`, `findAll`, `deleteById` and `existsById` for free — none of them owner-aware, all of them on the first screen of autocomplete. **Do not extend it and those methods do not exist**, so the wrong call cannot be written.

> The write method declares `saveAndFlush`, not `save`. This is the easiest line to lose when copying this template: `save` defers the flush to commit, by which time the controller has already mapped the entity into a response — so the write returns the timestamp from **before** the change. The reasoning and the acceptance test are in §5.2.

> This is not a style preference. `extends JpaRepository` is the line everyone types by reflex, and it opens the leak by default.

**Dangerous methods come from two places, and both are closed:**

| Source | What it looks like |
|---|---|
| **Inherited** | `extends JpaRepository` hands over four owner-blind methods |
| **Hand-written** | `Optional<Note> findById(UUID id)` declared on a bare `Repository` — nothing inherited, and it leaks identically |

Closing only the first is the common half-measure.

### 2.2 Machine-enforced: three ArchUnit rules

They live in `architecture/RepositoryChokePointTest` and run with `./gradlew check`.

**Rule one · the parent interface is an allow-list, not a deny-list.**

```java
// The bare Repository is the only permitted parent; everything else is a violation,
// including parents nobody has heard of yet.
repository.getRawInterfaces() must equal { org.springframework.data.repository.Repository }
```

Writing it as a deny-list — "must not be assignable to `CrudRepository`" — leaks, and leaks without symptoms:

- **`PagingAndSortingRepository`** has extended the bare `Repository` **directly** since Spring Data 3.0, no longer through `CrudRepository`. So it passes a deny-list while handing over `findAll(Sort)` and `findAll(Pageable)`. "Extends `Repository`" no longer describes the rule at all.
- **`JpaSpecificationExecutor` and `QueryByExampleExecutor`** are not `Repository` subtypes in the first place, so a check like `areAssignableTo(Repository)` cannot see them. Let one in and the whole table can be pulled out through a Specification or an Example.

**This rule applies to every repository, including tables with no ownership** — lookup tables, reference data, configuration. Neither annotation buys a wider parent interface; the reasoning is at the end of §2.4. The cost is one hand-written `List<Dict> findAll();` on a lookup repository. What it buys is that "the parent-interface allow-list **has no exceptions**" carries no conditions to remember — and a rule with conditions attached is exactly the kind of thing this section opened by ruling out.

**Rule two · every declared method must visibly filter by owner**, or carry `@CrossUserQuery`; when the table has no ownership column at all, `@OwnerlessTable` instead (both are in §2.4). "Visibly" means genuinely parsing the derived query name, not searching for the substring `OwnerId` — every one of these contains it, and not one filters by it:

| Written as | What it actually means |
|---|---|
| `findAllByOrderByOwnerId` | **Sorts** by owner and selects the whole table. Everything after `OrderBy` is ordering, so truncate there before judging |
| `findByOwnerIdNot` | The exact opposite: the rows that are **not** yours |
| `findByIdOrOwnerId` | `Or` **widens** — either side suffices, so a known id reaches anybody's row |
| `findByOwnerIdAndTitleOrId` | The nastiest one. It parses as `(ownerId AND title) OR id`: the owner predicate is real, and the branch beside it still reads everyone's data |
| `findAllByOwnerId()` | A perfect name with **no parameter** to bind |
| `@Query("select n from Note n")` on `findByIdAndOwnerId` | `@Query` overrides the derived query entirely, so the name stops being evidence |

So the check is: **split on `Or` first, and every branch must contain `OwnerId`** — a disjunction is as wide as its widest branch. Then confirm the method really accepts a `UUID`, and that a method carrying `@Query` really binds `ownerId` inside that JPQL.

> Text splitting misjudges property names that contain `Or` or `And` themselves, such as `orderNumber`. **That direction is safe**: it fails, and asks you to rename the property or write a `@CrossUserQuery` explaining why — rather than waving through a query nobody has read.

Write methods (`save`, `saveAndFlush`) are exempt: they persist an aggregate the caller **already** obtained through an owner-scoped finder, so there is no predicate for them to carry.

**Rule three · `@OwnerlessTable` must be telling the truth.** For a repository carrying that annotation, the machine checks that its entity really has **no** `ownerId` field, and fails when it does.

This rule is the precondition that makes rule two's exemption safe. `@OwnerlessTable` is **interface-level**: one annotation covers every method on that interface, now and in future. So it has to be **a claim a machine can check**, not a self-description. Without rule three, mislabelling it — accidentally or deliberately — on a per-user table switches off ownership checking for the whole table in one line, and looks exactly like correct usage.

### 2.3 Negative tests: two accounts

See item 2 of "How to verify" in [`../testing/index.md`](../testing/index.md). The essentials: **reaching A's resource id while authenticated as B must answer 404**, and the test must also assert **A's data is still there** — otherwise an implementation that answers 404 while actually deleting the row passes the first assertion.

A fully green set of positive cases proves nothing about isolation: none of them ever attempted to cross a boundary.

### 2.4 Two annotations, covering two different things

**`@CrossUserQuery` is the only registered exception for cross-user access, and its scope is defined in this section alone.** When cross-user access is needed elsewhere, come back and read this table rather than copying the conclusion.

The other annotation, `@OwnerlessTable`, **is not an isolation exception** — it declares that the table holds nothing to isolate. Their shapes and their disciplines differ completely, so do not conflate them:

| | `@CrossUserQuery` | `@OwnerlessTable` |
|---|---|---|
| Claims | **This query** crosses users, for the reason given | **This table's** rows belong to nobody |
| Goes on | The **method** (interface level is forbidden outright) | The **interface** (it is a property of the table, not of one query) |
| Machine-checkable | No — only the written reason | Half of it (§2.2 rule three) |
| Typical | Finding an account by email at login; an admin export | Lookup tables, reference data, static configuration |

**How to tell, in one question: does a row in this table have somebody it belongs to?**

- **No** — a currency table, a region table, a feature flag → `@OwnerlessTable`.
- **Yes** — even when the ownership is not a column called `ownerId`, as with **`app_user`, where the row *is* the person** → keep annotating method by method with `@CrossUserQuery`.

**This boundary is held by a human, and a machine cannot hold it**: `app_user` and a lookup table are identical on the question "does it have an `ownerId` field", and rule three passes both. What rule three catches is **mislabelling** — a genuine per-user table with `ownerId` declared ownerless. It does not catch deliberate misclassification. Mark `AppUserRepository` as `@OwnerlessTable` and anybody who later adds a `findAll()` can pull out every account — while **looking exactly like correct usage**.

#### `@CrossUserQuery`

Some queries genuinely have no owner to carry: login has to find the account **before there is a session to scope by**; admin views and background jobs really do cross accounts. These are exceptions, and **an invisible exception is indistinguishable from a mistake**.

So an exception takes the form of an annotation, never a quietly widened interface:

```java
@CrossUserQuery("login and signup: the user table has no owner, and this runs before there is a session to scope by")
@Query("select u from AppUser u where lower(u.email) = lower(:email)")
Optional<AppUser> findByEmailIgnoringCase(@Param("email") String email);
```

It puts the reason beside the code, and makes every exception in the repository **listable with one command**.

**It goes on methods only, never on an interface.** That is deliberate: an interface-level exemption automatically covers every method added to that interface later — including methods nobody wrote a reason for, added by somebody who never saw the exemption. One exception equals one method plus one reason.

| Allowed | Forbidden |
|---|---|
| `@CrossUserQuery("reason")` on the **method** | On the interface, or swapping in a wider parent |
| An **explicitly named** service such as `AdminNoteQueryService`, whose method names carry the admin meaning | Adding `findById` / `findAll` to a business repository |
| An **explicit permission check** inside that service — is the current user an admin — written at the method's entry | Skipping it because "the caller already validated" |
| A separate repository interface for it, again declaring only the methods it truly needs | Business code casually reusing that admin path |

**Acceptance is negative**: an ordinary account calling that admin endpoint must be refused. Having written a role check is not the same as it working.

#### `@OwnerlessTable`

Lookup tables, reference data and static configuration have no ownership column at all, so none of their methods can possibly filter by `ownerId`:

```java
@OwnerlessTable("currency reference data: rows belong to the system, every account reads all of them")
public interface CurrencyRepository extends Repository<Currency, String> {
    List<Currency> findAll();
    Optional<Currency> findByCode(String code);
}
```

**Why not approximate it with `@CrossUserQuery` on each method**: that drowns out the signal saying "this genuinely reads across users". `@CrossUserQuery` earns its keep by making **one command list every cross-user access** for review — and when half that list is harmless lookup-table queries, nobody reviews it. **The enemy of an exception mechanism is noise, not only omission.**

**Why it may go on the interface** while `@CrossUserQuery` may not: it states a **property of the table**, equally true of every method on that interface now and later, so an interface-level exemption cannot quietly extend to a new method nobody considered. The price is that it must be **a checkable fact** — which is §2.2 rule three, plus the reminder above that a machine holds only half of it.

**Neither annotation buys a wider parent interface.** §2.2 rule one has no exceptions: an inherited `findAll` is an owner-blind path nobody chose to write, and somebody reading the code later cannot tell which method the exemption was originally for. A lookup table that wants `findAll()` declares the line itself — **a hand-written line is a decision somebody made; an inherited one is not**.

### 2.5 Testing the guards themselves

The three ArchUnit rules above need their own **negative test** (`architecture/RepositoryChokePointGuardTest`): feed the rules a batch of **deliberately wrong** repositories, every one of which must be rejected, then feed them correct ones, which must pass.

The reason is simple: **a guard that has stopped working and a guard with nothing to catch are both green**, and the result cannot tell them apart. This guard protects the property the whole track rests on.

The negative fixtures cover at minimum every row of the two tables in §2.2, plus three things that are easy to forget:

- Fixture interfaces carry **`@NoRepositoryBean`**. The test classes sit on the classpath that repository scanning walks, so without it the container really does gain a set of owner-blind repository beans — written to be rejected, and never meant to exist in usable form at the same time.
- Assert **which method was named**, not merely that an exception was thrown. When `@CrossUserQuery` sits on one method, another unannotated method on the same interface must still be reported; asserting only "it went red" lets an implementation pass that waves through a whole interface on sight of the annotation.
- **Feed `@OwnerlessTable` from both directions**: on a genuinely ownerless entity it must pass, or lookup tables become unwritable; on an entity carrying `ownerId` it must be rejected by rule three. **Feed only the passing half and rule three can be deleted while everything stays green** — and rule three is the only reason that interface-level exemption is safe.

## 3. CSRF: that one line stays

The session is a cookie, so CSRF protection must be on. The configuration is:

```java
CsrfTokenRequestAttributeHandler handler = new CsrfTokenRequestAttributeHandler();
handler.setCsrfRequestAttributeName(null);   // ← this line
http.csrf(csrf -> csrf
        .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
        .csrfTokenRequestHandler(handler));
```

**What `setCsrfRequestAttributeName(null)` does**: Spring Security 6+ loads the CSRF token **lazily** by default — nobody reads it, so it is not generated; it is not generated, so no `XSRF-TOKEN` cookie is issued. The frontend has no token, and every write request gets a 403.

**Why this sends people the wrong way**: a 403 looks like a permission problem. People go through `authorizeHttpRequests`, through roles, through the session — while the cause sits somewhere unrelated to authorization.

On the frontend side, the `X-XSRF-TOKEN` header is added once by `dataProvider`, **never at individual call sites**. The first token arrives with the `GET /api/auth/me` issued when the page mounts.

## 4. Auth and sessions

- **Spring Session JDBC**: sessions live in Postgres. Restarts do not sign people out, instances share state, and no sticky sessions are needed.
- The session table is created by **Flyway** (`spring.session.jdbc.initialize-schema=never`), with the schema copied out of the spring-session-jdbc jar — see [`../database/index.md`](../database/index.md) §3.
- **Login is done explicitly** in `AuthController` (`AuthenticationManager.authenticate` → `saveContext`), because the client sends JSON. **Logout goes to the framework's logout filter** — session invalidation is not something to hand-write.
- **Session fixation protection**: after a successful login, call `request.changeSessionId()` when a session already existed. Hand-writing login means taking this over too.
- **No JWT.** Revisit it when statelessness is genuinely needed; do not pull in the whole refresh-token apparatus by default.
- **Every route requires authentication by default, and going public is an explicit decision.** The scaffold makes only `/api/auth/login` and `/api/auth/signup` public, because that is the only path it has — **that is the scaffold's shape, not this track's ceiling**. Landing pages, public read-only data, share links, health checks and webhook callbacks are all legitimate public routes: add one explicitly in `SecurityConfig`, and write down **what an anonymous caller can read** in the same place. **How to tell**: would it matter whether the reader is signed in? Not being able to answer means it is not ready to be public. The one thing that never relaxes is the other rule — **an expensive operation on a public route must be rate limited** (§4.2).
- **The cookie name is per project** (`server.servlet.session.cookie.name`). The default `JSESSIONID` is shared by every application on localhost, so two projects in development sign each other out. `scripts/init-project.sh` changes it.
- **To disable self-service signup while keeping login**: `app.auth.signup-enabled=false`. That closes the signup endpoint only; existing users sign in as usual. Do not close the whole authentication path.
- The failure message for "no such email" and for "wrong password" **must be identical**, or the login endpoint becomes an account enumerator.

### 4.1 No credentials in the session

The session principal **implements `CredentialsContainer` and clears the password hash in `eraseCredentials()`**.

**Why this matters especially on this track**: sessions live in Postgres, and the principal is Java-serialized into `spring_session_attributes.attribute_bytes`. A principal carrying `passwordHash` copies `app_user.password_hash` into a second table on every login — a table that only grows, outlives the login, and is readable by anything that can read the database. A carefully guarded column becomes a pile of unguarded rows.

`ProviderManager` calls `eraseCredentials()` after successful authentication by default, but **only when the principal implements that interface** — and not implementing it produces no error, it just quietly skips the erasure.

**Acceptance can only look at the bytes**: query `spring_session_attributes` and assert that the byte string of `app_user.password_hash` appears in no `attribute_bytes` row. Asserting "`eraseCredentials` was called" proves nothing — what needs proving is that the stored bytes do not contain it.

### 4.2 Authentication endpoints must be rate limited

Login and signup are **public** and **deliberately expensive** — BCrypt is designed to be slow. Without rate limiting, one machine resubmitting the same **already-registered** email saturates the CPU while the database sits idle: signup hashes **before** the unique index adjudicates, so every guaranteed-to-fail request pays a full BCrypt. Password guessing is the same shape.

**Two budgets, defending two different things:**

| Budget | Counts | Defends against |
|---|---|---|
| **Per client address** | **Every** attempt, successful or not | One host burning CPU. Charging every time is fine, because it is charging its own budget |
| **Per account** | Reserved **atomically on entry** to each attempt, **returned in full** after a successful authentication | A botnet spreading guesses against one account across thousands of hosts |

Three things in this section are **all required**; dropping any one degrades it into a different incident.

**① The rejection must come before the password is verified.** Put it after — run BCrypt, then rewrite the 401 into a 429 — and the rate limiting is reduced to a status code: an attacker rotating addresses still triggers unlimited BCrypt and still walks through passwords one at a time. **The observable acceptance test is exactly this**: when the budget is exhausted, **even the correct password must not get a 200**. That is the only externally visible evidence that BCrypt did not run.

**② It must be a reservation, not "check then charge".** Querying the budget and decrementing it are two steps with a window between them: with one token left, 64 requests arriving together all **read** that token, all **pass**, and all **buy** a password hash — only the few that actually decrement are recorded afterwards. **A limit that is checked but not held is not a limit.** Use an atomic operation such as `tryConsume` to make admission and accounting one step, so *n* tokens admit exactly *n* requests.

> This is visible only under concurrency. A sequential loop makes that "check then charge" code look entirely correct — which is why the acceptance test must be a concurrency test (see [`../testing/index.md`](../testing/index.md)).

**③ It must not become account lockout.** Two properties together guarantee that:

- **A rejected request is charged nothing** (`tryConsume` is all-or-nothing). So the traffic hitting the wall does not pin the budget at zero; it refills on schedule and the rate limiter recovers on its own.
- **A successful authentication returns the whole budget**, so the account's owner does not pay for one typo — or for somebody else's guessing — with the rest of the minute.

**Residual risk, stated plainly**: **while** a fast distributed attack is under way, the account's owner competes with the attack traffic for the tokens trickling back, and may get a 429 and need to retry. That is the real cost of rate limiting that genuinely bites. The actual solution is a human challenge or a second factor — something that lets a real person prove they are not a botnet — and that is a product decision this track does not make for you. What this design rules out is the version with **no way out**, where an attacker pins the budget at zero permanently and locks the account.

**The remaining rules, each one a trap already walked into:**

- **The client address comes from `getRemoteAddr()` and never from `X-Forwarded-For`.** The client writes that header, so trusting it hands an attacker unlimited identities. Behind a reverse proxy, set `server.forward-headers-strategy=native` and let Tomcat's own valve rewrite `getRemoteAddr()` — the same information, handled by the thing that knows which hop to trust. **Forgetting to configure it is equally an incident**: every request then appears to come from the proxy's single address, the whole internet shares one budget, and the first ordinary user exhausts it.
- **The tracking table needs a hard cap**, or the rate limiter itself becomes the memory-exhaustion entry point. And **the cap check must be inside the same lock as the insert**: "read `size`, then `computeIfAbsent`" is not a cap — threads arriving together all read a size under the limit and all insert, so a cap of 8 tracks 64 new addresses.
- **When the table is full, refuse new callers rather than admitting them.** A full table means this many distinct callers are being rate limited at once, which means **a flood is under way**; admitting untracked callers at that moment switches the rate limiter off exactly when it is most needed. Refusing new logins does not affect existing sessions, and it recovers when the flood passes.
- **Evict only full buckets** — refilled means that caller has been quiet long enough that forgetting it changes nothing. Evicting buckets that are short of tokens evicts precisely the callers **still being limited**, handing an attacker a reset they can obtain by flooding the table with new keys.
- **Refill greedily (trickling back), not on an interval (full at the top of the period).** An interval lets an attacker align requests to the boundary and take a full burst every period.
- **A 429 carries `Retry-After`**, rounded up — `Retry-After: 0` invites the client to immediately retry a request that is certain to fail.
- **Normalize the account key** (trim and lowercase), matching what the unique index on email uses, or a change of case buys a fresh budget.
- **In-process buckets mean one budget per instance.** On a single-instance deployment that is an honest trade — no extra Redis to run — but scaling horizontally means moving to a bucket in shared storage.

### 4.3 What the API accepts must be what the storage underneath can hold

When validation misses a real downstream limit, **the failure lands after the write** — half the work is done and the user gets a 500. Two real examples, neither visible from the DTO:

**BCrypt takes only 72 bytes.** Since Spring Security 6.3 it throws `IllegalArgumentException` beyond that (earlier versions truncated silently). It happens inside `PasswordEncoder.encode`, halfway through signup, where nothing catches it. A password manager generating a 100-character passphrase reaches it.

- **`@Size(max = 72)` cannot express this limit**: BCrypt counts **bytes**, `@Size` counts **characters**. Nineteen emoji are 38 Java characters and 76 UTF-8 bytes — they stroll past the character check and hit the same 500. Write a custom constraint that counts UTF-8 bytes.
- **Only signup needs it.** Verification goes through `BCrypt.checkpw`, which returns false for an over-long password rather than throwing, so login is already a 401.

**The session table's `PRINCIPAL_NAME` holds the email.** In the vendor schema it is `VARCHAR(100)`, while `app_user.email` is unbounded `text`. So an address longer than 100 characters means the user row **commits successfully** and the request then explodes writing the session. The result is an account that exists and **can never be signed into**, failing with a 500 every time — which looks like an outage and is an input problem.

- The fix is **widening the column** (a new migration, see [`../database/index.md`](../database/index.md) §3), not truncating the email to 100: widening also rescues accounts that already exist, while truncating locks them out permanently.
- **The API's length limit and that column width are one decision**, changed together. 254 is the maximum email length RFC 5321 permits.
- Acceptance must **cross that write**: asserting signup returns 201 is not enough. Use the resulting session for another request, and sign in **again** — because the explosion is in the session write, not in the user insert.

## 5. The write path

Three rules about the seam between a write and what comes back from it: which layer adjudicates a conflict, when the flush happens, and what precision survives the round trip.

### 5.1 Uniqueness is adjudicated by a constraint, not by an exists check

"Check whether it exists, then insert" is a TOCTOU: two concurrent requests both pass the check, the second insert hits the unique index, and the caller gets a **500**.

**The problem with that 500 is not that it is ugly**: it is indistinguishable from "the server is broken", so nobody investigates it as a race.

The correct approach is to **remove the up-front check**, let the unique index be the sole adjudicator, and translate the constraint violation into a 409:

```java
try {
    users.saveAndFlush(new AppUser(email, encoded));
} catch (DataIntegrityViolationException alreadyTaken) {
    throw new ConflictException("That email is already registered.");
}
```

Note `saveAndFlush`: without the flush, the conflict is not thrown until commit, which is already outside the `try`.

A useful side effect: with the up-front check gone, the conflict path becomes **deterministically testable** — run it twice in sequence — instead of depending on a concurrency test winning a race. A concurrency test is still worth adding, but as reinforcement rather than the only coverage.

### 5.2 A write's response must reflect that write

`@PreUpdate` and `@PrePersist` run at **flush**, and the service usually maps the entity into a DTO before that — so a `PUT` returns the `updatedAt` from **before** the change, and a second `GET` is needed to see the new value.

A client that relies on the response for optimistic updates, ETags or a "last saved at" display shows wrong data outright, and this bug is invisible to any test that only asks whether the feature works.

**The approach**: write paths call `saveAndFlush` and then map, making the lifecycle callback the **only** source of the timestamp.

> Do not "also stamp the timestamp in `edit()`". That creates two sources, the value in the response and the value in the database differ by tens of microseconds, and it is harder to diagnose.

**Acceptance**: assert the `PUT` response's `updatedAt` is strictly later than the created value, **and** that the `GET` immediately after equals it exactly. Assert only the first and an implementation with two timestamp sources passes too.

### 5.3 Truncate timestamps to microseconds (another one that is invisible locally)

Every stamped timestamp is `Instant.now().truncatedTo(ChronoUnit.MICROS)`.

`timestamptz` stores **microseconds**, while `Instant.now()` on Linux yields **nanoseconds**. So the in-memory value and the value read back from the database differ in their last digits — a write's response and the read that follows are **not byte-equal**, and any client comparing timestamps for equality (ETags, "has this changed", optimistic concurrency) draws the wrong conclusion.

**Why it slips past the tests**: `Instant.now()` on macOS has only microsecond precision anyway, so the two sides are naturally equal on a development machine and the tests are green. It diverges only inside a Linux container. **This was found by checking by hand inside a container, not by a test** — which is why "verify it once for real, in a container" is not a step to skip.

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

## 8. Where server-side validation goes

Bean Validation (`@Valid` plus constraints on the record) runs at the controller boundary; errors become a `ProblemDetail` through `ApiExceptionHandler`, and the frontend renders the `detail` field.

That **does not** mean the other layers may trust unconditionally:

- **Authorization is enforced server-side.** Hiding an entry point in the frontend, or a route guard, is not authorization.
- **Data invariants are backstopped by the database** — NOT NULL, foreign keys, unique constraints. Concurrent requests, background jobs and migration scripts never pass through a controller.
- **A closed enum's value domain is constrained by the database too.** A string column the application reads with `Enum.valueOf` or `@Enumerated(EnumType.STRING)` has a matching CHECK; a new value ships as a migration before anything writes it. The details and the negative test are in [`../database/index.md`](../database/index.md) §4.1.

The criteria are in [`../guides/cross-layer.md`](../guides/cross-layer.md), under "validation scattered across layers".

### 8.1 Field errors must be locatable, and the two handlers must produce one shape

A 400 carrying only `detail` gives the frontend no way to locate the offending field, leaving it to render the whole thing as one sentence. **A Bean Validation 400 keeps `detail` and adds an `errors` map: field name → human-readable message**, normalized by `dataProvider` and handed to the form for inline display.

**Request bodies and query parameters go through two different handlers** — a `@Valid` record throws `MethodArgumentNotValidException`, constraints on controller method parameters throw `ConstraintViolationException`. Handle only the first and a query-parameter 400 arrives without `errors`, the frontend degrades to a single root error, and the premise that there is one error shape collapses on the spot. Both must produce the same shape: build the key from the **last segment** of the property path for `ConstraintViolationException`, and use an ordered map when there are several violations so that `detail` is stable for a given input.

**Every query-parameter constraint declares a human-readable `message` explicitly.** Bean Validation's defaults are in English, and `@Pattern` prints the regex verbatim — and `detail` is exactly the string the frontend renders word for word, so a regex would appear on the user's screen.

## 9. Heterogeneous sub-services

> **This whole section does not apply when the project has no `services/` directory** — the scaffold has none, and most projects will not. It is kept because the trust-boundary reasoning is expensive, and nobody should have to walk through it again when the split is genuinely needed.

**When it is needed**: the product has an execution-heavy side — SSH deployment, calling a target system's internal API, heavy computation — that does not belong inside the web process.

**When it is not**: anything that can be finished synchronously in a service should not be split out. The cost of splitting is another deployment, another trust boundary, and another version to keep aligned.

**The standard pattern**: `services/<svc>/` carries its own `AGENTS.md` and `CLAUDE.md` (the root `CLAUDE.md`'s imports do not reach into subdirectories); jobs are dispatched over HTTP with a Bearer token; it gets its own compose file.

**The trust boundary**: a shared Bearer token proves only that "the caller is one of our services". It **does not prove which user this call belongs to**. So the worker's only input is a job id; the job's ownership is fixed at creation time by a user-scoped path; and every user table the worker reads goes through a query that **checks ownership explicitly**, never fetching by a primary key handed in from outside. Acceptance is negative here too: using A's job to reach B's resource must be refused.

---

## 10. The list-endpoint contract

The frontend's `getList` expects a `{ data, total }` shape, so list endpoints return `{ items, total }` and `dataProvider` maps it. **Do not paginate a full array in the frontend** — that hides the permission and performance contract inside the provider, and makes both cross-user access and out-of-range values invisible.

Four things are each validated; missing one carries an illegal value into SQL:

| Parameter | Constraint |
|---|---|
| Page | One-based, with an upper bound |
| Page size | Has an upper bound |
| Sort field and direction | **An allow-list**, not a free string |
| Search term | Has a length limit |

**A unique secondary key (`id ASC`) is always appended after the user's chosen sort.** When sort values repeat, OFFSET pagination can both repeat a row across adjacent pages and drop one entirely — and **nothing errors**. It shows up as "I see duplicates when paging", which looks like a frontend caching problem and sends the investigation in completely the wrong direction.

**Escape `!`, `%` and `_` in the search term first**, then do a case-insensitive literal contains, or a `%` the user typed becomes a wildcard.

**The allow-list must be the same list the frontend clamps against.** The type layer cannot carry this constraint — the generated `schema.d.ts` widens these parameters back to `string` and `number` — so each side carries a comment pointing at the other and at the paired test, and **changing one means changing the other in the same commit** (the frontend half is in [`../frontend/index.md`](../frontend/index.md) §3.2).

The repository is still a bare `Repository`, and the list query still carries `ownerId` (§2). **The two-account negative test must cover search**: assert that account B's `items` and `total` are both zero, and confirm afterwards that A's data was not modified.

## Pre-Development Checklist

- [ ] The repository you are about to create — is the bare `Repository` its **only** parent? (`PagingAndSortingRepository` and a mixed-in `JpaSpecificationExecutor` are equally rejected — §2.2)
- [ ] Adding a field to the session principal? It is serialized into the database — no credentials, tokens or keys (§4.1)
- [ ] Any "check whether it exists, then insert"? Let the unique index adjudicate and translate it into a 409 (§5.1)
- [ ] Does a write endpoint's response carry a timestamp or version? Did you flush before mapping (§5.2)?
- [ ] For every new query method, is the `OwnerId` in the name genuinely **filtering**? (`OrderBy` starts ordering, `Not` inverts, `Or` widens — §2.2)
- [ ] Did you add `@Query` to a method? The name stops counting as evidence — does that JPQL bind `ownerId`?
- [ ] Does the "not yours" path answer **404** rather than 403?
- [ ] Need to read across users? **Not allowed by default** — a genuine exception carries `@CrossUserQuery("reason")` on the **method** (§2.4), with negative acceptance
- [ ] Does a row in this table have somebody it belongs to? If not — lookup table, reference data, configuration — put `@OwnerlessTable("reason")` on the interface rather than `@CrossUserQuery` on each method. **A table like `app_user`, where the row *is* the person, does not count as ownerless** (§2.4)
- [ ] Is the new endpoint public, or does it do something expensive (hashing, an external call)? Is it rate limited, and is the rejection **before** the expensive operation (§4.2)?
- [ ] Does a new field's length or format limit match what its column, and that database, can really hold (§4.3)?
- [ ] Adding a list endpoint? Does it return `{ items, total }`? Are page, page size, sort allow-list and search length all validated? Is the fixed secondary key there (§10)?
- [ ] Changed the sort allow-list or a parameter bound? Did you change the frontend's clamp **in the same commit** (§10)?
- [ ] Will a new validation answer 400? Does it carry the `errors` map? Does the query-parameter handler carry it too (§8.1)?
- [ ] Should a new route be public? **Authentication is the default** — to go public, register it explicitly in `SecurityConfig` and write down what an anonymous caller can read (§4); public plus expensive means rate limiting is mandatory
- [ ] Added a backend path? Add it to the SPA fallback's exclusion list (§6)
- [ ] Changed the schema? Add a Flyway migration only; `ddl-auto` does not move
- [ ] Adding or removing a persisted enum value? Is the database CHECK in step, and does the migration ship before anything writes it ([`../database/index.md`](../database/index.md) §4.1)?
- [ ] Copied Boot 3 code from the internet? Check it against the package-trap table in [`../README.md`](../README.md) first, Jackson 3 especially
- [ ] Splitting out a heterogeneous sub-service? First ask whether it can be finished synchronously in a service (§9)

## Quality Check

```bash
./gradlew spotlessCheck check
```

Then check by hand:

- [ ] The three ArchUnit rules are still green (parent-interface allow-list, every method visibly filtering by owner, `@OwnerlessTable` entities genuinely ownerless)
- [ ] Did you touch those rules? Are the guards' negative tests (§2.5) updated to match?
- [ ] Every new per-user table has a **two-account negative test** asserting that the other account's data was not modified
- [ ] No entity is returned straight from a controller
- [ ] No new `@ManyToMany` or `EAGER`
- [ ] No secret appears in `application.yml`, in source, or in any `VITE_*` variable

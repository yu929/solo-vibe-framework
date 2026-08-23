# Owner-Scoped Data Access · Java Stack

> The heaviest section on this track. Isolation here has no database backstop — it is the `owner_id = ?` in the query, so every guard below exists because the failure it prevents has no symptom.
>
> Part of the backend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across all five files, so a
> section reference means the same thing wherever it is cited.

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

> The write method declares `saveAndFlush`, not `save`. This is the easiest line to lose when copying this template: `save` defers the flush to commit, by which time the controller has already mapped the entity into a response — so the write returns the timestamp from **before** the change. The reasoning and the acceptance test are in [`write-path.md`](write-path.md) §5.2.

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

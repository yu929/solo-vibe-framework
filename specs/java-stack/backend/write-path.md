# The Write Path and the List Contract · Java Stack

> The seam between a write and what comes back from it, the shape a validation error takes, and the contract every list endpoint honours.
>
> Part of the backend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across all five files, so a
> section reference means the same thing wherever it is cited.

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

## 8. Where server-side validation goes

Bean Validation (`@Valid` plus constraints on the record) runs at the controller boundary; errors become a `ProblemDetail` through `ApiExceptionHandler`, and the frontend renders the `detail` field.

That **does not** mean the other layers may trust unconditionally:

- **Authorization is enforced server-side.** Hiding an entry point in the frontend, or a route guard, is not authorization.
- **Data invariants are backstopped by the database** — NOT NULL, foreign keys, unique constraints. Concurrent requests, background jobs and migration scripts never pass through a controller.
- **A closed enum's value domain is constrained by the database too.** A string column the application reads with `Enum.valueOf` or `@Enumerated(EnumType.STRING)` has a matching CHECK; a new value ships as a migration before anything writes it. The details and the negative test are in [`../database/conventions.md`](../database/conventions.md) §4.1.

The criteria are in [`../guides/cross-layer.md`](../guides/cross-layer.md), under "validation scattered across layers".

### 8.1 Field errors must be locatable, and the two handlers must produce one shape

A 400 carrying only `detail` gives the frontend no way to locate the offending field, leaving it to render the whole thing as one sentence. **A Bean Validation 400 keeps `detail` and adds an `errors` map: field name → human-readable message**, normalized by `dataProvider` and handed to the form for inline display.

**Request bodies and query parameters go through two different handlers** — a `@Valid` record throws `MethodArgumentNotValidException`, constraints on controller method parameters throw `ConstraintViolationException`. Handle only the first and a query-parameter 400 arrives without `errors`, the frontend degrades to a single root error, and the premise that there is one error shape collapses on the spot. Both must produce the same shape: build the key from the **last segment** of the property path for `ConstraintViolationException`, and use an ordered map when there are several violations so that `detail` is stable for a given input.

**Every query-parameter constraint declares a human-readable `message` explicitly.** Bean Validation's defaults are in English, and `@Pattern` prints the regex verbatim — and `detail` is exactly the string the frontend renders word for word, so a regex would appear on the user's screen.

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

**The allow-list must be the same list the frontend clamps against.** The type layer cannot carry this constraint — the generated `schema.d.ts` widens these parameters back to `string` and `number` — so each side carries a comment pointing at the other and at the paired test, and **changing one means changing the other in the same commit** (the frontend half is in [`../frontend/data-layer.md`](../frontend/data-layer.md) §3.2).

The repository is still a bare `Repository`, and the list query still carries `ownerId` ([`owner-scoping.md`](owner-scoping.md) §2). **The two-account negative test must cover search**: assert that account B's `items` and `total` are both zero, and confirm afterwards that A's data was not modified.

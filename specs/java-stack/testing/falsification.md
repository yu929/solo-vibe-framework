# Proving the Tests Themselves Work · Java Stack

> A guard that has stopped biting and a guard with nothing to catch are both green. This is how you tell them apart.
>
> Part of the testing spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across the whole layer, so a
> section reference means the same thing wherever it is cited.

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

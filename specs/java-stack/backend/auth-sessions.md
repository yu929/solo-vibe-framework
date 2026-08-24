# CSRF, Auth and Sessions · Java Stack

> How a session is established and kept, what may never be stored in it, and why the public endpoints in front of it have to be rate limited.
>
> Part of the backend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across all five files, so a
> section reference means the same thing wherever it is cited.

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

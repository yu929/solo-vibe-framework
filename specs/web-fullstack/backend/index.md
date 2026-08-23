---
name: backend
description: Data access through Supabase, auth and sessions, the explicit auth cookie name, where server-side validation goes, and the trust boundary for a heterogeneous sub-service
paths:
  - src/lib/**
  - src/app/**/actions.ts
  - src/proxy.ts
---

# Backend and Auth Rules · Web Fullstack

> One way to do each thing. The track overview and the Never list are in [`../README.md`](../README.md); the database and RLS are in [`../database/index.md`](../database/index.md).

## Quick reference

| Operation | The one way |
|---|---|
| Reading data | Inside a Server Component: `const supabase = await createClient()` (from `server.ts`), then `.select()` |
| Writing data | **Server Actions** (`"use server"`). **Never a new API Route Handler for a form** |
| Refreshing the session | Only in `src/proxy.ts → updateSession` |
| The Supabase key | The **publishable key** in both the browser and the server (`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`) |
| Writing cookies | Leave it to the proxy or a server action; **never write one directly in a Server Component** |

## 1. Reading and writing data

- **Read**: `await createClient()` inside a Server Component, then `.select()`.
- **Write**: always Server Actions. No new API Route Handler for a form.
- **The client is generic**: `createClient<Database>()`, with types from the generated `database.types.ts`.

The three Supabase entry points each have one job: `client.ts` for the browser, `server.ts` for the server, `middleware.ts` for refreshing the session.

## 2. Auth

Supabase Auth, email and password.

- Session refresh happens **only** in `src/proxy.ts → updateSession`.
- Protected routes are intercepted in one place by the proxy; unauthenticated requests go to `/login`.
- **Every route requires authentication by default, and going public is an explicit decision.** The scaffold's public prefixes are only `/login`, `/signup` and `/auth`, because that is the only path it has — **that is the scaffold's shape, not this track's ceiling**. Landing pages, public read-only pages, share links, health checks and webhook callbacks are all legitimate public routes: add one explicitly to the proxy's public-prefix table, and write down **what an anonymous caller can read** in the same place. **How to tell**: would it matter whether the reader is signed in? Not being able to answer means it is not ready to be public. Data read on a public route still goes through RLS ([`../database/index.md`](../database/index.md) §1).
- `requireUser()` lives in `src/lib/auth/require-user.ts` (server-only plus react cache). Once there is a `profiles` table, extend it with `requireAdmin` in the same file.

## 3. The auth cookie name must be set explicitly

All three Supabase entry points — client, server, middleware — carry `cookieOptions: { name: SUPABASE_AUTH_COOKIE_NAME }`, defined in `src/lib/supabase/auth-cookie.ts` and renamed per project.

**What happens without it**: supabase-js derives the cookie name from the URL's hostname. In a self-hosted deployment the server uses `SUPABASE_INTERNAL_URL` while the browser uses the public URL, so the two names diverge and the browser client silently falls back to anon — queries answer 401, and every Realtime event is blocked by RLS.

**Why it is easy to miss**: the two URLs are identical in local development, so it **can never be reproduced there**.

## 4. Disabling signup while keeping login

For an invite-only setup where an administrator creates accounts and self-service signup is closed:

```toml
[auth]
enable_signup = false          # → GoTrue DISABLE_SIGNUP, disables signup globally

[auth.email]
enable_signup = true           # → EXTERNAL_EMAIL_ENABLED, keeps the email login channel open
```

**Do not** set `[auth.email].enable_signup` to `false` — that closes the entire email provider, and existing users get `Email logins are disabled`.

There is also **no** `[auth.email].enabled` key; a recent CLI refuses to start when it sees one.

**This trap surfaces only on a fresh `supabase start` in CI**; reusing a local auth container hides it. After changing this, verify with `supabase stop && supabase start`.

## 5. Where server-side validation goes

Form validation is written in the server action (see [`../frontend/index.md`](../frontend/index.md) §3), but that **does not** mean the other layers may trust unconditionally:

- **Authorization is enforced server-side.** Hiding an entry point in the client is not authorization.
- **Data invariants are backstopped by the database** — RLS, unique constraints, foreign keys, NOT NULL. Concurrent requests, background jobs and migration scripts never pass through a server action.

The criteria are in [`../guides/cross-layer.md`](../guides/cross-layer.md), under "validation scattered across layers".

## 6. Heterogeneous sub-services (a Python executor, for instance)

> **First decide whether this section applies: does the project have a `services/` directory?** The scaffold does not, and most projects will not. **When it does not, this section and every cross-reference pointing at it do not apply** — the "registered controlled exception" in [`../README.md`](../README.md)'s Never list, the "only controlled exception" in [`../database/index.md`](../database/index.md) §1, and item 3 of "How to verify" in [`../testing/index.md`](../testing/index.md) are all void, and the rule reduces to its simplest form: **do not bypass RLS, no exceptions**.
>
> This section is kept because the trust-boundary reasoning is expensive and nobody should walk through it twice when the split is genuinely needed. Until you have a `services/` directory, it is worth nothing to you.

**When it is needed**: the product has an execution-heavy side — SSH deployment, calling a target system's internal API, heavy computation — that does not belong inside the Next process. Split it out, and let Next dispatch jobs over HTTP with a Bearer token.

**When it is not**: anything that can be finished synchronously in a server action should not be split out. The cost of splitting is another deployment, another trust boundary, and another version to keep aligned.

**The standard pattern:**

1. **Directory**: `services/<svc>/`, with Python dependencies managed by **uv** (FastAPI plus `pyproject.toml` and `uv.lock`).
2. **The paired convention**: that directory carries its own `AGENTS.md` (the locked rules for that track) and `CLAUDE.md` (one line, `@AGENTS.md`) — the root `CLAUDE.md`'s imports **do not** reach into subdirectories, so a heterogeneous sub-project brings its own pair. Add a line to the root `AGENTS.md`: read `services/<svc>`'s own `AGENTS.md` before editing it.
3. **The trust boundary**: §6.1 below, the one part of this section that must not be abbreviated.
4. **Release coupling**: `pnpm release:validate` already checks that `services/*/pyproject.toml` versions match the tag. Add that service's quality job (ruff, mypy, pytest) plus image build and OCI metadata verification to `release.yml`.
5. **Compose**: the sub-service gets its own `docker-compose.<svc>.yml`, started and stopped separately from the app.

### 6.1 The trust boundary: a worker consumes only jobs whose ownership is already bound

**Start with what a shared Bearer token proves**: only that "the caller is our Next app". It **does not prove which user this call belongs to**. And service-role bypasses RLS. Put those together, and if the worker is willing to fetch by a primary key handed in from outside, then a key that was guessed, replayed, or simply passed wrong by Next is a cross-tenant read — with nothing at the database level to stop it.

So **a worker may not fetch user data by an arbitrary primary key**. It goes in three parts instead.

**① The job is created by a user-scoped path.** Next writes a row into the job table from a server action using the ordinary client (publishable key plus RLS), taking `user_id` from `auth.uid()` and **never from the client**. The job table itself is created with the three parts in [`../database/index.md`](../database/index.md) §2 — grant, RLS, policies. Ownership is fixed by the database at this step, rather than carried along later as a parameter.

**② The worker consumes by job id only.** Its single input is a job id. Every user table it reads goes through a **database function that checks ownership explicitly** — the function compares that job's `user_id` or `tenant_id` against the target row's owner and raises on a mismatch. **A bare `service_role` `.select()` on an externally supplied primary key is not allowed.**

**③ The exception's scope is fixed and does not widen.**

| service-role may | service-role may not |
|---|---|
| Update that job's status, progress and result, by job id | Read or write user data across jobs |
| Call one of those ownership-checking database functions | Fetch from a user table by an externally supplied primary key |
| Read its own runtime configuration | Skip the ownership check because "Next already validated it" |

**This is the only controlled exception to "do not bypass RLS" in [`../database/index.md`](../database/index.md) §1, and its scope is defined in this section alone.** When service-role is needed elsewhere, come back and read this table rather than copying this section's conclusion.

**④ Ciphertext does not travel over HTTP.** **Next does not send ciphertext over HTTP**; keys are injected through the environment, and the encryption format the two sides share is maintained in one place.

**⑤ Acceptance is negative.** Having written an ownership check is not the same as it working, and the only thing that counts is this: using tenant A's job to reach tenant B's resource key **must be refused**. See item 3 of "How to verify" in [`../testing/index.md`](../testing/index.md). This matches how the track treats RLS in general — a policy that is written gets tried with a second account.

> By the same reasoning, the identity groundwork "every internal tool needs" — administrator-created accounts, disabled self-service signup, brute-force protection, TOTP, LDAP — **is not pre-installed**. Implement what the project actually needs, in the slice that needs it. The scaffold keeps the minimum that runs, and does not decide for you what you may not want.

---

## Pre-Development Checklist

- [ ] Do reads go through a Server Component with `createClient()`, rather than some other route?
- [ ] Do writes go through a Server Action, with **no** new API Route created for a form?
- [ ] Does a new Supabase entry point carry `cookieOptions: { name: SUPABASE_AUTH_COOKIE_NAME }`?
- [ ] Is this operation's **authorization** enforced server-side? (Hiding an entry point in the client does not count.)
- [ ] Using `service_role`? **Not allowed by default** — a genuine exception is recorded explicitly as a controlled exception
- [ ] Should a new route be public? **Authentication is the default** — to go public, add it explicitly to the proxy's public-prefix table and write down what an anonymous caller can read (§2); the data it reads still goes through RLS
- [ ] Splitting out a heterogeneous sub-service? First ask whether it can be finished synchronously in a server action (§6)
- [ ] For **every** user table the sub-service reads this time, which database function performs the ownership check? Not being able to name the function means it was not done (§6.1)
- [ ] Is any input parameter "a primary key for user data handed in from outside"? That means the design took a wrong turn — a worker's only input is a job id

## Quality Check

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

Then check by hand:

- [ ] No cookie is written directly in a Server Component
- [ ] No DB client, secret or server-only module is imported into a client component
- [ ] After an auth configuration change, `supabase stop && supabase start` was used to re-verify (an old container hides the signup-configuration trap)

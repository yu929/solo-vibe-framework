---
name: backend
description: Data access through Supabase, auth and sessions, the explicit auth cookie name, and where server-side validation goes
paths:
  - src/lib/**
  - src/app/**/*.ts
  - src/proxy.ts
---

# Backend and Auth Rules · Web Fullstack

> One way to do each thing. The track overview and the Never list are in [`../README.md`](../README.md); the database and RLS are in [`../database/index.md`](../database/index.md).
>
> Section numbers are shared with the sibling file listed below, so a section reference means the same thing wherever it is cited.

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

---

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`sub-services.md`](sub-services.md) | §6 — when splitting an execution-heavy service out of Next is worth its cost, and the trust boundary a worker holding service-role must respect | The project has a `services/` directory, or you are considering adding one |

## Pre-Development Checklist

- [ ] Do reads go through a Server Component with `createClient()`, rather than some other route?
- [ ] Do writes go through a Server Action, with **no** new API Route created for a form?
- [ ] Does a new Supabase entry point carry `cookieOptions: { name: SUPABASE_AUTH_COOKIE_NAME }`?
- [ ] Is this operation's **authorization** enforced server-side? (Hiding an entry point in the client does not count.)
- [ ] Using `service_role`? **Not allowed by default** — a genuine exception is recorded explicitly as a controlled exception
- [ ] Should a new route be public? **Authentication is the default** — to go public, add it explicitly to the proxy's public-prefix table and write down what an anonymous caller can read (§2); the data it reads still goes through RLS
- [ ] Splitting out a heterogeneous sub-service? First ask whether it can be finished synchronously in a server action (`sub-services.md` §6)
- [ ] For **every** user table the sub-service reads this time, which database function performs the ownership check? Not being able to name the function means it was not done (`sub-services.md` §6.1)
- [ ] Is any input parameter "a primary key for user data handed in from outside"? That means the design took a wrong turn — a worker's only input is a job id (`sub-services.md` §6.1)
- [ ] Writing a test, or fixing a bug? [`../testing/index.md`](../testing/index.md) says which kind to write and what to do first

## Quality Check

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

Then check by hand:

- [ ] No cookie is written directly in a Server Component
- [ ] No DB client, secret or server-only module is imported into a client component
- [ ] After an auth configuration change, `supabase stop && supabase start` was used to re-verify (an old container hides the signup-configuration trap)

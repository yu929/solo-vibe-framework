---
name: database
description: RLS as the isolation mechanism, the three parts of a new table, the migration workflow, generated types, and the local stack's project-name trap
paths:
  - supabase/migrations/**
---

# Database Rules · Web Fullstack

> SQL appears only in `supabase/migrations/`. The track overview and the Never list are in [`../README.md`](../README.md).

## Quick reference

| Situation | What to do |
|---|---|
| Changing the schema | `supabase migration new <name>` → `pnpm db:reset` → `pnpm db:types` |
| Creating a table | Three parts, all required: grant, enable RLS, policies |
| Data isolation | An RLS policy of `(select auth.uid()) = user_id`; inserts carry `user_id` explicitly |
| Generated types | `pnpm db:types`; **never hand-edit** `database.types.ts` |

## 1. Data isolation (RLS)

Per-user data **must** have RLS enabled.

- Policies are written as `(select auth.uid()) = user_id`.
- Inserts carry `user_id` **explicitly**.
- **Do not bypass RLS**: no service-role client reads or writes user data.

**The only controlled exception** is a heterogeneous sub-service's worker, whose scope and invariants are defined in [`../backend/sub-services.md`](../backend/sub-services.md) §6.1 — **defined there once and nowhere else**. **When the project has no `services/` directory, that exception does not exist**, "do not bypass RLS" has no exceptions at all, and this paragraph can be skipped entirely. In outline: the worker's only input is a job id; the job's ownership is fixed at creation time by a user-scoped path plus RLS; and every user table the worker reads goes through a database function that checks ownership explicitly, never fetching by an externally supplied primary key. When service-role looks useful elsewhere, do not carry over the conclusion that "the sub-service is allowed to".

## 2. The three parts of a new table

Every table-creating migration contains **all three**; missing one causes a problem:

```sql
-- ① Grant: Supabase no longer exposes a new table to the Data API automatically,
--    and without the grant you get "permission denied"
grant select, insert, update, delete on table <name> to authenticated;

-- ② Turn on row level security
alter table <name> enable row level security;

-- ③ RLS policies, per operation
create policy "..." on <name> for select using ((select auth.uid()) = user_id);
-- insert / update / delete likewise
```

**`anon` gets no grant by default.** The scaffold requires authentication everywhere, so it has not one anon grant — **that is the scaffold's shape, not this track's ceiling**. Genuinely public data — landing-page content, a public leaderboard, a share link — uses the same grant plus RLS policies, with the policy written as `using (true)` or filtering on a visibility column, **and a comment in the migration stating exactly which rows an anonymous caller can read**.

What is not allowed is a different thing: **using "it is public anyway" as a reason to skip RLS.** A public table still enables RLS with explicit policies — granting to `anon` without RLS hands over the whole table, including every column added to it later.

## 3. The migration workflow

```bash
supabase migration new <name>   # write the migration
pnpm db:reset                   # verify it replays cleanly
pnpm db:types                   # regenerate the types
pnpm typecheck                  # confirm the types are still green
```

All four steps are required. **A schema change updates the migration and regenerates `database.types.ts` together.**

## 4. Generated files are not hand-edited

`src/lib/supabase/database.types.ts` is produced by `pnpm db:types`. A hand edit is overwritten at the next generation, and in the meantime the types no longer match the real schema.

## 5. The local stack's project-name trap

The first thing a new project runs is `pnpm init:project <project-name>`. It clears every leftover template name in one pass: Supabase's `project_id`, `package.json`'s name, the auth cookie name, the image prefix and LABEL, and `MASTER.md`'s title.

**`project_id` determines the local Supabase container and volume names.** Skip it and every project generated from this template shares one local stack — **project A's `db:reset` silently drops project B's tables**. This one has been walked into for real.

---

## Pre-Development Checklist

- [ ] Is the SQL only in `supabase/migrations/`, with none in application code?
- [ ] Does the table-creating migration contain **all three parts** (grant, enable RLS, policies)?
- [ ] Is the RLS policy `(select auth.uid()) = user_id`? Does the insert carry `user_id` explicitly?
- [ ] Should this table be publicly readable? **`anon` gets no grant by default** — to go public, grant explicitly in the migration, write the policies, and add a comment saying which rows an anonymous caller can read. **RLS still gets enabled.**
- [ ] Has the new project run `pnpm init:project <project-name>`? (Skipping it shares the local stack, so `db:reset` drops the other project's tables.)

## Quality Check

```bash
pnpm db:reset      # the migrations replay cleanly
pnpm db:types      # regenerate the types
pnpm typecheck     # the types are still green
```

Then check by hand:

- [ ] `database.types.ts` is generated, and **was not hand-edited** this time
- [ ] RLS was verified with a second account to be genuinely isolating (a written policy is not a working one)

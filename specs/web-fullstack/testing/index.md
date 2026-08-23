---
name: testing
description: The required checks, what to add per kind of change, how to verify behaviour and data, and the local backend, container and release commands
paths:
  - e2e/**
  - "**/*.test.ts"
---

# Quality Gates and Verification · Web Fullstack

> Everything is green before you say it is done. The track overview is in [`../README.md`](../README.md).

## Required checks (every time)

```bash
pnpm typecheck   # tsc --noEmit
pnpm lint        # eslint
pnpm test        # vitest run (unit and logic)
pnpm build       # next build (type-checks again, and produces the artifact)
```

## Add these, by kind of change

| What you touched | Also run |
|---|---|
| Styling or formatting | `pnpm format` (Prettier, including Tailwind class ordering) |
| A page or flow | `pnpm test:e2e` (Playwright; run `pnpm db:start` first) |
| The DB schema | `supabase migration new` → `pnpm db:reset` → `pnpm db:types` |

**After `pnpm format`, check yourself**: documentation (`*.md`), `.venv`, `design-system/` and generated files are already excluded in `.prettierignore`. Run `git status` afterwards — **if files appear that this task never edited**, find out why first, and either revert them or split them into a separate formatting change.

**After running `pnpm build`, delete `.next` before starting `pnpm dev`.** Mixing a production artifact with the dev cache raises errors.

## What tests which

- **Vitest**: units and logic, in `*.test.ts`, beside the code under test.
- **Playwright**: end to end, in `e2e/*.spec.ts`, **including RLS isolation**.

## How to verify (behaviour and data)

1. `pnpm dev` → `localhost:3000`: sign up → sign in → create, edit and delete in one business module → sign out
2. **Data isolation**: switch to a second account and confirm it can neither see nor modify the first account's data (RLS is working)
3. **Cross-tenant access through a sub-service (only when there is one)**: create a job as account A, then use **that job** to reach account B's resource key — **it must be refused**. See [`../backend/index.md`](../backend/index.md) §6.1
4. Required checks all green, and `supabase db reset` replays every migration cleanly
5. After a schema change: confirm the migration and `database.types.ts` are both updated, and that typecheck is still green

Items 2 and 3 are the two most often skipped and the most expensive to skip. **Written is not working** — RLS gets tried with a second account, and an ownership check gets tried with another tenant's key.

Both are **negative tests**: they prove that what should be refused is refused, which a fully green set of positive cases cannot show. So they have to exist separately, and cannot be picked up incidentally by "the feature works".

## The local backend

```bash
pnpm db:start        # Docker or OrbStack must be running
supabase status      # check status and keys
```

## Containers and releases

```bash
docker compose up -d --build                          # personal or cloud
docker compose -f docker-compose.yml \
  -f docker-compose.selfhost.yml up -d --build        # self-hosted on an internal network
```

Releases go through a `vX.Y.Z` or `vX.Y.Z-rc.N` tag:

1. Update the version in `package.json` first, including `services/*/pyproject.toml` where those exist
2. `pnpm release:validate <tag>`
3. Pushing the tag triggers the release quality gates in `.github/workflows/release.yml`

The image's environment conventions are in `.env.example`: `NEXT_DEPLOYMENT_ID` changes on every release, while `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` must stay stable across rebuilds.

---

## Pre-Development Checklist

- [ ] Which kind of test does this change need? Logic → Vitest; a page or flow → Playwright
- [ ] Is this a bug fix? **Write a failing test first**, then fix it
- [ ] Does this involve multi-user data? E2E must cover RLS isolation
- [ ] Did you touch a heterogeneous sub-service? Add a **two-tenant negative test** (A's job cannot reach B's resource)

## Quality Check

See "Required checks" on this page. All four must be green before you say it is done, plus whatever the kind of change adds.

---
name: frontend
description: The SPA's data layer and stack rules — the provider as the only path to the backend, generated types, CSRF bootstrap, cache across tabs, reuse order, theme tokens and deep links
paths:
  - frontend/src/**
---

# Frontend Rules · Java Stack

> One way to do each thing. The track overview and the prohibitions are in [`../README.md`](../README.md); the other half of the API contract is in [`../backend/index.md`](../backend/index.md).
>
> **UI/UX decision rules are not on this page.** Page skeletons, button hierarchy, filters, tables and empty states are in [`ui-structure.md`](ui-structure.md); forms, validation, overlays, feedback, loading and destructive actions are in [`ui-interaction.md`](ui-interaction.md). This page covers the data layer and the stack.

## Quick reference

| Topic | Rule |
|---|---|
| Calling the backend | **Only through `dataProvider` / `authProvider`** — no bare `fetch` in a component, no `useQuery` aimed at an endpoint |
| Data types | Derived from `src/lib/api/schema.d.ts` — **never hand-written, never hand-edited** |
| Read / write | ra-core's `useGetList` / `useGetOne` / `useCreate` / `useUpdate` / `useDelete` |
| Adding a UI component | `pnpm dlx shadcn@latest add <name>` — **never hand-edit `components/ui/*`** |
| Where component APIs come from | shadcn skill / MCP first; without it, the official component pages and the admin kit docs. **Never from memory** |
| Reuse order | `components/admin/*` → `components/ui/*` → `{data,forms,app}/*` → build new only when none fit |
| Forms | shadcn-admin-kit's `<SimpleForm>` with `<TextInput>` and friends; React Hook Form underneath |
| Colours and type sizes | Only in `@theme` in `src/styles/globals.css`; nothing new outside the tokens |
| List keys | A stable id — **never the array index** |
| Memoization | No `useMemo` / `useCallback` / `memo` by default; add one when a profile proves a cost |
| UI/UX decisions | [`ui-structure.md`](ui-structure.md) (structure) and [`ui-interaction.md`](ui-interaction.md) (behaviour) — everything the approved hi-fi did not draw follows them |

## 1. All backend calls go through the provider

**MUST route every backend call through ra-core's `dataProvider`, and every authentication call through `authProvider`.**

- *Applies:* every component, hook and utility under `frontend/src`.
- *Default:* ra-core's hooks, which all end at the provider.
- *✗* a bare `fetch` inside a component, or a `useQuery` pointed straight at an endpoint. Every bypass has to remember CSRF and the error shape on its own, and the one that forgets does not fail at the time you write it.

Two things live in the provider and must not be reimplemented at a call site:

1. **CSRF.** Unsafe methods carry `X-XSRF-TOKEN` automatically, read from the `XSRF-TOKEN` cookie. Miss it and the answer is 403 — and a 403 looks like a permission problem, which sends people off to audit authorization.
2. **Error normalization.** The backend answers RFC 9457 `problem+json`; the provider turns that into the error shape ra-core recognizes, so a page renders exactly one thing.

**The single place has to be the provider itself.** Every ra-core hook ends up there, so putting this logic anywhere else misses half the call sites.

**MUST declare each backend resource exactly once, as one `<Resource>`.**

- *Applies:* `app.tsx`, where routing and data are bound together.
- *Default:* one backend resource, one `<Resource name list edit create>`.
- *✗* declaring the same resource in two places.

### 1.1 CSRF cold start: a form reachable while signed out must wait for the bootstrap

Login and signup are **the only two screens that can be submitted before an `XSRF-TOKEN` cookie exists**. Every other page sits behind a route guard, by which time `/auth/me` has long since returned.

A password manager filling both fields instantly, or someone fast enough to hit Enter, sends **a POST with no CSRF header** and gets a 403 — and on a login page a 403 looks like "wrong password".

**The second door is sign-out.** Signing out **deletes the XSRF-TOKEN cookie** — Spring clears the CSRF token along with the session — so between sign-out and the next `/auth/me` the app holds no usable token. "Sign out, then immediately sign in as someone else", the most common way to switch accounts, therefore gets a 403.

**MUST issue `/auth/me` before rendering the login or signup form, and disable the inputs and the submit while it is pending.**

- *Applies:* login and signup.
- *Default:* that request is itself what re-issues `XSRF-TOKEN`. Tens of milliseconds of disabled input buys off a whole class of unreadable 403s.
- *✗* retrying once automatically on a 403. That papers over a race with a retry, and swallows genuine CSRF failures along with it.

**MUST make sign-out local-first: tear the local session down whatever the server answers.**

- *Applies:* sign-out.
- *Default:* clear the cache, reset the store and redirect, without waiting on the response.
- *Why:* a failed request is not evidence that the session survived, and letting it reject means clearing the cache, resetting the store and redirecting **all three fail to run** — ra-core's sign-out only attaches `.then`, callers do not catch, so one network hiccup leaves the user on a screen that still looks signed in.
- *Residual limit, recorded honestly:* when the request never reaches the server at all, the httpOnly session cookie lives until it expires, and no client-side sign-out can overrule that.

**Acceptance — this is run evidence and does not change with the implementation:** sign out, immediately sign back in with the same account, and assert you reach the app, rather than sitting on the login page holding a 403 nobody can interpret.

### 1.2 Classify failures; never render them all as "not found"

Rendering every failed request as "X does not exist" is **a false claim about content**. A 401 (session expired), a 500 and a dropped connection all get reported as "your data is gone", so the user goes looking for the data instead of signing back in or reporting an outage.

**MUST classify failures in `dataProvider`, in one place, into at least three kinds.**

| Test | Meaning | UI |
|---|---|---|
| 404 | Genuinely absent, or not this account's | "Does not exist" plus a way back to the list |
| 401 | Session expired | "Please sign in again" plus a route to the login page |
| Everything else — 5xx, network, parse failure | Temporarily unavailable | "Cannot open right now" plus **Retry** |

**MUST route 401 through `authProvider.checkError()`. NEVER redirect from inside `dataProvider`.**

- *Applies:* every 401.
- *Default:* ra-core runs its own sign-out flow when `checkError` rejects.
- *✗* redirecting from both places, which makes the two fight.

## 2. Types come from the backend, not from your hands

```ts
import type { components } from "./schema";
export type Note = Required<components["schemas"]["NoteResponse"]>;
```

**MUST derive every API type from `src/lib/api/schema.d.ts`. NEVER hand-edit that file.**

- *Applies:* every type that crosses the API boundary.
- *Default:* `pnpm api:types` generates it from the backend's `/v3/api-docs`.
- *Why:* when the backend renames a DTO field and the frontend has not followed, **typecheck fails outright** — which is exactly the effect you want. A parallel hand-written interface switches that protection off, and the rename becomes a runtime `undefined` instead.
- *✗* hand-editing `schema.d.ts` until it compiles. Regenerate, run `pnpm typecheck`, fix what it reports.

**`Required<>` is deliberate.** springdoc marks a property `required` only when it carries a Bean Validation annotation, and response DTOs usually carry none — so the generated types come out entirely optional. These columns are `NOT NULL` in the database; the API really does always send them.

**MUST map the primary key onto `id` inside `dataProvider` when the backend calls it something else.**

- *Applies:* every resource whose backend primary key is not named `id`. ra-core requires an `id` field on every record.
- *Default:* the mapping lives in `dataProvider`.
- *✗* mapping inside components — once it is spread out, "which field is this resource's id" has no single answer.

## 3. Reading, writing and the cache

- **Read** with `useGetList` / `useGetOne`. The resource name is a string constant, never assembled at the call site.
- **Write** with `useCreate` / `useUpdate` / `useDelete`. ra-core handles invalidation itself — **never call `invalidateQueries` by hand**, because two invalidation schemes overwrite each other.
- **401 is not an error, it is "not signed in".** Translate it into "go to the login page" instead of letting it surface as a red error page.
- `retry: false` by default. 401 and 404 are answers, not jitter; retrying only makes the screen arrive later.

**TanStack Query sits underneath ra-core; never call an endpoint with it directly.** It is still the cache implementation, so debugging a cache problem means looking at it — but application code touching it means the provider has been bypassed.

### 3.1 Switching accounts: clear the cache, and tell the other tabs

**MUST clear the query cache on a successful sign-in or sign-up, rather than merely invalidating it.**

- *Applies:* sign-in and sign-up — both establish a session.
- *Default:* clear.
- *Why:* invalidation leaves the previous account's data in the cache, so the **first frame** after signing in as someone else renders the predecessor's data until the refetch lands. Signing in is precisely the moment when not one row of that data may be used again.

**MUST clear on sign-out as well, and NEVER write a "signed out" value into the cache.**

- *Applies:* sign-out.
- *Default:* clear, and write nothing in its place.
- *Why:* this reads like the mirror of the rule above and is in fact its opposite, which is why it is written out separately. At sign-in you hold a freshly fetched user object and a freshly established session. After sign-out there is nothing to write, and writing an empty value makes the "current user" query read as *confirmed signed out* **without a single request having been sent** — which switches off the CSRF bootstrap guard in §1.1, **and sign-out has just deleted the XSRF-TOKEN cookie**.

**The harder half: the query cache lives in one tab.**

Sign out in tab A and you clear tab A's cache. Tab B is parked on a list, and **nothing is going to correct it** — `refetchOnWindowFocus` is off, which is right in itself: a round of requests on every focus change, for a screen that has not changed, does not pay. So B keeps rendering rows fetched under a session that no longer exists. Sign in with another account in the same browser and B becomes **one person's name beside another person's data**, with no request coming to fix it.

**MUST broadcast every session change — sign-in, sign-up and sign-out — on a single `BroadcastChannel` instance, and MUST have receiving tabs reload the whole page.**

- *Applies:* every session change.
- *Default:* one channel instance for both sending and receiving; the receiving tab does a full page reload.
- *Why a reload:* it is the most honest response available here. It drops all in-memory state at once, so nothing has to permanently remember which caches the app still holds — and in the account-switch case it also connects that tab to the **new** session.

Three specific traps, **none of them specific to the frontend framework**:

- **Send and receive on the same channel object.** `BroadcastChannel` excludes **the channel object that sent the message**, not the tab it lives in. Send through a throwaway `new BroadcastChannel(...)` and your own listener still fires, so the tab that just signed in or out reloads itself. **It still "works", which is exactly why this one is so easy to miss.**
- **Subscribe before the first render.** Another tab may sign in or out while this page is still loading, and this reload has to be independent of which route you landed on.
- **Older browsers have no `BroadcastChannel`** — Safari before 2022. Check that it exists before using it.

**The receiving end cannot reload and stop there.** After reloading, that tab runs its own sign-out flow, broadcasts again, and bounces the original sender into a reload of its own.

**MUST write the reload-suppression flag to `sessionStorage`, and MUST consume it on the next page load rather than inside sign-out.**

- *Applies:* every tab that reloads because it received a session broadcast.
- *Default:* the flag is written before the reload, consumed once on the next page load, and cleared by any session change the tab itself initiates — sign-in, sign-up or local sign-out. The sign-out carrying the flag clears the cache and does not broadcast.
- *Why the lifetime is one page load:* the flag describes "this one page load", so one page load is what its lifetime must be. Consume it inside sign-out instead and you miss every route that never calls sign-out — login and signup both sit outside the route guard — and the leftover flag then makes that tab **silently skip broadcasting one real sign-out**, while the other tabs go on rendering an account that has signed out. This is the most expensive detail in this section.

**The server is unaffected by any of this**: requests from a stale tab still get 401. This section is about not continuing to display the previous session's data.

**Acceptance — run evidence, and it does not change with the implementation:** one browser context, **two** pages sharing cookies and session but with independent JS. Sign out in one; assert the other goes to the login page by itself and no longer shows that data; then assert **the initiating page did not reload**, by setting a marker on its `window` that a reload would wipe.

### 3.2 List parameters: the provider must clamp them

ra-core **persists list parameters into localStorage** and restores them whenever the URL carries none. So an out-of-range sort field or page number **is not a one-off**: it comes back every time that list is opened, pinning the user behind a Retry that can only keep failing, with no way out but hand-editing the URL or signing out. One stale bookmark, or a link someone shared, is enough to produce that state.

**MUST clamp sort field, direction, page and page size inside `dataProvider` before the request goes out.**

- *Applies:* every list request.
- *Default:* clamp against **the same** allow-list the backend uses, then clamp the page number again against Java's int upper bound.
- *Why the second clamp:* an out-of-range page number fails conversion **before** the backend's `@Min` is ever consulted, and what comes back then is not a readable validation error.

**MUST change both copies of the allow-list in the same commit.**

- *Applies:* the sort allow-list and the parameter bounds, which exist once on each side of the API.
- *Default:* a comment on each side pointing at the other and at the paired test.
- *Why:* the type layer cannot carry this constraint — `schema.d.ts` widens these parameters back to `string` and `number`. The backend half is in [`../backend/index.md`](../backend/index.md) §10.

## 4. Server / Client boundary (this track has none)

This is a plain SPA: **no** Server Components, **no** Server Actions, **no** `"use client"`. When you carry code over from the Next.js track, delete those directives. Vite does not complain about them, they simply do nothing, and leaving them in suggests a boundary that does not exist.

Correspondingly there is **no `useFormStatus`**. Take the pending state from ra-core's mutation hook and pass it to the button explicitly.

## 5. Hooks

- Follow the Rules of Hooks, and treat a `react-hooks/exhaustive-deps` warning **as a failure** — eslint is already configured to error on it.
- `useEffect` is for synchronizing with an external system: subscriptions, timers, browser APIs. **Not** for derived values, and **not** for mirroring props or query results into state.
  - When a form needs to be initialized from loaded data, **split the form into a child component** initialized with `useState(props.x)`, and have the parent render it only once the data has arrived. Using an effect to `setState` causes cascading renders, and `eslint-plugin-react-hooks` errors on it outright.
  - ra-core's `<Edit>` already handles waiting for the data before rendering the form. Go through it and you do not need to split anything yourself.
- Always clean up a subscription, timer or request you create.
- No `useMemo` / `useCallback` / `memo` by default; add one when a profile proves a cost.

## 6. Reuse order

New UI looks in this order:

1. **`components/admin/*`** — shadcn-admin-kit's **frozen source snapshot**: `<List>` `<DataTable>` `<Edit>` `<Create>` `<SimpleForm>` `<TextInput>` `<SelectInput>` and the rest. **The whole point of installing it is not to assemble CRUD screens by hand: read the directory first, then its docs.**
2. **`components/ui/*`** — shadcn primitives: `Button` `Card` `Input` `Select` `Dialog` `Tooltip` `Skeleton` `Badge` and so on. Added with `pnpm dlx shadcn@latest add <name>`, **never hand-edited**.
3. **`components/{data,forms,app}/*`** — the pattern layer, for what the two layers above do not have. **Resource CRUD screens barely touch it**, because the kit already covers that whole surface; dashboards, wizards and reports are what make it grow.
4. Build something new only when none of the above fit.

**NEVER reimplement a component that already exists.** When the pattern layer does start to grow, and which kit defaults must be explicitly switched off, are in [`ui-structure.md`](ui-structure.md) §6.

**Lay out with Tailwind utility classes.** One-off spacing goes straight in the class name; no new CSS file.

**`components/ui/*` is the shadcn CLI's output, and editing it means you can no longer follow upstream.** To change behaviour, wrap it in `components/{data,forms,app}/` — the same reasoning that makes vendored code read-only.

**`components/admin/*` is a frozen snapshot of upstream source, not a dependency.** shadcn-admin-kit's install model copies source out of a registry: it sits outside npm version management, and the moment it lands in the repo you own a fork. Three things follow.

- **Never hand-edit it.** Wrap it in the pattern layer to change behaviour.
- **Record every genuinely necessary local modification, one at a time** — which file, why, and what breaks without it — in `THIRD_PARTY_NOTICES.md`. On the day you move the pin, that record is the **only** basis for deciding which way to resolve a conflict; without it you are guessing which parts of a dozens-of-files diff are yours. **A modification with no runtime benefit — one that only touches JSDoc, say — is reverted to the pin**, because all it can do is add conflicts to the next upgrade.
- **Diff against the source at the pinned commit.** The registry address recorded in `components.json` serves **latest**, so diffing against that reports upstream's later changes as your local modifications.

**The authority on how a component is written is upstream, not your memory.** Before deciding which component to `add`, or how to compose `components/ui/*` with `components/admin/*`:

- If `shadcn` is registered in the project's root `.mcp.json`, or a shadcn skill is installed under the project's `.claude/skills/`, **consult it before writing**. It can read `components.json`, so it knows this project's kernel, its aliases and what is already installed.
- With neither of those, or when `frontend/` has no `components.json` at all, **read <https://ui.shadcn.com/docs/components> and the shadcn-admin-kit docs before writing**, and mention once that this project is not wired up. Once is enough — not every round.

> **⚠️ Not yet verified by a real run.** The admin kit's registry is registered in `components.json`, but **whether MCP can actually find its components has never been tried**. When it cannot, `components/admin/*` is governed by the admin kit's own docs and by the source in this repo's snapshot. Note that the address serves latest, so **it cannot be the diff baseline for the snapshot** — see above.

**NEVER copy component APIs into this spec.** They follow upstream versions, so a copy is guaranteed to go stale, and the stale copy will outrank upstream.

**Division of labour with `ui-ux-pro-max`:** visual design, typography, colour and the design system are its job; component selection, composition and props belong to the shadcn skill / MCP. Its bundled shadcn data is a static snapshot and **is not an authority on component APIs**.

## 7. Forms

- Use shadcn-admin-kit's `<SimpleForm>` with `<TextInput>` / `<SelectInput>` and friends; React Hook Form is underneath. **NEVER nest your own RHF instance inside an admin kit form** — two form contexts fight each other.
- Server errors arrive in `problem+json`'s `detail`, are normalized by `dataProvider`, and are handed to the form for inline display.
- Layout, required markers, where the submit action sits, how far the pending state disables, when validation runs and how field errors are announced are all in [`ui-interaction.md`](ui-interaction.md) §1–§2.

## 8. Theme and visuals

- Read `design-system/MASTER.md` before changing how the UI looks: colour, type size, how state is shown, badges and icons.
- **The single source for visuals is `src/styles/globals.css`.** Values are defined in `:root` and its dark variant, then mapped to Tailwind tokens by `@theme inline` — the standard shadcn structure under Tailwind v4. **Never write values straight into `@theme`.** Outside the tokens, invent no colour, no shadow and no arbitrary type size.
- **When you delete a layer of components, delete the design tokens only it used**, and check the comments and `design-system/MASTER.md` for references to them. A factual claim like "this token is still in use" has **no machine checking it**, so leaving it behind leaves a falsehood the next person will believe.
- Badges, links and filter controls are covered by [`ui-structure.md`](ui-structure.md) §2–§3 and [`ui-interaction.md`](ui-interaction.md) §4. This page only says where the tokens come from.
- **Fonts are vendored.** No Google Fonts and no CDN font of any kind — an internal or offline build fails outright.
- **NEVER put a secret in a `VITE_*` variable.** Vite inlines `VITE_`-prefixed values into the browser bundle. This track's frontend needs no secret at all: same origin plus httpOnly cookies.

## 9. Routing and deep links

React Router in declarative mode, with ra-core's `<Resource>` on top of it. **Every route must survive a cold load** — paste the address, reload — because the backend serves an SPA fallback.

Cover a cold load in E2E whenever you add a route. This failure **can never be reproduced under `pnpm dev`**, because Vite ships its own history fallback; it exists only in the packaged artifact. See [`../testing/index.md`](../testing/index.md).

A client-side route guard decides **what to render**. It is not authorization — authorization is the backend's job.

## 10. Relationship to the task's prd.md

- **Fields and rules are the source of truth for implementation and acceptance.** The field table and rule descriptions in `prd.md` must be covered by the implementation and the tests. No field is silently dropped, and none of a field's business meaning, type or control, requiredness, default, editability, enumeration, length or range, or rule constraints are changed.
- **Page structure follows this slice's approved hi-fi screens.** Their paths come from the fourth column of the slice list in `docs/discovery/slices.md`, and they **must go into `implement.jsonl`** — an implementation sub-agent in a fresh context sees only the files that jsonl lists.
- **Behavioural boundaries stay under the rules.** When a change of shape affects behaviour — going back or cancelling, unsaved state, deep-link access, closing restrictions — `prd.md`'s rule descriptions govern. When the rules do not cover it and product behaviour would change, go back and settle the requirement first.
- **The full precedence between the approved hi-fi, `MASTER.md`, shadcn MCP and the UI/UX rules is in [`ui-structure.md`](ui-structure.md) §0.** Where the approved hi-fi depicts something it governs; where it is silent, the rules fill in.

---

## Pre-Development Checklist

Work through this before writing frontend code.

- [ ] Does this touch the backend? Does it go through `dataProvider` / `authProvider`? Any bare `fetch`, or a `useQuery` that bypasses the provider?
- [ ] Is this a form reachable while signed out? Is submit disabled until the CSRF bootstrap returns (§1.1)?
- [ ] Do the error branches separate 401, 5xx and network failure from a genuine 404? Does 401 go through `checkError` (§1.2)?
- [ ] Are the data types derived from `schema.d.ts`? If the backend API changed, has `pnpm api:types` been re-run?
- [ ] Does `components/admin/*` already have what you need? Does `components/ui/*`? (Reuse order in §6.)
- [ ] **Are this slice's approved hi-fi screens in `implement.jsonl`?** (Fourth column of `slices.md`; missing them has no symptom.)
- [ ] Does this screen have states the approved hi-fi did not draw — loading, empty, failure, pending? Fill them in from [`ui-structure.md`](ui-structure.md) and [`ui-interaction.md`](ui-interaction.md), not from improvisation.
- [ ] Have list actions, pagination bounds, Select option counts and how filters apply been checked against [`ui-structure.md`](ui-structure.md) §3–§4?
- [ ] Is there a destructive action? Confirmation dialog, destructive variant, copy that names the target, and the overlay stays open on failure ([`ui-interaction.md`](ui-interaction.md) §6).
- [ ] Is a `useEffect` mirroring a query result into state? Replace it with a child component initialized by `useState`, or use `<Edit>`.
- [ ] Did you touch the sign-in, sign-up or sign-out flow? Cache cleared, no empty value written on sign-out, and all three broadcast to the other tabs (§3.1)?
- [ ] Did you touch sign-out? Does "sign out and immediately sign back in" still reach the app, rather than a 403 (§1.1, the second door)?
- [ ] Did you edit `components/ui/*` or `components/admin/*`? **Not allowed** — a modification the snapshot needs in order to compile is recorded in `THIRD_PARTY_NOTICES.md`, one entry at a time.
- [ ] Did you touch list parameters? Is the provider's clamp the same list as the backend's allow-list, and are both changed in **the same commit** (§3.2)?
- [ ] In code carried over from the Next.js track, are `"use client"`, server actions and `useFormStatus` all gone?
- [ ] Adding a colour, shadow or type size? **Not allowed** — read `design-system/MASTER.md`, then change `@theme` in `globals.css`.
- [ ] Added a route? Add a **cold load** case to E2E; it is always green under dev.
- [ ] What is this screen's primary action? Not being able to say means the information architecture is not settled.

## Quality Check

```bash
pnpm -C frontend typecheck && pnpm -C frontend lint && pnpm -C frontend test && pnpm -C frontend build
```

Add `pnpm -C frontend format` after style or formatting changes, and E2E after page or flow changes — E2E requires `./gradlew :backend:bootJar` first, because it runs against the packaged artifact. The full set of required checks is in [`../testing/index.md`](../testing/index.md).

Then check by hand:

- [ ] List keys are a stable id, not the array index
- [ ] Action columns and pagination render only capabilities that can actually be used; pending feedback stays visible (`ui-structure.md` §4)
- [ ] A Select with eight or more options is searchable by label; filters write to the URL only on submit; Reset clears only its own keys (`ui-structure.md` §3)
- [ ] Interactive controls are semantic HTML, keyboard reachable, with a visible focus ring (`ui-structure.md` §7)
- [ ] `react-hooks/*` reports nothing — both deps and set-state-in-effect are configured to error
- [ ] Dialogs and Sheets holding unsubmitted state have overlay-click closing disabled (`ui-interaction.md` §3)
- [ ] No failure is reported by toast alone; an overlay does not close on failure (`ui-interaction.md` §4)
- [ ] Refresh, paging and filtering keep the previous data instead of flashing back to a skeleton (`ui-interaction.md` §5)
- [ ] `components/ui/*` has not been hand-edited
- [ ] No secret appears in any `VITE_*` variable

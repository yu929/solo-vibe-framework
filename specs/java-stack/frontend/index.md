---
name: frontend
description: The one way to do each frontend thing, what decides what when sources disagree, the rules that fail silently, and where the full text of each lives
paths:
  - frontend/src/**
---

# Frontend Rules · Java Stack

> What you get on every frontend edit: the one way to do each thing, which source wins when two disagree, and the two checklists. **The reasoning, the patterns and the traps are in the three sibling files** — open the one your change touches.
>
> Section numbers restart in each file, so every reference below names the file it means.

## Quick reference

| Topic | Rule |
|---|---|
| Calling the backend | **Only through `dataProvider` / `authProvider`** — no bare `fetch` in a component, no `useQuery` aimed at an endpoint (`data-layer.md` §1) |
| Data types | Derived from `src/lib/api/schema.d.ts` — **never hand-written, never hand-edited** |
| Read / write | ra-core's `useGetList` / `useGetOne` / `useCreate` / `useUpdate` / `useDelete` |
| Adding a UI component | `pnpm dlx shadcn@latest add <name>` — **never hand-edit `components/ui/*`** |
| Where component APIs come from | shadcn skill / MCP first; failing that, the official component pages and the admin kit docs. **Never from memory** |
| Reuse order | `components/admin/*` → `components/ui/*` → `{data,forms,app}/*` → build new only when none fit (`data-layer.md` §6) |
| Forms | shadcn-admin-kit's `<SimpleForm>` with `<TextInput>` and friends; React Hook Form underneath, submit-time validation (`ui-interaction.md` §1–§2) |
| Colours and type sizes | Only in `@theme` in `src/styles/globals.css`; nothing new outside the tokens |
| List keys | A stable id — **never the array index** |
| Memoization | No `useMemo` / `useCallback` / `memo` by default; add one when a profile proves a cost |

## What decides what

Four things govern this UI; only one produces *rules*.

| Source | Produces | Owns |
|---|---|---|
| Approved hi-fi screens | An instance: this screen looks like this | Every structural choice it actually depicts |
| `design-system/MASTER.md` | Tokens: colour roles, type scale, spacing, density | All visual values, plus this project's recorded deviations |
| shadcn skill / MCP | Parts: which component exists, what props it takes | Component API and composition |
| `ui-structure.md` + `ui-interaction.md` | Rules: which pattern applies when | Cross-screen consistency, and every state no mockup drew |

**Follow the hi-fi where it depicts something; apply the rules everywhere it is silent** — which is most of the time, since a mockup shows one state of one screen. **Apply every NEVER rule even when a mockup contradicts it.** A project overrides a default by writing the deviation and its reason into `design-system/MASTER.md`; an unwritten one is not an override.

## Which of those are green when you get them wrong

None of these produces an error, a failing test, or any visible defect on a developer machine.

- **A form reachable while signed out submitting before the CSRF bootstrap returns** — it works once the page has been open a moment, and fails only on the fast path (`data-layer.md` §1.1).
- **Sign out, then straight back in** — the second door: a stale token answers 403 where you expected the app (`data-layer.md` §1.1).
- **A 401, a 5xx or a network failure rendered as "not found"** — the screen looks reasonable and sends everyone in the wrong direction (`data-layer.md` §1.2).
- **This slice's approved hi-fi screens missing from `implement.jsonl`** — a sub-agent in a fresh context builds something else, and the diff reads like carelessness.
- **The provider's clamp and the backend's sort allow-list drifting apart** — the generated types widen both back to `string`, so nothing catches it (`data-layer.md` §3.2).
- **A route with no cold-load E2E case** — the Vite dev server has its own history fallback, so deep links are always green in dev.
- **Reading these rules after the first write** — injection fires PostToolUse on Claude Code, so it can arrive too late. Open the file your change touches first.

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`data-layer.md`](data-layer.md) | The provider as the only path to the backend, generated types, the cache across tabs, reuse order, hooks, theme tokens, routing and deep links | You call the backend, add a component, or touch auth, cache or tokens |
| [`ui-structure.md`](ui-structure.md) | Page skeletons, button hierarchy, search and filters, tables, empty states, what the admin kit switches on by default, accessibility invariants | You build a screen, a list, or anything the hi-fi did not draw |
| [`ui-interaction.md`](ui-interaction.md) | Forms and validation, dialog vs drawer vs route, feedback, loading, destructive actions, where a mutation leaves the user | You build a form, an overlay, or any loading or failure state |

## Pre-Development Checklist

- [ ] Does this touch the backend? Does it go through `dataProvider` / `authProvider`? Any bare `fetch`, or a `useQuery` that bypasses the provider?
- [ ] Is this a form reachable while signed out? Is submit disabled until the CSRF bootstrap returns (`data-layer.md` §1.1)?
- [ ] Do the error branches separate 401, 5xx and network failure from a genuine 404? Does 401 go through `checkError` (`data-layer.md` §1.2)?
- [ ] Are the data types derived from `schema.d.ts`? If the backend API changed, has `pnpm api:types` been re-run?
- [ ] Does `components/admin/*` already have what you need? Does `components/ui/*`? (Reuse order in `data-layer.md` §6.)
- [ ] **Are this slice's approved hi-fi screens in `implement.jsonl`?** (Fourth column of `slices.md`; missing them has no symptom.)
- [ ] Does this screen have states the approved hi-fi did not draw — loading, empty, failure, pending? Fill them in from `ui-structure.md` and `ui-interaction.md`, not from improvisation.
- [ ] Have list actions, pagination bounds, Select option counts and how filters apply been checked against `ui-structure.md` §3–§4?
- [ ] Is there a destructive action? Confirmation dialog, destructive variant, copy that names the target, and the overlay stays open on failure (`ui-interaction.md` §6).
- [ ] Is a `useEffect` mirroring a query result into state? Replace it with a child component initialized by `useState`, or use `<Edit>`.
- [ ] Did you touch the sign-in, sign-up or sign-out flow? Cache cleared, no empty value written on sign-out, and all three broadcast to the other tabs (`data-layer.md` §3.1)?
- [ ] Did you touch sign-out? Does "sign out and immediately sign back in" still reach the app, rather than a 403 (`data-layer.md` §1.1, the second door)?
- [ ] Did you edit `components/ui/*` or `components/admin/*`? **Not allowed** — a modification the snapshot needs in order to compile is recorded in `THIRD_PARTY_NOTICES.md`, one entry at a time.
- [ ] Did you touch list parameters? Is the provider's clamp the same list as the backend's allow-list, and are both changed in **the same commit** (`data-layer.md` §3.2)?
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

---
name: frontend
description: Server/Client boundary, forms and overlays, hooks, theme tokens and accessibility for the Next.js App Router track
paths:
  - src/components/**
  - src/app/**/*.tsx
  - src/app/**/*.css
---

# Frontend Rules · Web Fullstack

> One way to do each thing. The track overview and the Never list are in [`../README.md`](../README.md).
>
> Section numbers are shared with the sibling file listed below, so a section reference means the same thing wherever it is cited.

## Quick reference

| Topic | Rule |
|---|---|
| A new component defaults to | A Server Component; `"use client"` only for state, effects, refs, browser APIs or event handlers |
| Adding a UI component | `pnpm dlx shadcn@latest add <name>`; never hand-edit `src/components/ui/*` |
| Where component APIs come from | shadcn skill / MCP first; without it, the official component pages. **Never from memory** — this track runs the Base UI kernel, not Radix (`components.md` §2) |
| Reuse order | `ui/*` → `{data,forms,app}/*` → build new only when neither fits (`components.md` §2) |
| Forms | `useActionState` with a server action, and `<form noValidate>` |
| List keys | A stable id — **never the array index** |
| Memoization | No `useMemo` / `useCallback` / `memo` by default; add one when a profile proves a cost |

## 1. The Server / Client boundary

A new component is **a Server Component by default**. Add `"use client"` — on the first line — only for state, effects, refs, browser APIs or event handlers. Only serializable values cross from server to client.

**Never** import a DB client, a secret or a server-only module into a client component.

**The reverse direction is equally dangerous**: do not export a constant or a pure function from a `"use client"` file for the server to import. It becomes a client reference and fails silently — a `.limit(N)` receives something that is not a number — and **neither typecheck nor build reports anything; only the runtime does.** Shared constants and pure functions live in `src/lib/`.

## 3. Forms

- `useActionState` with a server action.
- `<form>` carries `noValidate`, which turns off the browser's own English validation bubbles — **validation happens in the action**.
- Fields are wrapped in `FormRow` (label, required marker, inline error), and submission uses `SubmitButton`.
- A validation failure comes back as `{ error }` and renders inline; a success uses a `sonner` toast and `revalidatePath`.

> "Validation happens in the action" says **where this layer's form validation is implemented**, not "the whole system validates in one layer". Authorization is still server-side and data invariants are still backstopped by database constraints — see "validation scattered across layers" in [`../guides/cross-layer.md`](../guides/cross-layer.md).

## 4. How dialogs and drawers close

Any `Dialog` or `Sheet` holding **form input, a password or key, a textarea, a bulk selection, a pending confirmation, or any other unsubmitted state** must disable outside-click dismissal (`disablePointerDismissal` in Base UI), leaving only the explicit cancel, close and submit paths.

Purely navigational overlays, menus, popovers, tooltips and read-only previews **may** keep outside-click dismissal.

## 5. Hooks

- Follow the Rules of Hooks, and treat a `react-hooks/exhaustive-deps` warning **as a failure**.
- `useEffect` is for synchronizing with an external system: subscriptions, timers, browser APIs. **Not** for derived values, **not** for mirroring props into state, and **not** for a notification that belongs in an event handler.
- Always clean up a subscription, timer or request you create.
- No `useMemo` / `useCallback` / `memo` by default; add one when a profile proves a cost.

## 6. How React components are organized

- Function components and composition.
- State lives as close as possible, lifted only to the nearest common parent.
- Containers (fetching, side effects) are separate from presentation (rendering from props).
- List keys are a stable id, **never the array index**.

## 7. Client-side fetching

**No bare `fetch` inside a `useEffect`.** Reads go through Server Components; writes go through a server action plus `revalidatePath` — see [`../backend/index.md`](../backend/index.md).

## 8. Theme and visuals

- Read `design-system/MASTER.md` before changing how the UI looks: colour, type size, how state is shown, badges and icons.
- **Colour values have one source, `@theme` in `src/app/globals.css`.** Outside the tokens, invent no colour, no shadow and no arbitrary type size.
- A badge is only ever given to a **real state** (the vocabulary is in `src/lib/status.ts`).
- To make a `Link` look like a button, pass `buttonVariants({...})` as its className — Base UI has no `asChild`.
- **Dark mode**: `next-themes` is used only by `sonner`, to keep toasts in step with the theme; the scaffold ships no switcher. To get dark mode, add a provider and a toggle. **Do not delete `next-themes` because it looks unused** — `sonner.tsx` is a generated file and imports it, so removing it breaks the build.

## 9. Accessibility

- Prefer semantic HTML: a real `button`, a real `a`, never a clickable `div`.
- Every interactive control has an accessible name.
- Keyboard reachable, with a visible focus ring.

## 10. Relationship to the task's prd.md

- **Fields and rules are the source of truth for implementation and acceptance.** The field table and rule descriptions in `prd.md` must be covered by the implementation and the tests. No field is silently dropped, and none of a field's business meaning, type or control, requiredness, default, editability, enumeration, length or range, or rule constraints are changed.
- **Page structure is UI reference only.** As long as no field, capability or business behaviour is lost, the shape of a page, dialog or drawer, its entry point, its grouping, its field order and its layout may be adjusted. **A purely presentational difference is not a requirements mismatch.**
- **Behavioural boundaries stay under the rules.** When a change of shape affects behaviour — going back or cancelling, unsaved state, deep-link access, closing restrictions — `prd.md`'s rule descriptions govern. When the rules do not cover it and product behaviour would change, go back and settle the requirement first.

---

## Where the rest of it lives

| File | Covers | Open it when |
|---|---|---|
| [`components.md`](components.md) | §2 — the order to look in before building something new, why memory is unreliable about component APIs on this kernel, and the division of labour with `ui-ux-pro-max` | You add a UI component, or compose anything out of `components/ui/*` |

## Pre-Development Checklist

Work through this before writing frontend code.

- [ ] Is this component a **Server Component** by default? If it carries `"use client"`, can you state the reason (state, effect, ref, browser API, event handler)?
- [ ] Does `components/ui/*` or `components/{data,forms,app}/*` already have what you need? (Reuse order in `components.md` §2.)
- [ ] **Are this slice's approved hi-fi screens in `implement.jsonl`?** (Their paths are in the fourth column of the slice list in `docs/discovery/slices.md`; missing them has no symptom — an implementation sub-agent in a fresh context sees only the files that jsonl lists.)
- [ ] Adding a colour, shadow or type size? **Not allowed** — read `design-system/MASTER.md` first; the tokens live in `@theme` in `globals.css`
- [ ] Does anything export a constant or a pure function from a `"use client"` file to the server? (It fails silently, and typecheck says nothing.)
- [ ] What is this screen's primary action? Not being able to say means the information architecture is not settled.
- [ ] Writing a test, or fixing a bug? [`../testing/index.md`](../testing/index.md) says which kind to write and what to do first

## Quality Check

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

Add `pnpm format` after style or formatting changes, and `pnpm test:e2e` after page or flow changes. The full set of required checks is in [`../testing/index.md`](../testing/index.md).

Then check by hand:

- [ ] List keys are a stable id, not the array index
- [ ] Interactive controls are semantic HTML (a real `button`, a real `a`), keyboard reachable, with a visible focus ring
- [ ] `react-hooks/exhaustive-deps` reports nothing
- [ ] Dialogs and Sheets holding unsubmitted state have outside-click dismissal disabled

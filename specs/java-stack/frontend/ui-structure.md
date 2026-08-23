---
name: ui-structure
description: Page skeletons, button hierarchy, filters, tables and empty states — the layout decisions a single approved mockup cannot generalize
paths:
  - frontend/src/routes/**
  - frontend/src/components/**
---

# UI/UX Decision Rules · Structure

> The behavioural half — forms, validation, dialogs, feedback, loading, dangerous actions — is in [`ui-interaction.md`](ui-interaction.md). Stack rules (provider, generated types, hooks, theme tokens) stay in [`index.md`](index.md).

## 0. What decides what

Four things govern this UI. Only one of them produces *rules*.

| Source | Produces | Owns |
|---|---|---|
| Approved hi-fi screens | An instance: this screen looks like this | Every structural choice it actually depicts |
| `design-system/MASTER.md` | Tokens: colour roles, type scale, spacing, density | All visual values, plus this project's recorded deviations from the rules below |
| shadcn skill / MCP | Parts: which component exists, what props it takes | Component API and composition |
| This file + `ui-interaction.md` | Rules: which pattern applies in which situation | Cross-screen consistency, and every state no mockup drew |

**Follow the approved hi-fi wherever it depicts something.** It is the slice's signed-off instance, and it outranks the defaults below.

**Apply these rules everywhere it is silent.** A mockup depicts one state of one screen. It is silent about loading, empty, failure, pending and disabled, and about every screen a later slice adds. Silence is not permission to improvise.

**Apply every NEVER rule even when a mockup contradicts it.** They cover accessibility and destructive actions, which are not style preferences.

A project may override a default here by writing the deviation and its reason into `design-system/MASTER.md`. An unwritten deviation is not an override.

> **Read this file before writing UI code, not after.** Path-based injection fires PostToolUse on Claude Code, so it can arrive after the first write.

## 1. Page skeletons

Applies to any screen the approved hi-fi did not draw.

**MUST build a list screen as page header → toolbar → table → pagination bar.**

- *Applies:* every resource list.
- *Default:* that order, no extra chrome between the bands.
- *Exception:* the hi-fi drew a different arrangement for this screen.
- *✗* wrapping the table in a card that adds a second title next to the page header.

**MUST place the primary action before the filter group in DOM order.**

- *Applies:* every list screen that carries both.
- *Default:* the primary action's markup comes first. Visual placement — which band, left or right — is the hi-fi's call, not this file's.
- *Exception:* none. This rule holds even when the design puts the two in different bands.
- *✗* reordering the markup to land the primary action where the design wants it. A static mockup cannot express DOM order either way, so nothing else in the project decides this; get it wrong and keyboard and screen-reader users tab through the entire filter group to reach the screen's main action.

**MUST render a detail screen as a description list or one low-decoration card.**

- *Applies:* read-only views of a single record.
- *Default:* one container for the whole record.
- *Exception:* the record has genuinely independent sections that the PRD treats separately.
- *✗* one card per field, which turns eight facts into eight boxes.

## 2. Button hierarchy

**MUST keep exactly one primary action per page region.**

- *Applies:* page header, toolbar, form footer, dialog footer — each is a region.
- *Default:* the region's main outcome is primary; everything else is secondary or ghost.
- *Exception:* none. Two primaries in one region means the screen has no main action.
- *✗* promoting both "Save" and "Save and add another" to primary.

**MUST style a destructive action with the destructive variant, and NEVER as the region's primary.**

- *Applies:* delete, revoke, disable, reset, anything the user cannot undo.
- *Default:* destructive variant, secondary weight in the layout.
- *Exception:* none.
- *✗* making "Delete" the primary button of a dialog because it is the confirming action.

**MUST order a dialog footer as cancel then confirm, left to right.**

- *Applies:* every dialog with two or more actions.
- *Default:* cancel left, confirm right.
- *Exception:* none — a per-dialog choice here is what makes users misclick.

**MUST use a real link with an accessible name for inline navigation. NEVER wrap an anchor in a button.**

- *Applies:* jump-off points inside table rows and detail fields.
- *Default:* a bare link, wrapped in a tooltip when the label is an icon.
- *Exception:* none. A button that navigates breaks role-based selectors and link semantics.
- *✗* a button wrapping an anchor.

**MUST give an icon-only control an accessible name and a tooltip.**

- *Applies:* every control whose visible content is an icon.
- *Default:* `aria-label` carrying the same words the tooltip shows.
- *Exception:* none.

## 3. Search and filter

**MUST apply filters only on explicit submit.**

- *Applies:* every filter control on a list screen, free-text search included.
- *Default:* the filter group is a form; submitting it writes the query keys to the URL and refetches.
- *Exception:* none. One control applying instantly while its neighbours wait is the mixed model this rule exists to prevent.
- *Why:* the URL then always equals the applied filter set, which is what makes deep links and reloads truthful. Enterprise lists are paginated joins; refetching per keystroke costs the backend far more than it saves the user.

**MUST apply sort, page and page size immediately.**

- *Applies:* pagination and column sorting.
- *Default:* immediate, written straight to the URL.
- *Exception:* none. These are view controls, not filters, so they are outside the filter form.

**MUST have each filter control declare the query keys it owns.**

- *Applies:* every filter control.
- *Default:* Reset clears only the declared keys.
- *Exception:* none.
- *✗* treating every query key as a filter, which makes Reset wipe the page number and sort order, and lights Reset up for a bare `?page=3`.

**SHOULD let a compact filter row carry the field name through placeholder, current option or a from/to pair.**

- *Applies:* toolbar filters where a visible label would repeat the control's own content.
- *Default:* no visible label; an accurate `aria-label` stays.
- *Exception:* a control that cannot explain itself keeps its visible label.

**MUST enable label search on a Select at eight or more options.**

- *Applies:* every Select.
- *Default:* filter by visible label.
- *Exception:* none.

**MUST restore every selected value from the URL for a multi-select filter.**

- *Applies:* multi-select filters only.
- *Default:* single select. Multi-select requires the PRD to allow a set condition and the API to define the repeated parameter or array, with the query semantic stated (normally OR within one field).
- *Exception:* none — a multi-select without an API contract silently drops values on reload.

## 4. Table

**MUST key every row by a stable id.**

- *Applies:* every table and list rendering.
- *Default:* the record id.
- *Exception:* none.
- *✗* the array index, which reuses keys across pages and reorderings.

**MUST make the identifying column the link. NEVER make the row itself the click target.**

- *Applies:* every list whose rows lead somewhere.
- *Default:* link on the identifying cell.
- *Exception:* none.
- *Why:* rows already hold buttons and possibly checkboxes, so a clickable row has to fight event bubbling — and a clickable row is neither link nor button, so keyboard and screen-reader users cannot reach it at all.

**MUST render only the row actions this identity can execute on this row right now.**

- *Applies:* row action columns and pagination edges.
- *Default:* omit an action that business state or permission rules out; omit first/previous on the first page, next/last on the last, and all pagination on an empty result.
- *Exception:* an in-flight request — the entry already exists and the action already fired, so keep it visible and disabled with a pending indicator.
- *✗* a row of disabled buttons with tooltips explaining why they are disabled.

**MUST give each row action a unique and specific accessible name.**

- *Applies:* every action rendered per row.
- *Default:* the verb plus the record's identifying value.
- *✓* `Edit acme-prod` — not `Edit`, which collides with the cell of the same name in test selectors.

**MUST keep the header on one line and keep every truncated value reachable.**

- *Applies:* wide tables.
- *Default:* reserve width for short semantic columns (time, status, actions) so they never wrap; ellipsize long identifier columns and expose the full value through a tooltip or `title`, and through the accessible name.
- *Exception:* none.

**MUST keep horizontal scrolling in one layer.**

- *Applies:* tables wider than their container.
- *Default:* the table's own scroll container.
- *✗* an outer overflow wrapper around a table that already scrolls, producing two scrollbars for one overflow.

**Bulk selection is off unless the PRD asks for it.**

- *Applies:* every list.
- *Default:* no selection column — and the kit ships it **on**, so this one has to be switched off explicitly (§6). Whether a list supports bulk operations is a product capability, so the PRD and the hi-fi decide it — not this file.
- *Exception:* when the PRD does ask, a bulk destructive action takes the same confirmation as a single one (see [`ui-interaction.md`](ui-interaction.md) §6).

## 5. Empty state

**MUST show an empty state only when the request succeeded and returned zero rows.**

- *Applies:* lists and any collection rendering.
- *Default:* one plain "no data" message, with no call to action.
- *Exception:* none.
- *Why no action:* Reset already lives in the filter group, permanently visible above the table, so an in-state button would be a second entry to the same escape hatch.

**NEVER render an empty state for a request that failed.**

- *Applies:* 401, 404, 5xx, network and parse failures.
- *Instead:* route it through the failure classification in [`index.md`](index.md) §1.2.
- *✗* rendering "no data" for a request that never returned rows to begin with, which tells the user their data is gone and sends them looking for it instead of signing in again.

**Permission never surfaces as an empty state.** Row-level isolation returns an empty list and is *designed* to be indistinguishable from "there is nothing" — this track answers 404 for both "not yours" and "does not exist", because 403 would confirm the record exists. Page-level permission is handled before the page: the entry is not rendered, and a pasted URL produces a failure state.

## 6. What the kit covers, and what you must switch off

Reuse order is in [`index.md`](index.md) §6. **The inventory of what already exists is the `components/admin/` directory itself** — read it before building anything. A parallel list maintained here would go stale the moment the pin moves, for the same reason component APIs are not copied into this spec.

Two things live outside that directory, and each needs a rule.

### The pattern layer starts empty, and that is not permanent

`components/{app,data,forms}/` are empty at the start because the kit covers the whole resource-CRUD surface. **They fill up the moment a screen is not resource CRUD** — a dashboard, a wizard, a report, a bulk import. Build there; never by editing the snapshot.

What already sits outside the kit is what this track decided differently: the auth pages (session cookie plus CSRF bootstrap, not the kit's own auth), the app shell's branding, and the providers.

### Kit defaults that violate the rules above

The kit ships a demo's defaults. Several are on out of the box and break a rule in this file, so **switching them off is required, and leaving one on is a violation rather than a preference.**

| Default | Why it must be off |
|---|---|
| Bulk selection | §4: bulk is a product capability the PRD decides, not a list's resting state |
| Row click navigation | §4: only the identifying column is the link |
| Export | Ships whatever the list query returns, to a file, without any PRD asking |
| Column configuration | Which columns a screen shows belongs to the screen, not to per-user local state |
| Undoable mutations | [`ui-interaction.md`](ui-interaction.md) §4 assumes a mutation has either succeeded or reported a failure that stays put; an undo window means neither is true yet |
| Telemetry entry point | Sends usage data off the deployment with nobody asking |

- *Applies:* every list and the admin root.
- *Default:* explicitly off; update and delete run as pessimistic mutations.
- *Exception:* the PRD names the capability and the hi-fi draws it.
- *✗* leaving a default on because the demo had it — nothing fails, and it ships.

## 7. Accessibility invariants

These bind every rule above and are not overridden by a mockup.

- Semantic HTML: a real `button`, `a`, `table`, `form`, `h1`–`h6`. NEVER a clickable `div` — it is unreachable by keyboard.
- Every interactive control has an accessible name; icon-only controls carry `aria-label` plus a tooltip.
- Keyboard reach and a visible focus ring on every control, in DOM order.
- Colour is never the only carrier of meaning; body text meets 4.5:1 (values and trade-offs live in `design-system/MASTER.md`).
- Errors that arrive asynchronously are announced, not merely associated — see [`ui-interaction.md`](ui-interaction.md) §2.

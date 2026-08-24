# UI/UX Decision Rules · Interaction

> Behaviour: forms and validation, dialog vs drawer vs route, feedback, loading, destructive actions, and where a successful mutation leaves the user.
>
> Part of the frontend spec — the resident rules, what decides what, and the two
> checklists are in [`index.md`](index.md). Section numbers are per file, so a
> reference always names its file.

**Precedence, in full, is [`index.md`](index.md), under "What decides what".** In short: follow the approved hi-fi wherever it depicts something; apply the rules below everywhere it is silent, which is most of this file, because mockups draw the success state and almost never the other four; apply every NEVER rule even when a mockup contradicts it.

> **Read this file before writing UI code, not after.** It carries no `paths:`, so it never arrives on its own — open it from `index.md`'s "Where the rest of it lives" table.

## 1. Form layout and submission

**MUST place labels above their fields.**

- *Applies:* every form.
- *Default:* vertical layout.
- *Exception:* the hi-fi drew this form differently.

**MUST mark required fields and leave optional ones unmarked.**

- *Applies:* every form field.
- *Default:* an asterisk in the label plus `aria-required`.
- *Exception:* none — marking "optional" instead is the mixed model this rule prevents.
- *Why:* required is the constraint that changes what the user must do; optional is the resting state and carries no information.

**MUST put the submit action at the bottom of the form, left aligned, primary first.**

- *Applies:* every form.
- *Default:* submit then cancel, matching the DOM-order rule in `ui-structure.md` §1.
- *Exception:* a form taller than the viewport may pin the same group to a sticky footer.

**MUST disable the whole form while its submission is in flight, and show the pending state on the submit button.**

- *Applies:* every submitting form.
- *Default:* form disabled, submit button in its loading state, both driven by the mutation's pending flag.
- *Exception:* none.
- *Why:* editing a field while its own request is in flight cannot affect the outcome, so leaving the fields live only invites a second, conflicting submit.

## 2. Validation

**MUST run client validation on save only.**

- *Applies:* every form.
- *Default:* nothing is validated until submit, and a field that failed stays failed until the next submit.
- *Exception:* none.
- *Wiring:* `mode="onSubmit"`, `reValidateMode="onSubmit"` and `noValidate`, all three passed explicitly through the kit's form wrapper. The wrapper forwards these props but supplies none of them, and React Hook Form's own default re-validates a failed field on every change — so omitting any one of them silently produces the behaviour this rule forbids.
- *✗* validating as the user types, which reports "invalid email" to someone who has typed three characters of one.

**MUST let the server adjudicate admission.**

- *Applies:* every rule that decides whether a request is allowed.
- *Default:* the client blocks only obviously unusable input — missing required values, malformed formats. Everything else is answered by the response.
- *Exception:* none. Authorization is server-side and invariants are backed by the database — see [`../guides/cross-layer.md`](../guides/cross-layer.md).
- *✗* reimplementing a business rule in the browser so the two copies can drift.

**MUST announce field errors that arrive asynchronously.**

- *Applies:* errors returned by a submission, normalized from `problem+json` by the data provider.
- *Default:* render each one inside a live region (`role="alert"`) next to its field.
- *Exception:* none.
- *Why:* `aria-describedby` plus `aria-invalid` is correct only while focus is *inside* the field. After a submit, focus is on the button, so a merely associated description is never read aloud — which makes a failed sign-in completely silent for screen-reader users, at the one moment they most need telling.

**MUST let the form's own validation own format checking. NEVER set `type="email"` on a text input.**

- *Applies:* text inputs that hold structured values.
- *Default:* `type="text"` with the format rule in the form's validation, plus `inputMode="email"` and `autoComplete="email"`.
- *Why the hints stay:* the rule's target is one validation path and one announcement path. Dropping the mobile keyboard and the password-manager hint buys nothing toward that.
- *Why, given that `noValidate` is already mandatory:* `noValidate` only suppresses **interactive** validation — the bubble at submit. Constraint validation still runs, so `type="email"` keeps a **second validity state** that nothing on this page controls: `:invalid` matches, and `validity.typeMismatch` is set, **whenever the current value is not a syntactically valid email address** — which is every keystroke of one being typed. Any stylesheet reaching for `:invalid` — the kit's own, or one added later — then marks the field failed while React Hook Form, in `mode="onSubmit"`, still reports nothing. That is the behaviour §2's first rule forbids, arriving through CSS instead of through a message, and it is invisible until somebody writes the selector.
- *✗* `type="email"` on a field whose format the form already validates.

## 3. Dialog, drawer, or route

**MUST put creating and editing a resource on its own route, whatever the field count.**

- *Applies:* the main create and edit flow of any resource.
- *Default:* a route, through the kit's edit and create shells.
- *Exception:* none. The deciding question is "is this the resource's main CRUD flow?", never "how many fields does it have today".
- *Why the field count is the wrong question:* field counts change. A two-field form that grows to five would have to migrate out of the overlay, and that migration rewrites the URL, the deep link and the E2E suite — the cost lands exactly where it hurts most. Whether something is a resource's main CRUD flow stays stable for the life of the project.
- *Why a route at all:* every route in this track must survive a cold load from a pasted URL ([`data-layer.md`](data-layer.md) §9), and a form inside an overlay has no URL to paste.

**Use a dialog for a decision, not for a CRUD flow.**

- *Applies:* confirmations, in-place single-field edits such as rename, one-off choices.
- *Default:* the user returns to exactly the context they left.
- *✗* reaching for a dialog because the form happens to be short today.

**Use a drawer when the list must stay visible, or for a multi-group form that does not deserve a route.**

- *Applies:* side-by-side work against a list.
- *Default:* the list stays mounted and scrolled where it was.

**MUST disable overlay-click closing whenever the overlay holds unsubmitted state.**

- *Applies:* dialogs and drawers containing form input, secrets, a textarea, a bulk selection or a pending confirmation.
- *Default:* closing happens only through cancel, close or submit. Escape stays live — it is the keyboard's cancel, not a misclick.
- *Exception:* purely navigational overlays, menus, popovers, tooltips and read-only previews keep outside-click closing.

## 4. Feedback

**MUST report success with a toast.**

- *Applies:* create, update, delete and any other completed mutation.
- *Default:* a short toast naming what happened.
- *Exception:* none.

**MUST report failure somewhere it stays. NEVER report one with a toast alone.**

- *Applies:* every failed request.
- *Default:* a field-locatable failure renders on its field (§2); a failure that belongs to a block of content renders as an inline alert with retry, next to that block.
- *Exception:* a failure with nowhere to live — an asynchronous background job, for instance — may use a toast, and then must also leave a trace on the page.
- *Why:* a toast dismisses itself. A failure the user has not read yet, and can no longer read, is a failure they cannot act on.

**MUST keep a failing overlay open. NEVER close it and fire a toast instead.**

- *Applies:* any submit or confirmation inside a dialog or drawer.
- *Default:* the overlay stays open and renders the error inside itself.
- *✗* closing on failure and firing a toast, which discards the user's input and their only view of what went wrong.

**MUST leave a locatable field error visible.**

- *Applies:* forms that fail on submit.
- *Default:* the field-level errors are the report; a summary must not obscure them.

**MUST restrict status badges to real state.**

- *Applies:* every badge.
- *Default:* the project's status vocabulary, rendered as a dot plus text.
- *Exception:* none.
- *✗* animating a badge, which reads as "something is happening now" when it means "this is what this is".

## 5. Loading

**MUST render a skeleton for a first load whose layout is already known.**

- *Applies:* the first fetch of a screen with no cached data.
- *Default:* a skeleton shaped like the content that is coming, rendered only while the query is pending **and** there is no data yet.
- *Exception:* none.
- *✗* a hand-drawn spinner; and keying the skeleton on the pending flag alone, which brings it back on every refetch.

**MUST keep the current data on screen while it is being replaced.**

- *Applies:* refetches with data already rendered — pagination, sorting, filter submits, invalidation.
- *Default:* the previous rows stay, with a local pending indicator.
- *Exception:* none.
- *Why:* falling back to a skeleton on every filter submit makes the whole screen flash, and the user reads the flash as "my data disappeared".
- *Wiring:* the kit's list keeps the previous result across a query-key change on its own. What it does not supply is the first-load shape — that skeleton is the screen's job.

**MUST decide content state and pagination visibility together.**

- *Applies:* every list.
- *Default:* a failure renders the classified error with Retry; a successful zero-row result renders the empty state; pagination renders nothing in either case.
- *Exception:* none.
- *✗* leaving the kit's pagination mounted under a failure, which puts an uninterpolated range label beneath an error message and makes a failed request look like a successful page of zero rows.

**MUST show a single action's pending state on the control that started it.**

- *Applies:* row actions, submits, confirmations.
- *Default:* the control stays visible, disabled, in its loading state.
- *Exception:* none — this is the one case in `ui-structure.md` §4 where a disabled control is correct, because the entry already exists and the action already fired.
- *✗* a full-screen overlay for a single row's request. Reserve blocking overlays for operations that genuinely block the whole screen.

## 6. Dangerous actions

**MUST take a confirmation dialog before any destructive action.**

- *Applies:* delete, revoke, disable, reset, and anything else the user cannot undo — single-row and bulk alike.
- *Default:* one confirmation dialog. Its confirming button uses the destructive variant, and its text names the object being acted on (a bulk action names the count).
- *Exception:* none.
- *✓* `Delete connector acme-prod?` — not `Are you sure?`, which asks the user to trust that the right row was selected.

**MUST keep the confirmation dialog open when the action fails.**

- *Applies:* every destructive confirmation.
- *Default:* the error renders inside the dialog; the user can retry or cancel from there.

**MUST route confirmations through the pattern layer's confirm dialog. NEVER use `window.confirm`.**

- *Applies:* every confirmation.
- *Default:* one shared confirmation component — the kit's, or a single pattern-layer wrapper when the kit's does not fit — so every confirmation in the app behaves alike.
- *✗* `window.confirm`, which cannot be styled, cannot show a server error, and blocks the whole tab.

**NEVER make a destructive action the primary button.** Its weight comes from the destructive variant, not from promotion — see `ui-structure.md` §2.

## 7. Where a successful mutation leaves the user

One rule per mutation kind, so the three do not each get decided per screen.

| Mutation | Destination |
|---|---|
| Create | Back to the list, plus a success toast |
| Update | Stay on the current screen, plus a success toast |
| Delete | Stay on the list and refresh it, plus a success toast |

*Why creating returns to the list:* creating adds to a collection, and the list is where the user confirms it actually landed there.

*Why updating stays:* updating changes one record the user is looking at. Navigating away discards their context and turns editing several fields into a round trip per field.

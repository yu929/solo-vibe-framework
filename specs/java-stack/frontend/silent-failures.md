# What Fails Silently · Java Stack Frontend

> The six frontend mistakes that produce no error, no failing test and no visible defect on a developer machine: what each one looks like from the outside, and which file carries the rule it breaks.
>
> Part of the frontend spec — the resident rules, what decides what, and the two
> checklists are in [`index.md`](index.md). Section numbers are per file, so a
> reference always names its file.

Each one has a matching line in `index.md`'s Pre-Development Checklist. That line is what you act on before writing; this page is why it is there, and what you would be looking for once it has already gone wrong.

- **A form reachable while signed out submitting before the CSRF bootstrap returns** — it works once the page has been open a moment, and fails only on the fast path (`data-layer.md` §1.1).
- **Sign out, then straight back in** — the second door: a stale token answers 403 where you expected the app (`data-layer.md` §1.1).
- **A 401, a 5xx or a network failure rendered as "not found"** — the screen looks reasonable and sends everyone in the wrong direction (`data-layer.md` §1.2).
- **This slice's approved hi-fi screens missing from `implement.jsonl`** — a sub-agent in a fresh context builds something else, and the diff reads like carelessness.
- **The provider's clamp and the backend's sort allow-list drifting apart** — the generated types widen both back to `string`, so nothing catches it (`data-layer.md` §3.2).
- **A route with no cold-load E2E case** — the Vite dev server has its own history fallback, so deep links are always green in dev.

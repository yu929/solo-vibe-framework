# Web Fullstack · Spec Overview

> This file is the spec root overview (the official template's `.trellis/spec/README.md`). Each layer's entry point is `<layer>/index.md`; the track-independent thinking guides are in `guides/`.

> Coding rules for the Next.js 16 + Supabase track. Once installed they sit in `.trellis/spec/` and Trellis injects them on demand.
>
> **This file is the source of truth for the rules this track locks.** Where it conflicts with the starter repository's `AGENTS.md`, this file wins — see "Relationship to the starter's AGENTS.md" at the end.

> ### This template is self-contained; install exactly one
>
> One command:
>
> ```bash
> trellis init --claude --registry <framework repo URL> --template web-fullstack
> ```
>
> **Do not install a second template.** `registry.spec.template` in `.trellis/config.yaml` is a **singular** field, and installing a second one replaces that line outright. From then on `trellis update` refreshes only the one installed last — **this track's rules, including the safety red lines below, stop receiving fixes, and nothing reports an error**.
>
> That is why `guides/` (the track-independent thinking guides) is already packaged here: you do not need to install `universal-guides` as well. That template exists only for projects that have **no track spec at all**.

## Locked stack (substitutions need confirmation)

| Layer | Locked to |
|---|---|
| Framework | **Next.js 16 App Router** + **React 19** + **TypeScript** (strict) |
| Styling and components | **Tailwind v4** + **shadcn/ui** (Base UI kernel, `base-nova` style, neutral base colour) |
| Backend and data | **Supabase** (Postgres, Auth, RLS), locally through the Supabase CLI and Docker |
| Package manager and runtime | **pnpm** (corepack enabled); **Node ≥ 22** |
| Data access | `@supabase/supabase-js` + `@supabase/ssr` |
| Testing | **Vitest** (`*.test.ts`) + **Playwright** (`e2e/*.spec.ts`) |
| Deployment | **Docker containers** (`output: "standalone"` with a multi-stage build); **not Vercel** |

## Never (most lethal first)

> When a real project genuinely needs an exception — service-role for the Auth Admin API, say, or a forwarding Route because a secret cannot be a server-action argument — it is **recorded explicitly as a controlled exception** (scope, reason, where it lives). Nothing is bypassed quietly, and the exception itself has to survive review.
>
> **There is exactly one registered controlled exception, and most projects will never use it**: a heterogeneous sub-service's worker holding service-role, scoped in [`backend/sub-services.md`](backend/sub-services.md) §6.1. **When the project has no `services/` directory that exception does not exist**, and the rule is five words: do not bypass RLS. It carries one invariant that must not be abbreviated — the worker's only input is a job id, and it never fetches user data by an externally supplied primary key — plus one negative acceptance test: using tenant A's job to reach tenant B's resource must be refused. **"There is an exception" does not mean "service-role is free to use"**: anything not in that table is forbidden.

**Security (breaking these causes a real incident):**

- Never use a `service_role` or `secret` key in the frontend, or in any `NEXT_PUBLIC_*` variable.
- Never bypass RLS — no service-role client reading or writing user data.
- Never keep session credentials or a long-lived token in `localStorage`; use an httpOnly cookie, which Supabase SSR already does.
- Never use `dangerouslySetInnerHTML` on the client; where it is unavoidable, sanitize against an allow-list at the call site. Validate the protocol of an untrusted URL before assigning it to `href` or `src`, and always pair `target="_blank"` with `rel="noopener noreferrer"`.
- Never commit `.env.local`, and never write a key into source.

**Structure (breaking these spreads):**

- No hand-written SQL in application code; SQL appears only in `supabase/migrations/`.
- Generated files are not hand-edited: `src/components/ui/*` (produced by shadcn) and `src/lib/supabase/database.types.ts` (produced by Supabase).
- No API Route for handling a form submission; use Server Actions.
- No cookie written directly in a Server Component; leave it to the proxy or a server action.
- No `@radix-ui/*`: shadcn on this track runs the **Base UI** kernel (`components.json` → `style: base-nova`). Base UI uses a render prop and has **no `asChild`**, so do not apply Radix-era shadcn patterns found online.
- No `next/font/google` — it downloads fonts from the network at build time, so an internal or offline build fails. Fonts are vendored in `src/app/fonts/` and loaded through `next/font/local`.
- Ask before introducing a new dependency, especially a heavy one.

## Directory structure (where new code goes)

```
src/
  app/
    layout.tsx                  # root layout, mounts <Toaster/>
    fonts/*.woff2               # vendored fonts (next/font/local): zero network dependency at build time
    page.tsx                    # home (protected in the scaffold; to make it public see backend/index.md §2)
    login/page.tsx  signup/page.tsx
    auth/actions.ts             # auth server actions: login / signup / signOut
    <feature>/actions.ts        # one group of write operations per business module
    <feature>/[id]/edit/page.tsx  # a module's edit page, where needed
  components/
    ui/                         # shadcn components; add and remove with the CLI only, never hand-edit
    data/                       # patterns: DataTable / FilterBar / EmptyState / StatusBadge / ConfirmDialog / CopyButton / ActionTooltip
    forms/                      # patterns: FormRow / PasswordInput / SubmitButton
    app/                        # page scaffolding: page-header.tsx
    *.tsx                       # business components
  lib/
    auth/require-user.ts        # requireUser() (server-only plus react cache)
    supabase/{client,server,middleware}.ts   # the browser, server and session-refresh entry points
    supabase/auth-cookie.ts     # the one auth cookie name, shared by all three
    supabase/database.types.ts  # generated by supabase, not hand-edited
    status.ts                   # the status vocabulary: domain → tone and label
    utils.ts                    # cn()
  proxy.ts                      # the Next 16 proxy (formerly middleware); calls updateSession
design-system/MASTER.md         # the authority on the product's visual design
design-system/screens/          # the approved hi-fi screens; the fourth column of slices.md points here
supabase/
  config.toml  migrations/*.sql # the database schema (the only place SQL is written)
e2e/*.spec.ts                   # Playwright E2E, including RLS isolation
*.test.ts                       # Vitest unit tests, beside the code under test
Dockerfile  docker-compose*.yml # containerized deployment, including the self-hosted internal variant
.github/workflows/{ci,release}.yml
```

## Locked vs free

**Locked — ask before changing**: the stack, the directory layout, how data is accessed, RLS, where authorization happens.

**Free — just change it**: an individual page's layout, its copy, which components it uses.

## Spec index

Every `<layer>/index.md` carries the **Pre-Development Checklist** and **Quality Check** sections Trellis expects (`workflow.md` reads them by that convention).

**Track-specific.** Every file in this table declares `paths:`, so it is injected when you touch the source files it governs.

**Under `src/app/` the two layers are separated by extension**: `*.ts` is server code and belongs to the backend spec, `*.tsx` and `*.css` are route UI and belong to the frontend spec. App Router colocates server actions with the pages that call them, the glob grammar has no exclusion syntax, and one edited file must match exactly one spec — the extension is the only seam left.

**A colocated unit test belongs to the layer it sits in, not to the testing spec.** `src/lib/utils.test.ts` is governed by the backend spec and `src/components/x.test.ts` by the frontend spec; only `e2e/**` reaches the testing spec by path. The same grammar limit applies — nothing distinguishes `utils.ts` from `utils.test.ts` — so a testing glob over `**/*.test.ts` would match every layer at once and cost the loser its tail. Each layer's Pre-Development Checklist therefore carries a line pointing at [`testing/index.md`](testing/index.md) for the two rules a unit test actually needs. The java track assigns ownership the same way, globs and checklist line alike.

**Configuration is a layer, not an afterthought.** The four source-tree layers cover source files only, so `docker-compose*.yml`, `Dockerfile`, `package.json`, `next.config.*`, `supabase/config.toml` and `.github/workflows/**` used to match no spec at all — while the rules governing them sat inside [`backend/index.md`](backend/index.md) and [`database/index.md`](database/index.md), reachable only by someone already reading those layers. [`ops/index.md`](ops/index.md) owns those paths and routes each setting back to the file that owns its other half. The java track carries the same layer, for the same reason.

| File | Covers | Read it when |
|---|---|---|
| [`frontend/index.md`](frontend/index.md) | The Server/Client boundary, forms and overlays, hooks, theme and visuals, accessibility | Adding a component, writing a form, touching theme tokens |
| [`backend/index.md`](backend/index.md) | How data is read and written, auth and sessions, the auth cookie, the signup toggle | Writing a server action, touching auth or the proxy |
| [`database/index.md`](database/index.md) | RLS, the three parts of a new table, migrations, type generation | Adding a table, writing a migration |
| [`testing/index.md`](testing/index.md) | Required checks, how to verify behaviour and data (including two negative tests) | Before saying it is done |
| [`ops/index.md`](ops/index.md) | Project configuration, the local stack, compose, the image and the release tag | Changing a setting, a compose file, `next.config.*` or a workflow, or cutting a release |

**The longest sections sit beside their core**, in files that carry no `paths:` — they are reached from the core's "Where the rest of it lives" table, never injected. Section numbers are shared with the core they came from.

| File | Covers |
|---|---|
| [`backend/sub-services.md`](backend/sub-services.md) | §6 — when an execution-heavy service is worth splitting out, and the trust boundary a service-role worker must respect |
| [`frontend/components.md`](frontend/components.md) | §2 — the reuse order, and where a component's API comes from on a Base UI kernel |

**Track-independent** (holds on any stack; ships with this template):

| File | Covers | Read it when |
|---|---|---|
| [`guides/index.md`](guides/index.md) | Entry point for the guides | Unsure which guide applies |
| [`guides/code-reuse.md`](guides/code-reuse.md) | Where to look for an existing implementation before writing a new one | About to write something that resembles existing code |
| [`guides/cross-layer.md`](guides/cross-layer.md) | Criteria for splitting responsibility across layers, including "validation scattered across layers" — what [`backend/index.md`](backend/index.md) §5 and [`frontend/index.md`](frontend/index.md) §3 both point at | A feature crosses three or more layers |
| [`guides/review-adjudication.md`](guides/review-adjudication.md) | The four-field finding while coding; reporting is not deciding | You found a rule that is wrong, or a trap the spec never mentioned |
| [`guides/task-artifacts.md`](guides/task-artifacts.md) | What belongs in a task's `design.md` and `implement.md` | Writing task artifacts — **injected by path** |
| [`guides/source-of-truth.md`](guides/source-of-truth.md) | Which artifact is authoritative at each stage; writing back as a delta | Two documents disagree — **injected by path** |

> In the framework repository `guides/` is a **generated copy**; the source of truth is `specs/universal/guides/`, synced by `scripts/sync-spec-guides.sh`. **Edit the source of truth** — editing the copy here is overwritten at the next sync, and the framework repository's CI reports it first.

## Relationship to the starter's AGENTS.md

- **This directory is the source of truth.** It is maintained in the framework repository and injected on demand by Trellis.
- The starter's `AGENTS.md` keeps only project information, a pointer to this spec, and the few most lethal red lines — and those must be a **strict subset** of the Never list on this page, grouped the same way (security / structure). **The test for pushing a rule down**: a session that does not go through Trellis cannot see an on-demand spec, and breaking this rule causes a real incident. A rule that fails that test stays on this page.
- **Do not write that subset as a fixed enumeration.** Both lists will grow, and the moment an enumeration falls behind, a reader will judge the starter "out of scope" when it has merely pushed down one more equally lethal rule. Check it by **finding each starter rule's counterpart in the Never list on this page** — having no counterpart is the violation.
- **Change this directory first**, then sync back to the starter. Changing the other direction drifts.

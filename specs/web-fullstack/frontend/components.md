# Component Selection and Reuse · Web Fullstack

> Where to look before building something new, and where a component's API comes
> from on a Base UI kernel.
>
> Part of the frontend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across both files, so a
> section reference means the same thing wherever it is cited.

## 2. Component reuse order

New UI looks in this order:

1. `components/ui/*` — shadcn primitives
2. `components/{data,forms,app}/*` — the pattern layer: `DataTable` for lists, `FilterBar` for filters, `EmptyState`, `StatusBadge`, `ConfirmDialog` for deletions and other dangerous confirmations
3. Build something new only when neither fits

**Never reimplement a component that already exists.** Delete confirmations use `ConfirmDialog`, **never `window.confirm`**. The fixed page structure is in `design-system/MASTER.md`.

**The authority on how a component is written is upstream, not your memory.** Before deciding which component to `add`, or how to compose `components/ui/*`:

- If `shadcn` is registered in the project's root `.mcp.json`, or a shadcn skill is installed under the project's `.claude/skills/`, **consult it before writing**. It can read `components.json`, so it knows this project's kernel, its aliases and what is already installed.
- With neither, **read the matching component page at <https://ui.shadcn.com/docs/components> before writing**, and mention once that this project is not wired up. Once is enough — not every round.

**Memory is especially unreliable on this track**: `components.json` says `style: base-nova`, which is the **Base UI kernel**, while almost every public example and almost everything a model remembers is from the Radix era. A component written from memory compiles and renders; what it gets wrong is composition and accessibility attributes. The "no `@radix-ui/*`" entry in [`../README.md`](../README.md)'s Never list says what you may not write; this rule says where to get what is correct.

**Never copy component APIs into this spec.** They follow upstream versions, so a copy is guaranteed to go stale, and the stale copy will outrank upstream.

**Division of labour with `ui-ux-pro-max`:** visual design, typography, colour and the design system are its job; component selection, composition and props belong to the shadcn skill / MCP. Its bundled shadcn data is a static snapshot and **is not an authority on component APIs**.

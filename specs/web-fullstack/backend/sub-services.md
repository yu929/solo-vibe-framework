# Heterogeneous Sub-Services · Web Fullstack

> When an execution-heavy service is worth splitting out of Next, and the trust
> boundary a worker holding service-role must respect.
>
> Part of the backend spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across both files, so a
> section reference means the same thing wherever it is cited.

## 6. Heterogeneous sub-services (a Python executor, for instance)

> **First decide whether this section applies: does the project have a `services/` directory?** The scaffold does not, and most projects will not. **When it does not, this section and every cross-reference pointing at it do not apply** — the "registered controlled exception" in [`../README.md`](../README.md)'s Never list, the "only controlled exception" in [`../database/index.md`](../database/index.md) §1, and item 3 of "How to verify" in [`../testing/index.md`](../testing/index.md) are all void, and the rule reduces to its simplest form: **do not bypass RLS, no exceptions**.
>
> This section is kept because the trust-boundary reasoning is expensive and nobody should walk through it twice when the split is genuinely needed. Until you have a `services/` directory, it is worth nothing to you.

**When it is needed**: the product has an execution-heavy side — SSH deployment, calling a target system's internal API, heavy computation — that does not belong inside the Next process. Split it out, and let Next dispatch jobs over HTTP with a Bearer token.

**When it is not**: anything that can be finished synchronously in a server action should not be split out. The cost of splitting is another deployment, another trust boundary, and another version to keep aligned.

**The standard pattern:**

1. **Directory**: `services/<svc>/`, with Python dependencies managed by **uv** (FastAPI plus `pyproject.toml` and `uv.lock`).
2. **The paired convention**: that directory carries its own `AGENTS.md` (the locked rules for that track) and `CLAUDE.md` (one line, `@AGENTS.md`) — the root `CLAUDE.md`'s imports **do not** reach into subdirectories, so a heterogeneous sub-project brings its own pair. Add a line to the root `AGENTS.md`: read `services/<svc>`'s own `AGENTS.md` before editing it.
3. **The trust boundary**: §6.1 below, the one part of this section that must not be abbreviated.
4. **Release coupling**: `pnpm release:validate` already checks that `services/*/pyproject.toml` versions match the tag. Add that service's quality job (ruff, mypy, pytest) plus image build and OCI metadata verification to `release.yml`.
5. **Compose**: the sub-service gets its own `docker-compose.<svc>.yml`, started and stopped separately from the app.

### 6.1 The trust boundary: a worker consumes only jobs whose ownership is already bound

**Start with what a shared Bearer token proves**: only that "the caller is our Next app". It **does not prove which user this call belongs to**. And service-role bypasses RLS. Put those together, and if the worker is willing to fetch by a primary key handed in from outside, then a key that was guessed, replayed, or simply passed wrong by Next is a cross-tenant read — with nothing at the database level to stop it.

So **a worker may not fetch user data by an arbitrary primary key**. It goes in three parts instead.

**① The job is created by a user-scoped path.** Next writes a row into the job table from a server action using the ordinary client (publishable key plus RLS), taking `user_id` from `auth.uid()` and **never from the client**. The job table itself is created with the three parts in [`../database/index.md`](../database/index.md) §2 — grant, RLS, policies. Ownership is fixed by the database at this step, rather than carried along later as a parameter.

**② The worker consumes by job id only.** Its single input is a job id. Every user table it reads goes through a **database function that checks ownership explicitly** — the function compares that job's `user_id` or `tenant_id` against the target row's owner and raises on a mismatch. **A bare `service_role` `.select()` on an externally supplied primary key is not allowed.**

**③ The exception's scope is fixed and does not widen.**

| service-role may | service-role may not |
|---|---|
| Update that job's status, progress and result, by job id | Read or write user data across jobs |
| Call one of those ownership-checking database functions | Fetch from a user table by an externally supplied primary key |
| Read its own runtime configuration | Skip the ownership check because "Next already validated it" |

**This is the only controlled exception to "do not bypass RLS" in [`../database/index.md`](../database/index.md) §1, and its scope is defined in this section alone.** When service-role is needed elsewhere, come back and read this table rather than copying this section's conclusion.

**④ Ciphertext does not travel over HTTP.** **Next does not send ciphertext over HTTP**; keys are injected through the environment, and the encryption format the two sides share is maintained in one place.

**⑤ Acceptance is negative.** Having written an ownership check is not the same as it working, and the only thing that counts is this: using tenant A's job to reach tenant B's resource key **must be refused**. See item 3 of "How to verify" in [`../testing/index.md`](../testing/index.md). This matches how the track treats RLS in general — a policy that is written gets tried with a second account.

> By the same reasoning, the identity groundwork "every internal tool needs" — administrator-created accounts, disabled self-service signup, brute-force protection, TOTP, LDAP — **is not pre-installed**. Implement what the project actually needs, in the slice that needs it. The scaffold keeps the minimum that runs, and does not decide for you what you may not want.

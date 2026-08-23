# What Tests Which · Java Stack

> The level-to-tool map, and the state that leaks between tests when it is treated as test state.
>
> Part of the testing spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across the whole layer, so a
> section reference means the same thing wherever it is cited.

## What tests which

| Level | Tool | Location | Covers |
|---|---|---|---|
| Architecture constraints | **ArchUnit** | `src/test/java/**/architecture/` | That owner-scoped access is not bypassed |
| **The guards' own tests** | **Plain JUnit** (no container) | `src/test/java/**/architecture/` | That the rules above **still bite** |
| Backend integration | **JUnit 5 + Testcontainers** | `src/test/java/**/<module>/` | A real Postgres, a real filter chain, a real session |
| **Concurrency invariants** | **Plain JUnit + a thread pool** | Beside the component itself | Properties that appear only when requests arrive together (rate limiting, caps) |
| Frontend logic | **Vitest** | `frontend/src/**/*.test.ts` | Pure functions and logic |
| End to end | **Playwright** | `frontend/e2e/*.spec.ts` | Real flows against the packaged artifact |

Backend integration tests carry the session in a cookie (the `ApiIntegrationTest` base class). **Do not take a shortcut past the filter chain with something like `@WithMockUser`** — that leaves CSRF, sessions and authorization all untested, and those three are the easiest to misconfigure.

Integration tests do **not** carry `@Transactional`: rolling back the test transaction hides problems that only surface on a real commit.

**Rate limiting is application state, not test state.** This ruins tests in two ways, both of which look like "green alone, red together":

- **Tests in one context consume each other's budget.** MockMvc reports every request's client address as `127.0.0.1`, so to the rate limiter the whole suite is one caller. Have the base class **give each test instance its own address** and stamp it on every request — tests are independent callers already; this just says so.
- **The buckets are not reset between tests.** A test that asserts a specific budget empties the limiter first (inject the component, call a package-private `reset()`), or it is asserting how many tests ran before it.

**A property that only holds under concurrency needs a concurrency test.** A sequential loop is completely green against a "check then charge" implementation — it issues one request at a time and never hits the window. The shape is: a `CountDownLatch` releasing N threads at once, counting **how many were admitted**, and asserting that equals the budget rather than N.

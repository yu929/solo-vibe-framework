# The Local Development Database · Java Stack

> How the local stack is brought up and reset, and the traps that only exist on a developer machine.
>
> Part of the database spec — the resident rules and the checklists are in
> [`index.md`](index.md). Section numbers are shared across the whole layer, so a
> section reference means the same thing wherever it is cited.

## 5. The local development database

Three separate traps: which volume it uses, which interface it listens on, and which password it starts with.

### 5.1 The project-name trap

The first thing a new project runs is `scripts/init-project.sh <project-name>`.

**Compose derives the volume name from the project name.** Skip this and every project generated from this template **shares one Postgres volume** — project A's `docker compose down -v` silently wipes project B's data.

The same script also changes the session cookie name: the default `JSESSIONID` is shared by every application on localhost, so two projects in development sign each other out.

### 5.2 The development database binds to loopback only

Writing `"5432:5432"` in compose means `0.0.0.0:5432` — **publishing the development database on every interface**. Combined with a fixed password committed to a public template repository, that is a database anybody can connect to from a café's wifi or a corporate network.

Always write **`"127.0.0.1:5432:5432"`**. Everything that connects to it — the application, an IDE, psql — runs on this machine, and none of it needs the database visible from outside.

### 5.3 The database password has no default, not even one that looks like a development value

`application.yml` **carries no default for the password**, not even one named `dev-only-not-a-secret`. The reason is not the naming, it is the **silent fallback**: any startup path with the variable unset — a bare `java -jar`, a systemd unit, a k8s manifest missing one env entry — **starts successfully** on that publicly known password.

The password's only source is an **uncommitted `.env`** (seeded from `.env.example`), which `bootRun` reads; deployments use environment variables.

#### But "no default" does not mean "it will fail" — two counter-intuitive traps

**Trap one: the variable name must not be the property's relaxed-binding form.**

```yaml
password: ${SPRING_DATASOURCE_PASSWORD}   # ← self-referential
```

`SPRING_DATASOURCE_PASSWORD` is precisely the environment-variable form of `spring.datasource.password`, so this asks the property to resolve itself. With the variable unset it collapses to an empty string instead of failing. **Use a name that is not an alias of the property**, such as `APP_DB_PASSWORD`.

**Trap two: a failed placeholder resolution does not abort startup either.**

Spring Boot **ignores unresolvable placeholders** when binding `@ConfigurationProperties`, and hands the literal string `${APP_DB_PASSWORD}` to the driver. Most servers answer `password authentication failed` — cryptic, but at least fatal. With Postgres configured for `trust` authentication, **any password passes**, and the application comes up normally on a credential nobody ever set. Another one with no symptom.

**So `main()` blocks it explicitly**, checking environment variables and system properties before `SpringApplication.run` and throwing when they are missing. That guard needs a unit test, with the environment lookup passed in as a parameter — a JVM cannot change its own environment variables.

> Both traps came out of running it: first the assumption that "removing the default will make it fail", which turned out to be `password authentication failed`; then a rename, which still did not fail. **"I assumed it would error" is not verification.**

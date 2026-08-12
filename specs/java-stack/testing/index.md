# 质量门与验证 · Java Stack 轨

> 说「做完了」之前必须全绿。轨总览见 [`../README.md`](../README.md)。

## 命令门（每次都要）

```bash
./gradlew spotlessCheck check
pnpm -C frontend typecheck && pnpm -C frontend lint && pnpm -C frontend test && pnpm -C frontend build
```

`./gradlew check` 里包含：Java 编译 + 单元/集成测试（Testcontainers 起真 Postgres）+ ArchUnit 归属收口 + 前端 Vitest。

> **Testcontainers 要 Docker 在跑。** 没开 Docker 时 `check` 的失败信息是连接错误，容易被当成环境坏了——先看一眼 `docker ps`。

## 按改动类型追加

| 动过什么 | 追加 |
|---|---|
| 格式 | `pnpm -C frontend format` · `./gradlew spotlessApply` |
| 页面 / 路由 / 流程 | `./gradlew :backend:bootJar && pnpm -C frontend test:e2e` |
| DB schema | 先 `docker compose -f docker-compose.dev.yml down -v && up -d`，确认能从空库重放 |
| 后端 API 契约 | `pnpm -C frontend api:types` 重新生成，再 `pnpm -C frontend typecheck` 看哪里断了 |

**`pnpm format` / `spotlessApply` 的收尾自检**：跑完用 `git status` 看一眼——**如果出现本次任务没编辑过的文件**，先确认原因，必要时回退或拆成单独的格式化变更。

## E2E 必须跑在打包产物上

`playwright.config.ts` 的 webServer 起的是 **`backend/build/libs/app.jar`**，不是 `vite dev`。这不是偏好：

- Vite dev server 自带 history fallback，**SPA 深链 404 这个坑在 dev 下永远是绿的**；
- 它也不经过 Spring 的静态资源链路，所以 `SpaForwardConfig` 的排除列表根本没被执行到。

在 dev server 上跑 E2E，等于把这条轨最容易出、也最难自查的一类缺陷排除在测试之外。

```bash
docker compose -f docker-compose.dev.yml up -d   # Postgres
./gradlew :backend:bootJar                        # SPA 打进 jar
pnpm -C frontend test:e2e
```

> `java -jar` 用的是**你 PATH 上的 JDK**，不是 Gradle toolchain 下载的那个。PATH 上低于 25 会报 `UnsupportedClassVersionError`——构建成功、运行失败，看起来像产物坏了。

## 测试分工

| 层 | 工具 | 位置 | 管什么 |
|---|---|---|---|
| 架构约束 | **ArchUnit** | `src/test/java/**/architecture/` | 归属收口不被绕过 |
| 后端集成 | **JUnit 5 + Testcontainers** | `src/test/java/**/<模块>/` | 真 Postgres、真过滤器链、真会话 |
| 前端逻辑 | **Vitest** | `frontend/src/**/*.test.ts` | 纯函数与逻辑 |
| 端到端 | **Playwright** | `frontend/e2e/*.spec.ts` | 打包产物上的真实流程 |

后端集成测试用 cookie 携带会话（`ApiIntegrationTest` 基类），**不要用 `@WithMockUser` 之类绕过过滤器链的捷径**——那样 CSRF、会话、授权全都没被测到，而这三样正是最容易配错的。

集成测试**不加 `@Transactional`**：测试事务回滚会掩盖只在真正提交时才暴露的问题。

## 怎么验证（功能 + 数据）

1. `./gradlew :backend:bootRun` → `localhost:8080`：注册 → 登录 → 对某业务模块走通新增/编辑/删除 → 登出
2. **数据隔离（负向，本轨最贵的一条）**：用 A 账号建一条数据，拿它的 id 用 **B 账号的会话**去 `GET` / `PUT` / `DELETE`，**三个都必须 404**；B 的列表必须为空；**并且回头确认 A 的数据没被改动**——否则一个「返回 404 但其实删掉了」的实现也能骗过前面的断言
3. **跨用户例外（有 admin 通道时才需要）**：用普通账号调那个 admin 端点，**必须被拒**
4. **打包后深链**：`./gradlew :backend:bootJar && java -jar backend/build/libs/app.jar`，浏览器**直接粘**一个子路由 URL 并刷新 → 必须正常渲染
5. 命令门全绿；空库能从零重放全部迁移

第 2、3、4 条是本轨最容易被跳过、也最贵的三条。**写了不等于生效。**

第 2、3 条都是**负向测试**：证明"该拒的拒了"。正向用例全绿并不能证明这一点，因为它们从来没试过越权。所以它们必须单独存在，不能靠"功能跑通了"顺带覆盖。

## 验证测试本身有效（falsification）

新加的守卫要确认它**会红**，否则你只是加了一个永远绿的装饰：

| 守卫 | 怎么证明它有效 |
|---|---|
| ArchUnit 归属收口 | 把某个 repository 改成 `extends JpaRepository<T, ID>` → 必须红 |
| 双账号负向测试 | 把 service 里的 `findByIdAndOwnerId` 换成 `findById` → 必须红 |
| 深链 E2E | 摘掉 `SpaForwardConfig` 的 `@Configuration` → 必须红 |
| 契约漂移 | 改一下 `schema.d.ts` 里的字段名 → `pnpm typecheck` 必须红 |
| 凭据不进会话 | 把 `eraseCredentials()` 的方法体清空（**保留方法**，删掉会变成编译错误而不是测试变红）→ 必须红 |
| 写响应时间戳 | 把 `saveAndFlush` 换回 `save` → 必须红 |
| 改名脚本的拒绝路径 | 预先建好目标包目录再跑 `--package` → 必须拒绝，且已有文件仍在 |
| 改名脚本的零写入 | 给某个待改文件插一处小改动让模式不再命中 → 必须拒绝，且**其它文件一个都没被改** |
| 改名脚本的祖先校验 | 把目标包的某一级祖先做成普通文件 → 必须拒绝，且其它文件未被改 |
| 改名脚本的幂等 | 用一个**包含模板名**的项目名（如 `java-stack-demo`）连跑两次 → 第二次必须是 no-op，不得拼成 `java-stack-demo-demo` |
| 改名脚本的权限校验 | 把某个待改文件的**父目录**设为只读（文件本身仍可写）→ 必须拒绝且零写入 |
| 改名脚本的统一表 | 给 `build.gradle.kts` 的 `group` 行加个行尾注释 → 必须拒绝，且包目录未被移动 |
| 改名脚本的清单完整性 | 把源包里的一个**子目录**设为不可遍历（`chmod a-x`）→ 必须拒绝，且深层文件原样保留 |
| 改名脚本的可重跑 | 成功后把**完整命令**（含 `--package`）原样再跑一次 → 必须 exit 0 并报告已改名 |
| 口令守卫 | `env -u APP_DB_PASSWORD java -jar app.jar` → 必须在任何 Hikari/Flyway 日志之前就拒绝 |

> 权限用例在 root 下无意义（root 绕过权限位），测试脚本要自己 `id -u` 判断并跳过，否则 CI 里是假绿。

> **「凭据不进会话」那行的括号是实战教训**：删掉整个方法只会让类少实现一个接口方法，构建在**编译阶段**就挂了，看起来像测试红了，其实测试根本没跑。**falsification 要注入的是「行为错」，不是「编译错」。**

**做完记得改回来并复跑一次全绿。**

## 本地依赖

```bash
docker compose -f docker-compose.dev.yml up -d    # Postgres（Testcontainers 另起自己的）
pnpm -C frontend install
```

## 容器化与发版

```bash
cp .env.example .env                                  # 至少填 POSTGRES_PASSWORD
docker compose up -d --build                          # 自带数据库
docker compose -f docker-compose.yml \
  -f docker-compose.external-db.yml up -d --build     # 外部 / 托管 Postgres
```

发版走 `vX.Y.Z` / `vX.Y.Z-rc.N` tag：

1. 先改 `gradle.properties` 的 `version` **和** `frontend/package.json` 的 `version`（两处必须一致）
2. `./gradlew validateReleaseTag -Ptag=vX.Y.Z`
3. tag push 触发 `.github/workflows/release.yml` 的发布质量门 + 镜像元数据核验

**镜像与环境无关**（前端只调相对 `/api`，没有构建期烤进去的地址），所以一次构建可以部署到任何环境。生产记得 `APP_API_DOCS_ENABLED=false`、TLS 后 `APP_COOKIE_SECURE=true`。

---

## Pre-Development Checklist

- [ ] 这次改动要补哪一类测试？逻辑 → Vitest；后端行为 → JUnit + Testcontainers；页面/流程 → Playwright
- [ ] 改的是 bug 吗？**先写一个会失败的测试**，再修
- [ ] 新增每用户表或新增读写它的接口了吗？**必须补双账号负向测试**
- [ ] 新增路由了吗？E2E 补一条**冷加载 + 刷新**用例
- [ ] 新加的守卫，验过它会红吗？

## Quality Check

见本页「命令门」。说「做完了」之前两条必须全绿，按改动类型追加对应的那条。

额外自检：

- [ ] Docker 是开着的（否则 Testcontainers 的失败会被误读成代码问题）
- [ ] E2E 跑的是 `bootJar` 的产物，不是 dev server
- [ ] 格式化没有顺手改到本次任务无关的文件

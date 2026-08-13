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
| **守卫的守卫** | **纯 JUnit**（不起容器） | `src/test/java/**/architecture/` | 上面那些规则**还咬得动** |
| 后端集成 | **JUnit 5 + Testcontainers** | `src/test/java/**/<模块>/` | 真 Postgres、真过滤器链、真会话 |
| **并发不变量** | **纯 JUnit + 线程池** | 组件自己的包下 | 只在同时到达时才出现的性质（限流、上限） |
| 前端逻辑 | **Vitest** | `frontend/src/**/*.test.ts` | 纯函数与逻辑 |
| 端到端 | **Playwright** | `frontend/e2e/*.spec.ts` | 打包产物上的真实流程 |

后端集成测试用 cookie 携带会话（`ApiIntegrationTest` 基类），**不要用 `@WithMockUser` 之类绕过过滤器链的捷径**——那样 CSRF、会话、授权全都没被测到，而这三样正是最容易配错的。

集成测试**不加 `@Transactional`**：测试事务回滚会掩盖只在真正提交时才暴露的问题。

**限流是应用状态，不是测试状态**——这会以两种方式毁掉测试，都表现为「单跑绿、一起跑红」：

- **同一个上下文里的测试互相消耗额度**。MockMvc 给每个请求报的客户端地址都是 `127.0.0.1`，所以在限流眼里全套测试是同一个调用方。让基类给**每个测试实例分配一个自己的地址**并盖在每个请求上——测试本来就是彼此独立的调用方，说出来而已。
- **测试之间不复位桶**。要断言具体额度的测试，先把限流器清空（注入组件、调一个包级 `reset()`），否则它断言的是「前面跑了几个测试」。

**只在并发下成立的性质，必须用并发测试**。顺序循环对「先查后扣」这类实现是完全绿的——它一次只发一个请求，永远撞不上那个窗口。写法是：一个 `CountDownLatch` 让 N 个线程同时起跑，数**放行了几个**，断言它等于额度而不是等于 N。

## 怎么验证（功能 + 数据）

1. `./gradlew :backend:bootRun` → `localhost:8080`：注册 → 登录 → 对某业务模块走通新增/编辑/删除 → 登出
2. **数据隔离（负向，本轨最贵的一条）**：用 A 账号建一条数据，拿它的 id 用 **B 账号的会话**去 `GET` / `PUT` / `DELETE`，**三个都必须 404**；B 的列表必须为空；**并且回头确认 A 的数据没被改动**——否则一个「返回 404 但其实删掉了」的实现也能骗过前面的断言
3. **跨用户例外（有 admin 通道时才需要）**：用普通账号调那个 admin 端点，**必须被拒**
4. **认证限流（负向）**：把按账号的额度用光，然后拿**正确**的密码登录——必须仍然是 **429**。这是「BCrypt 根本没跑」唯一能从外部观察到的证据；一个先验证、再把 401 改写成 429 的实现，在这里会回 200（[`../backend/index.md`](../backend/index.md) §4.5）
5. **换账号不留残影**：一个浏览器开两个标签页，在其中一个登出 → 另一个必须自己去登录页且不再显示那份数据，而发起的那个**没有**被重新加载（[`../frontend/index.md`](../frontend/index.md) §3.1）
6. **打包后深链**：`./gradlew :backend:bootJar && java -jar backend/build/libs/app.jar`，浏览器**直接粘**一个子路由 URL 并刷新 → 必须正常渲染
7. 命令门全绿；空库能从零重放全部迁移

第 2、3、4、6 条是本轨最容易被跳过、也最贵的几条。**写了不等于生效。**

第 2、3、4 条都是**负向测试**：证明"该拒的拒了"。正向用例全绿并不能证明这一点，因为它们从来没试过越权、也从来没打满过额度。所以它们必须单独存在，不能靠"功能跑通了"顺带覆盖。

## 验证测试本身有效（falsification）

新加的守卫要确认它**会红**，否则你只是加了一个永远绿的装饰：

| 守卫 | 怎么证明它有效 |
|---|---|
| ArchUnit · 父接口白名单 | 把某个 repository 改成 `extends JpaRepository<T, ID>` → 必须红。再单独试 `PagingAndSortingRepository` 和混入 `JpaSpecificationExecutor`，**黑名单式的旧规则对这两个是绿的** |
| ArchUnit · 方法按 owner 过滤 | 手写一个 `Optional<T> findById(UUID)` 挂在裸 `Repository` 上 → 必须红 |
| ArchUnit · `@OwnerlessTable` 说的是真的 | 把 `@OwnerlessTable` 标到一个**带 `ownerId`** 的实体的 repository 上 → 规则三必须红。**只验放行那一半是不够的**——把规则三整个删掉，字典表用例照样全绿，而那条接口级豁免从此不受任何核对 |
| 守卫的守卫 | 把 ArchUnit 规则改成恒真（比如条件永远不 `violated`）→ 反向测试必须红。**这条是唯一能发现「守卫失效」的东西**，因为失效的守卫本身是绿的 |
| 双账号负向测试 | 把 service 里的 `findByIdAndOwnerId` 换成 `findById` → 必须红 |
| 限流 · 拒绝点在验证之前 | 把额度检查挪到 `authenticate()` **之后** → 「额度耗尽时正确密码也拿不到 200」那条必须红 |
| 限流 · 预留而非先查后扣 | 把原子 `tryConsume` 换成「先读余量、再扣」两步 → **并发**测试必须红（顺序测试仍然全绿，这正是要点） |
| 限流 · 不是账号锁定 | 让被拒的请求也记一次失败 → 「额度会自己回填」那条必须红 |
| 追踪表上限 | 把上限判断挪到锁外 → 并发插入测试必须红 |
| 输入边界 · 密码 | 提交 73 字节的密码 → 必须 400；把校验换成 `@Size(max=72)`，再用 19 个 emoji（38 字符 / 76 字节）提交 → 必须红 |
| 输入边界 · 邮箱 | 用一个 150 字符的邮箱注册，然后**用它拿到的会话再发一个请求、并重新登录一次** → 必须全绿；只断言注册返回 201 的话，列宽不够也照样通过 |
| 换账号不留残影 | 把登录成功后的 `clear()` 换回 `invalidateQueries()` → 首帧仍显示前一个账号数据；把广播关掉 → 两标签页那条必须红 |
| 深链 E2E | 摘掉 `SpaForwardConfig` 的 `@Configuration` → 必须红 |
| 契约漂移 | 改一下 `schema.d.ts` 里的字段名 → `pnpm typecheck` 必须红 |
| 凭据不进会话 | 把 `eraseCredentials()` 的方法体清空（**保留方法**，删掉会变成编译错误而不是测试变红）→ 必须红 |
| 写响应时间戳 | 把 `saveAndFlush` 换回 `save` → 必须红 |
| 口令守卫 | `env -u APP_DB_PASSWORD java -jar app.jar` → 必须在任何 Hikari/Flyway 日志之前就拒绝 |

> **改工作树的脚本（如 `scripts/init-project.sh`）另有一组 falsification 用例**——拒绝路径、零写入、祖先校验、幂等、父目录权限、清单完整性——它们跟着那个可执行工件走，写在 starter 仓的 `scripts/README.md` 与 `scripts/test-init-project.sh` 里，不在本页。本页只列产品代码的守卫。

> **「凭据不进会话」那行的括号是实战教训**：删掉整个方法只会让类少实现一个接口方法，构建在**编译阶段**就挂了，看起来像测试红了，其实测试根本没跑。**falsification 要注入的是「行为错」，不是「编译错」。**

**做完记得改回来并复跑一次全绿。**

## 本地依赖

```bash
docker compose -f docker-compose.dev.yml up -d    # Postgres（Testcontainers 另起自己的）
pnpm -C frontend install
```

## 容器化与发版

```bash
cp .env.example .env                                  # A 至少填 POSTGRES_PASSWORD；B 填 APP_DB_*

# A) 自带数据库：不写 -f，compose 自动加载 docker-compose.override.yml
docker compose up -d --build

# B) 外部 / 托管 Postgres：显式 -f 会连带抑制那个 override，自带库整个不参与
docker compose -f docker-compose.yml \
  -f docker-compose.external-db.yml up -d --build
```

**两个 compose 的坑，都没有症状**：

- **`environment:` 块里没列的变量，容器根本收不到。** 它在 `.env` 里、compose 能读到它、然后就到此为止。表现是「我明明调了参数，容器还在用默认值」。**每加一个应用配置项，同时把它加进 compose 的 `environment:`。**
- **compose 先逐文件插值、再合并**，所以基础文件里的 `${X:?...}` 会在**每一种**模式下触发，包括那些根本不启动对应服务的模式。把只属于某一种模式的必填变量放进那一种模式自己的文件里。`deploy: replicas: 0` 不解决问题——插值早在它生效之前就发生了。

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
- [ ] 这次的性质只在并发下才成立吗？（限流、上限、去重）顺序测试对它是绿的——补一条同时起跑的
- [ ] 新加的守卫，验过它会红吗？改的是**守卫本身**的话，它的反向测试跟着更新了吗？

## Quality Check

见本页「命令门」。说「做完了」之前两条必须全绿，按改动类型追加对应的那条。

额外自检：

- [ ] Docker 是开着的（否则 Testcontainers 的失败会被误读成代码问题）
- [ ] E2E 跑的是 `bootJar` 的产物，不是 dev server
- [ ] 格式化没有顺手改到本次任务无关的文件

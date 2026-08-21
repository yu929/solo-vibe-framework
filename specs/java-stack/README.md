# Java Stack 轨 · 规范总览

> 本文件是 spec 根总览（对应官方模板的 `.trellis/spec/README.md`）。各层入口在 `<layer>/index.md`，轨无关思维清单在 `guides/`。

> Spring Boot 4 + Postgres + React 19 / shadcn-admin-kit 轨的编码规范。装进项目后位于 `.trellis/spec/`，由 Trellis 按需注入。
>
> **本文件是本轨锁定规则的权威源。** 与 starter 仓 `AGENTS.md` 冲突时以本文件为准——见本页末「与 starter AGENTS.md 的关系」。

> ### 本模板是自足的，一个项目只装它一个
>
> 装法只有一条命令：
>
> ```bash
> trellis init --claude --registry <框架仓 URL> --template java-stack
> ```
>
> **不要再装第二个模板。** Trellis 的 `.trellis/config.yaml` 里 `registry.spec.template` 是**单数**字段，装第二个会把它整行替换掉，此后 `trellis update` 只刷新后装的那个——**本轨规范（含下面那些安全红线）从此收不到修复，而且不报错**。
>
> 所以 `guides/`（轨无关思维清单）已经打包在本模板里，不需要额外装 `universal-guides`。那个模板只给**还没有轨规范**的项目用。

## 数据隔离是本轨最重的一节

每用户数据隔离**没有数据库兜底**。隔离就是查询里带的那个 `owner_id` 谓词，**fail-open**：漏了不会报错，会返回 200 和别人的数据，日志里什么都没有。

所以本轨用三样机器能验的东西代替这条人要记住的纪律，完整定义在 [`backend/index.md`](backend/index.md) §2。其余都是常规工程。

## 栈锁定（不经确认不得替换）

| 层 | 锁定 |
|---|---|
| 语言 / 运行时 | **Java 25 LTS**（Gradle toolchain 自动下载用于编译） |
| 框架 | **Spring Boot 4.1.x**（Spring Framework 7） |
| 构建 | **Gradle 9 + Kotlin DSL** + version catalog（`gradle/libs.versions.toml`） |
| 数据库 | **Postgres 17** + **Flyway**（纯 SQL 迁移） |
| ORM | **Spring Data JPA / Hibernate 7** |
| 鉴权 | **Spring Security** + **Spring Session JDBC**（会话存 Postgres），**不用 JWT** |
| 认证限流 | **bucket4j**（`bucket4j_jdk17-core`）令牌桶，进程内；按客户端地址 + 按账号两份额度 |
| API 文档 | **springdoc-openapi 3.x** → `/v3/api-docs` → 前端类型 |
| 前端 | **Vite 8 + React 19 + TypeScript 6 + Tailwind v4 + shadcn/ui + shadcn-admin-kit**（视觉单源在 `globals.css` 的 `@theme`） |
| 前端数据层 | **ra-core**（shadcn-admin-kit 的内核）的 dataProvider / authProvider / `<Resource>`；**TanStack Query 在它下面，不直接用** |
| 前端路由 / 表单 | **React Router 8** + **React Hook Form**（ra-core 自带集成） |
| 包管理 | 后端 Gradle；前端 **pnpm**（宿主机 Node ≥ 24 + corepack，**不让 Gradle 另下一个 pnpm**） |
| 测试 | **JUnit 5 + Testcontainers + ArchUnit**；**Vitest**；**Playwright** |
| 部署 | **单容器**：SPA 打进 jar 的 `static/`，三阶段 Dockerfile + 分层 jar |

**版本上有两条不能凭直觉改**：

- **TypeScript 锁 6.0.x，不要升 7。** TS 7 已发布，但 `typescript-eslint` 的 peer 范围是 `>=4.8.4 <6.1.0`——升上去 `tsc` 照常跑，**lint 链会断**。升级前先确认 typescript-eslint 支持了。
- **Flyway / Testcontainers / Postgres 驱动 / Spring Session 不在 version catalog 里钉版本**，由 Spring Boot BOM 管。在 catalog 里覆盖它们等于让它们悄悄脱离你所在的 Boot 版本。要升就升 Boot。

## Boot 4 的包名陷阱（照抄 Boot 3 的代码会中招）

Boot 4 大改了坐标和包名。这些**编译期就报错**的还算好，最坏的是 Jackson 那条：

| 你以为 | 实际是 | 症状 |
|---|---|---|
| `spring-boot-starter-web` | **`spring-boot-starter-webmvc`** | 依赖解析失败 |
| `spring-boot-starter-test` | 按模块拆开：**`-webmvc-test` / `-data-jpa-test` / `-security-test` / `-flyway-test`** | 测试类编译失败 |
| `com.fasterxml.jackson.databind.ObjectMapper` | **`tools.jackson.databind.ObjectMapper`**（Jackson 3） | ⚠️ **编译通过、运行时 `No qualifying bean of type ObjectMapper`**——Jackson 2 还在 classpath 上（传递依赖），所以 import 是合法的，只是没人注册那个类型的 bean |
| `o.s.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc` | **`o.s.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc`** | 编译失败 |
| `org.testcontainers.containers.PostgreSQLContainer` | **`org.testcontainers.postgresql.PostgreSQLContainer`**（Testcontainers 2.x） | 编译失败 |

**不确定就去查真实坐标**（`start.spring.io` 生成一份对照，或翻 jar 里的包路径），别照记忆写。

## 禁止清单（最致命的先列）

**数据隔离（本轨第一红线）**：

- **repository 唯一允许的父接口是裸 `Repository<T, ID>`**——这是白名单，不是「除了 `JpaRepository`/`CrudRepository` 都行」的黑名单。黑名单必漏：`PagingAndSortingRepository` 自 Spring Data 3.0 起直接继承裸 `Repository`，照样白送 `findAll(Sort)` / `findAll(Pageable)`；`JpaSpecificationExecutor` / `QueryByExampleExecutor` 压根不是 `Repository` 子类型，混进来整张表都能捞。
- **手写的方法和继承的方法泄露程度相同**。挂在裸 `Repository` 上的 `findById(UUID)` 一样不带归属谓词。所以每个声明的方法要么在派生查询名里真的按 `ownerId` **过滤**，要么标 `@CrossUserQuery("理由")`（[`backend/index.md`](backend/index.md) §2）。
- **上面两条对每一个 repository 都成立，不只是每用户实体的那些。** 不带归属的表（字典、参考数据、配置）标 `@OwnerlessTable("理由")` 在**接口**上，别拿 `@CrossUserQuery` 逐个方法凑——那会把「真的跨用户读」这个信号淹掉。它只豁免方法级归属检查，**不豁免父接口白名单**，而且实体真带 `ownerId` 时会被拒（[`backend/index.md`](backend/index.md) §2.4）。
- 每张每用户表必须 `owner_id uuid not null references app_user(id)` + `owner_id` 索引 + **一条双账号负向测试**。
- 「不是你的」和「不存在」都回 **404**，不回 403——403 等于确认了那条记录存在。
- 跨用户读写走**显式登记的受控例外**（[`backend/index.md`](backend/index.md) §2.4）：标注在**方法**上，不许靠加方法或换更宽的父接口实现。
- **守卫本身要有反向测试**。失效的守卫和无事可抓的守卫都是绿的，看不出区别（[`testing/index.md`](testing/index.md)）。

**安全**：

- **任何密钥不得进 `VITE_*` 变量**——Vite 把 `VITE_` 前缀的值内联进浏览器包，等于公开发布。
- **不许关 CSRF**，也不许删 `SecurityConfig` 里 `setCsrfRequestAttributeName(null)` 那行（见 [`backend/index.md`](backend/index.md) §3）。
- 不在 `localStorage` 存会话凭证或 token（会话是 httpOnly cookie）。
- **session principal 里不许带凭据**——会话被序列化进 Postgres，带着密码哈希就是把它复制进第二张表（[`backend/index.md`](backend/index.md) §4.1）。
- 不提交 `.env`，不把密码/密钥写进 `application.yml` 或源码。**数据库口令不许有任何默认值**（连「看起来像开发值」的也不行）——漏配变量的启动路径会用那个公开已知的口令静默成功。注意「没有默认值」不等于「会失败」：占位符解析失败**不会**中止 Spring 启动，必须在 `main()` 里显式挡一道（[`database/index.md`](database/index.md) §5.2）。
- **开发用的容器端口只绑 `127.0.0.1`**，不要 `"5432:5432"`（那是 0.0.0.0）。
- **不许摘掉登录/注册的限流**（[`backend/index.md`](backend/index.md) §4.5）。BCrypt 是故意慢的，且注册在唯一索引裁决**之前**就已经哈希过了——没有限流，一台机器反复提交同一个已注册邮箱就能打满 CPU，而数据库全程空闲。
- **客户端地址只取 `getRemoteAddr()`，绝不信 `X-Forwarded-For`**——那是客户端自己写的，等于送攻击者无限身份。挂反代时改配 `server.forward-headers-strategy=native`，让 Tomcat 的 valve 去改写 `getRemoteAddr()`。
- **API 接受的输入必须是底下存储真能存的**（[`backend/index.md`](backend/index.md) §4.6）。校验不到位的失败点在写入之后：一半的记录已经落库，用户拿到 500。
- 授权一律在服务端；前端路由守卫只管渲染，不构成授权。
- 上了 TLS 就 `APP_COOKIE_SECURE=true`；生产 `APP_API_DOCS_ENABLED=false`。

**结构**：

- `spring.jpa.hibernate.ddl-auto` 只能是 **`validate`**，禁 `update` / `create-drop`。
- `spring.jpa.open-in-view` 保持 **false**。
- SQL 只出现在 `backend/src/main/resources/db/migration/`。
- 禁 `@ManyToMany`、禁 `FetchType.EAGER`；controller 不返回实体，只返回 DTO record。
- **不引入 Lombok**（注解处理器 + 与 record/JPA 的长期摩擦）。DTO 用 record，实体用普通类。
- 不手改生成文件：`V*__spring_session.sql`（抄自 jar）、`frontend/src/lib/api/schema.d.ts`（`pnpm api:types` 生成）。
- 前端所有后端调用经 ra-core 的 `dataProvider` / `authProvider`，**组件里不裸 `fetch`**，也不绕开 provider 直接 `useQuery`。
- 唯一性由**数据库约束**裁决，不由「先查存在再插入」裁决（[`backend/index.md`](backend/index.md) §4.2）。
- 引入新依赖（尤其重型库）前先问。

**工具与脚本**：

- **改工作树的脚本（改名、批量重写、数据迁移）必须先做完整 preflight**：所有校验通过之前不许写任何一个字节。半途失败留下的仓库既不是原样也不是目标态，比直接拒绝难收拾得多。注意「先写再判断有没有命中」等于没有 preflight——那是**边写边校验**。
- 脚本**永远不要 `rm -rf` 目标路径**来「腾地方」。目标已存在就是拒绝的理由，不是删除的理由——那可能是别人的代码。
- **同一条策略不要在两层各写一份守卫**。数据库口令若在 Gradle 的 `bootRun` 和应用的 `main()` 各判一次，两份规则必然漂移：应用接受 `SPRING_DATASOURCE_PASSWORD` 而 Gradle 不接受，用那个变量跑 `bootRun` 就会在 JVM 启动前被拒。**留在离事实最近的那一层**（这里是应用），另一层只负责把环境准备好。
- **注释声称的行为要和实际行为一致**。`node { download = false }` 只跳过 Node 下载，`pnpmSetup` 照样会 `npm install` 一个不受版本控制的 pnpm；写着「只用 PATH 上那个」而实际装了第二个，比没写注释更糟。改完用 `--info` 看一眼真实执行了什么。

> **怎么写好这类脚本不在本规范里。** preflight 的清单与范围、`perl -0ne` 与 `perl -pi` 对 `^`/`$` 的分歧、`trap ... EXIT` 会改写退出码、`find ... 2>/dev/null` 把权限失败连同错误一起吞掉、bash 3.2 的限制、要查**父目录**的 `write + execute` 而不是文件的 `-w`、幂等改名必须以**当前值**为基准——这些是 `scripts/init-project.sh` 这个**可执行工件**的教训，跟着工件走，写在 starter 仓的 `scripts/README.md` 里。本页只留上面那几条换个脚本也成立的。

## 目录结构（新增代码按此归位）

```
backend/src/main/java/<pkg>/
  config/      SecurityConfig（CSRF/会话/公共前缀）· SpaForwardConfig（深链）
  auth/        AppUser · AppUserRepository · AppUserPrincipal · AppUserDetailsService
               CurrentUserService（≈ requireUser()）· AuthController · AuthProperties
  <功能>/      实体 · Repository（归属收口）· Service · Controller · Dtos（record）
  common/      ApiExceptionHandler（RFC 9457 ProblemDetail）· NotFoundException · ConflictException
               CrossUserQuery（方法级例外）· OwnerlessTable（接口级：这张表没有归属）
backend/src/main/resources/
  application.yml
  db/migration/V*.sql          # 唯一写 SQL 的地方
backend/src/test/java/<pkg>/
  support/ApiIntegrationTest   # 带 cookie 的 MockMvc 基类 + Testcontainers
  architecture/                # ArchUnit：归属收口
  <功能>/                       # 含 *OwnershipIsolationTest（负向）
  TestcontainersConfiguration · DatabasePasswordGuardTest   # 跨模块的，放包根
frontend/src/
  lib/api/                     # dataProvider（唯一数据出口：CSRF 头 + 错误归一化）
                               # authProvider（唯一认证出口）· schema.d.ts（生成，勿手改）
  lib/{status,utils}.ts
  components/ui/               # shadcn 基础件，勿手改（用 CLI 加）
  components/admin/            # shadcn-admin-kit 的 List/Edit/Create 封装
  components/{data,forms,app}/ # patterns 层（上面两层都没有的那部分）
  routes/                      # 页面
  styles/globals.css           # 视觉唯一真源：Tailwind v4 的 @theme
  app.tsx  main.tsx  assets/fonts/
design-system/MASTER.md        # 全站 UI 视觉权威
CONTEXT.md                     # 术语表（domain-modeling 维护，唯一宿主）
docs/
  adr/NNNN-*.md                # 有取舍的决定（唯一宿主）
  discovery/prd.md             # 完整 PRD（需求与验收的唯一宿主）
  discovery/slices.md          # 切片地图：阶段目标 / 切片清单 / frontier
  releases/vX.Y.Z.md           # 逐版本发布说明 + 验收清单
scripts/
  README.md                    # 改工作树的脚本怎么写（preflight、bash 3.2、权限位…），本规范不复述
  init-project.sh              # 新项目第一步：改名（否则共享数据卷，见 database §5）
  test-init-project.sh         # 上面那个脚本的拒绝路径与零写入验收
gradle/libs.versions.toml      # 后端版本唯一钉版处（哪些故意不钉见「栈锁定」）
Dockerfile
docker-compose.dev.yml         # 本地开发库（只绑 127.0.0.1）
docker-compose.yml             # 只有应用，没有数据库
docker-compose.override.yml    # 自带库；不写 -f 时 compose 自动加载
docker-compose.external-db.yml # 外部库；显式 -f 会连带抑制上面那个 override
.github/workflows/{ci,release}.yml
```

> **数据库为什么不写在 `docker-compose.yml` 里**：compose **先逐文件插值、再合并**。自带库的 `${POSTGRES_PASSWORD:?…}` 只要写在基础文件里，外部库那条路径也会去解析它——为一个自己根本不启动的数据库要口令，整个 deploy 失败。把它挪进 override 之后，两种模式各自只解析自己用到的变量。注意 `deploy: replicas: 0` **不解决这个问题**：插值发生在任何 override 生效之前。

> **`lib/api/` 内部怎么分文件待实跑确认。** 已定的是职责：后端调用一律经 `dataProvider`，认证经 `authProvider`，`schema.d.ts` 由 `pnpm api:types` 生成。

> **实现规格不进 `docs/`**——它随 task 住在 `.trellis/tasks/<task>/prd.md`。集中预先穷举的那份必然先于代码腐化。

## 锁死 vs 放手

**锁死，改动先问**：栈、目录、归属收口方式、鉴权与 CSRF、迁移方式、部署形态。

**放手，直接改**：单个页面的布局、文案、组件选用、业务字段。

## 已知取舍（本轨默认不做，真实项目要自己判断）

写在这里是因为**沉默会被当成背书**：默认实现里没有的东西，下一个人会默认「这条轨不需要它」。

- **写路径默认是无条件 last-write-wins**，没有版本列、`@Version`、ETag 或条件更新。实体单人所有时，冲突只可能出现在同一用户的两个标签页之间，默认不为它付这份复杂度。**但凡你的实体会被多人同时编辑，就必须上乐观锁**：加版本列 + `@Version`，请求带上版本（或 `If-Match`），不匹配返回 409/412，并配并发事务与陈旧表单测试。**沿用默认**等于把「后提交者静默覆盖」带进一个它不再安全的场景。
- **限流是进程内的**，两个实例就是两份额度（[`backend/index.md`](backend/index.md) §4.5）。单实例部署下这是诚实的取舍——不用多跑一个 Redis——但横向扩容后要换成共享存储的桶。
- **没有二次验证 / 人机挑战**。所以按账号的限流有一份残余风险，写在 §4.5 里，不许假装它不存在。

## 本轨规范索引

每个 `<layer>/index.md` 都带 Trellis 约定的 **Pre-Development Checklist** 与 **Quality Check** 两节（`workflow.md` 会按这个约定去读）。

**轨特化（这条轨专有）**：

| 文件 | 管什么 |
|---|---|
| [`backend/index.md`](backend/index.md) | 分层与数据读写、**归属收口**、鉴权与会话、CSRF、JPA 禁止项、SPA 深链、异构子服务 |
| [`database/index.md`](database/index.md) | Flyway 流程、**新表三件套**、`ddl-auto=validate`、生成的迁移不手改、本地卷名陷阱 |
| [`frontend/index.md`](frontend/index.md) | API 调用收口、组件复用顺序、Hooks、表单、主题与视觉、可访问性 |
| [`testing/index.md`](testing/index.md) | 质量门命令、怎么验证（含两条负向测试）、Testcontainers、E2E 必须跑在打包产物上 |

**轨无关（换技术栈也成立，随本模板一起装）**：

| 文件 | 管什么 |
|---|---|
| [`guides/index.md`](guides/index.md) | guides 总入口 |
| [`guides/code-reuse.md`](guides/code-reuse.md) | 写新代码前先找既有实现的顺序 |
| [`guides/cross-layer.md`](guides/cross-layer.md) | 跨层职责判据（含「校验散落各层」） |
| [`guides/review-adjudication.md`](guides/review-adjudication.md) | 编码期 finding 的 4 字段、召回与裁决分离 |

> `guides/` 在框架仓里是**生成副本**，权威源是 `specs/universal/guides/`，由 `scripts/sync-spec-guides.sh` 同步。**改 guides 要去改权威源**——直接改这里下次同步就被覆盖（框架仓的 CI 会先报出来）。

## 与 starter AGENTS.md 的关系

**同一套规则目前存在两处**：本目录，与 starter 仓 `java-stack/AGENTS.md`。这是临时状态。

- **本目录是权威源**，跟着框架仓维护、经 Trellis 按需注入。
- starter 的 `AGENTS.md` 只保留「项目信息 + 指向本规范 + 最致命的那几条红线」，且它们必须是本页禁止清单的**严格子集**，分组也与本页一致（数据隔离 / 安全 / 结构）。**下放的判据**：不走 Trellis 的 session 读不到按需注入的 spec，而这条破了会出真事故。不满足这条判据的规则留在本页，不下放。
- **不要把这份子集写成固定枚举。** 两边的清单都会长，枚举一旦落后，读的人会按枚举判定 starter「超范围」，而它其实只是又下放了一条同样致命的规则。核对方式是**逐条回本页禁止清单找对应项**——找不到对应项才是违规。
- 改规则**先改本目录**，再同步回 starter。反向改会漂移。

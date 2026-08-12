# Java Stack 轨 · 规范总览

> 本文件是 spec 根总览（对应官方模板的 `.trellis/spec/README.md`）。各层入口在 `<layer>/index.md`，轨无关思维清单在 `guides/`。

> Spring Boot 4 + Postgres + React 轨的编码规范。装进项目后位于 `.trellis/spec/`，由 Trellis 按需注入。
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

## 这条轨和 Web Fullstack 轨最大的区别

**没有 RLS。**

Supabase 轨的每用户数据隔离由数据库兜底：策略写在表上，应用怎么问都拿不到别人的行——**fail-closed**。这条轨没有那层东西。隔离就是查询里带的那个 `owner_id` 谓词，**fail-open**：漏了不会报错，会返回 200 和别人的数据，日志里什么都没有。

所以本轨把那一层**重新造了一遍**，用三样机器能验的东西代替一条人要记住的纪律。完整定义在 [`backend/index.md`](backend/index.md) §2，**只在那里定义一次**。这是本轨最重的一节，其余都是常规工程。

## 栈锁定（不经确认不得替换）

| 层 | 锁定 |
|---|---|
| 语言 / 运行时 | **Java 25 LTS**（Gradle toolchain 自动下载用于编译） |
| 框架 | **Spring Boot 4.1.x**（Spring Framework 7） |
| 构建 | **Gradle 9 + Kotlin DSL** + version catalog（`gradle/libs.versions.toml`） |
| 数据库 | **Postgres 17** + **Flyway**（纯 SQL 迁移） |
| ORM | **Spring Data JPA / Hibernate 7** |
| 鉴权 | **Spring Security** + **Spring Session JDBC**（会话存 Postgres），**不用 JWT** |
| API 文档 | **springdoc-openapi 3.x** → `/v3/api-docs` → 前端类型 |
| 前端 | **Vite 8 + React 19 + TypeScript 6 + Tailwind v4 + shadcn/ui（Base UI 内核，`base-nova`，neutral）** |
| 前端路由 / 状态 | **React Router 8**（declarative）+ **TanStack Query 5** |
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

- **owner-scoped 的 repository 不得 extend `JpaRepository` / `CrudRepository`**——一律 extend 裸 `Repository<T, ID>`，只声明带 `ownerId` 的方法。继承来的 `findById` / `findAll` / `deleteById` 不带归属谓词，误用即静默泄漏。
- 每张每用户表必须 `owner_id uuid not null references app_user(id)` + `owner_id` 索引 + **一条双账号负向测试**。
- 「不是你的」和「不存在」都回 **404**，不回 403——403 等于确认了那条记录存在。
- 跨用户读写走**显式登记的受控例外**（[`backend/index.md`](backend/index.md) §2.4），不许靠给 repository 加方法实现。

**安全**：

- **任何密钥不得进 `VITE_*` 变量**——Vite 把 `VITE_` 前缀的值内联进浏览器包，等于公开发布。
- **不许关 CSRF**，也不许删 `SecurityConfig` 里 `setCsrfRequestAttributeName(null)` 那行（见 [`backend/index.md`](backend/index.md) §3）。
- 不在 `localStorage` 存会话凭证或 token（会话是 httpOnly cookie）。
- **session principal 里不许带凭据**——会话被序列化进 Postgres，带着密码哈希就是把它复制进第二张表（[`backend/index.md`](backend/index.md) §4.1）。
- 不提交 `.env`，不把密码/密钥写进 `application.yml` 或源码。**数据库口令不许有任何默认值**（连"看起来像开发值"的也不行）——漏配变量的启动路径会用那个公开已知的口令静默成功。注意「没有默认值」不等于「会失败」：占位符解析失败**不会**中止 Spring 启动，必须在 `main()` 里显式挡一道（[`database/index.md`](database/index.md) §5.2）。
- **开发用的容器端口只绑 `127.0.0.1`**，不要 `"5432:5432"`（那是 0.0.0.0）。
- 授权一律在服务端；前端路由守卫只管渲染，不构成授权。
- 上了 TLS 就 `APP_COOKIE_SECURE=true`；生产 `APP_API_DOCS_ENABLED=false`。

**结构**：

- `spring.jpa.hibernate.ddl-auto` 只能是 **`validate`**，禁 `update` / `create-drop`。
- `spring.jpa.open-in-view` 保持 **false**。
- SQL 只出现在 `backend/src/main/resources/db/migration/`。
- 禁 `@ManyToMany`、禁 `FetchType.EAGER`；controller 不返回实体，只返回 DTO record。
- **不引入 Lombok**（注解处理器 + 与 record/JPA 的长期摩擦）。DTO 用 record，实体用普通类。
- 不手改生成文件：`V*__spring_session.sql`（抄自 jar）、`frontend/src/lib/api/schema.d.ts`（`pnpm api:types` 生成）、`frontend/src/components/ui/*`（shadcn 生成）。
- 前端所有后端调用经 `frontend/src/lib/api/client.ts`，**组件里不裸 `fetch`**。
- 唯一性由**数据库约束**裁决，不由「先查存在再插入」裁决（[`backend/index.md`](backend/index.md) §4.2）。
- 引入新依赖（尤其重型库）前先问。

**工具与脚本**：

- **改工作树的脚本必须先做完整 preflight**：所有校验通过之前不许写任何一个字节。半途失败留下的仓库既不是模板也不是新项目，比直接拒绝难收拾得多。
  - 注意「先写再判断有没有命中」等于没有 preflight——那是**边写边校验**。校验必须**在改写之前**跑完，包括「每个文件都在」「每条模式都命中（或已是目标态）」「每个要写的文件可写」。
  - 校验用的正则和改写用的正则**必须语义一致**。`perl -0ne`（整文件）与 `perl -pi`（逐行）对 `^`/`$` 的理解不同，不加 `/m` 就会把好好的仓库判成漂移。
  - **要创建的路径，每一级祖先都要校验**，不只是最终目标。只查 `a/b/c` 存不存在，而 `a/b` 是个普通文件时，`mkdir` 会在 apply 阶段才失败——那时前面的改写已经落盘了。
  - **权限要查父目录的 `write + execute`，不是文件本身的 `-w`**。`perl -pi` 是在同目录写临时文件再改名，`mv` 是把条目从父目录里摘掉——两者真正需要的都是**父目录**可写可进入。文件可写而父目录只读时，检查通过、执行失败。要查三处：每个待改写文件的父目录、包移动的**源**父目录、目标路径最深的现有父目录。
  - **每一处改写都必须进那张统一表**。留在 apply 阶段"顺手跑一下"的固定正则不会经过模式 preflight：给 `group = "com.example"` 加个行尾注释，脚本照样 exit 0、包目录已移动，而 group 没改。
  - **脚本要能在 bash 3.2 上跑**（macOS 的 `/bin/bash`）。`declare -A`、`mapfile`、`${var^^}` 都是 bash 4+ 的，写了在 Linux 上测不出来，到 Mac 上直接语法错误。
- **不要用 `find ... 2>/dev/null` 生成待处理清单。** 它把权限失败连同错误信息一起吞掉，返回一份**短清单加一个成功状态**——preflight 看着通过，读不到的文件从此不在计划内。要检 `find` 的退出码，并让它的 stderr 可见（`Permission denied: <path>` 就是诊断本身）。
  - 退出码也**不便携**：不同 find 实现对「缺 `+x` 的目录」反应不同（这台机器上的 `bfs` 直接走了进去还 exit 0）。所以再逐个目录检查 `-r` / `-x` 权限位——`perl -pi` 在缺 `+x` 的目录里一定失败，跟 find 怎么想无关。
  - **apply 阶段复用 preflight 验证过的那份清单**，不要再 `find` 一次（process substitution 里的失败传不出来）。顺序上把「不依赖路径的改写」（如包声明）放在 `mv` **之前**，清单里的路径就一直有效，省掉旧路径到新路径的重映射。
- **`trap ... EXIT` 里最后一条命令的返回值会成为脚本的退出码。** `cleanup() { [[ -n "$f" ]] && rm -f "$f"; }` 在变量为空时返回 1，于是一次干净的「无事可做」变成了失败退出。trap 函数末尾显式 `return 0`。
- **幂等的改名要以「当前值」为基准，不能硬编码原始值**。从权威处（如 `settings.gradle.kts` 的 `rootProject.name`）读出当前名再替换。硬编码模板名看起来等价，直到新名**包含**旧名：把项目改名成 `java-stack-demo` 再跑一次，`java-stack` 仍然匹配到已改名值内部，于是变成 `java-stack-demo-demo`。以当前值为基准顺带还能支持「改完再改成第三个名字」。
- **同一条策略不要在两层各写一份守卫**。曾经 Gradle 的 `bootRun` 和应用的 `main()` 各判一次数据库口令，规则却不一样——应用接受 `SPRING_DATASOURCE_PASSWORD`，Gradle 不接受，于是用那个变量跑 `bootRun` 会在 JVM 启动前被拒。两份规则必然漂移；**留在离事实最近的那一层**（这里是应用），另一层只负责把环境准备好。
- 脚本**永远不要 `rm -rf` 目标路径**来"腾地方"。目标已存在就是拒绝的理由，不是删除的理由——那可能是别人的代码。
- **注释声称的行为要和实际行为一致**。`node { download = false }` 只跳过 Node 下载，`pnpmSetup` 照样会 `npm install` 一个不受版本控制的 pnpm；写着"只用 PATH 上那个"而实际装了第二个，比没写注释更糟。改完用 `--info` 看一眼真实执行了什么。

## 目录结构（新增代码按此归位）

```
backend/src/main/java/<pkg>/
  config/      SecurityConfig（CSRF/会话/公共前缀）· SpaForwardConfig（深链）
  auth/        AppUser · AppUserRepository · AppUserPrincipal · AppUserDetailsService
               CurrentUserService（≈ requireUser()）· AuthController · AuthProperties
  <功能>/      实体 · Repository（归属收口）· Service · Controller · Dtos（record）
  common/      ApiExceptionHandler（RFC 9457 ProblemDetail）· NotFoundException · ConflictException
backend/src/main/resources/
  application.yml
  db/migration/V*.sql          # 唯一写 SQL 的地方
backend/src/test/java/<pkg>/
  support/ApiIntegrationTest   # 带 cookie 的 MockMvc 基类 + Testcontainers
  architecture/                # ArchUnit：归属收口
  <功能>/                       # 含 *OwnershipIsolationTest（负向）
  TestcontainersConfiguration · DatabasePasswordGuardTest   # 跨模块的，放包根
frontend/src/
  lib/api/client.ts            # 唯一出口：CSRF 头 + 错误归一化
  lib/api/schema.d.ts          # 生成，勿手改
  lib/api/<功能>.ts             # endpoint + TanStack Query hooks
  lib/{status,utils}.ts
  components/ui/               # shadcn，只用 CLI 增删
  components/{data,forms,app}/ # patterns 层
  routes/                      # 页面
  app.tsx  main.tsx  styles/globals.css  assets/fonts/
design-system/MASTER.md        # 全站 UI 视觉权威
docs/
  discovery/brief.md           # 产品简报（产品全貌的唯一宿主）
  discovery/wireframe/<片>/     # 逐切片低保真骨架，final/ 冻结
  releases/vX.Y.Z.md           # 逐版本发布说明 + 验收清单
scripts/
  init-project.sh              # 新项目第一步：改名（否则共享数据卷，见 database §5）
  test-init-project.sh         # 上面那个脚本的拒绝路径与零写入验收
gradle/libs.versions.toml      # 后端版本唯一钉版处（哪些故意不钉见「栈锁定」）
Dockerfile  docker-compose{,.dev,.external-db}.yml
.github/workflows/{ci,release}.yml
```

> **实现规格不进 `docs/`**——它随 task 住在 `.trellis/tasks/<task>/prd.md`。集中预先穷举的那份必然先于代码腐化。

## 锁死 vs 放手

**锁死，改动先问**：栈、目录、归属收口方式、鉴权与 CSRF、迁移方式、部署形态。

**放手，直接改**：单个页面的布局、文案、组件选用、业务字段。

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

**同一套规则目前存在两处**：本目录，与 starter 仓 `java-stack/AGENTS.md`。这是已知的临时状态，不是设计意图。

- **本目录是权威源**，跟着框架仓维护、经 Trellis 按需注入。
- starter 的 `AGENTS.md` 只保留「项目信息 + 指向本规范 + 最致命的那几条红线」，且它们必须是本页禁止清单的**严格子集**，分组也与本页一致（数据隔离 / 安全 / 结构）。**下放的判据**：不走 Trellis 的 session 读不到按需注入的 spec，而这条破了会出真事故。不满足这条判据的规则留在本页，不下放。
- **不要把这份子集写成固定枚举。** 两边的清单都会长，枚举一旦落后，读的人会按枚举判定 starter「超范围」，而它其实只是又下放了一条同样致命的规则。核对方式是**逐条回本页禁止清单找对应项**——找不到对应项才是违规。
- 改规则**先改本目录**，再同步回 starter。反向改会漂移。

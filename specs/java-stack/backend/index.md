# 后端与鉴权规范 · Java Stack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；迁移与建表见 [`../database/index.md`](../database/index.md)。

## 速查

| 操作 | 唯一做法 |
|---|---|
| 读写用户数据 | Service 方法**第一个参数是 `ownerId`**，经只暴露归属方法的 Repository |
| Repository 基类 | 裸 `Repository<T, ID>`，**绝不** `JpaRepository` / `CrudRepository` |
| 「不是我的」 | 回 **404**（不是 403） |
| 当前用户 | `CurrentUserService.requireUserId()`，只在 controller 调一次往下传 |
| 会话 | Spring Session JDBC（存 Postgres），httpOnly cookie，**不用 JWT** |
| 写接口 | `@RestController` + DTO record + `@Valid`；错误经 `ProblemDetail` |
| schema 变更 | 只加 Flyway 迁移；`ddl-auto` 永远是 `validate` |

## 1. 分层

`Controller`（HTTP + 取当前用户）→ `Service`（业务 + 事务）→ `Repository`（归属收口）→ DB。

- **Controller 不碰 Repository**，Service 不碰 `HttpServletRequest`。
- **实体不出 Service**：controller 只收发 DTO record。返回实体会把 JPA 的加载行为拖进序列化，并让 API 契约跟着表结构漂。
- `@Transactional(readOnly = true)` 放类上，写方法单独覆盖 `@Transactional`。

## 2. 归属收口（本轨最重的一节）

**先说清楚为什么需要它。** Supabase 轨的隔离是数据库给的：RLS 让「拿到别人的行」在物理上做不到。这条轨没有那层。这里的隔离只是查询里那个 `owner_id = ?`，而漏掉它**没有任何症状**——返回 200、返回数据、日志干净、测试全绿。它只在某天有人发现能看到别人的东西时才被发现。

一条要靠人每次记得的纪律，等于没有纪律。所以拆成三件机器能验的事：

### 2.1 结构性收口：危险方法不存在

owner-scoped 实体的 repository **extend 裸 `Repository<T, ID>`**，只声明带 `ownerId` 的方法：

```java
public interface NoteRepository extends Repository<Note, UUID> {
    List<Note> findAllByOwnerIdOrderByUpdatedAtDesc(UUID ownerId);
    Optional<Note> findByIdAndOwnerId(UUID id, UUID ownerId);
    @Transactional long deleteByIdAndOwnerId(UUID id, UUID ownerId);
    Note saveAndFlush(Note note);
}
```

`JpaRepository` 会白送 `findById` / `findAll` / `deleteById` / `existsById`——全都不带归属，全都在自动补全的第一屏。**不继承它，那些方法就不存在**，写不出错误的调用。

> 写方法声明的是 `saveAndFlush` 而不是 `save`，这是照抄这段模板时最容易漏掉的一处：`save` 把 flush 推迟到事务提交，那时 controller 早已把实体映射成了响应，于是写操作返回的是**改之前**的时间戳。理由与验收见 §4.3。

> 这不是风格偏好。`extends JpaRepository` 是所有人下意识会打的那行字，而它把泄漏入口默认打开。

### 2.2 机器强制：ArchUnit

```java
noClasses().that().areInterfaces().and().areAssignableTo(Repository.class)
    .should().beAssignableTo(CrudRepository.class)
```

放在 `architecture/RepositoryChokePointTest`，跟着 `./gradlew check` 跑。**验证这条测试本身有效**：把某个 repository 改成 `extends JpaRepository<T, ID>`，它必须变红。

### 2.3 负向测试：双账号

见 [`../testing/index.md`](../testing/index.md)「怎么验证」第 2 条。要点：**A 的资源 id 用 B 的身份去够，必须 404**；并且要断言 **A 的数据还在**（否则一个「返回 404 但其实删掉了」的实现也能骗过前面的断言）。

正向用例全绿证明不了隔离——它们从来没试过越权。

### 2.4 受控例外：跨用户读写

**这是本轨唯一登记的例外，范围只在本节定义。** 别处需要跨用户访问时不要照抄结论，回来读这张表。

管理员视图 / 后台任务确实需要跨用户读时：

| 允许 | 禁止 |
|---|---|
| 建一个**显式命名**的 service（如 `AdminNoteQueryService`），方法名自带 admin 语义 | 给业务 repository 加 `findById` / `findAll` |
| 在那个 service 里做**显式的权限判断**（当前用户是不是管理员），判断写在方法入口 | 以「调用方已经校验过了」为由跳过 |
| 为它单独建一个 repository 接口，同样只声明它真正需要的方法 | 让业务代码顺手复用这个 admin 通道 |

**验收是负向的**：普通账号调那个 admin 端点必须被拒。写了角色判断 ≠ 生效。

## 3. CSRF：那一行不能删

会话是 cookie，所以 CSRF 防护必须开。配置长这样：

```java
CsrfTokenRequestAttributeHandler handler = new CsrfTokenRequestAttributeHandler();
handler.setCsrfRequestAttributeName(null);   // ← 这一行
http.csrf(csrf -> csrf
        .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
        .csrfTokenRequestHandler(handler));
```

**`setCsrfRequestAttributeName(null)` 是干什么的**：Spring Security 6+ 默认**延迟**加载 CSRF token——没人读它就不生成，不生成就不下发 `XSRF-TOKEN` cookie。前端拿不到 token，于是每个写请求都 403。

**为什么会看错方向**：403 长得像权限问题。人会去翻 `authorizeHttpRequests`、翻角色、翻会话，而问题在一个跟授权无关的地方。

前端侧：`X-XSRF-TOKEN` 头由 `frontend/src/lib/api/client.ts` 统一加，**不在调用点各写各的**。首个 token 由页面挂载时的 `GET /api/auth/me` 带下来。

## 4. 鉴权与会话

- **Spring Session JDBC**：会话存 Postgres。重启不掉线、多实例共享，不需要粘性会话。
- 会话表由 **Flyway** 建（`spring.session.jdbc.initialize-schema=never`），schema 从 spring-session-jdbc jar 里抄，见 [`../database/index.md`](../database/index.md) §3。
- **登录**在 `AuthController` 里显式做（`AuthenticationManager.authenticate` → `saveContext`），因为客户端发 JSON；**登出交给框架的 logout filter**，会话失效这种事不要手写。
- **会话固定防护**：登录成功后，若登录前已存在会话，必须 `request.changeSessionId()`。手写登录就等于接管了这件事。
- **不用 JWT**。要无状态时再谈，别默认引入 refresh token 那一整套。
- **cookie 名按项目改**（`server.servlet.session.cookie.name`）。默认 `JSESSIONID` 在 localhost 上被所有应用共享——两个项目同时开发会互相顶掉登录。`scripts/init-project.sh` 会改。
- **禁自助注册但保留登录**：`app.auth.signup-enabled=false`。只关注册端点，已有用户照常登录——别去关整个认证通道。
- 登录失败的文案对「邮箱不存在」和「密码错」**必须一致**，否则登录接口成了账号枚举器。

### 4.1 会话里不许有凭据

session principal **必须实现 `CredentialsContainer` 并在 `eraseCredentials()` 里清掉密码哈希**。

**为什么这条在本轨特别重要**：会话存在 Postgres，principal 会被 Java 序列化进 `spring_session_attributes.attribute_bytes`。principal 里带着 `passwordHash`，就等于把 `app_user.password_hash` 每登录一次复制一份到另一张表——那张表行数只增、活得比这次登录久、且任何能读库的东西都能读到。一个被小心保管的列，被复制成了一堆不被保管的行。

`ProviderManager` 默认在认证成功后调 `eraseCredentials()`，但**只有 principal 实现了那个接口才生效**——不实现不会有任何报错，只是悄悄不擦。

**验收只能看字节**：查 `spring_session_attributes`，断言 `app_user.password_hash` 的字节串不出现在任何一条 `attribute_bytes` 里。断言「调用了 eraseCredentials」是没用的——要证明的是存进去的东西里没有它。

### 4.2 唯一性由约束裁决，不由 exists 检查裁决

「先查在不在，再插入」是 TOCTOU：两个并发请求都通过了检查，第二条插入撞上唯一索引，调用方拿到 **500**。

**500 的坏处不只是难看**：它和「服务器坏了」无法区分，所以没人会把它当成竞态去查。

正确做法是**去掉前置检查**，让唯一索引做唯一裁决，把约束冲突翻译成 409：

```java
try {
    users.saveAndFlush(new AppUser(email, encoded));
} catch (DataIntegrityViolationException alreadyTaken) {
    throw new ConflictException("That email is already registered.");
}
```

注意 `saveAndFlush`：不 flush 的话，冲突要到事务提交时才抛，那已经在 try 之外了。

顺带的好处：去掉前置检查之后，冲突路径变成**确定性可测**的（顺序跑两次即可），不用靠并发测试撞运气。并发测试仍然值得补一条，但它是加固，不是唯一的覆盖手段。

### 4.3 写操作的响应必须反映这次写

`@PreUpdate` / `@PrePersist` 在 **flush** 时才跑，而 service 通常在那之前就把实体映射成了 DTO —— 于是 `PUT` 返回的是**改之前**的 `updatedAt`，要再 `GET` 一次才看得到新值。

依赖响应做乐观更新、ETag、「最后保存于」的客户端会直接显示错数据，而这个 bug 在「功能跑通了」的测试里完全看不出来。

**做法**：写路径用 `saveAndFlush` 再映射，让生命周期回调成为时间戳的**唯一**来源。

> 不要改成「在 `edit()` 里也盖一个时间戳」——那样会有两个来源，响应里的值和库里的值差几十微秒，更难查。

**验收**：断言 `PUT` 响应的 `updatedAt` 严格晚于创建值，**并且**紧接着的 `GET` 与它完全相等。只断言前者的话，两个时间戳来源的写法也能通过。

### 4.4 时间戳截断到微秒（又一条本地测不出来的）

盖时间戳时一律 `Instant.now().truncatedTo(ChronoUnit.MICROS)`。

`timestamptz` 只存到**微秒**，而 `Instant.now()` 在 Linux 上给的是**纳秒**。于是内存里的值和从库里读回来的值末几位不同——写操作的响应和随后一次读**不字节相等**，任何拿时间戳做相等判断的客户端（ETag、「变了没」、乐观并发）都会误判。

**为什么它能溜过测试**：macOS 的 `Instant.now()` 本来就只有微秒精度，所以在开发机上两边天然相等，测试全绿；只有跑在 Linux 容器里才分叉。**这条是在容器里手工核对时发现的，不是测试发现的** —— 所以「写完在容器里真的对一次」这一步不能省。

## 5. SPA 深链与后端路径

SPA 打进 jar，所以 Spring 要为客户端路由兜底：未命中的非后端路径一律 forward 到 `index.html`。

**这个坑在开发环境永远复现不了**：Vite dev server 自带 history fallback，dev 下深链一切正常；只有打包后的 jar 里，刷新 `/notes/<id>/edit` 才 404。所以 E2E 必须跑在打包产物上（[`../testing/index.md`](../testing/index.md)）。

**反过来的坑同样真实**（实战踩过）：兜底必须**排除后端拥有的前缀**——`api/`、`actuator/`、`v3/api-docs`、`swagger-ui`。否则一个关掉的或拼错的后端路径会返回 **200 + 一整页 HTML**：抓 `/v3/api-docs` 生成前端类型的工具会下载到 HTML，然后在离原因很远的地方炸掉。**新挂一个后端路径，就往那个排除列表里加一条。**

## 6. JPA 禁止项（每条都对应一类静默故障）

| 规则 | 不守会怎样 |
|---|---|
| `ddl-auto: validate`，禁 `update` / `create-drop` | Hibernate 悄悄改表，schema 与迁移分叉；换台机器重放迁移行为就不一样 |
| `open-in-view: false` | 懒加载会在渲染阶段触发，本地正常、压力下 N+1，且堆栈离肇事代码很远 |
| 禁 `@ManyToMany` | 隐藏中间表，没法加字段，级联行为难推理 |
| 禁 `FetchType.EAGER` | 每次查询都拖一串关联，改一处影响全局 |
| 读多字段走 DTO 投影 / `@Query` | 返回实体会把加载行为拖进序列化 |
| 归属列用 `UUID ownerId` 而不是 `@ManyToOne` | 关联会在每次读列表时把用户也拖出来；这个列只是过滤条件 |
| 实体的 `equals`/`hashCode` 不要基于可变字段 | 进了集合之后行为不可预测 |

## 7. 服务端校验的位置

Bean Validation（`@Valid` + record 上的约束）在 controller 边界做，错误经 `ApiExceptionHandler` 变成 `ProblemDetail`，前端渲染 `detail` 字段。

但这**不代表**其余层可以无条件信任：

- **授权必须在服务端执行**——前端隐藏入口、路由守卫都不算授权。
- **数据不变量由数据库兜底**（NOT NULL、外键、唯一约束）——并发请求、后台任务、迁移脚本都不经过 controller。

判据见 [`../guides/cross-layer.md`](../guides/cross-layer.md) 的「校验散落各层」。

## 8. 异构子服务

**什么时候需要**：产品有「重执行」的一侧（SSH 部署、调目标系统内部 API、重计算），不适合塞进 web 进程。

**什么时候不需要**：能在 service 里同步做完的就别拆。拆的代价是多一套部署、多一条信任边界、多一份版本对齐。

**标准模式**：`services/<svc>/` 自带 `AGENTS.md` + `CLAUDE.md`（根 `CLAUDE.md` 的 import 不会钻进子目录）；经 HTTP(Bearer) 下发任务；单独一份 compose 文件。

**信任边界**：共享 Bearer 只证明「调用方是我们的服务」，**不证明这次调用属于哪个用户**。所以 worker 的入参只有 job id，job 的归属在创建时由用户作用域的路径钉死；worker 要读的每一张用户表都经过**显式校验归属**的查询，不按外部传入的主键取数。验收同样是负向的：拿 A 的 job 去够 B 的资源必须被拒。

---

## Pre-Development Checklist

- [ ] 这次要建的 repository，extend 的是**裸 `Repository`** 吗？有没有手滑写成 `JpaRepository`？
- [ ] 往 session principal 里加字段了吗？它会被序列化进数据库——凭据、令牌、密钥一律不许进（§4.1）
- [ ] 有「先查存在再插入」的地方吗？改成让唯一索引裁决 + 翻译成 409（§4.2）
- [ ] 写接口的响应里有时间戳/版本号吗？映射前 flush 了吗（§4.3）
- [ ] 新增的每个查询方法都带 `ownerId` 吗？说不出归属谓词在哪就是没做
- [ ] 「不是你的」这条路径回的是 **404** 而不是 403？
- [ ] 要跨用户读数据吗？**默认不允许**——确需破例走 §2.4 的受控例外，并配负向验收
- [ ] 新增路由需要登录吗？公共前缀只有 `/api/auth/login` `/api/auth/signup`
- [ ] 挂了新的后端路径吗？记得加进 SPA 兜底的排除列表（§5）
- [ ] 改了 schema 吗？只加 Flyway 迁移，`ddl-auto` 不动
- [ ] 从网上抄了 Boot 3 的代码吗？先对一遍 [`../README.md`](../README.md) 的包名陷阱表（尤其 Jackson 3）
- [ ] 要拆异构子服务吗？先问能不能在 service 里同步做完（§8）

## Quality Check

```bash
./gradlew spotlessCheck check
```

额外自检：

- [ ] `ArchUnit` 那条仍然绿（说明没有 repository 偷偷继承了 `CrudRepository`）
- [ ] 新的每用户表配了**双账号负向测试**，且断言了「另一个账号的数据没被改动」
- [ ] 没有把实体直接返回给 controller
- [ ] 没有新增 `@ManyToMany` 或 `EAGER`
- [ ] 密钥没有出现在 `application.yml`、源码或任何 `VITE_*` 变量里

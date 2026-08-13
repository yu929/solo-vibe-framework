# 后端与鉴权规范 · Java Stack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；迁移与建表见 [`../database/index.md`](../database/index.md)。

## 速查

| 操作 | 唯一做法 |
|---|---|
| 读写用户数据 | Service 方法**第一个参数是 `ownerId`**，经只暴露归属方法的 Repository |
| Repository 基类 | **只能是**裸 `Repository<T, ID>`，**每一个 repository 都是**（白名单：其它父接口一律不行，包括 `PagingAndSortingRepository` 和混入 `JpaSpecificationExecutor`） |
| Repository 方法 | 名字里真的按 `ownerId` 过滤，否则标 `@CrossUserQuery("理由")`——**标方法，不标接口** |
| 表根本没有归属列 | 接口上标 `@OwnerlessTable("理由")`（§2.4），**不是**给每个方法套 `@CrossUserQuery` |
| 「不是我的」 | 回 **404**（不是 403） |
| 公开且昂贵的端点 | 限流：按地址 + 按账号两份额度，**验证前**原子预留（§4.5） |
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

一条要靠人每次记得的纪律，等于没有纪律。所以拆成几件机器能验的事：**危险方法不存在**（§2.1）、**机器每次构建都检查**（§2.2）、**双账号负向测试证明它真的成立**（§2.3），以及**守卫本身还咬得动**（§2.5）。

### 2.1 结构性收口：危险方法不存在

**每一个** repository **extend 裸 `Repository<T, ID>`**——不只是每用户实体的那些，见 §2.2 规则一末尾。每用户实体的 repository 在此之上只声明带 `ownerId` 的方法：

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

**危险方法有两个来源，两个都要堵**：

| 来源 | 长什么样 |
|---|---|
| **继承来的** | `extends JpaRepository` 白送四个 owner-blind 方法 |
| **手写的** | 挂在裸 `Repository` 上的 `Optional<Note> findById(UUID id)`——一个都没继承，泄露一模一样 |

只堵第一个是常见的半拉子做法。

### 2.2 机器强制：ArchUnit 的三条规则

放在 `architecture/RepositoryChokePointTest`，跟着 `./gradlew check` 跑。

**规则一 · 父接口是白名单，不是黑名单。**

```java
// 唯一允许的父接口就是裸 Repository，其它一律违规——包括还没听说过的那些
repository.getRawInterfaces() 必须等于 { org.springframework.data.repository.Repository }
```

写成「不得 assignable to `CrudRepository`」这种黑名单会漏，而且漏的方式没有症状：

- **`PagingAndSortingRepository`** 自 Spring Data 3.0 起**直接继承裸 `Repository`**，不再经过 `CrudRepository`。所以它能通过黑名单，同时白送 `findAll(Sort)` 和 `findAll(Pageable)`。「extends `Repository`」这个说法本身已经不足以描述规则了。
- **`JpaSpecificationExecutor` / `QueryByExampleExecutor`** 压根不是 `Repository` 的子类型，`areAssignableTo(Repository)` 这类判据根本扫不到它们。混进来一个，整张表都能通过 Specification 或 Example 捞出来。

**这条规则对每一个 repository 生效，包括不带归属的表**（字典、参考数据、配置）。两个注解都买不回一个更宽的父接口——理由见 §2.4 末尾。代价只是给字典表手写一行 `List<Dict> findAll();`，换来的是「父接口白名单**没有例外**」这句话不必记任何限定条件；而带限定条件的规则，正是本节开头说的那种「要靠人每次记得」的东西。

**规则二 · 每个声明的方法必须看得出按 owner 过滤**，否则标 `@CrossUserQuery`；整张表压根没有归属列时改标 `@OwnerlessTable`（两者都在 §2.4）。「看得出」是指真的解析派生查询名，不是搜一下有没有 `OwnerId` 这个词——下面这些全都含有它，没有一个在按它过滤：

| 写法 | 实际语义 |
|---|---|
| `findAllByOrderByOwnerId` | 按 owner **排序**，选的是整张表。`OrderBy` 之后全是排序，要先截断再判断 |
| `findByOwnerIdNot` | 正好相反：**不是**你的那些行 |
| `findByIdOrOwnerId` | `Or` 是**放宽**，任一边成立即可，于是一个已知 id 能够到任何人的行 |
| `findByOwnerIdAndTitleOrId` | 最阴的一个。解析成 `(ownerId AND title) OR id`——owner 谓词是真的，旁边那条分支照样能读到所有人的数据 |
| `findAllByOwnerId()` | 名字完美，**没有参数**可绑 |
| `@Query("select n from Note n")` 配 `findByIdAndOwnerId` | `@Query` 完全覆盖派生查询，名字从此不构成证据 |

所以判据是：**先按 `Or` 拆分支，每一条分支都必须含 `OwnerId`**——析取式的宽度取决于它最宽的那条分支。再确认方法真的接受一个 `UUID`，以及带 `@Query` 时那段 JPQL 里真的绑了 `ownerId`。

> 文本拆分对自身带 `Or` / `And` 的属性名（比如 `orderNumber`）会误判。**这个方向是安全的**：它判失败，要求你改名或写一条 `@CrossUserQuery` 说明理由，而不是放行一个没人看过的查询。

写方法（`save` / `saveAndFlush`）豁免：它们持久化的是调用方**已经**通过 owner-scoped finder 取到的聚合，本来就没有谓词可带。

**规则三 · `@OwnerlessTable` 说的必须是真的。** 标了这个注解的 repository，机器去看它的实体**真的没有** `ownerId` 字段；有就报错。

这条是规则二那个豁免能安全存在的前提。`@OwnerlessTable` 是**接口级**的，一标就覆盖这个接口现在和将来的每个方法——所以它必须是一个**可核对的事实声明**，不是一句自述。少了规则三，把它误标（或有意标）在一张每用户表上，就等于一行注解关掉整张表的归属检查，而且和正确用法长得一模一样。

### 2.3 负向测试：双账号

见 [`../testing/index.md`](../testing/index.md)「怎么验证」第 2 条。要点：**A 的资源 id 用 B 的身份去够，必须 404**；并且要断言 **A 的数据还在**（否则一个「返回 404 但其实删掉了」的实现也能骗过前面的断言）。

正向用例全绿证明不了隔离——它们从来没试过越权。

### 2.4 两个注解，管两件不同的事

**跨用户访问的唯一登记例外是 `@CrossUserQuery`，范围只在本节定义。** 别处需要跨用户访问时不要照抄结论，回来读这张表。

另一个注解 `@OwnerlessTable` **不是隔离的例外**——它声明的是「这张表里没有要隔离的东西」。两者的形状和纪律因此完全不同，别混：

| | `@CrossUserQuery` | `@OwnerlessTable` |
|---|---|---|
| 说的是 | **这个查询**跨用户，理由如下 | **这张表**的行不归属于任何人 |
| 标在哪 | **方法**（接口级一律禁止） | **接口**（它是表的属性，不是某个查询的） |
| 机器能核对吗 | 不能，只能靠写下的理由 | 能核对一半（§2.2 规则三） |
| 典型 | 登录按邮箱找账号、admin 导出 | 字典、参考数据、静态配置 |

**判据是一句话：这张表的一行，有没有一个「它属于的人」？**

- **没有**（币种表、地区表、功能开关）→ `@OwnerlessTable`。
- **有**——哪怕归属不是一个叫 `ownerId` 的列，比如 **`app_user` 那种「行本身就是那个人」的表** → 继续逐方法标 `@CrossUserQuery`。

**这条边界必须靠人守，机器守不住**：`app_user` 和一张字典表在「有没有 `ownerId` 字段」上完全一样，规则三对两者都放行。它挡的是**误标**（把一张真带 `ownerId` 的每用户表标成无归属），不是有意的错误分类。把 `AppUserRepository` 标成 `@OwnerlessTable`，之后任何人加一个 `findAll()` 就能拉出全部账号，而且**看起来和正确用法一模一样**。

#### `@CrossUserQuery`

有些查询确实没有 owner 可带：登录要在**还没有会话可以作用域**的时候先把账号找出来；管理员视图和后台任务也真的跨账号。这些是例外，而**看不见的例外和错误没有区别**。

所以例外的形式是一个注解，不是一个悄悄放宽的接口：

```java
@CrossUserQuery("login and signup: the user table has no owner, and this runs before there is a session to scope by")
@Query("select u from AppUser u where lower(u.email) = lower(:email)")
Optional<AppUser> findByEmailIgnoringCase(@Param("email") String email);
```

它把理由放在代码旁边，并让全仓库的例外**一条命令就能列全**。

**只能标在方法上，不能标在接口上。** 这是刻意的：接口级豁免会自动覆盖以后加进这个接口的每一个方法——包括那些没人写过理由、加它的人根本没看见这条豁免的方法。一个例外 = 一个方法 + 一条理由。

| 允许 | 禁止 |
|---|---|
| 在**方法**上标 `@CrossUserQuery("理由")` | 标在接口上，或换一个更宽的父接口 |
| 建一个**显式命名**的 service（如 `AdminNoteQueryService`），方法名自带 admin 语义 | 给业务 repository 加 `findById` / `findAll` |
| 在那个 service 里做**显式的权限判断**（当前用户是不是管理员），判断写在方法入口 | 以「调用方已经校验过了」为由跳过 |
| 为它单独建一个 repository 接口，同样只声明它真正需要的方法 | 让业务代码顺手复用这个 admin 通道 |

**验收是负向的**：普通账号调那个 admin 端点必须被拒。写了角色判断 ≠ 生效。

#### `@OwnerlessTable`

字典、参考数据、静态配置这类表压根没有归属列，它们的每个方法都不可能按 `ownerId` 过滤：

```java
@OwnerlessTable("currency reference data: rows belong to the system, every account reads all of them")
public interface CurrencyRepository extends Repository<Currency, String> {
    List<Currency> findAll();
    Optional<Currency> findByCode(String code);
}
```

**为什么不用 `@CrossUserQuery` 逐个方法凑**：那会让「真的跨用户读」这个信号被淹掉。`@CrossUserQuery` 的价值在于**一条命令列全所有跨用户访问**然后逐条审——当这个清单里一半是无害的字典表查询，就没有人会去审它了。**例外机制的敌人是噪音，不只是遗漏。**

**它为什么可以标在接口上**（而 `@CrossUserQuery` 不行）：它声明的是**表的属性**，对这个接口现在和将来的每个方法一样成立，所以接口级豁免不会像 `@CrossUserQuery` 那样悄悄覆盖到一个当初没人考虑过的新方法。代价是它必须是个**可核对的事实**——那就是 §2.2 规则三，以及上面那条「机器只守得住一半」的提醒。

**两个注解都买不回一个更宽的父接口。** §2.2 规则一没有例外：继承来的 `findAll` 是没人主动写下的 owner-blind 通道，事后读代码的人无从判断那条豁免当初到底是为哪个方法写的。字典表要 `findAll()` 就自己声明一行——**手写的那行是有人做过的决定，继承来的那个不是**。

### 2.5 守卫的守卫

上面三条 ArchUnit 规则本身要有一份**反向测试**（`architecture/RepositoryChokePointGuardTest`）：拿一批**故意写错**的 repository 喂给规则，每一个都必须被拒；再拿正确的喂进去，必须放行。

理由很简单：**一个已经失效的守卫，和一个没东西可抓的守卫，都是绿的**，从结果上看不出区别。而这条守卫保着整条轨赖以成立的性质。

反向 fixture 至少要覆盖 §2.2 那两张表里的每一行，另外三点容易忘：

- fixture 接口要标 **`@NoRepositoryBean`**。测试类就在 repository 扫描走的 classpath 上，不标的话，容器里真的会多出一堆 owner-blind 的 repository bean——它们是为了「必须被拒」而写的，绝不该同时以能用的形态存在。
- 断言**哪个方法被点名**，不只是「抛了异常」。`@CrossUserQuery` 标在一个方法上时，同接口里另一个没标的方法必须仍然被报出来；只断言「整体变红」的话，一个「见到注解就放过整个接口」的实现照样能过。
- **`@OwnerlessTable` 要两个方向都喂**：标在真正无归属的实体上必须放行（否则字典表根本没法写），标在带 `ownerId` 的实体上必须被规则三拒掉。**只喂放行那一半，等于把规则三删了还是绿的**——而规则三正是那个接口级豁免能安全存在的唯一理由。

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
- **默认全部路由需登录，公开是一次显式决定。** 骨架里公开的只有 `/api/auth/login` 和 `/api/auth/signup`，因为它只有那一条链路——**那是骨架的形状，不是本轨的上限**。落地页、公开只读数据、分享链接、健康检查、webhook 回调都是正当的公开路由：在 `SecurityConfig` 里显式加一条，并在同一处写下**匿名能读到什么**。判据是「这些东西登不登录都无所谓吗」；答不上来就还不该公开。真正不许放松的是另一条——公开路由上的**昂贵操作必须限流**（§4.5）。
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

### 4.5 认证端点必须限流

登录和注册是**公开的**，而且**故意昂贵**——BCrypt 就是设计来慢的。没有限流，一台机器反复提交同一个**已注册**的邮箱就能把 CPU 打满，而数据库全程空闲（注册在唯一索引裁决**之前**就已经哈希过了，所以每个必然失败的请求都完整付了一次 BCrypt）。密码猜测同理。

**两份额度，防的是两件不同的事**：

| 额度 | 计什么 | 防什么 |
|---|---|---|
| **按客户端地址** | **每一次**尝试，成功失败都算 | 一台主机烧 CPU。可以每次都扣，因为扣的是它自己的额度 |
| **按账号** | 每次尝试**入场时原子扣减**，认证成功后**整份归还** | 僵尸网络把对一个账号的猜测摊到几千台主机上 |

这一节有三条是**缺一不可**的，少任何一条都会退化成另一种事故：

**① 必须在验证密码之前拒绝。** 放到验证之后（先跑完 BCrypt 再把 401 改写成 429），这道限流就只剩一个状态码：攻击者轮换地址照样能无限触发 BCrypt，逐个试密码。**可观测的验收**就是这一条——额度耗尽时，**连正确的密码也必须拿不到 200**。那是「BCrypt 根本没被执行」唯一能从外部看到的证据。

**② 必须是「预留」，不是「先查后扣」。** 查询额度和扣减额度是两步，中间有窗口：只剩一个令牌时，同时到达的 64 个请求会**全部**读到那个令牌、**全部**放行、**全部**买一次密码哈希，只有事后真正扣到的那几个被记下来。**被检查但没被占住的限制不是限制。** 用 `tryConsume` 这类原子操作把「准入」和「记账」合成一步，跑几个令牌就只放几个请求。

> 这条只在并发下可见。顺序循环里那份「先查后扣」的代码看起来完全正确——所以验收必须是并发测试（见 [`../testing/index.md`](../testing/index.md)）。

**③ 它不能变成账号锁定。** 两个性质一起保证这点：

- **被拒的请求什么都不扣**（`tryConsume` 全有或全无）。所以撞墙的流量不会把额度摁在 0，它照常按时回填，限流自己会好。
- **认证成功归还整份额度**，账号主人不必为一次打错字、或者别人的猜测，赔上这一分钟剩下的时间。

**残余风险，如实写在这里**：高速分布式攻击**正在进行**时，账号主人要和攻击流量抢那些滴回来的令牌，可能收到 429 需要重试。这是「限流真的咬人」的真实代价。真正的解法是人机挑战 / 二次验证——让真人能证明自己不是僵尸网络——那是产品决策，本轨不替你定。这套设计排除掉的是**没有出路**的那个版本：攻击者能把额度永久摁在 0，把账号锁死。

**其余几条，每条都对应一次踩过的坑**：

- **客户端地址只能取 `getRemoteAddr()`，绝不能读 `X-Forwarded-For`**。那个头是客户端自己写的，信它等于送攻击者无限身份。挂反向代理时配 `server.forward-headers-strategy=native`，让 Tomcat 自己的 valve 去改写 `getRemoteAddr()`——同一份信息，交给知道该信哪一跳的东西处理。**反过来忘了配也是事故**：所有请求都显示来自代理那一个地址，整个互联网共用一份额度，第一个正常用户就把它耗光。
- **追踪表要有硬上限**，否则限流器自己成了内存耗尽的入口。而且**上限判断必须和插入在同一把锁里**：「先看 size 再 `computeIfAbsent`」不是上限——同时到达的线程都读到一个没超限的 size，然后全都插入，上限 8 遇上 64 个新地址就跟踪了 64 个。
- **表满时拒绝新来的，不要放行**。表满意味着这么多不同的调用方同时在被限流，也就是**正在发生洪水**；此时放行未跟踪的调用方，等于让限流器在它最该工作的时刻关掉。拒绝新登录不影响已有会话，洪水过去就恢复。
- **淘汰只能淘汰满桶的**（已经回满 = 这个调用方安静够久了，忘掉它不改变任何事）。淘汰缺令牌的桶正好是**还在受限**的那些，等于给攻击者一个用新键刷表就能拿到的重置。
- **回填用 greedy（持续滴回），不要 interval（整点还满）**。interval 会让攻击者把请求卡在分钟边界上，每分钟拿一次满额突发。
- **429 必须带 `Retry-After`**，而且向上取整——`Retry-After: 0` 等于邀请客户端立刻重试一次注定失败的请求。
- **账号键要归一化**（trim + 转小写），和邮箱唯一索引的判据保持一致，否则大小写一换就是一份新额度。
- **进程内的桶 = 每实例一份额度**。单实例部署下这是诚实的取舍（不用多跑一个 Redis），横向扩容后要换成共享存储的桶。

### 4.6 API 接受的输入，必须是底下存储真能存的

校验漏了下游的真实限制时，**失败点在写入之后**——一半的活已经干完，用户拿到 500。两个真实的例子，都不是从 DTO 上看得出来的：

**BCrypt 只吃 72 字节。** Spring Security 6.3 起，超过就直接抛 `IllegalArgumentException`（更早的版本是静默截断）。它发生在 `PasswordEncoder.encode` 里，也就是注册进行到一半的地方，没有人接。密码管理器生成一个 100 字符的口令就能踩到。

- **`@Size(max = 72)` 表达不了这条限制**：BCrypt 数的是**字节**，`@Size` 数的是**字符**。19 个 emoji 是 38 个 Java 字符、76 个 UTF-8 字节，能大摇大摆走过字符校验，然后撞进同一个 500。要写一个按 UTF-8 字节数判断的自定义约束。
- **只有注册需要它**。验证走 `BCrypt.checkpw`，对超长密码返回 false 而不是抛异常，所以登录本来就是 401。

**会话表的 `PRINCIPAL_NAME` 存的是邮箱。** vendor schema 里它是 `VARCHAR(100)`，而 `app_user.email` 是无界 `text`。于是一个超过 100 字符的地址：用户行**提交成功**，请求末尾写会话时炸掉。结果是一个存在、但**永远登不进去**的账号，而且每次尝试都是 500——看起来像故障，其实是输入问题。

- 修法是**把列加宽**（新迁移，见 [`../database/index.md`](../database/index.md) §3），不是把邮箱截短到 100：加宽能顺带救活已经建出来的账号，截短会把它们永久留在外面。
- **API 侧的长度上限和那个列宽是同一个决定**，要一起改。254 是 RFC 5321 允许的邮箱最大长度。
- 验收要**跨越那次写入**：只断言注册返回 201 是不够的，还要用拿到的会话再发一个请求、并且能**重新登录**——因为炸点在会话写入，而不是在插入用户。

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

> **项目里没有 `services/` 目录时，本节整节不适用**——骨架里没有它，多数项目也不会有。保留它是因为那条信任边界的推理很贵，真要拆时不该重新踩一遍。

**什么时候需要**：产品有「重执行」的一侧（SSH 部署、调目标系统内部 API、重计算），不适合塞进 web 进程。

**什么时候不需要**：能在 service 里同步做完的就别拆。拆的代价是多一套部署、多一条信任边界、多一份版本对齐。

**标准模式**：`services/<svc>/` 自带 `AGENTS.md` + `CLAUDE.md`（根 `CLAUDE.md` 的 import 不会钻进子目录）；经 HTTP(Bearer) 下发任务；单独一份 compose 文件。

**信任边界**：共享 Bearer 只证明「调用方是我们的服务」，**不证明这次调用属于哪个用户**。所以 worker 的入参只有 job id，job 的归属在创建时由用户作用域的路径钉死；worker 要读的每一张用户表都经过**显式校验归属**的查询，不按外部传入的主键取数。验收同样是负向的：拿 A 的 job 去够 B 的资源必须被拒。

---

## Pre-Development Checklist

- [ ] 这次要建的 repository，父接口**只有**裸 `Repository` 吗？（`PagingAndSortingRepository`、混入 `JpaSpecificationExecutor` 一样不行——§2.2）
- [ ] 往 session principal 里加字段了吗？它会被序列化进数据库——凭据、令牌、密钥一律不许进（§4.1）
- [ ] 有「先查存在再插入」的地方吗？改成让唯一索引裁决 + 翻译成 409（§4.2）
- [ ] 写接口的响应里有时间戳/版本号吗？映射前 flush 了吗（§4.3）
- [ ] 新增的每个查询方法，名字里那个 `OwnerId` 真的在**过滤**吗？（`OrderBy` 之后是排序、`Not` 是取反、`Or` 是放宽——§2.2）
- [ ] 给方法加了 `@Query` 吗？名字从此不算数了，那段 JPQL 里绑 `ownerId` 了吗？
- [ ] 「不是你的」这条路径回的是 **404** 而不是 403？
- [ ] 要跨用户读数据吗？**默认不允许**——确需破例标 `@CrossUserQuery("理由")` 在**方法**上（§2.4），并配负向验收
- [ ] 这张表的一行有没有「它属于的人」？没有（字典、参考数据、配置）→ 接口上标 `@OwnerlessTable("理由")`，别逐个方法套 `@CrossUserQuery`。**`app_user` 那种「行本身就是人」的表不算无归属**（§2.4）
- [ ] 新加的端点是公开的、或者会做昂贵的事（哈希、外部调用）吗？限流了吗，拒绝点在昂贵操作**之前**吗（§4.5）
- [ ] 新字段的长度/格式上限，和它底下那一列、那个库的真实限制对得上吗（§4.6）
- [ ] 新增的路由要公开吗？**默认需登录**——要公开就在 `SecurityConfig` 显式登记，并写下匿名能读到什么（§4）；公开 + 昂贵 = 必须限流
- [ ] 挂了新的后端路径吗？记得加进 SPA 兜底的排除列表（§5）
- [ ] 改了 schema 吗？只加 Flyway 迁移，`ddl-auto` 不动
- [ ] 从网上抄了 Boot 3 的代码吗？先对一遍 [`../README.md`](../README.md) 的包名陷阱表（尤其 Jackson 3）
- [ ] 要拆异构子服务吗？先问能不能在 service 里同步做完（§8）

## Quality Check

```bash
./gradlew spotlessCheck check
```

额外自检：

- [ ] `ArchUnit` 那三条仍然绿（父接口白名单 + 每个方法看得出按 owner 过滤 + `@OwnerlessTable` 的实体真的无归属）
- [ ] 动过那两条规则吗？守卫的反向测试（§2.5）跟着更新了吗
- [ ] 新的每用户表配了**双账号负向测试**，且断言了「另一个账号的数据没被改动」
- [ ] 没有把实体直接返回给 controller
- [ ] 没有新增 `@ManyToMany` 或 `EAGER`
- [ ] 密钥没有出现在 `application.yml`、源码或任何 `VITE_*` 变量里

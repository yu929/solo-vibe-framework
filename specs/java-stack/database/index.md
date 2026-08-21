# 数据库规范 · Java Stack 轨

> SQL 只出现在 `backend/src/main/resources/db/migration/`。轨总览与禁止清单见 [`../README.md`](../README.md)。

## 速查

| 场景 | 做法 |
|---|---|
| 改 schema | 新增一个 `V<n>__<name>.sql`，**永不改已提交的迁移** |
| 建每用户表 | 必须三件套：`owner_id not null` 外键 + `owner_id` 索引 + 归属收口的 repository |
| 验证迁移能干净重放 | `docker compose -f docker-compose.dev.yml down -v && up -d` 再起应用 |
| schema 生成方式 | **只有 Flyway**。`ddl-auto` 恒为 `validate` |

## 1. Flyway 是唯一改 schema 的东西

`spring.jpa.hibernate.ddl-auto: validate`，**禁 `update` / `create-drop`**。

`update` 的问题不是它不好用，而是它**没有症状**：Hibernate 按实体推断出一个 DDL 打上去，你的库和迁移脚本从此分叉。本地一切正常，直到 CI 或新环境从零重放迁移，得到一个**结构不同的库**。`validate` 会在启动时就把这种分叉喊出来。

**已提交的迁移不许改。** 改了的话，已经跑过它的环境不会重跑，校验和还会对不上。要修就加下一个版本。

## 2. 新表三件套（每用户表）

每用户表的隔离全靠这三样加一条测试。少一个就漏。

```sql
create table <name> (
    id         uuid        primary key,
    owner_id   uuid        not null references app_user (id) on delete cascade,  -- ①
    ...
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index <name>_owner_id_idx on <name> (owner_id);                            -- ②
```

**① 归属列非空 + 外键**：让「这行属于谁」成为数据库约束，而不是某个 service 记得填的字段。
**② `owner_id` 索引**：每次读都按它过滤。
**③ 归属收口的 repository**：见 [`../backend/index.md`](../backend/index.md) §2.1——不 extend `JpaRepository`，只声明带 `ownerId` 的方法。

**④ 加一条双账号负向测试**（[`../testing/index.md`](../testing/index.md)）。前三条是「写了」，第四条才是「生效」。

> **不是每用户的表**（字典、参考数据、静态配置）当然没有 `owner_id`。这是正常的例外，但要在两处都说出来，否则下一个人无法区分「有意的」和「忘了」：迁移里**写一行注释**，repository 接口上标 **`@OwnerlessTable("理由")`**（[`../backend/index.md`](../backend/index.md) §2.4）。
>
> **别拿 `@CrossUserQuery` 逐个方法凑**——那个注解是给「真的跨用户读」用的，混进一堆无害的字典查询之后，那份例外清单就没人会去审了。反过来也要小心：`app_user` 那种「行本身就是人」的表**不算**无归属，它继续走 `@CrossUserQuery`。

## 3. Spring Session 的表是抄来的，不是写的

会话表来自 spring-session-jdbc 的 jar，**逐字复制**进第一个迁移，不要凭记忆重写：

```bash
unzip -p ~/.gradle/caches/**/spring-session-jdbc-<版本>.jar \
  org/springframework/session/jdbc/schema-postgresql.sql
```

配合 `spring.session.jdbc.initialize-schema: never`——建表的事只许 Flyway 做一份。

升级 Spring Session 时：把新 jar 里的 schema 与仓库里那份 diff 一下，有差异就**加一个新迁移**，不要去改老的那个。

### 3.1 抄来的 schema 未必装得下你的数据

「不改抄来的迁移」不等于「抄来的尺寸都合适」。vendor schema 是按它自己的通用假设写的，而你往里塞的是**你的**数据。

实战踩过的那条：`SPRING_SESSION.PRINCIPAL_NAME` 在 vendor schema 里是 `VARCHAR(100)`，而本轨的 principal name 就是邮箱，`app_user.email` 是无界 `text`。于是一个 100 字符以上的地址——

1. 用户行**插入成功并提交**；
2. 请求末尾写会话时，才撞上列宽炸掉。

结果是一个**存在、但永远登不进去**的账号，之后每次登录都是同一个 500。它看起来像故障，其实是输入长度问题，而且已经把坏数据留在库里了。

**处理方式**：

- 加**一个新迁移**去 `alter column ... type`，不要动 V1。加宽而不是把输入截短——加宽能顺带救活已经建出来的账号，截短会把它们永久留在外面。
- 在那个迁移里**写清楚这是对 vendor schema 的有意偏离**，以及升级 Spring Session 时要重新确认。否则下一个人 diff 出差异，会以为是自己抄错了。
- **API 侧的长度校验和这个列宽是同一个决定**，一起改（[`../backend/index.md`](../backend/index.md) §4.6）。

**顺带一条通用的**：接了任何第三方 schema（会话、任务队列、审计表）之后，把**你会往它每一列里塞什么**过一遍。这类不匹配的共同特征是——在写入链条的**后半段**才炸，前半段已经提交了。

## 4. 时间与类型约定

- 时间列一律 `timestamptz`，应用侧 `Instant`，`spring.jpa.properties.hibernate.jdbc.time_zone: UTC`。
- 主键 `uuid`，由 Hibernate 生成（`@GeneratedValue(strategy = GenerationType.UUID)`）——不用自增，避免 id 可枚举。
- 大小写不敏感的唯一性（邮箱）用**表达式唯一索引**：`create unique index ... on app_user (lower(email))`，查询侧也走 `lower(...)`。只在应用层 `toLowerCase()` 挡不住并发插入。

### 4.1 闭集枚举必须在数据库约束同一取值域

Java 那边写了 `enum`、字段标了 `@Enumerated(EnumType.STRING)`，很容易觉得取值域已经管住了。管住的只是**经过应用写入口的那一条路**。迁移脚本、人工 SQL、数据恢复、还没下线的旧版本实例，每一条都能往那一列里写进 enum 不认识的字符串。

而且它炸的位置不在写入侧：坏值当场落库、事务正常提交，直到某次查询把那一行读出来做 `Enum.valueOf`——**整页列表跟着挂掉**，不是那一行降级。一行脏数据放倒一屏，这是它比普通脏数据贵的地方。

所以列上要有 CHECK，值集合与当前 Java enum 一致：

```sql
-- 错：Java 拿它当闭集，数据库却收任意字符串
event_type varchar(64) not null

-- 对：两边共享同一个显式取值域
event_type varchar(64) not null
    constraint audit_event_type_check
    check (event_type in ('LOGIN', 'LOGOUT'))
```

**改取值域时顺序有讲究，而且两个方向不对称**：

- **加值**：先上扩 CHECK 的迁移，再让应用写新值。反过来写入直接失败（PostgreSQL `23514`）——那是发布顺序错了，**别临时把约束放宽过去**。
- **删值**：存量行要在**同一个前向迁移**里裁决掉，再收紧 CHECK。存量没处理干净就让迁移失败，别让它带着一批读不出来的行通过。

两个方向都只加新迁移，不回改已执行的（§1）。

**遇到不认识的值要 fail closed。** 尤其审计、任务状态这类正式记录——加个 `UNKNOWN` 兜底、或者把读不出来的行静默过滤掉，都是把「数据坏了」翻译成「数据没了」，跟 [`../frontend/index.md`](../frontend/index.md) §2.2 是同一类错误断言。什么情况才算真有兼容对象值得保留旧值，判据在 [`../guides/review-adjudication.md`](../guides/review-adjudication.md)。

**验它会红**：空库重放迁移后逐个插入 `Enum.values()`，必须全部成功；再插一个退役值和一个随机字符串，必须都被拒。摘掉 CHECK 之后那条负向测试必须变红（[`../testing/index.md`](../testing/index.md)）。

## 5. 本地库的项目名陷阱

新项目第一步跑 `scripts/init-project.sh <项目名>`。

**compose 从项目名派生 volume 名。** 不改则所有从本模板生成的项目**共享同一个 Postgres 数据卷**——A 项目的 `docker compose down -v` 会静默清掉 B 项目的数据。

同一个脚本还会改会话 cookie 名（默认 `JSESSIONID` 在 localhost 上被所有应用共享，两个项目同时开发会互相顶掉登录）。

## 5.1 开发库只绑回环

compose 里写 `"5432:5432"` 等于 `0.0.0.0:5432`——**把开发数据库发布到了所有网卡**。配上一个写在公开模板仓里的固定口令，在咖啡馆 wifi 或公司内网上就是一个人人可连的库。

一律写成 **`"127.0.0.1:5432:5432"`**。要连它的东西（应用、IDE、psql）都跑在这台机器上，没有一个需要它对外可见。

## 5.2 数据库口令不许有默认值（连「看起来像开发值」的也不行）

`application.yml` 里**不许出现口令的默认值**，哪怕它叫 `dev-only-not-a-secret`。理由不是命名，是**静默回落**：任何漏配变量的启动路径（裸 `java -jar`、systemd unit、少写一条 env 的 k8s manifest）都会用那个公开已知的口令**成功启动**。

口令的唯一来源是**未提交的 `.env`**（由 `.env.example` 播种），`bootRun` 读它，部署用环境变量。

### 但「没有默认值」并不等于「会失败」 —— 两个反直觉的坑

**坑一：变量名不能是属性的 relaxed-binding 形式。**

```yaml
password: ${SPRING_DATASOURCE_PASSWORD}   # ← 自引用
```

`SPRING_DATASOURCE_PASSWORD` 正是 `spring.datasource.password` 的环境变量形式，所以这是拿属性自己解析自己。变量没设时它塌成空串，而不是报错。**用一个不是属性别名的名字**（如 `APP_DB_PASSWORD`）。

**坑二：占位符解析失败也不会中止启动。**

Spring Boot 绑定 `@ConfigurationProperties` 时**忽略无法解析的占位符**，把 `${APP_DB_PASSWORD}` 这串字面量原样交给驱动。多数服务器会回 `password authentication failed`——难懂但至少是致命的；而 Postgres 配了 `trust` 认证时**任何口令都通过**，应用就在一个没人设过的凭据上正常起来了。又是一个没有症状的。

**所以要在 `main()` 里显式挡一道**，在 `SpringApplication.run` 之前检查环境变量与系统属性，缺失就抛异常。这条守卫要配单测（把环境查找做成参数——JVM 内改不了自己的环境变量）。

> 这两条都是实测出来的：先以为「去掉默认值就会失败」，跑了才发现是 `password authentication failed`；再改名字，还是没失败。**「我以为它会报错」不算验证过。**

## 6. 迁移写完怎么验

```bash
docker compose -f docker-compose.dev.yml down -v   # 丢掉本地数据
docker compose -f docker-compose.dev.yml up -d
./gradlew :backend:bootRun                          # Flyway 从零重放 + JPA validate
```

能干净起来，才说明迁移在一个新环境里是成立的。**在有旧数据的库上「跑通了」什么都不证明**——那次可能只跑了增量的那一条。

集成测试用 Testcontainers，每次都是全新库，所以 `./gradlew check` 天然覆盖了「迁移能重放」这件事。

---

## Pre-Development Checklist

- [ ] SQL 只写在 `db/migration/`，没有写进应用代码？
- [ ] 新迁移是**新增文件**，没有改动任何已提交的迁移？
- [ ] 每用户表带了 `owner_id not null references app_user(id)` + 索引？
- [ ] 不是每用户表的，迁移里写了注释、repository 上标了 `@OwnerlessTable("理由")`？（不是给每个方法套 `@CrossUserQuery`）
- [ ] 时间列是 `timestamptz`？大小写不敏感的唯一性用了表达式索引？
- [ ] Java 用闭集 enum 读取字符串列吗？数据库有同值域 CHECK，新增值的前向迁移排在应用写入之前吗？
- [ ] 新项目跑过 `scripts/init-project.sh <项目名>` 了吗？（不跑会共享本地数据卷，`down -v` 互相清库）

## Quality Check

```bash
docker compose -f docker-compose.dev.yml down -v && docker compose -f docker-compose.dev.yml up -d
./gradlew check     # Testcontainers 会在全新库上重放全部迁移
```

额外自检：

- [ ] 应用能在**空库**上从零起来（`validate` 没有报表结构不符）
- [ ] 新表配了双账号负向测试，并且**验过它会红**（把归属谓词去掉试一次）
- [ ] 闭集枚举约束逐个接受当前值，并拒绝退役值与随机未知值；摘掉 CHECK 后负向测试会红
- [ ] 没有手改 `V*__spring_session.sql`

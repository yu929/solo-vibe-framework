# 后端与鉴权规范 · Web Fullstack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；数据库与 RLS 见 [`../database/index.md`](../database/index.md)。

## 速查

| 操作 | 唯一做法 |
|---|---|
| 读数据 | Server Component 内 `const supabase = await createClient()`（`server.ts`）再 `.select()` |
| 写数据 | **Server Actions**（`"use server"`）。**不为表单新建 API Route Handler** |
| 会话刷新 | 只在 `src/proxy.ts → updateSession` |
| Supabase key | 浏览器与服务端都用 **publishable key**（`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`） |
| 写 cookie | 交给 proxy 或 server action，**不在 Server Component 里直接写** |

## 1. 数据读写

- **读**：Server Component 内 `await createClient()` 再 `.select()`。
- **写**：一律 Server Actions。不为表单新建 API Route Handler。
- **client 用泛型**：`createClient<Database>()`，类型来自生成的 `database.types.ts`。

三个 Supabase 接入点各司其职：`client.ts`（浏览器）、`server.ts`（服务端）、`middleware.ts`（会话刷新）。

## 2. 鉴权

Supabase Auth（邮箱 + 密码）。

- 会话刷新**只在** `src/proxy.ts → updateSession`
- 受保护路由由 proxy 统一拦截，未登录跳 `/login`
- 公共前缀：`/login`、`/signup`、`/auth`
- `requireUser()` 在 `src/lib/auth/require-user.ts`（server-only + react cache）；有 `profiles` 后在此扩 `requireAdmin`

## 3. auth cookie 名必须显式指定

三个 Supabase 接入点（client / server / middleware）**一律**带 `cookieOptions: { name: SUPABASE_AUTH_COOKIE_NAME }`（定义在 `src/lib/supabase/auth-cookie.ts`，按项目改名）。

**不带会怎样**：supabase-js 按 URL hostname 推导 cookie 名。自托管部署里 server 走 `SUPABASE_INTERNAL_URL`、浏览器走公网 URL，两边名字分叉 → 浏览器 client 静默变 anon（查询 401、Realtime 事件全被 RLS 挡掉）。

**为什么容易漏**：本地开发两个 URL 一致，**永远复现不了**。

## 4. 禁注册但保留登录

要做「邀请制 / 管理员建号、禁自助注册」时：

```toml
[auth]
enable_signup = false          # → GoTrue DISABLE_SIGNUP，全局禁 signup

[auth.email]
enable_signup = true           # → EXTERNAL_EMAIL_ENABLED，保留 email 登录通道
```

**别**把 `[auth.email].enable_signup` 设成 `false`——它关的是整个 email provider，已有用户也会报 `Email logins are disabled`。

**也没有** `[auth.email].enabled` 这个键，新版 CLI 见到会直接拒绝启动。

**此坑只在 CI 的 fresh `supabase start` 暴露**，本地复用旧 auth 容器测不出。改后务必 `supabase stop && supabase start` 复验。

## 5. 服务端校验的位置

表单校验写在 server action 里（见 [`../frontend/index.md`](../frontend/index.md) §3），但这**不代表**其余层可以无条件信任：

- **授权必须在服务端执行**，客户端隐藏入口不算授权
- **数据不变量由数据库兜底**（RLS、唯一约束、外键、非空）——并发请求、后台任务、迁移脚本都不经过 server action

判据见 [`../guides/cross-layer.md`](../guides/cross-layer.md) 的「校验散落各层」。

## 6. 异构子服务（如 Python 执行器）

**什么时候需要**：产品有「重执行」的一侧（SSH 部署、调目标系统内部 API、重计算），不适合塞进 Next 进程——独立成子服务，Next 只经 HTTP(Bearer) 下发任务。

**什么时候不需要**：能在 server action 里同步做完的，就别拆。拆子服务的代价是多一套部署、多一条信任边界、多一份版本对齐。

**标准模式**：

1. **目录**：`services/<svc>/`，Python 用 **uv** 管依赖（FastAPI + `pyproject.toml` + `uv.lock`）。
2. **约定配对**：该目录放自己的 `AGENTS.md`（那条轨的锁定规则）+ `CLAUDE.md`（仅一行 `@AGENTS.md`）——根 `CLAUDE.md` 的 import **不会**钻进子目录，异构子项目必须自带一对。根 `AGENTS.md` 加一行「编辑 `services/<svc>` 前先读其 `AGENTS.md`」。
3. **信任边界**：见下面 §6.1，这是本节唯一不许简写的一条。
4. **发版联动**：`pnpm release:validate` 已自动校验 `services/*/pyproject.toml` 版本与 tag 一致；在 `release.yml` 补该服务的 quality job（ruff / mypy / pytest）与镜像构建 + OCI 元数据核验。
5. **compose**：子服务单独一份 `docker-compose.<svc>.yml`，与 app 分开起停。

### 6.1 信任边界：worker 只消费绑定归属的 job

**先说清楚共享 Bearer 证明了什么**：它只证明「调用方是我们的 Next」，**不证明「这次调用属于哪个用户」**。而 service-role 绕过 RLS。两者叠加，如果 worker 肯按外部传进来的主键取数据，那么一个被猜中、被重放、或者 Next 自己传错的主键，就是一次跨租户读取——数据库层面没有任何东西会拦它。

所以**不允许 worker 按任意主键自取用户数据**。改成三段：

**① job 由用户作用域的路径创建。** Next 在 server action 里用普通 client（publishable key + RLS）往 job 表写一行，`user_id` 取自 `auth.uid()`，**不接受客户端传入**；job 表本身按 [`../database/index.md`](../database/index.md) §2 的三件套建（grant + RLS + 策略）。归属在这一步就被数据库钉死了，不是后面靠参数带过去的。

**② worker 只按 job id 消费。** 它拿到的唯一入参是 job id。要读的每一张用户表都经过一个**显式校验归属的数据库函数**——函数内部比对该 job 的 `user_id` / `tenant_id` 与目标行的归属，不匹配就报错。**不允许裸 `service_role` `.select()` 一个外部传进来的主键。**

**③ 例外范围写死，不许外扩。**

| service-role 允许 | service-role 禁止 |
|---|---|
| 按 job id 更新该 job 的状态、进度、结果 | 跨 job 读写用户数据 |
| 调用上面那种自带归属校验的数据库函数 | 按外部传入的主键直接取用户表 |
| 读自己的运行时配置 | 以「Next 已经校验过了」为由跳过归属校验 |

**这是 [`../database/index.md`](../database/index.md) §1「不绕过 RLS」的唯一受控例外，例外范围只在本节定义。** 别处需要用 service-role 时不要照抄这一节的结论，回来读这张表。

**④ 密文不过 HTTP。** **Next 不经 HTTP 传密文**；密钥经 env 注入，双方共享的加密格式单源维护。

**⑤ 验收是负向的。** 写了归属校验 ≠ 生效，判据只有一个：拿 A 租户的 job 去够 B 租户的资源主键，**必须被拒**。见 [`../testing/index.md`](../testing/index.md)「怎么验证」第 3 条。这与本轨对 RLS 的态度一致——策略写了要用第二个账号真的试。

> 同理，「每个内网工具都要」的身份地基（管理员建号 / 禁自助注册 / 防暴破 / TOTP / LDAP）**不进 starter**——按项目实际需要在对应切片里实现。starter 只保留最小可跑的骨架，不预置你不一定要的东西。

---

## Pre-Development Checklist

- [ ] 读数据走 Server Component + `createClient()`，不是别的路子？
- [ ] 写数据走 Server Action，**没有**为表单新建 API Route？
- [ ] 新加的 Supabase 接入点带 `cookieOptions: { name: SUPABASE_AUTH_COOKIE_NAME }` 了吗？
- [ ] 这个操作的**授权**在服务端做了吗？（客户端隐藏入口不算）
- [ ] 用到 `service_role` 了吗？**默认不允许**——确需破例要显式记载受控例外
- [ ] 新增路由需要登录吗？公共前缀只有 `/login` `/signup` `/auth`
- [ ] 要拆异构子服务吗？先问能不能在 server action 里同步做完（见 §6）
- [ ] 子服务这次读的**每一张**用户表，归属校验在哪个数据库函数里？说不出函数名就是没做（§6.1）
- [ ] 有没有哪个入参是「外部传进来的用户数据主键」？有就是走错路了——worker 的入参只该有 job id

## Quality Check

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

额外自检：

- [ ] 没有在 Server Component 里直接写 cookie
- [ ] 没有把 DB client / 密钥 / server-only 模块 import 进 client
- [ ] 改过 auth 配置的话，`supabase stop && supabase start` 复验过（旧容器测不出 signup 配置的坑）

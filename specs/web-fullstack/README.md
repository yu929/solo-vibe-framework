# Web Fullstack 轨 · 规范总览

> 本文件是 spec 根总览（对应官方模板的 `.trellis/spec/README.md`）。各层入口在 `<layer>/index.md`，轨无关思维清单在 `guides/`。

> Next.js 16 + Supabase 轨的编码规范。装进项目后位于 `.trellis/spec/`，由 Trellis 按需注入。
>
> **本文件是本轨锁定规则的权威源。** 与 starter 仓 `AGENTS.md` 冲突时以本文件为准——见本页末「与 starter AGENTS.md 的关系」。

> ### 本模板是自足的，一个项目只装它一个
>
> 装法只有一条命令：
>
> ```bash
> trellis init --claude --registry <框架仓 URL> --template web-fullstack
> ```
>
> **不要再装第二个模板。** Trellis 的 `.trellis/config.yaml` 里 `registry.spec.template` 是**单数**字段，装第二个会把它整行替换掉，此后 `trellis update` 只刷新后装的那个——**本轨规范（含上面那些安全红线）从此收不到修复，而且不报错**。
>
> 所以 `guides/`（轨无关思维清单）已经打包在本模板里，不需要额外装 `universal-guides`。那个模板只给**还没有轨规范**的项目用。

## 栈锁定（不经确认不得替换）

| 层 | 锁定 |
|---|---|
| 框架 | **Next.js 16 App Router** + **React 19** + **TypeScript**（strict） |
| 样式/组件 | **Tailwind v4** + **shadcn/ui**（Base UI 内核，`base-nova` 风格，neutral 主色） |
| 后端/数据 | **Supabase**（Postgres + Auth + RLS），本地经 Supabase CLI + Docker |
| 包管理 / 运行时 | **pnpm**（corepack 启用）；**Node ≥ 22** |
| 数据访问 | `@supabase/supabase-js` + `@supabase/ssr` |
| 测试 | **Vitest**（`*.test.ts`）+ **Playwright**（`e2e/*.spec.ts`） |
| 部署 | **Docker 容器化**（`output: "standalone"` + 多阶段构建），**不用 Vercel** |

## 禁止清单（最致命的先列）

> 真实项目确需破例时（如 service-role 用于 Auth Admin API、secret 不能作 server action 入参而需一个转发壳 Route），必须**显式记载受控例外**（范围 + 理由 + 落点），不许默默绕过；例外本身也要能被评审核对。
>
> **已登记的受控例外只有一条**：异构子服务的 worker 持 service-role，范围写在 [`backend/index.md`](backend/index.md) §6.1。它带一条不许简写的不变量——worker 的入参只有 job id，不按外部传入的主键取用户数据——和一条负向验收（拿 A 租户的 job 够 B 租户的资源必须被拒）。**「有一条例外」不等于「service-role 可以自由用」**：不在那张表里的用法一律按禁止处理。

**安全（破了会出真事故）**：

- 不把 `service_role` / `secret` key 用于前端或任何 `NEXT_PUBLIC_*` 变量。
- 不绕过 RLS（不用 service-role client 读写用户数据）。
- 不在 `localStorage` 存会话凭证或长期 token（用 httpOnly cookie——Supabase SSR 已走 cookie）。
- 不在 client 用 `dangerouslySetInnerHTML`（非用不可则在调用点用 allowlist 消毒）；不可信 URL 赋给 `href`/`src` 前先校验协议；`target="_blank"` 必配 `rel="noopener noreferrer"`。
- 不提交 `.env.local` 或把密钥写进源码。

**结构（破了会扩散）**：

- 不在应用代码里手写 SQL（SQL 只出现在 `supabase/migrations/`）。
- 不手改生成文件：`src/components/ui/*`（shadcn 生成）与 `src/lib/supabase/database.types.ts`（Supabase 生成）。
- 不用 API Route 处理表单提交（用 Server Actions）。
- 不在 Server Component 里直接写 cookie（交给 proxy 或 server action）。
- 不引入 `@radix-ui/*`：本轨 shadcn 用 **Base UI** 内核（`components.json` → `style: base-nova`）。Base UI 用 render prop、**无 `asChild`**，别套网上 Radix 时代的 shadcn 写法。
- 不用 `next/font/google`（构建时联网下载字体，内网/离线构建会失败）；字体一律 vendored 在 `src/app/fonts/` 走 `next/font/local`。
- 引入新依赖（尤其重型库）前先问。

## 目录结构（新增代码按此归位）

```
src/
  app/
    layout.tsx                  # 根布局，挂 <Toaster/>
    fonts/*.woff2               # vendored 字体（next/font/local），构建零外网依赖
    page.tsx                    # 受保护首页（需登录）
    login/page.tsx  signup/page.tsx
    auth/actions.ts             # 鉴权 server actions: login/signup/signOut
    <功能>/actions.ts           # 每个业务模块一组写操作
    <功能>/[id]/edit/page.tsx   # 模块编辑页（按需）
  components/
    ui/                         # shadcn 组件，只用 CLI 增删，勿手改
    data/                       # patterns：DataTable / FilterBar / EmptyState / StatusBadge / ConfirmDialog / CopyButton / ActionTooltip
    forms/                      # patterns：FormRow / PasswordInput / SubmitButton
    app/                        # 页面骨架：page-header.tsx
    *.tsx                       # 业务组件
  lib/
    auth/require-user.ts        # requireUser()（server-only + react cache）
    supabase/{client,server,middleware}.ts   # 浏览器 / 服务端 / 会话刷新三个接入点
    supabase/auth-cookie.ts     # 统一 auth cookie 名（三处共用）
    supabase/database.types.ts  # supabase 生成，勿手改
    status.ts                   # 状态词表：domain → tone/label
    utils.ts                    # cn()
  proxy.ts                      # Next 16 proxy（原 middleware），调 updateSession
design-system/MASTER.md         # 全站 UI 视觉权威
supabase/
  config.toml  migrations/*.sql # 数据库 schema（唯一写 SQL 的地方）
e2e/*.spec.ts                   # Playwright E2E（含 RLS 隔离）
*.test.ts                       # Vitest 单元测试（与被测代码同目录）
Dockerfile  docker-compose*.yml # 容器化部署（含 selfhost 内网版）
.github/workflows/{ci,release}.yml
```

## 锁死 vs 放手

**锁死，改动先问**：栈、目录、数据访问方式、RLS、鉴权位置。

**放手，直接改**：单个页面的布局、文案、组件选用。

## 本轨规范索引

每个 `<layer>/index.md` 都带 Trellis 约定的 **Pre-Development Checklist** 与 **Quality Check** 两节（`workflow.md` 会按这个约定去读）。

**轨特化（这条轨专有）**：

| 文件 | 管什么 |
|---|---|
| [`frontend/index.md`](frontend/index.md) | 组件复用顺序、Server/Client 边界、Hooks、表单与弹框、主题与视觉、可访问性 |
| [`backend/index.md`](backend/index.md) | 数据读写方式、鉴权与会话、auth cookie、注册开关、异构子服务的信任边界 |
| [`database/index.md`](database/index.md) | RLS、新表三件套、迁移、类型生成 |
| [`testing/index.md`](testing/index.md) | 质量门命令、怎么验证功能与数据（含两条负向测试） |

**轨无关（换技术栈也成立，随本模板一起装）**：

| 文件 | 管什么 |
|---|---|
| [`guides/index.md`](guides/index.md) | guides 总入口 |
| [`guides/code-reuse.md`](guides/code-reuse.md) | 写新代码前先找既有实现的顺序 |
| [`guides/cross-layer.md`](guides/cross-layer.md) | 跨层职责判据（含「校验散落各层」，[`backend/index.md`](backend/index.md) §5 与 [`frontend/index.md`](frontend/index.md) §3 引的就是它） |
| [`guides/review-adjudication.md`](guides/review-adjudication.md) | 编码期 finding 的 4 字段、召回与裁决分离 |

> `guides/` 在框架仓里是**生成副本**，权威源是 `specs/universal/guides/`，由 `scripts/sync-spec-guides.sh` 同步。**改 guides 要去改权威源**——直接改这里下次同步就被覆盖（框架仓的 CI 会先报出来）。

## 与 starter AGENTS.md 的关系

**同一套规则目前存在两处**：本目录，与 starter 仓 `web-fullstack/AGENTS.md`。这是已知的临时状态，不是设计意图。

- **本目录是权威源**，跟着框架仓维护、经 Trellis 按需注入。
- starter 的 `AGENTS.md` 应当逐步瘦身成「项目信息 + 指向本规范」，但**最致命的几条必须留正文**：`service_role` 不进前端、不绕 RLS、不手改生成文件。理由：不走 Trellis 的 session 读不到按需注入的 spec，那几条破了会出真事故，不能只存在于注入路径里。
- 瘦身之前，改规则**先改本目录**，再同步回 starter。反向改会漂移。

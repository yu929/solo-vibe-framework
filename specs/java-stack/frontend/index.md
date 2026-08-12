# 前端规范 · Java Stack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；API 契约的另一半在 [`../backend/index.md`](../backend/index.md)。

## 速查

| 主题 | 规则 |
|---|---|
| 调后端 | **只经 `src/lib/api/client.ts`**，组件里不裸 `fetch` |
| 数据类型 | 从 `src/lib/api/schema.d.ts` 派生，**不手写、不手改** |
| 读 / 写 | TanStack Query 的 `useQuery` / `useMutation`，写完 `invalidateQueries` |
| 加 UI 组件 | `pnpm dlx shadcn@latest add <name>`，勿手改 `src/components/ui/*` |
| 复用顺序 | `ui/*` → `{data,forms,app}/*` → 都不满足才新建 |
| 表单 | 受控 state + `<form noValidate>`，pending 由 `mutation.isPending` 显式传入 |
| 列表 key | 稳定 id，**别用数组下标** |
| 记忆化 | 默认不加 `useMemo/useCallback/memo`，profile 证明有成本再加 |

## 1. 所有后端调用收口在一个 client

`src/lib/api/client.ts` 是唯一出口。两样东西在那里，不许在调用点重新实现：

1. **CSRF**：非安全方法自动带 `X-XSRF-TOKEN`（值取自 `XSRF-TOKEN` cookie）。漏了就是 403，而 403 长得像权限问题，会把人引去查授权。
2. **错误归一化**：后端回 RFC 9457 `problem+json`，client 把它变成一个 `ApiError`，页面只渲染一种东西。

**禁止在组件里裸 `fetch`。** 每个绕过它的调用点都要自己记得 CSRF 和错误形状，而漏掉的那个不会在写的时候报错。

## 2. 类型来自后端，不是手写的

```ts
import type { components } from "./schema";
export type Note = Required<components["schemas"]["NoteResponse"]>;
```

`schema.d.ts` 由 `pnpm api:types` 从后端 `/v3/api-docs` 生成，**不手改**。后端 DTO 改了字段名而前端没跟上时，**typecheck 直接失败**——这正是要的效果。手写一份平行的 interface 就把这层保护关掉了，改名会变成运行时的 `undefined`。

**`Required<>` 是有意的**：springdoc 只在属性带 Bean Validation 注解时才标 `required`，响应 DTO 通常不带，于是生成的类型全是可选。这些列在库里都是 `NOT NULL`，API 确实总会给。

改了后端 API：重新生成 → `pnpm typecheck` → 按报错改。**别反过来手改 `schema.d.ts` 让它编译过。**

## 2.1 CSRF 冷启动：签出可达的表单要等 bootstrap

登录页和注册页是**唯一在拿到 `XSRF-TOKEN` cookie 之前就能被提交**的两个界面（其余页面都在路由守卫后面，`/auth/me` 早就回来了）。

密码管理器瞬间填好两个字段、或者手快的人直接回车，就会发出一个**没有 CSRF 头的 POST**，拿到 403 —— 而 403 在登录页上看起来就是「密码错了」。

**做法**：把「bootstrap 是否完成」传进表单，未完成时禁用输入与提交（`useCurrentUser()` 的 `isPending` 就是它）。几十毫秒的禁用换掉一整类看不懂的 403。

**不要**改成「403 就自动重试一次」——那是拿重试掩盖竞态，真正的 CSRF 失败也会被一起吞掉。

## 2.2 失败要分类，不要一律显示成「没找到」

把所有请求失败都渲染成「XX 不存在」是**内容层面的错误断言**：401（会话过期）、500、网络中断都会被说成「你的数据没了」。用户于是去找数据，而不是去重新登录或报障。

至少分三类，收口在 API client 里一次：

| 判据 | 含义 | 界面 |
|---|---|---|
| 404 | 真的没有，或不属于这个账号 | 「不存在」+ 回列表 |
| 401 | 会话过期 | 「请重新登录」+ 去登录页 |
| 其余（5xx / 网络 / 解析失败） | 暂时不可用 | 「暂时打不开」+ **重试** |

## 3. 读写与缓存

- **读**：`useQuery`，key 用模块常量（`notesKey` / `noteKey(id)`），别在调用点拼字符串。
- **写**：`useMutation`，成功后 `invalidateQueries({ queryKey: <模块 key> })`。
- **401 不是错误，是「没登录」**：client 抛的 `ApiError` 带 `isUnauthenticated`，取当前用户的那个 query 把它翻译成 `null`，路由守卫据此跳登录。别让它冒成一个红色的错误页。
- 默认 `retry: false`：401 / 404 是答案不是抖动，重试只是让屏幕晚点出来。

## 4. Server / Client 边界（本轨没有）

这是纯 SPA，**没有** Server Component、没有 Server Action、没有 `"use client"`。从 Next.js 轨搬代码时把这些指令删掉——它们在 Vite 里不报错，只是毫无作用，留着会让人以为存在一条并不存在的边界。

对应地：**没有 `useFormStatus`**。pending 状态由 `mutation.isPending` 显式传给 `SubmitButton`。

## 5. Hooks

- 守 Rules of Hooks；`react-hooks/exhaustive-deps` 警告**当失败处理**（eslint 里已配成 error）。
- `useEffect` 只用于同步外部系统（订阅 / 计时器 / 浏览器 API）。**不用于**派生值、**不用于把 props 或查询结果镜像进 state**。
  - 需要用加载到的数据初始化表单时，**把表单拆成子组件**并用 `useState(props.x)` 初始化，父组件在数据到位后才渲染它。用 effect 去 `setState` 会造成级联渲染，`eslint-plugin-react-hooks` 会直接报错。
- 建订阅 / 计时器 / 请求**必清理**。
- 默认不加 `useMemo` / `useCallback` / `memo`，profile 证明有成本再加。

## 6. 组件复用顺序

新 UI 按顺序找：

1. `components/ui/*`（shadcn 基础件）
2. `components/{data,forms,app}/*`（patterns 层）——列表 `DataTable`、筛选 `FilterBar`、空态 `EmptyState`、状态 `StatusBadge`、删除/高危确认 `ConfirmDialog`、页头 `PageHeader`、表单行 `FormRow`
3. 都不满足才新建

**禁止重复实现已有组件。** 删除确认用 `ConfirmDialog`，**别用 `window.confirm`**。页面固定结构见 `design-system/MASTER.md` §6。

## 7. 表单

- 受控 state + `onSubmit` 调 mutation。
- `<form>` 加 `noValidate`——关掉浏览器原生英文校验气泡，**校验结果以后端返回的为准**。
- 字段包 `FormRow`（label + 必填星号 + 内联错误），提交用 `SubmitButton` 并传 `pending`。
- 错误来自 `mutation.error?.message`（即后端 `problem+json` 的 `detail`），内联展示；成功用 `sonner` toast。

> 「校验结果以后端为准」说的是**这一层怎么显示错误**，不是「整个系统只在后端校验」。授权在服务端、不变量由数据库兜底——见 [`../guides/cross-layer.md`](../guides/cross-layer.md)。

## 8. 弹框 / 抽屉的关闭行为

凡是 `Dialog` / `Sheet` 内含**表单录入、密码或密钥、textarea、批量选择、执行确认，或其它未提交状态**，必须禁用外部点击关闭（Base UI 用 `disablePointerDismissal`，或在 `onOpenChange` 里拦 `reason === "outside-press"`），只允许明确的取消 / 关闭 / 提交路径。

纯导航、菜单、Popover、Tooltip、只读预览**可以**保留外部点击关闭。

## 9. 主题与视觉

- 改界面观感（颜色 / 字号 / 状态呈现 / 徽章与图标）前先读 `design-system/MASTER.md`。
- **色值单源在 `src/styles/globals.css` 的 `@theme`**；令牌之外不新造色值、阴影、任意字号。
- 徽章只给**真实状态**（词表在 `src/lib/status.ts`）。
- 把 `Link` 当按钮时用 `buttonVariants({...})` 作 className（Base UI 无 `asChild`）。
- **字体 vendored**，禁 Google Fonts / 任何 CDN 字体——内网或离线构建会直接失败。
- **任何密钥不得进 `VITE_*`**：Vite 把 `VITE_` 前缀的值内联进浏览器包。本轨前端根本不需要密钥（同源 + httpOnly cookie）。

## 10. 路由与深链

React Router declarative 模式。**每一条路由都必须能被冷加载**（直接粘地址栏 + 刷新），因为后端为 SPA 做了兜底。

新增路由时顺手在 E2E 里覆盖一次冷加载——这个坑在 `pnpm dev` 下**永远复现不了**（Vite 自带 history fallback），只存在于打包产物里。见 [`../testing/index.md`](../testing/index.md)。

客户端路由守卫（`RequireAuth`）只决定**渲染什么**，不构成授权。授权是后端的事。

## 11. 可访问性

- 优先语义 HTML（真 `button` / `a`，别用可点 `div`）。
- 每个交互控件有可访问名；图标按钮必配 `aria-label` + `ActionTooltip`。
- 键盘可达 + 焦点可见。
- 表格里给行内操作起**唯一且具体**的可访问名（`Edit <标题>`），否则测试选择器会撞上同名单元格。

## 12. 与 task prd.md 的关系

- **字段与规则是实现和验收源真**：`prd.md` 的字段表与规则描述必须被实现和测试覆盖。不得静默遗漏字段，或改变字段的业务含义、类型/控件、必录性、默认值、可编辑性、枚举、长度/范围与规则约束。
- **页面结构仅作 UI 参考**：在不遗漏字段、操作能力和业务行为的前提下，可调整页面/弹窗/抽屉形态、入口、区域分组、字段顺序与布局。**不把纯呈现差异当成需求不一致。**
- **行为边界仍受规则约束**：形态变化若影响返回/取消、未保存状态、深链访问、关闭限制等行为，以 `prd.md` 的规则描述为准；规则未覆盖且会改变产品行为时，先回去把需求说清楚。

---

## Pre-Development Checklist

动手写前端代码前逐条过：

- [ ] 这次要调后端吗？走的是 `lib/api/client.ts` 吗？有没有在组件里裸 `fetch`？
- [ ] 加的是签出也能到达的表单吗？CSRF bootstrap 没回来之前禁用提交了吗（§2.1）
- [ ] 错误分支把 401 / 5xx / 网络故障和真正的 404 分开了吗？（§2.2）
- [ ] 用到的数据类型是从 `schema.d.ts` 派生的吗？后端改过 API 的话，重新跑过 `pnpm api:types` 了吗？
- [ ] 要用的东西在 `components/ui/*` 或 `components/{data,forms,app}/*` 里已经有了吗？（复用顺序见 §6）
- [ ] 有没有用 `useEffect` 把查询结果镜像进 state？（改成子组件 + `useState` 初始化）
- [ ] 从 Next.js 轨抄来的代码里，`"use client"` / server action / `useFormStatus` 都清掉了吗？
- [ ] 要新增色值 / 阴影 / 字号吗？**不允许**——先读 `design-system/MASTER.md`
- [ ] 新增路由了吗？E2E 里补一条**冷加载**用例（dev 下永远是绿的）
- [ ] 这一屏的主操作是哪个？说不出来说明信息架构没想清楚

## Quality Check

```bash
pnpm -C frontend typecheck && pnpm -C frontend lint && pnpm -C frontend test && pnpm -C frontend build
```

改过样式/格式再加 `pnpm -C frontend format`；改过页面/流程再加 E2E（**必须先 `./gradlew :backend:bootJar`**，跑在打包产物上）。完整门见 [`../testing/index.md`](../testing/index.md)。

额外自检：

- [ ] 列表 key 用的是稳定 id，不是数组下标
- [ ] 交互控件都是语义 HTML，键盘可达、焦点可见
- [ ] `react-hooks/*` 零报错（deps 与 set-state-in-effect 都已配成 error）
- [ ] 含未提交状态的 Dialog / Sheet 已禁用外部点击关闭
- [ ] 没有任何密钥出现在 `VITE_*` 变量里

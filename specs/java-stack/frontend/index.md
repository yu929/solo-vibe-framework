# 前端规范 · Java Stack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；API 契约的另一半在 [`../backend/index.md`](../backend/index.md)。

## 速查

| 主题 | 规则 |
|---|---|
| 调后端 | **只经 `src/lib/api/client.ts`**，组件里不裸 `fetch` |
| 数据类型 | 从 `src/lib/api/schema.d.ts` 派生，**不手写、不手改** |
| 读 / 写 | TanStack Query 的 `useQuery` / `useMutation`，写完 `invalidateQueries` |
| 加 UI 组件 | 直接 `import { X } from "antd"`；图标 `@ant-design/icons` |
| 复用顺序 | `antd` → `{data,forms,app}/*` → 都不满足才新建 |
| 表单 | antd `<Form>` + `<Form.Item>`，pending 由 `mutation.isPending` 显式传入 |
| 提示 / 弹窗 | `App.useApp()` 取 `message` / `modal`，**不用 antd 的静态方法** |
| 色值字号 | 只在 `src/styles/theme.ts`，取值用 `theme.useToken()` |
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

**第二扇门：登出。** 登出会**删掉 XSRF-TOKEN cookie**（Spring 连同会话一起清掉 CSRF token），所以登出之后到下一次 `/auth/me` 回来之前，应用手里没有可用的 token。于是「登出后立刻用另一个账号登进来」——换账号最常见的走法——会拿到 403。

这一条**卡在登出的 `onSuccess` 怎么写**：只 `clear()`，**不要** `setQueryData(currentUserKey, null)`。播种等于让 `useCurrentUser()` 在**一次请求都没发**的情况下报 `isPending: false`，上面那道 bootstrap 守卫就被关掉了，而 cookie 还不存在。留空缓存则登录页会重新去取 `/auth/me`，那次请求正是重新签发 cookie 的动作，期间表单保持禁用。

**验收**：登出后立刻用同一个账号登回去，断言进得了应用——而不是停在登录页上举着一个看不懂的 403。

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

### 3.1 换账号：清缓存，并且告诉其他标签页

**登录成功要 `clear()` 再塞新值，不是 `invalidateQueries()`。** invalidate 只把上一个账号的数据标成「陈旧」，它还在缓存里——于是以新身份登录后的**第一帧**渲染的是前任的数据，等重新请求回来才换掉。登录恰恰是「这些数据一条都不能再用」的那一刻。

**登出不对称：只 `clear()`，不塞值。** 这一条看着像上面那条的镜像，其实相反，所以单独写出来。登录时手上有刚拿到的用户对象、会话也刚建立，塞进去是省掉一次往返；登出之后没有任何东西可塞，而塞一个 `null` 会让 `useCurrentUser()` 在**一次请求都没发**的情况下报 `isPending: false`，把 §2.1 那道 CSRF bootstrap 守卫关掉——**而登出恰恰刚把 XSRF-TOKEN cookie 删掉**。理由与验收在 §2.1。

**更麻烦的一半：React Query 的缓存只活在一个标签页里。**

在标签页 A 登出，清掉的是 A 的缓存。标签页 B 停在列表页上，而且**没有任何东西会去纠正它**——`refetchOnWindowFocus` 是关掉的（这本身是对的：为一个没变的屏幕在每次切换焦点时发一轮请求不划算）。所以 B 会继续渲染一个已经不存在的会话下取到的行；这时在同一个浏览器里换个账号登录，B 就变成了**一个人的名字旁边显示着另一个人的数据**，而且没有任何请求会把它纠正过来。

**做法**：登录和登出都往 `BroadcastChannel` 发一条消息，其他标签页收到就 **整页 reload**。

reload 看着粗暴，但它是这里最诚实的响应：一次性丢掉所有内存态，不需要我们永远正确地记住「app 里还有哪些缓存要清」；而且换账号的场景里，它顺带让那个标签页接上**新**会话。

三个具体的坑：

- **收发要用同一个 channel 对象。** `BroadcastChannel` 排除的是**发消息的那个 channel 对象**，不是它所在的标签页。用一个临时的 `new BroadcastChannel(...)` 发消息，自己的监听器照样会收到，于是刚登录/登出的这个标签页把自己 reload 一遍。**功能上仍然「能用」，所以极容易漏掉。**
- **订阅要在首次渲染之前建立**。别的标签页可能在这一页加载的过程中就登录或登出了，而这个 reload 必须跟落在哪条路由无关。
- **老浏览器没有 `BroadcastChannel`**（2022 年前的 Safari），要判存在再用。

**服务端不受这条影响**——陈旧标签页发出的请求照样 401。这一节从头到尾说的是**不要把上一个会话的数据继续显示出来**。

**验收**：一个浏览器 context 开**两个** page（同 cookie、同会话、各自独立的 JS），在其中一个登出，断言另一个自己去了登录页且看不到那份数据；再断言**发起的那个没有重新加载过**（在它的 `window` 上打个标记，reload 会抹掉它）。

## 4. Server / Client 边界（本轨没有）

这是纯 SPA，**没有** Server Component、没有 Server Action、没有 `"use client"`。从 Next.js 轨搬代码时把这些指令删掉——它们在 Vite 里不报错，只是毫无作用，留着会让人以为存在一条并不存在的边界。

对应地：**没有 `useFormStatus`**。pending 状态由 `mutation.isPending` 显式传给按钮的 `loading` 与 `<Form disabled>`。

## 5. Hooks

- 守 Rules of Hooks；`react-hooks/exhaustive-deps` 警告**当失败处理**（eslint 里已配成 error）。
- `useEffect` 只用于同步外部系统（订阅 / 计时器 / 浏览器 API）。**不用于**派生值、**不用于把 props 或查询结果镜像进 state**。
  - 需要用加载到的数据初始化表单时，**把表单拆成子组件**并用 `useState(props.x)` 初始化，父组件在数据到位后才渲染它。用 effect 去 `setState` 会造成级联渲染，`eslint-plugin-react-hooks` 会直接报错。
- 建订阅 / 计时器 / 请求**必清理**。
- 默认不加 `useMemo` / `useCallback` / `memo`，profile 证明有成本再加。

## 6. 组件复用顺序

新 UI 按顺序找：

1. **antd**——`Button` / `Card` / `Form` / `Input` / `Select` / `Table` / `Modal` / `Tooltip` / `Skeleton` / `Empty` / `Badge` / `Typography` / `Flex` / `Space`…装 antd 就是为了不自己攒这些，**先翻它的文档**
2. `components/{data,forms,app}/*`（patterns 层，只放 antd 没有的）——列表 `DataTable`、筛选 `FilterBar`、空态 `EmptyState`、状态 `StatusBadge`、删除/高危确认 `ConfirmDialog`、页头 `PageHeader`、登录壳 `AuthForm`
3. 都不满足才新建

**禁止重复实现已有组件。** 删除确认用 `ConfirmDialog`，**别用 `window.confirm`**。页面固定结构见 `design-system/MASTER.md` §6。

**布局用 antd 的 `Flex` / `Space` / `Row·Col`**，一次性的间距用 `style`。本轨没有工具类 CSS 框架——想写 `className="mt-4"` 说明你在找一个不存在的东西。

`DataTable` 是 antd `Table` 加本项目默认值的**薄封装**，不是替代品：`size`、空态和「`rowKey` 必填」定在那里，其余 props 直通 antd。查用法翻 antd 文档，不要去读那个封装。

## 7. 表单

- antd `<Form layout="vertical">` + `onFinish` 调 mutation；`<Form disabled={pending}>` 一次性禁用整组控件。
- 字段用 `<Form.Item name label>`（label + 必填星号 + 内联错误一体），提交用 `<Button type="primary" htmlType="submit" loading={mutation.isPending}>`。
- **客户端 `rules` 只挡明显不可用的输入**（必填、格式），**准入判定以后端返回的为准**。
- 服务端错误来自 `mutation.error?.message`（即后端 `problem+json` 的 `detail`），经 `Form.Item` 的 `validateStatus` + `help` 内联展示；成功用 `App.useApp()` 的 `message`。
- **`help` 里的服务端错误必须包成 live region**（`components/forms/field-error.tsx` 的 `fieldError()`，内部就是 `<span role="alert">`）。antd 只给输入框挂 `aria-describedby` + `aria-invalid`——那在焦点**在**字段里时是对的，但提交后才回来的错误，焦点还停在提交按钮上，一个只是被"关联"到别处的描述**永远不会被念出来**。于是登录失败对读屏用户是彻底静默的，而这恰恰是最需要被告知的一次。
- **别给 `<Input>` 写 `type="email"`** —— 那会触发浏览器自带的英文校验气泡（旧版靠 `<form noValidate>` 关掉的正是它）。格式校验写成 `rules: [{ type: "email" }]`。
- **`<Form>` 不要设 `name`**，除非确实需要多表单隔离：设了之后每个字段的 DOM id 会变成 `<formName>_<field>`，按 id 选择的测试与深链锚点会一起断。

> 「以后端为准」说的是**谁裁决**，不是「客户端一行校验都不许写」。授权在服务端、不变量由数据库兜底——见 [`../guides/cross-layer.md`](../guides/cross-layer.md)。

## 8. 弹框 / 抽屉的关闭行为

凡是 `Modal` / `Drawer` 内含**表单录入、密码或密钥、textarea、批量选择、执行确认，或其它未提交状态**，必须 `maskClosable={false}`，只允许明确的取消 / 关闭 / 提交路径。Esc 保持可用——它是键盘上的「取消」，不是误触。

纯导航、菜单、Popover、Tooltip、只读预览**可以**保留外部点击关闭。

## 9. 主题与视觉

- 改界面观感（颜色 / 字号 / 状态呈现 / 徽章与图标）前先读 `design-system/MASTER.md`。
- **色值单源在 `src/styles/theme.ts`**（antd `ConfigProvider` 的 `token` + `components`）；令牌之外不新造色值、阴影、任意字号。`globals.css` 只剩 `@font-face` 和 token 表达不了的东西。
- 组件里取 token 用 **`theme.useToken()`**，key 有类型检查；**不要写 `var(--ant-…)`**——那需要显式开 `cssVar`，且变量名拼错是静默失效（颜色直接没有，不报错）。
- 徽章只给**真实状态**（词表在 `src/lib/status.ts`），用 `<Badge color>`；**别用 `<Badge status="processing">`**，它自带涟漪动画，会把"这是什么状态"说成"正在发生什么"。
- 行内的跳转入口用**裸 `<Link>` + `aria-label`**（外面可以套 `Tooltip`）。**别拿 `<Button>` 包 `<Link>`**：可及元素会变成按钮，链接语义与按 role 的选择器一起失效。裸 `<a>` 的颜色、hover/active、focus-visible 由 antd 的 reset 按 `colorLink` 给出，不用自己写——但 **`colorLink` 派生自 `colorInfo` 而不是 `colorPrimary`**，改品牌色不会带着链接一起走。
- **筛选控件要显式声明自己占用的 query key**（`<FilterBar names={[…]}>`）。URL 是共享地盘：分页、排序也住在那里，把所有 query key 都当筛选，Reset 就会连页码和排序一起清掉，而一个光秃秃的 `?page=3` 还会让 Reset 亮起来。
- **字体 vendored**，禁 Google Fonts / 任何 CDN 字体——内网或离线构建会直接失败。
- **任何密钥不得进 `VITE_*`**：Vite 把 `VITE_` 前缀的值内联进浏览器包。本轨前端根本不需要密钥（同源 + httpOnly cookie）。

### 9.1 antd 的静态方法读不到 provider

`message.success()` / `Modal.confirm()` / `notification.open()` 这三个从 antd **直接 import** 的静态版本，渲染在 React 树之外，因此 **读不到 `ConfigProvider` 的主题，也读不到 locale**。

症状是「别处主题都对，就这个提示条/确认框不对」——而且**不报错、不警告**，看起来只是没调好样式。

**做法**：`main.tsx` 里在 `ConfigProvider` 内侧包一层 antd 的 `<App>`，组件里一律 `const { message, modal } = App.useApp();`。本仓自己的 `App`（路由根）与 antd 的 `App` 重名，import 时给后者起别名。

### 9.2 locale 决定的是一整套文案，不只是 antd 那半套

`ConfigProvider` 的 `locale`（连同 `dayjs` 的 locale）管的是分页、`Empty`、`Select` 的"无数据"、日期选择器、`Popconfirm` 这些**内建**文案。**产品自己写的文案不受它影响。**

所以这两半必须同一种语言。骨架自带的 `notes` 样例是英文的，而 `locale` 是 `zh_CN`——**那是样例的性质，不是范式**：样例整块会被真实功能替换掉，`locale` 会留下。**接手真实项目时先对齐这两半**，别让列表长到出现分页时，页面上一半中文一半英文。

## 10. 路由与深链

React Router declarative 模式。**每一条路由都必须能被冷加载**（直接粘地址栏 + 刷新），因为后端为 SPA 做了兜底。

新增路由时顺手在 E2E 里覆盖一次冷加载——这个坑在 `pnpm dev` 下**永远复现不了**（Vite 自带 history fallback），只存在于打包产物里。见 [`../testing/index.md`](../testing/index.md)。

客户端路由守卫（`RequireAuth`）只决定**渲染什么**，不构成授权。授权是后端的事。

## 11. 可访问性

- 优先语义 HTML（真 `button` / `a`，别用可点 `div`）。
- 每个交互控件有可访问名；图标按钮必配 `aria-label` + `Tooltip`。
- 键盘可达 + 焦点可见。
- **异步出现的错误要能被读屏播报**：光有 `aria-describedby` 不够（见 §7）。
- **正文字号的文字对白底至少 4.5:1。** `colorTextTertiary` 达不到，它只作装饰——判据与取舍写在 `design-system/MASTER.md` §2。
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
- [ ] 要用的东西 antd 里已经有了吗？`components/{data,forms,app}/*` 里呢？（复用顺序见 §6）
- [ ] 同类屏在 `docs/discovery/wireframe/*/final/` 里有既有结构吗？沿用还是偏离，偏离说得出理由吗？
- [ ] 有没有用 `useEffect` 把查询结果镜像进 state？（改成子组件 + `useState` 初始化）
- [ ] 动了登录/登出流程吗？登录 `clear()` 后塞新值、登出只 `clear()` 不塞（§3.1），并且都广播给了其他标签页
- [ ] 动了登出吗？「登出后立刻登回来」还进得去应用，而不是一个 403 吗？（§2.1 第二扇门）
- [ ] 从 Next.js 轨抄来的代码里，`"use client"` / server action / `useFormStatus` 都清掉了吗？
- [ ] 要新增色值 / 阴影 / 字号吗？**不允许**——先读 `design-system/MASTER.md`，改 `src/styles/theme.ts`
- [ ] 用到提示条或确认框了吗？是从 `App.useApp()` 取的，不是 antd 的静态方法吧？（§9.1）
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
- [ ] 含未提交状态的 Modal / Drawer 已 `maskClosable={false}`
- [ ] 没有任何密钥出现在 `VITE_*` 变量里

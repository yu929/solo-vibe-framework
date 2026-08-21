# 前端规范 · Java Stack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)；API 契约的另一半在 [`../backend/index.md`](../backend/index.md)。

> ### ⚠️ 本页有几节尚未实跑验证
>
> 标着 **⚠️ 待实跑验证** 的是「做法」，跑通一次就回来把它改成结论。同一节里的「症状 + 验收」有实跑证据，可以直接依赖。
>
> **starter 仓 `java-stack/frontend/` 的骨架与本页规定的数据层不一致**，照本页开工会立刻撞上。

## 速查

| 主题 | 规则 |
|---|---|
| 调后端 | **只经 `dataProvider` / `authProvider`**，组件里不裸 `fetch`，也不直接 `useQuery` 打接口 |
| 数据类型 | 从 `src/lib/api/schema.d.ts` 派生，**不手写、不手改** |
| 读 / 写 | ra-core 的 `useGetList` / `useGetOne` / `useCreate` / `useUpdate` / `useDelete` |
| 加 UI 组件 | `pnpm dlx shadcn@latest add <name>`，**勿手改 `components/ui/*`** |
| 复用顺序 | `components/admin/*` → `components/ui/*` → `{data,forms,app}/*` → 都不满足才新建 |
| 表单 | shadcn-admin-kit 的 `<SimpleForm>` + `<TextInput>` 等，底层是 React Hook Form |
| 色值字号 | 只在 `src/styles/globals.css` 的 `@theme`；令牌之外不新造 |
| 列表 key | 稳定 id，**别用数组下标** |
| 操作列 / 分页 | 业务上不可执行的**不渲染**；只有 pending 这类暂时状态才保留并禁用 |
| Select 选项 | 8 个及以上默认按标签搜索；多选须有明确集合语义与 API 契约 |
| 记忆化 | 默认不加 `useMemo/useCallback/memo`，profile 证明有成本再加 |

## 1. 所有后端调用收口在 provider

**ra-core 的 `dataProvider` 是唯一数据出口，`authProvider` 是唯一认证出口。** 两样东西住在那里，不许在调用点重新实现：

1. **CSRF**：非安全方法自动带 `X-XSRF-TOKEN`（值取自 `XSRF-TOKEN` cookie）。漏了就是 403，而 403 长得像权限问题，会把人引去查授权。
2. **错误归一化**：后端回 RFC 9457 `problem+json`，provider 把它变成 ra-core 认得的错误形状，页面只渲染一种东西。

**收口必须落在 provider 上**：ra-core 的所有 hook 最终都走 provider，把逻辑放在别处等于漏掉一半调用点。

**禁止在组件里裸 `fetch`，也禁止绕开 provider 直接 `useQuery` 打接口。** 每个绕过的调用点都要自己记得 CSRF 和错误形状，而漏掉的那个不会在写的时候报错。

**`<Resource>` 声明是路由与数据的绑定处**，一个后端资源对应一条 `<Resource name list edit create>`。别为同一个资源在两处各声明一次。

## 2. 类型来自后端，不是手写的

```ts
import type { components } from "./schema";
export type Note = Required<components["schemas"]["NoteResponse"]>;
```

`schema.d.ts` 由 `pnpm api:types` 从后端 `/v3/api-docs` 生成，**不手改**。后端 DTO 改了字段名而前端没跟上时，**typecheck 直接失败**——这正是要的效果。手写一份平行的 interface 就把这层保护关掉了，改名会变成运行时的 `undefined`。

**`Required<>` 是有意的**：springdoc 只在属性带 Bean Validation 注解时才标 `required`，响应 DTO 通常不带，于是生成的类型全是可选。这些列在库里都是 `NOT NULL`，API 确实总会给。

改了后端 API：重新生成 → `pnpm typecheck` → 按报错改。**别反过来手改 `schema.d.ts` 让它编译过。**

**ra-core 要求每条记录有 `id` 字段。** 后端主键不叫 `id` 时在 `dataProvider` 里映射，**不要在组件里改**——映射散开之后，「这个资源的 id 到底是哪个字段」就没有单一答案了。

## 2.1 CSRF 冷启动：签出可达的表单要等 bootstrap

登录页和注册页是**唯一在拿到 `XSRF-TOKEN` cookie 之前就能被提交**的两个界面（其余页面都在路由守卫后面，`/auth/me` 早就回来了）。

密码管理器瞬间填好两个字段、或者手快的人直接回车，就会发出一个**没有 CSRF 头的 POST**，拿到 403 —— 而 403 在登录页上看起来就是「密码错了」。

**第二扇门：登出。** 登出会**删掉 XSRF-TOKEN cookie**（Spring 连同会话一起清掉 CSRF token），所以登出之后到下一次 `/auth/me` 回来之前，应用手里没有可用的 token。于是「登出后立刻用另一个账号登进来」——换账号最常见的走法——会拿到 403。

**不要**改成「403 就自动重试一次」——那是拿重试掩盖竞态，真正的 CSRF 失败也会被一起吞掉。

> **⚠️ 待实跑验证 · 做法**
>
> 原则不变：**在 bootstrap 完成之前，登录表单必须处于禁用状态**，几十毫秒的禁用换掉一整类看不懂的 403。
>
> 落点应该在 `authProvider.checkAuth()` 与登录页之间——但 ra-core 的 `useAuthState()` 在「从未请求过」和「请求已返回未登录」这两个状态上怎么区分，**没有实跑证据**。
>
> 第一次跑通登录流程之后回来把这一段改成结论，并删掉这个标记。

**验收（这条是实跑证据，不随实现变）**：登出后立刻用同一个账号登回去，断言进得了应用——而不是停在登录页上举着一个看不懂的 403。

## 2.2 失败要分类，不要一律显示成「没找到」

把所有请求失败都渲染成「XX 不存在」是**内容层面的错误断言**：401（会话过期）、500、网络中断都会被说成「你的数据没了」。用户于是去找数据，而不是去重新登录或报障。

至少分三类，收口在 `dataProvider` 里一次：

| 判据 | 含义 | 界面 |
|---|---|---|
| 404 | 真的没有，或不属于这个账号 | 「不存在」+ 回列表 |
| 401 | 会话过期 | 「请重新登录」+ 去登录页 |
| 其余（5xx / 网络 / 解析失败） | 暂时不可用 | 「暂时打不开」+ **重试** |

**401 走 `authProvider.checkError()`，不要在 `dataProvider` 里自己跳转。** ra-core 收到 `checkError` 的 reject 会走它自己的登出流程；两处各跳一次会打架。

## 3. 读写与缓存

- **读**：`useGetList` / `useGetOne`。资源名是字符串常量，别在调用点拼。
- **写**：`useCreate` / `useUpdate` / `useDelete`。ra-core 自己管失效，**别再手动 `invalidateQueries`**——两套失效逻辑会互相覆盖。
- **401 不是错误，是「没登录」**：翻译成「去登录页」，别让它冒成一个红色的错误页。
- 默认 `retry: false`：401 / 404 是答案不是抖动，重试只是让屏幕晚点出来。

**TanStack Query 在 ra-core 下面，不直接用它打接口。** 它仍然是缓存实现，所以调试缓存问题要看它；但业务代码碰到它就说明绕开了 provider。

### 3.1 换账号：清缓存，并且告诉其他标签页

**登录成功要清干净上一个账号的缓存，不是标记为陈旧。** 只失效（invalidate）会把上一个账号的数据留在缓存里——于是以新身份登录后的**第一帧**渲染的是前任的数据，等重新请求回来才换掉。登录恰恰是「这些数据一条都不能再用」的那一刻。

**登出不对称：清空，但不要往缓存里塞一个「未登录」的值。** 这一条看着像上面那条的镜像，其实相反，所以单独写出来。登录时手上有刚拿到的用户对象、会话也刚建立；登出之后没有任何东西可塞，而塞一个空值会让「当前用户」这个查询在**一次请求都没发**的情况下显示成「已确定未登录」，把 §2.1 那道 CSRF bootstrap 守卫关掉——**而登出恰恰刚把 XSRF-TOKEN cookie 删掉**。

**更麻烦的一半：查询缓存只活在一个标签页里。**

在标签页 A 登出，清掉的是 A 的缓存。标签页 B 停在列表页上，而且**没有任何东西会去纠正它**——`refetchOnWindowFocus` 是关掉的（这本身是对的：为一个没变的屏幕在每次切换焦点时发一轮请求不划算）。所以 B 会继续渲染一个已经不存在的会话下取到的行；这时在同一个浏览器里换个账号登录，B 就变成了**一个人的名字旁边显示着另一个人的数据**，而且没有任何请求会把它纠正过来。

**做法**：登录和登出都往 `BroadcastChannel` 发一条消息，其他标签页收到就 **整页 reload**。

reload 看着粗暴，但它是这里最诚实的响应：一次性丢掉所有内存态，不需要我们永远正确地记住「app 里还有哪些缓存要清」；而且换账号的场景里，它顺带让那个标签页接上**新**会话。

三个具体的坑（**与前端框架无关**）：

- **收发要用同一个 channel 对象。** `BroadcastChannel` 排除的是**发消息的那个 channel 对象**，不是它所在的标签页。用一个临时的 `new BroadcastChannel(...)` 发消息，自己的监听器照样会收到，于是刚登录/登出的这个标签页把自己 reload 一遍。**功能上仍然「能用」，所以极容易漏掉。**
- **订阅要在首次渲染之前建立**。别的标签页可能在这一页加载的过程中就登录或登出了，而这个 reload 必须跟落在哪条路由无关。
- **老浏览器没有 `BroadcastChannel`**（2022 年前的 Safari），要判存在再用。

> **⚠️ 待实跑验证 · 落点**
>
> 上面三条坑和「清空 / 不塞值」的取舍不随实现变，但**具体调用哪个 API 没有实跑证据**：ra-core 下清缓存的正确入口，以及广播该挂在 `authProvider.login()` / `logout()` 还是别处，都要实跑确认。
>
> 第一次跑通换账号之后回来把这一段改成结论。

**服务端不受这条影响**——陈旧标签页发出的请求照样 401。这一节从头到尾说的是**不要把上一个会话的数据继续显示出来**。

**验收（实跑证据，不随实现变）**：一个浏览器 context 开**两个** page（同 cookie、同会话、各自独立的 JS），在其中一个登出，断言另一个自己去了登录页且看不到那份数据；再断言**发起的那个没有重新加载过**（在它的 `window` 上打个标记，reload 会抹掉它）。

## 4. Server / Client 边界（本轨没有）

这是纯 SPA，**没有** Server Component、没有 Server Action、没有 `"use client"`。从 Next.js 轨搬代码时把这些指令删掉——它们在 Vite 里不报错，只是毫无作用，留着会让人以为存在一条并不存在的边界。

对应地：**没有 `useFormStatus`**。pending 状态从 ra-core 的 mutation hook 上取，显式传给按钮。

## 5. Hooks

- 守 Rules of Hooks；`react-hooks/exhaustive-deps` 警告**当失败处理**（eslint 里已配成 error）。
- `useEffect` 只用于同步外部系统（订阅 / 计时器 / 浏览器 API）。**不用于**派生值、**不用于把 props 或查询结果镜像进 state**。
  - 需要用加载到的数据初始化表单时，**把表单拆成子组件**并用 `useState(props.x)` 初始化，父组件在数据到位后才渲染它。用 effect 去 `setState` 会造成级联渲染，`eslint-plugin-react-hooks` 会直接报错。
  - ra-core 的 `<Edit>` 已经处理了「等数据到位再渲染表单」，走它就不用自己拆。
- 建订阅 / 计时器 / 请求**必清理**。
- 默认不加 `useMemo` / `useCallback` / `memo`，profile 证明有成本再加。

## 6. 组件复用顺序

新 UI 按顺序找：

1. **`components/admin/*`**（shadcn-admin-kit）——`<List>` `<DataTable>` `<Edit>` `<Create>` `<SimpleForm>` `<TextInput>` `<SelectInput>` `<ReferenceField>` …**装它就是为了不自己攒 CRUD 页，先翻它的文档**
2. **`components/ui/*`**（shadcn 基础件）——`Button` `Card` `Input` `Select` `Dialog` `Tooltip` `Skeleton` `Badge` …用 `pnpm dlx shadcn@latest add <name>` 装，**勿手改**
3. `components/{data,forms,app}/*`（patterns 层，只放上面两层都没有的）——筛选 `FilterBar`、空态 `EmptyState`、状态 `StatusBadge`、页头 `PageHeader`、登录壳 `AuthForm`
4. 都不满足才新建

**禁止重复实现已有组件。** 删除确认用 admin kit 的确认流程，**别用 `window.confirm`**。页面固定结构见 `design-system/MASTER.md` §6。

**布局用 Tailwind 工具类。** 一次性的间距直接写类名，不新造 CSS 文件。

**`components/ui/*` 是 shadcn CLI 的产物，改了就跟不上上游。** 要改行为就在 `components/{data,forms,app}/` 里包一层，别动生成物——这条和 vendor 只读是同一个道理。

**操作列只渲染当前身份与当前行状态下真实可执行的能力。** 业务上不适用、权限上被排除或当前状态没有意义的操作直接不渲染；不要用一排 disabled 按钮占位再靠 Tooltip 解释。分页同理：首页不渲染「首页 / 上一页」，末页不渲染「下一页 / 末页」，空结果不渲染翻页控件。异步请求进行中是另一类状态：入口已经存在且操作已经发起，必须保持可见，用 loading / disabled 阻止重复提交并反馈进度。

**Select 有 8 个及以上选项时默认启用搜索，按可见标签过滤。** 多选不是视觉偏好：只有产品明确允许集合条件、API 定义了重复参数或数组且查询语义明确（通常同一字段内 OR）时才用多选。URL 筛选要能恢复全部已选值，Reset 仍只清理该筛选拥有的 key。

## 7. 表单

- 用 shadcn-admin-kit 的 `<SimpleForm>` + `<TextInput>` / `<SelectInput>` 等，底层是 React Hook Form。**别在 admin kit 的表单里再套一层自己的 RHF 实例**，两个 form context 会打架。
- **客户端校验只挡明显不可用的输入**（必填、格式），**准入判定以后端返回的为准**。
- 服务端错误来自 `problem+json` 的 `detail`，由 `dataProvider` 归一化后交给表单内联展示。
- **异步回来的字段错误必须包成 live region**（`<span role="alert">`）。只挂 `aria-describedby` + `aria-invalid` 在焦点**在**字段里时是对的，但提交后才回来的错误，焦点还停在提交按钮上，一个只是被「关联」到别处的描述**永远不会被念出来**。于是登录失败对读屏用户是彻底静默的，而这恰恰是最需要被告知的一次。
- **别给文本输入写 `type="email"`** —— 那会触发浏览器自带的英文校验气泡。格式校验交给表单的 validate。

> 「以后端为准」说的是**谁裁决**，不是「客户端一行校验都不许写」。授权在服务端、不变量由数据库兜底——见 [`../guides/cross-layer.md`](../guides/cross-layer.md)。

## 8. 弹框 / 抽屉的关闭行为

凡是 Dialog / Sheet 内含**表单录入、密码或密钥、textarea、批量选择、执行确认，或其它未提交状态**，必须禁用点击遮罩关闭，只允许明确的取消 / 关闭 / 提交路径。Esc 保持可用——它是键盘上的「取消」，不是误触。

纯导航、菜单、Popover、Tooltip、只读预览**可以**保留外部点击关闭。

## 9. 主题与视觉

- 改界面观感（颜色 / 字号 / 状态呈现 / 徽章与图标）前先读 `design-system/MASTER.md`。
- **色值单源在 `src/styles/globals.css` 的 `@theme`**（Tailwind v4）；令牌之外不新造色值、阴影、任意字号。
- 徽章只给**真实状态**（词表在 `src/lib/status.ts`）。**别给状态徽章加动画**——动画会把「这是什么状态」说成「正在发生什么」。
- 行内的跳转入口用**裸链接 + `aria-label`**（外面可以套 Tooltip）。**别拿按钮包链接**：可及元素会变成按钮，链接语义与按 role 的选择器一起失效。
- **筛选控件要显式声明自己占用的 query key**。URL 是共享地盘：分页、排序也住在那里，把所有 query key 都当筛选，Reset 就会连页码和排序一起清掉，而一个光秃秃的 `?page=3` 还会让 Reset 亮起来。
- **字体 vendored**，禁 Google Fonts / 任何 CDN 字体——内网或离线构建会直接失败。
- **任何密钥不得进 `VITE_*`**：Vite 把 `VITE_` 前缀的值内联进浏览器包。本轨前端根本不需要密钥（同源 + httpOnly cookie）。

## 10. 路由与深链

React Router declarative 模式，ra-core 的 `<Resource>` 在它之上。**每一条路由都必须能被冷加载**（直接粘地址栏 + 刷新），因为后端为 SPA 做了兜底。

新增路由时顺手在 E2E 里覆盖一次冷加载——这个坑在 `pnpm dev` 下**永远复现不了**（Vite 自带 history fallback），只存在于打包产物里。见 [`../testing/index.md`](../testing/index.md)。

客户端路由守卫只决定**渲染什么**，不构成授权。授权是后端的事。

## 11. 可访问性

- 优先语义 HTML（真 `button` / `a`，别用可点 `div`）。
- 每个交互控件有可访问名；图标按钮必配 `aria-label` + Tooltip。
- 键盘可达 + 焦点可见。
- **异步出现的错误要能被读屏播报**：光有 `aria-describedby` 不够（见 §7）。
- **正文字号的文字对白底至少 4.5:1。** 达不到的令牌只作装饰——判据与取舍写在 `design-system/MASTER.md` §2。
- 表格里给行内操作起**唯一且具体**的可访问名（`Edit <标题>`），否则测试选择器会撞上同名单元格。

## 12. 与 task prd.md 的关系

- **字段与规则是实现和验收源真**：`prd.md` 的字段表与规则描述必须被实现和测试覆盖。不得静默遗漏字段，或改变字段的业务含义、类型/控件、必录性、默认值、可编辑性、枚举、长度/范围与规则约束。
- **页面结构以本片定稿的高保真屏为准**：定稿路径由 `docs/discovery/slices.md` 切片清单第四列给出，并且**必须进 `implement.jsonl`**——实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件。
- **行为边界仍受规则约束**：形态变化若影响返回/取消、未保存状态、深链访问、关闭限制等行为，以 `prd.md` 的规则描述为准；规则未覆盖且会改变产品行为时，先回去把需求说清楚。

---

## Pre-Development Checklist

动手写前端代码前逐条过：

- [ ] 这次要调后端吗？走的是 `dataProvider` / `authProvider` 吗？有没有裸 `fetch` 或绕开 provider 的 `useQuery`？
- [ ] 加的是签出也能到达的表单吗？CSRF bootstrap 没回来之前禁用提交了吗（§2.1）
- [ ] 错误分支把 401 / 5xx / 网络故障和真正的 404 分开了吗？401 走的是 `checkError` 吗？（§2.2）
- [ ] 用到的数据类型是从 `schema.d.ts` 派生的吗？后端改过 API 的话，重新跑过 `pnpm api:types` 了吗？
- [ ] 要用的东西 `components/admin/*` 里已经有了吗？`components/ui/*` 呢？（复用顺序见 §6）
- [ ] **本片的高保真定稿屏进 `implement.jsonl` 了吗？**（`slices.md` 第四列；漏了没有症状）
- [ ] 列表操作或分页边界有业务上不可执行的按钮吗？直接不渲染；pending 等暂时状态才保留 disabled/loading（§6）
- [ ] Select 达到 8 个选项了吗？启用按标签搜索；若要多选，API 和 URL 已有明确集合语义吗？（§6）
- [ ] 有没有用 `useEffect` 把查询结果镜像进 state？（改成子组件 + `useState` 初始化，或直接用 `<Edit>`）
- [ ] 动了登录/登出流程吗？缓存清干净了、登出没往缓存里塞空值、并且都广播给了其他标签页（§3.1）
- [ ] 动了登出吗？「登出后立刻登回来」还进得去应用，而不是一个 403 吗？（§2.1 第二扇门）
- [ ] 改了 `components/ui/*` 吗？**不允许**——要改行为在 patterns 层包一层（§6）
- [ ] 从 Next.js 轨抄来的代码里，`"use client"` / server action / `useFormStatus` 都清掉了吗？
- [ ] 要新增色值 / 阴影 / 字号吗？**不允许**——先读 `design-system/MASTER.md`，改 `globals.css` 的 `@theme`
- [ ] 新增路由了吗？E2E 里补一条**冷加载**用例（dev 下永远是绿的）
- [ ] 这一屏的主操作是哪个？说不出来说明信息架构没想清楚

## Quality Check

```bash
pnpm -C frontend typecheck && pnpm -C frontend lint && pnpm -C frontend test && pnpm -C frontend build
```

改过样式/格式再加 `pnpm -C frontend format`；改过页面/流程再加 E2E（**必须先 `./gradlew :backend:bootJar`**，跑在打包产物上）。完整门见 [`../testing/index.md`](../testing/index.md)。

额外自检：

- [ ] 列表 key 用的是稳定 id，不是数组下标
- [ ] 操作列与分页没有业务上不可执行的 disabled 占位；pending 反馈仍可见
- [ ] 8 个及以上选项的 Select 可按标签搜索；多选筛选可从 URL 完整恢复
- [ ] 交互控件都是语义 HTML，键盘可达、焦点可见
- [ ] `react-hooks/*` 零报错（deps 与 set-state-in-effect 都已配成 error）
- [ ] 含未提交状态的 Dialog / Sheet 已禁用点击遮罩关闭
- [ ] `components/ui/*` 没有被手改
- [ ] 没有任何密钥出现在 `VITE_*` 变量里

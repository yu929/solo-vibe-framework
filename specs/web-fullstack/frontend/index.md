# 前端规范 · Web Fullstack 轨

> 每类只许一种做法。轨总览与禁止清单见 [`../README.md`](../README.md)。

## 速查

| 主题 | 规则 |
|---|---|
| 新组件默认 | Server Component；要 state/effect/ref/浏览器 API/事件才 `"use client"` |
| 加 UI 组件 | `pnpm dlx shadcn@latest add <name>`，勿手改 `src/components/ui/*` |
| 复用顺序 | `ui/*` → `{data,forms,app}/*` → 都不满足才新建 |
| 表单 | `useActionState` + server action，`<form noValidate>` |
| 列表 key | 稳定 id，**别用数组下标** |
| 记忆化 | 默认不加 `useMemo/useCallback/memo`，profile 证明有成本再加 |

## 1. Server / Client 边界

新组件**默认 Server Component**。只有要 state / effect / ref / 浏览器 API / 事件处理时才加 `"use client"`（写首行）。server → client 只传可序列化值。

**绝不**把 DB client、密钥、server-only 模块 import 进 client。

**反向同样危险**：不从 `"use client"` 文件导出常量或纯函数给 server 端 import——它会变成 client reference 静默失效（例如 `.limit(N)` 拿到的不是数值），**typecheck 和 build 都不报错，只有运行时能发现**。共享常量与纯函数放 `src/lib/`。

## 2. 组件复用顺序

新 UI 按顺序找：

1. `components/ui/*`（shadcn 基础件）
2. `components/{data,forms,app}/*`（patterns 层）——列表 `DataTable`、筛选 `FilterBar`、空态 `EmptyState`、状态 `StatusBadge`、删除/高危确认 `ConfirmDialog`
3. 都不满足才新建

**禁止重复实现已有组件。** 删除确认用 `ConfirmDialog`，**别用 `window.confirm`**。页面固定结构见 `design-system/MASTER.md` §6。

## 3. 表单

- `useActionState` + server action
- `<form>` 加 `noValidate`——关掉浏览器原生英文校验气泡，**校验一律在 action 里做**
- 字段包 `FormRow`（label + 必填星号 + 内联错误），提交用 `SubmitButton`
- 校验失败经返回值 `{ error }` 内联展示；成功用 `sonner` toast / `revalidatePath`

> 注意「校验一律在 action 里做」说的是**这一层的表单校验实现放哪**，不是「整个系统只在这一层校验」。授权仍在服务端、数据不变量仍由数据库约束兜底——见 [`../guides/cross-layer.md`](../guides/cross-layer.md) 的「校验散落各层」。

## 4. 弹框 / 抽屉的关闭行为

凡是 `Dialog` / `Sheet` 内含**表单录入、密码或密钥、textarea、批量选择、执行确认，或其它未提交状态**，必须禁用外部点击关闭（Base UI 用 `disablePointerDismissal`），只允许明确的取消 / 关闭 / 提交路径。

纯导航、菜单、Popover、Tooltip、只读预览**可以**保留外部点击关闭。

## 5. Hooks

- 守 Rules of Hooks；`react-hooks/exhaustive-deps` 警告**当失败处理**
- `useEffect` 只用于同步外部系统（订阅 / 计时器 / 浏览器 API）。**不用于**派生值、把 props 镜像进 state、或该写在事件里的通知
- 建订阅 / 计时器 / 请求**必清理**
- 默认不加 `useMemo` / `useCallback` / `memo`，profile 证明有成本再加

## 6. React 组件组织

- 函数组件 + 组合
- state 默认就近，只上提到最近公共父
- 容器（取数 / 副作用）与展示（纯 props 渲染）分离
- 列表 key 用稳定 id，**别用数组下标**

## 7. 客户端取数

**不在 `useEffect` 里裸 `fetch`。** 读走 Server Component、写走 server action + `revalidatePath`——见 [`../backend/index.md`](../backend/index.md)。

## 8. 主题与视觉

- 改界面观感（颜色 / 字号 / 状态呈现 / 徽章与图标）前先读 `design-system/MASTER.md`
- **色值单源在 `src/app/globals.css` 的 `@theme`**；令牌之外不新造色值、阴影、任意字号
- 徽章只给**真实状态**（词表在 `src/lib/status.ts`）
- 把 `Link` 当按钮时用 `buttonVariants({...})` 作 className（Base UI 无 `asChild`）
- **暗色**：`next-themes` 只被 `sonner` 用来同步 toast 明暗，骨架没接切换器。要暗色就加 provider + toggle。**别因「看着多余」删 `next-themes`**——`sonner.tsx` 是生成文件且 import 了它，删了编译失败。

## 9. 可访问性

- 优先语义 HTML（真 `button` / `a`，别用可点 `div`）
- 每个交互控件有可访问名
- 键盘可达 + 焦点可见

## 10. 与 task prd.md 的关系

- **字段与规则是实现和验收源真**：`prd.md` 的字段表与规则描述必须被实现和测试覆盖。不得静默遗漏字段，或改变字段的业务含义、类型/控件、必录性、默认值、可编辑性、枚举、长度/范围与规则约束。
- **页面结构仅作 UI 参考**：在不遗漏字段、操作能力和业务行为的前提下，可调整页面/弹窗/抽屉形态、入口、区域分组、字段顺序与布局。**不把纯呈现差异当成需求不一致。**
- **行为边界仍受规则约束**：形态变化若影响返回/取消、未保存状态、深链访问、关闭限制等行为，以 `prd.md` 的规则描述为准；规则未覆盖且会改变产品行为时，先回去把需求说清楚。

---

## Pre-Development Checklist

动手写前端代码前逐条过：

- [ ] 这个组件默认是 **Server Component** 吗？加 `"use client"` 的理由说得出来吗（state / effect / ref / 浏览器 API / 事件）？
- [ ] 要用的东西在 `components/ui/*` 或 `components/{data,forms,app}/*` 里已经有了吗？（复用顺序见 §2）
- [ ] 同类屏在 `docs/discovery/wireframe/*/final/` 里有既有结构吗？沿用还是偏离，偏离说得出理由吗？
- [ ] 要新增色值 / 阴影 / 字号吗？**不允许**——先读 `design-system/MASTER.md`，令牌在 `globals.css` 的 `@theme`
- [ ] 有没有从 `"use client"` 文件往 server 端导出常量或纯函数？（会静默失效，typecheck 不报）
- [ ] 这一屏的主操作是哪个？说不出来说明信息架构没想清楚

## Quality Check

```bash
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

改过样式/格式再加 `pnpm format`；改过页面/流程再加 `pnpm test:e2e`。完整门见 [`../testing/index.md`](../testing/index.md)。

额外自检：

- [ ] 列表 key 用的是稳定 id，不是数组下标
- [ ] 交互控件都是语义 HTML（真 `button` / `a`），键盘可达、焦点可见
- [ ] `react-hooks/exhaustive-deps` 零警告
- [ ] 含未提交状态的 Dialog / Sheet 已禁用外部点击关闭

# 3 · 第三方 skill 与 MCP

> 三组东西：随本仓分发的六个已经装好了，完整 PRD skill 要自己装，shadcn 那套按项目装。

## 已经装好的六个

mattpocock 那六个都在本仓 `vendor/mattpocock-skills/`，[第 1 篇](01-trellis-skills.md)的软链一并做了：

| skill | 用在流程的哪一步 |
|---|---|
| `grill-with-docs` | 需求讨论。它等于 `grilling` 加 `domain-modeling`，**三个必须一起装**，它全文只有一句「Call the Skill tool twice」 |
| `grilling` / `grill-me` | 同上，也可以单独用 |
| `domain-modeling` | 术语落 `CONTEXT.md`，有取舍的决定落 `docs/adr/`。**这两个是唯一宿主**，别在 PRD 里再存一份 |
| `prototype` | 验字段那一步。**只用 LOGIC 分支** |
| `writing-for-agents` | 写项目 `AGENTS.md`，以及你自己写 skill 时 |

不需要跑 `npx skills add`。为什么必须**不装** `setup-matt-pocock-skills`（装了就有两个任务系统），以及其余「不装」的理由，见 [`../../references/third-party.md`](../../references/third-party.md)。

> 「`prototype` 只用 LOGIC 分支」是提示语，不是判定。 它第一步就是 "Pick a branch"，没有任何机制挡得住它选 UI 分支，而 UI 分支会在真项目路由里开几个变体，跟「全量高保真加设计系统」是两条路。发现它跑去 UI 分支就当场拉回来，并把这次记进 `references/third-party.md`。

## 步骤 1 · 装完整 PRD skill

`create-prd-skill` 上游没有许可证（`license: null`），不能 vendor 进本仓再分发，所以自己装：

```bash
git clone -b community/complexity-aware https://github.com/pmYangKun/create-prd-skill
cd create-prd-skill && python scripts/install_skill.py
```

分支选 `community/complexity-aware`：主干那份对任何需求都产出 14 章，complexity-aware 会按 L1–L4 分级裁剪深度。

产物落项目自己的 `docs/discovery/prd.md`，不进框架仓。

## 步骤 2 · 装 shadcn skill 与 MCP

两条轨的前端都是 shadcn 系。官方 skill 和 MCP 都**装进项目仓**，不走全局软链那套，所以每开一个新项目都要再来一次。

### 先判断这个项目够不够格

```bash
pnpm dlx shadcn@latest info --cwd frontend
```

它不依赖 Claude Code，秒出结果。看两行就够：

- `framework` 认出来了（`Next.js` 或 `Vite`，不是 `Manual`）
- `Configuration` 一节有内容，不是 `No components.json found`

**两条里缺一条就先别装。** 装了也只是个通用 registry 搜索。它拿不到你项目的内核、别名和已装组件，而那正是装它的理由。先把骨架跑通 `shadcn init`，再回来。

> java-stack 的 starter 现在不够格（2026-08-21 实测）：`frontend/` 认得出 Vite，但没有 `components.json`，也没检测到 Tailwind。要在这条轨上验证，先换骨架再装 MCP，顺序反了会白装。

### 够格了再装

在**项目根目录**跑，就是有 `package.json` 和 `components.json` 的那一层，**不是 `~/.claude`**：

```bash
pnpm dlx skills add shadcn/ui
```

```bash
pnpm dlx shadcn@latest mcp init --client claude
```

第二条会在项目根写 `.mcp.json`。装完重启 Claude Code，用 `/mcp` 确认 `shadcn` 连上了。

前端在子目录的项目（比如 java-stack 的 `frontend/`），要多传一个参数，因为 `.mcp.json` 没有工作目录字段：

```json
{ "mcpServers": { "shadcn": { "command": "npx", "args": ["shadcn@latest", "mcp", "--cwd", "frontend"] } } }
```

### 它解决的是什么

AI 凭记忆写出来的组件能编译、能渲染，错在组合方式和可访问性属性上，这类错不看文档发现不了。装了它，AI 就有地方查。

**怎么用是轨规范管的事**，正文在 `specs/<track>/frontend/index.md` 的复用顺序一节。没装也能开工：轨规范里写了没装时的替代动作，不会卡住，装了只是让 AI 少猜。

## 步骤 3 · 跟随 vendor 上游（平时不用做）

```bash
scripts/sync-vendor.sh --verify   # 只查本地有没有被改过，离线，秒回
scripts/sync-vendor.sh            # 再加上：上游动了没有
scripts/sync-vendor.sh --pull     # 读完 diff、确认要跟随，才更新
```

默认只读是有意的：自动跟随等于让别人的改动在你不知情时改变你的工作流。

**平时你不用手动跑这个。** `.github/workflows/sync-vendor.yml` 每晚会自己 diff 一次，内容真变了才开一个 PR 给你读（已在跑，连续多日成功，也真开过 PR）。手动跑的场合只剩一个：你现在就想知道上游动没动。

## 常见卡点

### 「shadcn 的 MCP 装到 `~/.claude` 去了」

`shadcn mcp init` 把 `.mcp.json` 写在**你跑命令时所在的目录**。在 `~/.claude` 里跑，它就写到那儿，而那**不是**全局配置。Claude Code 只从**项目根**读 `.mcp.json`。

它还会顺手在那个目录留下 `package.json`、`package-lock.json` 和一个几十 MB 的 `node_modules`。清掉这四样，回到项目根重跑。机制细节见 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)。

### 「要不要干脆装 user 级」

不要。MCP 的工具定义在每个 session 都占 context，而只有前端项目用得上它，后端 task 和框架仓吃这份开销没有回报。装 project 级，再让 starter 带着 `.mcp.json`，新项目就是免费的。

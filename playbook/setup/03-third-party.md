# 3 · 第三方 skill 与 MCP

> 这里要处理三组工具：本仓分发的六个 skill 已随软链装好，完整 PRD skill 需要自行安装，shadcn skill 和 MCP 则按项目安装。
>
> **步骤 1 必需，步骤 2、3 可选。** `create-prd-skill` 在主线上被直接调用，没有它「写完整 PRD」那一步没有替代动作；shadcn 那两样缺了仍能开工，轨规范里给了替代动作；vendor 跟随平时根本不用做。

## 已经装好的六个

mattpocock 那六个都在本仓 `vendor/mattpocock-skills/`，[第 1 篇](01-trellis-skills.md)的软链一并做了：

| skill | 用在流程的哪一步 |
|---|---|
| `grill-with-docs` | 需求讨论。它等于 `grilling` 加 `domain-modeling`，**三个必须一起装**，它全文只有一句「Call the Skill tool twice」 |
| `grilling` / `grill-me` | 同上，也可以单独用 |
| `domain-modeling` | 术语落 `CONTEXT.md`，有取舍的决定落 `docs/adr/`。**这两个是唯一宿主**，别在 PRD 里再存一份 |
| `prototype` | 验字段那一步。**只用 LOGIC 分支** |
| `writing-for-agents` | 写项目 `AGENTS.md`，以及你自己写 skill 时 |

不用再运行 `npx skills add`。`setup-matt-pocock-skills` 会引入第二套任务系统，因此明确不装；其他取舍见 [`../../references/third-party.md`](../../references/third-party.md)。

> 「`prototype` 只用 LOGIC 分支」只是一句提示，不会被程序校验。它的第一步是 "Pick a branch"，仍可能选择 UI 分支，在真实项目路由中创建多个变体，与后续的全量高保真流程冲突。发现选错时立即改回 LOGIC，并把实际情况记进 `references/third-party.md`。

## 步骤 1 · 装完整 PRD skill（必需）

[`../build/01-discovery.md`](../build/01-discovery.md) 步骤 2 直接用它产出 `docs/discovery/prd.md`，后面的高保真和切片都从这份完整 PRD 开始。这里没有降级路径：跳过后，AI 只能自行决定 PRD 结构，也不会按 L1–L4 调整深度。

`create-prd-skill` 上游没有许可证（`license: null`），本仓不能把它放进 vendor 再分发，只能自行安装：

```bash
git clone -b community/complexity-aware https://github.com/pmYangKun/create-prd-skill
cd create-prd-skill && python scripts/install_skill.py
```

使用 `community/complexity-aware` 分支。主干对所有需求都生成 14 章，complexity-aware 会按 L1–L4 调整深度。

产物落项目自己的 `docs/discovery/prd.md`，不进框架仓。

装完确认一次：`ls ~/.claude/skills/create-prd-skill`。

## 步骤 2 · 装 shadcn skill 与 MCP（可选）

两条轨的前端都是 shadcn 系。官方 skill 和 MCP 都**装进项目仓**，不走全局软链那套，所以每开一个新项目都要再来一次。

### 先判断这个项目够不够格

```bash
pnpm dlx shadcn@latest info --cwd frontend
```

这条命令不依赖 Claude Code，很快就会返回结果。检查两处：

- `framework` 认出来了（`Next.js` 或 `Vite`，不是 `Manual`）
- `Configuration` 一节有内容，不是 `No components.json found`

任一项不满足都先不要安装。此时工具拿不到项目内核、别名和已装组件，只能做通用 registry 搜索。先在项目骨架中跑通 `shadcn init`，再回来安装。

> 2026-08-21 实测，java-stack 的 starter 还不满足条件：`frontend/` 能识别为 Vite，但没有 `components.json`，也未检测到 Tailwind。要在这条轨上验证，先调整骨架，再安装 MCP。

### 够格了再装

在项目根目录运行，也就是包含 `package.json` 和 `components.json` 的那一层；不要在 `~/.claude` 中运行：

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

AI 凭记忆写出的组件可能可以编译和渲染，却在组合方式或可访问性属性上出错。装上 skill 和 MCP 后，它才有官方资料可查。

具体用法由轨规范管理，见 `specs/<track>/frontend/index.md` 的复用顺序一节。没有安装也能开工，规范中给了替代动作；安装后的主要收益是减少 AI 猜测。

## 步骤 3 · 跟随 vendor 上游（可选，平时不用做）

```bash
scripts/sync-vendor.sh --verify   # 只查本地有没有被改过，离线，秒回
scripts/sync-vendor.sh            # 再加上：上游动了没有
scripts/sync-vendor.sh --pull     # 读完 diff、确认要跟随，才更新
```

默认只读，避免上游改动在未经检查时直接改变本地工作流。

日常不用手动运行。`.github/workflows/sync-vendor.yml` 每晚检查一次，内容变化时才开 PR。该流程已连续成功运行，也真开过跟随上游的 PR，运行记录和三条设计取舍见 [`../../references/third-party.md`](../../references/third-party.md)。只有想立即确认上游是否变化时，才需要手动执行。

## 常见卡点

### 「shadcn 的 MCP 装到 `~/.claude` 去了」

`shadcn mcp init` 会把 `.mcp.json` 写到当前工作目录。在 `~/.claude` 中运行，它就写到那里，但这并不是全局配置；Claude Code 只从项目根读取 `.mcp.json`。

它还会顺手在那个目录留下 `package.json`、`package-lock.json` 和一个几十 MB 的 `node_modules`。清掉这四样，回到项目根重跑。机制细节见 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)。

### 「要不要干脆装 user 级」

不要。MCP 工具定义会占用每个 session 的 context，而它只服务前端项目。按 project 级安装，并让 starter 自带 `.mcp.json`，可以避免后端 task 和框架仓承担这部分开销。

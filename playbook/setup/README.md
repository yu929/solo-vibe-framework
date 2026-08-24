# 场景 · 装起来

> 这里处理一次性的安装准备。装好后，日常开发不用再回来。

## 什么时候用这个场景

满足任一条：

- 换了一台机器
- 起一个新项目
- `trellis init` 之后发现某个 skill 没被触发
- 从旧版升级，`~/.claude/skills/` 里还留着指向旧仓的软链

## 开始之前

- [ ] Node ≥ 18、Python ≥ 3.9。这是 Trellis 的要求；各轨技术栈可能要求更高，安装后看 `.trellis/spec/README.md` 的栈锁定表
- [ ] `gh` CLI，只在同步 vendor 时需要

## 先分清四套安装机制

registry 装不了 skill。`trellis init --registry` 只认 `type: spec`，遇到其他类型会直接失败，也不会顺带安装本仓的 skill。

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| 一条轨的 spec，自带 guides | `trellis init --registry ... --template <id>` | 项目内 `.trellis/spec/` |
| 本仓 skill 与 vendor skill | `scripts/install-skills.sh` | `~/.claude/skills/`，全局软链 |
| Trellis 自带 skill | `trellis init --claude` | 项目内 `.claude/skills/` |
| workflow 模板 | `--workflow` / `trellis workflow` | 项目内 `.trellis/workflow.md` |

这四种操作表面上都是安装，实际使用不同机制，也写入不同位置。最常见的混淆是：已经运行过 init，slash 列表里却仍没有 `/vertical-slicing`。

## 四篇，按顺序装

| 篇 | 装什么 | 跳过它会怎样 |
|---|---|---|
| [`01-trellis-skills.md`](01-trellis-skills.md) | Trellis 本体 + 全局 skill 软链 | slash 列表里没有本仓的 skill |
| [`02-track-spec.md`](02-track-spec.md) | 项目里的一条轨 spec | agent 按 Trellis 的占位脚手架干活 |
| [`03-third-party.md`](03-third-party.md) | 完整 PRD skill、shadcn skill 与 MCP、vendor 跟随 | 需求那一步没有 skill 接，前端组件靠 AI 记忆写 |
| [`04-workflow-prompts.md`](04-workflow-prompts.md) | 两段粘进 `.trellis/workflow.md` 的提示 | 提醒不在你做决定的那一刻出现 |

前两篇必须完成。后两篇是增强项，跳过不会阻塞开发，但 AI 会少一些项目上下文。

## 装完检查这四条

| # | 检查什么 | 漏了会怎样 |
|---|---|---|
| 1 | `scripts/install-skills.sh --check` 全绿 | 旧 PRD skill 残留会抢走需求，走上已废弃的流程 |
| 2 | `.trellis/spec/` 里轨规范和 `guides/` 都在 | 缺一半，agent 工作时就少一半约束 |
| 3 | 只装了**一个**模板 | 装了两个，`trellis update` 只刷新后装的那个，而且不报错 |
| 4 | `.trellis/spec/guides/` 里有 `task-artifacts.md` 和 `source-of-truth.md` | 少了这两份，`design.md` 与 `implement.md` 没有固定形状，四个源真也没人管 |

各篇都给出了对应的确认命令。

## 这个场景为什么带命令

其他手册不写技术栈命令，相关内容归 `specs/<track>/`。本场景讲的就是安装，因此保留必要命令。

安装机制的源码依据和实测输出集中在 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)。这里各篇只说明怎么做，以及出错时会看到什么。

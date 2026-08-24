# 场景 · 装起来

> 一次性准备。装完之后日常不用再回到这个场景。

## 什么时候用这个场景

满足任一条：

- 换了一台机器
- 起一个新项目
- `trellis init` 之后发现某个 skill 没被触发
- 从旧版升级，`~/.claude/skills/` 里还留着指向旧仓的软链

## 开始之前

- [ ] Node ≥ 18、Python ≥ 3.9。这是 **Trellis 自己**的要求；各轨技术栈另有更高要求，装完看 `.trellis/spec/README.md` 的栈锁定表
- [ ] `gh` CLI，只在同步 vendor 时需要

## 最要紧的一件事：这里有四套机制

registry 装不了 skill。 `trellis init --registry` 只认 `type: spec`，遇到别的类型直接返回失败，不会顺手把本仓的 skill 放好。

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| 一条轨的 spec，自带 guides | `trellis init --registry ... --template <id>` | 项目内 `.trellis/spec/` |
| 本仓 skill 与 vendor skill | `scripts/install-skills.sh` | `~/.claude/skills/`，全局软链 |
| Trellis 自带 skill | `trellis init --claude` | 项目内 `.claude/skills/` |
| workflow 模板 | `--workflow` / `trellis workflow` | 项目内 `.trellis/workflow.md` |

四个都像「装个东西进来」，落点和机制完全不同。搞混的典型症状是「我明明 init 了，怎么 slash 列表里没有 `/vertical-slicing`」。

## 四篇，按顺序装

| 篇 | 装什么 | 跳过它会怎样 |
|---|---|---|
| [`01-trellis-skills.md`](01-trellis-skills.md) | Trellis 本体 + 全局 skill 软链 | slash 列表里没有本仓的 skill |
| [`02-track-spec.md`](02-track-spec.md) | 项目里的一条轨 spec | agent 按 Trellis 的占位脚手架干活 |
| [`03-third-party.md`](03-third-party.md) | 完整 PRD skill、shadcn skill 与 MCP、vendor 跟随 | 需求那一步没有 skill 接，前端组件靠 AI 记忆写 |
| [`04-workflow-prompts.md`](04-workflow-prompts.md) | 两段粘进 `.trellis/workflow.md` 的提示 | 提醒不在你做决定的那一刻出现 |

前两篇是必须的，后两篇缺了不阻塞，只是 AI 要多猜。

## 装完检查这四条

| # | 检查什么 | 漏了会怎样 |
|---|---|---|
| 1 | `scripts/install-skills.sh --check` 全绿 | 旧 PRD skill 残留会抢走需求，走上已废弃的流程 |
| 2 | `.trellis/spec/` 里轨规范**和** `guides/` 都在 | 缺一半，等于 agent 少一半约束在工作 |
| 3 | 只装了**一个**模板 | 装了两个，`trellis update` 只刷新后装的那个，而且不报错 |
| 4 | `.trellis/spec/guides/` 里有 `task-artifacts.md` 和 `source-of-truth.md` | 少了这两份，`design.md` 与 `implement.md` 没有固定形状，四个源真也没人管 |

对应的命令写在各篇的「怎么确认这步成了」。

## 这个场景为什么带命令

其余各篇一律不写栈命令，命令归 `specs/<track>/`。这里例外：装东西就是这个场景的正题。

安装期的源码依据与实测输出集中在 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)，各篇只写「怎么做」和「出错是什么样」，不复述推导。

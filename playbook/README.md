# 操作手册

> **给你自己看的清单，照着做就行。** 不是给 AI 的指令文件。
>
> 日常**直接走 Trellis 的流程**即可：描述需求 → 它带你 Plan → Execute → Finish。本手册只讲 Trellis 没有、而这套工作流需要的那部分。

## 两个场景

| 场景 | 什么时候用 | 从哪进 |
|---|---|---|
| [**装起来**](setup/README.md) | 换机器 · 起新项目 · slash 列表里没有本仓的 skill | [`setup/README.md`](setup/README.md) |
| [**做产品**](build/README.md) | 装完之后的一切 | [`build/README.md`](build/README.md) |

「做产品」不区分新产品和加功能，两者走同一条路，只是进入的位置不同：

- 还没有收敛的需求 → [`build/01-discovery.md`](build/01-discovery.md)
- 已经有 `slices.md`，这次是加一片或修 bug → [`build/06-off-path.md`](build/06-off-path.md)

完整流程图、七处拍板点和五件反复出现的事，都在 [`build/README.md`](build/README.md)，全仓只有那一份。

## 别的东西在哪

| 你想找 | 去哪 |
|---|---|
| 规则为什么长这样 | [`../AGENTS.md`](../AGENTS.md) |
| 装什么、不装什么、为什么 | [`../references/third-party.md`](../references/third-party.md) |
| 安装期的源码依据与实测输出 | [`../references/install-mechanics.md`](../references/install-mechanics.md) |
| 已经定下、不再重议的取舍 | [`../references/decisions.md`](../references/decisions.md) |
| 编码规范正文 | 项目里的 `.trellis/spec/` |

## 这份手册怎么维护

照着做的时候，凡是需要停下来问「这步到底该干嘛」的地方，就是手册的 bug。 当场记进对应文件的「常见卡点」，趁你还记得。

文档里的每一句 prompt 都标了「已实跑」或「未实跑」。跑过之后把标记擦掉、把你实际敲的那句替换进去，这是这份手册变准的唯一途径。没跑过就编 prompt，正是这套框架要防的事。

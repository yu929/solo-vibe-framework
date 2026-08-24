# 操作手册

> 这是一份给你自己看的清单，照着做就行。它不是给 AI 的指令文件。
>
> 日常直接走 Trellis：描述需求，然后按 Plan → Execute → Finish 推进。本手册只补充 Trellis 没覆盖的部分。

## 两个场景

| 场景 | 什么时候用 | 从哪进 |
|---|---|---|
| [**装起来**](setup/README.md) | 换机器 · 起新项目 · slash 列表里没有本仓的 skill | [`setup/README.md`](setup/README.md) |
| [**做产品**](build/README.md) | 装完之后的一切 | [`build/README.md`](build/README.md) |

「做产品」不区分新产品和加功能，两者走同一条路，只是进入的位置不同：

- 还没有收敛的需求 → [`build/01-discovery.md`](build/01-discovery.md)
- 已经有 `slices.md`，这次是加一片或修 bug → [`build/06-off-path.md`](build/06-off-path.md)

完整流程图、七处拍板点和五条贯穿全程的规则，都在 [`build/README.md`](build/README.md)。

## 别的东西在哪

| 你想找 | 去哪 |
|---|---|
| 规则为什么长这样 | [`../AGENTS.md`](../AGENTS.md) |
| 装什么、不装什么、为什么 | [`../references/third-party.md`](../references/third-party.md) |
| 安装期的源码依据与实测输出 | [`../references/install-mechanics.md`](../references/install-mechanics.md) |
| 已经定下、不再重议的取舍 | [`../references/decisions.md`](../references/decisions.md) |
| 编码规范正文 | 项目里的 `.trellis/spec/` |

## 这份手册怎么维护

照着做时，如果某一步让你停下来琢磨「到底该干嘛」，就趁还记得写进对应文件的「常见卡点」。这说明手册还没讲清楚。

文档里的每一句 prompt 都标了「已实跑」或「未实跑」。实际跑过后，删掉标记，换成当时真正有效的说法。没有跑过就不要替它润色，否则手册里留下的仍然只是猜测。

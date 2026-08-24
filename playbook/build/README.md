# 场景 · 做产品

> 从一句话想法到逐片交付，以及交付开始之后的日常。装完之后的一切都在这个场景里。

## 什么时候用这个场景

[setup](../setup/README.md) 走完之后的一切。它不区分「新产品」和「加功能」，两者走的是同一条路，只是进入的位置不同：

- 还没有收敛的需求 → 从 [`01-discovery.md`](01-discovery.md) 开始
- 已经有 `slices.md`，这次是加一片或修一个 bug → 直接进 [`06-off-path.md`](06-off-path.md)

## 开始之前

- [ ] [setup](../setup/README.md) 那四条检查全绿
- [ ] 仓库已建，`trellis init` 跑过
- [ ] 你有一段能说出口的想法。**不需要想清楚**，那正是接下来要做的事

## 全流程

这是全仓唯一一张完整流程图。★ 是你必须停下来拍板的地方。

```
一句话想法
   │
   ├─ 需求讨论 ─────── grill-with-docs      → 术语进 CONTEXT.md
   │                                          有取舍的决定进 docs/adr/
   ├─ 写完整 PRD ───── create-prd-skill     → docs/discovery/prd.md
   │                                                    ★ 范围 + 明确不做
   ├─ 抛原型验字段 ─── prototype（LOGIC）    → 丢弃品，验完就删
   ├─ 反写 PRD                              → 字段级收敛到此为止
   │
   ├─ 全量高保真定稿 ─ ui-ux-pro-max        → design-system/screens/
   │                                                    ★ 选案，一次定
   ├─ 垂直切片 ─────── /vertical-slicing    → docs/discovery/slices.md
   │                                                    ★ 切法 + 第一片
   │
   └─ 逐片进 Trellis ─┬─ Plan     prd / design / implement
                      │           本片定稿屏进 implement.jsonl
                      │                       ★ 批准 planning summary 才 start
                      ├─ Execute  实现 → check
                      │                       ★ 人工验收（流程里没有，你得插）
                      └─ Finish   update-spec → commit → 归档
                                              ★ 看它改了哪几条 spec

                      每 3–5 片 → 项目级检查点
                                              ★ 该砍什么 + 阶段末批量回写
```

**需求与原型一次做全，实现逐片推进。** 切片需要一个已收敛的东西才切得动，所以需求那一轮本来就要做全；实现做全则意味着几个月拿不到任何可验证的东西。这个取舍的完整推导在 [`../../references/decisions.md`](../../references/decisions.md)。

## 六篇

| 篇 | 覆盖 |
|---|---|
| [`01-discovery.md`](01-discovery.md) | 需求讨论 → 完整 PRD → 抛原型验字段 → 反写 PRD |
| [`02-hifi.md`](02-hifi.md) | 全量高保真定稿与设计系统 |
| [`03-slicing.md`](03-slicing.md) | 切片，写出 `slices.md` |
| [`04-slice-loop.md`](04-slice-loop.md) | 逐片进 Trellis，含人工验收和 finding |
| [`05-checkpoint.md`](05-checkpoint.md) | 项目级检查点，含阶段末批量回写 |
| [`06-off-path.md`](06-off-path.md) | 加一片 · 修 bug · 宽重构 · `design-review` 逃生舱 |

## 你必须停下来拍板的七处

| # | 拍什么 | 在哪 | 拍错的代价 |
|---|---|---|---|
| 1 | **范围 + 明确不做** | 完整 PRD | 最贵。方向错了后面全白做 |
| 2 | **选哪个方案** | 高保真走查 | 定稿之后每一片都照着它实现 |
| 3 | **切法 + 第一片是哪个** | `slices.md` 切片清单 | 第一片定下后面都要沿用的结构 |
| 4 | **planning summary** | Trellis，`task.py start` 之前 | 最后一道免费的闸 |
| 5 | **本片验收** | check 绿了之后、`update-spec` 之前 | 带着缺陷归档，后面几片在它上面接着盖 |
| 6 | **Finish 改了哪几条 spec** | Trellis Finish | AI 倾向于把一次性决定写成永久约定 |
| 7 | **该砍什么、下一阶段目标** | 项目级检查点 | 不定下来，下一批切片又是一批孤立功能 |

**1 和 3 是真正值钱的两个**，拍错了后面全白做。

**5 是唯一一个漏了不会有任何提示的。** 其余六个都有东西来找你：AI 会出方案、会出 summary、会列提交计划；验收没有任何一步会提醒你，Trellis 的流程里根本没有它。

这条链上唯一的硬门禁是第 4 项，Trellis 自带的那个。 本仓的产物一律没有 frontmatter、没有 approved 字段：没有任何东西读它们，加了只会造出一个跟现实永远对不上的假状态。理由见 [`../../references/decisions.md`](../../references/decisions.md)。

## 五件反复出现的事

不管你现在在哪一篇，这五条都成立。

### 一、高保真定稿之前，PRD 必须已经收敛到字段级

这是整个「需求做全、实现逐片」安排的前提。没收敛就画高保真，等于在替未收敛的需求猜结构。一个用高保真画出来的猜测会被当成已定，后面每一片都照着它实现。

顶住这条的是 `01-discovery.md` 里那两步：**抛原型验字段**和**反写 PRD**。这两步走过场，高保真就是在猜，而那时候**没有任何机制会告诉你**。

### 二、每一片都要能独立端到端跑通

判据只有一个：

> 做完这一片，有没有一件事是用户能真正做成的？

「先把所有表建了」「先搭好框架」不是切片，它们验证不了任何东西，该被拆进各自的片里。

### 三、切片不能静默长大

逐片模式最主要的失控形态：每片都「顺手多做一点」，三片之后就回到了一次做全。

发现这一片需要更多东西时，先分清是**本片必需**（少了它主链路就断）还是**顺手想加**。后者记进 `slices.md` 当后面的片。

### 四、brainstorm 问的每个问题，都是 PRD 里缺的一条

Trellis 的 brainstorm 被合同要求「每条消息只问一个问题」，直到没有你该拍的决策为止。这是设计如此，不是走样。

**答的时候顺手补进 PRD**，别只在对话里答。对话下个 session 就没了。

两套提问纪律在这里会打架：Trellis 一次一问，`grilling` 一轮问完 frontier。**取 Trellis 的**，它在 planning 阶段是强制的。

### 五、编码期发现的东西，先记 finding 再改 spec

AI 在实现或调试时会发现「这个约定其实不对」「这里有坑 spec 没写」。不要让它直接改 `.trellis/spec/`。那等于让报告方兼任裁决方，spec 会在几周内被填满未经检验的经验。

四字段格式、值不值得记的判据、升到哪一层，全在 `.trellis/spec/guides/review-adjudication.md`。你要判的是哪一条值得升级、升到哪里、什么时候升，见 [`04-slice-loop.md`](04-slice-loop.md) 和 [`05-checkpoint.md`](05-checkpoint.md)。

## Trellis 有什么，这里补什么

**Trellis 有需求收敛。** `trellis-brainstorm` 一问一答帮你把一个 task 想清楚，还带一个硬门禁：没有你的显式批准，不许 `task.py start`。这部分很好用，本场景不复述。

它没有的只有两样，都在 task 之上：

| 缺什么 | 为什么它没有 | 这里怎么补 |
|---|---|---|
| **产品全貌** | `.trellis/spec/` 只放编码规范、`prd.md` 只记单次改动、journal 只是时间流水。跑五十个 task 也没有一处回答「这产品现在整体是什么」 | 完整 PRD + `slices.md` + [`05-checkpoint.md`](05-checkpoint.md) |
| **切片顺序** | Trellis 原话：*"Parent/child structure is not a dependency system"* | `slices.md` 的阻塞边 |

Trellis 自己也是这么设计的。它的 brainstorm 明说 *"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* 它主动把产品层留空给你。

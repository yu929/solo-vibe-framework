# 场景 · 做产品

> 从一句话想法走到逐片交付，开始交付后的日常也在这里。安装完成后，从这里往下走。

## 什么时候用这个场景

[setup](../setup/README.md) 走完之后的一切。它不区分「新产品」和「加功能」，两者走的是同一条路，只是进入的位置不同：

- 还没有收敛的需求 → 从 [`01-discovery.md`](01-discovery.md) 开始
- 已经有 `slices.md`，这次是加一片或修一个 bug → 直接进 [`06-off-path.md`](06-off-path.md)

## 开始之前

- [ ] [setup](../setup/README.md) 那四条检查全绿
- [ ] 仓库已建，`trellis init` 跑过
- [ ] 你能用一段话说出自己的想法。暂时没想清楚也没关系，后面就是用来收敛它的

## 全流程

下面是完整流程。看到 ★ 就停下来拍板。

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

需求和原型一次做全，实现则逐片推进。需求必须先收敛，否则没有东西可切；实现如果也一次做全，可能几个月都拿不到可验证的结果。这个取舍的完整推导在 [`../../references/decisions.md`](../../references/decisions.md)。

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
| 1 | 范围 + 明确不做 | 完整 PRD | 范围错了，后面的工作都会跟着偏 |
| 2 | 选哪个方案 | 高保真走查 | 定稿之后每一片都照着它实现 |
| 3 | 切法 + 第一片是哪个 | `slices.md` 切片清单 | 第一片会定下后面沿用的结构 |
| 4 | planning summary | Trellis，`task.py start` 之前 | 最后一道免费的闸 |
| 5 | 本片验收 | check 绿了之后、`update-spec` 之前 | 带着缺陷归档，后面几片会在它上面继续做 |
| 6 | Finish 改了哪几条 spec | Trellis Finish | AI 容易把一次性决定写成永久约定 |
| 7 | 该砍什么、下一阶段目标 | 项目级检查点 | 不定下来，下一批切片又会变成孤立功能 |

第 1 和第 3 处最值得多花时间：范围或切法错了，后面的实现都会跟着偏。

第 5 处最容易漏。其余六处都会有产物来找你确认：方案、summary 或提交计划；Trellis 的流程里没有人工验收这一步，不会主动提醒。

第 4 项是流程里的硬门禁，由 Trellis 提供。本仓产物不加 frontmatter 或 approved 字段，因为没有程序读取或维护这些字段。理由见 [`../../references/decisions.md`](../../references/decisions.md)。

## 五件反复出现的事

不管你现在在哪一篇，这五条都成立。

### 一、高保真定稿之前，PRD 必须已经收敛到字段级

这是「需求做全、实现逐片」能够成立的前提。PRD 还没收敛就画高保真，画出来的结构只是猜测，却会被后续切片当成定稿。

`01-discovery.md` 里的「抛原型验字段」和「反写 PRD」专门处理这个风险。两步如果只是走过场，高保真开始猜时流程不会报警。

### 二、每一片都要能独立端到端跑通

判据只有一个：

> 做完这一片，有没有一件事是用户能真正做成的？

「先把所有表建了」「先搭好框架」不是切片，它们验证不了任何东西，该被拆进各自的片里。

### 三、切片不能静默长大

逐片推进最常见的失控方式，是每一片都顺手多做一点。几片之后，范围又悄悄长回了一次做全。

发现这一片需要更多东西时，先分清是**本片必需**（少了它主链路就断）还是**顺手想加**。后者记进 `slices.md` 当后面的片。

### 四、brainstorm 问的每个问题，都是 PRD 里缺的一条

Trellis 的 brainstorm 按约定每条消息只问一个问题，直到没有需要你拍板的决定。这是正常行为。

**答的时候顺手补进 PRD**，别只在对话里答。对话下个 session 就没了。

两套提问纪律在这里会打架：Trellis 一次一问，`grilling` 一轮问完 frontier。**取 Trellis 的**，它在 planning 阶段是强制的。

### 五、编码期发现的东西，先记 finding 再改 spec

AI 在实现或调试时可能发现约定不对，或者 spec 漏了某种情况。先记 finding，不要直接改 `.trellis/spec/`；否则发现问题的一方同时做裁决，未经检验的经验很快就会堆进 spec。

四字段格式、值不值得记的判据、升到哪一层，全在 `.trellis/spec/guides/review-adjudication.md`。你要判的是哪一条值得升级、升到哪里、什么时候升，见 [`04-slice-loop.md`](04-slice-loop.md) 和 [`05-checkpoint.md`](05-checkpoint.md)。

## Trellis 有什么，这里补什么

Trellis 已经负责需求收敛。`trellis-brainstorm` 用一问一答把单个 task 想清楚，并在 `task.py start` 前等你明确批准。本手册不复述这部分。

本手册补的是 task 之上的两件事：

| 缺什么 | 为什么它没有 | 这里怎么补 |
|---|---|---|
| **产品全貌** | `.trellis/spec/` 只放编码规范、`prd.md` 只记单次改动、journal 只是时间流水。跑五十个 task 也没有一处回答「这产品现在整体是什么」 | 完整 PRD + `slices.md` + [`05-checkpoint.md`](05-checkpoint.md) |
| **切片顺序** | Trellis 原话：*"Parent/child structure is not a dependency system"* | `slices.md` 的阻塞边 |

这也符合 Trellis 自己的设计。它的 brainstorm 明说：*"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* 产品层由项目自己的文档承担。

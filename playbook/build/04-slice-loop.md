# 4 · 逐片进 Trellis

> 每个切片走一个循环，完成后回到 `slices.md` 取下一片。本篇只补充 Trellis 流程之外需要人工处理的环节。

## 一片的完整循环

```
建 task
  │
Phase 1 Plan ──── brainstorm 一问一答 → prd.md / design.md / implement.md
  │               本片定稿屏 + 本片碰到的每一层 spec → implement.jsonl
  │                                   ★ 你批准 planning summary，它才 start
  │
  ══════════ 从这里往后它一路自己跑 ══════════
  │
Phase 2 Execute ─ 派 implement 子 agent → 派 check 子 agent
  │                                   ★ 人工验收 ← Trellis 没有，靠一段提示唤起
  │
Phase 3 Finish ── update-spec → 提交计划（唯一的自动停顿）→ 归档 + journal
                                      ★ 看它改了哪几条 spec
```

Phase 2 会直接接着跑进 Phase 3，中间步骤都被 Trellis 标为 `[required]`。AI 会自行推进，直到 Phase 3 的提交计划才停下来：它会列出提交批次、自己改过的文件和无法识别的文件，等你回复「ok」。

人工验收不在这条自动流程里。[`../setup/04-workflow-prompts.md`](../setup/04-workflow-prompts.md) 步骤 3 会注入一段提示，要求它在 check 之后停下来列验收结果。提示不是门禁，hook 拦不住工具调用；如果它没有停，立即中断，验收后再用 `/trellis:continue` 接着执行。

中断后接着干：`/trellis:continue`。

## 步骤

### 步骤 1 · 建 task

```
按 slices.md 的第 <N> 片建 task。
```

> 未实跑。

### 步骤 2 · 盯住 `implement.jsonl`

这一步要仔细看，因为漏掉文件时不会报错。

实现由带着全新 context 的子 agent 完成，它只会拿到 `implement.jsonl` 中列出的文件。仅在 `prd.md` 里写下定稿路径还不够，那里只是说明文字，不会把文件内容带进 context。

两类东西必须进去：

1. **本片对应的高保真屏**，路径取自 `slices.md` 切片清单第四列。**只列这一片的**，全量定稿会撑爆子 agent 的 context
2. **本片碰到的每一层**，它的 `.trellis/spec/<层>/index.md`，以及那份 index 指向的同层文件

检查方法：打开 task 目录的 `implement.jsonl`，确认其中列出了 `design-system/screens/` 下本片对应的文件。

**补法**：

```
把这一片的定稿屏加进 implement.jsonl，然后重做实现。
```

> 未实跑。第一条已实跑得出，第二条未实跑验证。

漏掉后的表现是：定稿已经画好，`prd.md` 也有引用，实现结构却仍与定稿不同。表面上很像执行出了问题，其实是输入没送到子 agent。

### ★ 拍板 4：planning summary

这是 Trellis 自带的硬门禁，没有你的明确批准，`task.py start` 不会执行。

看两样：这一片的边界对不对，`implement.jsonl` 里那两类文件在不在。

### ★ 拍板 5：本片验收

Trellis 没有人工验收这一步。check 只能核对代码是否符合规范和 `prd.md`，不能替你确认成品是否真是你想要的。

装好 [`../setup/04-workflow-prompts.md`](../setup/04-workflow-prompts.md) 步骤 3 后，AI 应在 check 之后停下来，按 `prd.md` 的验收标准列出可观测结果，并点名没有亲自跑过的条目。提示可能被忽略，是否通过仍由你判断。

把验收放在 check 全绿之后、`update-spec` 之前：

- check 已经先清掉不合规范的问题，此时更适合看实际行为
- 亲手跑一遍发现的问题可以接着交给 `update-spec` 判断
- 代码尚未提交，返工成本较低

不用另写验收清单，直接使用 `prd.md` 的验收标准。brainstorm 要求这里描述可观测结果，正好可以逐条手工验证。

多花时间验负向用例。正向路径通常容易覆盖，「不该看见的人是否看得见」「不该执行的操作是否被拦住」更容易漏，而且代价更高。

**不过的话，先分清是哪一类**：

| 现象 | 退到哪 | 贵不贵 |
|---|---|---|
| 没照 `prd.md` 做 | 退回实现，重做 | 便宜 |
| 照 `prd.md` 做了，但那不是你要的 | 退回 Phase 1 改 `prd.md`，再重做 | 贵得多 |

如果第二类问题反复出现，说明高保真走查没有提前拦住需求偏差。不要只修当前切片，还要回头检查 [`02-hifi.md`](02-hifi.md) 漏了什么。

### ★ 拍板 6：Finish 改了哪几条 spec

`trellis-update-spec` 会把本片经验升级进 `.trellis/spec/`。检查它准备修改的内容，避免把一次性决定写成永久约定。

判据是：**下次遇到同类情况，还该这么做吗？** 只此一次的，不进。

如果答案是「不该」，也不一定要丢掉，只是去处不同：

| 这次的新东西 | 落哪 |
|---|---|
| 下次同类情况还该这么做的编码约定 | `.trellis/spec/`，走 `update-spec` |
| 有取舍的架构决定 | `docs/adr/`，卡三条判据 |
| 只此一次 | 哪也不进 |

## 编码期发现的东西

AI 在实现或调试时可能发现约定不对，或者 spec 漏了某种情况。先记 finding，经确认后再升级。四字段格式和记录判据都在 `.trellis/spec/guides/review-adjudication.md`。

你需要判断三件事：

| 判什么 | 判据 |
|---|---|
| 值不值得记 | 别的 session 会不会**因为 spec 没写**而重犯同一个错？大部分 bug 不需要记，bug 说明代码没做到已有约定，约定本身没变 |
| 升到哪一层 | 换一个同轨的**别的项目**还成立吗？成立 → 框架仓的源真；不成立但本项目后面还要用 → 本项目 `.trellis/spec/`；一次性 → 留在 `findings/` |
| 什么时候升 | 见下表，三类各不相同 |

| 升到哪一层 | 什么时候 |
|---|---|
| 框架仓的源真 | **攒到阶段末批量做**，见 [`05-checkpoint.md`](05-checkpoint.md)。一条只出现过一次的经验，分不清是通用规律还是当前情境的特例 |
| 本项目 `.trellis/spec/` | 当场升，走 `update-spec` |
| 留在 `findings/` | **不升**。一次性的东西哪也不进，记录本身就是它的终点 |

不要在 task 内修改框架仓。`trellis-update-spec` 不知道 spec 来自 registry，只会写项目里的拷贝。把经验带回框架仓再重新安装属于跨仓操作，需要由人处理。

## 常见卡点

### 「第三片的列表页跟第一片长得不一样」

先看 `design-system/screens/`。如果定稿一致而实现不一致，通常是实现期没有读到定稿，回步骤 2 检查 `implement.jsonl`。

### 「实现出来的前端不堪入目」

先分是哪一种：

| 现象 | 归谁 |
|---|---|
| 默认样式，但布局和信息层级是对的 | `design-system/MASTER.md` 没被读到，查 `implement.jsonl` |
| 布局或层级本身就烂 | 这一片的结构债，退回改 `prd.md` |

**两种同时出现很正常。** 顺序不能反：先定结构，再上视觉。

### 「小改动要不要建 task」

一句话能答完、不改文件、不需要调研的，不建。Trellis 自己的规矩就是这样。

**但改动跨多个文件、或需要先调研的，建**，你需要那份跨 session 记忆。

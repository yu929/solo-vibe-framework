# 4 · 两段粘进 `.trellis/workflow.md` 的提示

> 可选，但推荐。缺了不阻塞，只是提醒不会出现在你做决定的那一刻。
>
> **这两段都是提示语，不是判定。** Trellis 的 hook 是 parser-only，把这段原样注入对话，不做任何检查。它挡不住任何事，价值全在出现的时机。

## 步骤 1 · 让 `no_task` 状态先看切片地图

Trellis 在没有活跃 task 时每轮都会问「要不要建 task」。默认它不知道你有切片地图这回事。

打开项目里的 `.trellis/workflow.md`，找到 `[workflow-state:no_task]` 块，替换成：

```md
[workflow-state:no_task]
建 task 前先看 docs/discovery/slices.md 是否存在：
- 不存在 → 正常流程，不阻塞。
- 存在但没写「当前阶段目标」→ 先补，再建 task。
- 存在且有阶段目标 → 读它。本次 task 必须是阶段目标下的一个纵向切片；
  说不出它属于哪个切片，就先打 /vertical-slicing 排切片。
一句话能答完、不改文件、不需要调研的，不建 task。
[/workflow-state:no_task]
```

**⚠️ 未实跑验证。** 第一次用的时候看它实际效果，不对就当场改。改的是你自己项目里的文件，`.trellis/.template-hashes.json` 会保护本地修改不被升级覆盖。

## 步骤 2 · 让 planning 阶段先读固定小节

Trellis 规定复杂 task 在 `task.py start` 之前必须有 `design.md` 和 `implement.md`，但**只给 `prd.md` 生成骨架**，另外两份靠 agent 自由发挥。模板已经随 registry 装进 `.trellis/spec/guides/task-artifacts.md`，这一段是让它在**写之前**被读到。

打开 `.trellis/workflow.md`，找到 `[workflow-state:planning]` 块，在末尾加这几行：

```md
写 design.md / implement.md 前先读 .trellis/spec/guides/task-artifacts.md 的固定小节。
本片对应的高保真定稿屏（slices.md 切片清单第四列）必须进 implement.jsonl。
实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件，prd.md 里写一行路径不算。
本片碰到的每一层，它的 .trellis/spec/<层>/index.md 和那份 index 指向的同层文件，
同样必须进 implement.jsonl，规范和定稿屏走的是同一条通路。
```

**第二条是实跑得出的，漏了没有症状**：定稿画了、`prd.md` 也引用了，实现出来照样不是定稿的结构，看起来像是执行不认真。

**第三条未实跑验证**，推理依据在下面。

## 为什么这一步是保险，不是唯一通路

`task-artifacts.md` 自带 `paths: [".trellis/tasks/"]`，动 task 目录里的文件时会自动注入。这条已实测**：在临时项目里建 task，`get_context.py --mode spec --file <task>/prd.md` 命中该文件，反向对照 `src/a.ts` 不命中。

但注入在 Claude Code 那侧挂在 **PostToolUse**，matcher 是 `Read|Edit|Write|MultiEdit`。先读一个受管路径下的文件也能触发，真正来不及的是**凭空建新文件**那种。

子 agent 更彻底：它的 context 在 PreToolUse 时由 `implement.jsonl` 内联组装，dispatch prompt 还明说「需要的都给你备好了」。jsonl 没列的规范，在它开工前等于不存在。上面第二、三条都由此而来。

源码依据在 [`../../references/third-party.md`](../../references/third-party.md) 的 "Measured: what it provides, and what it does not"。

## 常见卡点

### 「Trellis 一直问要不要建 task，很烦」

它在没有活跃 task 时每轮都问。需求还没收敛之前答**否**。Trellis 自己就允许这样，它的原话是用户说不就 *"skip Trellis for this session"*。`no_task` 是设计内的合法状态，不是你在绕过什么。

**要它这一轮彻底闭嘴**，消息里带上 `no-trellis` 这个词（独立成词，`no-trellisfoo` 不算），那一轮的提示完全不注入：

```
no-trellis 我们先把 PRD 第 3 节聊完
```

这是 Trellis 自带的逃生舱，开关在 `.trellis/config.yaml` 的 `prompt_injection.skip_keyword`，默认就是 `no-trellis`。**已实测**：带这个词跑，注入内容为空。

它和本篇步骤 1 那段粘贴**不是一回事，别互相替代**：粘贴是给 `no_task` 状态**加**一段提醒，长期生效；`no-trellis` 是**关掉**当轮全部提醒，一次性。写 PRD 那几轮嫌吵就用后者，平时靠前者。

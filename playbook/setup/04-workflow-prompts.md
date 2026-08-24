# 4 · 三段粘进 `.trellis/workflow.md` 的提示

> 这是推荐的可选配置。跳过不会阻塞流程，但你在做决定时收不到对应提醒。
>
> 这三段只是提示，不会被程序校验。Trellis 的 hook 是 parser-only，只负责把文字原样注入对话。它不能阻止操作，作用在于及时提醒。

## 步骤 1 · 让 `no_task` 状态先看切片地图

没有活跃 task 时，Trellis 每轮都会询问是否新建 task。默认情况下，它不知道项目里还有一份切片地图。

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

> 未实跑验证。第一次使用时检查实际效果，不合适就当场调整。修改的是项目自己的文件，`.trellis/.template-hashes.json` 会保护本地内容，不让升级直接覆盖。

## 步骤 2 · 让 planning 阶段先读固定小节

Trellis 要求复杂 task 在 `task.py start` 前具备 `design.md` 和 `implement.md`，但只为 `prd.md` 生成骨架，另外两份由 agent 自行组织。registry 已把模板安装到 `.trellis/spec/guides/task-artifacts.md`，下面这段提示让 agent 在动笔前先读模板。

打开 `.trellis/workflow.md`，找到 `[workflow-state:planning]` 块，在末尾加这几行：

```md
写 design.md / implement.md 前先读 .trellis/spec/guides/task-artifacts.md 的固定小节。
本片对应的高保真定稿屏（slices.md 切片清单第四列）必须进 implement.jsonl。
实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件，prd.md 里写一行路径不算。
本片碰到的每一层，它的 .trellis/spec/<层>/index.md 和那份 index 指向的同层文件，
同样必须进 implement.jsonl，规范和定稿屏走的是同一条通路。
```

第二条来自实跑结论。漏掉时不会报错：定稿已经画好，`prd.md` 也有引用，实现结构却仍与定稿不同，看起来像执行不认真。

第三条尚未实跑验证，依据如下。

## 步骤 3 · 让 check 之后停一下等验收

Trellis 从 `task.py start` 到归档一路自跑，唯一的自动停顿在 Phase 3.4 的提交计划。人工验收该发生在 check 全绿之后、`update-spec` 之前，那个位置上没有任何东西会来找你。

打开 `.trellis/workflow.md`，找到 `[workflow-state:in_progress]` 块，在末尾加这几行：

```md
trellis-check 全绿之后先停下，等人工验收通过，再进 trellis-update-spec。
停下时按 prd.md 的验收标准逐条列出可观测结果，指明哪几条你没有亲自跑过。
在用户明确回复通过之前，不要开始 update-spec，也不要起草提交计划。
```

> 未实跑验证。

`[workflow-state:in_progress]` 的作用域从 Phase 2 延续到 Phase 3.4，Trellis `workflow.md` 在这个块的注释里写明了这一点。因此 check 结束时，这段提醒仍在上下文中。

这段提示不是门禁。hook 只往对话里放文字，不能阻断工具调用；全流程真正能停住 `task.py start` 的只有 planning summary。这里给 AI 一个停下来列验收结果的时机。如果它继续执行，立即中断，按 [`../build/04-slice-loop.md`](../build/04-slice-loop.md) 的拍板 5 验收，再用 `/trellis:continue` 接着执行。

第二句要求它点名没有亲自跑过的条目，避免把「代码写了」说成「已经验证」。

## 为什么还要加这层提醒

`task-artifacts.md` 自带 `paths: [".trellis/tasks/"]`，操作 task 目录中的文件时会自动注入。实测在临时项目中建 task 后，`get_context.py --mode spec --file <task>/prd.md` 会命中该文件，而 `src/a.ts` 不会命中。

不过，Claude Code 侧的注入挂在 PostToolUse，matcher 是 `Read|Edit|Write|MultiEdit`。先读取受管路径中的文件可以触发注入；直接从空白创建新文件时，提示可能来得太晚。

子 agent 的 context 则在 PreToolUse 阶段由 `implement.jsonl` 内联组装。dispatch prompt 还明确说所需材料已经备好，因此 jsonl 没列出的规范在开工时不会进入它的视野。上面的第二、三条都基于这一点。

源码依据在 [`../../references/third-party.md`](../../references/third-party.md) 的 "Measured: what it provides, and what it does not"。

## 常见卡点

### 「Trellis 一直问要不要建 task，很烦」

没有活跃 task 时，它每轮都会询问。需求尚未收敛就回答「否」。Trellis 明确允许这样做，原话是用户拒绝后 *"skip Trellis for this session"*；`no_task` 本来就是合法状态。

如果想在当前一轮关闭提示，在消息中加入独立成词的 `no-trellis`（`no-trellisfoo` 不算）：

```
no-trellis 我们先把 PRD 第 3 节聊完
```

这是 Trellis 自带的临时开关，配置项是 `.trellis/config.yaml` 中的 `prompt_injection.skip_keyword`，默认值为 `no-trellis`。已实测：消息中带这个词时，注入内容为空。

它与步骤 1 的配置用途相反，不能互相替代：步骤 1 为 `no_task` 状态长期增加提醒，`no-trellis` 则只关闭当前一轮的全部提醒。写 PRD 时临时觉得干扰，可以使用后者。

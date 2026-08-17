---
name: lofi-prototype
description: 在 Trellis planning 阶段把当前切片的需求变成低保真骨架，让人在界面或交互上走查、选案、拍板，再把结论回写这一片的 prd.md——把返工从「实现后」提前到「开工前」。有 UI 的产品出自包含灰度可点击 HTML 骨架，CLI/API/SDK/管道等非 UI 产品出交互面骨架（命令序列、请求响应样例、状态迁移）。覆盖当前切片声明的全部屏或交互序列（含它自己的支撑页与异常态），出 2–3 个结构上真有区别的方案供拍板；内置保真度红线（只灰度、无品牌视觉、零外部依赖）与有界收敛（方案一次定、走查最多两轮、单片屏数警报）。触发词：低保真原型、线框图、走查原型、原型确认、画个原型、lofi、wireframe、low fidelity。视觉设计、设计系统、配色字体与高保真 UI 用 ui-ux-pro-max，实现规格与技术设计归 Trellis task 本身。
---

# Lofi Prototype · 低保真原型走查

把**当前切片**的需求变成**能点着走查的低保真骨架**，让人在界面和交互上发现问题，而不是在文字规格上发现问题。

## 位置：Trellis Phase 1 planning 内部

本 skill 不是独立关卡，它是 **planning 阶段的一个产物**，与 `design.md` / `implement.md` 平级：

```
task.py create
  → trellis-brainstorm 写 prd.md
  → 【本 skill】有交互面时出骨架 → 走查选案 → 回写 prd.md
  → brainstorm 的 planning summary
  → ★ 用户显式批准（Trellis 自带硬门禁）→ task.py start
```

**不自造门禁**。Trellis 的 brainstorm 已经规定「没有用户显式批准 planning summary 就不许 `task.py start`」，本 skill 的产物是喂给那次批准的材料，不需要再加一个 approved 标记。

保真度红线与停止规则的权威源是 [`references/fidelity-contract.md`](references/fidelity-contract.md)；操作细则见 [`references/sop-guide.md`](references/sop-guide.md)；骨架资产见 `assets/`。

## 核心理念

> **看不懂前端代码的人，唯一真正的审查杠杆是渲染出来的屏幕。** 所以把拍板点提前到开工前——在原型上改一屏几分钟，在实现后改一屏几小时。

两条容易搞混的边界，必须一开始就说清：

- **本 skill 管结构和流程**：有哪些屏、信息怎么组织、任务怎么流转、异常怎么恢复。**不管视觉**：配色、字体、间距、组件选型全归 `ui-ux-pro-max`。
- **覆盖面锚定当前切片，不锚定整个产品**。不变量是 `原型覆盖面 ≥ 本片实现覆盖面`——原型漏一屏，实现时就多一屏由 AI 自由发挥。**不需要**把整个 MVP 画全，那是另一回事。

## 触发与前置

- 触发词：低保真原型 / 线框图 / 走查原型 / 原型确认 / 画个原型 / lofi / wireframe。
- **输入检查点**：读当前 task 的 `prd.md`，**按顺序判定，命中即停**（叫「检查点」不叫「门禁」是有意的——这套流程里唯一能真正拦住开工的是 Trellis 的 planning summary 批准，本 skill 只是先把不该开画的情况挡回去）：
  1. **没有活跃 task** → 不直接开画。原型要覆盖的是「这一片要做什么」，没有 task 就没有这个范围。引导先进 Trellis planning（`task.py create` + brainstorm）。用户坚持要先看个草图时，可以出**单屏**探索草图，但不建立 `docs/discovery/wireframe/` 目录。
  2. **`prd.md` 缺少这一片的屏 / 交互序列清单** → **停下**。只输出「这一片还没定的产品决策清单」，引导回 brainstorm 补完。清单不存在就画，等于本 skill 自己在拍需求。
  3. **这一片没有交互面变更**（纯后端重构、纯配置调整、只改一条规则）→ 本 skill 不适用，直接告知可以继续 planning。
  4. **以上都不命中** → 进入 Phase 2。

## 4 阶段流程

```
Phase 1 检查点 + 读本片需求 → Phase 2 出 2–3 个方案 → Phase 3 走查 + 选案(≤2 轮) → Phase 4 回写 prd.md
```

### Phase 1 · 检查点 + 读本片需求

1. 跑上面的输入检查点。
2. 读当前 task 的 `prd.md`，吃透**这一片**的：屏 / 交互序列清单、必须表达的状态、明确不做的部分、以及**会影响交互的技术限制**（它直接约束你能画什么）。
3. **读已定稿的既有屏**——见下一节，这是本 skill 最容易被跳过、后果最贵的一步。
4. 读产品简报（`docs/discovery/brief.md`，如果存在）的**措辞**一节，按它用词，不要自造同义词。
5. 判定分支：有 UI → HTML 屏骨架；无 UI → 交互面骨架；混合 → 两者都出，各自标范围。

### Phase 1.5 · 沿用既有结构（逐片推进的一致性保障）

**出方案之前，必须先读 `docs/discovery/wireframe/` 下所有已定稿（`*/final/`）的屏或交互序列。**

逐片推进丢掉的唯一东西是跨片一致性：第一片画的列表页和第三片画的列表页可能长得完全不一样，而没有任何一处会发现这件事。这一步是唯一的补救，不能省。

**两个分支都读同一个 `*/final/`**：有 UI 的片定稿在 `final/index.html`，非 UI 的片定稿在 `final/interaction-sketch.md`。**布局统一是有意的**——一致性检查只认 `*/final/` 这一个路径，非 UI 定稿要是落在别处，第二个 CLI 切片就读不到上一片定下的命令组织、错误格式、退出码和幂等契约，这条纪律在非 UI 分支就整个失效了。

规则：

- **同类屏 / 同类序列沿用既有模式**。已经有列表页了，这一片的列表页就用同一套结构（同样的筛选位置、同样的行操作位置、同样的空态表达）。非 UI 同理：子命令怎么分组、错误往 stdout 还是 stderr、退出码怎么编号、`--json` 给不给，定过一次就沿用。
- **结构性偏离要显式说明理由**，写进方案的取舍说明里，让人有机会否掉。
- 没有既有定稿（这是第一片）→ 跳过本步，但要意识到**这一片定下的模式会被后面所有片沿用**，值得多想一轮。

### Phase 2 · 出 2–3 个方案

**每个方案都要覆盖本片声明的全部屏 / 序列**，含空、加载、错误、无权限等声明状态。不是"方案 A 画主流程、方案 B 画异常"。

**方案必须有结构性区分度**：区别落在信息架构与任务流组织上，例如——

| 分化维度 | 例 |
|---|---|
| 任务流形态 | 分步向导 / 单页长表单 / 列表内联渐进配置 |
| 信息组织 | 按对象分组 / 按流程阶段分组 / 单一工作台 |
| 配置与执行的关系 | 配置和执行分离两屏 / 配置即预览即执行一屏 |
| 异常处理位置 | 阻断式弹窗 / 内联提示 + 允许继续 / 独立修复页 |

三套雷同皮肤换个色不算方案——那让要看的东西翻三倍而信息不翻倍。

**先给取舍说明，再给屏**：每个方案先一句话说清它牺牲什么换什么（"A 步骤清晰但改配置要重走向导；B 一屏看全但首次使用信息量大"）。沿用/偏离既有结构的判断也写在这里。

产物（按 task slug 分目录，因为每一片都有自己的一套）：

```
docs/discovery/wireframe/<task-slug>/方案A/index.html
docs/discovery/wireframe/<task-slug>/方案B/index.html
docs/discovery/wireframe/<task-slug>/方案C/index.html   # 2 个够用时不必凑 3 个
```

用 [`assets/wireframe-base.html`](assets/wireframe-base.html) 起手，各方案共用同一份内联 token，便于并排对比。非 UI 分支用 [`assets/interaction-sketch-template.md`](assets/interaction-sketch-template.md) 出 `docs/discovery/wireframe/<task-slug>/interaction-sketch.md`（分方案段落），选案后**另存**一份定稿到 `final/`，见 Phase 3。

### Phase 3 · 走查 + 选案（≤2 轮）

1. **告诉用户怎么走查**：直接在浏览器打开各方案的 `index.html`；顶部 devbar 可切屏、切状态（正常/空/加载/错误/无权限）。走查顺序建议：先按本片主链路从入口点到成功结果，再逐个异常态。
2. **接收大白话反馈**："这步太绕""这两个应该在一屏""失败了不知道该干什么"——看到什么说什么，不需要懂代码。
3. **当面问 `prd.md` 里标了待确认的项**。对着屏问，答案通常立刻就有。
4. **选案**：用户选定 1 个方案。落选方案里想保留的要素**当场合并**进定稿，不留"再看看"。
5. **定稿一律落 `final/`**，两个分支同一个位置：

   | 分支 | 定稿路径 |
   |---|---|
   | 有 UI | `docs/discovery/wireframe/<task-slug>/final/index.html` |
   | 非 UI | `docs/discovery/wireframe/<task-slug>/final/interaction-sketch.md` |

   非 UI 的定稿是**只含选中方案**的一份（落选段落留在同目录的 `interaction-sketch.md` 里供回看）——`final/` 里放全部方案，下一片读的时候就不知道该沿用哪个。落选方案保留在 git 里供回看，但不再是任何东西的源真。

**最多 2 轮修改**。第 2 轮后仍有分歧的，按 [`assets/walkthrough-notes-template.md`](assets/walkthrough-notes-template.md) 记成「待确认」或「挪到后面的切片」，不进第 3 轮。

> **在方案之间反复摇摆是本阶段唯一真会失控的地方**——不是画得多。纪律落在这里：一次定，合并要素，往下走。

### Phase 4 · 回写 prd.md

1. 写 `docs/discovery/wireframe/<task-slug>/walkthrough-notes.md`（两段：走查发现 4 字段 + 方案对比与选案留痕）。
2. **回写当前 task 的 `prd.md`**：走查暴露的东西一定要回到 `prd.md`，否则实现时读的还是走查之前的旧共识。常见回写项——
   - 屏 / 序列清单增删（走查阶段发现漏了支撑页或异常态很常见）
   - 必须表达的状态增删
   - 走查中定掉的待确认划掉，新暴露的补上
   - 定稿方案的路径，以及「页面结构与区域分组沿用定稿原型」这句
3. **把定稿路径写进当前 task 的 `implement.jsonl`**——漏了这一步，前面全白做。

   ```bash
   python3 ./.trellis/scripts/task.py add-context "$TASK_DIR" implement \
     "docs/discovery/wireframe/<task-slug>/final/index.html" \
     "本片实现的结构依据：区域分组、字段顺序、状态表达沿用定稿"
   ```

   非 UI 分支列 `final/interaction-sketch.md`，同理。

   **`prd.md` 里写了路径不等于实现能看见它。** 实现期的子 agent 在一个全新 context window 里工作，它拿到的是 `implement.jsonl` 列出的文件内容；`prd.md` 里的一行路径字符串，混在好几份规范的注入内容中间，很容易被略过。实跑验证过这个失效形态：定稿画了、走查选案了、`prd.md` 也引用了，实现出来照样不是定稿的结构。

   Trellis 的 jsonl 规则说「不放 code files」，定稿 HTML 容易被误判进那条排除。**它不是 code，是结构依据**——不列进去，本 skill 的全部产出就停在了 planning，没有一个字到达真正写代码的地方。

4. **发现问题超出这一片的范围时**，不要私自扩大切片。两个出口：挪进 `brief.md` §4 的切片清单当后面的片，或者记进待确认。**切片边界变了要说出来，不能在原型里静默长大。**
5. 简报（`docs/discovery/brief.md`）的能力地图或阶段目标被走查证伪时，回去改简报并说明——这比在实现后发现便宜两个量级。

回写完就把材料交给 brainstorm 的 planning summary，由**用户**在那里批准。本 skill 不置任何 approved 标记。

## 保真度红线

完整清单见 [`references/fidelity-contract.md`](references/fidelity-contract.md)，六条硬的：

1. **只灰度** + 一个中性强调色（仅用来标出主操作）。无渐变、阴影、插画、品牌视觉、装饰动画。
2. **不定字体、配色、间距**——那是视觉阶段的事。文案只表达信息层级，不做营销润色。
3. **自包含单文件，零外部依赖**。无 CDN、无 npm、无外链字体图标。保证能 git 提交、能离线双击打开、下一个 session 能直接改。
4. **必须能点着看每个声明状态**：空、加载、错误、无权限，以及这一片列的其他状态。写在注释里不算——devbar 要能切过去。
5. **不生成生产级前端代码，不写进 `src/`**。原型是丢弃品，不是实现起点。
6. **不引入本片范围外的功能**。想加就先标记出来问，不静默添加。

## 有界收敛

压力落在**轮次与拍板**，不落在覆盖面：

| 项 | 规则 |
|---|---|
| 覆盖面 | = **当前切片**声明的全量（含本片的支撑页、异常态）。不允许只画主链路 |
| 一致性 | 出方案前先读既有 `*/final/`（两个分支都在这里），同类屏 / 同类序列沿用既有模式，偏离要说明 |
| 方案数 | 2–3 个，必须有结构性区分度 |
| 选案 | 一次定，落选要素当场合并，不留"再看看" |
| 走查轮次 | ≤ 2 轮。第 2 轮后的分歧记「待确认」或「挪到后面的切片」 |
| 单片规模警报 | 本片屏 / 序列 **> 6** 时提醒「这一片是不是切大了」，结论留痕，**不阻塞** |
| 问题记录 | 4 字段（现象/判定/动作/落点），不套 `design-review` 的 8 字段台账 |

## 与其他 skill 的边界

- **上游**：当前 task 的 `prd.md`（由 Trellis 的 `trellis-brainstorm` 产出）。本 skill 不自己定义切片范围，只按 `prd.md` 执行；发现范围有问题就回写，不私自扩大。
- **视觉设计与设计系统**：`ui-ux-pro-max`。本 skill 的产物**不是**视觉验收基准——那是视觉阶段的 `design-system/prototype.html`，两者阶段、保真度、目的都不同，名字也不同，不要互相替代、升级或合并。
- **设计准入**：`design-review` 不做需求评审，本 skill 不调用它。

## 文件清单

| 文件 | 用途 |
|---|---|
| `references/fidelity-contract.md` | 保真度红线、输入/输出契约、上限与停止规则（**权威源**） |
| `references/sop-guide.md` | 走查怎么做、方案怎么分化与合并、回写怎么写、FAQ |
| `assets/wireframe-base.html` | 自包含灰度骨架：内联 token + hash 路由 + devbar 状态切换 + 组件骨架 |
| `assets/interaction-sketch-template.md` | 非 UI 分支产物模板 |
| `assets/walkthrough-notes-template.md` | 走查发现（4 字段）+ 方案对比与选案留痕 |

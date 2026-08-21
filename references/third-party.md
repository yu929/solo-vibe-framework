# 第三方依赖

> **装什么和不装什么同样重要。** 每条「不装」都写了理由——没有理由的禁令会在半年后被自己推翻，然后重踩同一个坑。
>
> 核实日期：2026-08-21（vendor 判定与实测事实表）。上游变了先回来改这份，别在别处打补丁。

## 底座：Trellis

```bash
npm install -g @mindfoldhq/trellis@latest
trellis init -u <your-name>
```

要求 Node ≥ 18、Python ≥ 3.9。License **AGPL-3.0**。

### 不 fork

Trellis 官方只认四种 fork 理由：给它提 PR、改 npm 包发布内容、改 `trellis init/update` 的生成逻辑、明确要 fork。都不占。

定制落点全在本地，无需 fork：

| 想改什么 | 落点 |
|---|---|
| 阶段、下一步提示、要不要建 task、skill 路由、自定义状态 | 目标项目的 `.trellis/workflow.md`（单文件，改完不用重 build，下个 session 生效） |
| 编码约定 | `.trellis/spec/` |
| `task.py` 等运行时脚本 | 它们是生成到项目里的，直接改 |

fork 的实际代价：Trellis 是 pnpm monorepo（`packages/cli` + `packages/core` + 两个 submodule + husky + pyright），fork 后要维护 TS/Python 混合构建，且**不能再 `npm install -g` 拿上游更新**。

**本仓不发 `type: workflow` 模板。** 实测它是整份替换 `.trellis/workflow.md`（官方 marketplace 的条目就是 `path: workflows/native/workflow.md`），等于接管整个 Plan/Execute/Finish 正文。理由不是代价不可接受——`trellis workflow create <id>` 是**从 native 派生**的（`dist/cli/index.js:224-227`，写进 `.trellis/workflows/<id>.md`），`trellis workflow -s <id>` 也能把一个模板存进那个库而不动活跃 workflow，再合并没那么痛——理由是**这套流程一次都没实跑过**，现在写等于把猜测固化。

> 别把 `-s/--save <id>` 和 `-n/--create-new` 搞混：前者写 `.trellis/workflows/<id>.md`（每 task 可选的模板库），后者写 `.trellis/workflow.md.new`（活跃 workflow 的待合并副本）。实跑一遍知道该卡在哪，再决定。

#### workflow 变体：实测（2026-08-13，v0.7.0-beta.3）

**「再合并没那么痛」那句话是错的，实测修正**：`trellis workflow create <id>` 产出的是 native `workflow.md` 的**逐字全量副本**（709 行 / 38 KB，`diff` 完全相同），不是差异层。建一份就是接管整份 Plan/Execute/Finish 正文，从此上游改了要自己 diff 回来。**结论不变（仍然不发、不建），但理由现在有两条**：流程没实跑过，加上代价比原先估计的高。

解析优先级（`scripts/common/workflow_selection.py` 的 docstring，实测逐层验过）：

| 层 | 落点 | 提交与否 |
|---|---|---|
| 1 | active task 的 `task.json` `workflow` 字段（`task.py create --workflow <id>` / `task.py workflow <id>`） | 提交 |
| 2 | `.trellis/.developer` 的 `workflow=<id>` | **gitignore，个人级** |
| 3 | `.trellis/config.yaml` 的 `default_workflow` | 提交 |
| 4 | `.trellis/workflow.md` | 提交 |

**对本仓最要紧的一条实测结论：需求探索期（`no_task`）第 1 层用不上，第 2 层照样生效。** 官方两篇文档主推的都是 per-task pin，但简报阶段**没有 task**，那一层根本不参与解析。实测：清掉 active task 后只设 `.developer` 的 `workflow=`，per-turn breadcrumb 读的就是那个变体的 `[workflow-state:no_task]` 块。

所以「给需求探索期定制一套流程」在机制上唯一的落点是第 2 层——**而它是 gitignore 的个人级配置，跨项目不共享**。这也是本仓不往这个方向走的追加理由：定制的收益落在一个不可分发的位置上。

真需要在简报阶段给 agent 加规则时，**先用下面两个轻得多的东西**，别动 workflow。

在那之前，需要的那一段提示语靠手工粘进 `[workflow-state:no_task]`，见 [`../playbook/00-setup.md`](../playbook/00-setup.md) 步骤 5。

### 实测：它提供什么，不提供什么

> 本机版本 **v0.7.0-beta.3**。以下每条都有出处，上游变了回来改这里。

| 事实 | 出处 | 对本仓的后果 |
|---|---|---|
| `trellis-brainstorm` 已做需求收敛，且有硬门禁：没显式批准 planning summary 就不许 `task.py start` | `.agents/skills/trellis-brainstorm/SKILL.md` | **不自造门禁**，把原型接在它前面 |
| 它的前置是「task-creation consent 已给出」，先 `task.py create` 再问 | 同上 · Preconditions | task 之前是真空——简报的位置 |
| *"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* | 同上 | Trellis **主动**把产品层留给你 |
| 强制**一次一问**（"Ask only one question per message"） | 同上 · Question Rules | 见下「两套提问纪律」 |
| `.trellis/spec/` = *"Maintain coding standards"*，目录只有 frontend/backend/unit-test/guides | `trellis-meta/references/core/specs.md` | **纯编码规范，零产品内容**；也没有 `architecture/` |
| `finish-work` 四步：`get_context.py --mode record` → `git status` → `task.py archive` → `add_session.py` | `.agents/skills/trellis-finish-work/SKILL.md` | 归档 + journal，**零产品问题**，且 task-scoped |
| workflow-state hook 是 **parser-only**（*"reads whatever you put in the block"*） | `trellis-meta/references/customize-local/change-workflow.md` | 任何「门禁」都只是提示语 |
| **`--registry` 只认 `type: spec`，其他类型直接返回失败** | `dist/utils/template-fetcher.js:828` | `index.json` 只登记一条 |
| **`no-trellis` 是自带逃生舱**：prompt 里含这个独立词（词边界匹配，`no-trellisfoo` 不算），当轮 breadcrumb 完全不注入；不影响 SessionStart 与子 agent 注入 | `config.yaml` 的 `prompt_injection.skip_keyword`，**实测注入为空** | 写简报被反复问「要不要建 task」时的正解，见 [`../playbook/01-new-product.md`](../playbook/01-new-product.md) 常见卡点 |
| **spec 注入按 frontmatter `paths:` glob 触发，glob 不限于代码路径** | 实测：写一份 `paths: ["docs/discovery/**"]` 的 spec，`get_context.py --mode spec --file docs/discovery/slices.md` 命中；反向对照 `src/a.ts` 不命中 | 想给需求探索期加规则，这是**比 workflow 变体轻一个量级**的落点：一个文件、随 registry 分发、跨项目共享 |
| **`paths: [".trellis/tasks/**"]` 同样命中**——glob 可以指向 Trellis 自己的产物目录 | 实测 2026-08-21：临时项目里 `task.py create` 之后，`get_context.py --mode spec --file .trellis/tasks/08-21-probe/prd.md` 命中该 spec；`src/a.ts` 不命中 | `specs/universal/guides/task-artifacts.md` 靠这条在 agent 动 task 产物时自动注入 |
| **没有 `paths:` 的 spec 不参与路径路由**——它走 `guides/index.md` 指针那条路 | `scripts/common/spec_match.py` 只收 frontmatter 首行为 `---` 的文件；`spec_inject.py` 只处理 `SpecMatch` | 两条投递通道并存：**要在特定时刻自动出现的**加 `paths:`，**按需查阅的**留在 index 里 |
| **Claude Code 那侧的注入是 PostToolUse**（Codex 是 PreToolUse 且会 deny-once 让模型重读） | `shared-hooks/inject-spec-context.py` 的 Triggers 段 | 「写之前就读到」在 Claude Code 上**不保证**——所以 `task-artifacts.md` 还配了一段 `workflow.md` 提示语兜底 |

以下五条来自**第一次完整实跑**（2026-08-16，一个切片走完 Plan/Execute/Finish 并归档）：

| 事实 | 出处 | 对本仓的后果 |
|---|---|---|
| **`trellis-update-spec` 不知道 spec 是不是装来的**，全文无 registry / 源仓 / 上游字样，只写 `.trellis/spec/` | 该 SKILL.md 全文（357 行） | 经 registry 装的 spec，写回权威源**没有任何机制在守**——规则只能靠 [`../specs/universal/guides/review-adjudication.md`](../specs/universal/guides/review-adjudication.md) 的落点表 |
| **Phase 2 → Phase 3 是连着自动跑完的**，唯一会停下来问用户的是 3.4 的提交计划（*"Present the plan once, ask for one-shot confirmation"*） | `workflow.md` 3.4 step 5 | **人工验收没有位置**，必须手动插在 check 之后。这就是拍板 5 的由来 |
| **3.4 的脏文件分类依赖会话记忆**：分「AI-edited **this session**」与「Unrecognized」两堆 | `workflow.md` 3.4 step 3 | 实现到提交之间**不要换 session**，换了所有文件都变成「不认识的」，那份提交计划就废了 |
| **换 session 靠单文件 fallback 续上**：`.trellis/.runtime/sessions/` 里**恰好 1 个**文件才认，0 个或 ≥2 个直接返回「无活跃 task」（源码注释：*refuses to guess across windows*） | `scripts/common/active_task.py:599-621` | 单窗口串行干活无缝；**同时开两个窗口对同一个仓库，换 session 就丢活跃 task** |
| **`task.py start` 不校验任何产物**——只解析路径、写指针、翻状态，不看 `prd.md` 在不在、不看 jsonl 填没填 | `scripts/task.py` `cmd_start` | 推论：**别用 `start` 去修丢失的指针**，它会顺手把 `planning` 翻成 `in_progress`，把开工闸门跳过去且不报错 |

**推论：纯用 Trellis 看不到产品全貌。** 跑五十个 task 之后你有一堆编码规范 + 一堆已归档的单次改动 + 一条时间流水，没有一处回答「这个产品现在整体是什么」。所以完整 PRD 与 `docs/discovery/slices.md` **都不是消耗品**——它们是这一层仅有的宿主，跟着阶段目标更新，不随发布删除。

### 四种分发机制（最容易踩的一处）

它们长得都像「装个东西进来」，落点和机制完全不同：

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| **一个** `specs/<track>`（自带 guides） | `trellis init --registry ... --template <id>` | 项目 `.trellis/spec/` |
| **本仓 skill + vendor skill** | **`scripts/install-skills.sh`**（全局软链） | `~/.claude/skills/` |
| Trellis 自带 skill | `trellis init --claude` | 项目 `.claude/skills/` |
| workflow 模板 | `--workflow` / `--workflow-source` / `trellis workflow` | 项目 `.trellis/workflow.md` |

**registry 模板的路径会被抹平**：`specs/<id>/` 的**内容**复制进 `.trellis/spec/`，`<id>/` 那一层不保留。所以 `specs/web-fullstack/frontend/index.md` 落成 `.trellis/spec/frontend/index.md`（正好是 Trellis 自己的目录约定），而**不是** `.trellis/spec/web-fullstack/frontend/index.md`。

#### 一个项目只能装一个 spec 模板

**跑第二次 init 追加模板，会让先装的那个静默失去更新来源。** 源码证据：

| 事实 | 出处 |
|---|---|
| `.trellis/config.yaml` 的 `registry.spec` 只有**单数**的 `template` 字段 | `dist/utils/registry-config.js:12-18` |
| `writeSpecRegistryConfig` 命中已有的 `template:` 行就**整行替换** | 同文件 `:121-126` |
| 每次带 `--template` 的 init 都会写这份配置 | `dist/commands/init.js:1384, 1512` |
| `trellis update` 只读 `config.template` 那**一个** id 去刷新 | `dist/commands/update.js:469, 505, 510` |

所以先装轨规范、再装 `universal-guides` 之后，`trellis update` 从此只刷新 guides，**含安全规则的轨规范再也收不到修复**。而 update 命令仍然成功、仍然打印绿色——这就是它能藏住的原因。

**做法：轨模板自带 guides，只跑一次 init。** `specs/<track>/guides/` 是 `specs/universal/guides/` 的生成副本，由 `scripts/sync-spec-guides.sh` 同步、`scripts/test-spec-templates.sh` 卡住漂移。`universal-guides` 模板仍然保留，但它的用途窄了一条：**只给还没有轨规范的项目单独装**，永远不和轨模板一起装。

顺带解决了一个只在安装态才暴露的断链：`<id>/` 被抹平之后，`../../universal/guides/x.md` 会解析到 `.trellis/universal/guides/x.md`（不存在）。guides 与轨规范同级之后，`../guides/x.md` **在源码树和安装树里指的是同一个东西**。这类缺陷在仓库里跑任何常规链接检查都是绿的，所以必须按安装树查——`test-spec-templates.sh` 用例 1 做的就是这件事。

**registry 为什么装不了 skill**——`dist/utils/template-fetcher.js:828`：

```js
// Only support spec type in MVP
if (resolved.type !== "spec") {
    return { success: false,
      message: `Template type "${resolved.type}" is not supported yet (only "spec" is supported)` };
}
```

同文件 `:18` 的 `INSTALL_PATHS` 里确实有 `skill: ".agents/skills"`，但类型闸在前面，那行是死代码。即便上游将来打开，落点也是**项目内**的 `.agents/skills`，不是 `~/.claude/skills/`——跨项目的 skill 还是得软链。`dist/configurators/claude.js:96` 写的是项目内 `.claude/skills/`，但只装 Trellis 自己的 bundled skill。

**所以 `index.json` 只登记 `type: spec`**（现在三条：`universal-guides`、`web-fullstack` 与 `java-stack`）。上游支持非 spec 类型之后，才可以把 skill 加进去。

### 两套提问纪律会打架

| 来源 | 节奏 | 停止规则 |
|---|---|---|
| Trellis `trellis-brainstorm` | **一次一问** | 用户显式批准 planning summary |
| mattpocock `grilling` | 一轮问完 frontier | frontier 空（无界） |

**本仓取 Trellis 的**，理由是它在 planning 阶段是强制的，另一套只会跟它对着来。`grilling` 仍然有用——用在**写简报**那一步（还没建 task，brainstorm 没上场），frontier 让一轮问得更饱满。

赌注是：**brainstorm 问的每个问题都是简报里缺的一条，补进简报之后下一片会明显变短**（它的 Evidence Rule 要求「能从仓库文档查到的就别问用户」）。**这是推测，实跑后回来修正。**

### `trellis update` 的双向性

`.trellis/.template-hashes.json` 记录每个生成文件的 SHA256，`update` 靠它识别本地改动、**不覆盖你改过的文件**。

反面：**你改过的文件，上游改进你也拿不到**。所以需要定期 diff 复核，范围只盯 `workflow.md` 与 `spec/guides/`——不必盯整棵树。

如果想留后路：fork 一份**只读镜像**（不改、不发包），只用来 diff 和查源码，零维护。

## mattpocock/skills — 取六个（已 vendor）

### 装

| skill | 取它什么 | 附带依赖 |
|---|---|---|
| `grilling` | design tree + frontier 分轮批量提问：一轮问完整个 frontier、编号 + **每题附推荐答案**、依赖未决的排到下一轮、「Finding facts is your job, never the user's」（环境事实派子 agent 查，不问用户） | 无 |
| `grill-me` | 用户可调用薄壳（`disable-model-invocation: true` + 一句 `Run a /grilling session`） | 依赖 `grilling` |
| `grill-with-docs` | 逼问的同时把术语与决策落盘。**全文只有一句** `Call the Skill tool twice, for "grilling" and "domain-modeling"` | **强依赖 `domain-modeling`**，少了它第二次调用指向不存在的东西 |
| `domain-modeling` | `CONTEXT.md` 术语表（*"a glossary and nothing else"*）+ `docs/adr/` + **ADR 三判据原件** | 无 |
| `prototype` | **只用 LOGIC 分支**：为回答「这个逻辑/状态模型对不对」造一个单文件可分享 HTML，把状态机推过纸上想不清的用例，非开发者也能驱动 | 无 |
| `writing-for-agents` | 写给 agent 读的文档的元规则：context pointer 的措辞决定触发可靠性、两种 load 的预算、信息层级与 progressive disclosure、completion criterion 的清晰度与要求量、leading words | sibling `SKILL-MECHANICS.md` |

**它的停止条件是「frontier 空」，无界。** 本仓不给提问加轮次上限。

**那它在 PRD 阶段靠什么收敛？** 靠它自己的两条：frontier 空即停，以及 *"Finding facts is your job, never the user's"*（环境事实派子 agent 查，不问用户）。这一步在 task 之外，Trellis 的 brainstorm 还没上场，所以确实没有外部闸——**这是有意接受的**：需求阶段问题问不够，代价会在后面每一片重复付。真正需要有界的是走查轮次和选案次数，那两条纪律现在落在 `skills/vertical-slicing/` 与 `ui-ux-pro-max` 的用法约定里。

**ADR 三判据**（难以回退 + 没上下文会困惑 + 真有取舍，三条全中才写）**正文在上游原件** `vendor/mattpocock-skills/domain-modeling/SKILL.md`。本仓一度维护过一份抄本（`playbook/assets/decisions-template.md`），2026-08-21 随 `domain-modeling` 装回来一起删掉了——**同一套判据两个落点必然分叉**。要改判据只能改用法，不能改原件（vendor 只读）。

### 明确不装

| 不装 | 理由 |
|---|---|
| **`setup-matt-pocock-skills`** | 它配置的正是 issue tracker 与 label 词表。**上游 README 提示必装，我们必须不装** |
| **`to-spec`（本体）** | 其 SKILL.md 步骤 3 要求 publish 到 issue tracker 并打 `ready-for-agent` 标签，且要求先跑 `setup-matt-pocock-skills` |
| **`to-tickets`** | **判据 2026-08-21 更新**：上游现在有本地文件模式（`.scratch/<feature>/issues/<NN>-<slug>.md`），且 `disable-model-invocation: true`（只能用户显式调用，不会自动抢）。冲突**降级但没消失**——`.scratch/.../issues/` 与 `.trellis/tasks/` 仍是两个任务系统。**结论不变，理由已换**。它的四条纪律见下 |
| `tdd` / `code-review` / `triage` | 都建立在 issue tracker 工作流上 |
| **`addyosmani/agent-skills` 的 `planning-and-task-breakdown`**（MIT，2026-08-14） | 三条：① `tasks/plan.md` + `tasks/todo.md` 是第二任务系统，且它明说 `/build` 与下游工具期望该路径 ② **粒度锚在文件数上**（≤5 文件），而一个真垂直切片（表 + 迁移 + 服务 + 路由 + 页面）天然 5 文件起，按它的表被判 M/L 会诱导往横切走 ③ `## See Also` 引 `../../references/definition-of-done.md`，**跨目录引用装到 `~/.claude/skills/` 就断** |

**但要借它们的纪律**（不是代码）。

**`to-spec` 两条**，对写 `prd.md` 与 `design.md` 仍然成立：

- 不写具体文件路径和代码片段（会很快过时）；例外是比散文更精确的 schema / 状态机 / 类型形状
- 只合成已有共识，不新问问题——要问的在 grilling 阶段已经问完

**`to-tickets` 四条**，全部落进本仓的 `skills/vertical-slicing/`：

| 借什么 | 为什么它值钱 |
|---|---|
| **切片尺度锚 = 一个全新 context window**（*"sized to fit in a single fresh context window"*） | 本仓原有判据只答「是不是切片」，不答「切得对不对大」。这个锚比文件数/工时对——Trellis 的实现就是子 agent 在全新 context 里跑 |
| **宽重构是垂直切片的显式例外，走 expand–contract** | 影响面铺满全仓的机械改动切不成垂直片，硬切每片都红。本仓原有判据遇到它会判「不是切片」然后**没有下文** |
| **阻塞边 + frontier 替代顺序列表** | 每片自己声明被谁阻塞，frontier = blocker 全完成的片。比「依赖」列精确，且正好补上 Trellis 那个洞（*"Parent/child structure is not a dependency system"*） |
| **第 4 步「Quiz the user」** | 编号清单 + 三个问题（粒度 / 阻塞边 / 合并或拆分）+ 迭代到批准。这正是本仓的拍板形态 |

**`addyosmani` 一条**：「**标题里出现「和 / 与 / and」就是两个任务**」——零成本、可判定的拆分信号。它的尺寸表不借，锚错了。

**不借的是发布步骤**：发布目标是 `docs/discovery/slices.md`（切片地图）与 `.trellis/tasks/<task>/prd.md`，不是 issue tracker，也不是 `tasks/todo.md`。

### 装法：vendor 进本仓，不用上游安装器

**本仓已经把两个 skill 落在 [`../vendor/mattpocock-skills/`](../vendor/mattpocock-skills/)**，跑 `scripts/install-skills.sh` 一并软链到 `~/.claude/skills/`。不需要跑 `npx skills add`。

**为什么 vendor 而不是各项目各装一份**：

| | 上游安装器 | vendor 进本仓 |
|---|---|---|
| 落点 | **项目仓库**（上游 README：*"It writes the skills into your repo"*） | `~/.claude/skills/`，全局一份 |
| N 个项目 | N 份拷贝、N 次 `npx skills update` | 一份 |
| 装错的机会 | 40 选 2、**安装器明确提示 `setup-matt-pocock-skills` 必选**（原文 *"make sure `setup-matt-pocock-skills` is one of them"*）而我们必须不勾 | 0 |
| 与本仓自有 skill 的分发 | 不一致（一半在项目、一半在全局） | 一致 |

这两个跟**流程**走不跟技术栈走，本来就该跨项目。体量约 5 KB / 4 个文件，diff 成本几乎为零。

**规矩**：

- `vendor/` 是**只读**拷贝，改了就跟上游 diff 不上。版本固定在 `vendor/mattpocock-skills/.upstream-sha`。
- **`.upstream-manifest` 是漂移判据**（每个受管文件一行 sha256）。为什么不能只比 `.upstream-sha`：文件被误改、被误删、被塞进新文件时那个 sha 一个字都不会变，只看它就会把漂移报成「已是最新」。清单让这个检查**离线**，因而能被回归测试（`scripts/test-sync-vendor.sh`）——依赖网络的检查会抖，当不了测试。
- **必须保留上游 LICENSE**（`vendor/mattpocock-skills/LICENSE`，MIT）。这不是礼节而是再分发条件：MIT 原文要求「副本或实质部分必须保留版权与许可声明」，而 `vendor/` 就是一份副本。`scripts/sync-vendor.sh` 启动时硬断言该文件存在，缺了直接 exit 1——靠人记得是不够的。
- 上游改 LICENSE 时同步脚本会把 diff 打出来。**那种 diff 要单独判读**：许可条款变了可能意味着不能再 vendor 了，不是普通内容变更。

**跟随上游**：

```bash
scripts/sync-vendor.sh --verify   # 只查本地漂移，完全离线（CI 与测试走这条）
scripts/sync-vendor.sh            # 查漂移 + 报告上游差异，不改任何东西
scripts/sync-vendor.sh --pull     # 读完 diff、确认要跟随，才更新（并重建校验和清单）
```

**先查漂移再查上游，顺序不能反。** 「本地被改过」和「上游前进了」是两回事，混进同一个 diff 就读不出谁是谁——所以漂移状态下只读模式直接停住，不做上游比对。

默认只读是有意的：自动跟随上游等于让别人的改动在你不知情时改变你的工作流。**每晚的 GitHub workflow 也守这条**——它只开 PR，不自动 merge，见本文件末「上游同步」。

**两种上游装法本身也不能兼用**（README 原文：*"Pick one — installing both leaves you with every skill twice."*）。如果你以前装过，先卸掉再跑本仓脚本：

```bash
# claude plugins install mattpocock-skills   ← 受管只读全量装，无法挑选
# npx skills@latest add mattpocock/skills    ← 拷进项目仓库，per-repo
```

**还需不需要 `grilling`——待实跑验证。** 本仓已决定提问纪律取 Trellis 的（见上「两套提问纪律会打架」），而 Trellis 的 brainstorm 已经有了 grilling 的两条核心（Evidence Rule、每题附推荐答案），差别只剩 frontier 批量 vs 一次一问。所以 grilling 的净增量只剩「**出完整 PRD 那一步、brainstorm 还没上场时的批量提问**」——真实但很窄。

**新流程下这个净增量变大了一点**：0-1 的前四步（需求讨论 → 完整 PRD → 验字段 → 反写）全在 task 之外，`grill-with-docs` 在那里没有竞争者。实跑一次完整 PRD 之后再定去留。不需要了就删掉 `vendor/mattpocock-skills/<name>/`、从 `scripts/install-skills.sh` 的 `VENDORED` 数组移除、**并加进 `RETIRED` 数组**（否则已存在的软链会留着继续被触发），同时从 `scripts/sync-vendor.sh` 的 `SKILLS` 数组移除。

### `domain-modeling`：退役过，2026-08-21 装回来

**它曾被整个删除**，理由是它要求维护 `CONTEXT.md` 当术语源真，而当时本仓的术语结论落在产品简报里，两处都自称术语权威，一次正常的术语讨论就能产生两个互相漂移的事实源。

**装回来是因为 `grill-with-docs` 强依赖它**——上游那个 skill 全文只有一句 `Call the Skill tool twice, for "grilling" and "domain-modeling"`，没有它第二次调用指向不存在的东西。

冲突现在有**两处**（原记录只有一处）：

| 它的产出 | 本仓曾经的 | 冲突 |
|---|---|---|
| `CONTEXT.md`（且要求术语一裁决就**立刻**更新、不许攒） | 简报 §5「措辞」 | 两个术语源真 |
| `docs/adr/` + 三判据 | `docs/discovery/decisions.md` + **同一套三判据**（本仓那份就是从它抄的） | 两个决策落点 + 一份抄本 |

**解法：本仓让位。** 理由是机制性的，不是「上游更好」——当年判定它时列过三条路径，「改 vendor 原件让它写别的位置」因**违反 vendor 只读**被否；那条理由今天原样成立。既然要装，只能接受它的落点。

- **术语源真 = `CONTEXT.md`**。完整 PRD 的术语章改成**指向它**，不自己存一份
- **决策源真 = `docs/adr/`**。`docs/discovery/decisions.md` 与 `playbook/assets/decisions-template.md` **已删除**，ADR 三判据（难以回退 + 没上下文会困惑 + 真有取舍，三条全中才写）回到上游原件 `vendor/mattpocock-skills/domain-modeling/SKILL.md`，本仓不再维护抄本

**代价说清**：`decisions.md` 是 2026-08-13 才加的，理由是实测确认 Trellis 四处候选宿主全都不记「当初否掉了什么」。换成 `docs/adr/` 之后**那个需求仍然被满足**（ADR 正是记这个的），只是宿主和格式换成上游的。**需求不丢，宿主换人**，并且少一个漂移源。

**要再退役它**：先解决 `grill-with-docs` 怎么办（一起退，还是自己写一个只调 `grilling` 的壳），再走「删一个 vendor skill 要动四处」。

### `prototype`：只用 LOGIC 分支

上游这个 skill 分两支，**第一步就是 "Pick a branch"**：

| 分支 | 产物 | 本仓 |
|---|---|---|
| **LOGIC**（*"Does this logic / state model feel right?"*） | 单个可分享 HTML，free-play 按钮 + 分页引导走查，把状态机推过纸上想不清的用例 | **用它**——对应 0-1 流程「每个模块即抛 prototype，验证字段」 |
| UI（*"What should this look like?"*） | 真项目路由上开几个变体，URL search param 切换 | **不用**——归 `ui-ux-pro-max`。两者都答「这该长什么样」，但一个是在真项目里开变体、一个是全量高保真 + 设计系统，混用会长出两套视觉源真 |

**这条纪律是提示语，不是判定。** skill 是整个装的，没有任何机制挡得住它选 UI 分支。发现它跑去 UI 分支就当场拉回来，并把实际手感记在这里。

**它的规则 1 与规则 6 跟本仓「探索」纪律曾经对撞**（*"Locate the prototype code close to where it will actually be used"*、*"commit it to a throwaway branch"* vs 本仓的「不进 `src/`、验完就删」）。**新流程下这个冲突消失了**：验字段发生在 0-1 流程步骤 3，早于步骤 6「定后端轨」——那时候还没有 `src/`。

## spec-anchor — 整体不装

[`linziyanleo/spec-anchor`](https://github.com/linziyanleo/spec-anchor)：375 文件 / 7.2 MB、23 个 shell 脚本、12+ 命令、82 个测试、54 份 reference。

它是 **Trellis 的竞品而非补充**。两套 spec 系统 = 两套命令 + 两棵文档树 + 两处记任务，solo 维护不动。

它做得并不差——比 Trellis 严谨得多（有 schema 校验和测试）。问题是**海拔不匹配**：为多人、多模块、长期演进设计。两条来自它**自身仓库**的证据：

1. 它的 `.specanchor/module-index.md` 显示自己两个模块**全是 `DRIFTED`**——漂移检测工作正常（准确报出了漂移），但没人去修。对 solo 来说，装一个永远亮黄灯的仪表盘是负价值：要么去修（成本），要么学会无视（那就没用了）。
2. 它自己的 finding `F-20260530-001` 记录：boot/assemble 每次调用重复输出 Global summary，同一 session 多轮激活会**线性撑大上下文**。一个管理上下文的系统在制造上下文膨胀。

### 但借两个概念（只借概念，不借实现）

| 概念 | 落点 | 克制 |
|---|---|---|
| **findings 分层**：编码期发现先落 finding，确认后才升级进 spec，不允许 AI 直接改 spec | `specs/universal/guides/review-adjudication.md` | 字段**只要 4 个**（现象 / 证据 / 该改哪个 spec / 状态）。原版是 11 个 frontmatter 字段 + 6 个小节，那是多人海拔 |
| **模块覆盖索引**：哪些模块有 spec、哪些没有、上次同步日期 | 待定，**还没有宿主** | 落地时是手工维护的三列小表，**不要那 23 个脚本** |

## 已退役（软链要删掉）

旧仓 `~/Developer/skills` 的这些 skill 已退役。**它们的软链如果还在 `~/.claude/skills/`，会继续被触发**——最典型的后果是你描述一个需求，被旧的 PRD skill 接走去走已经废弃的流程。

| 退役的 | 掉下来的能力去哪了 |
|---|---|
| `product-brief` | 降级成 [`skills/vertical-slicing/assets/slices-template.md`](../skills/vertical-slicing/assets/slices-template.md)，一份模板不是 skill。它只剩「阶段目标 + 切片清单 + frontier」三节 |
| `prd-generator` / `-noweb` | 字段级需求不再预先穷举，随 task 在 `prd.md` 里就近定义（Trellis 的 `task.py create` 自带模板，本仓**不再提供** task 级 PRD 模板） |
| `system-design` / `design-system-java` | 承重决策落 `docs/adr/`（由 `domain-modeling` 维护）；切片顺序落 `docs/discovery/slices.md` |
| **`lofi-prototype`**（本仓自有，2026-08-21 退役） | 新流程里全量高保真在切片**之前**就定稿，task 内再出一次低保真等于跟定稿构成两个结构源真。它承接的实跑结论「**定稿必须进 `implement.jsonl`**」已改由 `vertical-slicing` 接住（`slices.md` 切片清单第四列 → 每片进 task 时填 jsonl）。保真度红线、走查轮次上限随之作废 |

清理命令见 [`../playbook/00-setup.md`](../playbook/00-setup.md) 步骤 2。**脚本只删软链**：退役名如果在 `~/.claude/skills/` 下是真目录（可能是你自己的同名 skill），它报错退出而不是删除。这条由 `scripts/test-install-skills.sh` 用例 1 卡住。

## 仍在用的其他第三方

| skill | 何时用 | 边界 |
|---|---|---|
| `ui-ux-pro-max` | PRD 收敛到字段级之后的全量高保真与设计系统 | **不早于 PRD 收敛**——提前画等于替还没定的需求猜结构，而猜出来的结构一旦成了定稿，后面每一片都照着它实现。组件 API 不归它，归 shadcn skill / MCP |
| `code-review-skill`（awesome） | 通用代码正确性/可读性评审 | 轨不变量由 `specs/<track>/` 的 Pre-Development Checklist 与 Quality Check 管，不混用 |
| `skill-creator` | 改完 skill 校验 frontmatter 与相对链接 | — |
| `shadcn/ui` 官方 skill + shadcn MCP | 两条轨写前端组件时 | **per-project 装，本仓不分发**，只规定怎么用——见下 |

### shadcn 官方 skill + MCP：本仓不分发，只规定怎么用

两样都是 **per-project** 装的，本仓的两条分发机制都覆盖不到：

| 东西 | 装到哪 | 为什么本仓管不了 |
|---|---|---|
| 官方 skill（`skills add shadcn/ui`） | **项目仓**的 `.claude/skills/` | 和 mattpocock 同一个安装器，上游原话是 *"writes the skills into your repo"*。`scripts/install-skills.sh` 只管 `~/.claude/skills/` 那一层全局软链 |
| MCP（`shadcn@latest mcp init --client claude`） | **项目根** `.mcp.json` | 是可执行配置，按 `AGENTS.md` 的落点表归 starter |

`index.json` 也放不下它们——registry 只收 `type: spec`。

所以本仓只做一件事：**在两条轨的 `frontend/index.md` 里规定「怎么用」，并给出没装时的替代动作**。装法在 [`../playbook/00-setup.md`](../playbook/00-setup.md) 步骤 4.2。

**为什么值得接**：web-fullstack 轨的 `components.json` 是 `style: base-nova`（Base UI 内核），而公开资料里绝大多数 shadcn 写法是 Radix 时代的。轨规范早就禁了 `@radix-ui/*`，但那是否定式规则——它说不许写什么，没说对的写法去哪拿。官方 skill 读 `components.json` 就知道内核是哪个，补的正是这一半。

**它替代不了 `ui-ux-pro-max`，也不该被它替代**：那个 skill 的 description 声称集成 shadcn MCP，但正文没有任何 MCP 调用——它读自带的 `data/stacks/shadcn.csv`，是一份静态快照。视觉归 `ui-ux-pro-max`、组件 API 归 shadcn skill / MCP，这条分界写进了两条轨的规范正文，理由和 `prototype` 只用 LOGIC 分支是同一个：两个来源同时回答同一个问题，就会长出两套源真。

**这条规则没有机器在卡。** 「有没有先查 MCP」不可判定，它是检查点不是门禁。可判定的那条（`components/ui/*` 勿手改）规范正文里已经有了。

## 上游同步

分两半，**状态不同**：

### vendor skill —— 已建（`.github/workflows/sync-vendor.yml`）

每晚 03:00（Asia/Shanghai）跑一次 `scripts/sync-vendor.sh --pull`，**只在 skill 内容或 LICENSE 真的变了时开 PR**，绝不自动 merge。你在 PR 里读 diff，决定跟不跟。

三个设计取舍，都不是随手定的：

| 取舍 | 为什么 |
|---|---|
| **开 PR，不直接提交 main** | 自动跟随上游等于让别人的改动在你不知情时改变你的工作流。PR 保留「读完 diff 再决定」这个动作，只是把 diff 送到你面前 |
| **只有内容变了才开 PR**（`.upstream-sha` 被排除在判据外，然后整棵 vendor 回滚） | 上游在别处提交时 `--pull` 只会 bump sha，那种 PR 是纯噪音。代价是 sha 会停在旧值、每晚重新拉一次——**换零噪音，划算** |
| **固定分支名 `chore/sync-vendor`** | 每晚复用同一个 PR，不堆一串 |

两条运行时注意：GitHub 定时任务在整点高峰会被**延迟**，别当准点闹钟；**仓库连续 60 天无提交活动，GitHub 会自动停用 schedule**，到时要手动 `workflow_dispatch` 或去 Actions 页面重新启用。

**⚠️ 未实跑验证**：这份 workflow 写成时本仓还没有 GitHub remote，一次都没跑过。第一次推上去后用 `workflow_dispatch` 手动触发一次，对不上的地方当场改。

### Trellis 本体 —— 仍未建（有意的）

Trellis 更新频繁（1300+ commits）。将来同样是 GitHub Action 定期 diff 上游、自动提 PR、人工审核是否跟随。

**范围只盯两处**：`.trellis/workflow.md` 与 Trellis 内置的 `spec/guides/`。整棵树没必要跟——`.template-hashes.json` 已经护住了你改过的文件，你需要知道的只是「上游把我改过的那几个文件改了什么」。

**先不建**，等这套流程实跑过一遍再说——现在不知道该盯什么。和 vendor 那半的区别在这里：vendor 是三个固定文件的字面 diff，盯什么是确定的；Trellis 那半盯的是「我改过的文件被上游改了什么」，而**我还没改过任何一个**，现在建等于建一个永远报空的任务。

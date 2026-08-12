# 第三方依赖

> **装什么和不装什么同样重要。** 每条「不装」都写了理由——没有理由的禁令会在半年后被自己推翻，然后重踩同一个坑。
>
> 核实日期：2026-08-12。上游变了先回来改这份，别在别处打补丁。

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

**本仓不发 `type: workflow` 模板。** 实测它是整份替换 `.trellis/workflow.md`（官方 marketplace 的条目就是 `path: workflows/native/workflow.md`），等于接管整个 Plan/Execute/Finish 正文。理由不是代价不可接受——`trellis workflow create <id>` 是**从 native 派生**的，`--create-new` / `--save <id>` 还能写 `.trellis/workflows/<id>.md` 而不动活跃 workflow，再合并没那么痛——理由是**这套流程一次都没实跑过**，现在写等于把猜测固化。实跑一遍知道该卡在哪，再决定。

在那之前，需要的那一段提示语靠手工粘进 `[workflow-state:no_task]`，见 [`../playbook/00-setup.md`](../playbook/00-setup.md) 步骤 5。

### 实测：它提供什么，不提供什么

> 本机版本 **v0.7.0-beta.3**。以下每条都有出处，上游变了回来改这里。

| 事实 | 出处 | 对本仓的后果 |
|---|---|---|
| `trellis-brainstorm` 已做需求收敛，且有硬门禁：没显式批准 planning summary 就不许 `task.py start` | `.agents/skills/trellis-brainstorm/SKILL.md` | **不自造门禁**，把原型接在它前面 |
| 它的前置是「task-creation consent 已给出」，先 `task.py create` 再问 | 同上 · Preconditions | task 之前是真空——简报的位置 |
| *"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* | 同上 | Trellis **主动**把产品层留给你 |
| 强制**一次一问**（"Ask only one question per message"） | 同上 · Question Rules | 见下「三套提问纪律」 |
| `.trellis/spec/` = *"Maintain coding standards"*，目录只有 frontend/backend/unit-test/guides | `trellis-meta/references/core/specs.md` | **纯编码规范，零产品内容**；也没有 `architecture/` |
| `finish-work` 四步：`get_context.py --mode record` → `git status` → `task.py archive` → `add_session.py` | `.agents/skills/trellis-finish-work/SKILL.md` | 归档 + journal，**零产品问题**，且 task-scoped |
| workflow-state hook 是 **parser-only**（*"reads whatever you put in the block"*） | `trellis-meta/references/customize-local/change-workflow.md` | 任何「门禁」都只是提示语 |
| **`--registry` 只认 `type: spec`，其他类型直接返回失败** | `dist/utils/template-fetcher.js:828` | `index.json` 只登记一条 |

**推论：纯用 Trellis 看不到产品全貌。** 跑五十个 task 之后你有一堆编码规范 + 一堆已归档的单次改动 + 一条时间流水，没有一处回答「这个产品现在整体是什么」。所以 `docs/discovery/brief.md` **不是消耗品**——它是这一层唯一的宿主，跟着阶段目标更新，不随发布删除。

### 四种分发机制（最容易踩的一处）

它们长得都像「装个东西进来」，落点和机制完全不同：

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| **一个** `specs/<track>`（自带 guides） | `trellis init --registry ... --template <id>` | 项目 `.trellis/spec/` |
| **本仓 skill + vendor skill** | **`scripts/install-skills.sh`**（全局软链） | `~/.claude/skills/` |
| Trellis 自带 skill | `trellis init --claude` | 项目 `.claude/skills/` |
| workflow 模板 | `--workflow` / `--workflow-source` / `trellis workflow` | 项目 `.trellis/workflow.md` |

**registry 模板的路径会被抹平**：`specs/<id>/` 的**内容**复制进 `.trellis/spec/`，`<id>/` 那一层不保留。所以 `specs/web-fullstack/frontend/index.md` 落成 `.trellis/spec/frontend/index.md`（正好是 Trellis 自己的目录约定），而**不是** `.trellis/spec/web-fullstack/frontend/index.md`。

#### 一个项目只能装一个 spec 模板（曾经写错，已改正）

**旧版本的这份文档教人跑两次 init、第二次带 `--append` 装 guides。那是错的**，会让轨规范静默失去更新来源。源码证据：

| 事实 | 出处 |
|---|---|
| `.trellis/config.yaml` 的 `registry.spec` 只有**单数**的 `template` 字段 | `dist/utils/registry-config.js:12-18` |
| `writeSpecRegistryConfig` 命中已有的 `template:` 行就**整行替换** | 同文件 `:121-126` |
| 每次带 `--template` 的 init 都会写这份配置 | `dist/commands/init.js:1384, 1512` |
| `trellis update` 只读 `config.template` 那**一个** id 去刷新 | `dist/commands/update.js:469, 505, 510` |

所以第二条命令把配置改成 `universal-guides` 之后，`trellis update` 从此只刷新 guides，**含安全规则的轨规范再也收不到修复**。而 update 命令仍然成功、仍然打印绿色——这就是它能藏住的原因。

**现在的做法：轨模板自带 guides，只跑一次 init。** `specs/<track>/guides/` 是 `specs/universal/guides/` 的生成副本，由 `scripts/sync-spec-guides.sh` 同步、`scripts/test-spec-templates.sh` 卡住漂移。`universal-guides` 模板仍然保留，但它的用途窄了一条：**只给还没有轨规范的项目单独装**，永远不和轨模板一起装。

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

**所以 `index.json` 只登记 `type: spec`**（现在两条：`universal-guides` 与 `web-fullstack`）。上游支持非 spec 类型之后，才可以把 skill 加进去。

### 三套提问纪律会打架

| 来源 | 节奏 | 停止规则 |
|---|---|---|
| Trellis `trellis-brainstorm` | **一次一问** | 用户显式批准 planning summary |
| mattpocock `grilling` | 一轮问完 frontier | frontier 空（无界） |
| 本仓旧版 `product-brief`（已退役） | 一轮批量问 | ≤2 轮（有界） |

**本版取 Trellis 的**，理由是它在 planning 阶段是强制的，另外两套只会跟它对着来。`grilling` 仍然有用——用在**写简报**那一步（还没建 task，brainstorm 没上场），frontier 让一轮问得更饱满。

赌注是：**brainstorm 问的每个问题都是简报里缺的一条，补进简报之后下一片会明显变短**（它的 Evidence Rule 要求「能从仓库文档查到的就别问用户」）。**这是推测，实跑后回来修正。**

### `trellis update` 的双向性

`.trellis/.template-hashes.json` 记录每个生成文件的 SHA256，`update` 靠它识别本地改动、**不覆盖你改过的文件**。

反面：**你改过的文件，上游改进你也拿不到**。所以需要定期 diff 复核，范围只盯 `workflow.md` 与 `spec/guides/`——不必盯整棵树。

如果想留后路：fork 一份**只读镜像**（不改、不发包），只用来 diff 和查源码，零维护。

## mattpocock/skills — 只取两个（已 vendor）

### 装

| skill | 取它什么 | 附带依赖 |
|---|---|---|
| `grilling` | design tree + frontier 分轮批量提问：一轮问完整个 frontier、编号 + **每题附推荐答案**、依赖未决的排到下一轮、「Finding facts is your job, never the user's」（环境事实派子 agent 查，不问用户） | 无 |
| `grill-me` | 用户可调用薄壳（147 字节：`disable-model-invocation: true` + 一句 `Run a /grilling session`） | 依赖 `grilling` |

**它的停止条件是「frontier 空」，无界。** 本仓**不再**给提问加轮次上限（旧版那条 ≤2 轮已随 `product-brief` 一起退役，见下节），所以别再写「用自有的 ≤2 轮给它兜底」——那条纪律不存在了，写了就是指向一个不存在的规则。

**那它在简报阶段靠什么收敛？** 靠它自己的两条：frontier 空即停，以及 *"Finding facts is your job, never the user's"*（环境事实派子 agent 查，不问用户）。这一步在 task 之外，Trellis 的 brainstorm 还没上场，所以确实没有外部闸——**这是有意接受的**：简报阶段问题问不够，代价会在后面每一片重复付。真正需要有界的是走查轮次和选案次数，那两条纪律落在 `lofi-prototype` 里。

**ADR 三判据**（防 ADR 泛滥成流水账）：难以回退 + 没上下文会困惑 + 真有取舍。**三条全中才写**，缺一条就跳过。这条原本抄自 `domain-modeling`；那个 skill 已退役（见下），所以**本文件现在是它唯一的家**，别当成引用删掉。

### 明确不装

| 不装 | 理由 |
|---|---|
| **`to-spec`（本体）** | 其 SKILL.md **硬依赖 issue tracker**：步骤 3 要求 publish 到 issue tracker 并打 `ready-for-agent` 标签，且要求先跑 `setup-matt-pocock-skills`。装了就与 `.trellis/tasks/` 构成两个任务系统 |
| **`setup-matt-pocock-skills`** | 它配置的正是 issue tracker 与 label 词表。**上游 README 提示必装，我们必须不装** |
| `tdd` / `code-review` / `triage` / `to-tickets` | 同上，都建立在 issue tracker 工作流上 |

**但要借 `to-spec` 的两条纪律**（不是它的代码）。逐片之后本仓没有「合成」这一步了——需求收敛由 Trellis 的 brainstorm 在 task 内做——但这两条对写 `prd.md` 仍然成立：

- 不写具体文件路径和代码片段（会很快过时）；例外是比散文更精确的 schema / 状态机 / 类型形状
- 只合成已有共识，不新问问题——要问的在 grilling 阶段已经问完

差异只有一处：**发布目标是 `.trellis/tasks/<task>/prd.md`，不是 issue tracker**。

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

**还需不需要 `grilling`——待实跑验证。** 本仓已决定提问纪律取 Trellis 的（见下节），而 Trellis 的 brainstorm 已经有了 grilling 的两条核心（Evidence Rule、每题附推荐答案），差别只剩 frontier 批量 vs 一次一问。所以 grilling 的净增量只剩「**写简报那一步、brainstorm 还没上场时的批量提问**」——真实但很窄。

实跑一次简报之后再定去留。不需要了就删掉 `vendor/mattpocock-skills/<name>/`、从 `scripts/install-skills.sh` 的 `VENDORED` 数组移除、**并加进 `RETIRED` 数组**（否则已存在的软链会留着继续被触发），同时从 `scripts/sync-vendor.sh` 的 `SKILLS` 数组移除。

### 已退役：`domain-modeling`

**曾经装过，现已整个删除。** 它的问题是机制性的，不是好不好用：

它的 SKILL.md 明确要求「首次术语裁决时创建 `CONTEXT.md` 并即时更新」，且规定 *"It is a glossary and nothing else"*。而本仓的术语结论落 **brief §5「措辞」**。两处都自称术语权威，正常的一次术语讨论就能产生两个互相漂移的事实源——而安装脚本是**全局**启用它的，也就是说这个冲突默认就会发生。

三条候选路径里选了删除：

| 路径 | 为什么不选 |
|---|---|
| 改 vendor 原件让它写 brief §5 | 违反 `vendor/` 只读——改了就跟上游 diff 不上 |
| 新写一个本仓包装 skill 转移落点 | 为一个净增量很窄的能力新增一份要维护的 skill |
| **删掉**（选中） | 它的两样干货已经在本仓有家：ADR 三判据在本文件，术语裁决手法在 brief 模板注释 |

**`grill-with-docs` 不能拿来替代它。** 上游那个 skill 全文只有一句 —— `Run a /grilling session, using the /domain-modeling skill.` —— 它是 `domain-modeling` 的**入口**，description 还明写 *"creates docs (ADR's and glossary) as we go"*。装它等于把冲突装回来并加一个显式入口。想要「简报阶段批量提问」，`grill-me` 已经在做，两者的差别正好就是 `domain-modeling`。

要回退这个决定：把 `domain-modeling:skills/engineering/domain-modeling` 加回 `sync-vendor.sh` 的 `SKILLS`、跑 `--pull` 取回目录，再在 `install-skills.sh` 里从 `RETIRED` 挪回 `VENDORED`。**但先解决 `CONTEXT.md` 与 brief §5 谁是源真**，不然装回来还是同一个问题。

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
| `product-brief` | 降级成 [`playbook/assets/brief-template.md`](../playbook/assets/brief-template.md)，一份模板不是 skill。逐片之后它只剩「方向 + 阶段目标 + 切片清单」，一页纸的事 |
| `prd-generator` / `-noweb` | 字段级需求不再预先穷举，随 task 在 `prd.md` 里就近定义（Trellis 的 `task.py create` 自带模板，本仓**不再提供** task 级 PRD 模板） |
| `system-design` / `design-system-java` | 承重决策落目标仓库自己的架构文档 + ADR；切片顺序落简报 §4 |
| `domain-modeling`（原 vendor 项，不属于旧仓） | ADR 三判据落本文件、术语裁决手法落 brief 模板注释。理由见上面「已退役：`domain-modeling`」 |

清理命令见 [`../playbook/00-setup.md`](../playbook/00-setup.md) 步骤 2。**脚本只删软链**：退役名如果在 `~/.claude/skills/` 下是真目录（可能是你自己的同名 skill），它报错退出而不是删除。这条由 `scripts/test-install-skills.sh` 用例 1 卡住。

## 仍在用的其他第三方

| skill | 何时用 | 边界 |
|---|---|---|
| `ui-ux-pro-max` | 结构定了之后的视觉与设计系统 | **不得下沉到低保真阶段**——骨架只准灰阶 + 一个强调色 |
| `code-review-skill`（awesome） | 通用代码正确性/可读性评审 | 轨不变量由 `specs/<track>/` 的 Pre-Development Checklist 与 Quality Check 管，不混用 |
| `skill-creator` | 改完 skill 校验 frontmatter 与相对链接 | — |

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

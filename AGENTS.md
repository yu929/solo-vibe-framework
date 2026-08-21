# Solo Vibe Framework — AGENTS

> 维护本仓库的约定。改任何东西前先读本文件。流程总览见 [`README.md`](README.md)。

## 本仓库是什么

Trellis 工作流的**轨无关层**：registry + 通用 skill + 给人读的操作手册。底座（task 生命周期、spec 注入、journal）由 Trellis 提供，本仓**不重造**。

本仓同时是**多轨 spec 的 registry**：`specs/universal/` 是轨无关思维清单的**权威源**，`specs/<track>/` 是各轨编码规范正文**外加一份 guides 生成副本**。经 `trellis init --registry` 装进项目的 `.trellis/spec/`——**一个项目只装一个模板**（原因见下面「一个项目只能装一个 spec 模板」）。

**判断某样东西该不该进本仓**，问两个问题：

1. **它是 spec 还是流程？** 两个都进，但进不同地方——见下面「哪些东西住哪」。真正不进本仓的只有一类：**某个具体项目**的产品内容（需求、模块清单、业务规则），那些住项目自己的仓库。
2. **Trellis 已经有了吗？** 有了就不要再写一份——写引用。

### 哪些东西住哪

| 内容 | 住哪 | 判据 |
|---|---|---|
| 流程手册、通用 skill、轨无关 guides | `playbook/` `skills/` `specs/universal/`（**权威源**，各轨的 `guides/` 是它的生成副本） | 跟框架走，换技术栈不用改 |
| **各轨编码规范正文** | **`specs/<track>/`** | 跟技术栈走，但**跨项目复用**——所以在这里维护，不在每个 starter 里各存一份 |
| 第三方 skill 的只读拷贝 | `vendor/` | 别人的代码，只读 |
| 某个具体项目的产品内容 | **项目自己的仓库** | 只对那一个项目成立 |
| 部署脚本、CI 配置、Dockerfile 本体 | **各 starter** | 是可执行工件，不是规范 |

注意第二行是**从旧版改过来的**：旧版把编码规范正文归 starter，理由是「跟技术栈走」。但那个判据推错了方向——跟技术栈走的东西**依然跨项目**，每个 starter 存一份就是 N 份要同步。规范正文归本仓、可执行工件归 starter，才是对的切法。

## 目录职责

| 路径 | 读者 | 职责 |
|---|---|---|
| `references/third-party.md` | 人 | 第三方装什么/不装什么/为什么 |
| `.github/workflows/` | CI | `checks.yml`（三条不变量回归）+ `sync-vendor.yml`（每晚 diff 上游 vendor，**只开 PR 不 merge**） |
| `specs/universal/` | **agent**（经 Trellis 按需注入） | 轨无关思维清单与收敛纪律（**权威源**；也是无轨项目的独立模板） |
| `specs/<track>/` | **agent**（同上） | 该轨编码规范正文（栈锁定、模式、禁止清单、质量门）+ `guides/` 生成副本 |
| `skills/` | agent | 本仓自有的触发式能力 |
| `vendor/` | agent | 第三方 skill 的**只读**拷贝，改了就跟上游 diff 不上 |
| `playbook/` | **人** | 照着做的清单。**模板跟着 skill 走，不放这里** |
| `scripts/` | 人 | 安装、上游同步、guides 分发；外加三个 `test-*.sh`（被 `checks.yml` 跑） |
| `index.json` | Trellis CLI | registry manifest（**只能登记 `type: spec`**） |

### 一个项目只能装一个 spec 模板 —— 所以轨模板自带 guides

Trellis 的 `.trellis/config.yaml` 里 `registry.spec.template` 是**单数**字段，第二次 init 会整行替换它（`dist/utils/registry-config.js:121-126`），此后 `trellis update` 只刷新后装的那个（`dist/commands/update.js:469`）。**且不报错**——update 照常成功、照常打绿字，只是少刷了一半。

于是本仓的布局是：

| 目录 | 是什么 |
|---|---|
| `specs/universal/guides/` | **唯一权威源**；同时也是独立模板 `universal-guides`，给还没有轨规范的项目单独装 |
| `specs/<track>/guides/` | 上面那份的**生成副本**，由 `scripts/sync-spec-guides.sh` 产出。**别直接改它**——改了下次同步就被覆盖，而且 `test-spec-templates.sh` 会先报出来 |

**新增一条轨**（比如加个 Java 或 Python starter 的规范）：

1. 建 `specs/<track>/`，写轨规范正文（`frontend/` `backend/` … 按那条轨的实际分层）
2. 在 `index.json` 登记一条 `type: spec`
3. 跑 `scripts/sync-spec-guides.sh` —— 它会自动给新目录带上 `guides/`。脚本是**推导**轨列表的（`specs/` 下除 `universal` 外的每个目录），不需要回来改脚本
4. 跑 `scripts/test-spec-templates.sh` 验收

**跨模板引用一律禁止。** `specs/<track>/**` 里不许出现 `](../../`——一个项目只装一个模板，跨模板链接装完必然断。guides 与轨规范同级之后，`../guides/x.md` 在源码树和安装树里指的是同一个东西，这是唯一正确的写法。

**链接必须按安装树验，不是按源码树。** `specs/<id>/` 那一层安装时会被抹平，所以源码树里通的链接装完可能是断的——仓库里跑任何常规链接检查都发现不了。`test-spec-templates.sh` 用例 1 把模板映射到临时 `.trellis/spec/` 之后再验，就是为这件事。

**写 `scripts/` 里的 bash 时**：macOS 自带的是 **bash 3.2**（`/bin/bash`，`env bash` 也是它）。`readarray` / `mapfile` / 关联数组 `declare -A` 全都没有，写了在本机直接报错。`declare -a`、`${var:?}`、`[[ ]]` 可用。**别按 bash 4/5 的习惯写**，这条和 AGENTS.md 里那条「BSD grep 与 GNU grep 行为不同」是同一类坑：本机工具链比你以为的旧。

## playbook 是给人读的，不是 command

本仓**最容易做歪的一处**。

playbook 的读者是**还不熟这套流程的人**，产物是「照着做的清单」。**不要把它改造成 command 或 agent 指令文件。**

理由不是风格偏好，是顺序：command 的读者是 AI，手册的读者是正在学流程的人；二者不是同一东西的两种形态，而是**先后两步**——手册先记录「我实际怎么做」，被实跑验证后，其中稳定的部分才值得固化成 command。跳过手册直接写 command，等于把没验证过的流程写死。

每个场景文件固定六节：

```
## 什么时候用这个场景   判据，不是描述
## 开始之前             必须已经有什么
## 步骤                 每步三件事：我敲什么 / AI 会产出什么 / 怎么确认这步成了
## 我该在哪停下来看     拍板点清单
## 常见卡点             坑 + 怎么绕
## 对 AI 说什么 · 速查  可直接复制的 prompt 原文
```

最后一节**只写实跑验证过的 prompt**。没跑过就编 prompt，正是这套框架要防的事——没跑过的地方标「实跑后补」，留空不丢人。

**内容边界**：playbook 是「Trellis 默认流程 + 自有增量」的**差异说明书**，不从零复述 Trellis。日常直接走 Trellis 即可，手册只讲：什么时候不能直接进 Trellis、Trellis 问「要不要建 task」时怎么答、拍板点在哪。

**playbook 里不得出现** `pnpm` / `supabase` / `docker` / 部署命令——手册讲流程与拍板，具体命令归 `specs/<track>/`（规范正文）与各 starter 的操作手册。

唯一例外是 [`00-setup.md`](playbook/00-setup.md)：它讲的就是怎么把这套东西装起来，`npm` / `trellis` / `ln -s` 是它的正题。

## Skill 结构约定

```text
skills/<name>/
  SKILL.md                  # frontmatter(name/description) + 主流程
  references/*.md           # 按需加载的完整细则
  assets/*                  # 输出模板
  agents/<role>.md          # 可选：只读 reviewer 提示词
```

- `SKILL.md` 保持精炼，细则下沉 `references/`。
- **单一事实源**：同一规则只在一处定义正文，其他处引用。改规则先改权威源。
- 新增或实质修改 skill 后用 `skill-creator` 校验 frontmatter 与相对链接。

## 文档语言与写作约定

**语言按文件整份统一，不按目录。** 一个文件要么全中文要么全英文——中文文档里冒出英文段落是漂移；整份换语言是有意决定，换完适用下面另一档规则。

两个写作 skill 按**文件的语言**分工。它们各自的触发面由 description 写死，不可改：

| 文件 | 用哪个 | 自动触发吗 |
|---|---|---|
| 中文文档 | `tech-doc-style-chinese`（Fenng，MIT，装在 `~/.claude/skills/`，**不在 `vendor/`**） | 会。分支含「中文技术文档 / Markdown 文档 / 操作手册」等 |
| 给 agent 读的英文文档 | `writing-for-agents`（vendor） | 只在 skill / `AGENTS.md` / `CLAUDE.md` 上触发 |

**改英文 spec 时两个都不会自动触发**——Fenng 的分支限定中文，`writing-for-agents` 的分支不含 spec，而 vendor 只读改不了它的 description。**手动点名 `writing-for-agents`。**

**与语言无关的三条**：

- **代码、命令、字段名、注解参数里的引号一律不动。** `owner_id`、`@CrossUserQuery("理由")`、`"5432:5432"` 是机器可读内容。
- **`id` / `owner_id` 指字段名，不改成 `ID`。**
- **spec 用第二人称称呼开发者，保留。**

**只对中文文档成立**：正文引号用直角引号 `「」`。英文文档照常用 `"`；中文文档里**引用英文原文时也保持原样**（本文件里那两处 Trellis 与 vendor skill 的原句就是）。

### Fenng 的检查器只能按文件跑，不能跑整个目录

`~/.claude/skills/tech-doc-style-chinese/scripts/lint_copy_rules.py` **没有语言判断**：它把每一个可见 `"` 都报成「应改为直角引号」。跑在英文文件上输出全是噪音，所以**只喂中文 md**。

中文文件上已知的三类误报，**报出来也不要改**：

| 误报 | 为什么不能改 |
|---|---|
| `id` → `ID` | 那是字段名，改了就是改代码 |
| 称呼「你」 | spec 直接称呼开发者是刻意的；skill 自己也写了第二人称可由项目约定覆盖 |
| blockquote 里嵌的 bash 围栏中的命令行引号 | 它的围栏识别漏了带 `>` 前缀的嵌套围栏，把命令当成了正文 |

## vendor：第三方只读拷贝

`vendor/mattpocock-skills/` 是 [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）**六个** skill 的固定版本拷贝，靠软链暴露给 agent：

| skill | 用在哪 |
|---|---|
| `grilling` · `grill-me` | 需求讨论时的批量逼问 |
| `grill-with-docs` | 上面两个 + `domain-modeling`，**全文只有一句「Call the Skill tool twice」，所以它俩绑定** |
| `domain-modeling` | 术语表 `CONTEXT.md` 与 `docs/adr/` 的**权威源**，见「拍板」节 |
| `prototype` | **只用 LOGIC 分支**验字段与状态机；UI 分支归 `ui-ux-pro-max` |
| `writing-for-agents` | 写给 agent 读的文档（skill / `AGENTS.md` / spec） |

**为什么落地本仓而不是各项目各装一份**：上游安装器 `npx skills add` 写进**项目仓库**，而这些跟流程走、跨项目通用。每项目一份意味着 N 份拷贝、N 次更新，还跟本仓自有 skill 的分发方式（全局软链）不一致。

**`prototype` 只用 LOGIC 分支这条是提示语，不是判定。** skill 是整个装的，它第一步就是 "Pick a branch"，没有任何机制挡得住它选 UI 分支。实跑发现它跑去 UI 分支就当场记进 `references/third-party.md`。

**规矩**：

- **只读**。改了就跟上游 diff 不上，本仓关于 skill 的约定（单一事实源、`skill-creator` 校验）**不适用于** `vendor/`。
- 版本固定在 `vendor/mattpocock-skills/.upstream-sha`。
- **必须保留上游 `LICENSE`**。MIT 要求副本保留版权与许可声明，而 `vendor/` 就是一份副本——这是再分发条件，不是礼节。`scripts/sync-vendor.sh` 启动时硬断言它存在，`.github/workflows/sync-vendor.yml` 再卡一道。
- 同步跑 `scripts/sync-vendor.sh`（只报告差异），确认要跟随再 `--pull`。**不自动跟随上游**——那等于让别人的改动在你不知情时改变你的工作流。每晚的 workflow 守同一条：它**只开 PR，不 merge**。
- **删一个 vendor skill 要动四处**：① 删目录 ② 从 `install-skills.sh` 的 `VENDORED` 移除 ③ **加进同文件的 `RETIRED`** ④ 从 `sync-vendor.sh` 的 `SKILLS` 数组移除。漏第 ③ 步会留下一条活软链，skill 继续被触发。
- **装回一个退役的 vendor skill 要动三处**：① `install-skills.sh` 的 `RETIRED` 移除 + `VENDORED` 加入 ② `sync-vendor.sh` 的 `SKILLS` 数组加回 ③ 跑 `--pull` 重建 `.upstream-manifest`。**还要检查 `test-install-skills.sh` 有没有拿它当样本**——用例 2 和用例 4 各钉了一个具体 skill 名，身份变了那两条会红。

**退役项只删软链，不删真目录。** 退役名（`system-design`、`product-brief` 这类）很通用，用户可能有同名自有 skill；对真文件/目录一律报错退出。这条由 `scripts/test-install-skills.sh` 用例 1 卡住，**改 `install-skills.sh` 的删除逻辑前先读那个测试**。

## 拍板：不设审批字段

`docs/discovery/` 下的产物——完整 PRD 与 `slices.md`——**都没有 frontmatter，没有 approved 字段，没有状态位**。

理由是机制性的：**没有任何东西读它**。本仓不提供 workflow，Trellis 的 `--registry` 只装 spec，workflow-state 的 hook 又是 parser-only（*"reads whatever you put in the block"*）——所以「门禁」在这套流程里只可能是提示语，不可能是判定。给一个没人读的文件加状态位，只会造出一个永远和现实对不上的假状态。

**这条链上唯一真正的硬门禁是 Trellis 自带的**：`trellis-brainstorm` 规定「没有用户显式批准 planning summary 就不许 `task.py start`」。要挂什么在开工前，挂在那里，别自己再造一个。

**全仓措辞用「检查点」，不用「门禁」**——除非指的是 Trellis 那个。

三个曾经存在的字段（`brief_approved` / `prototype_required` / `prototype_approved`）连同整套「审批失效」规则**已删除**，不要加回来（也别换个名字给完整 PRD 加一个）。它们制造过两个真实缺陷：一条允许不更新原型就重新批准的捷径，以及一条把「影响交互的技术约束」无条件豁免出失效范围的规则。删掉字段之后两个问题都不存在了——**用删除解决，不用打补丁解决**。

## 逐片推进（本仓的核心取舍）

**需求与原型一次做全，实现逐片推进。**

这个切法是有意的，因为「一次做全」的代价在两者身上完全不同：

| | 一次做全的代价 | 结论 |
|---|---|---|
| 完整 PRD + 全量高保真 | 前期慢一轮，但**这一轮本来就要做**——切片需要一个已收敛的东西才切得动 | 一次做全 |
| 实现 | 一次做全 = 几个月没有任何可验证的东西 | 逐片 |

不变量 `原型覆盖面 ≥ 实现覆盖面` **原样成立且自动成立**——全量 ≥ 任何一片。别再给它加「当前切片」这类限定，那是旧模式的产物。

**这条流程有一个前提，它不成立时整条会退化：**

> **高保真定稿之前，PRD 必须已经收敛到字段级。**

一次画全高保真，等于把「后面几片的需求还没被收敛过，现在画等于替它们猜」这个风险接了回来——而猜出来的结构一旦画成高保真，就会被当成已定稿，后面每一片都照着它实现。

抵消它的是 PRD 阶段的两步：**抛 prototype 验字段**（`prototype` 的 LOGIC 分支，把状态机推过纸上想不清的用例）和**反写 PRD**。这两步跳过或走过场，高保真就是在替未收敛的需求猜结构，而那时候没有任何机制会告诉你。

**仍然要兜的两件事**：

1. **本片的定稿屏必须进 `implement.jsonl`**。实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件，`prd.md` 里写一行路径不算——这是实跑验证过的失效形态。落点是 `slices.md` 切片清单的第四列「本片对应的高保真屏」，`vertical-slicing` 把它列为必做步骤。**只填这一片的那几屏**，全量塞进去会撑爆子 agent。
2. **定期回头看**：每 3–5 片走一次项目级检查点。高保真定稿只保证了结构一致，不保证**实现**没有偏离它。

第 1 条漏了没有任何症状（实现出来结构不对，看起来像执行不认真）；第 2 条漏了会在十几片之后才发作。

## 评审纪律

按**读者**分两处，不是同一份正文的两个副本：

| 在哪 | 管什么 | 谁读 |
|---|---|---|
| [`specs/universal/guides/review-adjudication.md`](specs/universal/guides/review-adjudication.md) | 编码期 finding 4 字段、需求探索期轻量收敛 | 每个 session，经 Trellis 注入 |
| `skills/design-review/references/review-adjudication.md` | 完整评审协议：十条纪律、P0–P3、八字段证据格式、停止规则 | 只在触发评审时加载 |

**协议正文必须住在 skill 里。** skill 会被软链或拷贝到 `~/.claude/skills/`，那里读不到本仓的 `specs/`——跨目录引用的 skill 到了那里就是个缺核心规则的空壳，评审结果会退化成模型自行补全。**skill 内不得出现 `](../../` 形式的引用**——这条**目前还没有机器在卡**（`test-spec-templates.sh` 用例 3 只扫 `specs/`），它列在下面「稳定后要建的两条检查」里，在建起来之前靠人守。

改纪律先判断改的是哪一层，只改那一份，然后检查 `design-review/SKILL.md` 的摘要是否还成立。

### 需求探索期用轻量收敛，不套完整台账

完整台账服务**设计准入及以后**。需求探索期用轻量收敛：

| 项 | 规则 |
|---|---|
| 走查 | ≤ 2 轮。第 2 轮后的分歧记「待确认」或「挪到后面的切片」 |
| 方案 | 2–3 个且必须有结构性区分度；**一次拍板**，落选要素当场合并入定稿 |
| 问题记录 | 只 4 字段（现象 / 判定 / 动作 / 落点），判定 ∈ {改 prd, 改原型, 挪到后面的切片, 待确认} |
| 单片规模警报 | 一片对应的屏或交互序列 > 6 时提醒「是不是切大了」，结论留痕，**不阻塞** |

**提问轮次不由本仓管**。Trellis 的 `trellis-brainstorm` 强制「每条消息只问一个问题」，且它在 planning 阶段是必经的；本仓再规定一套 ≤2 轮批量提问只会跟它对着来。两套纪律（Trellis 一次一问 / `grilling` 一轮问完 frontier）取 Trellis 的。

两条理由，关系到别把两套机制搞混：

1. **设计准入那套八字段证据格式是过重海拔**（台账在它之上再加 `status` 与 `reopen_condition`，共十字段）。它要求可定位设计依据、触发条件和受影响需求；走查阶段的发现形态是「这步太绕」「失败了不知道该干什么」。套八字段等于要求用户为每条直觉反馈写举证材料。
2. **收敛压力放在轮次与拍板上，不放在覆盖面上**。原型定稿必须覆盖 PRD 声明的全量（它是实现期的结构依据，覆盖面小于实现就等于把缺口留给 AI 自由发挥）；真会失控的是在方案之间反复摇摆，所以纪律落在选案上。

## 防漂移

- **四个领域各有唯一宿主，别在别处存副本**：需求与验收归完整 PRD（切片开始后归该片 `prd.md`）、术语归 `CONTEXT.md`、有取舍的决定归 `docs/adr/`、界面与交互结构归定稿高保真 + `master.md`。正文与反写规则在 [`specs/universal/guides/source-of-truth.md`](specs/universal/guides/source-of-truth.md)。**判据：这句话要说的事，是不是已经有别的宿主了？**
- **反写只在阶段切换点发生一次，且必须是 delta**（ADDED / MODIFIED / REMOVED，直接改正文）。出现「注意上面那段已废弃」「补充：实际用的是 D」这类追加式修改就是漂移——它会把文档从「这东西是什么」变成「这东西被改过几次」。
- **实现覆盖面不得超过原型覆盖面**。高保真是全量定稿的，所以这条自动成立；真正会破它的是**实现时顺手多做一点**。判据：这一片在做的，定稿里有对应结构吗？
- **轨约束不得进轨无关层**：RLS、Server Action、Maven、DDD 这类词出现在 `playbook/`、`skills/`、`specs/universal/` 里就是漂移——那三处必须换个技术栈还成立。它们出现在 `specs/<track>/` 里是**正常的**，那正是那些目录的用途。判据不是「有没有出现这个词」，是「**它出现在哪一层**」。
- **不要把 Trellis 已有的东西再写一遍**。这条现在有具体清单，因为实测过了：
  | Trellis 已有 | 别在本仓重造 |
  |---|---|
  | `trellis-brainstorm` 的需求收敛与提问纪律 | 另一套提问轮次规则 |
  | planning summary 的开工门禁 | 自造的 approved 字段 |
  | `task.py create` 生成的 `prd.md` | task 级 PRD 模板 |
  | ——（`design.md` / `implement.md` **只有语义定义、没有文件模板**） | 这一条**反过来**：补模板不算重造，正文在 [`specs/universal/guides/task-artifacts.md`](specs/universal/guides/task-artifacts.md) |
  | `trellis-update-spec` 的 spec 升级 | 另一套 spec 写入流程 |
  | task 生命周期、spec 注入、workflow 阶段 | 同名概念的第二套定义 |
  要改流程改**目标项目自己的** `.trellis/workflow.md`（一段话的事），**不 fork Trellis**，也不发 `type: workflow` 模板——那是整份替换 `workflow.md`（判据见 `references/third-party.md`）。
- **`index.json` 只登记 `type: spec`**。Trellis v0.7.0-beta.3 的 `--registry` 见到别的类型直接返回失败（`dist/utils/template-fetcher.js:828`），登记了就是每次 init 放一个必定失败的条目。
- 修改后检查是否夹带单一项目名。**语言漂移看的是文件内是否混语言**，不是「出现了英文」——有意整份换语言见「文档语言与写作约定」。

## 关于校验脚本（第一版未建，经验先记下）

旧仓有两个跨 skill 不变量校验脚本。本仓第一版**不照搬**——它们 28 处检查面指向已退役的 PRD skill，守的是不存在的东西。

> **现有的三个 `test-*.sh` 不属于这一类**，别混。它们守的都是**有确定输入输出的机械事实**，跟规则稳不稳定无关，所以现在就该有：
>
> | 脚本 | 守什么 | 为什么非有不可 |
> |---|---|---|
> | `test-install-skills.sh` | 退役项只删软链、只动能证明是本框架装的链接 | 那条 `rm -rf` 会删掉用户真目录，纯文字约定挡不住 |
> | `test-sync-vendor.sh` | vendor 内容 == 固定 SHA 的上游内容（离线校验和） | 只比 SHA 会把本地漂移报成「已是最新」 |
> | `test-spec-templates.sh` | **按安装树**校验链接 + 各轨 guides 与权威源一致 | 装完才断的链接，在源码树里怎么查都是绿的 |
>
> 三条的共同点：**缺陷都没有症状**。装两个模板不报错、vendor 被改过 SHA 不变、断链只在安装产物里存在。这类东西必须靠机器发现。
>
> 本节讲的是另一类——**跨 skill 的文本不变量**（措辞有没有漂移），那类检查依赖规则本身先稳定下来。（`test-spec-templates.sh` 用例 3 那条 `](../../` 是例外：它的判据是路径解析，不是措辞，没有歧义空间。）

等新的跨 skill 规则稳定后再重建。重建时这些是踩过的坑，**不要重踩**：

- **否定式检查要卡在子句上，不能整行豁免**。markdown 段落是一整行，用「本行含否定词就跳过」会被段落里任意一句「不要 X」放过，检查静默失效。
- **别用多字节否定字符组（如 `[^。；]`）写 grep**。BSD `/usr/bin/grep` 按字节处理，汉字中间字节与「。」的字节重叠，导致永不匹配；同一模式在 GNU grep 下却正常，症状是「手跑有结果、脚本里没结果」。这类检查用 `python3` 写。
- **每加一条检查，必须注入对应 bug 验证它真的会失败**。只跑「真实仓库全绿」什么都证明不了。
- **还要配一个「合法内容不得误报」的反向用例**。同一个词在不同分支可能是对的，不限定范围的检查会把正确写法判成错误，逼着后来的人绕开校验。
- **按段落判、别按行判**，子句分隔符要含破折号。
- **引用要先遮蔽再匹配**，把引用区间整体遮蔽掉再跑规则。
- **上下文按章节维护，别用固定回溯行数**；分支声明写在反引号里时，上下文识别必须读原文而非遮蔽后的文本。
- **关键词本身不是判据，修饰它的限定词才是**。本次重构实测：grep `全量屏|全部屏` 出 16 处命中，逐条读完**全部合法**——「本片全量屏」是对的，「MVP 全量屏」才是漂移，而两者共用同一个关键词。可用的写法是取匹配点前一个窗口的上下文，按限定词分三类：切片限定（`本片`/`当前切片`/`这一片`）放行、产品级限定（`MVP`/`整个产品`/`简报`）报错、无限定词交人工判读。
- **描述历史的句子必然误报，要留人工判读出口**。「旧版把它读成『覆盖全量 MVP』」「那条捷径已删」这类句子必须含违规词才说得清楚。别为它们加豁免正则（正则会顺带豁免真漂移），做成「报出来但标为待判读」。

### 稳定后要建的两条检查

现在还不建（新流程一次都没实跑过，规则本身可能还要改），但已经知道该守什么：

> **原来第二条是「覆盖面措辞必须被切片限定」，已作废**——那条判据锚在逐片低保真上，需求与原型改成一次做全之后它会把正确写法判成漂移。替换成下面第二条。

| 检查 | 为什么 | 注入什么 bug 验证它 |
|---|---|---|
| **skill 内不得出现 `](../../`** | skill 被软链到 `~/.claude/skills/` 后读不到本仓 `specs/`，跨目录引用到那里就断链。这是本次修掉的 high 级缺陷，纯文字约定挡不住它复发 | 在任一 `SKILL.md` 里加一条 `](../../specs/x.md)`，检查必须失败 |
| **四个源真不得互相存副本** | 需求 / 术语 / 决定 / 界面结构各有唯一宿主，副本一出现就会分叉，而分叉半年内不会有症状 | 在 PRD 模板里塞一份术语表，检查必须失败；写一句「术语见 `CONTEXT.md`」，检查**不得**报错 |

**新增跨 skill 规则时，同时加一条校验**——纯文字约定没有任何机制能发现漂移，这是实战教训。

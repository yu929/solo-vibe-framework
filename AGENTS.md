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
| `playbook/` | **人** | 照着做的清单 + 简报模板 |
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

playbook 的读者是**还不熟这套流程的人**，产物是「照着做的清单」——参照 `web-fullstack/VIBE-CODING-PLAYBOOK.md` 的写法。**不要把它改造成 command 或 agent 指令文件。**

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

## vendor：第三方只读拷贝

`vendor/mattpocock-skills/` 是 [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）**两个** skill（`grilling` / `grill-me`）的固定版本拷贝，靠软链暴露给 agent。

**为什么落地本仓而不是各项目各装一份**：上游安装器 `npx skills add` 写进**项目仓库**，而这两个跟流程走、跨项目通用。每项目一份意味着 N 份拷贝、N 次更新，还跟本仓自有 skill 的分发方式（全局软链）不一致。

**规矩**：

- **只读**。改了就跟上游 diff 不上，本仓关于 skill 的约定（单一事实源、`skill-creator` 校验）**不适用于** `vendor/`。
- 版本固定在 `vendor/mattpocock-skills/.upstream-sha`。
- **必须保留上游 `LICENSE`**。MIT 要求副本保留版权与许可声明，而 `vendor/` 就是一份副本——这是再分发条件，不是礼节。`scripts/sync-vendor.sh` 启动时硬断言它存在，`.github/workflows/sync-vendor.yml` 再卡一道。
- 同步跑 `scripts/sync-vendor.sh`（只报告差异），确认要跟随再 `--pull`。**不自动跟随上游**——那等于让别人的改动在你不知情时改变你的工作流。每晚的 workflow 守同一条：它**只开 PR，不 merge**。
- **删一个 vendor skill 要动三处**：删目录、从 `install-skills.sh` 的 `VENDORED` 移除、**并加进 `RETIRED`**。漏最后一步会留下一条活软链，skill 继续被触发——`domain-modeling` 退役时就差点漏掉。同时从 `sync-vendor.sh` 的 `SKILLS` 数组移除。

**退役项只删软链，不删真目录。** 退役名（`system-design`、`product-brief` 这类）很通用，用户可能有同名自有 skill；对真文件/目录一律报错退出。这条由 `scripts/test-install-skills.sh` 用例 1 卡住，**改 `install-skills.sh` 的删除逻辑前先读那个测试**。

## 拍板：不设审批字段

`docs/discovery/brief.md` **没有 frontmatter，没有 approved 字段**。

理由是机制性的：**没有任何东西读它**。本仓不提供 workflow，Trellis 的 `--registry` 只装 spec，workflow-state 的 hook 又是 parser-only（*"reads whatever you put in the block"*）——所以「门禁」在这套流程里只可能是提示语，不可能是判定。给一个没人读的文件加状态位，只会造出一个永远和现实对不上的假状态。

**这条链上唯一真正的硬门禁是 Trellis 自带的**：`trellis-brainstorm` 规定「没有用户显式批准 planning summary 就不许 `task.py start`」。要挂什么在开工前，挂在那里，别自己再造一个。

**全仓措辞用「检查点」，不用「门禁」**——除非指的是 Trellis 那个。

三个曾经存在的字段（`brief_approved` / `prototype_required` / `prototype_approved`）连同整套「审批失效」规则**已删除**，不要加回来。它们制造过两个真实缺陷：一条允许不更新原型就重新批准的捷径，以及一条把「影响交互的技术约束」无条件豁免出失效范围的规则。删掉字段之后两个问题都不存在了——**用删除解决，不用打补丁解决**。

## 逐片推进（本仓的核心取舍）

**低保真原型只覆盖当前切片，不覆盖整个 MVP。**

不变量是 `原型覆盖面 ≥ 实现覆盖面`，它锚的是**即将实现的东西**。旧版把它读成「覆盖全量 MVP」，靠的是「下一步会实现全量 MVP」这个隐含假设；逐片推进之后覆盖面只需 ≥ 当前片，**不变量原样成立，成本降一个量级**。

不画后面几片的理由不是省事：那些需求还没被 brainstorm 收敛过，现在画等于替它们猜，而猜出来的结构一旦画成 HTML 就会被当成已定稿。

**代价必须被兜住**，两条纪律缺一不可：

1. **跨片一致性**：出方案前先读 `docs/discovery/wireframe/*/final/` 下所有已定稿的屏**或交互序列**，同类的沿用既有模式，结构性偏离要写进取舍说明。**两个分支定稿在同一个 `*/final/` 下**（`final/index.html` 与 `final/interaction-sketch.md`）——这条检查只扫那一个路径，非 UI 定稿落在别处，这条纪律对非 UI 分支就等于不存在。
2. **定期回头看**：每 3–5 片走一次项目级检查点。一次画全时你被迫看过一遍全貌，改成逐片之后那个动作没了，不补就是净变差。

删掉任何一条，逐片模式都会退化——前者退化成「每片重新发明一次列表页」，后者退化成「十几片之后产品跑偏了没人发现」。

## 评审纪律

按**读者**分两处，不是同一份正文的两个副本：

| 在哪 | 管什么 | 谁读 |
|---|---|---|
| [`specs/universal/guides/review-adjudication.md`](specs/universal/guides/review-adjudication.md) | 编码期 finding 4 字段、需求探索期轻量收敛 | 每个 session，经 Trellis 注入 |
| `skills/design-review/references/review-adjudication.md` | 完整评审协议：十条纪律、P0–P3、九字段证据格式、停止规则 | 只在触发评审时加载 |

**协议正文必须住在 skill 里。** skill 会被软链或拷贝到 `~/.claude/skills/`，那里读不到本仓的 `specs/`——跨目录引用的 skill 到了那里就是个缺核心规则的空壳，评审结果会退化成模型自行补全。**skill 内不得出现 `](../../` 形式的引用**，这条要在验证里卡。

改纪律先判断改的是哪一层，只改那一份，然后检查 `design-review/SKILL.md` 的摘要是否还成立。

### 需求探索期用轻量收敛，不套完整台账

完整台账服务**设计准入及以后**。需求探索期用轻量收敛：

| 项 | 规则 |
|---|---|
| 走查 | ≤ 2 轮。第 2 轮后的分歧记「待确认」或「挪到后面的切片」 |
| 方案 | 2–3 个且必须有结构性区分度；**一次拍板**，落选要素当场合并入定稿 |
| 问题记录 | 只 4 字段（现象 / 判定 / 动作 / 落点），判定 ∈ {改 prd, 改原型, 挪到后面的切片, 待确认} |
| 单片规模警报 | 一片的屏或交互序列 > 6 时提醒「是不是切大了」，结论留痕，**不阻塞** |

**提问轮次不再由本仓管**。Trellis 的 `trellis-brainstorm` 强制「每条消息只问一个问题」，且它在 planning 阶段是必经的；本仓再规定一套 ≤2 轮批量提问只会跟它对着来。三套纪律（Trellis 一次一问 / `grilling` 一轮问完 frontier / 旧版 ≤2 轮）取 Trellis 的。

两条理由，关系到别把两套机制搞混：

1. **完整台账的九字段是过重海拔**。它要求可定位设计依据、触发条件和受影响需求；走查阶段的发现形态是「这步太绕」「失败了不知道该干什么」。套九字段等于要求用户为每条直觉反馈写举证材料。
2. **收敛压力放在轮次与拍板上，不放在覆盖面上**。低保真原型必须覆盖**当前切片**声明的全量（它是本片实现的结构依据，覆盖面小于实现就等于把缺口留给 AI 自由发挥）；真会失控的是在方案之间反复摇摆，所以纪律落在选案上。

## 防漂移

- **原型覆盖面锚定当前切片，不锚定 MVP**。出现「全量屏」「全部屏」「交接契约」这类措辞就是在往回滑。判据：这句话要求画的，是不是这一片马上要实现的？
- **骨架不得升级成视觉设计稿**：低保真产物只允许灰阶 + 一个强调色、零外部依赖；出现配色方案、字体选型、间距体系、组件库依赖即为漂移，那些属于 `ui-ux-pro-max`。
- **视觉不得反向下沉**：`design-system/` 与 `docs/discovery/` 不互为源真，也不共享文件。
- **轨约束不得进轨无关层**：RLS、Server Action、Maven、DDD 这类词出现在 `playbook/`、`skills/`、`specs/universal/` 里就是漂移——那三处必须换个技术栈还成立。它们出现在 `specs/<track>/` 里是**正常的**，那正是那些目录的用途。判据不是「有没有出现这个词」，是「**它出现在哪一层**」。
- **不要把 Trellis 已有的东西再写一遍**。这条现在有具体清单，因为实测过了：
  | Trellis 已有 | 别在本仓重造 |
  |---|---|
  | `trellis-brainstorm` 的需求收敛与提问纪律 | 另一套提问轮次规则 |
  | planning summary 的开工门禁 | 自造的 approved 字段 |
  | `task.py create` 生成的 `prd.md` | task 级 PRD 模板 |
  | `trellis-update-spec` 的 spec 升级 | 另一套 spec 写入流程 |
  | task 生命周期、spec 注入、workflow 阶段 | 同名概念的第二套定义 |
  要改流程改**目标项目自己的** `.trellis/workflow.md`（一段话的事），**不 fork Trellis**，也不发 `type: workflow` 模板——那是整份替换 `workflow.md`（判据见 `references/third-party.md`）。
- **`index.json` 只登记 `type: spec`**。Trellis v0.7.0-beta.3 的 `--registry` 见到别的类型直接返回失败（`dist/utils/template-fetcher.js:828`），登记了就是每次 init 放一个必定失败的条目。
- 修改后检查中文说明是否漂移成英文、是否夹带单一项目名。

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

现在还不建（这套流程一次都没实跑过，规则本身可能还要改），但已经知道该守什么：

| 检查 | 为什么 | 注入什么 bug 验证它 |
|---|---|---|
| **skill 内不得出现 `](../../`** | skill 被软链到 `~/.claude/skills/` 后读不到本仓 `specs/`，跨目录引用到那里就断链。这是本次修掉的 high 级缺陷，纯文字约定挡不住它复发 | 在任一 `SKILL.md` 里加一条 `](../../specs/x.md)`，检查必须失败 |
| **覆盖面措辞必须被切片限定** | 逐片是本仓的核心取舍，往回滑的形态就是措辞先松掉 | 写一句「每个方案覆盖 MVP 全量屏」，检查必须失败；同时写一句「每个方案覆盖本片全量屏」，检查**不得**报错 |

**新增跨 skill 规则时，同时加一条校验**——纯文字约定没有任何机制能发现漂移，这是实战教训。

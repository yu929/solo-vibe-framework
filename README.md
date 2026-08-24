# Solo Vibe Framework

> 个人用的 vibe coding 工程框架：编码规范、skill 和操作手册。

底座是 [Trellis](https://github.com/mindfold-ai/Trellis)（`@mindfoldhq/trellis`，AGPL-3.0），负责 task 生命周期、需求收敛和跨 session 记忆。本仓补上这套工作流还缺的部分，不重复实现 Trellis 已有的能力。

Trellis 能管好单个 task，却不回答三个跨 task 的问题：产品现在是什么，下一片做什么，当初为什么否掉另一个方案。即使跑完五十个 task，这些答案也不会自动出现。

这套框架适合一个人做产品、把大量需求讨论和实现交给 AI，同时又需要跨 session 保持结构一致的开发者。

准备安装看 [`playbook/setup/`](playbook/setup/README.md)，要走流程看 [`playbook/build/`](playbook/build/README.md)。

## 快速开始

环境要求：Node ≥ 18、Python ≥ 3.9，这是 Trellis 的要求。各轨技术栈可能要求更高，安装后以 `.trellis/spec/README.md` 的栈锁定表为准。

```bash
# 1. 装底座
npm install -g @mindfoldhq/trellis@latest

# 2. 软链 skill 到 ~/.claude/skills/（幂等，可反复跑）
scripts/install-skills.sh

# 3. 到你的项目目录下，装一条轨的编码规范
trellis init --claude --registry https://github.com/yu929/solo-vibe-framework \
             --template web-fullstack
```

装完先确认两件事：`scripts/install-skills.sh --check` 全绿，`.trellis/spec/` 下同时有轨规范和 `guides/`。完整步骤与四条验收见 [`playbook/setup/`](playbook/setup/README.md)。

### 现有的轨

| `--template` | 技术栈 | 跨用户隔离靠什么 |
|---|---|---|
| `web-fullstack` | Next.js 16 App Router + React 19 + Tailwind v4 + shadcn/Base UI + Supabase | 数据库层 RLS 强制隔离 |
| `java-stack` | Spring Boot 4 + Postgres/Flyway + React 19/Vite + shadcn-admin-kit(ra-core)，单容器部署 | 没有 RLS。查询按归属过滤，加 ArchUnit 约束和双账号负向测试 |
| `universal-guides` | 不锁定 | 不涉及。只有轨无关 guides，给还没有轨规范的项目 |

> **一个项目只能装一个模板。** Trellis 的 `registry.spec.template` 是单数字段，装第二个会把第一个顶掉，此后 `trellis update` 只刷新后装的那个，而且不报错。所以轨模板自带 guides，一条命令装齐。已经跑过裸 `trellis init` 的项目要补 `--overwrite`，见 [`playbook/setup/02-track-spec.md`](playbook/setup/02-track-spec.md)。

### 四套机制落点不同，别搞混

先记住：registry 装不了 skill，只认 `type: spec`。

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| 一条轨的 spec，自带 guides | `trellis init --registry ... --template <id>` | 项目 `.trellis/spec/` |
| 本仓 skill 与 vendor skill | `scripts/install-skills.sh` | `~/.claude/skills/` |
| Trellis 自带 skill | `trellis init --claude` | 项目 `.claude/skills/` |
| workflow 模板 | `--workflow` / `trellis workflow` | 项目 `.trellis/workflow.md` |

## 工作流

**需求与原型一次做全，实现逐片推进。**

```
一句话想法 → 完整 PRD → 抛原型验字段 → 反写 PRD → 全量高保真定稿
           → 垂直切片 → 逐片进 Trellis → 每 3–5 片一次项目级检查点
```

切片只能从已经收敛的需求里切，所以需求和原型要先做全。实现不能等到全部完成才验证，否则几个月里都拿不到可检查的结果。

这要求 PRD 在高保真定稿前收敛到字段级。「抛原型验字段」和「反写 PRD」就是用来补齐这一步的；如果只是走过场，高保真会替尚未收敛的需求猜结构，而且流程不会报警。

完整流程图、七处拍板点和五条贯穿全程的规则，都在 [`playbook/build/`](playbook/build/README.md)。

还有两件事只能由人盯住：

1. 本片的定稿屏要写进 `implement.jsonl`。路径来自 `slices.md` 切片清单第四列，只列这一片的几张屏。实现期子 agent 用的是全新 context，只能看到 jsonl 中列出的文件；`prd.md` 里出现路径还不够。漏掉时不会报错，最后只会看到实现结构和定稿不一致。
2. 每完成 3–5 片做一次项目级检查点。高保真定稿保证的是起点一致，不能保证实现一直没有偏离。跳过检查点，偏差往往要到十几片后才看出来。

流程里的硬门禁只有 Trellis 自带的 planning summary 批准。本仓产物不加 frontmatter 或 approved 字段，因为没有程序读取这些字段；加上反而会留下无法自动维护的假状态。

## 仓库结构

```
specs/                      Trellis registry —— 装进项目的 .trellis/spec/
  universal/guides/         轨无关思维清单（权威源，也是 universal-guides 模板）
  web-fullstack/            Next.js + Supabase 规范 + guides/ 生成副本
  java-stack/               Spring Boot + Postgres 规范 + guides/ 生成副本
skills/                     自有 skill：vertical-slicing · design-review
vendor/mattpocock-skills/   六个第三方 skill 的只读拷贝（含 LICENSE 与校验清单）
playbook/setup/             操作手册：装起来
playbook/build/             操作手册：做产品
scripts/                    install-skills · sync-vendor · sync-spec-guides + 五个 test-*
references/                 规则带不动的背景：第三方判定 · 安装机制 · 既定取舍 · 仓库约定 · 检查设计
index.json                  registry manifest（只登记 type: spec）
```

轨无关 guides 有六份：`index` · `code-reuse` · `cross-layer` · `review-adjudication` · `source-of-truth` · `task-artifacts`。权威源在 `specs/universal/guides/`。各轨目录下的同名文件由 `scripts/sync-spec-guides.sh` 生成，直接修改会在下次同步时被覆盖。

### 什么该进本仓

| 内容 | 住哪 | 判据 |
|---|---|---|
| 流程手册、通用 skill、轨无关 guides | 本仓 | 跟框架走，换技术栈不用改 |
| 各轨编码规范正文 | 本仓 `specs/<track>/` | 跟技术栈走，但跨项目复用。每个 starter 存一份就是 N 份要同步 |
| 部署脚本、CI 配置、Dockerfile 本体 | 各 starter | 是可执行工件，不是规范 |
| 某个项目的需求与业务规则 | 项目自己的仓库 | 只对那一个项目成立 |

`playbook/` 里不出现栈命令，`playbook/setup/` 除外，装东西是它的正题。手册讲流程与拍板，命令归 `specs/<track>/`。

## 维护

| 命令 | 干什么 |
|---|---|
| `scripts/install-skills.sh` | 软链 skill、清退役软链。`--check` 只检查不改 |
| `scripts/sync-vendor.sh` | 查 vendor 本地漂移与上游变化，默认只报告，`--pull` 才更新 |
| `scripts/sync-spec-guides.sh` | 从权威源分发 guides 到各轨。`--check` 只校验 |
| `scripts/test-*.sh`（五个） | 五条不变量回归，CI 每次 push 都跑 |

五条检查针对的都是不容易当场发现的缺陷：装两个模板不报错；vendor 内容变了但 `.upstream-sha` 不变；链接只在安装后才断；spec 超预算后被静默截断；skill 的跨目录引用换个安装位置才失效。这些问题靠人工很难及时发现。

`.github/workflows/sync-vendor.yml` 每晚检查一次上游 vendor，内容有变化才开 PR，不自动合并。这样可以先读 diff，再决定是否让上游改动进入工作流。

新增一条轨：建 `specs/<track>/` 写规范正文 → 在 `index.json` 登记一条 `type: spec` → 跑 `sync-spec-guides.sh` → 跑 `test-spec-templates.sh` 验收。脚本自己推导轨列表，不用回来改。

## 当前状态

流程在 2026-08-21 调整过，目前还没有按这套新流程完整跑过一次。旧流程（一页简报 + task 内逐片低保真）跑过一遍，得到的结论已经回写；现在的「完整 PRD → 全量高保真 → 切片」是在那之后定下的。规则以 [`AGENTS.md`](AGENTS.md) 和 [`specs/universal/guides/`](specs/universal/guides/) 为准。

两处已知的不确定：

- `playbook/` 里的每一句 prompt 都标了「已实跑」或「未实跑」，目前绝大多数是后者。实际跑过后，用当时有效的说法替换原文。
- `references/third-party.md` 里标着「未实跑验证」的条目，以实际输出为准，对不上的地方当场改那份文件。

CI 两条都在跑：`checks` 每次 push 触发，`sync-vendor` 每晚定时，都已成功执行，后者也真开过跟随上游的 PR。

照着做时，如果某一步让你停下来琢磨「到底该干嘛」，就把它当作文档缺陷，趁还记得写进对应文件的「常见卡点」。

## 致谢

这套框架建立在现有工具和方法之上。下面列出的项目都直接影响了本仓的设计。

### 直接使用

`vendor/` 中的六个 skill 随本仓分发，其余工具自行安装，见 [`playbook/setup/03-third-party.md`](playbook/setup/03-third-party.md)。

| 项目 | 许可 | 本仓怎么用它 |
|---|---|---|
| [Trellis](https://github.com/mindfold-ai/Trellis) | AGPL-3.0 | **底座**：task 生命周期、spec 注入、registry 机制、`trellis-brainstorm` 的需求收敛与开工门禁 |
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT © Matt Pocock | 六个 skill 的固定版本拷贝在 [`vendor/`](vendor/mattpocock-skills/)。术语表 `CONTEXT.md`、`docs/adr/` 与 ADR 三判据以它的 `domain-modeling` 为权威源；`vertical-slicing` 的四条核心纪律借自它的 `to-tickets`，**借纪律，skill 本身不装** |
| [create-prd-skill](https://github.com/pmYangKun/create-prd-skill) | 上游未声明 | 完整 PRD 那一步，用 `community/complexity-aware` 分支（按 L1–L4 分级裁剪深度）。**正因为没有许可证所以不 vendor** |
| [tech-doc-style-chinese](https://github.com/Fenng/tech-doc-style-chinese) | MIT © Fenng | 本仓中文文档的写作规范。它的检查器只按文件跑，英文文件不喂 |
| [code-review-skill](https://github.com/awesome-skills/code-review-skill) | MIT © awesome-skills | 通用代码正确性与可读性评审。轨不变量仍归 `specs/<track>/`，两者不混用 |
| `ui-ux-pro-max` | 本地拷贝无 LICENSE，`SKILL.md` 里也没有来源或作者声明 | 全量高保真与设计系统。来源不明是不 vendor 的直接原因：不能再分发一份来源不可考的东西 |
| `skill-creator` | Anthropic 官方 | 改完 skill 校验 frontmatter 与相对链接 |
| [shadcn/ui 官方 skill + MCP](https://ui.shadcn.com/docs/skills) | MIT © shadcn | 两条轨前端都是 shadcn 系，用它保证组件 API 用对。per-project 装，本仓不分发，只在两条轨的 `frontend/index.md` 规定怎么用 |

### 只借想法

| 项目 | 借了什么 |
|---|---|
| [spec-anchor](https://github.com/linziyanleo/spec-anchor) | **findings 分层**：编码期发现先落 finding，确认后才升级进 spec，不允许 AI 直接改 spec。落点 `specs/universal/guides/review-adjudication.md`，字段从 11 个压到 4 个。它本身比 Trellis 严谨，但海拔是为多人多模块设计的 |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 一条零成本判据：标题里出现「和 / 与 / and」就是两个任务。它的尺寸表不借，粒度锚在文件数上会诱导往横切走 |

判定过程、每条「不装」的理由，以及明确排除的项目，都记录在 [`references/third-party.md`](references/third-party.md)。

## 许可

仓库有两份 LICENSE，覆盖范围不同：

| 文件 | 覆盖什么 | 版权 |
|---|---|---|
| [`LICENSE`](LICENSE) | 本仓自有内容：`specs/` `skills/` `playbook/` `scripts/` `references/` | MIT © 2026 Adrian |
| [`vendor/mattpocock-skills/LICENSE`](vendor/mattpocock-skills/LICENSE) | 只覆盖 `vendor/` 里那份第三方拷贝 | MIT © 2026 Matt Pocock |

两份都是 MIT，但版权人不同。vendor 中的是[上游](https://github.com/mattpocock/skills)原件，再分发时必须随拷贝保留；`scripts/sync-vendor.sh` 也会检查它是否存在。

底座 [Trellis](https://github.com/mindfold-ai/Trellis) 是 AGPL-3.0，但本仓不含也不分发它的代码，只是依赖它，所以 AGPL 的传染性不及于此。

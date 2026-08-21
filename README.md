# Solo Vibe Framework

> 一个人用 AI 做产品的工程框架：装进项目的编码规范 + 通用 skill + 照着做的操作手册。

底座是 [Trellis](https://github.com/mindfold-ai/Trellis)（`@mindfoldhq/trellis`，AGPL-3.0），它提供 task 生命周期、需求收敛和跨 session 记忆。**本仓只放 Trellis 没有、而这套工作流需要的东西**——它已经有的一律不重造。

- **解决什么问题**：Trellis 管得住单个 task，管不住「这产品整体是什么」「下一片该做谁」「当初为什么否掉了那个方案」。跑五十个 task 也没有一处回答这三个问题。
- **给谁用**：一个人做产品、把需求讨论和实现大量交给 AI、需要跨 session 保持结构一致的开发者。
- **从哪开始读**：装东西看 [`playbook/00-setup.md`](playbook/00-setup.md)，走一遍流程看 [`playbook/README.md`](playbook/README.md)，想知道规则为什么长这样看 [`AGENTS.md`](AGENTS.md)。

## 快速开始

**环境要求**：Node ≥ 18、Python ≥ 3.9（Trellis 自己的要求）。各轨技术栈另有更高要求，装完看 `.trellis/spec/README.md` 的栈锁定表。

```bash
# 1. 装底座
npm install -g @mindfoldhq/trellis@latest

# 2. 软链 skill 到 ~/.claude/skills/（幂等，可反复跑）
scripts/install-skills.sh

# 3. 到你的项目目录下，装一条轨的编码规范
trellis init --claude --registry https://github.com/yu929/solo-vibe-framework \
             --template web-fullstack
```

确认装成了：`scripts/install-skills.sh --check` 全绿，且 `.trellis/spec/` 下轨规范与 `guides/` 同时存在。

### 现有的轨

| `--template` | 技术栈 | 跨用户隔离靠什么 |
|---|---|---|
| `web-fullstack` | Next.js 16 App Router + React 19 + Tailwind v4 + shadcn/Base UI + Supabase | Supabase RLS 兜底 |
| `java-stack` | Spring Boot 4 + Postgres/Flyway + React 19/Vite + shadcn-admin-kit(ra-core)，单容器部署 | 无 RLS，靠归属收口 + ArchUnit + 双账号负向测试 |
| `universal-guides` | 不锁定 | ——（只有轨无关 guides，给还没有轨规范的项目） |

> **一个项目只能装一个模板。** Trellis 的 `registry.spec.template` 是单数字段，装第二个会把第一个顶掉，此后 `trellis update` 只刷新后装的那个——**而且不报错**。所以轨模板自带 guides，一条命令装齐。已经跑过裸 `trellis init` 的项目要补 `--overwrite`，细节见 [`00-setup.md`](playbook/00-setup.md) 步骤 3。

### 四套机制落点不同，别搞混

这是最容易踩的一处：**registry 装不了 skill**，它只认 `type: spec`。

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| 一条轨的 spec（自带 guides） | `trellis init --registry ... --template <id>` | 项目 `.trellis/spec/` |
| 本仓 skill 与 vendor skill | `scripts/install-skills.sh`（全局软链） | `~/.claude/skills/` |
| Trellis 自带 skill | `trellis init --claude` | 项目 `.claude/skills/` |
| workflow 模板 | `--workflow` / `trellis workflow` | 项目 `.trellis/workflow.md` |

## 工作流

**需求与原型一次做全，实现逐片推进。**

```
一句话想法
   │
   ├─ 需求讨论 ──────── grill-with-docs    → 术语进 CONTEXT.md，有取舍的决定进 docs/adr/
   ├─ 写完整 PRD ────── create-prd-skill   → docs/discovery/prd.md      ★ 范围 + 明确不做
   ├─ 抛原型验字段 ──── prototype（LOGIC）  → 丢弃品，验完就删
   ├─ 反写 PRD                             → 字段级收敛到此为止
   ├─ 全量高保真定稿 ── ui-ux-pro-max      → design-system/             ★ 选案，一次定
   ├─ 垂直切片 ──────── vertical-slicing   → docs/discovery/slices.md   ★ 切法 + 第一片
   │
   └─ 逐片进 Trellis ──┬─ Plan     写 prd / design / implement
                       │           本片定稿屏进 implement.jsonl
                       │                                       ★ 批准 planning summary 才 start
                       ├─ Execute  实现 → check
                       └─ Finish   update-spec → commit → 归档  ★ 看它改了哪几条 spec

                       每 3–5 片 → 项目级检查点
```

切片需要一个已收敛的东西才切得动，所以需求与原型这一轮本来就要做全；实现做全则意味着几个月拿不到任何可验证的东西。

代价是一条前提：**高保真定稿之前，PRD 必须已经收敛到字段级**。抵消它的是上面「抛原型验字段」和「反写 PRD」那两步。这两步走过场，高保真就是在替未收敛的需求猜结构，而那时候没有任何机制会告诉你。

两件机制兜不住、要靠人守的事：

1. **本片的定稿屏必须进 `implement.jsonl`**（取值来自 `slices.md` 切片清单第四列，只填这一片的那几屏）。实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件，`prd.md` 里写一行路径不算。漏了没有任何症状——实现出来结构不对，看起来像执行不认真。
2. **每 3–5 片走一次项目级检查点**。高保真定稿只保证结构一致，不保证实现没有偏离它。漏了会在十几片之后才发作。

### 你必须停下来拍板的五处

| # | 拍什么 | 在哪 |
|---|---|---|
| 1 | 范围 + 明确不做 | 完整 PRD |
| 2 | 切法 + 第一片是哪个 | `slices.md` 切片清单 |
| 3 | 选哪个方案 | 高保真走查 |
| 4 | planning summary | Trellis，`task.py start` 之前 |
| 5 | Finish 阶段改了哪几条 spec | Trellis Finish |

前两个是真正值钱的——拍错了后面全白做。

**这条链上唯一的硬门禁是 Trellis 自带的第 4 项。** 本仓的产物一律没有 frontmatter、没有 approved 字段：没有任何东西读它们，加了只会造出一个跟现实永远对不上的假状态。

### 一个不在主流程里的出口

[`design-review`](skills/design-review/SKILL.md) 是**逃生舱**，你主动喊才上场。

它治的不是「审得不够细」，是「停不下来」：换了几个 session 反复审同一份设计，问题越修越多，你说不出什么时候算审完。它用冻结输入、问题台账、证据门槛、P0–P3 和停止规则强制收敛。完整触发条件在它自己的「什么时候用」一节。

## 仓库结构

```
specs/                      Trellis registry —— 装进项目的 .trellis/spec/
  universal/guides/         轨无关思维清单（权威源，也是 universal-guides 模板）
  web-fullstack/            Next.js + Supabase 规范 + guides/ 生成副本
  java-stack/               Spring Boot + Postgres 规范 + guides/ 生成副本
skills/                     自有 skill：vertical-slicing · design-review
vendor/mattpocock-skills/   六个第三方 skill 的只读拷贝（含 LICENSE 与校验清单）
playbook/                   给人读的操作手册（五个场景）
scripts/                    install-skills · sync-vendor · sync-spec-guides + 三个 test-*
references/third-party.md   第三方依赖：装什么、不装什么、为什么
index.json                  registry manifest（只登记 type: spec）
```

轨无关 guides 六份：`index` · `code-reuse` · `cross-layer` · `review-adjudication` · `source-of-truth` · `task-artifacts`。**权威源只有 `specs/universal/guides/` 一处**，各轨目录下的同名文件是 `scripts/sync-spec-guides.sh` 产出的生成副本，改了下次同步就被覆盖。

### 什么该进本仓

| 内容 | 住哪 | 判据 |
|---|---|---|
| 流程手册、通用 skill、轨无关 guides | 本仓 | 跟框架走，换技术栈不用改 |
| 各轨编码规范正文 | 本仓 `specs/<track>/` | 跟技术栈走，但跨项目复用——每个 starter 存一份就是 N 份要同步 |
| 部署脚本、CI 配置、Dockerfile 本体 | 各 starter | 是可执行工件，不是规范 |
| 某个项目的需求与业务规则 | 项目自己的仓库 | 只对那一个项目成立 |

`playbook/` 里不出现具体命令（`00-setup.md` 除外，装东西是它的正题）——手册讲流程与拍板，命令归 `specs/<track>/`。

## 维护

| 命令 | 干什么 |
|---|---|
| `scripts/install-skills.sh` | 软链 skill、清退役软链。`--check` 只检查不改 |
| `scripts/sync-vendor.sh` | 查 vendor 本地漂移与上游变化，默认只报告，`--pull` 才更新 |
| `scripts/sync-spec-guides.sh` | 从权威源分发 guides 到各轨。`--check` 只校验 |
| `scripts/test-*.sh`（三个） | 三条不变量回归，CI 每次 push 都跑 |

三条不变量守的都是**没有症状的缺陷**：装两个模板不报错、vendor 被改过 `.upstream-sha` 一个字不变、安装后才断的链接在源码树里怎么查都是绿的。这类东西必须靠机器发现。

`.github/workflows/sync-vendor.yml` 每晚 diff 上游 vendor，内容真变了才开 PR，**绝不自动 merge**——自动跟随上游等于让别人的改动在你不知情时改变你的工作流。

新增一条轨：建 `specs/<track>/` 写规范正文 → 在 `index.json` 登记一条 `type: spec` → 跑 `sync-spec-guides.sh` → 跑 `test-spec-templates.sh` 验收。脚本自己推导轨列表，不用回来改。

## 当前状态

**流程 2026-08-21 换过一次，新流程一次都没实跑过。** 旧流程（一页简报 + task 内逐片低保真）完整跑过一次，结论已回写；现在这套「完整 PRD → 全量高保真 → 切片」是在那之后定的。

三处已知的没跟上：

- `playbook/` 的四个场景文件（`01`–`04`）仍在描述旧流程，`00-setup.md` 已更新。规则的权威源是 [`AGENTS.md`](AGENTS.md) 与 [`specs/universal/guides/`](specs/universal/guides/)。
- `.github/workflows/` 两个 workflow 写成时本仓还没有 remote，**都未实跑**，第一次要用 `workflow_dispatch` 手动触发确认。
- `references/third-party.md` 里标着「未实跑验证」的条目，以实际输出为准，对不上的地方当场改那份文件。

**照着做的时候，凡是需要停下来问「这步到底该干嘛」的地方，就是手册的 bug**，当场记进对应文件的「常见卡点」。

## 致谢

这套框架是在别人做好的东西上面加一层，不是从零造的。下面每一条都实际影响了本仓的形态。

**直接用到的**（`vendor/` 那六个随本仓分发，其余自己装，见 [`00-setup.md`](playbook/00-setup.md) 步骤 4）：

| 项目 | 许可 | 本仓怎么用它 |
|---|---|---|
| [Trellis](https://github.com/mindfold-ai/Trellis) | AGPL-3.0 | **底座**：task 生命周期、spec 注入、registry 机制、`trellis-brainstorm` 的需求收敛与开工门禁 |
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT © Matt Pocock | 六个 skill 的固定版本拷贝在 [`vendor/`](vendor/mattpocock-skills/)。术语表 `CONTEXT.md`、`docs/adr/` 与 ADR 三判据以它的 `domain-modeling` 为权威源；`vertical-slicing` 的四条核心纪律借自它的 `to-tickets`——**借纪律，skill 本身不装** |
| [create-prd-skill](https://github.com/pmYangKun/create-prd-skill) | 上游未声明 | 完整 PRD 那一步，用 `community/complexity-aware` 分支（按 L1–L4 分级裁剪深度）。**正因为没有许可证所以不 vendor** |
| [tech-doc-style-chinese](https://github.com/Fenng/tech-doc-style-chinese) | MIT © Fenng | 本仓中文文档的写作规范。它的检查器只按文件跑，英文文件不喂 |
| [code-review-skill](https://github.com/awesome-skills/code-review-skill) | MIT © awesome-skills | 通用代码正确性与可读性评审。轨不变量仍归 `specs/<track>/`，两者不混用 |
| `ui-ux-pro-max` | 未核实 | 全量高保真与设计系统 |
| `skill-creator` | Anthropic 官方 | 改完 skill 校验 frontmatter 与相对链接 |
| shadcn 官方 skill + MCP | 见上游 | 两条轨前端都是 shadcn 系，用它保证组件 API 用对 |

**只借了想法，整体不装**：

| 项目 | 借了什么 |
|---|---|
| [spec-anchor](https://github.com/linziyanleo/spec-anchor) | **findings 分层**：编码期发现先落 finding，确认后才升级进 spec，不允许 AI 直接改 spec。落点 `specs/universal/guides/review-adjudication.md`，字段从 11 个压到 4 个。它本身比 Trellis 严谨，但海拔是为多人多模块设计的 |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 一条零成本判据：**标题里出现「和 / 与 / and」就是两个任务**。它的尺寸表不借——粒度锚在文件数上会诱导往横切走 |

判定过程、每条「不装」的理由，以及被明确排除的那些，都在 [`references/third-party.md`](references/third-party.md)——**装什么和不装什么同样重要**。

## 许可

仓库有两份 LICENSE，覆盖范围不同：

| 文件 | 覆盖什么 | 版权 |
|---|---|---|
| [`LICENSE`](LICENSE) | 本仓自有内容：`specs/` `skills/` `playbook/` `scripts/` `references/` | MIT © 2026 Adrian |
| [`vendor/mattpocock-skills/LICENSE`](vendor/mattpocock-skills/LICENSE) | 只覆盖 `vendor/` 里那份第三方拷贝 | MIT © 2026 Matt Pocock |

两份都是 MIT 但版权人不同。vendor 那份是[上游](https://github.com/mattpocock/skills)原件，**再分发时必须随拷贝保留**——这是 MIT 的条件，不是礼节，`scripts/sync-vendor.sh` 会硬断言它存在。

底座 [Trellis](https://github.com/mindfold-ai/Trellis) 是 AGPL-3.0，**但本仓不含也不分发它的代码**，只是依赖它，所以 AGPL 的传染性不及于此。

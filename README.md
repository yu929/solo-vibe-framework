# Solo Vibe Framework

个人 vibe coding 的工程框架：**Trellis registry**（轨无关 guides + 各轨编码规范）+ **通用 skill** + **给人读的操作手册**。

底座是 [Trellis](https://github.com/mindfold-ai/Trellis)（`@mindfoldhq/trellis`，AGPL-3.0）——它提供 task 生命周期、需求收敛（`trellis-brainstorm`）和跨 session 记忆（`.trellis/spec/` + `tasks/` + `workspace/journal`）。本仓只放 **Trellis 没有、而这套工作流需要**的东西。

> 不熟这套流程？**从 [`playbook/README.md`](playbook/README.md) 开始**，那是照着做的清单。装东西看 [`playbook/00-setup.md`](playbook/00-setup.md)。

## 这里放什么，不放什么

| 内容 | 位置 | 理由 |
|---|---|---|
| 流程手册、通用 skill、轨无关 guides | **本仓** | 跟框架走，换技术栈不用改 |
| **各轨编码规范正文** | **本仓 `specs/<track>/`** | 跟技术栈走，但**跨项目复用**——每个 starter 存一份就是 N 份要同步 |
| 部署脚本、CI 配置、Dockerfile 本体 | **各 starter** | 是可执行工件，不是规范 |
| 某个项目的需求与业务规则 | **项目自己的仓库** | 只对那一个项目成立 |

`playbook/` 不出现具体命令（`00-setup.md` 除外，装东西是它的正题）——手册讲流程与拍板，命令归 `specs/<track>/`。

## 目录

```
specs/
  universal/guides/          轨无关思维清单 —— **权威源**，也是无轨项目的独立模板
  web-fullstack/             Next.js 16 + Supabase 规范 + guides/（生成副本）→ .trellis/spec/
  java-stack/                Spring Boot 4 + Postgres + React 规范 + guides/（生成副本）→ .trellis/spec/
skills/                      lofi-prototype · design-review（自有）
vendor/mattpocock-skills/    grilling · grill-me（第三方 MIT，只读，含 LICENSE 与校验清单）
playbook/                    给人读的操作手册（五个场景 + 简报模板）
scripts/                     install-skills · sync-vendor · sync-spec-guides + 三个 test-*
references/third-party.md    第三方依赖：装什么、不装什么、为什么
.github/workflows/           checks.yml（三条不变量回归）· sync-vendor.yml（每晚 diff 上游，只开 PR）
index.json                   Trellis registry manifest
LICENSE                      MIT（本仓自有内容；vendor/ 那份是上游的，见文末「许可」）
```

## Trellis 有什么，本仓补什么

日常**直接走 Trellis** 即可。它的 `trellis-brainstorm` 会一问一答帮你把一个 task 想清楚，并且带一个硬门禁：**没有你的显式批准，不许 `task.py start`**。本仓不重造这一段。

它没有的只有两样，都在 **task 之上**：

| 缺什么 | 为什么 | 本仓怎么补 |
|---|---|---|
| **产品全貌** | `.trellis/spec/` 只放编码规范、`prd.md` 只记单次改动、journal 只是时间流水。跑五十个 task 也没有一处回答「这产品现在整体是什么」 | `docs/discovery/brief.md`（[模板](playbook/assets/brief-template.md)，六节一页）+ [项目级检查点](playbook/04-checkpoint.md) |
| **切片顺序** | Trellis 原文：*"Parent/child structure is not a dependency system"* | 简报 §4 切片清单 |

Trellis 自己也是这么设计的——brainstorm 明说 *"Do not invent a project-specific product/spec hierarchy. If the repository already has product docs, use them."* 它**主动**把产品层留空给你。

## 全流程

```
一句话想法
 ↓  写简报              → docs/discovery/brief.md    ★ 阶段目标 + 明确不做
 ↓  （可选）探索         → 丢弃品，验完就删
 ↓  切出第一片           → 简报 §4                    ★ 第一片是哪个
 ↓
Trellis: Plan（brainstorm + 本片原型 → ★ planning summary）→ Execute → Finish
 ↓
下一片 …  每 3–5 片 → 项目级检查点
```

**逐片推进，不一次画全。** 不变量是 `原型覆盖面 ≥ 实现覆盖面`——它锚的是**你即将实现的东西**，不是产品愿景。后面几片的需求还没被收敛过，现在画等于替它们猜结构，而猜出来的一旦画成 HTML 就会被当成已定稿。

代价是跨片一致性，由两条纪律兜：出方案前先读所有已定稿的屏、结构性偏离要说明理由。

## 拍板

简报是**可选**的——不存在时完全不阻塞，小改动就该跳过它。

**没有 approved 字段，也没有本仓自造的门禁。** 拍板是你读完点头这个动作，不是文件上的标记：没有任何机制读简报的 frontmatter，放个 bool 只会造出一个永远对不上的假状态。这条链上唯一真正的硬门禁是 Trellis 自带的 planning summary。

想让「建 task 前看一眼简报」这个提醒出现在决定的那一刻，把 [`00-setup.md`](playbook/00-setup.md) 步骤 5 那段粘进项目的 `.trellis/workflow.md`。**那也是提示语不是判定**——Trellis 的 hook 是 parser-only。

## 评审纪律

按**读者**分两处，不是同一份正文的两个副本：

| 在哪 | 管什么 | 谁读 |
|---|---|---|
| [`specs/universal/guides/review-adjudication.md`](specs/universal/guides/review-adjudication.md) | 编码期 finding 4 字段、需求探索期轻量收敛 | 每个 session，经 Trellis 注入 |
| `skills/design-review/references/review-adjudication.md` | 完整评审协议：十条纪律、P0–P3、八字段证据格式、停止规则 | 只在触发评审时加载 |

协议正文放在 skill 里是有意的：skill 会被软链到 `~/.claude/skills/`，那里读不到本仓的 `specs/`。**skill 必须自包含**，否则装到别处就是个缺核心规则的空壳。

## 安装

完整步骤见 [`playbook/00-setup.md`](playbook/00-setup.md)。两条命令：

```bash
scripts/install-skills.sh                         # 软链 skill 到 ~/.claude/skills/（幂等）
trellis init --claude --registry <本仓> --template web-fullstack   # 或 --template java-stack
```

现有的轨：`web-fullstack`（Next.js + Supabase）、`java-stack`（Spring Boot + Postgres + React）。都还没有的技术栈，装 `universal-guides`。

**一个项目只装一个 spec 模板。** Trellis 的 `registry.spec.template` 是单数的，装第二个会把第一个顶掉，此后 `trellis update` 只刷新后装的那个——而且不报错。所以轨模板**自带** guides（`specs/<track>/guides/` 是 `specs/universal/guides/` 的生成副本，`scripts/sync-spec-guides.sh` 同步）。

**四套机制落点各不相同，别搞混**——这是最容易踩的一处：

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| 一个 `specs/<track>`（自带 guides） | `trellis init --registry ... --template <id>` | 项目 `.trellis/spec/` |
| **本仓 skill 与 vendor skill** | **全局软链**，registry 装不了 | `~/.claude/skills/` |
| Trellis 自带 skill | `trellis init --claude` | 项目 `.claude/skills/` |
| workflow 模板 | `--workflow` / `--workflow-source` / `trellis workflow` | 项目 `.trellis/workflow.md` |

registry 只认 `type: spec`（源码位置见 [`references/third-party.md`](references/third-party.md)），所以 skill 只能软链。第三方依赖的清单与理由也在那份文件里——**装什么和不装什么同样重要**。

## 许可

**仓库有两份 LICENSE，覆盖范围不同，别看混：**

| 文件 | 覆盖什么 | 版权归谁 |
|---|---|---|
| [`LICENSE`](LICENSE) | 本仓自己的内容：`specs/` `skills/` `playbook/` `scripts/` `references/` | MIT © 2026 Adrian |
| [`vendor/mattpocock-skills/LICENSE`](vendor/mattpocock-skills/LICENSE) | **只覆盖 `vendor/` 里那份第三方拷贝** | MIT © 2026 Matt Pocock |

两份都是 MIT，但版权人不同——vendor 那份是[上游](https://github.com/mattpocock/skills)的原件，**再分发时必须随拷贝保留**，`scripts/sync-vendor.sh` 会硬断言它存在。

**底座 [Trellis](https://github.com/mindfold-ai/Trellis) 是 AGPL-3.0，但本仓不含也不分发它的代码**——只是依赖它，所以 AGPL 的传染性不及于此。

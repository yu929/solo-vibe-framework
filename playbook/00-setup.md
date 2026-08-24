# 场景零 · 装起来

> 一次性准备。装完之后日常不用再看这一篇。

## 什么时候用这个场景

- 换了台机器
- 起一个新项目
- `trellis init` 之后发现某个 skill 没被触发
- 从旧版升级（`~/.claude/skills/` 里还有指向旧仓的软链）

## 开始之前

- [ ] Node ≥ 18、Python ≥ 3.9（这是 **Trellis 自己**的要求；各轨的技术栈另有更高要求，装完看 `.trellis/spec/README.md` 的栈锁定表）
- [ ] `gh` CLI（只有同步 vendor 时才需要）

## 最要紧的一件事：这里有四套机制，不是一套

**registry 装不了 skill。** 别指望 `trellis init --registry` 会顺手把本仓的 skill 放好——它只认 `type: spec`，见到别的类型直接返回失败。

| 装什么 | 用什么装 | 落到哪 |
|---|---|---|
| `specs/<track>` 与 `specs/universal` | `trellis init --registry ... --template <id>` | 项目内 `.trellis/spec/` |
| **本仓 skill + vendor skill** | **`scripts/install-skills.sh`**（全局软链） | `~/.claude/skills/` |
| Trellis 自带 skill（brainstorm / check / meta…） | `trellis init --claude` | 项目内 `.claude/skills/` |
| workflow 模板 | `--workflow` / `--workflow-source` / `trellis workflow` | 项目内 `.trellis/workflow.md` |

四个都长得像「装个东西进来」，落点和机制完全不同。搞混的典型症状是「我明明 init 了，怎么 slash 列表里没有 `/vertical-slicing`」。

<details>
<summary>为什么 registry 不装 skill（源码依据，供将来复核）</summary>

`@mindfoldhq/trellis` v0.7.0-beta.3，`dist/utils/template-fetcher.js:828`：

```js
// Only support spec type in MVP
if (resolved.type !== "spec") {
    return { success: false,
      message: `Template type "${resolved.type}" is not supported yet (only "spec" is supported)` };
}
```

同文件 `:18` 的 `INSTALL_PATHS` 里确实有 `skill: ".agents/skills"`，但类型闸在前面，那行是死代码。即便将来打开，落点也是**项目内**的 `.agents/skills`，不是 `~/.claude/skills/` —— 跨项目的 skill 还是得靠软链。

上游支持之后，把 skill 加进本仓 `index.json` 即可。
</details>

## 步骤

### 步骤 1 · 装 Trellis

```bash
npm install -g @mindfoldhq/trellis@latest
```

**怎么确认这步成了**：

```bash
trellis --version
```

### 步骤 2 · 软链 skill（一条命令）

```bash
scripts/install-skills.sh
```

它做四件事，**幂等**，可以反复跑：

- 建 `~/.claude/skills/`（不存在时）
- 软链本仓的 `vertical-slicing` / `design-review`
- 软链 vendor 的 `grilling` / `grill-me` / `grill-with-docs` / `domain-modeling` / `prototype` / `writing-for-agents`
- **删掉已退役的软链**：`product-brief` / `prd-generator` / `prd-generator-noweb` / `system-design` / `design-system-java` / **`lofi-prototype`**

**为什么是脚本不是几行 `ln -s`**：升级场景下目标**总是**已存在（指向旧仓），裸 `ln -s` 会直接报 `File exists` 然后静默失败——看起来装完了，实际还在跑旧实现。脚本会核对指向、替换错的、对「不是软链而是真目录」的情况**中止并报告**而不是硬覆盖。

**它只删软链，不删真目录。** 退役名（`system-design`、`product-brief` 这些）都很通用，你完全可能有同名的自有 skill。所以脚本对退役项也只在「确实是软链」时删——删软链是无损的，指向的目标原样保留；遇到真文件或真目录一律报错退出，等你自己确认。这条由 `scripts/test-install-skills.sh` 卡住（在临时目录里跑，碰不到你的 `~/.claude/skills/`）。

**怎么确认这步成了**：

```bash
scripts/install-skills.sh --check
```

全 `=` 且 exit 0 就对了。看到 `✗` 按提示处理。

> **退役清单里有 `lofi-prototype`**，这不是笔误。新流程里全量高保真在切片**之前**就定稿了，task 内再出一次低保真等于跟定稿构成两个结构源真。它承接的那条实跑结论（**定稿必须进 `implement.jsonl`**）已改由 `vertical-slicing` 接住。
>
> `product-brief` 同理已降级成模板（[`../skills/vertical-slicing/assets/slices-template.md`](../skills/vertical-slicing/assets/slices-template.md)），不再是 skill。

### 步骤 3 · 在项目里装 spec（**只跑一条命令**）

```bash
trellis init --claude --registry https://github.com/<you>/solo-vibe-framework \
             --template web-fullstack
```

**换轨就换 `--template` 的值**，现有的两条：

| 轨 id | 技术栈 | starter |
|---|---|---|
| `web-fullstack` | Next.js 16 + Supabase（RLS 兜底隔离） | `starters/web-fullstack` |
| `java-stack` | Spring Boot 4 + Postgres + React（**无 RLS**，靠归属收口 + 负向测试） | `starters/java-stack` |

两条都不是你的技术栈时，装 `universal-guides`——它只有轨无关 guides，是给这种情况准备的。

**怎么确认这步成了**：

```bash
ls .trellis/spec/            # 应有 README.md frontend/ backend/ database/ testing/ guides/
ls .trellis/spec/guides/     # 应有 index.md code-reuse.md cross-layer.md
                             #      review-adjudication.md task-artifacts.md source-of-truth.md
```

轨规范和 guides **一次就都在**——轨模板自带 guides。

> ### ⚠️ 千万别装两个模板
>
> Trellis 的 `.trellis/config.yaml` 里 `registry.spec.template` 是**单数**的，第二次 init 会把它整行替换掉。此后 `trellis update` 只刷新第二个模板，**你的轨规范（含那些安全规则）再也收不到修复**。
>
> 最坏的地方是它不报错：update 照常成功、照常打绿字，只是少刷了一半。**没有任何症状**，直到某天你发现本地规范和框架仓的对不上。
>
> 源码依据（v0.7.0-beta.3）：`dist/utils/registry-config.js:12-18` 与 `:121-126`、`dist/commands/update.js:469`。完整推导见 [`../references/third-party.md`](../references/third-party.md)。

> **实测注意**：带 `--template` 时 Trellis **完全抑制默认 spec**——`.trellis/spec/` 里只有模板的内容，不会再有 Trellis 自带的 `frontend/` `backend/` `guides/`。这是对的（轨规范就该取代默认的），也正是轨模板**必须自带 guides** 的另一半理由。

#### 已经跑过裸 `trellis init` 的项目，怎么补装

上面那条命令是给全新项目的。如果你先跑了不带 `--template` 的 `trellis init`，`.trellis/spec/` 里已经躺着 Trellis 自带的占位脚手架，这时候要**多带一个 `--overwrite`**：

```bash
trellis init --claude --yes --registry https://github.com/<you>/solo-vibe-framework \
             --template java-stack --overwrite
```

> #### ⚠️ 漏了 `--overwrite` 不会报错
>
> 实测输出是这样的：
>
> ```
> 📦 Downloading template "java-stack"...
>    Skipped: .../.trellis/spec already exists
> 📋 Tracking 35 template files for updates
> ```
>
> **它跳过了，然后照常打绿字、正常退出。** 你会以为装好了，实际 `.trellis/spec/` 一个字没变——直到某天发现 AI 一直在按占位模板干活。又一个无症状缺陷。

**别用 `--append`。** 名字听起来更安全，实际是「只补缺失的文件」：`database/` `testing/` 装进来了，而 `backend/` `frontend/` 还是占位模板。半套轨规范半套脚手架，比全没装更难查。

**占位模板没什么可保的**，它本来就是等着被填的空壳。真在里面写过东西的话，先提交再 `--overwrite`，这样一条 `git diff` 就能看清换掉了什么。

**`--registry` 默认拉的是 `main`，不是你本地 checkout 的分支。** 注意是**写死的字面量 `main`**（`dist/utils/template-fetcher.js:201`），不是「这个仓库的默认分支」——默认分支要是叫别的名字，它不会自动跟过去，只会拉不到。

所以在框架仓改完轨规范，正常路径是先合进 main 再装。**想在合并前先验一把**，用 `#<分支名>` 指过去：

```bash
trellis init --claude --yes --registry gh:<you>/solo-vibe-framework#<分支名> \
             --template java-stack --overwrite
```

**必须用 `gh:` 这种前缀写法。** 浏览器地址 `https://github.com/<you>/<repo>/tree/<分支名>` 它也认，但那条路径解析分支名用的是 `[^/]+`——**带斜杠的分支名会被切错**，`feat/workflow` 会变成分支 `feat` + 子目录 `workflow`，然后报一个跟分支毫无关系的错。`gh:` 后面的 `#` 取的是剩下全部，斜杠不受影响。

### 步骤 4 · 装第三方 skill

**mattpocock 那六个已经装好了**——都在本仓 `vendor/mattpocock-skills/`，步骤 2 一并软链了：

| skill | 用在 0-1 的哪一步 |
|---|---|
| `grill-with-docs` | 步骤 1 需求讨论。它 = `grilling` + `domain-modeling`，**三个必须一起装**（它全文只有一句「Call the Skill tool twice」） |
| `grilling` / `grill-me` | 同上，也可单独用 |
| `domain-modeling` | 术语落 `CONTEXT.md`、有取舍的决定落 `docs/adr/`——**这两个是唯一宿主**，别在 PRD 里再存一份 |
| `prototype` | 步骤 3 验字段。**只用 LOGIC 分支** |
| `writing-for-agents` | 步骤 7 出项目 `AGENTS.md`，以及你自己写 skill 时 |

不需要跑 `npx skills add`。理由与「不装哪些、为什么」见 [`../references/third-party.md`](../references/third-party.md)——**装什么和不装什么同样重要**，尤其是为什么必须**不装** `setup-matt-pocock-skills`（装了就有两个任务系统）。

> **`prototype` 只用 LOGIC 分支这条是提示语，不是判定。** 它第一步就是 "Pick a branch"，没有任何机制挡得住它选 UI 分支——而 UI 分支会在真项目路由里开几个变体，跟「全量高保真 + 设计系统」是两条路。发现它跑去 UI 分支就当场拉回来，并记进 `references/third-party.md`。

**跟随上游更新**：

```bash
scripts/sync-vendor.sh --verify   # 只查本地有没有被改过（离线，秒回）
scripts/sync-vendor.sh            # 再加上：上游动了没有
scripts/sync-vendor.sh --pull     # 读完 diff、确认要跟随，才更新
```

默认只读是有意的：自动跟随等于让别人的改动在你不知情时改变你的工作流。

**平时你不用手动跑这个。** 框架仓推上 GitHub 之后，`.github/workflows/sync-vendor.yml` 每晚会自己 diff 一次，内容真变了才开一个 PR 给你读。守的还是同一条规矩——它只把 diff 送到你面前，merge 与否是你的事。手动跑的场合只剩两个：还没建远端仓，或者你现在就想知道上游动没动。

### 步骤 4.1 · 装完整 PRD skill（不 vendor）

`create-prd-skill` **上游没有许可证**（`license: null`），不能 vendor 进本仓再分发。自己装：

```bash
git clone -b community/complexity-aware https://github.com/pmYangKun/create-prd-skill
cd create-prd-skill && python scripts/install_skill.py
```

**分支选 `community/complexity-aware`**：主干那份对任何需求都产出 14 章，complexity-aware 会按 L1–L4 分级裁剪深度。

**产物落项目自己的 `docs/discovery/prd.md`**，不进本框架仓。

### 步骤 4.2 · 前端组件 skill + MCP（在项目里装，不是全局）

两条轨的前端都是 shadcn 系。官方 skill 和 MCP 都**装进项目仓**，不走步骤 2 那套全局软链——所以每开一个新项目都要再来一次。

在**项目根目录**跑——就是有 `package.json` 和 `components.json` 的那一层，**不是 `~/.claude`**（下面「常见卡点」有这个坑）：

```bash
pnpm dlx skills add shadcn/ui
```

```bash
pnpm dlx shadcn@latest mcp init --client claude
```

第二条会在项目根写 `.mcp.json`。装完重启 Claude Code，用 `/mcp` 确认 `shadcn` 连上了。

**前端在子目录的项目（比如 java-stack 的 `frontend/`），要多传一个参数。** `.mcp.json` 没有 cwd 字段，Claude Code 按「配置文件在哪」决定 server 的工作目录——而你是在仓库根启动 claude 的，server 就跟着落在仓库根，那里没有 `components.json`。改用 shadcn 自己的 `--cwd`：

```json
{ "mcpServers": { "shadcn": { "command": "npx", "args": ["shadcn@latest", "mcp", "--cwd", "frontend"] } } }
```

**装之前先用一条命令判断这个项目够不够格**，它不依赖 Claude Code，秒出结果：

```bash
pnpm dlx shadcn@latest info --cwd frontend
```

看两行就够：`framework` 认出来了（`Next.js` / `Vite`，不是 `Manual`），且 `Configuration` 一节有内容而不是 `No components.json found`。**两条里有一条不满足，装了 MCP 也只是个通用 registry 搜索**——它拿不到你项目的内核、别名和已装组件，而那正是装它的理由。先把骨架跑通 `shadcn init`，再回来装。

**它解决的是什么**：AI 凭记忆写出来的组件能编译、能渲染，错在 composition 和可访问性属性上，这类错不看文档发现不了。装了它，AI 就有地方查。**怎么用是轨规范管的事**，正文在 `specs/<track>/frontend/index.md` 的复用顺序一节。

**没装也能开工**：轨规范里写了没装时的替代动作，不会卡住。装了只是让 AI 少猜。

**java-stack 的 starter 现在还不够格**（2026-08-21 实测：`frontend/` 认得出 Vite，但没有 `components.json`，也没检测到 Tailwind）。要在这条轨上验证，先换骨架再装 MCP，顺序反了会白装。

### 步骤 5 · 粘一段 no_task 提示（可选，但推荐）

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

**这是提示语，不是判定。** Trellis 的 hook 是 parser-only——它把这段原样注入对话，不做任何检查。所以它挡不住任何事，只是把提醒放在**你做决定的那一刻**，比放在手册里管用。

**⚠️ 这段是未实跑验证的草稿。** 第一次用的时候看它实际效果，不对就当场改——改的是你自己项目里的文件，Trellis 的 `.template-hashes.json` 会保护本地修改不被升级覆盖。

### 步骤 6 · 粘一段 planning 提示（可选，但推荐）

Trellis 规定复杂 task 在 `task.py start` 之前必须有 `design.md` + `implement.md`，但**只给 `prd.md` 生成骨架**，另外两份靠 agent 自由发挥。模板已经随 registry 装进 `.trellis/spec/guides/task-artifacts.md`，这一段是让它在**写之前**被读到。

打开 `.trellis/workflow.md`，找到 `[workflow-state:planning]` 块，在末尾加这几行：

```md
写 design.md / implement.md 前先读 .trellis/spec/guides/task-artifacts.md 的固定小节。
本片对应的高保真定稿屏（slices.md 切片清单第四列）必须进 implement.jsonl——
实现期子 agent 在全新 context 里只看得到 jsonl 列出的文件，prd.md 里写一行路径不算。
本片碰到的每一层，它的 .trellis/spec/<层>/index.md 和那份 index 指向的同层文件，
同样必须进 implement.jsonl——规范和定稿屏走的是同一条通路。
```

**第二条是实跑得出的，漏了没有症状**：定稿画了、`prd.md` 也引用了，实现出来照样不是定稿的结构，看起来像是执行不认真。

> **`task-artifacts.md` 自带 `paths: [".trellis/tasks/**"]`**，动 task 目录里的文件时会自动注入——**这条已实测**（在临时项目里建 task，`get_context.py --mode spec --file <task>/prd.md` 命中该文件，反向对照 `src/a.ts` 不命中）。所以这一步是加一道保险，不是唯一通路。
>
> 但注入在 Claude Code 那侧挂在 **PostToolUse**，matcher 是 `Read|Edit|Write|MultiEdit`——先读一个受管路径下的文件也能触发，真正来不及的是**凭空建新文件**那种。子 agent 更彻底：它的 context 在 PreToolUse 时由 `implement.jsonl` 内联组装（`shared-hooks/inject-subagent-context.py`），dispatch prompt 还明说「需要的都给你备好了」——jsonl 没列的规范，在它开工前等于不存在。**第三条据此而来，未实跑验证。**

## 我该在哪停下来看

| # | 看什么 | 为什么 |
|---|---|---|
| 1 | `scripts/install-skills.sh --check` 是不是全绿 | 旧 PRD skill 残留会抢走需求，走上已废弃的流程 |
| 2 | `.trellis/spec/` 里轨规范**和** `guides/` 都在 | 缺一半 = agent 少一半约束在工作 |
| 3 | 只装了**一个**模板 | 装了两个，`trellis update` 会静默只刷新后装的那个 |
| 4 | `.trellis/spec/guides/` 里有 `task-artifacts.md` 和 `source-of-truth.md` | 少了这两份，design/implement 没有固定形状、四个源真没人管 |

## 常见卡点

### 「init 完了，但 slash 列表里没有 /vertical-slicing」

九成是软链没做。registry **不装 skill**，见本页开头那张表。

本仓两个 skill 都是**手工触发**（`disable-model-invocation`），所以判据是它在不在你的 slash 列表里，不是 AI 会不会自己想起来用。

```bash
scripts/install-skills.sh --check
```

### 「`ln -s` 报 File exists」

别手工 `ln -s`，跑 `scripts/install-skills.sh`。它会核对已存在的软链指向、替换错的。

### 「`.trellis/spec/` 里只有 guides，没有轨规范」

装成 `universal-guides` 了。删掉 `.trellis/spec/`，用轨 id 重装一次——轨模板自带 guides。

**别再补一次 init 去追加**：装第二个模板会把 `registry.spec.template` 顶掉，`trellis update` 从此只刷新后装的那个。

### 「已经装了两个模板，现在怎么办」

打开项目的 `.trellis/config.yaml` 看 `registry.spec.template` 那一行：

- 是轨 id（如 `web-fullstack`）→ **不用管**。轨模板现在自带 guides，`trellis update` 刷新它就够了。
- 是 `universal-guides` → 改成轨 id。改完 `trellis update` 才会重新开始刷新轨规范。

`.trellis/spec/` 里已有的文件不用动——它们内容是对的，只是更新来源被指错了地方。

### 「装完发现 `.trellis/spec/universal/guides/` 不存在」

对的，**不应该存在**。模板的 `<id>/` 那一层会被抹平，guides 直接落在 `.trellis/spec/guides/`。

### 「某个 skill 名字在 `~/.claude/skills/` 下是真目录不是软链」

脚本会报告并**中止不动它**——那可能是你自己装的第三方。确认后自己移走，再跑一次。

**退役名也一样。** 如果你有个自己写的 `system-design` 真目录，脚本不会删它，只会报错让你处理。

### 「同一个 skill 出现了两份」

如果你以前用 `claude plugins install mattpocock-skills` 或 `npx skills add` 装过，先卸掉再跑本仓的脚本。两种上游装法本身也不能兼用（上游 README：*"Pick one — installing both leaves you with every skill twice."*）。

### 「shadcn 的 MCP 装到 `~/.claude` 去了」

`shadcn mcp init` 把 `.mcp.json` 写在**你跑命令时所在的目录**。在 `~/.claude` 里跑，它就写到那儿——那**不是**全局配置。Claude Code 的 MCP 只有三档：`local` 与 `user` 都存 `~/.claude.json`，`.mcp.json` 只从**项目根**读。所以 `~/.claude/.mcp.json` 是「`~/.claude` 这个目录当项目」时才生效的配置，等于没装。

它还会顺手在那个目录留下 `package.json`、`package-lock.json` 和一个几十 MB 的 `node_modules`（安装依赖那步走的是 npm）。清掉这四样，回到项目根重跑。

**要不要干脆装 user 级？不要。** MCP 的工具定义在每个 session 都占 context，而你只有前端项目用得上它——后端 task 和框架仓吃这份开销没有回报。装 project 级，再让 starter 带着 `.mcp.json`，新项目就是免费的。

### 「已有项目，能不能只装一部分」

能。`trellis init` 对存量仓库是安全的（会问是否覆盖，也有 `--skip-existing`）。软链是全局的，跟项目无关，装一次就行。

## 对 AI 说什么 · 速查

> 本篇基本不需要对 AI 说话，都是敲命令。唯一一句：

| 场合 | 说什么 | 状态 |
|---|---|---|
| 装完确认 | `跑 scripts/install-skills.sh --check 和 ls .trellis/spec/，告诉我缺什么` | 待验证 |

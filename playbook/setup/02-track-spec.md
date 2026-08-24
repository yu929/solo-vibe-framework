# 2 · 在项目里装一条轨的 spec

> 这一步在**项目仓库**里做，不是在框架仓。每开一个新项目重来一次。

## 步骤

### 全新项目：只跑一条命令

```bash
trellis init --claude --registry https://github.com/yu929/solo-vibe-framework \
             --template web-fullstack
```

换轨就换 `--template` 的值：

| 轨 id | 技术栈 | 跨用户隔离靠什么 |
|---|---|---|
| `web-fullstack` | Next.js 16 App Router + React 19 + Tailwind v4 + shadcn/Base UI + Supabase | 数据库层 RLS 强制隔离 |
| `java-stack` | Spring Boot 4 + Postgres/Flyway + React 19/Vite + shadcn-admin-kit(ra-core)，单容器部署 | 没有 RLS。查询按归属过滤，加 ArchUnit 约束和双账号负向测试 |
| `universal-guides` | 不锁定 | 不涉及。它只有轨无关 guides，给还没有轨规范的项目用 |

**怎么确认这步成了**：

```bash
ls .trellis/spec/            # 应有 README.md frontend/ backend/ database/ testing/ guides/
ls .trellis/spec/guides/     # 应有 index.md code-reuse.md cross-layer.md
                             #      review-adjudication.md task-artifacts.md source-of-truth.md
```

轨规范和 guides **一次就都在**，因为轨模板自带 guides。

### 已经跑过裸 `trellis init` 的项目：多带 `--overwrite`

先跑过不带 `--template` 的 `trellis init` 的话，`.trellis/spec/` 里已经躺着 Trellis 自带的占位脚手架。这时候要多一个 `--overwrite`：

```bash
trellis init --claude --yes --registry https://github.com/yu929/solo-vibe-framework \
             --template java-stack --overwrite
```

占位模板本来就是等着被填的空壳，没什么可保的。真在里面写过东西的话，先提交再 `--overwrite`，这样一条 `git diff` 就能看清换掉了什么。

### 想在合并进 `main` 之前先验一把

`--registry` 默认拉的是**写死的字面量 `main`**，不是「这个仓库的默认分支」。所以在框架仓改完轨规范，正常路径是先合进 `main` 再装。要提前验证，用 `gh:` 前缀指过去：

```bash
trellis init --claude --yes --registry gh:yu929/solo-vibe-framework#<分支名> \
             --template java-stack --overwrite
```

**必须用 `gh:` 这种前缀写法。** 浏览器地址那种形式它也认，但那条路径解析分支名时会在斜杠处切断，带斜杠的分支名会被切错，然后报一个跟分支毫无关系的错。详见 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)。

## 我该在哪停下来看

### ⚠️ 千万别装两个模板

`.trellis/config.yaml` 里 `registry.spec.template` 是**单数**字段。第二次 init 会把它整行替换掉，此后 `trellis update` 只刷新第二个模板，**你的轨规范再也收不到修复**，包括那些安全规则。

最坏的地方是它不报错：update 照常成功、照常打绿字，只是少刷了一半。**没有任何症状**，直到某天你发现本地规范和框架仓的对不上。

源码依据在 [`../../references/third-party.md`](../../references/third-party.md) 的 "Four distribution mechanisms" 一节。

### ⚠️ 漏了 `--overwrite` 也不报错

实测输出是这样的：

```
📦 Downloading template "java-stack"...
   Skipped: .../.trellis/spec already exists
📋 Tracking 35 template files for updates
```

**它跳过了，然后照常打绿字、正常退出。** 你会以为装好了，实际 `.trellis/spec/` 一个字没变，直到某天发现 AI 一直在按占位模板干活。

所以上面「怎么确认这步成了」那两条 `ls` 不能省。

### 别用 `--append`

名字听起来更安全，实际是「只补缺失的文件」：`database/` 和 `testing/` 装进来了，而 `backend/` 和 `frontend/` 还是占位模板。半套轨规范加半套脚手架，比全没装更难查。

## 常见卡点

### 「`.trellis/spec/` 里只有 guides，没有轨规范」

装成 `universal-guides` 了。删掉 `.trellis/spec/`，用轨 id 重装一次，轨模板自带 guides。

**别再补一次 init 去追加**：装第二个模板会把 `registry.spec.template` 顶掉。

### 「已经装了两个模板，现在怎么办」

打开项目的 `.trellis/config.yaml`，看 `registry.spec.template` 那一行：

- 值是轨 id（如 `web-fullstack`）→ **不用管**。轨模板自带 guides，`trellis update` 刷新它就够了
- 值是 `universal-guides` → 改成轨 id。改完 `trellis update` 才会重新开始刷新轨规范

`.trellis/spec/` 里已有的文件不用动。它们内容是对的，只是更新来源被指错了地方。

### 「`.trellis/spec/universal/guides/` 不存在」

对的，**不应该存在**。模板的 `<id>/` 那一层会被抹平，guides 直接落在 `.trellis/spec/guides/`。

### 「带 `--template` 之后，Trellis 自带的 spec 没了」

这是对的，实测如此：带 `--template` 时 `.trellis/spec/` 里只有模板的内容。轨规范就该取代默认的，这也正是轨模板**必须自带 guides** 的另一半理由。

### 「改了 `.trellis/spec/` 里的文件，`trellis update` 会覆盖吗」

不会。`.trellis/.template-hashes.json` 记着每个生成文件的 SHA256，update 用它认出你改过的文件并跳过。

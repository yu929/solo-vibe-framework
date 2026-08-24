# 2 · 在项目里装一条轨的 spec

> 这一步要在项目仓库中执行，不是在框架仓。每个新项目都要做一次。

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

确认安装结果：

```bash
ls .trellis/spec/            # 应有 README.md frontend/ backend/ database/ testing/ guides/
ls .trellis/spec/guides/     # 应有 index.md code-reuse.md cross-layer.md
                             #      review-adjudication.md task-artifacts.md source-of-truth.md
```

轨模板自带 guides，因此一次安装后两者都应存在。

### 已经跑过裸 `trellis init` 的项目：多带 `--overwrite`

如果已经运行过不带 `--template` 的 `trellis init`，`.trellis/spec/` 中会有 Trellis 自带的占位脚手架。这时需要加上 `--overwrite`：

```bash
trellis init --claude --yes --registry https://github.com/yu929/solo-vibe-framework \
             --template java-stack --overwrite
```

占位模板本身没有需要保留的项目规则。如果你已经在里面写过内容，先提交，再运行 `--overwrite`，这样可以通过 `git diff` 看清替换了什么。

### 想在合并进 `main` 之前先验一把

`--registry` 默认拉取字面量 `main`，并不会读取仓库的默认分支设置。因此，框架仓修改轨规范后，通常要先合进 `main` 再安装。需要提前验证时，用 `gh:` 前缀指定分支：

```bash
trellis init --claude --yes --registry gh:yu929/solo-vibe-framework#<分支名> \
             --template java-stack --overwrite
```

这里要使用 `gh:` 前缀。浏览器 URL 虽然也能识别，但解析分支名时会在斜杠处截断；分支名含斜杠时，最后报出的错误还与分支无关。详见 [`../../references/install-mechanics.md`](../../references/install-mechanics.md)。

## 我该在哪停下来看

### 不要安装两个模板

`.trellis/config.yaml` 中的 `registry.spec.template` 是单值字段。第二次 init 会整行替换它，此后 `trellis update` 只刷新后装的模板，原来的轨规范也就收不到后续修复，包括安全规则。

这个问题不会报错。update 仍会成功并显示绿字，只是少更新一部分文件，通常要到对比本地规范与框架仓时才会发现。

源码依据在 [`../../references/third-party.md`](../../references/third-party.md) 的 "Four distribution mechanisms" 一节。

### 漏掉 `--overwrite` 也不会报错

实测输出是这样的：

```
📦 Downloading template "java-stack"...
   Skipped: .../.trellis/spec already exists
📋 Tracking 35 template files for updates
```

命令跳过写入后仍会正常退出并显示绿字，看起来像安装成功，实际 `.trellis/spec/` 没有变化，AI 仍按占位模板工作。

因此，上面的两条 `ls` 检查不能省。

### 别用 `--append`

`--append` 只补缺失文件。结果可能是 `database/` 和 `testing/` 来自轨规范，`backend/` 和 `frontend/` 仍是占位模板。这种混合状态比完全没装更难排查。

## 常见卡点

### 「`.trellis/spec/` 里只有 guides，没有轨规范」

这说明安装了 `universal-guides`。删除 `.trellis/spec/` 后，用轨 id 重装；轨模板本身已经包含 guides。

不要再运行一次 init 试图追加，第二个模板会覆盖 `registry.spec.template`。

### 「已经装了两个模板，现在怎么办」

打开项目的 `.trellis/config.yaml`，看 `registry.spec.template` 那一行：

- 值是轨 id（如 `web-fullstack`）→ 不用处理。轨模板自带 guides，运行 `trellis update` 即可
- 值是 `universal-guides` → 改成轨 id。改完 `trellis update` 才会重新开始刷新轨规范

`.trellis/spec/` 里已有的文件不用动。它们内容是对的，只是更新来源被指错了地方。

### 「`.trellis/spec/universal/guides/` 不存在」

这是正常的。安装时会去掉模板的 `<id>/` 这一层，guides 直接写到 `.trellis/spec/guides/`。

### 「带 `--template` 之后，Trellis 自带的 spec 没了」

这是正常结果。实测带 `--template` 时，`.trellis/spec/` 只保留模板内容；轨规范会取代默认 spec，所以轨模板必须自带 guides。

### 「改了 `.trellis/spec/` 里的文件，`trellis update` 会覆盖吗」

不会。`.trellis/.template-hashes.json` 记着每个生成文件的 SHA256，update 用它认出你改过的文件并跳过。

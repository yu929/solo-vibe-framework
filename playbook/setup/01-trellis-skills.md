# 1 · 装 Trellis 与全局 skill

> 这里只运行两条全局命令。以后换项目，不用重复这一步。

## 步骤

### 步骤 1 · 装 Trellis

```bash
npm install -g @mindfoldhq/trellis@latest
```

确认安装结果：

```bash
trellis --version
```

### 步骤 2 · 软链 skill

```bash
scripts/install-skills.sh
```

脚本可以反复运行，每次会处理四件事：

1. 建 `~/.claude/skills/`，不存在时才建
2. 软链本仓的 `vertical-slicing` 与 `design-review`
3. 软链 vendor 的 `grilling`、`grill-me`、`grill-with-docs`、`domain-modeling`、`prototype`、`writing-for-agents`
4. 删掉已退役的软链：`product-brief`、`prd-generator`、`prd-generator-noweb`、`system-design`、`design-system-java`、`lofi-prototype`

确认软链状态：

```bash
scripts/install-skills.sh --check
```

所有项目都显示 `=` 且退出码为 0，即为正常。出现 `✗` 时按脚本提示处理。

## 为什么是脚本，不是几行 `ln -s`

升级时，目标位置往往已经有一个指向旧仓的软链。直接运行 `ln -s` 只会报 `File exists`，不会更新指向；表面上完成了安装，实际仍在使用旧实现。

脚本会核对现有软链并替换错误指向。遇到真文件或真目录时，它会中止并报告，不会强行覆盖。

## 它删什么，不删什么

`system-design`、`product-brief` 这类退役名称很通用，可能与你自己的 skill 重名。脚本只有在下面两个条件都满足时才会删除：

- 目标确实是软链，而不是真文件或真目录
- 软链指向本仓或本框架旧版仓库根，而不是陌生位置

删除的只是软链，目标内容会原样保留。`scripts/test-install-skills.sh` 在临时目录中验证这条规则，不会碰你实际的 `~/.claude/skills/`。

## 退役清单里为什么有 `lofi-prototype`

这不是笔误。新流程会在切片前完成全量高保真，task 内再画一份低保真，会产生两个相互冲突的结构来源。

旧流程验证过的结论是：定稿必须进入 `implement.jsonl`。现在这条要求由 `vertical-slicing` 承接。

`product-brief` 同理已降级成模板 [`../../skills/vertical-slicing/assets/slices-template.md`](../../skills/vertical-slicing/assets/slices-template.md)，不再是 skill。

## 常见卡点

### 「init 完了，但 slash 列表里没有 `/vertical-slicing`」

通常是软链没有装好。registry 不负责安装 skill，见[场景首页](README.md)的四机制表。

本仓两个 skill 都要手工触发（`disable-model-invocation`）。检查它们是否出现在 slash 列表里，不要等 AI 自动调用。

```bash
scripts/install-skills.sh --check
```

### 「`ln -s` 报 File exists」

别手工 `ln -s`，跑 `scripts/install-skills.sh`。

### 「某个 skill 名字在 `~/.claude/skills/` 下是真目录，不是软链」

脚本会报告并中止，不动它。那可能是你自己装的第三方。确认之后自己移走，再跑一次。

退役名也一样：你有个自己写的 `system-design` 真目录，脚本不会删它。

### 「同一个 skill 出现了两份」

以前用 `claude plugins install mattpocock-skills` 或 `npx skills add` 装过的话，先卸掉再跑本仓的脚本。两种上游装法本身也不能兼用，上游 README 的原话是 *"Pick one — installing both leaves you with every skill twice."*

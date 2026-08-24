# 1 · 装 Trellis 与全局 skill

> 两条命令。它们是全局的，跟具体项目无关，换项目不用重来。

## 步骤

### 步骤 1 · 装 Trellis

```bash
npm install -g @mindfoldhq/trellis@latest
```

**怎么确认这步成了**：

```bash
trellis --version
```

### 步骤 2 · 软链 skill

```bash
scripts/install-skills.sh
```

它做四件事，幂等，可以反复跑：

1. 建 `~/.claude/skills/`，不存在时才建
2. 软链本仓的 `vertical-slicing` 与 `design-review`
3. 软链 vendor 的 `grilling`、`grill-me`、`grill-with-docs`、`domain-modeling`、`prototype`、`writing-for-agents`
4. 删掉已退役的软链：`product-brief`、`prd-generator`、`prd-generator-noweb`、`system-design`、`design-system-java`、`lofi-prototype`

**怎么确认这步成了**：

```bash
scripts/install-skills.sh --check
```

全 `=` 且退出码为 0 就对了。出现 `✗` 按它的提示处理。

## 为什么是脚本，不是几行 `ln -s`

升级场景下目标总是已存在，指向的是旧仓。裸 `ln -s` 会报 `File exists` 然后什么也不做。看起来装完了，实际还在跑旧实现。

脚本会核对已存在软链的指向、替换指错的那些，并对「不是软链而是真目录」的情况**中止并报告**，而不是硬覆盖。

## 它删什么，不删什么

退役名（`system-design`、`product-brief` 这些）都很通用，你完全可能有同名的自有 skill。所以删除动作卡两层，缺一不可：

- **真文件和真目录一律不碰**，只报告并退出，等你自己确认
- **指向陌生位置的软链也不碰**，那可能是你自己装的同名 skill

只有「确实是软链、且指向本仓或本框架旧版仓库根」的才删。删软链是无损的，指向的目标原样保留。这条由 `scripts/test-install-skills.sh` 卡住，它在临时目录里跑，碰不到你真正的 `~/.claude/skills/`。

## 退役清单里为什么有 `lofi-prototype`

这不是笔误。新流程里全量高保真在切片**之前**就定稿了，task 内再出一次低保真，等于跟定稿构成两个互相冲突的结构源真。

它承接的那条实跑结论是定稿必须进 `implement.jsonl`，已改由 `vertical-slicing` 接住。

`product-brief` 同理已降级成模板 [`../../skills/vertical-slicing/assets/slices-template.md`](../../skills/vertical-slicing/assets/slices-template.md)，不再是 skill。

## 常见卡点

### 「init 完了，但 slash 列表里没有 `/vertical-slicing`」

九成是软链没做。registry **不装 skill**，见[场景首页](README.md)那张四机制表。

本仓两个 skill 都是手工触发（`disable-model-invocation`），所以判据是**它在不在你的 slash 列表里**，不是 AI 会不会自己想起来用。

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

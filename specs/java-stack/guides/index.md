# 思维清单 · 索引

> **用途**：在动手之前扩大思考面，接住那些「没想到」的坑。
>
> 大部分 bug 和技术债不是来自能力不足，是来自**没想到**——没想到层与层之间的格式假设、没想到这个模式已经出现过三次、没想到这个改动会牵动别处。
>
> 这些清单不讲怎么写代码，只帮你在写之前**问对问题**。

## 本层范围

轨无关的通用思维方式与评审纪律。**不含任何技术栈约定**——那些是**轨规范**，和本目录一起装在 `.trellis/spec/` 下，在 `frontend/` `backend/` `database/` 这些同级目录里（具体分层随轨而定）。

## 动工前检查清单

不确定要不要读某份清单时，看触发条件：

### 什么时候读 [`code-reuse.md`](code-reuse.md)

- [ ] 你正要写一段和已有东西很像的代码
- [ ] 同一个模式你已经看到第三次
- [ ] 你正在给多个地方加同一个字段
- [ ] **你正要改任何一个常量或配置**
- [ ] **你正要新建一个工具函数 / helper** ← 先搜
- [ ] 两个文件在各自解析同一份数据结构

### 什么时候读 [`cross-layer.md`](cross-layer.md)

- [ ] 这个功能跨了 3 层以上（界面、服务、存储、外部接口）
- [ ] 数据在层与层之间换了格式
- [ ] 多个消费方需要同一份数据
- [ ] 你不确定某段逻辑该放在哪一层
- [ ] 你正在给某个事件、消息或配置加字段

### 什么时候读 [`review-adjudication.md`](review-adjudication.md)

- [ ] **编码或调试时发现了「这个约定其实不对」「这里有坑 spec 没写」** ← 最常触发的一条
- [ ] 要决定某条经验值不值得升级进 `.trellis/spec/`
- [ ] 原型走查、方案选案要收敛
- [ ] 想知道什么时候该升级到完整评审协议

**它不含完整评审协议**（十条纪律、P0–P3、八字段证据格式、停止规则）——那些在 `design-review` skill 里，只在触发评审时加载。这里只有每天都会用到的两条。

### 什么时候读 [`task-artifacts.md`](task-artifacts.md)

- [ ] 你正要写这个 task 的 `design.md` 或 `implement.md`
- [ ] 不确定某件事该写进 `prd.md`、`design.md` 还是 `implement.md`
- [ ] 判断这个 task 要不要补 `design.md`（轻量 task 只有 `prd.md` 也合法）

**这份自带 `paths: [".trellis/tasks/**"]`**，动 task 目录里的文件时会自动注入，不用记得来读。

### 什么时候读 [`source-of-truth.md`](source-of-truth.md)

- [ ] PRD 和原型对不上，不知道该改哪个
- [ ] 探针 / 走查跑出了新结论，要回灌进上游文档
- [ ] 同一件事在两个文件里都写了，不确定谁是准的
- [ ] 你正要在文档里追加一句「上面那段已废弃」← **这条就是它要防的事**

**这份自带 `paths: ["docs/discovery/**"]`**，动需求探索产物时自动注入。

## 完工质量门

这些清单本身不构成质量门——具体的 typecheck / lint / test / build 命令在各仓库自己的约定里。

本层只有一条通用质量门：

> **改任何值之前先搜一遍。**
>
> ```bash
> grep -rn "要改的值" .
> ```
>
> 这一个习惯能挡掉大部分「忘了同步 X」类的 bug。

## 本层文件

| 文件 | 管什么 |
|---|---|
| [`code-reuse.md`](code-reuse.md) | 写新代码之前先确认它是不是已经存在 |
| [`cross-layer.md`](cross-layer.md) | 跨层功能的数据流、边界与契约 |
| [`review-adjudication.md`](review-adjudication.md) | **召回与裁决分离**（日常海拔）：编码期 finding 4 字段、需求探索期轻量收敛 |
| [`task-artifacts.md`](task-artifacts.md) | task 的 `design.md` / `implement.md` 各写什么（**按路径自动注入**） |
| [`source-of-truth.md`](source-of-truth.md) | 每个阶段谁是权威源、反写用 delta 不用追加（**按路径自动注入**） |

## 怎么维护

- **踩到新坑之后**，回来把它加进相应清单——这些文件的价值全部来自真实教训，不来自通用最佳实践。
- 加之前先问：**这条是不是轨无关的？** 换个技术栈还成立才进这里；涉及具体框架、数据库、构建工具的，归同级的轨规范目录（`frontend/` `backend/` …）。
- **改这些文件要去改框架仓的 `specs/universal/guides/`（权威源）**，各轨模板里的是它的生成副本，直接改会在下次同步时被覆盖。

---

<sub>`code-reuse.md` 与 `cross-layer.md` 的问题框架参考了 [Trellis](https://github.com/mindfold-ai/Trellis)（AGPL-3.0）内置 spec 模板中的 thinking guides，内容按本框架重写，未逐字复制。</sub>

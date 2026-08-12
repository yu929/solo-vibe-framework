---
name: design-review
description: 对承重决策与切片计划做收敛式准入评审，判断「能否安全开工」而非「审到没有任何问题」。专治反复换 session/agent 审计、问题越修越多、停不下来的「无限审计循环」：用冻结输入、问题台账、证据门槛、P0–P3、停止规则和召回/裁决分离强制收敛，轨特化检查项由调用方提供。触发词：设计评审、设计准入、审设计、评审技术设计、评审切片计划、准入评审、设计审查、设计审不完、反复评审停不下来、design review。不做需求评审或代码评审。
---

# 设计准入评审

对承重决策与切片计划做**收敛式准入评审**，回答"能否以可控风险开工"，不是"是否再也找不出问题"。

> **纪律正文不在本文件。** 权威源是 [`references/review-adjudication.md`](references/review-adjudication.md)——十条纪律、严重度定义、证据格式都在那里。**本文件只定义什么时候触发、按什么顺序操作、用哪些模板。**
>
> 改纪律改那一份，不要在这里另写一套。
>
> 正文放在 skill 自己的 `references/` 里是有意的：本 skill 会被软链或拷贝到 `~/.claude/skills/`，那里读不到仓库的 `specs/` 目录。**skill 必须自包含**，否则装到别处就成了缺核心规则的空壳。

## 什么时候用

- 用户主动喊："审一下设计""这个设计能开工了吗""设计审不完了""反复评审停不下来"。
- 承重决策（数据所有权、权限与信任边界、模块切分、长期契约）刚定稿，准备建第一批 task 之前。
- 高风险范围变更后：鉴权、数据迁移、不可逆操作、涉钱。

**什么时候不用**：

- 需求还没收敛（那是简报和 `lofi-prototype` 的事，本 skill 明确不做需求评审）
- 单个 task 的实现正确性（那是 Trellis 的 check 阶段和代码评审的事）
- **编码期发现「这条约定不对」**——那走 4 字段 finding，不开评审。规则在 `specs/universal/guides/review-adjudication.md`

逐片推进时本 skill 的触发面很窄：大部分切片不需要独立的设计准入，Trellis 的 planning summary 门禁就够了。**它主要服务两种情况**——承重决策刚定稿，或者你已经陷在无限审计里出不来。

## 轨特化检查项由调用方提供

本 skill 提供**轨无关的收敛机制**。[`agents/design-reviewer.md`](agents/design-reviewer.md) 是轨无关的 reviewer 骨架，**轨硬约束必须由目标仓库的 overlay 补充**（例如某轨的数据隔离规则、数据访问路径约定、凭据边界）。

没有 overlay 时也能跑，但只覆盖通用检查面。**不要把某一轨的硬约束写进本仓**——那是漂移。

评审对象与台账路径服从目标仓库约定。切片顺序在 `docs/discovery/brief.md` 的切片清单里。承重决策的落点按目标仓库自己的文档约定找（可能是 `docs/adr/`、`docs/architecture/` 或别的）——**Trellis 的 `.trellis/spec/` 只放编码规范**，不是承重决策的宿主，别去那里找。

## 评审协议

### Step 0 · 冻结输入并读/建台账

记录：需求版本、承重决策版本、工程基线版本、评审范围与非范围、本次采用的 reviewer 清单、台账路径。

先读现有台账；不存在时用 [`assets/review-ledger-template.md`](assets/review-ledger-template.md) 建立。

**未冻结输入或未读/建台账时不得进入评审**——这是硬门禁，不是建议。

### Step 1 · Round 1 结构评审

只查：需求覆盖、模块职责、数据与状态流、契约一致、切片独立性、仓库约束、明显架构矛盾。

**不得扩大成泛泛"全面评审"。**

### Step 2 · Round 2 失败模式与数据风险

只查会阻塞实现的失败和数据问题：事务、幂等、并发、一致性、数据损坏、迁移删除、外部依赖不可用、身份权限、凭据边界、恢复路径。

轨专属硬约束只在对应轨启用，不得把一轨的规则带入另一轨。

### Step 3 · 合并、去重与裁决

把两轮或多个 reviewer 的发现合并去重，由主 agent **逐条回原文二次核实**后写入台账，落一个 `status`。

召回与裁决不能混用：不取并集全改，不用多数投票判真假。默认主 agent 作 adjudicator；只有高风险范围才升级多个独立 reviewer，但**裁决仍然只有一处**。

### Step 4 · 停止判定

满足全部即准入：

1. 所有 Accepted P0 已关闭
2. 所有 Accepted P1 已关闭或有明确处置
3. **连续一轮没有新的 Accepted P0/P1**
4. 新发现仅为 P2/P3、重复、无证据或范围外
5. 至少一个垂直切片可端到端实施验证

**最多两轮纯设计评审。** 超预算后把反馈渠道转向切片实现和测试。

## 输出

1. 对话中的准入报告，用 [`assets/review-report-template.md`](assets/review-report-template.md)。
2. 更新台账：全部发现的最终状态与 `reopen_condition`。
3. P0/P1 非空时列出开工前必做项；修复后**只跑一次复审**，不重启开放式审计。

## 约束

- 不把开放技术选择当问题。
- 不重复报同类问题；给 2–3 个代表项和影响范围。
- 不重提未满足 `reopen_condition` 的已裁决项。
- 不把"编码期决定"的实现细节报成阻塞。
- 不把风格偏好或其他轨的规则带入。
- 每条发现必须可由主 agent 打开原文二次核实。

## 台账生命周期

台账是评审期工作文件。版本发布时：仍开放的 `ACCEPTED_RISK` / `DEFERRED` / backlog 连同 `reopen_condition` 迁入目标仓库的已知问题；已关闭和已拒绝的历史由 Git 保存；台账按目标仓库文档生命周期删除或归档。下一大迭代需要准入时重新建立。

## 文件清单

| 文件 | 用途 |
|---|---|
| `references/review-adjudication.md` | **纪律权威源**（十条 + 严重度 + 证据格式） |
| `agents/design-reviewer.md` | 轨无关 reviewer 骨架；轨硬约束由目标仓库 overlay 补充 |
| `references/sop-guide.md` | 台账维护、多 agent 升级、收益递减判断、FAQ |
| `assets/review-ledger-template.md` | 问题台账模板 |
| `assets/review-report-template.md` | 准入报告模板 |

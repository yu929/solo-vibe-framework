# 设计评审问题台账（review ledger）

> **跨 session 记忆。每轮评审先读本文件。** `REJECTED_*` / `DEFERRED` / `ACCEPTED_RISK` 条目**不得重提**，除非满足其 `reopen_condition`。
> 严重度 P0–P3。`status ∈ {ACCEPTED_BLOCKING, ACCEPTED_NON_BLOCKING, DEFERRED, ACCEPTED_RISK, DUPLICATE, REJECTED_OUT_OF_SCOPE, REJECTED_UNSUPPORTED, CLOSED}`（CLOSED = 修复落地或 reopen 条件已兑现）。
> 本台账是评审期工作文件：版本发布时把仍开放条目迁入**目标仓库的已知问题文件**（路径按那个仓库自己的文档约定）后删除本文件（历史在 git），见 design-review SKILL「台账生命周期」。

## 冻结输入（每轮评审更新）

- 需求版本: `<brief.md commit / 已建 task 的 prd.md 版本>`
- 设计版本: `技术设计 v0.1` / `实施计划 v0.1`
- 工程基线版本: `<starter / repository baseline / commit>`
- 评审清单: `<轨专属 reviewer 路径>`
- 评审范围: `<全部 / 切片 B1–B2>`
- 非范围: `<多区域 / 离线 / SSO / ...>`
- 轮次记录:
  - R1 @`<YYYY-MM-DD>`: 发现 P0×_ P1×_ P2×_ P3×_；裁决 `<摘要>`
  - R2 @`<YYYY-MM-DD>`: 新增 Accepted P0/P1 = _（若为 0 → 满足停止规则）

---

## 已接受 · 进行中 / 待办

```yaml
- id: FINDING-001
  category: authorization             # authorization/concurrency/data-model/coverage/contract/...
  severity: P0                        # P0/P1/P2
  evidence: "技术设计 §3.2 未定义受保护资源的写入授权"
  trigger: "调用方提交不属于自己的资源标识"
  impact: "可能越权修改其他主体的数据"
  affected_requirement: "<task prd.md 章节 / 简报切片清单第几行>"
  blocking_reason: "破坏授权边界"
  status: ACCEPTED_BLOCKING
  resolution: ""                      # 关闭时填：改了哪个文档哪节
  reopen_condition: ""
```

## 推迟 / 拒绝 / 接受风险（本轮起不再重提，除非命中 reopen_condition）

```yaml
- id: FINDING-008
  category: scalability
  severity: P3
  evidence: "技术设计未描述多区域部署冲突解决"
  trigger: "当前单区域范围不触发"
  impact: "在当前范围内无影响"
  affected_requirement: "非范围：多区域部署"
  blocking_reason: "不阻塞：需求明确排除"
  status: REJECTED_OUT_OF_SCOPE
  reason: "当前单区域部署、无多区域需求"
  reopen_condition: "需求新增跨区域容灾"

- id: FINDING-012
  category: concurrency
  severity: P2
  evidence: "并发控制的锁实现未细化"
  trigger: "进入切片编码并选择具体并发实现"
  impact: "设计阶段无法仅靠纸面证明实现正确性"
  affected_requirement: "技术设计中的并发不变量"
  blocking_reason: "不阻塞：属于编码与测试细节"
  status: DEFERRED
  reason: "实现级细节，编码期定 + 补并发测试验证（海拔下放）"
  reopen_condition: "切片实现时发现业务不变量可被并发突破"
```

## 已关闭（留痕）

```yaml
- id: FINDING-003
  category: authorization
  severity: P1
  evidence: "技术设计 §3.4 原先缺少写入授权不变量"
  trigger: "调用方提交其他主体的资源标识"
  impact: "可能越权修改数据"
  affected_requirement: "<task prd.md 章节 / 简报切片清单第几行>"
  blocking_reason: "破坏授权边界"
  previous_status: ACCEPTED_BLOCKING
  status: CLOSED
  resolution: "技术设计 §3.4 补充授权不变量；实施计划 S02 增加双身份越权测试"
  reopen_condition: "权限模型或资源所有权发生变化"
```

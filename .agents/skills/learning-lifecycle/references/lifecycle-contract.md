# 学习生命周期契约

本文件规定路线、当前执行板、学习单和阶段检查点之间的机器可读接口。机器字段使用英文稳定标识；解释性正文使用简体中文。

## 生命周期与职责

```text
路线阶段契约
→ 当前执行板
→ 诊断或教学
→ 引导练习
→ 无提示验证
→ 延迟复核与真实迁移
→ 阶段退出审计
→ 通过检查点
→ 解锁下游阶段
→ 全路线终审
```

- 路线契约定义教学范围和退出能力，建议时间仅是 `pace_hint`。
- `state/current.md` 是唯一动态执行板，不保存手工完成阶段清单。
- 学习单状态描述文档工作流，逐目标证据描述学习强度，两者不得混用。
- 阶段检查点只记录已经通过的退出审计。不存在失败检查点或有条件通过。

## 路线契约

`roadmap/index.md` 使用固定表头：

```markdown
| stage_id | contract_version | route_file | depends_on | unlocks |
```

`depends_on` 可为 `none`、阶段 ID，或 `target:LS-02` 形式的目标依赖；多个引用使用英文逗号分隔。目标依赖只要求指定能力，不自动扩大为整个所属阶段。注册表中的 `depends_on` 是唯一可执行门槛。`unlocks` 只是同一注册表内供人阅读的下游导航摘要，只能引用已知阶段且不能自指，不参与解锁判定；各阶段正文不得再复制 `unlocks` 元数据。

每个阶段在对应路线文件中使用以下结构，元数据必须紧跟标题且保持顺序：

```markdown
## 阶段：阶段名称 {#stage-id}
- stage_id: stage-id
- contract_version: 1
- pace_hint: 约 10 周
- depends_on: none

### 阶段目的

### 教学范围

### 局部活动门槛

### 退出目标

| target_id | 类型 | 可观察表现 | 最低证据 | 代表性任务 |

### 阶段成果

### 退出条件与解锁
```

六个三级章节必须唯一、按上述顺序排列且包含实际内容，确保教学范围与退出能力分别维护。目标 ID 使用 `<大写阶段前缀>-<两位序号>`。基线诊断阶段目标的最低证据是 `sampled`；其他阶段目标的最低证据是 `independent` 或 `robust`。同一阶段的教学内容可以先于部分局部活动门槛出现，但依赖活动和阶段检查点不能绕过依赖。

`contract_version` 在目标集合、目标语义、最低证据、依赖或退出条件发生实质变化时必须递增；已有旧版本检查点不能自动继承新契约，必须重新执行退出审计。只改错字、排版或不改变门槛的解释性澄清不递增版本。注册表、阶段契约和检查点的版本必须一致，否则检查器失败关闭。

依赖顺序只记录到日期，无法证明同日事件先后。因此，上游目标证据或阶段检查点必须严格早于下游 `independent`、`robust` 证据及下游检查点；同日只允许 `learning`/`guided` 预览，不计正式能力。基线通过检查点也必须严格早于任何非基线阶段检查点。

## 证据状态

诊断目标只使用：

- `unsampled`：尚无足够样本；
- `sampled`：已有作答样本和可执行的起点结论。

教学目标使用：

- `not_started`：尚未开始；
- `learning`：正在教学，尚无可计入退出的表现；
- `guided`：使用了方法提示、框架或更强帮助；
- `independent`：仅澄清题意，独立完成熟悉类型任务；
- `robust`：独立完成，并通过延迟复核或真正的新情境、新表示迁移；
- `needs_refresh`：较新的证据暴露遗忘，需要局部重开。

只改变参数不算迁移。提示后的订正必须换等价任务无提示重做，才能升级为 `independent`。

## 当前执行板

`state/current.md` 的前置区字段和顺序固定为：

```yaml
---
updated: YYYY-MM-DD
focus_stage_id: baseline-diagnostic
focus_mode: work
parallel_stage_ids:
  - motion-change
---
```

`focus_mode` 只使用 `work` 或 `exit_review`。正文使用以下固定二级标题和机器表格：

```markdown
## 当前阶段目标状态
| target_id | state | evidence | unmet |

## 合法的并行学习线
| stage_id | target_ids | state | evidence | unmet |

## 关键能力复核队列
| target_id | due | task | status |

## 唯一下一学习任务
- stage_id: baseline-diagnostic
- activity: diagnostic
- target_ids: BD-03, BD-05
- task: 指向一份尚未创建的具体学习任务
```

`baseline-diagnostic` 不是运动或线性系统的知识依赖，因此两条线可以在诊断期间并行积累证据；但焦点离开基线前必须已有有效的基线通过检查点，且基线期间不得提前创建其他阶段检查点。

证据列使用指向已批阅学习单或有效检查点的相对链接；确实无证据时写 `none`。`unsampled` 可以链接只说明教学经历、但不构成原始诊断样本的学习单。下一任务不能指向已经满足的目标；唯一窄例外是 `focus_mode: exit_review` 下的 `assessment`，它可以引用至少一个已经达标的焦点目标，用于未见综合退出任务。复核队列 `status` 使用 `not_ready`、`pending`、`scheduled` 或 `completed`；`due` 可写日期、日期区间，或“取得无提示独立证据后 7～14 天”一类可执行窗口。正文还可以包含“当前焦点阶段”“已验证成果”“待解决问题”等说明，但不能新增第二份动态待办或手工完成阶段字段。

`updated` 是当前执行板采用的证据截止日。晚于今天的 `reviewed` 学习单和 `passed` 检查点一律非法；晚于 `updated` 的学习单不计入当前解锁。若这类学习单被执行板引用、改变当前相关目标/依赖的有效状态，或登记任何 `needs_refresh`，必须先同步执行板。没有改变跨学习单状态的已批阅记录不强制改写 `updated`，未来任务可以保持 `planned`。

阶段通过检查点保留历史结论。若检查点之后出现 `needs_refresh`，允许该阶段临时重新成为焦点、并行线或唯一下一任务，但只能指向存在补强债务的具体目标。后续 `learning`/`guided` 不会关闭债务；只有更晚日期重新达到该目标当前契约的最低证据，才恢复完成状态。依赖该目标的下游门槛在恢复前暂时失效。

## 学习单

学习单前置区字段和顺序固定为：

```yaml
---
date: YYYY-MM-DD
stage_id: stage-id
activity: diagnostic
target_ids:
  - BD-01
topic: 主题
planned_minutes: 90
status: planned
---
```

`activity` 只使用 `diagnostic`、`learning`、`assessment`、`project`；`status` 只使用 `planned`、`submitted`、`reviewed`。综合任务可以引用多个阶段目标，但主要阶段必须至少拥有其中一个目标。基线 `assessment` 可以在无方法提示时产生 `sampled`，用于综合复核样本和退出审计；它仍不是 `independent` 或“已掌握”的升级。目标所属阶段在该学习单日期尚未解锁时，`planned`/`submitted` 可以保留预览安排；若已批阅，则只允许 `activity: learning`，证据最多登记为 `guided`。此时不得用 `assessment`、`project` 或 `sampled`、`independent`、`robust`、`needs_refresh` 倒灌正式证据；应先复核失效的先修。

二级标题按顺序使用：`本次目标`、`前置检查`、`学习内容`、`练习`、`用户结果`、`AI 批阅`、`下一步`、`相关项目与资料`。

`reviewed` 学习单在 `AI 批阅` 中使用固定逐目标表：

```markdown
| target_id | help | evidence_state | evidence | correction_closure | review_debt |
```

表格覆盖学习单声明的全部目标。`help` 使用 `none`、`clarification`、`hint`、`framework`、`solution` 记录实际最高帮助程度；`evidence_state` 使用目标类型允许的状态，`evidence` 记录表现，`correction_closure` 记录提示后是否已换题闭环，`review_debt` 记录延迟复核或迁移债务。`correction_closure` 建议使用 `not_needed`、`open` 或 `independently_closed`，也可写成 `independently_closed: 具体说明`。教学证据使用了 `hint`、`framework` 或 `solution` 时，只有明确登记 `independently_closed` 的等价任务无提示闭环，才能升级为 `independent` 或 `robust`；诊断目标的 `sampled` 只证明已取得原始样本，不受后续批阅帮助限制。历史学习单可保留更具体的非占位说明。脚本验证帮助枚举、闭环冲突、非占位字段与引用一致性，但不从证据文字反向猜测提示是否过多。

## 阶段检查点

只在退出审计通过后创建 `checkpoints/stages/YYYY-MM-DD-<stage-id>.md`：

```yaml
---
stage_id: stage-id
contract_version: 1
completed_on: YYYY-MM-DD
decision: passed
---
```

正文包含按顺序排列的 `逐目标证据`、`独立性与迁移说明`、`非阻断问题` 和 `解锁结果`，逐目标表固定为：

```markdown
| target_id | evidence_level | evidence_files | independence_or_transfer |
```

表格必须恰好覆盖当前契约的全部退出目标。`evidence_files` 只引用已批阅学习单；从 `templates/` 复制到 `checkpoints/stages/` 时，必须按检查点文件的新位置重新计算相对路径，不能原样保留模板示例路径。基线目标的最后一列填写起点结论，其他目标填写独立性、延迟复核或迁移说明。检查点按 `completed_on` 汇总目标的最新有效状态，不能选择性引用旧强证据而忽略更晚的 `needs_refresh`。`decision` 只允许 `passed`，不创建失败或有条件通过检查点。

## 检查器边界

`scripts/check-lifecycle.ps1` 失败关闭并输出稳定错误码与路径，检查：

- 标识和引用存在且唯一，依赖图无环；
- 当前焦点、并行线和唯一下一任务合法，重开债务与证据截止日一致；
- 学习单路径、状态、活动、目标和必需内容一致；
- 只有已批阅学习单能作为检查点证据；
- 检查点覆盖契约并达到声明的最低证据，且依赖和证据日期合法；
- 学习单模板按真实结构实例化后可通过检查。

脚本不判断物理答案正确性、提示是否过多、任务是否为真实迁移或教学选择是否恰当。这些由退出审计作语义判断。

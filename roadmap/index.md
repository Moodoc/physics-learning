# 18 个月物理学习路线总览

## 路线目标与边界

在每周约 8 小时的前提下，以物理问题牵引数学、Python 与物理训练。阶段建议时间用于安排节奏，不是过关条件；学习者只有用可核验成果达到阶段契约，才能完成阶段并解锁依赖内容。

本路线的终点画像是“系统性物理入门和科研方向试学准备”：

- 能独立建立并验证典型简单物理模型；
- 能使用所需数学和 Python 检查单位、数量级、边界与数值误差；
- 完成量子信息、凝聚态和光学三个方向的代表性小项目；
- 根据真实学习和项目证据选择主方向与辅助方向。

该终点不等同于完整物理本科培养，也不宣称学习者已经具备独立科研能力。论文拆解和简化复现进入[选定方向后的衔接](05-post-selection.md)后再开展。

## 生命周期

正式学习统一遵循：

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
→ 18 个月路线终审
```

同一时间只有一个焦点阶段。无阶段依赖或已满足目标级门槛的学习线可以并行积累证据；并行证据不能绕过焦点阶段的退出审计，也不能提前生成阶段检查点。

## 阶段注册表

本表是阶段 ID、契约版本、依赖和解锁关系的唯一注册表。`depends_on` 使用 `none`、阶段 ID 或 `target:<目标 ID>`；多个依赖以英文逗号分隔。目标级依赖只要求对应目标达到其契约规定的最低证据，不要求完成目标所属的整个阶段。

| stage_id | contract_version | route_file | depends_on | unlocks |
|---|---:|---|---|---|
| baseline-diagnostic | 1 | [01](01-motion-linear-systems.md#baseline-diagnostic) | none | motion-change |
| motion-change | 1 | [01](01-motion-linear-systems.md#motion-change) | none | fields-electromagnetism, probability-thermal |
| linear-systems | 1 | [01](01-motion-linear-systems.md#linear-systems) | none | quantum-foundations |
| fields-electromagnetism | 1 | [02](02-fields-waves.md#fields-electromagnetism) | motion-change | route-18m-completion |
| waves-optics | 1 | [02](02-fields-waves.md#waves-optics) | none | quantum-foundations, trial-optics |
| probability-thermal | 1 | [03](03-thermal-quantum.md#probability-thermal) | motion-change | quantum-statistics |
| quantum-foundations | 1 | [03](03-thermal-quantum.md#quantum-foundations) | target:LS-02, target:LS-03, target:WO-01, target:WO-02 | quantum-statistics, trial-quantum-information, trial-condensed-matter |
| quantum-statistics | 1 | [03](03-thermal-quantum.md#quantum-statistics) | probability-thermal, quantum-foundations | route-18m-completion |
| trial-quantum-information | 1 | [04](04-direction-trials.md#trial-quantum-information) | target:QF-05, target:LS-02 | direction-selection |
| trial-condensed-matter | 1 | [04](04-direction-trials.md#trial-condensed-matter) | target:QF-04, target:LS-02 | direction-selection |
| trial-optics | 1 | [04](04-direction-trials.md#trial-optics) | target:WO-03, target:WO-04 | direction-selection |
| direction-selection | 1 | [04](04-direction-trials.md#direction-selection) | trial-quantum-information, trial-condensed-matter, trial-optics | route-18m-completion |
| route-18m-completion | 1 | [本文件](#route-18m-completion) | baseline-diagnostic, motion-change, linear-systems, fields-electromagnetism, waves-optics, probability-thermal, quantum-foundations, quantum-statistics, trial-quantum-information, trial-condensed-matter, trial-optics, direction-selection | post-selection |
| post-selection | 1 | [05](05-post-selection.md#post-selection) | route-18m-completion | none |

`baseline-diagnostic` 是诊断焦点门槛，不是运动或线性系统的知识先修。因此 `motion-change` 与 `linear-systems` 可以在诊断期间作为合法并行学习线积累证据；没有基线检查点时，焦点仍不得从诊断阶段迁出。

## 路线节奏

| 阶段 | pace_hint | 路线文件 | 主要成果 |
|---|---:|---|---|
| 基线诊断 | 2 周 | [01](01-motion-linear-systems.md#baseline-diagnostic) | 真实起点与具体补缺项 |
| 运动与变化 | 10 周 | [01](01-motion-linear-systems.md#motion-change) | 运动建模与数值复核 |
| 线性系统 | 12 周 | [01](01-motion-linear-systems.md#linear-systems) | 耦合振动与演化模型 |
| 场与电磁学 | 8 周 | [02](02-fields-waves.md#fields-electromagnetism) | 场计算与电磁关系 |
| 波与光学 | 8 周 | [02](02-fields-waves.md#waves-optics) | 波、边界和衍射模型 |
| 概率与热统 | 8 周 | [03](03-thermal-quantum.md#probability-thermal) | 配分函数与热统解释 |
| 量子基础 | 8 周 | [03](03-thermal-quantum.md#quantum-foundations) | 一维量子与二能级模型 |
| 量子统计 | 4 周 | [03](03-thermal-quantum.md#quantum-statistics) | 量子分布与经典极限 |
| 三方向试学 | 各 4 周 | [04](04-direction-trials.md) | 三个可运行小项目 |
| 方向选择、机动补缺与终审 | 6 周 | [04](04-direction-trials.md#direction-selection) | 证据化方向选择与全路线复核 |

合计约 78 周，接近 18 个月。机动时间分布在阶段交界和最终审计前，只补具体证据缺口，不压缩未掌握先修。

## 契约与证据约定

每个阶段正文分别维护教学范围与退出目标。“已经教过”不能替代退出证据；退出目标也不能反向删减契约中的教学范围。

目标表的 `最低证据` 只使用以下机器值：

- `sampled`：诊断目标已有学习者样本和起点结论；
- `independent`：仅澄清题意，无方法提示，独立完成熟悉类型任务；
- `robust`：先独立完成，再通过 7～14 天后的复核或真正不同的物理情境、表示方式迁移。

改变同一模型的参数只算练习，不算迁移。使用方法提示、框架或更强帮助完成时只能记为 `guided`；提示后订正必须更换等价任务无提示重做，才能升级为 `independent`。标为“关键先修”的目标采用更强门槛：必须同时具备当次无提示独立完成、7～14 天后的复核和真正的新情境或新表示迁移，进入高依赖阶段前还要短抽样。后续暴露遗忘时标记 `needs_refresh` 并局部重开。

阶段只有在退出审计通过后，才创建 `checkpoints/stages/YYYY-MM-DD-<stage-id>.md`。学习单达到 `reviewed` 只表示文档完成批阅，不等于目标已验证或阶段已通过。四周及以上的阶段都在正文指定累计检索或综合迁移里程碑。

## 推进规则

1. 当前焦点、并行线、目标证据、复核债务和唯一下一任务只在 `state/current.md` 维护。
2. 阶段完成状态从有效检查点推导；可用和锁定状态从本注册表及目标依赖推导，不另建进度流水账。
3. 依赖较强的活动先检查对应目标，不以“学完整门课”替代真实能力门槛。
4. 概率与热统不依赖正式量子；正式量子缺先修时，这条学习线仍可继续。
5. 三个方向试学彼此不依赖；方向选择必须等待三个项目阶段全部通过。
6. 概念预览用于建立联系，不能记作正式能力或阶段退出证据。

## 默认 90 分钟学习单

| 环节 | 时间 | 说明 |
|---|---:|---|
| 具体场景与问题 | 10 分钟 | 明确研究对象和本次要回答的问题 |
| 所需数学工具 | 20 分钟 | 只引入解决当前问题所需的数学 |
| 物理模型 | 25 分钟 | 建立方程，说明变量、单位、条件和近似 |
| 独立练习或代码验证 | 25 分钟 | 学习者先完成推导、计算、解释或代码 |
| 专业英语 | 5 分钟 | 3～6 个术语和一小段原文、题目或图注 |
| 证据与下一步 | 5 分钟 | 总结结果、暴露缺口并确定下一步 |

## 每周约 8 小时的默认分配

| 活动 | 时间 | 说明 |
|---|---:|---|
| 关联概念与例题 | 2.5 小时 | 数学与物理围绕同一问题展开 |
| 独立计算与推导 | 2.5 小时 | 不看完整答案先尝试 |
| Python 建模或图像 | 1.5 小时 | 验证模型、参数和极限情况 |
| 复述、批阅与延迟复核 | 1 小时 | 订正错误并清理复核债务 |
| 前沿信号 | 0.5 小时 | 每两周可用一次短英文材料，不挤占基础训练 |

专业英语不单设课程，也不背孤立词表。评价重点是能否读懂题意、图注并复述物理意义，而不是翻译篇幅或词汇数量。

## 前沿信息的渐进方式

- 基础阶段：每两周选一篇通俗解读，只回答研究问题、方法、意义和所缺基础。
- 方向试学阶段：每月浏览少量摘要和图表，不追求通读论文。
- 选定方向后：逐步进入论文拆解、公式或图表的简化复现。

可使用 [APS Physics Magazine](https://physics.aps.org/) 和 [APS RSS](https://journals.aps.org/feeds)。光学期刊动态使用 [Optica 邮件提醒](https://opg.optica.org/col/ToC_Alerts_Subscribe.cfm)；订阅入口和栏目可能变化，使用前应重新核验。

<a id="route-18m-completion"></a>
## 阶段：18 个月路线终审 {#route-18m-completion}

- stage_id: route-18m-completion
- contract_version: 1
- pace_hint: 方向选择完成后的最终审计
- depends_on: baseline-diagnostic, motion-change, linear-systems, fields-electromagnetism, waves-optics, probability-thermal, quantum-foundations, quantum-statistics, trial-quantum-information, trial-condensed-matter, trial-optics, direction-selection

### 阶段目的

用全路线检查点和近期综合表现确认终点画像，而不是把周数、文档数量或旧成绩当作完成。

### 教学范围

本阶段不增加新课程，只允许针对终审暴露的具体缺口进行局部复习和等价任务重验。

### 局部活动门槛

- 所有依赖阶段都有当前契约版本下的通过检查点，才进入终审。
- `RC-02` 必须先独立完成一项近期、未见过的综合任务，再在 7～14 天后用不同物理情境或表示方式完成无提示复核；旧项目或同模型改参数不能替代任一次证据。

### 退出目标

| target_id | 类型 | 可观察表现 | 最低证据 | 代表性任务 |
|---|---|---|---|---|
| RC-01 | 终审 | 汇总全部必修阶段、三个试学项目和方向选择的有效检查点 | independent | 审核检查点版本、目标覆盖与证据文件 |
| RC-02 | 关键先修 | 在近期新情境中独立建模，检查单位、数量级、边界和数值误差 | robust | 首次完成跨至少两个既有阶段的未见综合模型，7～14 天后再完成不同情境或表示方式的综合复核 |
| RC-03 | 终审 | 用项目证据说明自己的能力边界、主辅方向与下一周期缺口 | independent | 口头或书面答辩并逐条链接证据 |

### 阶段成果

一份 `route-18m-completion` 通过检查点，明确路线承诺已达到的能力和仍未承诺的能力。

### 退出条件与解锁

`RC-01`、`RC-03` 达到 `independent`；`RC-02` 同时具备首次无提示独立、7～14 天延迟复核和真实迁移证据，达到关键先修的 `robust` 门槛；且没有阻断性证据缺口时通过。通过后解锁下一周期 `post-selection`；否则只重开具体目标，不生成失败或“有条件通过”检查点。

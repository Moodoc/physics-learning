---
updated: 2026-09-02
focus_stage_id: baseline-diagnostic
focus_mode: exit_review
parallel_stage_ids:
  - motion-change
  - linear-systems
---

# 当前学习状态

## 当前焦点阶段

- 阶段契约：[baseline-diagnostic](../roadmap/01-motion-linear-systems.md#baseline-diagnostic)
- 当前目的：九个规定领域均已取得起点样本；通过未见综合任务审查样本覆盖、独立程度和起点结论后，再决定是否通过基线阶段。
- 当前模式：`exit_review`。所有目标均已达到最低 `sampled` 证据，但综合退出审计尚未完成，因此不能生成基线阶段检查点。
- 阶段完成只从有效的通过检查点推导；学习单为 `reviewed` 不等于目标已验证或阶段已完成。

## 当前阶段目标状态

| target_id | state | evidence | unmet |
|---|---|---|---|
| BD-01 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；代入算术、根式和数量级检查归入后续教学 |
| BD-02 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；本状态不表示三角函数已经掌握 |
| BD-03 | sampled | [补充诊断学习单](../sessions/2026/09/2026-09-01-logarithm-integral-diagnostic.md) | 无诊断欠账；对数精确变形正确，但数值估算与逆运算解释需教学；指数教学后样本中代入和极限正确，等比例衰减、绝对变化、无量纲指数与特征时间解释不稳；教学前指数起点不可恢复 |
| BD-04 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；更复杂情境的导数运用归入正式教学 |
| BD-05 | sampled | [补充诊断学习单](../sessions/2026/09/2026-09-01-logarithm-integral-diagnostic.md) | 无诊断欠账；定积分计算、曲线下面积、累积量解释和单位检查均正确，本状态不表示已经掌握跨情境积分运用 |
| BD-06 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；功的点积表述、接触条件和计算检查归入后续教学 |
| BD-07 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 已形成科学 Python 起点判断；NumPy、绘图和数值方法的教学证据另记在并行学习线 |
| BD-08 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；变量、参数、条件、假设和输出的稳定区分仍需教学 |
| BD-09 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；后续材料保持短题干和图注级别 |

## 合法的并行学习线

| stage_id | target_ids | state | evidence | unmet |
|---|---|---|---|---|
| motion-change | MC-02 | guided | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 受力、稳定状态和边界检查在反馈后完成；需换新运动情境无提示建模后才能升级为 `independent` |
| motion-change | MC-04 | independent | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 已独立完成 NumPy、绘图和误差解释；尚无延迟复核与真实迁移，不能登记 `robust` |
| linear-systems | LS-03 | guided | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 只形成使用方法框架完成的标量一阶演化证据；尚未覆盖二阶方程组改写、`solve_ivp`、无提示重做和迁移 |

这些并行线只积累真实证据，不改变当前焦点，也不能在缺少各自退出审计和通过检查点时提前完成阶段。

## 关键能力复核队列

| target_id | due | task | status |
|---|---|---|---|
| MC-04 | 2026-09-02 至 2026-09-09 | 无提示重做一次解析—数值交叉验证，并改用不同模型或表示方式；只改变参数不算迁移 | pending |
| LS-03 | 取得无提示独立证据后 7～14 天 | 在新的物理情境中独立完成二阶方程到一阶方程组的改写、数值演化和误差检查 | not_ready |

## 已验证成果

- 基线九个目标均已取得实际样本并形成起点结论；补充诊断显示定积分计算与累积量解释完整，对数精确变形和指数代入极限可完成，但指数比例、特征时间及对数逆运算意义仍需教学。这些结论不等于相关知识已经掌握。
- 在线性阻力任务中，学习者独立完成 NumPy 向量化计算、`np.gradient`、误差切片、两种步长比较和 Matplotlib 分图，形成 `MC-04: independent` 证据。
- 受力与稳定性分析、偏离量变换和一阶方程推导已经发生有效学习，但因使用了方法提示，分别只登记为 `MC-02: guided` 与 `LS-03: guided`。

## 待解决问题

- 基线已无未取样目标，但尚未完成未见综合退出审计；`BD-03` 的指数结论只能记为教学后当前水平，退出审计必须保留“教学前指数起点不可恢复”的限制。
- `MC-02` 和 `LS-03` 尚无无提示等价任务证据；`MC-04` 尚无 7～14 天延迟复核和真正的新情境或新表示迁移。
- `np.diff`、Euler 方法和 SciPy 是后续正式教学或验证内容，不是基线诊断欠账，也不能据此延长基线范围。
- 线性阻力任务中的参数变化只算同模型练习，不能作为迁移证据。

## 唯一下一学习任务

- stage_id: baseline-diagnostic
- activity: assessment
- target_ids: BD-01, BD-02, BD-03, BD-04, BD-05, BD-06, BD-07, BD-08, BD-09
- task: 创建一份约 90 分钟的未见综合基线退出任务，以一个新的运动与衰减测量情境串联代数、三角、指数与对数、导数、定积分、向量与基础力学、科学 Python、模型要素和短英文图注。除澄清题意外不提供帮助；逐目标核对样本真实性与起点结论，并明确保留 `BD-03` 的指数历史污染限制。通过语义审计后才创建基线阶段检查点，未通过则只重开具体缺口。

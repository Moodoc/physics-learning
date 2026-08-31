---
updated: 2026-08-31
focus_stage_id: baseline-diagnostic
focus_mode: work
parallel_stage_ids:
  - motion-change
  - linear-systems
---

# 当前学习状态

## 当前焦点阶段

- 阶段契约：[baseline-diagnostic](../roadmap/01-motion-linear-systems.md#baseline-diagnostic)
- 当前目的：完成规定领域的起点取样并形成后续教学判断；诊断取样不等于掌握。
- 当前模式：`work`。`BD-03` 与 `BD-05` 尚未取样，因此不能进入退出审计，也不能生成基线阶段检查点。
- 阶段完成只从有效的通过检查点推导；学习单为 `reviewed` 不等于目标已验证或阶段已完成。

## 当前阶段目标状态

| target_id | state | evidence | unmet |
|---|---|---|---|
| BD-01 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；代入算术、根式和数量级检查归入后续教学 |
| BD-02 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；本状态不表示三角函数已经掌握 |
| BD-03 | unsampled | none | 指数的教学前起点已不可恢复；需补充对数的原始诊断样本和指数的教学后当前水平样本，二者分开结论且不得倒写到 8 月 25 日 |
| BD-04 | sampled | [基线学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 无诊断欠账；更复杂情境的导数运用归入正式教学 |
| BD-05 | unsampled | none | 缺少定积分计算及面积—累积量物理意义的实际样本 |
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

- 基线已对代数、三角、导数、向量与基础力学、科学 Python、模型要素和短英文材料取得实际样本并形成起点结论；这些结论不等于相关知识已经掌握。
- 在线性阻力任务中，学习者独立完成 NumPy 向量化计算、`np.gradient`、误差切片、两种步长比较和 Matplotlib 分图，形成 `MC-04: independent` 证据。
- 受力与稳定性分析、偏离量变换和一阶方程推导已经发生有效学习，但因使用了方法提示，分别只登记为 `MC-02: guided` 与 `LS-03: guided`。

## 待解决问题

- 基线只缺 `BD-03` 的对数原始诊断、指数教学后当前水平样本与 `BD-05` 的定积分取样；指数的教学前起点不可恢复，退出审计必须保留这一限制。
- `MC-02` 和 `LS-03` 尚无无提示等价任务证据；`MC-04` 尚无 7～14 天延迟复核和真正的新情境或新表示迁移。
- `np.diff`、Euler 方法和 SciPy 是后续正式教学或验证内容，不是基线诊断欠账，也不能据此延长基线范围。
- 线性阻力任务中的参数变化只算同模型练习，不能作为迁移证据。

## 唯一下一学习任务

- stage_id: baseline-diagnostic
- activity: diagnostic
- target_ids: BD-03, BD-05
- task: 在一份约 90 分钟的补充诊断中，用短题取得对数的原始诊断样本、定积分及面积—累积量解释的原始诊断样本，并单独取得指数在 8 月 26 日教学后的无提示当前水平样本。三者分栏记录；指数不得倒写成教学前基线。除澄清题意外不提供方法提示，完成批阅并写明历史污染限制后再进入基线退出审计。

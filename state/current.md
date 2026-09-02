---
updated: 2026-09-02
focus_stage_id: motion-change
focus_mode: work
parallel_stage_ids:
  - linear-systems
---

# 当前学习状态

## 当前焦点阶段

- 阶段契约：[motion-change](../roadmap/01-motion-linear-systems.md#motion-change)
- 当前目的：从运动或受力描述建立简单动力学模型，并用解析关系、守恒量和数值结果互相验证。
- 当前模式：`work`。基线诊断已经通过[阶段检查点](../checkpoints/stages/2026-09-02-baseline-diagnostic.md)；当前先取得 `MC-02` 的无提示独立证据，并在复核队列中保留到期的 `MC-04` 延迟复核。
- 学习单为 `reviewed` 不等于阶段通过；`motion-change` 仍需满足全部退出目标并完成自身退出审计。

## 当前阶段目标状态

| target_id | state | evidence | unmet |
|---|---|---|---|
| MC-01 | not_started | none | 基线中的导数样本不自动升级为运动阶段独立证据；需连接非匀速运动的函数、图像、导数与积分意义 |
| MC-02 | guided | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 受力、稳定状态和边界检查在反馈后完成；需换新运动情境无提示建模后才能升级为 `independent` |
| MC-03 | not_started | none | 尚未在同一新问题中独立比较功—能量或动量方法及其适用条件 |
| MC-04 | independent | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 已独立完成 NumPy、绘图和误差解释；到期的延迟复核与真正的新模型迁移尚未完成 |
| MC-05 | not_started | none | 尚未在新情境中综合完成模型、量纲、数量级、初值和极限检查，也没有延迟复核证据 |

## 合法的并行学习线

| stage_id | target_ids | state | evidence | unmet |
|---|---|---|---|---|
| linear-systems | LS-03 | guided | [线性阻力学习单](../sessions/2026/08/2026-08-26-linear-drag-velocity.md) | 只形成使用方法框架完成的标量一阶演化证据；尚未覆盖二阶方程组改写、`solve_ivp`、无提示重做和迁移 |

这条并行线只积累真实证据，不改变当前焦点，也不能在缺少自身退出审计和通过检查点时提前完成阶段。

## 关键能力复核队列

| target_id | due | task | status |
|---|---|---|---|
| MC-04 | 2026-09-02 至 2026-09-09 | 无提示重做一次解析—数值交叉验证，并改用不同模型或表示方式；只改变参数不算迁移 | pending |
| LS-03 | 取得无提示独立证据后 7～14 天 | 在新的物理情境中独立完成二阶方程到一阶方程组的改写、数值演化和误差检查 | not_ready |

## 已验证成果

- 基线九个目标均已取得实际样本并通过[综合退出评估](../sessions/2026/09/2026-09-02-baseline-exit-assessment.md)复核；[基线阶段检查点](../checkpoints/stages/2026-09-02-baseline-diagnostic.md)已经通过。诊断完成只确定教学起点，不表示相关知识已经掌握。
- 综合评估确认二维运动、力分解、净功—动能核对较稳；对数反求、特征时间、指数积分、模型要素分类、数量级判断和短英文图注仍需正式教学。
- 在线性阻力任务中，学习者独立完成 NumPy 向量化计算、`np.gradient`、误差切片、两种步长比较和 Matplotlib 分图，形成 `MC-04: independent` 证据。
- 受力与稳定性分析、偏离量变换和一阶方程推导已经发生有效学习，但因使用了方法提示，分别只登记为 `MC-02: guided` 与 `LS-03: guided`。

## 待解决问题

- `MC-01`、`MC-03`、`MC-05` 尚未开始形成正式证据，`MC-02` 仍缺无提示等价任务。
- `MC-04` 的 7～14 天延迟复核窗口已经开始；后续必须使用简谐运动这一新模型完成解析—数值交叉验证，只换线性阻力参数不算迁移。由于 `MC-04` 已达到当前最低证据，它不能单独成为唯一下一任务。
- 对数、指数积分、模型要素和英文等基线薄弱点嵌入运动阶段具体任务教学，不单独重开基线阶段。
- `LS-03` 尚无无提示二阶方程组改写和 `solve_ivp` 证据，延迟复核也尚未就绪。

## 唯一下一学习任务

- stage_id: motion-change
- activity: assessment
- target_ids: MC-02
- task: 创建一份新的斜面滑块无提示建模评估。由学习者独立画出或文字说明受力，明确方向约定、接触约束、参数、单位、初始条件和停止条件，建立含重力分量、支持力与动摩擦的运动方程，并检查零摩擦与临界接触等边界；除澄清题意外不提供方法帮助。

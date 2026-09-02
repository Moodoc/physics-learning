---
stage_id: baseline-diagnostic
contract_version: 1
completed_on: 2026-09-02
decision: passed
---

# 阶段通过检查点：基线诊断

## 逐目标证据

| target_id | evidence_level | evidence_files | independence_or_transfer |
|---|---|---|---|
| BD-01 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 能完成基本代数与含力分量的一步方程；计算工具、对数式和数量级检查需后续教学 |
| BD-02 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 能由正弦、余弦和正切处理二维分量与方向；不据此宣称三角函数已掌握 |
| BD-03 | sampled | [补充诊断](../../sessions/2026/09/2026-09-01-logarithm-integral-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 对数精确变形曾正确完成，但综合任务中的反求式错误；指数代入与极限可完成，比例、无量纲指数和特征时间解释不稳。教学前指数起点不可恢复 |
| BD-04 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 能由二维位置函数得到速度、加速度、单位和变化率解释；复杂情境仍需正式教学 |
| BD-05 | sampled | [补充诊断](../../sessions/2026/09/2026-09-01-logarithm-integral-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 原始诊断中能完成定积分与累计量解释；综合任务仍懂面积、上下限和单位，但指数原函数提取不稳定 |
| BD-06 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 能处理二维运动、力分解、净功和动能交叉检查；位置向量术语与数量级判断需巩固 |
| BD-07 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 熟悉后端 Python，能够写 NumPy 数组、`np.gradient` 和 Matplotlib 骨架；运行验证、参数错误传播及坐标轴单位仍需关注 |
| BD-08 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 有变量、初值和假设意识，但参数、派生量、直接测量量与输出量的分类尚不稳定 |
| BD-09 | sampled | [第一次基线诊断](../../sessions/2026/08/2026-08-25-baseline-diagnostic.md)、[综合退出评估](../../sessions/2026/09/2026-09-02-baseline-exit-assessment.md) | 能借部分语境识别短英文材料，但运动、衰减比例和模型假设的完整复述不稳定；后续保持短图注级输入 |

## 独立性与迁移说明

- 综合退出任务使用新的二维巡检车与衰减信标情境，九个目标均由学习者先独立作答。
- AI 只在任务一作答完成后澄清“此时”的时间指代和位置向量术语，没有在取样前提供方法提示、公式框架或答案。
- 基线目标的 `sampled` 只表示已获得真实样本和可执行起点结论，不升级为 `independent` 或“已掌握”。
- `BD-03` 的指数内容在 2026-08-26 已接受教学；本次只能复核教学后当前水平，教学前指数起点不可恢复。

## 非阻断问题

- 对数反求、比例衰减、无量纲指数和特征时间的物理意义需要正式教学。
- 指数函数积分当前提取不稳定；科学 Python 的运行验证、单位标注和参数错误传播需要继续训练。
- 变量、参数、派生量、测量量与输出量的区分，以及短英文图注复述，需要在后续物理任务中持续练习。
- 上述问题定义后续教学起点，不影响基线阶段“完成取样并形成起点结论”的退出标准。

## 解锁结果

- 基线诊断阶段通过，当前焦点迁移到 `motion-change`。
- `linear-systems` 保留为合法并行学习线；既有并行证据不因本检查点自动升级。
- `MC-04` 的简谐运动解析—数值延迟复核继续保留在复核队列；唯一下一任务指向尚未满足的 `MC-02` 无提示建模评估。本检查点不替代运动与变化阶段自身的退出审计。

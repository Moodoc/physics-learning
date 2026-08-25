# 物理学习项目

这是一个与 AI 协作的物理学习工作区。目标是在约 18 个月、每周约 8 小时的节奏下，以物理问题牵引数学和 Python 建模，在达到具体能力门槛后进入量子与统计基础，并完成三个方向的试学，最终选择一个主方向和一个辅助方向。

路线采用螺旋并行模式：数学工具与对应的物理问题一起学习，量子直觉可以提前预览，但正式量子训练和量子统计仍受明确先修门槛约束。

## 从哪里开始

1. 查看[学习者档案](state/learner-profile.md)，确认长期基础和约束。
2. 查看[当前状态](state/current.md)，只关注当前阶段和下一步。
3. 按[路线总览](roadmap/index.md)进入当前阶段文档。
4. 告诉 AI“安排今天的学习内容”，AI 会生成约 90 分钟的学习单。
5. 完成其中的计算、推导或代码后，把结果交给 AI 批阅。

## 学习记录如何形成

- 每次学习只维护一份 `sessions/YYYY/MM/YYYY-MM-DD-<topic>.md`。
- 学习内容、你的结果、AI 批阅和下一步都写回同一文件。
- 跨学习单的进展只汇总到 `state/current.md`，不重复维护日报、周报和月报。
- 可运行程序、图像和较完整的实验成果进入 `projects/`，由对应学习单链接。

## 路线文件

- [总览与推进规则](roadmap/index.md)
- [基线诊断、运动与线性系统](roadmap/01-motion-linear-systems.md)
- [场与波](roadmap/02-fields-waves.md)
- [概率、热与量子](roadmap/03-thermal-quantum.md)
- [三方向试学](roadmap/04-direction-trials.md)
- [选定方向后的衔接](roadmap/05-post-selection.md)

路线按能力门槛推进，周数只是建议节奏。18 个月结束时的目标是完成方向选择；论文拆解与简化复现属于下一周期。

## 项目维护

创建或重组项目文档时，遵循[文档组织与长度规范](docs/document-conventions.md)。规范检查可通过 `pwsh -NoProfile -File scripts/check-docs.ps1` 执行。

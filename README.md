# 物理学习项目

这是一个与 AI 协作的物理学习工作区。目标是在约 18 个月、每周约 8 小时的建议节奏下，以物理问题牵引数学和 Python 建模，完成必修阶段、量子信息、凝聚态和光学三个方向的代表性小项目，依据真实证据选择主方向与辅助方向，并用近期综合建模任务完成全路线终审。

路线的终点定位是“系统性物理入门和科研方向试学准备”：能够独立建立并验证典型简单物理模型，使用必要的数学和 Python 检查单位、数量级、边界与数值误差，并完成三方向试学。它不等同于完整物理本科培养，也不宣称已经具备独立科研能力。

路线采用螺旋并行模式：数学工具与对应的物理问题一起学习，无依赖的学习线可以并行，但依赖阶段不能绕过能力门槛。学习单完成批阅不代表能力已验证；阶段只有通过退出审计并形成通过检查点后才算完成。

## 从哪里开始

1. 查看[学习者档案](state/learner-profile.md)，确认长期基础和约束。
2. 查看[当前执行板](state/current.md)，只关注焦点阶段、合法并行线和唯一下一任务。
3. 按[路线总览](roadmap/index.md)进入当前阶段契约。
4. 告诉 AI“开始学习”或“继续学习”，AI 会先核对阶段与证据，再安排下一份约 90 分钟的学习单。
5. 完成其中的计算、推导或代码后，把结果交给 AI 批阅。

## 课程大纲

- [课程导航与使用说明](curriculum/index.md)
- [全路线课程与单元](curriculum/course-units.md)：每个单元的问题、目标、知识、前置与练习产出。
- [前 4 周的 12 次课](curriculum/first-four-weeks.md)：运动、线性代数与计算课程的起步衔接。

大纲用于备课和了解课程结构；实际学习仍从当前执行板的唯一下一任务进入。

## 学习记录如何形成

- 每次学习只维护一份[学习单](sessions/)，路径为 `sessions/YYYY/MM/YYYY-MM-DD-<topic>.md`。
- 学习内容、你的结果、AI 批阅和下一步都写回同一文件。
- 跨学习单的进展只汇总到[当前执行板](state/current.md)，不重复维护日报、周报和月报。
- 可运行程序、图像和较完整的实验成果进入[项目目录](projects/)，由对应学习单链接。
- 学习单从[学习单模板](templates/learning-session.md)创建；阶段只有通过时才按[阶段检查点模板](templates/stage-checkpoint.md)在 `checkpoints/stages/` 建立记录。

## 生命周期与治理

- [学习生命周期](.agents/skills/learning-lifecycle/SKILL.md)：选择下一任务、登记证据、执行退出审计和阶段迁移。
- [文档治理](.agents/skills/document-governance/SKILL.md)：约束 Markdown 的职责、结构、命名与链接。
- [Git 学习检查点](.agents/skills/git-learning-checkpoint/SKILL.md)：在成果完整且检查通过后创建范围明确的本地提交。

## 路线文件

- [总览与推进规则](roadmap/index.md)
- [基线诊断、运动与线性系统](roadmap/01-motion-linear-systems.md)
- [场与波](roadmap/02-fields-waves.md)
- [概率、热与量子](roadmap/03-thermal-quantum.md)
- [三方向试学](roadmap/04-direction-trials.md)
- [选定方向后的衔接](roadmap/05-post-selection.md)

路线按能力门槛推进，周数只是建议节奏。只有必修阶段检查点、三个试学项目、方向选择和近期综合建模任务全部通过，才算完成 18 个月路线；选定方向后的论文拆解与简化复现属于下一周期。

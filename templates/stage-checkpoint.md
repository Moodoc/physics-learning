---
stage_id: stage-id
contract_version: 1
completed_on: YYYY-MM-DD
decision: passed
---

# 阶段通过检查点：阶段名称

> 只有阶段退出审计通过时才实例化本模板。未通过时更新 `state/current.md`，不创建检查点。复制到 `checkpoints/stages/` 后，必须按目标文件位置重新计算 `evidence_files` 的相对路径（通常从 `../sessions/` 改为 `../../sessions/`），不得原样保留示例路径。

## 逐目标证据

| target_id | evidence_level | evidence_files | independence_or_transfer |
|---|---|---|---|
| TARGET-01 | independent | [示例学习单](../sessions/2026/08/2026-08-25-baseline-diagnostic.md) | 待填写独立、延迟复核或迁移说明 |

## 独立性与迁移说明

- 待填写独立完成、延迟复核或新情境迁移的具体证据。

## 非阻断问题

- 无；或记录不影响本阶段通过、但需后续关注的问题。

## 解锁结果

- 待填写本检查点解锁的阶段或活动。

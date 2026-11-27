# AGENTS.md — {{PROJECT}} 项目管理仓

本文件管理**项目级 SDLC（外环）**。服务仓的 AI 执行由各服务仓自己的 `AGENTS.md` 管理。

## 1. 三环模型

- **外环（本仓）**：项目级完整 SDLC —— `00 constitution → 01 intent → 02 spec → 03 plan → 04 build → 05 test → 06 deploy → 07 maintain`。
- **内环（服务仓）**：每个服务仓的 AI 真实执行，commit 时采集并上传报告到 `execution/`。
- **沉淀环（本仓 knowledge/）**：把执行事实蒸馏为约束/技能/教训/context；**AI 只产 candidate，policy owner 人工签核才 active**。

## 2. 每阶段必读

| 阶段 | 读 | 写 | 门禁 |
|---|---|---|---|
| 00 constitution | 本文件 | `loop/00-constitution.md` | 架构师/项目负责人签署 |
| 01 intent | constitution | `loop/01-intent/INT-*/intent.md` | 客户/PM 接受 |
| 02 spec | intent | `loop/02-spec/REQ-*/spec.md` + clarify 问题清单 | PM+架构师签署 |
| 03 plan | spec | `loop/03-plan/PLAN-*/plan.md` + 服务拆分 | 技术负责人接受 |
| 04 build | plan | `loop/04-build/services.json` + 服务仓 | 每服务 PR code owner |
| 05 test | spec/plan | `loop/05-test/` 计划与矩阵 | QA 门禁 |
| 06 deploy | test | `loop/06-deploy/` 发布记录 | 发布经理授权 |
| 07 maintain | 监控/事故 | `loop/07-maintain/` → 新 intent | 值班分诊 |

## 3. 会话协议

0. 确保护栏已启用：`bash scripts/install-hooks.sh`（幂等；Claude Code 在 SessionStart 自动执行）。
1. 先读本文件 + `loop/README.md` + 当前阶段产物。
2. 明确当前阶段与外环任务，**不要越过人类门禁**。
3. 产出物写入对应 `loop/` 阶段目录，`draft` 状态由人改为 `accepted`。
4. 结束前：更新 `README.md`/`wiki/` 相关摘要（或运行 analyzer）。
5. **不写入** `execution/`（那是服务仓采集器写入的 append-only 事实）。

## 4. 硬规则

- 不开新服务不登记 `services.json`；不登记不算存在。
- 项目级约束/技能变更：只写 `knowledge/proposals/`，**不得**直接改 `knowledge/pack.json` 的 active 条目。
- 不把 secrets / PII 写进任何 artifacts。
- 门禁 owner 不清时停下询问。

## 提交信息

`[<姓名>] #<卡号> <类型>: <概述>`；无卡号用 `#N/A`；AI 生成的代码用 `[AI-Agent]`。
例：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`

## AI-first

任何操作、改进、知识都必须提供 AI 可调用入口：CLI/API + 结构化输出（`--json`）+ AGENTS/skill 说明；
网页或人工流程只能是补充。只有人类入口的功能视为未完成。

## 债务与复盘

- 延期/受阻/复盘行动一律登记债务：`bash scripts/debt.sh add ...`（kind/owner/priority/due 必填）。
- AI 可以 add/note/start；close/drop 需要证据或人类确认。
- 复盘按 `loop/07-maintain/retro-template.md`：每个 finding 必须落成 rule/check/test 或债务。
- 签核前先跑 `bash scripts/review-proposals.sh .`，AI 建议仅供参考，人工用 `signoff.py` 签核或驳回；
  驳回后 proposal 是 `status=rejected` 墓碑，不会被 analyzer 重建，也不能再 promote。
- deterministic 签核会进 `loop/04-build/gates/queue.json`：AI 用 `gate-queue.sh list/claim/done` 领取并关闭，
  `done` 必须带门禁证据；实现只写一份（control-plane/guardrails），用 `sync-project-gates.sh` 下发。
- `validate-project.sh` 默认对"deterministic 无门禁证据"告警；`--strict` 时失败（用于发布/CI）。

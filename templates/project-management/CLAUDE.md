# CLAUDE.md — {{PROJECT}} 项目管理仓（快速参考）

> 完整规则见 `AGENTS.md`。本文件是 Claude Code / 其他 agent 的快速入口。

## 这是什么
项目控制平面 + 实时 wiki：`loop/`（外环 SDLC）、`execution/`（内环事实）、`knowledge/`（沉淀环）、`wiki/`（生成视图）。

## 常用命令（路径按实际调整）
- 启用护栏（clone 后首次）：`bash scripts/install-hooks.sh`（幂等）
- 分析报告：`bash <framework>/scripts/analyze-reports.sh .`
- 校验：`bash <framework>/scripts/validate-project.sh .`

## 约定
- 外环产物进 `loop/<阶段>/`，状态 `draft → accepted`。
- `execution/` 只追加、不手改（采集器写入）。
- `knowledge/pack.json` 的 active 条目只能人工签核后更新；AI 只写 `knowledge/proposals/`。
- 门禁：constitution/intent/spec/plan/build/test/deploy/maintain 各自有人类 owner。
- 提交信息：`[<姓名>] #<卡号> <类型>: <概述>`；无卡号 `#N/A`；AI 生成用 `[AI-Agent]`。
- 债务：`bash scripts/debt.sh due|add|list`（AI 可登记/备注；关闭需证据或人）
- 签核/驳回：`python3 scripts/signoff.py`；AI 预判 `bash scripts/review-proposals.sh .`；
  驳回 CLI `bash scripts/review-proposals.sh reject <id> --owner <你>`；不得自行 promote 或驳回

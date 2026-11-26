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

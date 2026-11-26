# Plan：<一句话标题>（来自 intent.md <日期>，spec.md <日期>）

状态：draft。变更目录：`intent/<folder>/`。

## 会改动的文件

精确路径，一行一个，包含测试（`src/test`、`src/itest`）、网关路由、配置
（infra 仓 `config/` 或独立 config 仓）、以及必须重新生成而不是手改的生成代码。
注明需要同步的 infra 仓变更（Flux/Kustomize）。

## 工作顺序

1. <工作项 —— 可独立验证，例如"在现有鉴权后加状态端点">
2. <工作项 —— 例如"面板对接该端点">
3. <工作项 —— 例如"接网关路由 + 配置源">

按依赖排序：共享文件的任务在同一 session 顺序执行；独立任务可并行 worktree
（spec-kit `tasks.md` 思路）。

## 风险

可能破坏什么；限流；别人依赖的契约；哪一步最危险及原因。

## 证明

定义"完成"的可量化检查：

- `<测试类>` 全部通过。
- `<端点>` 返回 200 且含 `<字段>`。
- 截图与已批准的 mock 一致。
- `bash scripts/app-verify.sh all` 绿。

## 部署 / GitOps

变更如何到达 EKS：镜像构建 → Flux reconcile（dev）→ tag-bump PR（uat/prod）。
需要的 Config Server 或 infra 仓改动。

## 自问（接受前回答）

- 这次变更可能破坏什么？
- 哪一步最危险？
- 明确不做什么，备选方案是什么？

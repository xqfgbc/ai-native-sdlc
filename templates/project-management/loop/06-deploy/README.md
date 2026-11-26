# 06-deploy — 上线

- `releases/<version>.md`：发布记录（变更内容、审批人、回滚演练结果）。
- 门禁：**发布经理授权**（生产）；GitOps（Flux）reconcile，CI 不直接 `kubectl apply`。
- 环境：dev / uat / prod；镜像 tag 由 Flux ImagePolicy/ImageUpdateAutomation 驱动。
- 回滚：预批准 runbook（`docs/runbook-rollback-deploy.md` 或服务仓等价物）。

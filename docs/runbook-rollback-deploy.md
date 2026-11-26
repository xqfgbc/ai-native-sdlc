# Runbook：rollback-deploy（预批准）

**预批准人：** <发布经理姓名>。**触发：** 维护环在 3σ 时（`config/bands.yaml`，路由 `runbook:rollback-deploy`）或发布经理。
**范围：** 仅回滚——本 runbook 不做前向修复。

## 触发条件

某个被监控指标（如 `post_deploy_5xx_rate`）越过 3σ，且检测窗口内有部署。

## 步骤

1. 找到受影响服务的**最后已知良好版本**（image tag / git revision，从 infra 仓部署历史）。
2. **只回滚受影响的服务**。EKS + Flux 下：
   - **优先**：在 infra 仓 revert 该服务的 tag-bump PR，Flux 会 reconcile 回去
     （保持 Git 为真相源）。
   - **备选**：平台团队执行 `kubectl rollout undo deployment/<service>`。
3. 验证恢复：`/actuator/health/readiness` 为 `UP`，指标回到带内（Prometheus/CloudWatch）。
4. 把发现写成新 intent（`incident-to-intent` 技能），并为这类事故新增一条 eval。

## 约束

- 回滚**绝不**顺带做数据库 drop/迁移。
- 只回滚；前向修复走正常评审门禁。
- 每次调用本 runbook 都带时间戳记录。

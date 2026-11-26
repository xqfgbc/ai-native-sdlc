# {{SERVICE}} — infrastructure (Terraform + Helm + Flux GitOps)

**目的**：{{SERVICE}} 是项目的集群与部署真相源：Terraform 管 EKS / RDS PostgreSQL / ECR / IAM，
Helm/Kustomize 与 Flux 管工作负载，`environments/{dev,uat,prod}` 是环境 overlay。
**集群里的状态以本仓为准**，不要在控制台手改。

## 本地校验与调试（没有“启动”）

本仓不是运行时应用。本地做的是**校验与渲染**，不是启动：

```bash
terraform fmt -check -recursive      # 目录接入后（当前模板尚未包含 terraform/）
terraform validate                   # 需要先 terraform init
kustomize build environments/dev     # 渲染 dev overlay（或 kubectl kustomize）
flux build kustomization apps --path apps/gateway   # 本地渲染 Flux 资源（可选）
bash scripts/app-verify.sh smoke     # 非 Java/Node 栈会提示未知栈；以本节的 CLI 校验为准
```

- **不要在本仓执行 `terraform apply`**：生产/环境变更必须走 PR + 发布经理授权。
- 本地要连集群时用只读 context；不要在本地改集群状态。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，其他 agent 见第 0 步。
2. **变更循环**：`intent → spec → plan → build → test → deploy → maintain`；没有接受的 plan 不写代码。
3. **影响面**：任何架构/环境变更记录 CHG（变更说明、影响服务、回滚方式），并回灌控制平面仓
   `knowledge/context`；生产 overlay 需要发布经理授权（`production-gate`）。
4. **验证与提交**：至少 `terraform fmt/validate`（接入后）与 `kustomize build` 目标 overlay；
   消息遵循 `AGENTS.md §6`；pre-commit / commit-msg / pre-push 自动执行；`release*` 分支走 PR。
5. **采集与会话**：commit 后 `bash .sdlc/collect.sh`；会话结束写 `sdlc/session-log/`。
6. **部署**：推送到本仓 → Flux reconcile 到 EKS；镜像 tag 由 ImagePolicy 跟进（dev），
   uat/prod 走 tag-bump PR。接入 Terraform/Flux bootstrap 后，把真实集群与云账号信息补到本 README。

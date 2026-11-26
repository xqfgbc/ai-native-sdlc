# infra — infrastructure service (Terraform + Helm + Flux GitOps)

基础设施仓：**Terraform（EKS/RDS/ECR）+ Helm charts + Flux CD manifests**，以及 dev/uat/prod overlay。

内容已从旧单仓 `infra/` 迁入（`environments/`、`apps/`、`config/`、`image-automation.yaml`）。

## 规划结构
```
terraform/           # EKS / RDS PostgreSQL / ECR / IAM
helm/                # 各服务 chart（可选，或用 kustomize）
clusters/            # Flux 引导
environments/{dev,uat,prod}/   # kustomize overlay（镜像 tag 由 Flux ImagePolicy 驱动）
.sdlc/config.json    # 服务元数据 + managementRepo
sdlc/session-log/    # AI 会话记录
```

## 内环
变更循环 + 会话协议 + commit 采集；架构变更（CHG）回灌到管理仓 `06-technical`/`knowledge/context`。

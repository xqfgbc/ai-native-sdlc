# 仓库拓扑 — 多仓工厂 + 双仓 GitOps

本框架把代码分成五类仓库：

1. **框架仓（本仓）** —— 模板 + 生成器 + 公共 skills/hooks，不承载业务代码。
2. **项目管理仓**（`scripts/new-project.sh` 生成）—— 控制平面 + 实时 wiki + 执行事实 + 认知沉淀。
3. **服务仓**（`scripts/new-service-repo.sh` 生成）—— 每类服务一个独立仓，可独立构建；6 类：`infra`、`gateway`、`config-server`、`configuration-data`、`business`、`frontend-vue`。
4. **infra 仓**（`infra` 模板生成）—— Terraform + Helm + Flux CD，GitOps 真相源。
5. **配置数据仓**（`configuration-data` 模板生成，按环境分仓）—— Spring Cloud Config 的 git 后端：
   `<project>-prod-configuration-data`（生产）、`<project>-devops-configuration-data`（非生产）。

## 仓库关系

```
框架仓                         管理仓                         服务仓（N 个）                infra 仓
templates/  scripts/   ──生成──► loop/ execution/  ◄──采集报告──  business/ gateway/  ──部署──► flux/ terraform/
.agents/ hooks/                 knowledge/ wiki/             config-server/ web/            helm/
                                                            配置数据仓 prod / devops
```

- **管理仓**：项目级 SDLC（外环）+ 执行事实（内环 `execution/`）+ 认知（沉淀环 `knowledge/`）+ 生成视图（`wiki/`）。
- **服务仓**：AI 在这里执行；每次 commit 由 `.sdlc/collect.sh` 采集并上传管理仓。
- **infra 仓**：Flux reconciles 到 EKS；Terraform 管 EKS/RDS/ECR。
- **配置数据仓**：config-server 的 `git` 后端，按环境分仓；生产仓变更需发布经理授权。

## 服务仓内容

```
<service>/
  service.json          类型、端口、cognitionPack 版本、trustLevel
  build.gradle.kts      （Java 类）独立构建；platform/ + gradle wrapper + checkstyle
  src/                  main / test / itest
  Dockerfile            镜像构建
  scripts/app-verify.sh 统一验证 CLI
  feature-map.md        功能 → 需求 → 验证 → 状态
  findings/             scanner 队列（只追加）
  .sdlc/collect.sh      采集器；config.json 记录 managementRepo/lastCollectedSha
  .agents/skills/       多 agent 规范源
  .github/workflows/collect.yml   push 时采集并上传
```

## infra 仓内容

```
infra/
  environments/{dev,uat,prod}/   Flux Kustomize overlay
  apps/                          每应用 Kustomization
  config/                        Spring Cloud Config source（<service>.yml / <service>-<env>.yml）
  image-automation.yaml          Flux ImagePolicy / ImageUpdateAutomation
  clusters/<cluster>/flux-system (bootstrap)
```

## 它们如何连接

1. 服务仓 commit → `.sdlc/collect.sh` → 报告到管理仓 `execution/<stage>/<service>/reports/<sha>.json`。
2. 管理仓 `analyze-reports.sh` → `wiki/`、`knowledge/proposals/`、`loop/05-test/results.md`、`wiki/dora.md`。
3. 服务仓镜像 → ECR → Flux ImagePolicy 自动跟 `sha-*`（dev）；uat/prod 走 infra 仓 tag-bump PR，
   prod 额外需要发布经理授权（`production-gate` hook）。
4. `config-server` 用 `git` backend 读对应环境的配置数据仓（生产 → `<project>-prod-configuration-data`，
   非生产 → `<project>-devops-configuration-data`），把配置分发给各服务。

## Bootstrap 清单（平台团队，一次性）

1. 用 `infra` 模板建 infra 仓；`flux bootstrap github … --read-write-key`。
2. 建 ECR 仓库；在服务仓配 `AWS_CI_ROLE_ARN` + OIDC。
3. 置备 RDS PostgreSQL；凭证放 AWS Secrets Manager；infra 仓 `infrastructure/` 加 ESO `ExternalSecret` + `SecretStore`。
4. 为服务加 IRSA 角色（ECR pull、Config Server、RDS IAM auth）。
5. 用 `configuration-data` 模板建 `prod` / `devops` 两个配置数据仓，把 `config-server` 的 `git` profile
   分别指向对应环境的仓。

各步骤的护栏见 `gitops-deploy` 与 `aws-postgres` 技能。

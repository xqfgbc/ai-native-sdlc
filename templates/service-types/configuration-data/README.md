# {{SERVICE}} — Spring Cloud Config 配置数据仓

Spring Cloud Config 的 **git 后端**，按环境分仓：

| 环境 | 仓库 |
|---|---|
| 非生产（dev / uat） | `{{PROJECT}}-devops-configuration-data` |
| 生产 | `{{PROJECT}}-prod-configuration-data` |

`{{PROJECT}}-config-server` 用 `git` profile 指向本仓；本地开发用 config-server 自带的
`native` profile（`config/` 目录），不读本仓。

## 配置命名（Spring Cloud Config 约定）

- `application.yml` / `application-<profile>.yml` —— 所有服务共享。
- `<service>.yml` / `<service>-<env>.yml` —— 按服务、按环境覆盖。

## 变更规则

- 配置变更走 PR；**生产仓需要发布经理授权**（`production-gate`）。
- 不写 secrets：用 AWS Secrets Manager / SSM 引用。
- 变更后在 commit message 或 PR 里说明影响面，并回灌管理仓 `knowledge/context`。

## 内环

commit 触发 `.sdlc/collect.sh`（增量 facts + AI 候选认知）→ 上传管理仓。

# {{SERVICE}} — Spring Cloud Config 配置数据仓

**目的**：{{SERVICE}} 是 Spring Cloud Config 的 **git 后端**，按环境分仓：

| 环境 | 仓库 |
|---|---|
| 非生产（dev / uat） | `{{PROJECT}}-devops-configuration-data` |
| 生产 | `{{PROJECT}}-prod-configuration-data` |

本仓只放**配置内容**；配置分发能力在 `{{PROJECT}}-config-server`。

## 本地使用与调试（没有“启动”）

本仓不是运行时应用；本地用它给 config-server 提供配置：

```bash
# 方式一：config-server 用 native 直接读本目录
cd ../{{PROJECT}}-config-server
CONFIG_SEARCH_LOCATIONS=file:/abs/path/to/{{SERVICE}} ./gradlew bootRun
curl -fsS http://localhost:8888/<application>/<profile>

# 方式二：config-server 用 git 后端（本仓是 git repo）
./gradlew bootRun --args='--spring.profiles.active=git --spring.cloud.config.server.git.uri=file:///abs/path/to/{{SERVICE}}'

# 本地语法检查
yq '.' application.yml >/dev/null          # 有 yq 时
```

配置命名（Spring Cloud Config 约定）：

- `application.yml` / `application-<profile>.yml` —— 所有服务共享。
- `<service>.yml` / `<service>-<env>.yml` —— 按服务、按环境覆盖。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，其他 agent 见第 0 步。
2. **只改配置**：不写 secrets（用 AWS Secrets Manager / SSM 引用）；不把本仓当代码仓用。
3. **生产仓**：变更需要发布经理授权（`production-gate`）；在 commit/PR 里写清影响面，
   并回灌控制平面仓 `knowledge/context`。
4. **验证与提交**：改完至少做一次 YAML 解析/`config-server` 拉取验证；消息遵循 `AGENTS.md §6`；
   pre-commit / commit-msg / pre-push 自动执行；`release*` 分支走 PR。
5. **采集与会话**：commit 后 `bash .sdlc/collect.sh`；会话结束写 `sdlc/session-log/`。
6. **生效方式**：config-server 从本仓拉取；滚动重启或 `/actuator/refresh`（spring-cloud-starter-config）
   后生效。生产变更按发布流程执行。

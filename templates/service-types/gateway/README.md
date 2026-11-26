# {{SERVICE}} — Spring Cloud Gateway (Spring Boot 4.1.3 / JDK 21)

**目的**：{{SERVICE}} 是项目统一入口网关，负责路由 `Path=/api/<base>/**` → `lb://<service>`、
统一鉴权、超时与限流。路由表是跨服务契约：变更必须回灌控制平面仓 `knowledge/context`。

## 本地启动与调试

前置：JDK 21。`local` profile 关闭 Config Server 与 K8s discovery；路由默认指向 compose 网络地址
（`http://reference-service:8081`），单机调试可改成 `http://localhost:<port>`。

```bash
./gradlew bootRun --args='--spring.profiles.active=local'   # http://localhost:8080
curl -fsS http://localhost:8080/actuator/health
bash scripts/app-verify.sh smoke
```

- 本地路由：`src/main/resources/application-local.yml`。
- 端口：默认 8080。
- 检查：`./gradlew test`、`checkstyleMain checkstyleTest`、`check`（itest 需 Docker）。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，其他 agent 见第 0 步。
2. **变更循环**：`intent → spec → plan → build → test → deploy → maintain`；没有接受的 plan 不写代码。
   加载 `.agents/skills/`（spring-service-conventions、resiliency-review、secure-api-review、verify-work …）。
3. **网关约定**：路由用 `lb://<service>` 与服务名一致；出站超时显式配置；不要在 WebFlux 过滤器里 `.block()`；
   鉴权默认拒绝，只放行 `/actuator/health/**` 与声明的匿名路由。
4. **路由变更**：同步更新 `<project>-devops-configuration-data` 的 `gateway.yml`（生产覆盖写 prod 数据仓），
   并回灌 `knowledge/context`。
5. **验证与提交**：`bash scripts/app-verify.sh all`（itest 需 Docker）；消息遵循 `AGENTS.md §6`；
   pre-commit / commit-msg / pre-push 自动执行；`release*` 分支走 PR，其他分支直推前必须过验证。
6. **采集与会话**：commit 后 `bash .sdlc/collect.sh`；会话结束写 `sdlc/session-log/`。
7. **部署**：镜像 → ECR → Flux（`{{PROJECT}}-aws-infra`）跟 dev；uat/prod 走 infra 仓 tag-bump PR，
   生产需发布经理授权。当前仓库尚未接入 CI/ECR，接入后以 CI 为准。

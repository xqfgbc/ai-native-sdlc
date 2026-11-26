# {{SERVICE}} — business service (Spring Boot 4.1.3 / JDK 21)

**目的**：{{SERVICE}} 是项目的业务服务，负责 **（待填写）本项目拥有的数据、对外 API、依赖的上下游**。
以本仓 `AGENTS.md` 与控制平面仓 `loop/02-spec/REQ-*/spec.md` 为准，本段随 spec 更新。

当前是生成器脚手架：示例接口 `GET /api/hello`（`api/HelloController` → `core/HelloService`）。
实现第一个真实需求时替换它，并在 `feature-map.md` 登记“功能 → 需求 → 验证命令 → 状态”。

## 本地启动与调试

前置：JDK 21 + Podman。本地 `local` profile 使用 Podman 里的 PostgreSQL 17，Flyway 负责建表，
不连 Config Server、关闭 K8s discovery。

```bash
bash scripts/dev-db.sh up                                   # 幂等；首次会自动启动 podman machine
./gradlew bootRun --args='--spring.profiles.active=local'    # http://localhost:8081，Flyway 自动迁移
curl -fsS http://localhost:8081/actuator/health              # {"status":"UP"}
bash scripts/app-verify.sh smoke                             # 起服务并轮询 /actuator/health
```

- 端口：`SERVER_PORT`（默认 8081）；数据库：`DB_URL` / `DB_USERNAME` / `DB_PASSWORD`（默认 {{SERVICE}}/{{SERVICE}}/{{SERVICE}}）。
- 本地配置：`src/main/resources/application-local.yml`。
- itest 需要 Testcontainers 能连到 Podman：

```bash
SOCK=$(podman machine inspect <machine-name> --format '{{.ConnectionInfo.PodmanSocket.Path}}')
DOCKER_HOST="unix://$SOCK" TESTCONTAINERS_RYUK_DISABLED=true \
TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock ./gradlew check
```

检查：

```bash
./gradlew test                            # 单测 + ArchitectureTest
./gradlew checkstyleMain checkstyleTest   # 风格
./gradlew check                           # 含 src/itest（Testcontainers，需要 Docker/Podman 运行中）
bash scripts/app-verify.sh build|test|lint|itest|all|smoke
```

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`（本仓规则）。新 clone 的首个 Claude Code 会话会自动执行
   `scripts/install-hooks.sh`；其他 agent 按 `AGENTS.md` 第 0 步手动跑一次（幂等）。
2. **变更循环**：`intent → spec → plan → build → test → deploy → maintain`；没有接受的 plan 不写代码。
   按需加载 `.agents/skills/`（spring-service-conventions、spring-data-jpa、spring-testing、
   secure-api-review、resiliency-review、verify-work …），不要即兴发挥。
3. **开发约定**：构造器注入；金额用 `BigDecimal`；请求体 `@Valid`；错误用 RFC 9457 `ProblemDetail`；
   列表用 `PagedModel`；出站调用显式超时 + Resilience4j；禁止 field `@Autowired`、返回 JPA 实体、N+1、
   生产 `ddl-auto: update`。细节见 skills 与 `AGENTS.md`。
4. **链路追踪**：入站 W3C `traceparent` 自动提取，日志 correlation 带 `[service,traceId,spanId]`；
   出站必须使用自动配置的 `RestClient.Builder`（或 `WebClient.Builder`）构建客户端，traceparent 才会自动注入；
   不要手写 HTTP 客户端。已验证：入站 traceparent 被尊重、出站自动注入（`TracingPropagationIT`），
   日志 correlation 带 traceId/spanId。CloudWatch 走 OTLP→ADOT：AWS 环境设 `OTLP_TRACING_ENABLED=true` 与
   `MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT=<adot collector>`。
5. **验证后再说完成**：`bash scripts/app-verify.sh all`（itest 需 Docker/Podman）或至少 build+test+lint，
   把输出贴进结果；同步 `feature-map.md`。测试失败改代码，不改测试（bug 修复流程除外）。
6. **提交与门禁**：消息遵循 `AGENTS.md §6`（如 `feat(<slug>): add {{SERVICE}} lookup`）。
   `pre-commit`（secret / 受保护路径 / Boot4 违规）、`commit-msg`、`pre-push`（推送前 build+test+lint）
   会自动执行；`release*` 分支必须走 PR，其他分支可直推但必须先过验证。
7. **采集与会话**：commit 后运行 `bash .sdlc/collect.sh`，增量报告上传到控制平面仓 `execution/`；
   会话结束写 `sdlc/session-log/<YYYYMMDD-HHMM>.md`。
8. **部署**：`docker build` 镜像 → ECR → `{{PROJECT}}-aws-infra` 仓的 Flux ImagePolicy 跟进 dev；
   uat/prod 走 infra 仓 tag-bump PR，生产需要发布经理授权（`production-gate` hook）。
   当前仓库尚未接入 CI/ECR，接入后以 CI 结果为准。

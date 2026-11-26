# Spring Cloud AI-Native SDLC 框架（快速参考）

> 治理性指令见 `AGENTS.md`。本文件是 Claude Code / 其他 agent 的快速入口。

## 本仓库是什么

AI-Native SDLC 的**工厂/模板仓**，生成项目仓与服务仓，不承载业务代码：

- `templates/project-management/` → 管理仓（控制平面 + 实时 wiki）
- `templates/service-types/{infra,gateway,config-server,configuration-data,business,frontend-vue}/` → 6 类服务仓
- `scripts/new-project.sh` / `new-service-repo.sh` → 本地生成（不建远端仓）
- `scripts/collect.sh` / `analyze-reports.sh` / `validate-project.sh` → 采集/分析/校验闭环
- `scripts/selftest.sh` → 端到端自检
- `DESIGN.md` / `HANDOVER.md` / `DELIVERY.md` → 设计、交接、交付手册

框架自身的变更仍走 intent/spec/plan 循环；没有接受的 plan 不写代码。

## 框架仓验证（根目录没有 Gradle 工程）

- `bash scripts/selftest.sh` —— 应 **61 项全绿**
- `./scripts/validate-skills.sh` —— 应 **OK（19 skills / 8 agents）**
- `bash -n scripts/*.sh` —— shell 语法检查

## 在生成的服务仓里验证

- `bash scripts/app-verify.sh all`（或 `make verify`）—— build+test+lint+itest
- `bash scripts/app-verify.sh smoke`（或 `make smoke`）—— 起应用并探活 `/actuator/health`
- 等价：`make build/test/lint/itest` 或 `./gradlew assemble/test/check`

## 技术栈（normative）

- Java 21、Spring Boot **4.1.3**（最新 4.1.x；请求的 4.1.5 未发布）、Spring Cloud **2025.1.5**、Gradle（Kotlin DSL + version catalog）
- 发现：Kubernetes 原生（`spring-cloud-starter-kubernetes-client`），**不加 Eureka**
- 配置：Spring Cloud Config（config-server + client，`optional:configserver:`）
- 数据库：AWS RDS PostgreSQL（prod）/ H2（local）/ Testcontainers（itest）
- 部署：AWS EKS + Flux CD GitOps，dev/uat/prod
- Boot 4 改名：`spring-boot-starter-webmvc`（非 `-web`）、`@MockitoBean`（非 `@MockBean`）、
  网关 starter `spring-cloud-starter-gateway-server-webflux`

## 约定

- 构造器注入；不要 field `@Autowired`
- 金额用 `BigDecimal`，永不用 `double`
- 每个端点都有 `src/itest/java` 集成测试
- 请求体校验（`@Valid` / `@Validated` + jakarta.validation）
- 出站调用：显式超时 + Resilience4j 断路器 + 有界重试；阻塞调用用 `RestClient`（非 `RestTemplate`），声明式用 `@HttpExchange`
- 列表返回 `PagedModel`；错误用 RFC 9457 `ProblemDetail`；乐观锁冲突 409
- 服务类 `@Transactional(readOnly = true)`；写方法 `@Transactional`
- Testcontainers 用 `@ServiceConnection`（非 `@DynamicPropertySource`）
- 服务名 kebab-case；端口 config-server 8888、gateway 8080、业务 8081+
- 新服务在框架仓用 `scripts/new-service-repo.sh` 生成，不要手写模块
- 仓库命名由生成器强制：控制平面 `<project>-control-plane`、business/frontend-vue `<project>-<service>-management`、gateway
  `<project>-<usage>-gateway`、infra `<project>-<cloud>-infra`、config-server `<project>-config-server`、
  configuration-data `<project>-<prod|devops>-configuration-data`（`--allow-custom-name` 可绕过）

## 架构

- `config-server` —— 配置服务；本地 `config/` native，生产/非生产从 `<project>-prod-configuration-data` /
  `<project>-devops-configuration-data` 的 git 后端读取
- `gateway` —— Spring Cloud Gateway（WebFlux）；`Path=/api/<base>/**` → `lb://<service>`
- 业务服务 —— 独立服务仓，继承 platform BOM
- 部署 —— GitOps（infra 仓 Flux reconcile）；CI 只构建/测试/推 ECR
- 产物位置：`intent/`、`docs/`、`.agents/skills/`、`.claude/`/`.codex/`/`.opencode/`、
  `hooks/` + `.githooks/`、`evals/`、`config/bands.yaml`

## 常见错误

- 不要编辑 `build/`、`.gradle/`、生成的 schema 类
- `CLAUDE_FIX_TASK=1` 期间不要改 `src/test/`、`src/itest/`；先写失败测试并提交，再修代码
- 不要绕 BOM 加依赖（要加就在 PR 说明）
- 不要用 Hystrix；用 Resilience4j
- 不要硬编码 secrets，或写进提交的 `application.yml`
- 不要加 Eureka 或 Boot 3 的 starter 名
- Spring 坑：field `@Autowired`、private/自调用 `@Transactional`、返回 JPA 实体、N+1、
  `open-in-view: true`、生产 `ddl-auto: update`、无界 `findAll()`、缺 `@Valid`、无超时出站调用
- 确定性门禁：`hooks/spring-guard.sh`、生成的 `ArchitectureTest`、`scripts/check-endpoints.sh`、CI

## 验证你的工作

- 框架仓：`bash scripts/selftest.sh` + `./scripts/validate-skills.sh`
- 服务仓：`bash scripts/app-verify.sh all`（或 `make verify`）
- 全绿再报告完成，并粘贴输出；测试失败修代码，不修测试。

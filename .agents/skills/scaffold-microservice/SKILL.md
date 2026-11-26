---
name: scaffold-microservice
description: 生成一个新的 Spring Cloud 微服务仓（k8s 原生发现 / Config client / PostgreSQL 约定）。阶段 3c（Build）引入新服务时用。
---

# 生成微服务仓

阶段 3c（Build）。每次用同一方式生成，**不要手写模块结构**。
本项目是**多仓工厂**：在框架仓跑 `scripts/new-service-repo.sh` 生成独立服务仓。

## 步骤

1. 确认本次 `spec.md`/`plan.md` 需要新服务，并记录网关路由（`Path=/api/<base>/**` → `lb://<service>`）。
2. 在**框架仓**运行：

   ```bash
   scripts/new-service-repo.sh <type> <name> <management-repo> [target-dir] [--allow-custom-name]
   ```

   `type` ∈ `business | gateway | config-server | configuration-data | frontend-vue | infra`。
   **目录名由命名规则推导**（`<project>` = 管理仓名去掉 `-management`）：
   `business`/`frontend-vue` → `<project>-<service>-management`、`gateway` → `<project>-<usage>-gateway`、
   `infra` → `<project>-<cloud>-infra`、`config-server` → `<project>-config-server`、
   `configuration-data` → `<project>-<prod|devops>-configuration-data`。显式 `target-dir` 不符合规则会报错。它会：
   - 复制类型模板 + `_shared`（platform BOM / Gradle wrapper / checkstyle / Makefile）；
   - 渲染 `service.json`、`.sdlc/config.json`、`README.md`、`AGENTS.md`；
   - 复制 `.sdlc/collect.sh`、`scripts/app-verify.sh`、`scripts/autopilot-gate.sh`、`scripts/scan-findings.sh`；
   - 落地 `.agents/skills` + `.claude` 适配；
   - 播种 `feature-map.md`、`findings/inbox.md`；
   - 在管理仓 `loop/04-build/services.json` 登记（`trustLevel: L1`）。

3. 在服务仓里先自验：

   ```bash
   bash scripts/app-verify.sh all     # build+test+lint+itest
   ```

4. 网关路由：在 `<project>-devops-configuration-data` 仓的 `gateway.yml` 加 `Path=/api/<base>/**` → `lb://<name>`；生产覆盖写 `<project>-prod-configuration-data`。
5. 提交 scaffold，再按接受的 plan 实现行为（没有接受 plan 不 scaffold）。

## 约定

- 服务名 kebab-case；`business` 基础包 `com.example.app`（P1 固定；后续按服务名渲染）。
- 端口：config-server 8888、gateway 8080、业务 8081+。
- 金额 `BigDecimal`；仅构造器注入；不要 field `@Autowired`。

## 完成条件

`./gradlew assemble` 绿（`app-verify.sh build`）；服务出现在管理仓 `services.json`；`feature-map.md` 有初始条目。

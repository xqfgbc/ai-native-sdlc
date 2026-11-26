# Spec：<一句话标题>（来自 intent.md <YYYY-MM-DD>）

状态：draft。Intent：`intent/<folder>/intent.md`。

## 概述

一段话：要构建什么、为什么。

## 功能需求

编号、可测试的需求（FR-1、FR-2……）。

## 非功能需求

延迟、韧性（见 `resiliency-review`）、数据量、可用性。每条都要有数字或具名基线。

## 服务拓扑

- 新建或变更的服务（新服务走 `scaffold-microservice` / `new-service-repo.sh`？）。
- 同步 HTTP 还是异步事件；谁调用谁。
- 发现是 Kubernetes 原生（`lb://<service>`）；注明需要的新网关路由：
  `Path=/api/<base>/**` → `lb://<service>`。
- 配置：从 Spring Cloud Config 消费的新外部属性（config-server 的 `git` 后端，
  源在 infra 仓 `config/` 或独立 config 仓）。

## API 契约

每个端点：方法、路径、请求体、响应体、错误响应（ProblemDetail）、鉴权预期。
足够工程师不问就能实现。

## 数据模型变更

实体、表、迁移（Flyway/Liquibase —— 见 `aws-postgres`）；AWS RDS PostgreSQL 影响、
向后兼容说明、任何数据分级（PII）标记。

## 策略应用

编写本 spec 时应用的技能与约定（含版本）：
`spring-service-conventions`、`secure-api-review`、`resiliency-review`、`aws-postgres`、
`gitops-deploy`，以及任何品牌/UX 策略。spec、产生它的 prompt、生效的技能版本都进版本控制。

## 关注点（已标记）

每个关注点：冲突是什么、涉及哪条策略、由哪位具名 policy owner 解决。
这些解决后，工程才看到 spec。

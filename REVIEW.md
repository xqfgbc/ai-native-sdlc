# 评审策略

每个 PR 由 agent reviewer 执行本策略，人工 reviewer 在其上补充。
发现项按所属"遍"打标签。**发现项本身不批准也不阻塞 PR**——合并仍由分支保护要求的 code owner 批准决定。

## 三遍评审

先加载 `code-quality` 技能获取检查清单，然后跑三遍，并给每个发现项打上所属遍的标签：

- **正确性（Bugs）**：逻辑错误、边界破坏、隐性回归，以及 Spring 正确性：
  `@Transactional` 作用域/自调用、返回 JPA 实体、N+1、`open-in-view`、无界查询、
  缺 `@Version` 乐观锁、并发错误（`@Async`/`@Scheduled`、共享可变状态）。
- **安全（Security）**：注入风险、鉴权缺口（所有端点经网关；除 `/actuator/health` 外无匿名路由）、
  日志含 PII、代码含 secrets、缺输入校验、agentic 应用风险（不可信输入转发给下游 agent/tool — OWASP ASI01/ASI10）。
- **AI-first**：新操作/工具/知识必须同时提供 AI 可调用入口（CLI/API + 结构化输出 + AGENTS/skill 说明）；
  只有网页或纯人工入口的变更标 Important。
- **合规（Compliance）**：变更与本次 `spec.md`/`plan.md` 一致；遵守 `CLAUDE.md` 约定与
  `spring-service-conventions`、`spring-data-jpa`、`spring-testing` 技能；尊重生成的 `ArchitectureTest`；
  出站调用满足 `resiliency-review`；数据源变更满足 `aws-postgres`；部署变更遵循 `gitops-deploy`
  （GitOps，不 `kubectl apply`，生产由发布授权门控）。

## "Important" 的含义

会破坏行为、泄露数据或违反策略的发现项标为 **Important**；样式与命名是 nit。

## nit 上限

每次评审最多报 5 个 nit，其余只给数量汇总。

## 不要报

`build/` 下的生成物、生成的 schema 类、以及 CI 已经强制的东西（checkstyle、失败测试、`hooks/` 脚本）。

## 把发现回流

同一错误第二次被评审标出时，纠正要写进 `CLAUDE.md`（或 `.agents/skills/` 对应技能），作为评审的一部分。
评审也要指出某变更是否让 `CLAUDE.md` 或某个技能过时。

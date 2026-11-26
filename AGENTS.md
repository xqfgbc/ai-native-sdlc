# AGENTS.md — 项目级 agent 指令

**Spring Cloud AI-Native SDLC 框架**

本文件管理本仓库的每一个 AI 会话，无论由哪个 agent 驱动——Claude Code、Codex、opencode、
DeepSeek Harness，或任何遵守 `AGENTS.md` 的 agent。它定义你要跑的循环、要提交的产物、
不得越过的门禁、必须加载的技能。`CLAUDE.md` 是 day-one 快速参考。

---

## 0. 仓库定位：多仓工厂（先读）

本仓库是 AI-Native SDLC 的**工厂/模板仓**，不是业务项目：
- `templates/project-management/` — 生成"项目管理仓"模板（控制平面 + 实时 wiki）。
- `templates/service-types/{infra,gateway,config-server,configuration-data,business,frontend-vue}/` — 6 类服务仓模板。
- `scripts/new-project.sh` / `new-service-repo.sh` — 本地生成项目 / 服务仓（不建远端仓）。
- `scripts/collect.sh` / `analyze-reports.sh` / `validate-project.sh` — 采集 / 分析 / 校验闭环。
- `.agents/skills/` + `.claude/`/`.codex/`/`.opencode/` — 公共规范源与 agent 适配。
- `DESIGN.md` / `HANDOVER.md` / `DELIVERY.md` — 设计、交接、交付手册。

对本仓库自身的修改，仍走下面 §1–§9 的循环与门禁。

---

## 1. 运行原则

1. **循环，不是直线。** Plan → Design → Build → Test → Deploy → Maintain，
   Maintain 写出下一个 intent。你始终在某个阶段；动手前先命名阶段。
2. **每个阶段提交下一个阶段能读的产物。** commit 链就是审计链：谁提出、agent 产出了什么、谁批准。
3. **没有接受的 plan 不实现。** 接受的 `spec.md` 启动 plan；接受的 `plan.md` 启动实现。
4. **只走到人类门禁，绝不越过。** product owner 接受 intent/spec；engineer 接受 plan；
   code owner 批准 PR；发布经理授权生产。agent 绝不批准自己的工作。
5. **检测是确定性的；诊断可以归你；修复走评审门。** 脚本和 hooks 决定何时调用你；你不得决定绕过它们。
6. **修代码，不修测试。** 绝不跳过、删除或弱化检查来让它通过。
7. **fail closed。** 治理检查出错或含糊时，拒绝而不是放行。最小权限；内层 agent 不得比调用它的 agent 权限更大。
8. **审计只追加。** 每个门禁/工具决定都记录（时间戳、agent、允许/拒绝、规则），不编辑、不删除；这是审计链。
9. **验证优先于生成。** 先让检查变便宜再请人信任：自己跑 `bash scripts/app-verify.sh all`（或 `make verify`）。
   无法验证的变更，不要请人看。
10. **环境 > 指令。** 需要写第二遍的规则要变成代码——ArchUnit / lint / hook / CI，而不是再加一段文档。
    优先级：**架构 > 类型/lint/CI > 行为测试 > 文档/agent 规则 > 人读 diff**。
11. **信任是阶梯。** 信任只随可复现证据上升：单会话 → 验证闭环 → 多代理 → autopilot。每级需要更多验证与显式可回滚性。
    单向门变更（数据迁移、鉴权模型、资金）停在 "merge-ready"，合并键留给人。

---

## 2. 强制会话协议

每个会话开始前，先做：

0. 确保护栏已启用：`bash scripts/install-hooks.sh`（幂等；Claude Code 在 SessionStart 自动执行）。
1. 读本文件与 `CLAUDE.md`。
2. 识别当前**阶段**（§4）与会话触发（想法、已接受产物、流水线事件、告警）。
3. 加载该阶段的**技能**（§5）并严格执行。
4. 只要会改代码就默认 **plan 模式**；没有接受的 plan 不编辑文件。
5. 报告完成前跑 **verify-work** 技能，并把命令输出粘进总结。
6. 按 §6 格式提交产物。

硬规则（hooks 与 CI 会强制一部分，其余靠你）：

- 不编辑 `build/`、`.gradle/`、生成的 schema 类。
- bug 修复任务（`CLAUDE_FIX_TASK=1`）期间，失败测试提交后不改 `src/test/`、`src/itest/`。
- 不扩权、不禁用 hooks、不改 managed settings、不绕分支保护。
- secrets 不进源码/日志/提交配置（来自环境：ESO/IRSA，见 `aws-postgres` 技能）。
- 门禁 owner 或条件不清时，**停下问**。

---

## 3. 产物位置

一次变更一个目录，所有相关产物放一起：

```
intent/<YYYY-MM-DD>-<slug>/
  intent.md   — 阶段 1 产物（谁提的、要什么、约束）
  spec.md     — 阶段 2 产物（需求与设计）
  plan.md     — 阶段 3 产物（改哪些文件、顺序、风险、证明）
```

状态写在每个文件的 front matter：`draft | accepted | rejected` + reviewer + date。
`intent/README.md` 是规则；模板：`intent/TEMPLATE.md`、`docs/spec-template.md`、`docs/plan-template.md`。

---

## 4. 阶段手册

### 阶段 1 — Plan · 触发：想法、工单、事故

指令：把意图**只捕获一次**，用提出者自己的话，作为版本化产物。

- 加载技能：**capture-intent**。
- 产物：`intent/<YYYY-MM-DD>-<slug>/intent.md`。
- 门禁：product owner 接受（由合并记录）。被拒也保留目录，不删。
- 度量：首次对话到提交 `intent.md` 的时间。

### 阶段 2 — Design · 触发：已接受 intent

指令：需求与设计一次完成，写 spec 时就应用策略，而不是几周后在评审里发现。

- 加载技能：**requirements-and-design**。
- 产物：`spec.md` 与 intent 一起提交。
- 门禁：product owner 签 spec；每个 flagged concern 由具名 policy owner 解决后才给工程看。
- 度量：intent→spec 耗时；build 开始后的 spec 返工。

### 阶段 3 — Build · 触发：已接受 spec

指令：没有接受的 plan 不实现；组织知识放在 agent 会读的文件里；护栏以代码运行。

1. **3a — Plan。** 加载技能：**implementation-plan**（plan 模式）。产物：`plan.md`。门禁：engineer 接受。
2. **3b — Implement。** 加载技能：**implement-change**。按顺序执行工作项；现实偏离 plan 时，在同一 commit 更新 `plan.md`。
3. **3c — 新服务？** 加载技能：**scaffold-microservice**（框架仓内用 `scripts/new-service-repo.sh`）。
4. **3d — Verify。** 每个工作项后加载 **verify-work**，不是最后才跑。

治理：常规变更是 engineer 批准；涉及 schema、鉴权模型、资金、跨服务契约的升级到 tech lead/architect（§7）。

### 阶段 4 — Test · 触发：持续

指令：每个会话在给人看之前先检查自己的工作。

- **verify-work** 反馈循环强制，每个工作项后跑：build、test、lint、itest，并粘贴输出。
- bug 修复：先写失败测试并提交，再让它通过且不改测试（fix 任务期间 hook 强制）。
- 改 `AGENTS.md`、`CLAUDE.md`、`.claude/**`、`.codex/**`、`.opencode/**`、`.agents/**`、`evals/**` 必须保持 eval 套件绿
  （预算允许时 `python3 evals/run.py`；CI 在这些路径的 PR 上跑）。
- 度量：agent 变更的首次 CI 通过率。

### 阶段 5 — Deploy · 触发：绿色流水线

指令：评审双向进行，治理边做边执行——你做到生产门之前，绝不越过。

- 加载技能：**pr-review**。在请求评审前先对自己的 PR 跑 `REVIEW.md` 三遍；先处理发现再让人读 diff。
- 独立 reviewer agent 对传入 PR 跑 **pr-review**。发现项不批准也不阻塞 PR；要求 code owner 批准的分支保护才是门禁。
- 部署是 **GitOps**（加载 **gitops-deploy**）：infra 仓是真相源，Flux CD reconcile 到 EKS。CI 只构建/推镜像，绝不 `kubectl apply`。
  生产部署需要发布经理的 `RELEASE_APPROVAL`（`production-gate` hook 强制）。你准备发布，不授权发布。
- 度量：首次评审耗时；无需人碰分支就解决的发现占比。

### 阶段 6 — Maintain · 触发：控制带越界、事故、渠道请求

指令：循环闭合。agent 找到的东西作为新 intent 重新进入流水线。

- 加载技能：**incident-to-intent**。
- 读 `config/bands.yaml` 的指标层级：1σ 只记录；2σ 只读诊断；3σ 提议——开 PR 进评审门，或触发预批准 runbook
  `docs/runbook-rollback-deploy.md`。绝不在评审门外应用生产修复。
- 产物：诊断写成新 `intent/<date>-<slug>/intent.md`，像其他变更一样走阶段 1。
- 度量：breach 到 intent 的时间；同类重复事故（每次修复加一条 eval）。

---

## 5. 技能索引 — 加载这些而不是即兴发挥

| 技能 | 何时 | 效果 / 产物 |
|---|---|---|
| `capture-intent` | 阶段 1 | `intent/<folder>/intent.md` |
| `requirements-and-design` | 阶段 2 | `intent/<folder>/spec.md` |
| `implementation-plan` | 阶段 3a（plan 模式） | `intent/<folder>/plan.md` |
| `implement-change` | 阶段 3b | 按 plan 工作项的 commit |
| `scaffold-microservice` | 阶段 3c | 新服务仓 + 登记 `services.json` |
| `verify-work` | 每个工作项后 | 粘贴的 build/test/lint/itest（`app-verify.sh`） |
| `pr-review` | 阶段 5 | PR 上的 tagged findings 报告 |
| `review-triage` | 处理评审意见 | 接受/部分/拒绝/延后，均给理由 |
| `code-quality` | 评审 diff / 请求评审前 | 正确性、安全、性能、坏味道清单 |
| `secure-api-review` | 新建/改任何端点 | 端点检查 + `scripts/check-endpoints.sh` |
| `resiliency-review` | 任何出站调用或事件消费者 | 超时/断路器/重试合规 |
| `spring-service-conventions` | 任何服务代码 | 模块布局与代码标准 |
| `spring-data-jpa` | 任何实体/仓储/事务/迁移变更 | 事务、N+1、实体纪律 |
| `spring-testing` | 新建/改测试 | 正确测试切片 + Testcontainers + Boot 4 API |
| `spring-boot-4-migration` | build 文件或 Boot 4 前 API | Boot 4 改名/属性清单 |
| `architecture-guardrails` | 任何服务代码变更 | ArchUnit 分层规则（`make verify` 失败） |
| `gitops-deploy` | 任何部署变更 | Flux CD 在 dev/uat/prod 的 reconcile |
| `aws-postgres` | 任何数据源/schema/迁移变更 | RDS PostgreSQL + ESO/IRSA + 迁移规则 |
| `incident-to-intent` | 阶段 6 | 诊断 + 新 `intent.md` |

**技能与 agent 无关，规范源只有一处：** `.agents/skills/<name>/SKILL.md`（Agent Skills 标准）。
Codex、opencode、DeepSeek Harness 原生读取；`.claude/skills/<name>/` 是给 Claude Code 的生成副本
（改完技能跑 `scripts/sync-agent-adapters.sh`）。子代理在 `.claude/agents/`、`.codex/agents/`、`.opencode/agents/`
（`verifier`、`security-auditor`、`pr-reviewer`、`code-simplifier`、`codebase-researcher`、
`spec-reviewer`、`architect`、`scanner`）。完整映射见 `docs/agent-support-matrix.md`。
触发情境下加载技能是强制的，即使你认为自己更懂；要改技能走 PR，不要偏离。

---

## 6. 提交与 PR 约定

- 格式：`[<姓名>] #<卡号> <类型>: <概述>`；无卡号用 `#N/A`；**AI 生成的代码姓名用 `AI-Agent`**。
- 类型：`feat`（新增/修改功能）、`fix`、`refactor` 最常用；也允许 `docs`/`chore`/`test`/`perf`/`ci`/`build`/`revert`。
- 例：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`
- intent/spec/plan 产物：`[AI-Agent] #N/A docs: capture intent <title>` / `docs: requirements and design` / `docs: implementation plan`。
- 来自重复评审发现的指令/技能纠正：`[AI-Agent] #N/A docs: <correction>`。
- PR：标题 `[<slug>] <title>`；描述链接 intent 目录、陈述风险、包含 verify-work 输出块。
- 强制层：`pre-commit`（secret/路径/Boot4）、`commit-msg`（上面的消息格式）、`pre-push`（`release*` 必须走 PR；
  其余分支可直推，但推送前跑本仓验证）。`--no-verify` 只有人类明确批准时才可用。
- **Agent 不自行 push**：推送前必须由人确认（含服务仓）；推送以远端为准交接。

---

## 7. 升级 — 何时停下问人

- intent/spec 在范围、约束、成功标准上含糊。
- 变更触及受保护路径、平台锁定的依赖版本、生成的 schema 契约。
- 风险类：schema 迁移、鉴权模型、资金、跨服务契约 → tech lead/architect。
- 你无法识别被要求通过的门禁 owner。
- 验证无法在不弱化检查的情况下变绿。

---

## 8. 技术栈（normative — 不要偏离）

- **语言/构建：** Java 21、Gradle（Kotlin DSL + version catalog）。版本锁在 `gradle/libs.versions.toml`，
  经 `platform` 模块导出；由平台团队维护——功能变更里绝不自行升级。
- **框架：** Spring Boot 4.1.x（锁 `4.1.3`；请求的 `4.1.5` 未发布）+ Spring Cloud `2025.1.5`。
  Boot 4 改名：`spring-boot-starter-webmvc`（非 `-web`）、`@MockitoBean`（非 `@MockBean`）。
- **服务发现：** Kubernetes 原生（`spring-cloud-starter-kubernetes-client`）。**不要加 Eureka。**
- **配置：** Spring Cloud Config（config-server + `spring-cloud-starter-config` 客户端；`spring.config.import: optional:configserver:`）。
- **数据库：** 生产 AWS RDS PostgreSQL；本地 H2；集成测试 Testcontainers PostgreSQL。secrets 走 ESO/IRSA，绝不提交。
- **部署：** AWS EKS + **Flux CD GitOps**，双仓（服务仓 / infra 仓 + Spring Cloud Config source）。环境 `dev`/`uat`/`prod`。
  CI：GitHub Actions（build/test/lint → 推 ECR；Flux reconcile）。
- **模块布局：** `api/`（控制器 + DTO）、`core/`（领域逻辑，不 import web/http）、`adapters/`（持久化、HTTP、消息）。
  共享基础设施：config-server（8888）、gateway（8080）、业务 8081+。

### 常见 Spring 错误（技能里有完整规则；这些是重复犯的）

- field `@Autowired` 而非构造器注入；`@Transactional` 加在 private/final 方法或自调用（静默无效）。
- 控制器返回 JPA 实体；N+1；`open-in-view: true`；生产 `ddl-auto: update`；无界 `findAll()`。
- Boot 4 代码里用 Boot 3 API：`@MockBean`、`spring-boot-starter-web`、`spring-cloud-starter-gateway`（已移除/改名）。
- 缺 `@Valid`/`@Validated`；`@ConfigurationProperties` 没加 `@Validated`。
- 出站调用无超时/断路器；重试非幂等调用。
- **确定性门禁：** `hooks/spring-guard.sh`（Boot 4 / JPA 配置）、生成的 `ArchitectureTest`（ArchUnit 分层 + field 注入）、
  `scripts/check-endpoints.sh`（API 安全）、CI。

---

## 9. 会话总结 — 报告什么

每个非平凡会话结束报告：

1. 阶段与加载的技能；提交的产物路径。
2. 验证输出块（build / test / lint / itest）。
3. 与 plan 的偏离（如有）及 `plan.md` 如何更新。
4. 应成为 intent 的发现/异常（阶段 6 候选）。
5. 被要求时的度量：从 git 历史取阶段周期时间。

# Playbook 映射 — 可追溯性

《The AI-Native SDLC Playbook》的每一个 play 都对应本框架中的一个可执行产物；
框架还针对 Spring Cloud 2025.1 / AWS EKS / Flux GitOps 与多 agent 做了扩展。

| Playbook play | 阶段 | 框架产物 |
|---|---|---|
| 捕获为 intent.md | 1 Plan | `capture-intent` 技能；`intent/TEMPLATE.md`；`intent/README.md` 规则 |
| 需求与设计 | 2 Design | `requirements-and-design` 技能；`docs/spec-template.md`；`spec-reviewer` 子代理 |
| 默认 plan 模式 | 3 Build | `implementation-plan` 技能；`docs/plan-template.md` |
| 自动模式 | 3 Build | `AGENTS.md` §2 协议；hooks + `verify-work` 让自动接受变安全 |
| 遗留系统 / source of truth | 3 Build | `docs/repository-topology.md`（仓库即真相源） |
| CLAUDE.md | 3 Build | `CLAUDE.md` + `AGENTS.md`（命令、约定、常见错、验证） |
| 技能即组织知识 | 3 Build | `.agents/skills/*`（19 个，规范源）+ 各 agent 适配 |
| Hooks 作为构建护栏 | 3 Build | `hooks/protect-paths.sh`、`hooks/no-secrets.sh` + `.claude/.codex/.opencode` 接线 |
| 并行会话与子代理 | 3 Build | worktrees；`verifier`、`security-auditor`、`scanner` 等子代理 |
| 给 agent 反馈循环 | 4 Test | `verify-work` 技能；`scripts/app-verify.sh`；`hooks/test-freeze.sh` |
| CI 中的持续评测 | 4 Test | `evals/run.py`（多 agent）、`evals/tasks/`、`.github/workflows/agent-evals.yml` |
| AI 进入 PR 评审 | 5 Deploy | `pr-review` 技能；`REVIEW.md`；`code-quality` 清单；`pr-reviewer`/`security-auditor` |
| 处理评审反馈 | 5 Deploy | `review-triage` 技能（接受/部分/拒绝/延后，均给理由） |
| 工作分解 | 2/3 Build | `architect` 子代理 + `implementation-plan` 技能 |
| Hooks 作为审批门 | 5 Deploy | `hooks/production-gate.sh`（`RELEASE_APPROVAL`） |
| 托管设置（受监管企业） | 5 Deploy | `.claude/settings.json` 的 deny/allow 基线；可扩展为 managed settings |
| CI/CD 与部署 | 5 Deploy | 服务仓 `.github/workflows/collect.yml`、管理仓 `analyze-reports.yml`；`gitops-deploy` 技能 |
| 闭环 | 6 Maintain | `incident-to-intent` 技能；`config/bands.yaml`；`docs/runbook-rollback-deploy.md` |
| 值班（渠道接入） | 6 Maintain | 进入 `incident-to-intent`（Slack/MCP 接线因组织而异） |

## 框架在 Playbook 之外的扩展（栈相关）

| 关注点 | 产物 |
|---|---|
| Kubernetes 原生发现（不用 Eureka） | `spring-service-conventions` 技能；`templates/service-types/gateway` |
| Spring Cloud Config | `templates/service-types/config-server`；infra `config/` |
| Spring Data JPA 纪律 | `spring-data-jpa` 技能（事务、N+1、实体泄露、迁移） |
| Spring 测试策略 | `spring-testing` 技能（unit/slice/full、Testcontainers、Boot 4 API） |
| Spring Boot 4 迁移 | `spring-boot-4-migration` 技能；`hooks/spring-guard.sh` |
| ArchUnit 架构护栏 | `architecture-guardrails` 技能；生成的 `ArchitectureTest` |
| AWS RDS PostgreSQL | `aws-postgres` 技能（ESO/IRSA、迁移、Testcontainers） |
| Flux CD GitOps 多仓 | `gitops-deploy` 技能；`templates/service-types/infra`；`docs/repository-topology.md` |
| 多 agent 支持 | `docs/agent-support-matrix.md`；`scripts/sync-agent-adapters.sh` |
| 开源对标 | `research/agent-sdlc-patterns-report.md` |

## 度量可追溯性

| Playbook 度量 | 从哪里读 |
|---|---|
| intent 周期/存活 | `intent/` 的 git 历史 |
| spec 耗时/返工 | `spec.md` 与 `intent.md`、`plan.md` 的提交时间戳 |
| 首次合并/返工轮次 | PR 元数据 vs 已提交的 `plan.md` |
| 首次 CI 通过率 | 服务仓 CI / 管理仓 `framework-selftest.yml` |
| 评审耗时/门禁等待 | PR 历史；hook/门禁日志 |
| breach → intent.md | 检测脚本日志 vs intent 目录时间戳 |

# Spring Cloud AI-Native SDLC Framework

> 基于 Anthropic《The AI-Native SDLC Playbook》的**多仓 AI 原生 SDLC 框架**：
> 代码不再是瓶颈，流程才是。它把"一条线"变成"一个环"——AI 干活动，人守门禁；
> 并把"验证、环境约束、信任阶梯"做成基础设施（对齐 poteto 方法论）。

**本仓库是工厂/模板仓，不是业务项目。** 它生成「项目管理仓 + 服务仓」，并用三环模型组织 AI 全生命周期。

---

## 1. 它解决什么问题

| 传统 | 本框架 |
|---|---|
| AI 写代码，人当"人肉中转站" | **验证优先**：AI 先自验（`app-verify`），人只看证据 |
| 规则写进 prompt，反复纠正 | **环境 > 指令**：同错两次 → 变成 lint/ArchUnit/hook/CI |
| "我觉得 AI 可以了" | **信任阶梯**：L0 手动 → L1 验证闭环 → L2 多代理 → L3 autopilot（有确定性门禁） |
| 上下文散落在对话里 | **三环模型**：外环 SDLC / 内环执行事实 / 沉淀环认知，全部落成版本化 artifact |

一句话：让「项目 → 服务 → 执行 → 报告 → 认知 → 约束 → 下一次执行」形成**可审计、可版本化、有人类门禁**的闭环。

---

## 2. 快速开始

```bash
# 0) clone 后先启用确定性护栏（幂等）；Claude Code 会在会话开始时自动执行
bash scripts/install-hooks.sh
#    框架自检：应 99 项全绿
bash scripts/selftest.sh

# 1) 生成控制平面仓（项目管理仓：控制平面 + 实时 wiki）
scripts/new-project.sh myproj ./myproj-control-plane

# 2) 生成服务仓（目录名按命名规则推导，自动登记到管理仓 services.json）
scripts/new-service-repo.sh business   speaker  ./myproj-control-plane        # → myproj-speaker-management
scripts/new-service-repo.sh gateway    api      ./myproj-control-plane        # → myproj-api-gateway
scripts/new-service-repo.sh infra      aws      ./myproj-control-plane        # → myproj-aws-infra
scripts/new-service-repo.sh config-server config-server ./myproj-control-plane # → myproj-config-server
scripts/new-service-repo.sh configuration-data devops ./myproj-control-plane  # → myproj-devops-configuration-data
scripts/new-service-repo.sh configuration-data prod   ./myproj-control-plane  # → myproj-prod-configuration-data

# 3) 服务仓：改代码 → 自验 → 提交 → 采集
cd myproj-speaker-management
bash scripts/app-verify.sh all            # build+test+lint+itest
git add -A && git commit -m "[AI-Agent] #N/A feat: speaker status [learn] prefer RestClient"
bash .sdlc/collect.sh                     # 增量报告 + hash 链

# 4) 管理仓：分析 → 看 wiki / 测试 / DORA
cd ../myproj-control-plane
bash scripts/analyze-reports.sh .
```

> 完整端到端流程见 **`DELIVERY.md` §13**；命令总索引见 **`scripts/README.md`**。

### 2.1 AI 如何使用本仓库

- 先读 `AGENTS.md`（治理指令）和 `CLAUDE.md`（快速参考）；门禁现状与改进方向见 `todo.md`，
  已完成项在 `todo-archive.md`（`todo.md` 只保留未完成项）。
- 新 clone 的首个 Claude Code 会话会自动运行 `scripts/install-hooks.sh`；其他 agent 按 `AGENTS.md`
  会话协议第 0 步执行一次（幂等）。
- 生成项目/服务仓用 `scripts/new-*.sh`，不要手写模块；仓库命名规则由生成器强制。
- 改完必跑：`bash scripts/selftest.sh`、`./scripts/validate-skills.sh`、`bash -n scripts/*.sh hooks/*.sh`。
- 提交信息遵循 `AGENTS.md §6`；`pre-commit`、`commit-msg`、`pre-push` 会强制 secret/路径/Boot4、
  消息格式和推送前验证；`release*` 分支必须走 PR。
- 部署：本框架仓随 git 版本化；它生成的控制平面/服务仓的部署方式见各自仓的 `README.md`。

---

## 3. 三环模型

```
外环（管理仓）  00 constitution → 01 intent → 02 spec → 03 plan → 04 build
                → 05 test → 06 deploy → 07 maintain
内环（服务仓）  每次 commit 增量采集：AI 实际改动 + 人的指令 + 规则缺口
                → 确定性 facts + candidateKnowledge → 上传管理仓
沉淀环（管理仓 knowledge/）  蒸馏为 constraints / skills / lessons / context
                → proposals（AI 只产候选）→ 人签核 → cognition pack → 下发服务仓
```

- **外环产物**：`loop/<阶段>/`，状态 `draft → accepted`，每阶段一个人工门禁。
- **内环事实**：`execution/<stage>/<service>/reports/<sha>.json`，append-only + `prevHash` 链。
- **沉淀环**：`knowledge/pack.json` 是版本化认知；服务仓 `service.json` 锁定版本，升级走 PR。

---

## 4. 六类服务模板

| type | 技术栈 | 生成后可独立构建 |
|---|---|---|
| `infra` | Terraform + Helm + Flux CD | 结构就绪（未做 terraform validate） |
| `gateway` | Spring Boot 4.1.3 + Cloud Gateway (WebFlux) | ✅ `./gradlew assemble` |
| `config-server` | Spring Cloud Config Server | ✅ `./gradlew assemble` |
| `configuration-data` | Spring Cloud Config 的数据仓（按环境分仓的 yml） | 结构就绪（git 后端） |
| `business` | Spring Boot 4.1.3 + JPA + Testcontainers + ArchUnit | ✅ `./gradlew assemble` |
| `frontend-vue` | Vue 3 + Vite + TypeScript + Vitest | ✅ 结构/JSON 校验（npm 需联网） |

每个服务仓生成时自带：`app-verify.sh`（统一验证 CLI）、`feature-map.md`（功能→验证状态）、
`collect.yml`（push 采集）、`.sdlc/`、`.agents/skills`、`findings/`（scanner 队列）、`Makefile`，
以及 `hooks/` + `.githooks/`（已设置 `core.hooksPath=.githooks`：pre-commit 查 secret/路径/Boot4，
commit-msg 校验提交信息，pre-push 要求 `release*` 走 PR、其余分支推送前先跑本仓验证）。
控制平面仓（`new-project.sh`）同样带上并启用这些 hooks。

### 4.1 仓库命名规则（生成器强制）

`<project>` = 控制仓目录名去掉 `-control-plane`（`myproj-control-plane` → `myproj`；旧项目名
`<project>-management` 仍兼容）。

| 仓库用途 | 规则 | 示例 |
|---|---|---|
| 项目控制平面（管理仓） | `<project>-control-plane` | `ses-control-plane` |
| 服务仓（business / frontend-vue） | `<project>-<service>-management` | `ses-speaker-management` |
| 网关 | `<project>-<usage>-gateway` | `ses-api-gateway` |
| 基础设施 | `<project>-<cloud>-infra` | `ses-aws-infra` |
| 配置服务 | `<project>-config-server` | `ses-config-server` |
| 配置数据（生产） | `<project>-prod-configuration-data` | `ses-prod-configuration-data` |
| 配置数据（非生产） | `<project>-devops-configuration-data` | `ses-devops-configuration-data` |

- 目录名默认按规则推导；显式传入的 `target-dir` 不符合规则会**报错退出**
  （`--allow-custom-name` 可显式绕过）。
- `services.json` / `service.json` 的 `name` 用**短服务名**（如 `speaker`、`prod-configuration-data`），
  仓库全名在 `repo` 字段。

---

## 5. 技术栈（normative）

| Concern | Choice |
|---|---|
| Language / build | Java 21 · Gradle（Kotlin DSL + version catalog） |
| Framework | Spring Boot **4.1.3**（最新 4.1.x；请求的 4.1.5 未发布） · Spring Cloud **2025.1.5** |
| Discovery | **Kubernetes 原生**（`spring-cloud-kubernetes`）——不加 Eureka |
| Config | **Spring Cloud Config**（config-server + client） |
| Database | **AWS RDS PostgreSQL**（prod）· H2（local）· Testcontainers（itest） |
| Deploy | **AWS EKS + Flux CD GitOps**（双仓）· dev/uat/prod |
| CI | **GitHub Actions**（build/test/lint → ECR；Flux reconcile） |

---

## 6. 仓库结构

```
README.md / DELIVERY.md          入口 + 交付清单与使用手册
AGENTS.md / CLAUDE.md / REVIEW.md  agent 指令、快速参考、评审策略
DESIGN.md / HANDOVER.md          设计基线 + 交接
templates/project-management/    管理仓模板（loop/execution/knowledge/wiki/sync/intake）
templates/service-types/         6 类服务模板 + _shared（Gradle 脚手架）
schemas/                         execution-report / service-registry / cognition-pack
scripts/                         生成器 + 闭环 + 验证（见 scripts/README.md）
.agents/skills/                   23 个技能（Agent Skills 标准，规范源）
.claude/ .codex/ .opencode/       per-agent 适配（skills/agents/settings/hooks）
hooks/ + .githooks/               确定性护栏（secret/path/spring/生产门禁/测试冻结）
evals/                            agent 评测套件
config/bands.yaml                 控制带（1σ/2σ/3σ）
docs/                             project-factory / trust-ladder / agent-splitting / ...
research/                         上游研究
```

---

## 7. 验证与信任

```bash
# 服务仓：先自验，再请人看
bash scripts/app-verify.sh all     # build + test + lint + itest（Java）；前端 npm
bash scripts/app-verify.sh smoke   # 起应用并轮询 /actuator/health
make verify                        # 等价快捷方式

# 信任阶梯：只有 L3 + 验证绿 + 无单向门，才允许 autopilot 合并
jq .trustLevel service.json
bash scripts/autopilot-gate.sh
```

- 框架自检：`bash scripts/selftest.sh`（99 项）。
- 技能/子代理配置：`./scripts/validate-skills.sh`（23 skills / 8 agents）。
- 设计说明：`docs/trust-ladder.md`、`docs/agent-splitting.md`。

---

## 8. 认知闭环（沉淀环）

```bash
# 管理仓：proposals → 人工签核 → pack 版本化 → 下发
bash scripts/promote-proposal.sh . P-<service>-<slug> <owner> deterministic
bash scripts/sync-cognition.sh . ../myproj-speaker-management
```

- AI/CI 只写 `knowledge/proposals/`；`knowledge/pack.json` 的 active 条目**必须人工签核**（D19）。
- 同一候选 ≥2 次 → `repeat: true`（蒸馏信号）；`deterministic` 会生成 `knowledge/guardrails/<id>.md` 存根，
  要求落成 hook/ArchUnit/lint/CI，而不是再加 prompt。

---

## 9. 情报入口与扫描

- **intake（外循环）**：`scripts/intake-signal.sh` 收 Slack/Linear/邮件/告警 → `scripts/intake.sh` 聚类成
  `intake/candidates/`；人再提升为 `loop/01-intent/`。接入见 `docs/intake-channels.md`。
- **scanner（只扫不改）**：`scanner` 子代理 + `scripts/scan-findings.sh` 只往 `findings/inbox.md` 追加发现；
  重复发现逼出根因，再升级为 guardrail。

---

## 10. 文档索引

| 想看 | 打开 |
|---|---|
| 交付清单 + 使用手册 | `DELIVERY.md` |
| 设计方案 | `DESIGN.md` |
| 需求与交接 | `HANDOVER.md` |
| 工厂使用 | `docs/project-factory.md` |
| GitHub 自动化 | `docs/github-automation.md` |
| 信任阶梯 | `docs/trust-ladder.md` |
| agent 拆分 | `docs/agent-splitting.md` |
| skill 写作/瘦身 | `docs/skill-authoring.md` |
| intake 渠道 | `docs/intake-channels.md` |
| 命令台 | `scripts/README.md` |
| 多 agent 适配 | `docs/agent-support-matrix.md` |
| 云端拓扑 | `docs/repository-topology.md` |
| Playbook 映射 | `docs/playbook-mapping.md` |

---

## 11. 已知边界（诚实）

- 默认**只本地生成**，不自动建远端 GitHub 仓；接远端需配 `MANAGEMENT_REPO`/`SYNC_TOKEN`。
- `business` 模板基础包固定 `com.example.app`（每仓独立；后续可按服务名渲染）。
- `frontend-vue` 的 `npm install/build` 未在本地执行验证（JSON/结构已校验）。
- DORA 的 MTTR 需要 maintain 报告携带 `incident.openedAt/resolvedAt`；lead time 已按 build→deploy 计算。
- 不追求"100% 自主"：结构保险是 **agent 不能自批 + 确定性门禁最终裁决 + 人类变更门**。

---

> 一行证明：`bash scripts/selftest.sh` → `selftest: 99 passed, 0 failed`。

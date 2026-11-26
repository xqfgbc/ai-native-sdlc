# AI-Native SDLC 框架 · 交付清单与使用手册

> 版本：v1（P1–P4 核心完成） · 日期：2026-11-25
> 配套：`DESIGN.md`（设计方案）、`HANDOVER.md`（需求/状态/交接）、`README.md`（框架概览）

---

# 第一部分 · 交付清单

## 1. 交付物总览

本仓库是 **AI-Native SDLC 的工厂/模板仓**：它生成「项目管理仓 + 服务仓」，并以「三环模型」组织 AI 全生命周期。仓库根目录结构：

```
AGENTS.md / CLAUDE.md / REVIEW.md      agent 指令与评审策略
DESIGN.md / HANDOVER.md                设计与交接基线
DELIVERY.md                            本文件（交付清单 + 使用手册）
README.md                              框架概览
templates/                             ★ 生成模板
  project-management/                  管理仓模板（loop/execution/knowledge/wiki/sync）
  service-types/                       6 类服务模板 + _shared（Gradle 脚手架）
schemas/                               execution-report / service-registry / cognition-pack（JSON Schema）
scripts/                               ★ 生成器 + 闭环脚本
  new-project.sh                       生成项目管理仓
  new-service-repo.sh                  生成服务仓并登记
  collect.sh                           客户端增量采集（commit 触发）
  analyze-reports.sh                   管理仓分析（定时/手动）
  promote-proposal.sh                  人工签核（proposal → pack active）
  sync-cognition.sh                    cognition pack 下发
  upload-report.sh                     跨仓 PR 上传（P2）
  validate-project.sh / validate-skills.sh  校验
  selftest.sh                          端到端自测
.github/workflows/                     framework-selftest.yml / agent-evals.yml
.agents/skills/                        19 个 agent 技能（Agent Skills 标准，规范源）
.claude/ .codex/ .opencode/            per-agent 适配（skills/agents/settings/hooks）
hooks/ .githooks/                      确定性护栏（secret/path/spring/生产门禁/测试冻结）
config/                                bands.yaml（控制带）
evals/                                 agent 评测套件
docs/                                  project-factory / github-automation / 模板 / runbook 等
research/                              上游研究（playbook、Spring 坑、GitHub 护栏、上游技能）
```

## 2. 已完成能力（P1–P4）

| 阶段 | 交付能力 | 关键文件 | 验证 |
|---|---|---|---|
| **P1** | 多仓工厂：管理仓模板 + 6 类服务模板 + 生成器 | `templates/`、`scripts/new-*.sh` | selftest |
| P1 | 管理仓自包含（analyzer/validator 随生成复制） | `new-project.sh` | selftest |
| P1 | 多 agent 规范源（D8） | `new-service-repo.sh` 复制 `.agents/skills` + `.claude` | selftest |
| **P2** | 服务仓 collect 工作流（push/dispatch） | `templates/**/.github/workflows/collect.yml` | selftest |
| P2 | 跨仓 PR 上传 + 最小权限 | `scripts/upload-report.sh`、`docs/github-automation.md` | selftest |
| P2 | 管理仓定时/手动 analyze | `templates/project-management/.github/workflows/analyze-reports.yml` | — |
| **P3** | 执行报告契约 + 幂等 + hash 链 | `schemas/execution-report.schema.json`、`collect.sh` | selftest |
| P3 | 采集器 facts 确定性提取 + secrets 脱敏 | `collect.sh` | selftest |
| P3 | session-log → candidateKnowledge（D1） | `collect.sh`、服务模板会话协议 | selftest |
| P3 | proposal 人工签核 → pack 版本化（D2/D19） | `promote-proposal.sh` | selftest |
| P3 | cognition pack 下发（D3） | `sync-cognition.sh` | selftest |
| P3 | 蒸馏重复检测（D4） | `analyze-reports.sh` | selftest |
| **P4** | 测试管理 | `templates/.../loop/05-test/`、`analyze-reports.sh` | selftest |
| P4 | DORA 四键 | `analyze-reports.sh` → `wiki/dora.md` | selftest |
| 常备 | 确定性护栏（secret/path/Spring/生产门禁/测试冻结） | `hooks/`、`.githooks/`、CI | 功能测试 |
| 常备 | 多 agent 技能与子代理 | `.agents/skills`（19）、`.claude/agents`（8） | validate-skills |
| **P0/P1/P2** | 验证基础设施（app-verify / feature-map / make verify） | `scripts/app-verify.sh`、`_shared/Makefile`、`feature-map.md` | selftest |
| P0/P1 | 环境 > 指令（guardrail 提升 + 规则层级） | `promote-proposal.sh deterministic`、`knowledge/guardrails/`、`AGENTS.md` §1 | selftest |
| P1 | 信任阶梯（L0–L3 + autopilot 门禁） | `docs/trust-ladder.md`、`scripts/autopilot-gate.sh`、注册表 `trustLevel` | selftest |
| P1 | scanner 只扫不改 + findings 队列 | `scanner`（Claude/Codex/opencode）、`scripts/scan-findings.sh` | selftest |
| P1 | intake 情报聚类 + 真实渠道 | `intake/`、`scripts/intake.sh`、`scripts/intake-signal.sh`、`intake.yml` | selftest |
| P2 | agent 拆分标准 + skill 瘦身 | `docs/agent-splitting.md`、`docs/skill-authoring.md`、`scripts/README.md` | — |
| P2 | DORA lead time 精确化 | `analyze-reports.sh` | selftest |

## 3. 验证记录

```bash
$ bash scripts/selftest.sh
... 49 项 PASS ...
selftest: 49 passed, 0 failed

$ ./scripts/validate-skills.sh
validate-skills: OK (19 skills, 8 agents)
```

另有（已执行验证）：
- `gateway` / `config-server` / `business` 独立服务仓 `./gradlew assemble` → **BUILD SUCCESSFUL**。
- 旧单仓 `./gradlew check`（归档前）→ BUILD SUCCESSFUL。

## 4. 未完成 / 用户侧待办

| 项 | 说明 |
|---|---|
| **远端仓接入** | 建 GitHub 仓 + 配 `MANAGEMENT_REPO` / `SYNC_TOKEN`，启用真实回灌（`docs/github-automation.md`） |
| frontend-vue 构建验证 | 已校验 `package.json`/`tsconfig` 合法；`npm install && npm run build` 需在网络环境执行 |
| DORA MTTR | lead time 已精确计算（build→deploy）；MTTR 需 maintain 报告带 incident 时间戳 |
| 业务包名 | business 模板当前固定基础包 `com.example.app`（每仓独立，后续可按服务名渲染） |

---

# 第二部分 · 使用手册

## 1. 快速开始（3 步）

```bash
# 1) 生成一个项目管理仓
scripts/new-project.sh myproj ./myproj-control-plane

# 2) 生成服务仓（目录名按命名规则推导；自动登记到管理仓 services.json）
scripts/new-service-repo.sh business speaker ./myproj-control-plane        # → myproj-speaker-management
scripts/new-service-repo.sh gateway api ./myproj-control-plane             # → myproj-api-gateway
scripts/new-service-repo.sh config-server config-server ./myproj-control-plane   # → myproj-config-server
scripts/new-service-repo.sh configuration-data devops ./myproj-control-plane     # → myproj-devops-configuration-data
scripts/new-service-repo.sh configuration-data prod ./myproj-control-plane       # → myproj-prod-configuration-data
scripts/new-service-repo.sh infra aws ./myproj-control-plane               # → myproj-aws-infra

# 3) 在服务仓里开发并提交 → 自动采集 → 管理仓分析
cd myproj-speaker-management
git add -A && git commit -m "feat: speaker status [learn] prefer RestClient over RestTemplate"
bash .sdlc/collect.sh
cd ../myproj-control-plane && bash scripts/analyze-reports.sh .
```

> 一行验证框架自身：`bash scripts/selftest.sh`

## 2. 仓库角色

| 仓库 | 角色 |
|---|---|
| 框架仓（本仓） | 模板 + 生成器 + 公共 skills/hooks |
| `<project>-control-plane` | 控制平面 + 实时 wiki（外环 SDLC + 执行事实 + 认知沉淀） |
| `<project>-<cloud>-infra` | Terraform + Helm + Flux GitOps（如 `ses-aws-infra`） |
| `<project>-<usage>-gateway` | Spring Cloud Gateway（如 `ses-api-gateway`） |
| `<project>-config-server` | Spring Cloud Config（如 `ses-config-server`） |
| `<project>-<prod\|devops>-configuration-data` | Spring Cloud Config 的 git 后端（按环境分仓） |
| `<project>-<service>-management` | 业务服务 / 前端（business、frontend-vue，如 `ses-speaker-management`） |

## 3. 管理仓（控制平面）结构

```
loop/            外环：00 constitution → 01 intent → 02 spec → 03 plan → 04 build
                 → 05 test → 06 deploy → 07 maintain
execution/       内环：各服务上传的执行报告（append-only，含 prevHash 链）
knowledge/       沉淀环：constraints/skills/lessons/context + proposals + pack.json
wiki/            实时视图：index/services/decisions/testing/cognition/dora
sync/            schema + 状态
scripts/         自包含 analyze/validate/promote/sync
```

## 4. 内环闭环（commit → 报告 → 分析 → wiki）

在服务仓：
1. 开发 → `git commit`（可用 `[learn] <规则>` 标记一条候选认知）。
2. 会话结束前写 `sdlc/session-log/<ts>.md`（含「规则缺口」段）。
3. `bash .sdlc/collect.sh`：
   - 增量采集 `lastCollectedSha..HEAD`；
   - 确定性 facts（commits/files/layers/tests/arch/deps）；
   - candidateKnowledge（来自 `[learn]` + session-log 规则缺口，已脱敏）；
   - 写 `sync/reports/<toSha>.json`，本地上传（或留待远程 PR）；
   - 推进 hash 链（`prevHash`）。

在管理仓：
```bash
bash scripts/analyze-reports.sh .   # 生成 wiki、proposals、测试结果、DORA
bash scripts/validate-project.sh .
```

## 5. 认知闭环（proposal → 人工签核 → pack → 下发）

1. `analyze-reports.sh` 把候选认知写入 `knowledge/proposals/`，状态 `proposed`。
2. 同一候选出现 **≥2 次** → `repeat: true` + `recommendation: promote to constraint`（D4）。
3. **policy owner 人工签核**（AI/CI 不得自动提升，D19）：
   ```bash
   bash scripts/promote-proposal.sh . P-<service>-<slug> <owner>
   ```
   → 进入 `knowledge/pack.json` 的 `active` 条目，pack 版本 bump。
4. 下发到服务仓（本地模拟/远端 PR）：
   ```bash
   bash scripts/sync-cognition.sh . ../myproj-speaker-management
   ```
   → `.sdlc/cognition-pack.json` + `service.json` 锁定版本。

## 6. 测试管理与 DORA

- `loop/05-test/test-plan.md`：测试策略、环境、质量门禁。
- `loop/05-test/results.md`：各服务单测/集成/覆盖率（analyzer 生成）。
- `wiki/dora.md`：部署频率、变更失败率、lead time、MTTR（从报告推导，proxy 标注）。
- 事故 → 新 `07-maintain/incidents/INC-*.md` → 新 intent；每起事故补一条 eval。

## 7. GitHub 自动化（可选，P2）

1. 在服务仓设置 Variable `MANAGEMENT_REPO=org/<project>-control-plane`、Secret `SYNC_TOKEN`。
2. `.github/workflows/collect.yml` 在 push 时采集并调用 `scripts/upload-report.sh` **开 PR** 到管理仓。
3. 管理仓 `analyze-reports.yml` 定时/手动分析；`execution/**` 报告可自动合并，`knowledge/pack.json` 必须人工。
4. 最小权限与权限配置见 `docs/github-automation.md`。

## 8. 验证命令

| 命令 | 作用 |
|---|---|
| `bash scripts/selftest.sh` | 框架端到端自测（生成→采集→分析→签核→下发→校验） |
| `./scripts/validate-skills.sh` | 技能/子代理配置校验 |
| `bash scripts/validate-project.sh <management-repo>` | 管理仓一致性校验 |
| 服务仓 `bash scripts/app-verify.sh all`（或 `make verify`） | 统一验证：build+test+lint+itest；`smoke` 起应用探活 |
| 服务仓 `make build/test/lint` 或 `./gradlew assemble/test/check` | 服务构建/测试/静态检查 |

## 9. 关键设计决策（摘要，完整见 `DESIGN.md` / `HANDOVER.md` §3）

| 决策 | 结论 |
|---|---|
| 认知配置 | **cognition pack**（管理仓版本化，服务仓锁定，PR 升级） |
| GitHub 自动化 | **默认只本地生成**；远端流程可选 |
| 采集 / 分析 | commit 触发增量采集；管理仓定时/手动分析 |
| 蒸馏生效 | 服务内明确→自动；**项目级 pack 必须人工签核**（D19） |
| 确定性优先 | hooks + CI + ArchUnit + Schema 为最终裁决；AI reviewer 只做广度 |
| 审计 | append-only + hash 链；agent 不批准自己；CODEOWNERS 硬化门禁 |
| 交叉评审 | reviewer 与 writer 可用不同模型族（D20），共模盲区已知限制 |

## 10. 常见问题

- **为什么采集器报 `no new commits`？** 说明 `lastCollectedSha == HEAD`；提交新 commit 后再采集。
- **报告没出现在管理仓？** 本地模式检查 `managementRepo` 是目录；远程模式检查 `MANAGEMENT_REPO`/`SYNC_TOKEN`。
- **proposal 一直是 proposed？** 需要 policy owner 执行 `promote-proposal.sh`（D19 人工门禁）。
- **看不到 DORA 数据？** 需要有 `deploy`/`maintain` 阶段的报告；当前 demo 只有 `build`。
- **Gradle 首次很慢？** 是依赖下载；缓存 `.gradle-home`（gitignore）保留即可。

## 11. 文件索引（关键入口）

| 想看 | 打开 |
|---|---|
| 设计方案 | `DESIGN.md` |
| 需求与交接 | `HANDOVER.md` |
| 框架概览 | `README.md` |
| 工厂使用 | `docs/project-factory.md` |
| GitHub 自动化 | `docs/github-automation.md` |
| 多 agent 适配 | `docs/agent-support-matrix.md` |
| 云端拓扑 | `docs/repository-topology.md` |
| Playbook 映射 | `docs/playbook-mapping.md` |
| 信任阶梯 | `docs/trust-ladder.md` |
| agent 拆分 | `docs/agent-splitting.md` |
| skill 写作/瘦身 | `docs/skill-authoring.md` |
| intake 渠道 | `docs/intake-channels.md` |
| 命令台 | `scripts/README.md` |
| 上游研究 | `research/` |

## 12. poteto 方法论对齐（2026-11 增强）

- **验证优先于生成**：新增 `scripts/app-verify.sh` 统一验证 CLI（Java/Node 自动识别），
  `_shared/Makefile` 与 frontend-vue `Makefile` 增加 `make verify`/`make smoke`；
  每个服务仓生成 `feature-map.md`（功能 → 需求 → 验证 → 状态）。
- **环境 > 指令**：`promote-proposal.sh <mgmt> <id> <owner> deterministic` 会把重复约束
  落成 `knowledge/guardrails/<id>.md` 存根，要求实现为 hook/ArchUnit/lint/CI 而不是再加一句 prompt；
  `AGENTS.md` §1 新增规则层级（架构 > lint/CI > 测试 > 文档 > 人读 diff）。
- **信任阶梯**：`AGENTS.md` §1 新增原则 9/10/11 —— 验证优先、环境优先、信任是阶梯；
  单向门变更（数据迁移/鉴权/资金）停在 merge-ready，合并键留给人。
- **P1（本轮）**：`trustLevel`（L0–L3）+ `scripts/autopilot-gate.sh` 确定性门禁（`docs/trust-ladder.md`）；
  `scanner` 只扫不改 + `findings/` 队列（`scripts/scan-findings.sh`）；`intake/` 信号聚类 +
  `scripts/intake.sh` + `.github/workflows/intake.yml`。
- **P2（本轮）**：`docs/agent-splitting.md`（何时拆/合并 agent，当前 8 个的理由）；
  `docs/skill-authoring.md` + `scripts/README.md`（命令台，skill 只留流程/判断）；
  `scripts/intake-signal.sh` + `repository_dispatch`（Slack/Linear/邮件接入，见 `docs/intake-channels.md`）；
  DORA lead time 精确计算（build→deploy）+ MTTR（有 incident 时间戳时）。

## 13. 现在怎么用（端到端一次跑通）

```bash
# 0) 框架自检（应 49 项全绿）
bash scripts/selftest.sh

# 1) 生成项目 + 服务
scripts/new-project.sh myproj ./myproj-control-plane
scripts/new-service-repo.sh business speaker ./myproj-control-plane   # → myproj-speaker-management

# 2) 服务仓：改功能 → 先自验 → 更新 feature-map → 提交 → 采集
cd myproj-speaker-management
bash scripts/app-verify.sh all          # build+test+lint+itest（Java）；前端走 npm
# 在 feature-map.md 记录：功能 → 需求 → 验证命令 → 状态
git add -A && git commit -m "feat: speaker status [learn] prefer RestClient"
bash .sdlc/collect.sh                   # 增量报告 + hash 链

# 3) 管理仓：分析 → 看 wiki / 测试 / DORA
cd ../myproj-control-plane
bash scripts/analyze-reports.sh .
ls wiki/ loop/05-test/                  # index/dora/testing + results

# 4) 认知闭环：人工签核 → 下发
bash scripts/promote-proposal.sh . P-speaker-<slug> <owner> deterministic
bash scripts/sync-cognition.sh . ../myproj-speaker-management

# 5) 情报入口：任意渠道 → 信号 → 候选
echo "客户反馈：注册太慢" | scripts/intake-signal.sh onboarding "客户反馈：注册太慢"
bash scripts/intake.sh

# 6) 信任阶梯：升级到 L3 后由门禁判断能否自动合并
( cd ../myproj-speaker-management && bash scripts/autopilot-gate.sh )

# 7) 扫描（只扫不改）
( cd ../myproj-speaker-management && bash scripts/scan-findings.sh && cat findings/inbox.md )
```

### 关键约定速记

- **每次改完先自验**：`app-verify.sh all` 不绿，不要请人看。
- **规则重复两次**：改成 lint/ArchUnit/hook，不要只加 prompt。
- **项目级认知**：AI 只写 `proposals/`；`pack.json` 必须人签核（`promote-proposal.sh`）。
- **merge 权限**：L1/L2 由 code owner；L3 才允许 autopilot 门禁放行，且生产仍走 `production-gate`。
- **只扫不改**：scanner / `scan-findings.sh` 只往 `findings/inbox.md` 追加；人定期分诊。

---

> **一句话**：这个框架让「项目 → 服务 → 执行 → 报告 → 认知 → 约束 → 下一次执行」形成可审计、可版本化、有人类门禁的闭环；`bash scripts/selftest.sh` 是它当前全部能力的可执行证明。

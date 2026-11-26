# AI-Native SDLC 框架 · 设计方案

## 0. 一句话

一个以 **「AI 认知自我迭代」** 为中心的多仓 SDLC 方法：项目级**外循环**管理完整生命周期；每个服务仓是**内层执行单元**；执行事实持续回灌到项目管理仓，蒸馏为可复用的**约束/技能**，再下发驱动下一次 AI 执行。管理仓因此成为**实时自动更新的项目知识 wiki**。

## 1. 设计原则

1. **两层 SDLC**：外层=项目生命周期，内层=服务执行，职责不混。
2. **事实与认知分离**：`execution/` 是"发生过什么"（append-only 事实）；`knowledge/` 是"学到什么"（可版本化认知）。
3. **双触发**：采集在 **commit**（每个服务仓），分析在 **定时/手动**（管理仓）。
4. **歧义人工、明确自动**：防止 AI 幻觉污染项目认知。
5. **一切为 AI 消费而写**：所有产物既要人能读，也要能作为 `AGENTS.md`/skills/cognition pack 被 AI 加载。
6. **门禁 fail closed、审计 append-only**：检查出错就拒绝；记录不可篡改。
7. **本地生成优先**：GitHub 远程建仓/权限后续再加。
8. **认知可溯源**：每条约束/技能都能追到"哪次执行、哪次人纠正"教会的。

## 2. 三层闭环

```
┌──────────── 外层：项目级 SDLC（管理仓 · 人+AI · 门禁）───────────────┐
│ 01 intent → 02 spec → 03 plan → 04 build → 05 test → 06 deploy → 07 maintain │
│      ↑                                                              │        │
│      └────────────── maintain 产生新 intent（闭环）─────────────────┘        │
└───────────────────────────▲──────────────────────────┬───────────────────────┘
           读约束/技能       │                          │ 下发阶段任务
                             │                          ▼
┌──────────── 内层：每个阶段的 AI 真实执行（服务仓）──────────────────────────┐
│ 做了什么 / 和 AI 交流了什么 / 纠正了什么 / 用了或违反了哪些规则              │
│ commit 时增量采集 → 分类总结 → 上传报告                                     │
└───────────────────────────┬─────────────────────────────────────────────┘
                            │ 定时/手动分析 + 蒸馏
                            ▼
┌──────────── 沉淀层：项目认知（约束/技能/教训/项目事实）────────────────────┐
│ constraints · skills · lessons · context（版本化 + 溯源 + 生效范围）        │
│ → 打包 cognition pack → 服务仓锁定版本消费 → 下一次执行更聪明               │
└────────────────────────────────────────────────────────────────────────────┘
```

## 3. 仓库拓扑（本地生成，已确认）

| 仓库 | 角色 | 谁生成 |
|---|---|---|
| **框架仓**（本仓库） | 工厂：5 类服务模板 + 生成器 + 公共 skills/hooks | — |
| **项目管理仓** `project-management` | 控制平面 + 实时 wiki | `new-project` |
| **基础设施仓** `infra` | Terraform + Helm + Flux GitOps | 服务模板 `infra` |
| **网关仓** `gateway` | Spring Cloud Gateway | 服务模板 `gateway` |
| **配置仓** `config-server` | Spring Cloud Config | 服务模板 `config-server` |
| **业务仓** `business`（可多个） | Spring Boot 业务服务 | 服务模板 `business` |
| **前端仓** `frontend-vue` | Vue 3 + Vite | 服务模板 `frontend-vue` |

已确认：**认知配置用 cognition pack**；**只做本地生成**（脚本产出目录，建仓/push 由人执行）。

## 4. 项目管理仓结构（它就是 wiki）

```
<project>-management/
├── AGENTS.md / CLAUDE.md        # 外层规则 + 会话协议
├── README.md                    # wiki 首页（生成）
│
├── loop/                        # 【外循环】项目级 SDLC
│   ├── 01-intent/               #   客户意图
│   ├── 02-spec/                 #   需求 + 页面设计 + 功能/架构设计(+ADR)
│   ├── 03-plan/                 #   项目计划 + 服务拆分
│   ├── 04-build/                #   services.json 注册表 + 各服务状态
│   ├── 05-test/                 #   测试计划/矩阵/结果
│   ├── 06-deploy/               #   发布记录/审批
│   └── 07-maintain/             #   事故/控制带 → 新 intent
│
├── execution/                   # 【内层】AI 执行事实（append-only）
│   └── <stage>/<service>/reports/<sha>.json
│   └── <stage>/<service>/sessions/<ts>.md
│
├── knowledge/                   # 【沉淀】项目认知
│   ├── constraints/ skills/ lessons/ context/
│   ├── proposals/               #   待人工评审
│   └── pack.json                #   cognition pack（版本化）
│
├── wiki/                        # 【生成】实时视图
│   ├── index.md  services/*.md  decisions.md  testing.md  cognition.md
│
├── sync/                        # 契约 + schema + 状态
└── .github/workflows/           # analyze-reports.yml（cron + dispatch）
```

**读写关系**：人写 `loop/`；AI 写 `execution/`（经采集器）；分析器写 `wiki/`、`knowledge/`；服务仓读 `knowledge/pack.json`。

## 5. 外循环 7 阶段完整规格

| 阶段 | 触发 | 输入 | 产物 | 人类门禁 | 完成度量 |
|---|---|---|---|---|---|
| **01 intent** | 客户/PM 提出 | 客户原话 | `intent.md` | 客户/PM 接受 | 意图→提交时长 |
| **02 spec** | intent 接受 | intent | `spec.md` + 页面设计 + 功能/架构设计 + ADR | PM + 架构师签署 | spec 返工率 |
| **03 plan** | spec 接受 | spec | 项目计划 + 服务拆分 + 依赖顺序 | 技术负责人接受 | 计划偏差 |
| **04 build** | plan 接受 | plan + 模板 | 服务仓 + `services.json` 注册 + 状态 | 每服务 PR code owner | 首次合并率 |
| **05 test** | 持续 | 服务仓测试 | 测试计划 + 需求↔测试矩阵 + 结果 | QA 门禁 | 首次 CI 通过率、逃逸缺陷 |
| **06 deploy** | 测试通过 | 发布候选 | 发布记录 + 授权 + 回滚演练 | 发布经理授权 | 部署频率、失败率 |
| **07 maintain** | 告警/事故 | 监控/控制带 | 事故记录 → **新 intent** | 值班分诊 | 击穿→intent 时长 |

**闭环**：`07 maintain` 的事故写回 `01 intent`，重新进入外循环。

## 6. 内循环：执行事实采集（客户端，commit 触发）

**触发**：服务仓每次 commit/push 自动跑采集器。
**范围**：`上次采集 sha → HEAD`（增量，不重复处理）。
**采集内容**：
- **AI 操作**：commit、diff、工具/命令日志；
- **人给的指令**：session-log 里的 prompt、纠正、否决；
- **真实实现**：改动文件、分层（api/core/adapters）、迁移、测试；
- **规则使用**：命中/违反了哪些约束、技能。

**分类与总结**：
- **事实（facts）**：实现了什么需求、用了什么技术、架构是否遵循、测试结果；
- **经验（candidateKnowledge）**：值得沉淀的约束/技能/教训/项目事实。

**歧义判定**：采集器给出 `review.status = auto | needs_review`。判据：改动过大、无对应 session-log、与既有约束冲突、跨服务影响等 → `needs_review`（挂起等人）。

**上报**：写 `sync/reports/<sha>.json`，并**自动上传**到管理仓 `execution/<stage>/<service>/reports/`（本地=写文件；远端=开 PR，机器报告可自动合并、约束变更走人工）。

## 7. 执行报告契约（关键字段）

```
apiVersion/kind
metadata: service, repo, type, agent, trigger, fromSha, toSha, createdAt
spec:
  stage                         # intent…maintain
  requirementRefs[]             # 本次满足了哪些需求
  facts { commits, filesChanged, layers, tests{unit,integration,coverage,failed}, architectureSignals }
  interactions[] { type: prompt|correction|decision|question, summary, evidenceRef }
  decisions[]  { id, title, status, rationale, adrRef }
  ruleViolations[]
  candidateKnowledge[] { type: constraint|skill|lesson|context, title, proposal, evidenceRefs }
  review { status, reviewer, note }
```

## 8. 管理仓分析（定时/手动）

- **触发**：`cron` 定时 或 `workflow_dispatch` 手动（管理仓）。
- **输入**：各服务仓已上传的执行报告。
- **产出**：
  1. **项目真实状态**：需求实现情况（`services.json`）、技术使用情况、架构遵循情况、测试情况；
  2. **知识沉淀**：更新 `knowledge/`、`knowledge/pack.json`；
  3. **实时 wiki**：重生成 `wiki/`（首页/服务/决策/测试/认知看板）。
- **规则**：明确项自动生效；歧义项进 `knowledge/proposals/` 等人工。

## 9. 认知沉淀引擎（自我迭代核心）

**四种认知**：`constraint`（约束）、`skill`（技能）、`lesson`（教训）、`context`（项目事实）。

**提升规则**：

| 触发 | 沉淀为 | 例子 |
|---|---|---|
| 同一纠正/错误 ≥2 次 | constraint | "用 `@ServiceConnection`，不用 `@DynamicPropertySource`" |
| 同类流程 ≥3 次 | skill | "新增服务须登记注册表 + gateway 路由" |
| 事故/失败/绕过门禁 | lesson（+eval） | "上次漏了 Flyway 回滚预案" |
| 架构事实变化 | context（自动更新） | 服务拆分、依赖、端口 |
| 政策/安全硬规则 | 加确定性 gate（hook/CI） | 生产部署需 `RELEASE_APPROVAL` |

**每条认知的属性**：`id`、`type`、`scope`（project/service/process）、`owner`、`version`、`provenance`（哪些报告/事故）、`status`（proposed→active→retired）、`enforcement`（advisory/deterministic）。

**生效**：明确 → `active`；歧义 → 人工批准后 `active`。

## 10. Cognition Pack（已确认）

- **是什么**：项目级"认知包"，= `knowledge/pack.json`（constraints/skills/lessons/context）+ 引用文件，**语义化版本**（如 `1.3.0`）。
- **怎么消费**：每个服务仓在 `service.json` 里**锁定 pack 版本**；`AGENTS.md`/skills/hooks 由该版本生成。
- **怎么升级**：管理仓发新版本 → 服务仓开 PR 升级（policy owner 批准）→ 内容变更进入该服务仓的 AI 上下文。
- **与模板版本的区别**：template version = 脚手架形状；cognition pack version = 项目认知内容。

## 11. 五类服务仓模板规格

统一要求：`AGENTS.md`/`CLAUDE.md`、`service.json`（含 type、模板版本、cognition pack 版本）、`sdlc/`（采集器 + session-log 协议）、`sync/`（报告）、`.github/workflows/`（collect）、自身 SDLC 变更循环。

| 类型 | 技术栈 | 特有产物 |
|---|---|---|
| **infra** | Terraform + Helm + Flux | overlay、镜像策略、变更影响面记录 |
| **gateway** | Spring Boot 4 + Cloud Gateway（k8s 发现） | 路由表（同步到 context） |
| **config-server** | Spring Cloud Config | 配置源（同步到 context） |
| **business** | Spring Boot 4 + ArchUnit + Testcontainers `@ServiceConnection` | 现有脚手架 |
| **frontend-vue** | Vue3 + Vite + TS + Pinia + Vitest/Playwright | UI 变更报告 |

## 12. 工具链（方法层面的角色）

| 工具 | 角色 | 触发 | 输入→输出 |
|---|---|---|---|
| `new-project` | 生成管理仓骨架 | 人 | 项目名 → `project-management/` |
| `new-service-repo` | 生成服务仓 + 登记 | 人 | 类型+名 → 服务目录 + `services.json` 条目 |
| `collector` | 增量采集 + 上传报告 | commit | 上次 sha→HEAD → report.json + 本服务约束 |
| `analyzer` | 分析报告 → 状态/wiki/沉淀 | 定时/手动 | reports → wiki + knowledge |
| `sync-cognition` | 发布/下发 cognition pack | 人/定时 | pack.json → 服务仓版本锁定 |
| `validate` | 校验注册表/报告/认知一致性 | CI | 全仓 → 通过/失败 |

## 13. 测试管理方法

- **项目级**：测试计划、需求↔测试矩阵、E2E/验收用例、质量门禁（覆盖率下限、首次 CI 通过率、逃逸缺陷）。
- **服务级**（回灌）：单测/集成数量与通过率、覆盖率、失败用例。
- **闭环**：每起事故 → 新增一条 eval 用例（进入测试管理的回归集）。

## 14. 技术管理方法

- **ADR**：每个重要决策一份（提议→接受→废弃），从服务仓回灌、在 `knowledge/context/` 与 `wiki/decisions.md` 汇聚。
- **架构变更**：`CHG-*` 记录（改了什么、为什么、影响面）。
- **技术使用/架构遵循**：分析器从报告里算"用了哪些依赖/框架""是否越层/绕过约束"，进 wiki。

## 15. 开发管理方法

- **服务注册表** `services.json`：名字、类型、仓库、阶段、需求状态、模板/认知版本。
- **每服务状态**：已完成需求、进行中需求、阻塞项。
- **登记时机**：`new-service-repo` 创建时即登记；之后由报告持续更新。

## 16. 认知自迭代的度量与防退化

- **度量**：重复错误率、约束命中率、需求实现率、首次 CI 通过率、认知覆盖率（有约束覆盖的服务/流程）。
- **防退化**：认知必须有 owner 与 provenance；超过 N 次未命中的约束标 `retired`；报告去重；歧义走人工；变更走 PR。

## 17. 实施路径（方法层面）

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P1** | 5 模板 + 生成器 + 管理仓骨架 + 采集/分析契约（本地） | demo 项目跑通"执行→报告→分析→wiki" |
| **P2** | 管理仓 `analyze-reports` 定时/手动 + 上传通道 | 定时/手动各触发一次 |
| **P3** | cognition pack 版本化 + 服务仓锁定/升级 | 一条约束从报告进入服务仓 |
| **P4** | 测试管理 + 认知看板 | 测试与认知 wiki 自动更新 |

## 18. 待你确认的点

1. 上述"完整方法"是否定稿？
2. 那 3 个 schema 草稿**保留**（作为契约）还是**删除**（等你点头再落）？
3. 定稿后是否按 **P1** 开始实现？

你确认后我再动手。
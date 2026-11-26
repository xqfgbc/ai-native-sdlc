# AI-Native SDLC 框架 · 设计方案（v4 定稿）

> **定位**：本文件是**设计方案基线**（P1 实施依据）。需求、当前仓库状态、交接清单见 `HANDOVER.md`；本文只讲"设计成什么样、为什么"。
> **修订依据**：两轮专家评审——
> - 评审 ①（符合性 + 阻塞项）：关闭 3 个阻塞项（schemas、采集分工、D8 规范源、报告管道），吸收版本落位/secrets 脱敏/DORA/policy-as-code/CODEOWNERS/Spec Kit 等补强。
> - 评审 ②（三子目标）：确认"AI 管 AI / AI 检查 AI"须保留人类门禁 + 确定性校验，补 4 个挂载点（pack 人工签核、跨模型族评审、analyzer 自审、hash 链）。
> **状态**：可作为 **P1 动工基线**（两轮评审均给出"可进入 P1"）。

---

## 1. 设计目标与边界

### 1.1 三个子目标

1. **AI 管 AI（治理）**：cognition pack 版本化 + 服务仓锁定、execution append-only、7 个子代理角色分离、歧义/风险人工。
2. **AI 检查 AI（验证）**：verifier / security-auditor / pr-reviewer 独立会话，叠加 CI + ArchUnit + Testcontainers + hooks 确定性校验。
3. **一切为了 AI 理解与实施**：cognition pack + 实时 wiki + services.json + session-log + skill 规范源，让 AI 拿到的上下文是"被治理过、最新、可追溯"的。

### 1.2 设计边界（硬约束）

> 结论：三子目标能力上均成立，但**不做 100% 自治闭环**。

- **自评偏差**：模型评估自己刚产出的动作会偏宽松 → **agent 不批准自己**。
- **共模盲区**：writer 与 reviewer 同模型族会继承相同偏见、在都错处达成一致 → **跨模型族评审**（D20）+ 人类门禁。
- **共识 ≠ 正确**：两个 agent 收敛"无 blocking"不证明正确；"AI reviewed" 会诱发人类降低审查强度 → **确定性校验是最终裁决**。
- **结构性保险（本设计内建）**：
  1. agent 不批准自己（CODEOWNERS 硬化）；
  2. 确定性优先（hooks / CI Schema / ArchUnit 为最终裁决，AI reviewer 只做广度）；
  3. append-only 审计 + **hash 链**（D22）；
  4. **变更门留给人**：项目级 cognition pack / constraint 升 `active` 必须 policy owner 人工签 PR（D19）。

### 1.3 非目标
- 不做跨仓自动建仓/push（D2：本地生成）。
- 不做远端语义检索/RAG（P4+ 可选）。
- 不追求"去掉人类也能跑"的完全自治。

---

## 2. 总体架构：三环模型

```
┌──────────── 外环：项目级 SDLC（管理仓 · 人+AI · 门禁）──────────────┐
│ 00 constitution → 01 intent → 02 spec → 03 plan → 04 build → 05 test     │
│                                                        → 06 deploy → 07 maintain │
│        ↑                                                                    │       │
│        └──────────────── 07 maintain 产生新 intent（闭环）─────────────────┘       │
└────────────────────────────▲──────────────────────────────┬─────────────────────────┘
            读约束/技能        │                            │ 下发阶段任务
                               │                            ▼
┌──────────── 内环：AI 真实执行（服务仓）────────────────────────────────────┐
│ 每阶段：做了什么 / 和 AI 交流了什么 / 纠正了什么 / 遵守或违反了哪些规则       │
│ commit 时增量采集 → 确定性 facts + AI 候选认知 → 报告上传（幂等）            │
└────────────────────────────┬────────────────────────────────────────────────┘
                            │ 定时/手动分析 + 蒸馏（AI 产 candidate）
                            ▼
┌──────────── 沉淀环：项目认知（约束/技能/教训/项目事实）──────────────────┐
│ constraints · skills · lessons · context（版本化 + 溯源 + owner）            │
│ → 人工签核 → cognition pack 新版本 → 服务仓锁定升级 → 下一次执行更聪明       │
└──────────────────────────────────────────────────────────────────────────────┘
```

**三层职责**：外环=项目生命周期（人+AI）；内环=服务执行事实（AI）；沉淀环=认知（AI 产候选、人签核）。

---

## 3. 仓库拓扑

| 仓库 | 角色 | 生成方式 |
|---|---|---|
| 框架仓（本仓库） | 模板 + 生成器 + 公共 skills/hooks | — |
| `project-management` | 控制平面 + 实时 wiki | `new-project`（本地） |
| `infra` | Terraform + Helm + Flux GitOps | 服务模板 `infra` |
| `gateway` | Spring Cloud Gateway | 服务模板 `gateway` |
| `config-server` | Spring Cloud Config | 服务模板 `config-server` |
| `configuration-data`（prod / devops） | Spring Cloud Config 数据仓（yml） | 服务模板 `configuration-data` |
| `business`（可多个） | Spring Boot 业务服务 | 服务模板 `business` |
| `frontend-vue` | Vue 3 + Vite | 服务模板 `frontend-vue` |

> D2：全部**本地生成**目录；建 GitHub 远端仓由人执行。

---

## 4. 项目管理仓（控制平面）结构

```
<project>-control-plane/
├── AGENTS.md / CLAUDE.md          # 外层规则 + 会话协议
├── README.md                      # wiki 首页（生成）
├── loop/                          # 【外环】项目级 SDLC
│   ├── 00-constitution.md         # 项目宪法（02/03 门禁引用）
│   ├── 01-intent/                 # 客户意图
│   ├── 02-spec/                   # 需求 + 页面设计 + 功能/架构设计(+ADR) + clarify
│   ├── 03-plan/                   # 项目计划 + 服务拆分
│   ├── 04-build/                  # services.json + 各服务状态
│   ├── 05-test/                   # 测试计划/矩阵/结果
│   ├── 06-deploy/                 # 发布记录/审批
│   └── 07-maintain/               # 事故 → 新 intent
├── execution/                     # 【内环】执行事实（append-only）
│   ├── <stage>/<service>/reports/<toSha>.json   # 含 prevHash 哈希链
│   └── analysis/<ts>.json          # analyzer 输出（D21 进同一审计链）
├── knowledge/                     # 【沉淀环】
│   ├── constraints/ skills/ lessons/ context/
│   ├── proposals/                 # AI 产 candidate，待人工签
│   └── pack.json                  # cognition pack（版本化）
├── wiki/                          # 【生成】index/services/decisions/testing/cognition
├── sync/
│   ├── schemas/                   # 与框架仓 schemas/ 同源
│   └── state.json
└── .github/
    ├── workflows/analyze-reports.yml   # cron + workflow_dispatch
    └── CODEOWNERS
```

---

## 5. 外环 7 阶段规格

| 阶段 | 触发 | 产物 | 人类门禁 | 度量 |
|---|---|---|---|---|
| 00 constitution | 项目启动 | 项目宪法（不可协商原则） | 架构师/项目负责人签署 | — |
| 01 intent | 客户/PM 提出 | `intent.md`（客户原话） | 客户/PM 接受 | 意图→提交时长 |
| 02 spec | intent 接受 | 需求 + 页面设计 + 功能/架构设计 + ADR + **clarify 清单** | PM + 架构师签署 | spec 返工率 |
| 03 plan | spec 接受 | 项目计划 + 服务拆分（引用 constitution） | 技术负责人接受 | 计划偏差 |
| 04 build | plan 接受 | 服务仓 + `services.json` + 状态 | 每服务 PR code owner | 首次合并率 |
| 05 test | 持续 | 测试计划 + 需求↔测试矩阵 + 结果 | QA 门禁 | 首次 CI 通过率、逃逸缺陷 |
| 06 deploy | 测试通过 | 发布记录 + 授权 + 回滚演练 | 发布经理授权 | 部署频率、失败率 |
| 07 maintain | 告警/事故 | 事故记录 → **新 intent** | 值班分诊 | 击穿→intent 时长、MTTR |

**关键机制**：
- `07 maintain` 写回 `01 intent`，闭环。
- `02 spec` 的 **clarify**：代理先列歧义问题清单再定稿（与 D5 事后蒸馏互补）。
- 阶段产物是**提交的 artifact**，commit 链 = 审计轨迹（忠实 Playbook）。

---

## 6. 内环：采集与执行报告

### 6.1 采集分工（评审①阻塞项 2 的关闭）

| 产出 | 来源 | 是否用 AI |
|---|---|---|
| facts.commits / filesChanged | `git log` / `git diff --name-status` | 否 |
| facts.layers | 路径规则（api/core/adapters…） | 否 |
| facts.tests | Gradle 测试报告 XML | 否 |
| facts.architectureSignals | ArchUnit 输出 / import 扫描 | 否 |
| facts.dependencies | version catalog diff | 否 |
| interactions / candidateKnowledge | session-log + facts，**AI 摘要** | 是（强制 evidenceRef；无证据→丢弃/needs_review） |
| review.status | **确定性规则** | 否（AI 不自判） |

**`needs_review` 判据（确定性、可复现）**：无 evidenceRef；改动文件数超阈值；触碰受保护路径；与 active 约束冲突；非平凡改动缺 session-log；跨服务影响。

### 6.2 执行报告契约

```
metadata: service, repo, type, agent, trigger, fromSha, toSha, createdAt, prevHash
spec:
  stage
  requirementRefs[]
  facts { commits, filesChanged, layers, tests{unit,integration,coverage,failed}, architectureSignals, dependencies }
  interactions[] { type: prompt|correction|decision|question, summary, evidenceRef }
  decisions[] { id, title, status, rationale, adrRef }
  ruleViolations[]
  candidateKnowledge[] { type: constraint|skill|lesson|context, title, proposal, evidenceRefs }
  review { status, reviewer, note }
```

- `prevHash` = 该服务上一条报告 hash → **哈希链**（D22）。
- 字段以 `schemas/execution-report.schema.json` 为准（D11：保留并作为正式契约）。

### 6.3 报告流转、幂等、脱敏

- 服务仓 `.sdlc/config.json`：`{ service, type, managementRepo, lastCollectedSha, cognitionPack:{name,version} }`。
- 采集器产出 `sync/reports/<toSha>.json`。
- **本地上传 = 复制**到 `${managementRepo}/execution/<stage>/<service>/reports/<toSha>.json`。
- **幂等键 = `toSha`**：目标已存在则跳过（D10）。
- **脱敏**：session-log / 报告强制过 `no-secrets`（D18）。
- 增量范围 = `lastCollectedSha..HEAD`。

---

## 7. 管理仓分析（analyzer）

### 7.1 输入 / 输出
- **触发**：cron 定时 或 `workflow_dispatch` 手动（D4）。
- **输入**：各服务仓已上传报告。
- **输出**：
  1. 项目真实状态：需求实现情况（`services.json`）、技术使用、架构遵循、测试情况；
  2. 知识沉淀：`knowledge/` + `knowledge/proposals/`（**只产 proposed**，D19）；
  3. 实时 wiki：`wiki/` 重生成。

### 7.2 analyzer 自我审查（D21）
- analyzer 输出本身也是一份报告（`execution/analysis/<ts>.json`），进同一审计链。
- **定期人工抽检**蒸馏结论；`proposed→active` 前必须人工签。
- **禁止自我循环**：analyzer 不得引用自己产出的 proposed 作为新证据。

---

## 8. 认知沉淀与 cognition pack

### 8.1 提升规则

| 触发 | 沉淀为 |
|---|---|
| 同一纠正/错误 ≥2 次 | constraint |
| 同类流程 ≥3 次 | skill |
| 事故/失败/绕过门禁 | lesson（+eval） |
| 架构事实变化 | context（自动更新） |
| 政策/安全硬规则 | 确定性 gate（hook/CI） |

属性：`id/type/scope/owner/version/provenance/status/enforcement`。

### 8.2 生效边界（D19，关键刹车）
- **服务内约束**：明确→自动、歧义→人工。
- **项目级 cognition pack**：AI 只产 `proposed`；**policy owner 人工签 PR 才 `active`**；analyzer 不得自动提升。

### 8.3 cognition pack 生命周期
- **版本**：语义化（`x.y.z`），每次人工签核生成新版本。
- **消费**：服务仓 `service.json` 锁版本；`AGENTS.md`/skills/hooks 由该版本生成。
- **升级**：管理仓发新版 → 服务仓开 PR 升级（policy owner 批准）→ 进入该服务 AI 上下文。
- **与模板版本区分**：template version = 脚手架形状；cognition pack version = 项目认知内容。

---

## 9. 六类服务模板

每个模板统一包含（D8/D13/D20）：

1. **多 Agent 规范源**：`.agents/skills/`（Agent Skills 标准，规范源）+ `.claude/skills/`（生成副本）+ `.codex/`/`.opencode/` 适配；生成时跑 `validate-skills.sh`。
2. **版本/环境落位**：Boot 4.1.3 / JDK 21 / Gradle + version catalog / AWS PostgreSQL / dev-uat-prod（Flux kustomize overlay）；Java 模板自带 `platform/` 副本。
3. **固定文件**：`AGENTS.md`、`CLAUDE.md`、`service.json`、`sdlc/`（采集器+会话协议）、`sync/`、`.github/workflows/`、`.github/CODEOWNERS`。
4. **交叉评审**：`reviewer` 与 `writer` 用不同模型族（模板参数 `reviewModel`：Codex/DSH/Claude）；标注共模盲区为已知限制。

| 类型 | 技术栈 | 特有产物 |
|---|---|---|
| infra | Terraform + Helm + Flux | overlay、镜像策略、变更影响面 |
| gateway | Boot 4 + Cloud Gateway | 路由表 → context |
| config-server | Spring Cloud Config | 配置源 → context |
| configuration-data | Spring Cloud Config 数据仓（yml） | 按环境分仓（prod / devops） |
| business | Boot 4 + ArchUnit + Testcontainers `@ServiceConnection` | 现有脚手架 |
| frontend-vue | Vue3 + Vite + TS + Pinia + Vitest/Playwright | UI 变更报告 |

---

## 10. 策略执行面与门禁

- **同源 schema**：`schemas/*.schema.json` → `sync/schemas/`。
- **三消费点**：本地 hooks、CI（JSON Schema/Conftest）、validate 工具（D15）。
- **CODEOWNERS**：固化 code owner / release manager 门禁（D16）。
- **治理原则**：fail closed、append-only、最小权限、agent 不批准自己、不隐式升级版本。

---

## 11. 度量

- **DORA 四键**：部署频率、变更前置时间、变更失败率、MTTR（D14）。
- **认知度量**：需求实现率、首次 CI 通过率、重复错误率、约束命中率、认知覆盖率。
- **展示**：`wiki/` 认知看板并列展示。

---

## 12. 评审意见落实对照

### 评审①（符合性 + 阻塞项）

| 评审项 | 落位 |
|---|---|
| 阻塞 1：schemas 去留 | **D11 保留** + §6.2 + §10 |
| 阻塞 2：采集确定性/AI 分工 | **D9** + §6.1（7 行分工表 + 6 条 needs_review） |
| 阻塞 3：D8 规范源未入模板 | **D13** + §9 第 1 条 |
| 阻塞 4：报告流转含糊 | **D12** + §6.3（`.sdlc/config.json`、路径、幂等 toSha） |
| 非阻塞：版本/环境 | §9 第 2 条 |
| 非阻塞：secrets 脱敏 | **D18** + §6.3 |
| 非阻塞：cognition pack P3 | §8.3（P1 预留、P3 落地） |
| 非阻塞：术语 | 统一"三环模型" |
| 业界：Spec Kit | **D17**（constitution + clarify） |
| 业界：DORA | **D14** + §11 |
| 业界：policy-as-code | **D15** + §10 |
| 业界：CODEOWNERS | **D16** + §10 |
| 业界：Agent Skills | D8（已用 `.agents/skills/` 标准） |

### 评审②（三子目标 + 4 挂载点）

| 评审项 | 落位 |
|---|---|
| 挂载 1：pack 人工签核、analyzer 不得自动提升 | **D19** + §8.2 + §7.2 |
| 挂载 2：跨模型族交叉评审 + 共模盲区标注 | **D20** + §9 第 4 条 + §13 |
| 挂载 3：analyzer 自我审查 | **D21** + §7.2 |
| 挂载 4：execution hash 链 | **D22** + §6.2 |
| 三子目标与结构性保险 | §1.1 + §1.2 |

---

## 13. 已知限制（不做掩盖）

1. **共模盲区**：writer/reviewer 同模型族时无法消除，D20 参数化缓解。
2. **AI 自评偏差**：即使跨模型族，reviewer 仍非最终裁决，确定性校验兜底。
3. **蒸馏噪声**：AI 摘要可能误判，D19 人工签核 + D21 抽检。
4. **本地生成阶段**：无跨仓权限机制，靠文件约定模拟。
5. **远端语义检索**：P4+ 再设计，当前 wiki 全量生成。

---

## 14. 实施路线

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P1** | 6 模板 + 生成器 + 管理仓骨架 + 采集/分析契约（本地，含 hash 链字段） | demo 项目 + 3 服务仓，跑通"执行→报告→分析→wiki" |
| **P2** | analyze-reports 定时/手动 + 上传通道 | 定时/手动各触发一次 |
| **P3** | cognition pack 版本化 + 服务仓锁定/升级（本地 diff 模拟） | 一条约束从报告进入服务仓 hooks/skills |
| **P4** | 测试管理 + 认知看板（DORA） | 测试与认知 wiki 自动更新 |

---

## 15. 验收标准（P1）

1. `new-project` 生成管理仓骨架（含 loop/execution/knowledge/wiki/sync）。
2. `new-service-repo` 生成服务仓并登记 `services.json`。
3. 服务仓 commit → 采集器产出报告（facts 确定性、candidateKnowledge 带 evidenceRef、prevHash）。
4. 报告上传管理仓（幂等）→ analyzer 生成 wiki + proposals（不自动 active）。
5. `validate` 校验注册表/报告/pack 一致性通过。
6. `bash scripts/selftest.sh`（71 项）+ `validate-skills.sh` 绿。

---

## 16. 设计决策登记

完整 D1–D22 见 `HANDOVER.md` §3；要点：D1 cognition pack、D2 本地生成、D3 commit 采集、D4 定时/手动分析、D5/D19 生效边界、D9 确定性/AI 分工、D10 幂等、D11 schemas 保留、D12 报告流转、D14 DORA、D15 policy-as-code、D16 CODEOWNERS、D17 Spec Kit、D18 脱敏、D20 跨模型族、D21 analyzer 自审、D22 hash 链。

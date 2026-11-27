# AI-Native SDLC 框架 · 交接手册 v3

> 面向接手者（人 / AI 会话）。本手册汇总**用户对框架的全部需求**、**已确认的设计决策**、**当前仓库状态**、**待办与风险**。
> v2 按专家评审修订（关闭 3 个阻塞项 + 非阻塞补强）；**v3 按"三子目标"评审补 4 个挂载点**：cognition pack 人工签核、跨模型族交叉评审、analyzer 自我审查、execution hash 链。
> 最后更新：2026-11-24

---

## 1. 背景与目标

**来源**：Anthropic《The AI-Native SDLC Playbook》（Louis Claxton，54 页）。核心论点：**代码不再是瓶颈，流程才是**。回答是 AI-Native SDLC：保留控制目标、更换执行方式，把线性流水线变成以 AI 为中心的循环，人类在"环之上"判断与问责。

**用户愿景**：做一个**软件项目 SDLC 的 Framework**（不是真实项目），覆盖**需求收集 → 设计 → 开发 → 测试 → 部署上线 → 维护**全生命周期，**以 AI 为主、围绕 AI 组织**。框架要能**生成真实项目**，并**强有力地约束 AI 行为**。

---

## 2. 需求清单

### 2.1 框架定位
- 要的是 **framework**，不用真实创建项目；但必须**能生成真实项目**、**强约束 AI 行为**。
- 原型中没用的文件要删除，缺失内容按需求补齐。

### 2.2 多 AI Agent 支持
- 支持 **Codex、DeepSeek Harness、opencode、Claude Code** 等；一套规范源 + 按 agent 适配。

### 2.3 技术栈（硬性）
- Spring Cloud **2025.1.5** + Spring Boot **4.1.5**（实际不存在→4.1.3，D7）+ **JDK 21**。
- **AWS EKS**；**Flux CD + GitOps**（**双仓**）；**GitHub Actions**；**GitHub**。
- **K8s 原生发现**（不用 Eureka）；**AWS PostgreSQL**；**dev/uat/prod**；**Gradle**；**Spring Cloud Config**。

### 2.4 多仓项目工厂
- 以本框架为模板，每个新项目生成一个**项目实例**。
- 实例中管理：**客户意图、真正的需求、页面设计、功能/架构设计**。
- 通过模板分别创建微服务，**每个微服务是单独 repo**（本地生成，D2）。
- **6 类服务模板**：基础设施（Helm/Terraform/GitOps）、gateway、config server、配置数据（prod/devops 分仓）、业务服务、前端（Vue）。
- 生成服务时**登记到开发管理**；服务状态/技术决策/架构变更**自动同步回管理仓**，闭环。
- **测试管理**纳入管理仓。

### 2.5 三环模型（术语统一：外环 / 内环 / 沉淀环）
- **外环（项目级）**：完整 SDLC `intent → spec → plan → build → test → deploy → maintain`。
- **内环（服务级）**：每阶段 AI 真实执行——做了什么、和 AI 交流了什么、哪些规则 → **沉淀为约束/skills**。
- **沉淀环**：项目认知，让 AI 认知**自我迭代**。

### 2.6 采集 / 分析 / 闭环
- 客户端（服务仓）**commit 时增量采集**（上次采集 sha → HEAD）：AI 操作、人给的指令、真实实现，**分类与总结**。
- 值得作为项目层面真实行为与经验的：**形成本服务约束**并**自动传给管理仓**。
- 管理仓**定时/手动**分析上传报告 → 项目真实情况 + 知识沉淀 wiki。
- **蒸馏有歧义→人工；否则自动**（项目级 pack 例外，见 D19）。
- 管理仓 = **实时自动更新、掌握项目最新最全知识的 wiki**。

### 2.7 参考与学习
- 从 GitHub 收集开源 AI 开发用例完善 skills/agents（已完成 `research/`）。
- 指定学习：`piomin/claude-ai-spring-boot`、`github/awesome-copilot`。

### 2.8 三个子目标与结构性保险
- **目标**：AI 管 AI（治理）、AI 检查 AI（验证）、一切为了 AI 理解与实施项目。
- **结论**：三者能力上均成立；但"AI 管 AI / AI 检查 AI"**必须保留人类门禁 + 确定性校验**，不做 100% 自治闭环。
- **为什么必须有保险**：① **自评偏差**（模型评自己刚产出的动作会偏宽松）；② **共模盲区**（writer 与 reviewer 同模型族会继承同样偏见、在都错处达成一致）；③ **共识≠正确**（"AI reviewed" 会诱发人类降低审查强度，且 AI 协作 PR 缺陷密度更高）。LLM judge 自身判决不稳定（重跑/辩论会翻转且多偏离正确）。
- **结构保险（本框架已具备或补强）**：
  1. **agent 不批准自己**（CODEOWNERS 硬化）；
  2. **确定性优先**：hooks / CI / JSON Schema / ArchUnit 是最终裁决，AI reviewer 只做广度覆盖；
  3. **append-only 审计** + **hash 链**（D22）；
  4. **变更门留给人**：cognition pack / 项目级 constraint 升 `active` 必须 policy owner 人工签 PR（D19）。

---

## 3. 已确认的设计决策

| # | 决策 | 结论 |
|---|---|---|
| D1 | 服务仓认知配置 | **cognition pack**（管理仓版本化，服务仓 `service.json` 锁版本，PR 升级） |
| D2 | GitHub 自动化 | **只做本地生成** |
| D3 | 采集触发 | **commit 触发（客户端增量）** |
| D4 | 分析触发 | **管理仓定时 / 手动** |
| D5 | 蒸馏生效 | **歧义人工，否则自动**（服务内；项目级 pack 见 D19） |
| D6 | 同步方向 | **客户端 push 报告 + 管理仓下发 cognition pack** |
| D7 | 版本修正 | Spring Boot **4.1.3**、Cloud **2025.1.5**、JDK 21 |
| D8 | 多 Agent 规范源 | `.agents/skills/` 规范源；`.claude/skills/` 生成副本；`validate-skills.sh` 校验 |
| D9 | 采集分工 | **facts 100% 确定性**；`candidateKnowledge` 仅 AI 摘要且**强制 evidenceRef**；`review.status` 确定性规则判定 |
| D10 | 报告幂等 | 幂等键 = **`toSha`** |
| D11 | schemas 去留 | **保留**，升级为正式契约（`sync/schemas/`），CI/validate 同源 |
| D12 | 报告流转 | 服务仓 `sync/reports/<toSha>.json` → 管理仓 `execution/<stage>/<service>/reports/<toSha>.json`（§4.7） |
| D13 | 模板统一要求 | 多 agent 规范源 + 版本/环境落位（§4.8） |
| D14 | 度量 | 对齐 **DORA 四键** |
| D15 | 策略执行面 | **hooks + CI(Schema/Conftest) + validate 三处同源 schema** |
| D16 | 门禁硬化 | 人类门禁 **CODEOWNERS** 固化 |
| D17 | Spec Kit 对齐 | `loop/00-constitution.md` + spec 阶段 **clarify** |
| D18 | 脱敏 | 采集器对 session-log / 报告强制过 **no-secrets** |
| **D19** | **认知生效边界** | **服务内约束**：明确→自动、歧义→人工；**项目级 cognition pack**：AI 只产 `proposed`，**policy owner 人工签 PR 才 `active`**，analyzer 不得自动提升 |
| **D20** | **交叉评审** | 模板允许 **writer 与 reviewer 使用不同模型族**（Codex ↔ DSH ↔ Claude）；"共模盲区"列为已知限制 |
| **D21** | **analyzer 自审** | analyzer 输出本身也进审计链，需**定期人工抽检**，防蒸馏自我循环 |
| **D22** | **防篡改** | `execution/` 报告增加 **hash 链（prevHash）** |

---

## 4. 目标架构

### 4.1 仓库拓扑

```
框架仓（本仓库）            → 模板 + 生成器 + 公共 skills/hooks
project-management 仓       → 控制平面 + 实时 wiki
infra 仓                    → Terraform + Helm + Flux GitOps
gateway 仓                  → Spring Cloud Gateway
config-server 仓            → Spring Cloud Config
configuration-data 仓       → Spring Cloud Config 数据（prod / devops 分仓）
business 仓（可多个）        → Spring Boot 业务服务
frontend-vue 仓             → Vue 3 + Vite
```

### 4.2 项目管理仓结构

```
<project>-control-plane/
├── AGENTS.md / CLAUDE.md
├── README.md                     # wiki 首页（生成）
├── loop/                         # 【外环】项目级 SDLC
│   ├── 00-constitution.md        # 项目宪法（02/03 门禁引用）
│   ├── 01-intent/                # 客户意图
│   ├── 02-spec/                  # 需求 + 页面设计 + 功能/架构设计(+ADR) + clarify
│   ├── 03-plan/                  # 项目计划 + 服务拆分
│   ├── 04-build/                 # services.json + 各服务状态
│   ├── 05-test/                  # 测试计划/矩阵/结果
│   ├── 06-deploy/                # 发布记录/审批
│   └── 07-maintain/              # 事故 → 新 intent
├── execution/                    # 【内环】AI 执行事实（append-only）
│   └── <stage>/<service>/reports/<toSha>.json   # 含 prevHash 哈希链
├── knowledge/                    # 【沉淀环】constraints/skills/lessons/context
│   ├── proposals/                # 待人工评审（AI 只产 proposed）
│   └── pack.json                 # cognition pack（版本化）
├── wiki/                         # 【生成】index/services/decisions/testing/cognition
├── sync/
│   ├── schemas/
│   └── state.json
└── .github/
    ├── workflows/analyze-reports.yml
    └── CODEOWNERS
```

### 4.3 外环 7 阶段

| 阶段 | 产物 | 人类门禁 |
|---|---|---|
| 00 constitution | 项目宪法（不可协商原则） | 架构师/项目负责人签署 |
| 01 intent | 客户意图 `intent.md` | 客户/PM 接受 |
| 02 spec | 需求 + 页面设计 + 功能/架构设计 + ADR + **clarify 问题清单** | PM + 架构师签署 |
| 03 plan | 项目计划 + 服务拆分（引用 constitution） | 技术负责人接受 |
| 04 build | 服务仓 + `services.json` 注册 + 状态 | 每服务 PR code owner |
| 05 test | 测试计划 + 需求↔测试矩阵 + 结果 | QA 门禁 |
| 06 deploy | 发布记录 + 授权 + 回滚演练 | 发布经理授权 |
| 07 maintain | 事故记录 → **新 intent** | 值班分诊 |

**闭环**：`07 maintain` 写回 `01 intent`。**02 spec 的 clarify**：代理先列歧义问题清单再定稿。

### 4.4 执行报告契约

`metadata`（service/repo/type/agent/trigger/fromSha/toSha/createdAt/**prevHash**）+ `spec`（stage、requirementRefs、facts[commits/filesChanged/layers/tests]、interactions[prompt|correction|decision|question]、decisions、ruleViolations、candidateKnowledge、review[status/reviewer/note]）。

- `prevHash` = 该服务上一条报告的 hash，形成**哈希链**（D22），强化 append-only 防篡改。
- **字段以 `schemas/execution-report.schema.json` 为准。**

### 4.5 认知沉淀规则

| 触发 | 沉淀为 |
|---|---|
| 同一纠正/错误 ≥2 次 | constraint |
| 同类流程 ≥3 次 | skill |
| 事故/失败/绕过门禁 | lesson（+eval） |
| 架构事实变化 | context（自动更新） |
| 政策/安全硬规则 | 加确定性 gate |

属性：`id/type/scope/owner/version/provenance/status(proposed→active→retired)/enforcement(advisory|deterministic)`。

**生效边界（D19）**：**服务内约束**明确→自动、歧义→人工；**项目级 cognition pack 一律 `proposed` → 人工签 → `active`**，analyzer 只产 candidate。

### 4.6 采集器：确定性 vs AI 分工

| 产出 | 来源 | 是否用 AI |
|---|---|---|
| facts.commits / filesChanged | `git log` / `git diff --name-status` | 否 |
| facts.layers | 路径规则（api/core/adapters/…） | 否 |
| facts.tests | Gradle 测试报告 XML | 否 |
| facts.architectureSignals | ArchUnit 输出 / import 扫描 | 否 |
| facts.dependencies | version catalog diff | 否 |
| interactions / candidateKnowledge | session-log + facts，**AI 摘要** | 是（强制 evidenceRef；无证据→丢弃或 needs_review） |
| review.status | **确定性规则** | 否（AI 不自判） |

**`needs_review` 判据（确定性、可复现）**：无 `evidenceRef`；改动文件数 > 阈值；触碰受保护路径；与 `active` 约束冲突；非平凡改动缺 session-log；跨服务影响。

### 4.7 报告流转管道与幂等

- 服务仓 `.sdlc/config.json`：`{ service, type, managementRepo, lastCollectedSha, cognitionPack:{name,version} }`。
- 采集器产出 `sync/reports/<toSha>.json`。
- **本地"上传"= 复制**到 `${managementRepo}/execution/<stage>/<service>/reports/<toSha>.json`。
- **幂等**：目标文件已存在（同 `toSha`）则跳过。
- **P2+ 远端**：同路径开 PR；报告自动合并，约束变更走人工。
- 增量范围 = `lastCollectedSha..HEAD`。

### 4.7.1 analyzer 自我审查（D21）

- analyzer 的分析输出本身也是一份报告（`execution/analysis/<ts>.json`），进同一审计链。
- **定期人工抽检** analyzer 的蒸馏结论；`proposed→active` 前必须人工签（D19）。
- **禁止自我循环**：analyzer 不得引用自己产出的 `proposed` 作为新证据。

### 4.8 模板统一要求（D8 + 版本/环境 + D20）

每个服务仓模板必须包含：

1. **多 Agent 规范源**：`.agents/skills/` 规范源 + `.claude/skills/` 生成副本 + `.codex/`/`.opencode/` 适配；生成时跑 `validate-skills.sh`。
2. **版本/环境落位**：Boot **4.1.3** / JDK **21** / Gradle + version catalog / AWS PostgreSQL / dev-uat-prod（Flux kustomize overlay）；Java 模板自带 `platform/` 副本。
3. **固定文件**：`AGENTS.md`、`CLAUDE.md`、`service.json`、`sdlc/`、`sync/`、`.github/workflows/`、`.github/CODEOWNERS`。
4. **交叉评审（D20）**：`reviewer` 与 `writer` 使用**不同模型族**（模板参数 `reviewModel`，可切 Codex/DSH/Claude）；文档标注"共模盲区"为已知限制。

### 4.9 度量（DORA 四键）
部署频率、变更前置时间（commit→deploy）、变更失败率、MTTR；另加需求实现率、首次 CI 通过率、重复错误率。wiki 认知看板并列展示。

### 4.10 策略执行面（D15/D16）
- **同源 schema**：`schemas/*.schema.json` → 管理仓 `sync/schemas/`。
- 三消费点：**本地 hooks**、**CI（JSON Schema/Conftest）**、**validate 工具**。
- **CODEOWNERS** 固化 code owner / release manager 门禁。

---

## 5. 当前仓库状态

### 5.1 当前状态（P1–P4 + poteto 增强，2026-11）

本仓库已从"单仓原型"改造为**多仓工厂**：

| 类别 | 现状 |
|---|---|
| 指令 | `AGENTS.md`、`CLAUDE.md`、`REVIEW.md`（已中文化） |
| 技能 | `.agents/skills/` **19 个** |
| 子代理 | `.claude/.codex/.opencode` 各 **8 个**（含 `scanner`） |
| 模板 | `templates/project-management/` + 6 类服务模板 + `_shared` |
| 生成器 | `scripts/new-project.sh` / `new-service-repo.sh`（本地，不建远端仓） |
| 闭环 | `collect.sh` / `analyze-reports.sh` / `promote-proposal.sh` / `sync-cognition.sh` / `upload-report.sh` |
| 验证 | `scripts/selftest.sh`（**122 项**）、`scripts/validate-skills.sh` |
| 护栏 | `hooks/`、`.githooks/`、CI、`autopilot-gate.sh`、`scan-findings.sh` |
| 认知 | proposal → 人工签核 → pack 版本化 → 下发；`repeat` 蒸馏（D4） |
| 情报 | `intake/` + `intake-signal.sh`（Slack/Linear/邮件） |
| 度量 | `wiki/dora.md`（部署频率/变更失败率/lead time/MTTR） |

**已验证**：`bash scripts/selftest.sh` → **122/122**；`validate-skills.sh` OK（25 skills / 8 agents）；
gateway/config-server/business 独立仓 `./gradlew assemble` 通过。

### 5.2 尚未实现 / 用户侧待办

- 远端 GitHub 仓创建与 `MANAGEMENT_REPO`/`SYNC_TOKEN` 配置（用户侧）。
- `frontend-vue` 的 `npm install/build` 本地执行验证。
- DORA MTTR 需 maintain 报告携带 `incident.openedAt/resolvedAt`。
- `business` 模板基础包固定 `com.example.app`（后续可按服务名渲染）。

---

## 6. 实施路线

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P1** | 6 类服务模板 + 生成器 + 管理仓骨架 + 采集/分析契约（本地，含 hash 链字段） | demo 项目 + 3 服务仓，跑通"执行→报告→分析→wiki" |
| **P2** | analyze-reports 定时/手动 + 上传通道 | 定时/手动各触发一次 |
| **P3** | cognition pack 版本化 + 服务仓锁定/升级（本地 diff 模拟） | 一条约束从报告进入服务仓 hooks/skills |
| **P4** | 测试管理 + 认知看板（DORA） | 测试与认知 wiki 自动更新 |

---

## 7. 治理约束

- **门禁 fail closed**；**审计 append-only + hash 链**；**最小权限**。
- **确定性 > 劝导**：能写死的规则进 hooks + CI；**AI reviewer 只做广度覆盖，最终裁决以确定性校验为准**。
- **agent 不批准自己**（CODEOWNERS 硬化）。
- **变更门留给人**：cognition pack 升级、项目级 constraint 升 `active` 必须 **policy owner 人工签 PR**；AI 只产 candidate（D19）。
- **不隐式升级版本**。

---

## 8. 风险与待定

1. Spring Boot 4.1.5 不存在 → 4.1.3。
2. Testcontainers 2.x 命名 → 当前 `postgresql`（1.20.6，已验证）。
3. 跨仓权限（P2+）→ GitHub App / fine-grained token；本地阶段规避。
4. cognition pack 升级（P3）→ P1 预留契约，P3 落"本地 diff 模拟 PR"。
5. **共模盲区**：writer/reviewer 同模型族是已知限制（D20 参数化缓解，不能消除）。
6. Gradle 首次下载慢 → 保留 `.gradle-home` 缓存。

---

## 9. 业界对齐（参考）

- **三子目标能力/缺口**：AI 管 AI ~80%（D19 补 policy owner）、AI 检查 AI ~70%（D20 补跨模型族）、AI 理解/实施 ~95%（远端语义检索 P4+）。
- **结构保险**：自评偏差（Self-Attribution Bias）、共模盲区、共识≠正确、LLM judge 不稳定 → "AI 提速 + 确定性裁决 + 人类变更门"。
- **四支柱**：Context / Knowledge / Collaboration / Governance 均有对应实体（cognition pack+wiki+services.json / knowledge+provenance / AGENTS+skills+sessions / hooks+CI+append-only）。
- **Agent Skills 标准**、**Spec Kit**（constitution+clarify）、**Playbook 忠实度**、**DORA**、**policy as code**、**CODEOWNERS** 已纳入。
- **远期可选（P4 后）**：hash 链增强、MCP server、embedding 检索、Backstage `catalog-info.yaml` 对齐。

---

## 10. 参考文件与来源

- 原始材料：Playbook PDF、`AI-Native-SDLC-Playbook-总结.md`
- 本仓库研究：`research/`（4 份）
- 上游：`piomin/claude-ai-spring-boot`、`github/awesome-copilot`
- 契约：`schemas/*.schema.json`

---

## 11. 交接清单

1. 读 `AGENTS.md` + `CLAUDE.md`。
2. 读本手册 §2–§4（尤其 §4.6 采集分工、§4.7 报告管道、§4.7.1 analyzer 自审、§4.8 模板要求）。
3. 从 **P1** 开始：建 `templates/`、写生成器、落采集/分析契约、demo 跑通闭环。
4. 每阶段跑绿 `./gradlew check` + `validate-skills.sh`，再进下一阶段。

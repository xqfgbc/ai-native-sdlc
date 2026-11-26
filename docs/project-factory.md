# Project factory — 使用指南

本仓库是 **AI-Native SDLC 的工厂/模板仓**：它生成「控制平面仓 + 服务仓」，不承载业务代码。

## 1. 生成一个项目

```bash
scripts/new-project.sh <project> [target-dir]
# 例：scripts/new-project.sh orders ./orders-control-plane
```

产出 `<project>-control-plane/`，包含：

```
loop/                 外环 SDLC（00 constitution → 01 intent → … → 07 maintain）
execution/            内环事实（append-only，含 hash 链）
knowledge/            沉淀环（constraints/skills/lessons/context/proposals/pack.json）
wiki/                 自动生成的实时 wiki
sync/                 契约 schema + 状态
scripts/              自包含的 analyzer/validator（analyze-reports.sh / validate-project.sh）
hooks/ + .githooks/   确定性护栏，生成后已设置 core.hooksPath（重新 clone 需重设）
```

## 2. 生成服务仓

```bash
scripts/new-service-repo.sh <type> <name> <management-repo> [target-dir] [--allow-custom-name]
# 例：scripts/new-service-repo.sh business speaker ./ses-control-plane   # → ./ses-speaker-management
```

6 类 `type`：

| type | 技术栈 | 说明 |
|---|---|---|
| `infra` | Terraform + Helm + Flux | 基础设施仓（GitOps） |
| `gateway` | Spring Boot 4.1.3 + Cloud Gateway | 独立可构建（含 platform/wrapper/checkstyle） |
| `config-server` | Spring Cloud Config | 独立可构建 |
| `configuration-data` | Spring Cloud Config 数据仓（yml） | 按环境分仓：`prod` / `devops` |
| `business` | Spring Boot 4.1.3 + JPA + Testcontainers + ArchUnit | 独立可构建（基础包 `com.example.app`） |
| `frontend-vue` | Vue 3 + Vite + TS | 前端仓 |

### 命名规则（生成器强制）

`<project>` = 控制仓名去掉 `-control-plane`（旧项目名 `<project>-management` 仍兼容）。目录名默认按规则推导；显式 `target-dir` 不符合规则会报错
（`--allow-custom-name` 可绕过）。`--print-name` 只打印推导结果，无副作用。

| 用途 | 规则 | `<project>=ses` 示例 | `name` 参数 |
|---|---|---|---|
| 控制平面（项目管理仓） | `<project>-control-plane` | `ses-control-plane` | — |
| 服务仓（business / frontend-vue） | `<project>-<service>-management` | `ses-speaker-management` | `speaker` |
| gateway | `<project>-<usage>-gateway` | `ses-api-gateway` | `api` |
| infra | `<project>-<cloud>-infra` | `ses-aws-infra` | `aws` |
| config-server | `<project>-config-server` | `ses-config-server` | `config-server` |
| configuration-data | `<project>-<prod\|devops>-configuration-data` | `ses-prod-configuration-data` / `ses-devops-configuration-data` | `prod` / `devops` |

`services.json` 与 `service.json` 的 `name` 用短服务名（`speaker`、`api`、`aws`、`prod-configuration-data`…），
仓库全名写在 `repo` 字段。

生成的服务仓会自动：
- 写入 `service.json`、`.sdlc/config.json`（含 `managementRepo`、`lastCollectedSha`）。
- 复制采集器 `.sdlc/collect.sh`。
- 落地多 agent 规范源：`.agents/skills/` + `.claude/skills/` + `.claude/agents/` + `scripts/validate-skills.sh`。
- 复制确定性护栏 `hooks/` + `.githooks/`，并设置 `core.hooksPath=.githooks`（bootstrap 提交之后启用；
  重新 clone 后需再执行一次 `git config core.hooksPath .githooks`）。
- 在管理仓 `loop/04-build/services.json` **登记**。

## 3. 内环：commit → 报告 → 分析 → wiki

在服务仓里：

```bash
git add -A && git commit -m "[AI-Agent] #N/A feat: ... [learn] <一条值得沉淀的规则>"
bash .sdlc/collect.sh
```

- 采集器增量采集（`lastCollectedSha..HEAD`），产出**确定性 facts**（commits/filesChanged/layers/tests/arch/deps）+ `candidateKnowledge`（来自 `[learn]` 标记），并**幂等上传**到管理仓 `execution/<stage>/<service>/reports/<toSha>.json`，同时推进 **hash 链**（`prevHash`）。
- 在管理仓：

```bash
bash scripts/analyze-reports.sh .
bash scripts/validate-project.sh .
```

- analyzer 生成 `wiki/`、`knowledge/proposals/`（**只产 proposed，不自动 active**，D19）、刷新 `services.json`。
- 人签核 proposal → 更新 `knowledge/pack.json`（cognition pack）→ 服务仓锁定升级（P3 落地）。

## 4. 验证

```bash
bash scripts/selftest.sh        # 框架端到端自测（生成 demo → 采集 → 分析 → 校验）
bash scripts/validate-skills.sh # 技能/agent 配置校验
```

## 5. 当前限制（P1）

- `business` 模板使用固定基础包 `com.example.app`（每仓独立，可接受；后续支持按服务名渲染包名）。
- `frontend-vue` 的 npm 构建内容（package.json/vite/tsconfig/src）待补。
- 远端 GitHub 建仓/跨仓 PR 未自动化（D2：只本地生成）。
- `infra` 模板已含 Terraform/Helm/Flux 内容，但尚未做 Terraform 校验。

## 6. 路线（P1–P4 核心已完成）

- **P2**：collect/analyze 工作流 + 跨仓 PR + 权限（见 `docs/github-automation.md`）。✅
- **P3**：session-log→candidate、proposals 人工签核→pack 版本化、pack 下发。✅
- **P4**：测试管理（`loop/05-test/results.md`）+ DORA 四键（`wiki/dora.md`）。✅
- **待做**：真实远端仓接入（用户侧建仓 + `MANAGEMENT_REPO`/`SYNC_TOKEN`）、frontend-vue 的 `npm install/build` 本地执行验证、DORA 的 lead time/MTTR 精确化（需 deploy/incident 时间戳）。

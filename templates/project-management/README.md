# {{PROJECT}} — 项目控制平面（control plane）

**目的**：本仓是 {{PROJECT}} 项目的控制平面：外环 SDLC 产物（`loop/`）、所有服务仓的执行事实
（`execution/`）、沉淀的认知（`knowledge/`）、自动生成的实时 wiki（`wiki/`）。
**它不是运行时服务，不承载业务代码。**

## 本地使用（“启动”= 生成视图与校验）

前置：bash + jq + git，无需 Java/Node 运行时。

```bash
bash scripts/analyze-reports.sh .    # 读 execution/ 报告，刷新 wiki/、proposals/、测试与 DORA 视图
bash scripts/validate-project.sh .   # 校验 services.json、报告、cognition pack 一致性
bash scripts/intake.sh               # 把 intake/signals 聚成 candidates
```

- 没有报告时 analyzer 输出 `analyze: no reports found`（正常）。
- 看结果：直接打开 `wiki/index.md`（任意 Markdown 渲染器即可）。
- 登记新服务：在框架仓运行 `scripts/new-service-repo.sh <type> <name> <本仓>`。

### 人工签核（Web 工具）

签核必须由人完成；工具只在 127.0.0.1 监听，内部调用 `promote-proposal.sh` / `sync-cognition.sh`：

```bash
python3 scripts/signoff.py            # http://127.0.0.1:8765
```

页面展示 AI 预判（建议/置信度/理由），填写 owner、选择 `deterministic|advisory`；卡片常驻显示将执行的命令，
确认后签核、**驳回**或把 proposal 登记为债务；新 pack 可下发到本地服务仓或对远端仓开 PR（优先 gh；无 gh 时用 `GH_TOKEN` 直连 API；两者都没有则打印网页修改指引）。

驳回会把 proposal 标记为 `status: rejected`（墓碑）：从待签列表移除，`analyze-reports.sh` 不再重建，
`promote-proposal.sh` 拒绝提升它；驳回决定与 AI 预判的一致性照常计入 `review-proposals.sh stats`。
AI 预判为 `reject-duplicate` 时，推荐的动作就是驳回；也可以直接用 CLI：

```bash
bash scripts/review-proposals.sh reject <proposal-id> --owner <你> --reason "duplicate of <active-id>"
```

### 门禁任务与下发（S2）

签核为 deterministic 会自动写入 `loop/04-build/gates/queue.json`：一条规则一条任务（含 `authoringRepo`、
`appliesTo`），不会给每个服务各生成一份。AI 的工作流：

```bash
bash scripts/gate-queue.sh list --status open --json
bash scripts/gate-queue.sh claim G-<proposal-id> --owner <agent>
# 在 control-plane/guardrails/<gate-id>/ 写唯一实现 + manifest.json
bash scripts/gate-queue.sh done G-<proposal-id> --evidence "ArchUnit ... + app-verify test"
bash scripts/sync-project-gates.sh . --check     # 或 --write 下发到 appliesTo 服务
bash scripts/validate-project.sh . --strict      # deterministic 必须有门禁证据
```

`guardrails/<gate-id>/manifest.json`：

```json
{"id":"gate-<proposal-id>","proposalId":"<proposal-id>","appliesTo":["speaker"],
 "files":[{"src":"files/ProjectGateTest.java","dest":"src/test/java/.../ProjectGateTest.java"}],
 "evidence":"bash scripts/app-verify.sh test"}
```

`sync-project-gates.sh` 把 `files[].src` 复制到服务仓的 `dest`；服务只执行，不各自实现。

回填完 deterministic 的门禁证据后，创建 `loop/04-build/gates/strict`（内容随意），本仓 `pre-push`
会自动改用 `validate-project.sh --strict`；没有这个 marker 时仍只告警，避免历史条目阻塞推送。

S1 证据汇总：

```bash
bash scripts/local-cognition-report.sh . --json   # 覆盖率/stale/提升候选，同时刷新 wiki/local-cognition.md
```

### 认知如何到达 AI

签核后的 active 条目会在 `sync-cognition.sh` 时渲染进服务仓的 `CLAUDE.md` / `AGENTS.md`
（managed block，勿手改），并在 Claude Code 会话开始时由 `hooks/cognition-context.sh` 注入上下文；
Agent 也可随时查询：

```bash
bash scripts/cognition.sh list --json
bash scripts/cognition.sh context
```

deterministic 条目由 hook/ArchUnit/lint/CI 强制，advisory 条目靠注入与评审执行。

服务本地规则（S1）不进入 `knowledge/pack.json`：它们在服务仓用 `scripts/local-cognition.sh` 维护，
执行报告只上报 `origin/problem/summary/gate` 证据，不上报规则正文。只有需要多服务统一时才由人写成
`scope=project` 的 proposal 并签核。

`loop/04-build/services.json` 的 `cognitionPack.version` 记录服务**实际采用**的版本（`0.0.0` = 尚未下发）；
`sync-cognition.sh` 下发时同步更新，远端 PR 流程先记为 `pendingVersion`/`pendingPr`；
`validate-project.sh` 在本地能定位到服务仓时校验注册表与 pin 版本是否漂移。

### 债务与复盘

债务表在 `loop/07-maintain/debt/debt.json`，覆盖 intent/design/build/test/deploy/ops/security：

```bash
bash scripts/debt.sh due            # 7 天内到期
bash scripts/debt.sh add --kind tech --title "…" --priority P2 --owner <you> --due YYYY-MM-DD
```

存量服务仓的 hooks/scripts 与框架对齐（默认 dry-run，`--write` 落盘，`--check` 供 CI）：

```bash
bash scripts/sync-guardrails.sh . --source <框架仓> --check
bash scripts/sync-guardrails.sh . --source <框架仓> --write
```

AI 预判与人工决定一致率：

```bash
bash scripts/review-proposals.sh .          # 生成 knowledge/reviews/<id>.json
bash scripts/review-proposals.sh cluster    # 与 active 条目语义聚类，重复项建议 reject-duplicate
bash scripts/review-proposals.sh stats
```

复盘模板：`loop/07-maintain/retro-template.md`；结论必须落成规则/门禁/测试或债务。
定时任务 `knowledge-review.yml` 每日刷新预判与 `debt/DUE.md`，不会自动激活任何条目。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md` + `loop/README.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，
   其他 agent 按 `AGENTS.md` 第 0 步手动执行。
2. **外环流程**：`00 constitution → 01 intent → 02 spec → 03 plan → 04 build → 05 test → 06 deploy → 07 maintain`；
   产物进 `loop/<阶段>/`，状态 `draft → accepted`，每阶段的人类门禁不可跳过。
3. **只写 proposals**：AI 只写 `knowledge/proposals/`；`knowledge/pack.json` 的 active 条目必须人工签核
   （`scripts/promote-proposal.sh`）。
4. **不改 `execution/`**：那是服务仓采集器写入的 append-only 事实；analyzer 只读它。
5. **服务创建**：用框架仓 `new-service-repo.sh` 生成，不要手写模块；仓库命名规则由生成器强制。
6. **验证与提交**：改完跑 `analyze-reports.sh` + `validate-project.sh`；消息遵循 `AGENTS.md §6`；
   `pre-commit`、`commit-msg`、`pre-push`（推送前 `validate-project`）自动执行；`release*` 分支走 PR，
   其他分支可直推但必须先过验证。
7. **发布与下发**：本仓随 git 版本化，`.github/workflows/analyze-reports.yml` 在有新报告时刷新 wiki。
   认知下发：人工签核 → 发布新 pack → `scripts/sync-cognition.sh . ../<service-repo>`。

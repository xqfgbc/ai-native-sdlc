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

页面可查看候选与 provenance、填写 owner、选择 `deterministic|advisory`；卡片常驻显示将执行的命令，确认后签核，
并可把新 pack 下发到本地可用的服务仓。

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

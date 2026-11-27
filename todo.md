# todo.md — 门禁（确定性护栏）现状与改进方向

> 读者：在本框架仓工作的 AI agent 与人类。
> 目标：把"验证优先、环境 > 指令"落成可执行门禁，并记录从 sun-life 项目借鉴到的做法与剩余差距。
> 规则：每条 TODO 有 ID、优先级、现状、要做什么、验收命令。
> **归档**：做完的条目**移出本文件**，整条写入 `todo-archive.md`（保留 ID、完成日期、验证证据）。
> 本文件只保留未完成项，不要用 `[x]` 留在原地。
> 不要用"再加一段 prompt"解决重复问题：同一规则重复两次 → 落成 hook / lint / ArchUnit / CI。

---

## 1. 现在已生效的门禁（事实清单）

| 触发时机 | 门禁 | 实现 | 拦住什么 | 绕过方式 |
|---|---|---|---|---|
| Claude Code 会话开始 | SessionStart | `.claude/settings.json` → `scripts/install-hooks.sh` | 未启用 `core.hooksPath` 的 clone | 接受 workspace trust 后自动执行 |
| agent 编辑文件前 | PreToolUse | `hooks/{no-secrets,protect-paths,spring-guard,test-freeze,production-gate}.sh` | 写入 secret、受保护路径、Boot4/JPA 违规、测试冻结期改测试、无授权部署 | 不能绕过（agent 侧） |
| git commit | `pre-commit` | `.githooks/pre-commit` → `hooks/` 三个脚本 | staged 文件里的 secret / 生成物 / Boot4 违规 | `--no-verify`（需人类明确批准） |
| git commit | `commit-msg` | `.githooks/commit-msg` | 不符合 `AGENTS.md §6` 的提交信息 | 同上 |
| git push | `pre-push` | `.githooks/pre-push` | `release*` 直推需走 PR；其余分支（含 main/master）可直推，但必须先通过本仓验证 | `SDL_SKIP_VERIFY=1`（需在 PR 说明理由；分支规则不可跳过） |
| CI | `framework-selftest.yml` / `agent-evals.yml` | GitHub Actions | 框架自测（120 项）、技能/agent 配置评测 | 无（远端权威） |

`pre-push` 的"本仓验证"按仓类型分派：

- 服务仓：`scripts/app-verify.sh build` + `test` + `lint`（不含需要 Docker 的 itest）
- 控制平面仓：`scripts/validate-project.sh .`
- 框架仓：`scripts/selftest.sh`（120 项）

安装方式：`core.hooksPath` 是**本地配置**；生成器会写入并在 bootstrap 后启用，新 clone 靠 SessionStart 或 `AGENTS.md` 第 0 步恢复。

---

## 2. sun-life 项目的门禁模型（参考实现）

参考文件（在本机 `../sun-life-vibe-coding`，只读借鉴，不要修改）：

- `tools/shared/src/delivery-agent-check.mjs`（`agent-run-check` 实现）
- `tools/shared/src/delivery-agent-run.mjs`（`report.json` 如何被回写门禁消费）
- `standards/agent-run.md`（执行与回写契约）
- `standards/bug-swat.md`（提交范围与"永不 push"规则）
- `OPERATING_GUIDE.md`（执行者视角的操作序列）

它的核心是**命令 + 产物哈希绑定**，而不是自由文本承诺：

1. 设计提示词（`*-agent-run.md`，正文 v3）按工作项声明：改动清单（文件/symbol）、测试文件 + `bash check` 命令、方法逻辑步骤。
2. `agent-run-check --start`：记录提示词 SHA-256、Git 基线、未跟踪文件哈希，并跑一遍自检 + lint 存基线（执行前就失败的不算本轮）。
3. `--red --item N`：**红测门禁**。只允许改测试文件；`bash check` 必须失败，且必须是断言失败——编译错误、找不到模块/symbol、没有测试都不算红（内置关键字识别）。
4. `--item N`：跑第 N 项测试 + 全部自检；**越界检查**（相对基线的改动必须列在第 1..N 项的改动清单里）；**新增 lint 检查**（与基线比对，行号归一后按多重集比较，只有新增算失败）；结果写 `report.json`。
5. 最终运行（不带参数）：全量工作项检查 + 越界/lint + `changedDigest`（基线以来所有变更内容的哈希），生成 `report.json` 与结果草稿。
6. 回写 `completed` 只认 `report.json`：必须是最新 final、`promptSha256` 一致、越界/lint 通过、无失败测试；final 之后代码再改（digest 变化）必须重跑。
7. 代码审查 PASS 绑定最新一轮 results 的 SHA-256；`validate` 对"completed 但没有当前 PASS"报错；同一轮结果只能有一条 PASS/FAIL，最多 5 次 FAIL。
8. 提交纪律：提交只含声明的目录（`bug-commit`），消息 `[<user>] #<BUG-ID> <动作>：<标题>`；**执行 agent 永不 push**，提交后询问人类，人类确认才推。

可直接迁移的原则：

- 门禁读**记录下来的结果**（report/hash），不重新计算、不接受口头声明。
- 校验"变了什么"（范围）与"有没有变坏"（新增 lint/失败测试），而不只是"现在绿不绿"。
- 测试先行（red → green）是确定性门禁，不是建议。
- 报告与提示词/代码版本绑定，版本漂移自动失效。

---

## 3. 差距（我们 vs sun-life）

| 能力 | sun-life | 我们 | 影响 |
|---|---|---|---|
| 提交信息规范 | 有（`[id] #BUG-ID`） | ✅ `commit-msg`（`type(scope): subject`） | 已对齐 |
| 推送前验证 | final check + 报告 | ✅ `pre-push` 跑整仓验证（粗粒度） | 已对齐，但慢且无增量 |
| 测试先行（red） | `--red` 强制 | ❌（仅 `test-freeze` 阻止修 bug 时改测试） | 无法证明"先有失败测试" |
| 改动范围白名单 | 按工作项改动清单 | ❌ | 顺手改无关文件无法自动发现 |
| 新增 lint 才算失败 | 有基线 diff | ❌（整仓"现在是否绿"） | 历史问题会背锅，降低门禁可用性 |
| final 报告与哈希绑定 | `report.json` + digest | ❌（collect 有报告哈希链，但不在提交/推送口） | "跑过了"不可审计 |
| 审查 PASS 绑定结果 | `code-review` | ❌ | 高风险变更缺人工/强模型证据 |
| 提交范围限制 | `bug-commit` | ❌ | 一次提交可混入多个关注点 |
| agent 不 push | 流程强制 + 提问人类 | 仅 `AGENTS.md` 文字约定 | 技术上仍可自行 push |
| CI 权威镜像 | 有 | ✅（框架仓）；SES 服务仓 ❌ 无远端/CI | 本地门禁是唯一防线 |

---

## 4. 改进方向（按优先级；做之前先在 `loop/` 走 intent→spec→plan）

> 选型约束（所有 TODO 都必须满足）：
> - `pre-commit` 不允许依赖网络/Docker，单次耗时 < 2s；重检查放 `pre-push`。
> - 新增门禁必须有 selftest 用例（生成仓库 → 触发 → 断言拦截/放行），并同步 README/CLAUDE/DELIVERY/DESIGN/HANDOVER 的自检计数。
> - 无法确定性判断的规则不要写成门禁，写成 skill/AGENTS 指引。
> - 生成器改动必须同时更新 `templates/` 与存量仓同步方式（见 `scripts/sync-guardrails.sh`，已归档的 TODO-07）。

### 4.0 背景：只 clone 服务仓（无 control-plane）的降级行为

实测对象：`ses-speaker-management`（已推到 GitHub 私有仓），证据来自仓内脚本源码与本地运行。

| 能力 | 单仓是否可用 | 现状与证据 | 风险 |
|---|---|---|---|
| 构建/启动/测试 | ✅ | local profile + H2，不依赖 control-plane | 无 |
| pre-commit / commit-msg / pre-push | ✅ | `hooks/` + `.githooks/` 随仓复制 | 无 |
| SessionStart 自动装 hook | ✅ | `.claude/settings.json` + `scripts/install-hooks.sh` | 无 |
| 技能/子代理 | ✅ | `.agents/skills` 19 个、`.claude/agents` 8 个随仓复制 | 无 |
| `collect.sh` 本地采集 | ⚠️ 降级 | control-plane 目录不存在时走 else 分支：报告留在 `sync/reports/<sha>.json`，**仍推进 `lastCollectedSha`** | 报告滞留后再也不会被采集 |
| 上传到 control-plane | ⚠️ 静默 no-op | `upload-report.sh` 在缺 `GH_TOKEN`/`MANAGEMENT_REPO` 时打印 skipped 并 exit 0 | CI 不会红，但也没人知道闭环断了 |
| analyze / promote / sync | ❌ 缺失 | 三个脚本只在 control-plane 仓 | 知识闭环后半段无法执行 |
| 认知 pack 更新 | ❌ 不更新 | 保持锁定版本（当前 `0.0.0`） | 不影响运行，但认知不增长 |
| 项目级流程（intent/spec/plan → `loop/`） | ❌ 缺失 | control-plane 职责 | 只能做服务内开发 |

三个已知坑：

1. `lastCollectedSha` 在控制平面缺席时仍前进 → 之后的 collect 不会重采这些 commit，也没有本地补传命令。
2. `managementRepo` 在 `.sdlc/config.json` / `service.json` 里是**绝对路径**（`/Users/<user>/.../ses-control-plane`）→
   换机器/换目录即失效，即使 control-plane 存在也不会被找到。
3. `upload-report.sh` 硬编码控制平面默认分支为 `main`（`gh repo clone --branch main`、`--base main`），
   而本项目控制平面默认是 `master` → 配好 token 后远端 PR 仍会失败。

> 2026-11-27：三个坑已修复（TODO-10/11/12 已归档）——managementRepo 按 `SDL_MGMT_REPO` →
> 同级 `<project>-control-plane` → config 解析；采集位/上传位分离并新增 `replay-reports.sh`；
> upload-report 自动探测默认分支。§4.0 保留为问题背景。

### 4.0.1 门禁验证结论（2026-11-26 speaker 实验，原型 `ses-speaker-management/scripts/gate.sh`）

| sun-life 能力 | 本次验证 | 结论 |
|---|---|---|
| `--start` 基线 | `gate.sh start` 记录 HEAD/基线检查 | ✅ 可用 |
| 工作项改动清单 | `gate.sh scope`（暂存越界文件被拒） | ✅ 可用，未接 hook |
| `--red` 红测 | `gate.sh red` 接受断言失败、拒绝编译错误 | ✅ 可用 |
| final 报告 + digest | `gate.sh final` / `verify`（代码变更后 digest 失配） | ✅ 可用 |
| pre-commit 秘密拦截 | 暂存假 AKIA → 提交被拦 | ✅ 已验证 |
| commit-msg 格式 | `bad message` 被拦 | ✅ 已验证 |
| release 分支必须 PR | **发现缺陷**：只看 HEAD，推别的 release 分支可绕过 | ❌→✅ 已修：读取推送 refs，selftest 增回归用例 |
| lint 基线 diff / 报告↔collect 哈希绑定 / 审查 PASS 绑定 | 未实现 | ❌ 仍缺 |

结论：sun-life 的"基线→范围→红测→final+digest"模型可在本框架落地；缺的是与 collect/review 的绑定和
把原型接进 hook。原型状态目录 `.sdlc/gate/`（gitignored），不参与提交。

### 4.1 实施条件评估（2026-11-27）

判定口径：**可实施** = 目标/验收明确、无未决决策、无外部阻塞；
**有条件** = 需先定一个约定/格式或依赖另一条 TODO；**暂不具备** = 依赖外部条件或研究结论。

| TODO | 状态 | 前置条件 / 依赖 | 备注 |
|---|---|---|---|
| 01 范围白名单 | ⚠️ 有条件 | 先定清单格式（`.sdlc/change/<id>.json` vs commit trailer）与"未声明时不拦"的兼容策略 | `gate.sh scope` 原型仅在 speaker，未进框架 |
| 02 验证报告 + 哈希 | ⚠️ 有条件 | 先定 `.sdlc/verify/<sha>.json` schema 与 collect facts 字段（涉及 schema 版本） | 原型 `gate.sh final/verify` 仅在 speaker |
| 03 红测门禁 | ⚠️ 有条件 | 先定与 `CLAUDE_FIX_TASK` 的开关绑定与误报处理 | 原型 `gate.sh red` 仅在 speaker |
| 04 增量验证 + lint 基线 | ⚠️ 有条件 | 需设计 Gradle 变更→测试映射、基线存储与行号归一化 | 无原型，工作量最大 |
| 05 审查 PASS 绑定 | ⚠️ 有条件 | 依赖 02 的 SHA 绑定；需 owner 先定义高风险路径与 `review.md` 格式 | |
| 06 bug-commit 范围 | ⚠️ 有条件 | 与 01 的清单机制保持一致 | 实现本身简单 |
| 08 push 审批技术化 | ⛔ 暂不具备 | 需先调研各 agent 运行时的可识别信号；禁止启发式 | 调研完成前保持文档约定 |
| 09 SES 服务仓 CI | ⚠️ 有条件 | 外部：Actions secrets、分支保护、Testcontainers 运行环境 | 需仓库管理员操作，AI 只能提交 workflow |
| 13 README 独立开发小节 | ✅ 可实施 | 依赖已满足（TODO-10/11 已归档） | 用真实命令写单仓降级/补传步骤 |

**全局前置条件**（每条都适用）：

1. 按 §4 要求先走 `loop/01-intent → 02-spec → 03-plan`，plan 写明改动文件与验证命令；
2. 新增门禁必须带 selftest 用例（当前基线 120 项，改完同步 §1 计数）；
3. 完成后按文件头的归档规则移入 `todo-archive.md`。

**建议顺序**：01 → 03 → 02 → 06 → 05 → 04；13 现在可实施；08/09 等条件满足再启动。

### [ ] TODO-01（P1）变更范围白名单（scope guard）

- 进展（2026-11-26）：`gate.sh scope` 原型已验证（越界文件被拒），待产品化进 `pre-commit`/`pre-push`。

- 现状：`pre-commit` 只看内容违规，不看"这次允许改哪些文件"。
- 建议最小实现：每次变更在 `.sdlc/change/<id>.json`（或 commit trailer `Scope: a,b,c`）声明允许改动的路径 + 验证命令；`pre-commit` 校验 staged 文件 ⊆（声明路径 ∪ 测试 ∪ 文档）；`pre-push` 复用同一清单。
- 验收：
  - 生成的服务仓里，声明 `src/main/java/**` 后，提交 `src/main/java/...` 通过；
  - 同一提交夹带 `docs/other.md`（未声明）→ 被拦，错误信息指出文件与清单；
  - 未提供清单时行为与现在一致（向后兼容，默认不拦）；
  - selftest 增 3 条用例；文档说明清单格式与示例。
- 风险：清单与真实意图脱节 → 清单必须由 plan 生成，或在 PR 模板里显式列出。

### [ ] TODO-02（P1）验证报告与哈希绑定（verify report）

- 进展（2026-11-26）：`gate.sh final` 已产出 `final.json`（检查结果 + 变更内容 digest），`verify` 能发现 final 后改动；
  待并进 `pre-push` 与 `collect.sh` 的 report。

- 现状：`pre-push` 跑完验证只打印结果，不落盘、不可审计。
- 建议：`pre-push` 成功后在 `.sdlc/verify/<HEAD>.json` 记录：`commitSha`、命令、退出码、耗时、环境（JDK/Gradle 版本）、输出摘要哈希；`collect.sh` 把它带进 execution report 的 facts（新增字段需同步 schema）。
- 验收：
  - 推送 feature 分支后存在报告文件，字段符合 schema；
  - 改动代码后未重跑验证，报告与 HEAD 不匹配时 `collect.sh` 标 `needs_review`；
  - `validate-project.sh` 能校验报告完整性；selftest 覆盖。
- 备注：这是 sun-life `report.json` 的最小对等物；先服务仓，再控制平面/框架。

### [ ] TODO-03（P2）测试先行门禁（red-first）

- 进展（2026-11-26）：`gate.sh red` 已验证"断言失败=红、编译错误不算红"；待接进修复流程。

- 现状：修 bug 时 `test-freeze` 只阻止改测试，不能证明测试先红。
- 建议：为服务仓提供 `scripts/red-check.sh`：指定测试类/方法，先跑必须失败（且失败原因是断言），再用 `git` 校验本轮仅改测试文件；接入 `CLAUDE_FIX_TASK=1` 流程与 skill。
- 验收：
  - 未先跑 red 就改实现 → `pre-commit` 或 `app-verify` 报错（开关：`SDL_FIX_TASK=1`）；
  - 编译失败/找不到测试不算红；
  - selftest 覆盖红/非红两类用例。

### [ ] TODO-04（P2）增量验证 + lint 基线

- 现状：`pre-push` 全仓跑 build+test+lint，慢且会把历史 lint 问题算到本次头上。
- 建议：只验证变更模块；lint 与上次成功基线比对，只对本轮新增违规失败（行号归一化，避免噪声）。
- 验收：改动 1 个类时只跑相关测试（Gradle `--tests` / 变更映射）；新增 lint 拦截、既有 lint 放行；耗时对比记录在本文件。

### [ ] TODO-05（P2）代码审查 PASS 绑定（高风险变更）

- 现状：无审查证据链。
- 建议：高风险路径（鉴权、资金、schema 迁移、跨服务契约、生产配置）要求 PR 附 `review.md`（审查者、结论、绑定 commit SHA）；CI 或 `validate-project` 校验存在且 SHA 匹配。
- 验收：高风险变更缺审查 → 合并门禁失败；审查记录 SHA 不匹配 → 失败；低风险变更不受影响。

### [ ] TODO-06（P3）提交范围限制（bug-commit 对等物）

- 现状：一次提交可混入多个关注点。
- 建议：`scripts/bug-commit.sh <bug-dir>` 只允许提交该 bug 相关路径 + 工具重建的索引，并在提交信息里带 `#<BUG-ID>`。
- 验收：范围外文件被拒；消息格式由 `commit-msg` 校验；selftest 覆盖。


### [ ] TODO-08（P3）push 审批技术化

- 现状："agent 不得自行 push" 只有文字约定。
- 建议：研究 agent 运行时可识别的环境变量（Claude Code/Codex/opencode），在 agent 上下文中要求 `SDL_PUSH_APPROVED=1` 才放行；人类终端保持原行为。不可识别时保持文档约定，不要用不可靠的启发式。
- 验收：agent 环境无审批 → 被拦且提示"询问人类"；人类终端正常推送；两种环境的 selftest（用 env 模拟）。

### [ ] TODO-09（P3）SES 服务仓 CI 镜像

- 现状：`ses-control-plane` / `ses-speaker-management` 已有 GitHub 私有远端，但**没有验证 CI**；
  只带了 `collect.yml`（缺 `MANAGEMENT_REPO`/`SYNC_TOKEN` 时上传 no-op），本地 hook 仍是唯一验证门禁。
- 建议：加 GitHub Actions：`app-verify all`（含 Testcontainers）+ `validate-skills`，作为权威门禁；
  本地 hook 只做快速失败；`collect.yml` 的上传步骤保持"未配置即跳过"。
- 验收：PR 上 CI 必跑且失败阻断合并；本地与 CI 的命令一致（同一脚本入口）。




### [ ] TODO-13（P3）服务仓 README 的“独立开发（无 control-plane）”小节

- 现状：模板 README 只描述完整闭环路径，未说明单仓降级行为（见 4.0）。
- 依赖：已满足（TODO-10/11 已归档；`SDL_MGMT_REPO`、`--resolve-mgmt`、`replay-reports.sh` 可直接写进文档）。
- 内容：4.0 的降级表 + 单仓可用的验证命令 + 补传步骤 + 何时必须要有 control-plane。
- 验收：模板 README 与已生成服务仓 README 同步；命令可复制执行；不承诺尚未实现的能力。

---

## 5. AI 接手方式（照做即可）

1. 读本文件 + `AGENTS.md` + `CLAUDE.md`；确认要做的 TODO 未完成。
2. 按框架规则走 `loop/01-intent` → `02-spec` → `03-plan`（小改动可合并，但 plan 必须写清改动文件与验证命令）。
3. 实现时先加 selftest 用例（失败）→ 再实现 → 跑到全绿。
4. 必跑：
   ```bash
   bash scripts/selftest.sh          # 全绿，计数与文档一致
   ./scripts/validate-skills.sh      # OK
   bash -n scripts/*.sh hooks/*.sh   # 语法
   ```
5. 完成条目：把整条从本文件移入 `todo-archive.md`（保留 ID、完成日期、验证证据）；`todo.md` 只保留未完成项；
   同步所有文档里的自检计数。
6. 提交信息遵循 `AGENTS.md §6`；**不要 push**，等人类确认。

---

## 6. 验收命令（通用）

```bash
# 门禁自身
bash scripts/selftest.sh
./scripts/validate-skills.sh

# 真实 push 门禁（本地裸仓，不触网）
git init -q --bare /tmp/gate.git
git remote add gate-test /tmp/gate.git
git checkout -b test/gate && git push gate-test test/gate    # 应通过（先跑验证）
git checkout main && git push gate-test main                 # 应被拦
```

---

## 7. 变更记录

- 2026-11-26：新增 `commit-msg`、`pre-push` 验证；`no-secrets` 修复（内容检测与 stdin 挂起）；业务模板 `ArchitectureTest` 修复 checkstyle；selftest 59 项。
- 2026-11-26：本文件建立，记录 sun-life 门禁模型与 9 项改进方向。
- 2026-11-26：push 规则调整——只有 `release*` 必须走 PR，其余分支（含 main/master）可直推但必须先通过本仓验证；selftest 增 2 条分支策略用例（61 项）。
- 2026-11-26：speaker 实施（JPA + Flyway + Podman PG + W3C tracing）中验证 sun-life 门禁模型：基线/范围/红测/final+digest
  可用，发现并修复 pre-push 只看 HEAD 的绕过缺陷（selftest 62 项）；结论见 §4.0.1。
- 2026-11-26：记录“只 clone 服务仓（无 control-plane）”的降级行为（§4.0），新增 TODO-10～13：
  managementRepo 解析与显式失败、采集位/上传位分离 + 本地补传、upload-report 基线分支、README 独立开发小节；
  并按现状更新 TODO-09（SES 仓已有远端、仍无验证 CI）。
- 2026-11-27：新增 §4.1 实施条件评估（可实施/有条件/暂不具备 + 建议顺序）；完成条目改为归档到
  `todo-archive.md`，本文件不再保留已完成项。
- 2026-11-27：完成并归档 TODO-07（sync-guardrails）、TODO-10（managementRepo 解析）、
  TODO-11（采集/上传分离 + replay-reports）、TODO-12（upload-report 基线分支）；selftest 95 项。
- 2026-11-27：新增驳回流程——`review-proposals.sh reject` 与 signoff 页“驳回”按钮；`status=rejected`
  墓碑不再被 analyzer 重建、promote 会拒绝；selftest 99 项。
- 2026-11-27：知识分层 Phase 1——服务本地认知（S1）`local-cognition.sh`，正文只留服务仓；
  collect 只上报 origin/problem/summary/gate 证据；proposal/pack 增加 scope 校验；selftest 108 项。
- 2026-11-27：知识分层 Phase 2——`gate-queue.sh`（deterministic 签核自动入队）、
  `sync-project-gates.sh`（control-plane/guardrails 一份实现下发）、`local-cognition-report.sh`
  （S1 覆盖率/stale/跨服务提升候选）、`validate-project.sh --strict`；会话只注入一行后台待办；selftest 120 项。
- 2026-11-27：补齐 AI 可发现性——新增 `local-cognition` / `implement-gate` 技能（25 skills），
  存量仓同步技能与 AGENTS/CLAUDE；`validate --strict` 校验项目门禁已下发，`gate-queue done` 拒绝未同步的 gate；selftest 120 项。

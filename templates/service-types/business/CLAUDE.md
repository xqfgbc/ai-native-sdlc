# CLAUDE.md — {{SERVICE}}（{{TYPE}}）

> 完整规则见 `AGENTS.md`。本文件是 Claude Code 的快速入口。

## 提交信息（硬规则）

`[<姓名>] #<卡号> <类型>: <概述>`；无卡号用 `#N/A`；**AI 生成的代码用 `[AI-Agent]`**。
例：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`
`commit-guard`（执行 `git commit` 前）和 `commit-msg`（提交时）会拦截不合规消息。

## 开工

1. 读 `AGENTS.md`；新 clone 的首个会话会自动执行 `scripts/install-hooks.sh`（其他 agent 见 AGENTS 第 0 步）。
2. 按需加载 `.agents/skills/` 技能；没有接受的 plan 不写代码。
3. 跨线程：用注入的 `taskExecutor`（已带 trace/MDC 传播）；禁止裸 `Executors`/`new Thread`/默认池 `CompletableFuture`（ArchUnit 会拦）。
4. 改完先验证：`bash scripts/app-verify.sh all`（itest 需 Docker/Podman），把输出贴进结果。
5. **不要自行 push**；`release*` 分支必须走 PR，其余分支推送前会先跑本仓验证。
6. **延期/受阻**：`bash scripts/debt.sh add --kind <tech|test|ops|security|intent> --title "…" \
   --priority P2 --owner <你> --due YYYY-MM-DD`（登记到控制平面债务表）。

# hooks/ — 确定性护栏

这里的脚本 **agent 无关**。它们在两层运行：

1. **Agent PreToolUse**（动作发生前拦截）—— 经各 agent 的设置接线：
   `.claude/settings.json`、`.codex/hooks.json`。
2. **Git hooks**（拦截坏的 commit/push，对所有 agent 生效）—— `.githooks/`，
   用 `git config core.hooksPath .githooks` 安装。CI 是权威镜像
   （见 `.github/workflows/framework-selftest.yml`）。

生成的服务仓和控制平面仓都会自动带上 `hooks/` + `.githooks/` 并设好 `core.hooksPath`
（bootstrap 提交之后启用）；`core.hooksPath` 是本地配置，**重新 clone 后第一时间运行**
`bash scripts/install-hooks.sh`（幂等）即可恢复——Claude Code 通过 `.claude/settings.json` 的
SessionStart hook 自动执行，其他 agent 见 `AGENTS.md` 会话协议第 0 步。

| 脚本 | 作用 | 模式 |
|---|---|---|
| `no-secrets.sh` | 拦截 diff/编辑中的 secrets | git + PreToolUse |
| `protect-paths.sh` | 拦截对 `build/`、`.gradle/`、生成物的编辑 | git + PreToolUse |
| `spring-guard.sh` | 拦截 Boot 4 之前的 API + 不安全 JPA 配置 | git + PreToolUse |
| `production-gate.sh` | 无 `RELEASE_APPROVAL` 时拦截生产部署 | PreToolUse |
| `test-freeze.sh` | `CLAUDE_FIX_TASK=1` 期间拦截测试编辑 | PreToolUse |
| `session-log-guard.sh` | 会话有实质提交但没写 `sdlc/session-log/` 时阻止结束（一次） | Stop |

这些是"建议性技能"背后的确定性层（见 `AGENTS.md` §1）：技能让违规变少，hook 让违规不可能。

`.githooks/` 三个门禁：

- `pre-commit` → `no-secrets` + `protect-paths` + `spring-guard`（全量 staged 检查）。
- `commit-msg` → 强制 `[<姓名>] #<卡号> <类型>: <概述>`（无卡号 `#N/A`，AI 用 `[AI-Agent]`），保证提交可追溯。
- `pre-push` → 只有 `release*` 分支必须走 PR；其他分支（含 `main/master`）可直推，但推送前必须跑本仓验证：
  服务仓 `app-verify build+test+lint`、控制平面仓 `validate-project`、框架仓 `selftest`；
  只有 `SDL_SKIP_VERIFY=1` 才能显式跳过（并在 PR 里说明理由）。

stdin 读取都有上界：普通文件整读，其他非 TTY 输入只读一行且最多等 1 秒——所以 stdin 是
未关闭的管道时，hook 会退回 git 模式而不是挂起。

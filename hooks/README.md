# hooks/ — 确定性护栏

这里的脚本 **agent 无关**。它们在两层运行：

1. **Agent PreToolUse**（动作发生前拦截）—— 经各 agent 的设置接线：
   `.claude/settings.json`、`.codex/hooks.json`。
2. **Git hooks**（拦截坏的 commit/push，对所有 agent 生效）—— `.githooks/`，
   用 `git config core.hooksPath .githooks` 安装。CI 是权威镜像
   （见 `.github/workflows/framework-selftest.yml`）。

| 脚本 | 作用 | 模式 |
|---|---|---|
| `no-secrets.sh` | 拦截 diff/编辑中的 secrets | git + PreToolUse |
| `protect-paths.sh` | 拦截对 `build/`、`.gradle/`、生成物的编辑 | git + PreToolUse |
| `spring-guard.sh` | 拦截 Boot 4 之前的 API + 不安全 JPA 配置 | git + PreToolUse |
| `production-gate.sh` | 无 `RELEASE_APPROVAL` 时拦截生产部署 | PreToolUse |
| `test-freeze.sh` | `CLAUDE_FIX_TASK=1` 期间拦截测试编辑 | PreToolUse |

这些是"建议性技能"背后的确定性层（见 `AGENTS.md` §1）：技能让违规变少，hook 让违规不可能。

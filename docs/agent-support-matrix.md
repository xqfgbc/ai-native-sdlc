# 多 agent 支持矩阵

框架是 **agent 无关** 的：一套规范源（指令、技能、子代理、hooks）驱动所有受支持的 agent。
本表把每个规范概念映射到各 agent 的原生机制与位置。

## 支持的 agent

| Agent | 读指令 | 技能 | 子代理 | hooks / 护栏 | 无头 CI |
|---|---|---|---|---|---|
| **Claude Code** | `CLAUDE.md`（+ 插件读 `AGENTS.md`） | `.claude/skills/` | `.claude/agents/*.md` | `.claude/settings.json`（PreToolUse） | `claude -p … --output-format json` |
| **Codex**（OpenAI） | `AGENTS.md` | `.agents/skills/`（原生） | `.codex/agents/*.toml` | `.codex/hooks.json`（+ `requirements.toml`） | `codex exec … --json` |
| **opencode** | `AGENTS.md` | `.agents/skills/`（兼容） | `.opencode/agents/*.md` | `.opencode/opencode.jsonc`（policies） | `opencode run … --format json` |
| **DeepSeek Harness** | `AGENTS.md` + `CLAUDE.md` | `.agents/skills/`（原生） | Cordis presets（`cordis.patch.yml`） | Cordis 事件 / 沙箱策略 | `dsh headless …` / `dsh --profile sdk` |

## 规范位置

- **指令**：`AGENTS.md`（治理层，所有 agent）+ `CLAUDE.md`（快速参考）。`AGENTS.md` 是唯一规范源，`CLAUDE.md` 不得与其矛盾。
- **技能**：`.agents/skills/<name>/SKILL.md` —— **Agent Skills 标准**，Codex/opencode/DSH 原生读取。
  `.claude/skills/` 是给 Claude Code 的生成副本（改完技能后跑 `scripts/sync-agent-adapters.sh`）。
- **子代理**：`.claude/agents/` 的 Markdown 为准；`.codex/agents/` 是 TOML 适配；`.opencode/agents/` 是 Markdown 适配；
  DSH 用 Cordis presets（见 `adapters/deepseek-harness/`）。
- **Hooks（确定性层）**：`hooks/*.sh` 是 agent 无关的 bash。三处接线，确保每个 agent 都被约束：
  1. `.githooks/`（git pre-commit/pre-push）—— 通用，用 `git config core.hooksPath .githooks` 安装。
  2. 各 agent PreToolUse 接线：`.claude/settings.json`、`.codex/hooks.json`、`.opencode/opencode.jsonc`（policies）。
  3. CI 镜像（`.github/workflows/framework-selftest.yml`）—— 权威门禁。

## 无头调用（CI / evals / 维护循环）

| Agent | 命令 | 结构化输出 |
|---|---|---|
| Claude Code | `claude -p "<prompt>" --allowedTools … --output-format json` | JSON |
| Codex | `codex exec "<prompt>" --sandbox workspace-write --json` | JSON Lines |
| opencode | `opencode run "<prompt>" --format json --auto` | NDJSON |
| DSH | `dsh headless "<prompt>"`（或 `dsh --profile sdk`） | text / SDK |

`evals/run.py --agent <name>` 可通过上述任一方式跑评测集，因此每个 agent 的配置都被回归测试（见 `evals/README.md`）。

## 编辑约定

- 在 `.agents/skills/` 改技能，然后跑 `scripts/sync-agent-adapters.sh`。
- 在 `.claude/agents/` 改子代理行为，并同步到 `.codex/agents/` 与 `.opencode/agents/`（文件小、可并行）。
- Hooks 只在 `hooks/` 写一次；各 agent 文件只负责"接线"，保证护栏逻辑单一来源。
- 不要手改生成的适配文件；始终用同步脚本重新生成。

## 某些 agent 没有原生等价物时

- **opencode** 没有声明式 PreToolUse 钩子文件；用 `.opencode/opencode.jsonc` 的 `policies`（硬拒绝）+ git hooks 兜底。
- **DSH** 没有声明式钩子文件；护栏是 Cordis 事件/沙箱策略。git hooks + CI 镜像仍是 DSH 会话的权威护栏。
  示例 bundle 在 `adapters/deepseek-harness/`。

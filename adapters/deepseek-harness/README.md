# DeepSeek Harness (DSH) 适配

DSH 是基于 Cordis 的桌面 harness。**指令与技能无需适配**——它原生读取：

- **指令**：`AGENTS.md` + `CLAUDE.md`（`@deepseek-ai/dsh-agent-instructions` 插件从仓库根加载项目链）。
- **技能**：`.agents/skills/<name>/SKILL.md`（Agent Skills 标准——DSH 原生发现该目录，顺序 `.dsh/skills` → `.agents/skills`）。

DSH **不能**原生消费的是 **Markdown 子代理** 与 **声明式 hooks**（那是 Claude/Codex/opencode 的概念）：

| 概念 | DSH 机制 | 位置 |
|---|---|---|
| 子代理 | Cordis **agent presets**（`@deepseek-ai/dsh-agent-preset`） | bundle 的 `cordis.patch.yml` |
| Hooks/护栏 | Cordis 类型化事件 + 沙箱策略 | plugin/bundle |
| 无头 CI | `dsh headless "<task>"` 或 `dsh --profile sdk` | CLI |

因此 DSH 会话的确定性护栏是 **git hooks + CI 镜像**（`.githooks/`、`.github/workflows/framework-selftest.yml`），
它们对所有 agent 生效——这是 DSH 会话的权威层。

## 把子代理打包成 DSH presets

下面的 `cordis.patch.yml` 是**模板**。把它作为 bundle 编写，用 DSH 的 **Plugins > Add plugin**
（本地目录）流程或 `plugin_manager` 的 `install_bundle` 安装。安装前按已装 DSH 版本的
preset/persona 包 API 复核（见 `dsh-doc` 技能）。

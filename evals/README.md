# Agent 评测 — AI 原生的"阶段门 QA"

只要 agent 的配置变了（`AGENTS.md`、`CLAUDE.md`、skills、agents、hooks），就应跑评测套件——
配置在引导 agent，理应像代码一样做回归测试。通过率作为合并检查；套件**按 agent** 跑，
确保配置变更在你组织使用的每个 agent 上都被验证。

## 结构

- `tasks/*.md` —— 一个文件一个 eval。YAML frontmatter 放机器字段
  （`name`、`prompt`、`allowed_tools`、`verify`）；第二个 `---` 之后是给人看的说明，runner 忽略。
- `run.py` —— 通过选定 agent（`--agent claude|codex|opencode|dsh`）非交互地跑每个任务，
  再执行任务的 `verify` 命令。
- `.github/workflows/agent-evals.yml` —— 在配置变更和定时触发时跑套件，每个启用的 agent 一个 runner。

## 任务格式

```markdown
---
name: <kebab-name>
prompt: |
  <给 agent 的任务，用真实工作的口吻写>
allowed_tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash(make *)
  - Bash(bash scripts/*)
verify:
  - cmd: bash scripts/selftest.sh
    expect: "31 passed"
  - cmd: ./scripts/validate-skills.sh
    expect: "validate-skills: OK"
---
给人看的说明（这个 eval 防的是什么、何时加入）。
```

## 本地运行

```bash
ANTHROPIC_API_KEY=... python3 evals/run.py --agent claude --threshold 0.8
OPENAI_API_KEY=...   python3 evals/run.py --agent codex --threshold 0.8
python3 evals/run.py --agent opencode --threshold 0.8
python3 evals/run.py --agent dsh --threshold 0.8
```

## 套件规则

1. 从近期工作收集 20–50 个真实任务；每个写成 eval，检查项定义"可接受"（测试过、lint 干净、行为不变、遵守策略）。
2. 每起生产事故都新增一个 eval（由负责该事故的团队写），并作为回归测试长期保留。
3. 在 CI 里锁定 agent/model，避免把模型升级误判为配置回归（见 workflow）。
4. 套件是活的：模型变强后，失去区分度的用例被替换，监控发现新问题则新增。
5. 让通过率下降的技能/配置变更，合并前必须评审。

## Agent 支持

`run.py --agent` 分派到各 agent 的无头 CLI：`claude -p`、`codex exec`、`opencode run`、`dsh headless`。
完整命令面见 `docs/agent-support-matrix.md`。

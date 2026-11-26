---
name: commit-conventions
description: Use before every git commit. Enforces "[<name>] #<ticket> <type>: <summary>"; AI-generated code uses [AI-Agent], no ticket uses #N/A.
---

# Commit message conventions

Every commit subject must be:

```
[<姓名>] #<卡号> <类型>: <概述>
```

- **姓名**：提交人；AI 生成的代码固定用 `AI-Agent`。
- **卡号**：取自任务/PR/Jira 卡；没有卡号用 `N/A`。
- **类型**：`feat`（新增或修改功能）、`fix`、`refactor` 最常用；也允许 `docs`/`chore`/`test`/`perf`/`ci`/`build`/`revert`。
- 主语用祈使句，概述写"做了什么"，不写"修改了一些东西"。

示例：

- 新功能：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`
- 修 bug：`[AI-Agent] #OTRN-1234 fix: correct BMI3 rounding error`
- 重构：`[AI-Agent] #N/A refactor: extract pricing policy`
- 合并发布：`[AI-Agent] #N/A feat: merge release code`

执行前自检（写完 subject 先对照）：

1. 是否以 `[姓名] #卡号 ` 开头？
2. 类型是否在上面允许列表里，且后面是 `: `？
3. AI 生成的是否写了 `AI-Agent`？无卡号是否写了 `N/A`？

两道门禁会检查同一规则：PreToolUse `hooks/commit-guard.sh`（执行 `git commit -m ...` 前拦截）
与 `.githooks/commit-msg`（提交时兜底）。不要用 `--no-verify` 绕过；确需绕过的，先取得人类明确批准。

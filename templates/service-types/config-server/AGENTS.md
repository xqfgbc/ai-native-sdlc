# AGENTS.md — {{SERVICE}}（config-server service）

服务级（内环）SDLC。项目级规则见管理仓。

## 变更循环
`intent → spec → plan → build → test → deploy → maintain`；无接受的 plan 不写代码。

## 会话协议

> 会话开始先运行 `bash scripts/install-hooks.sh`（幂等，启用 `.githooks`；Claude Code 会自动执行）。
每次会话结束写 `sdlc/session-log/<YYYYMMDD-HHMM>.md`：人的指令、AI 实际改动、纠正、规则缺口、未决问题。

## 采集与上传
commit 触发 `.sdlc/collect.sh`（增量 facts + AI 候选认知）→ 上传管理仓。

## Config Server 专项
- 配置源变更（infra 仓 `config/`）要同步管理仓 `knowledge/context`。
- 不把 secrets 写进 config；用环境/ESO/IRSA。

## 硬规则
不写 secrets；不绕过 hooks/CI；cognition pack 版本锁定，不私自改。

## 提交信息

`[<姓名>] #<卡号> <类型>: <概述>`；无卡号用 `#N/A`；AI 生成的代码用 `[AI-Agent]`。
例：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`

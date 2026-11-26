# AGENTS.md — {{SERVICE}}（frontend-vue service）

服务级（内环）SDLC。项目级规则见管理仓。

## 变更循环
`intent → spec → plan → build → test → deploy → maintain`；无接受的 plan 不写代码。

## 会话协议
每次会话结束写 `sdlc/session-log/<YYYYMMDD-HHMM>.md`：人的指令、AI 实际改动、纠正、规则缺口、未决问题。

## 采集与上传
commit 触发 `.sdlc/collect.sh`（增量 facts + AI 候选认知）→ 上传管理仓。

## UI 专项
- 页面/组件变更记录在报告 `facts` 与 session-log；视觉/交互影响写清楚。
- 可访问性（a11y）与响应式检查纳入测试。
- 不引入未批准的 UI 框架/依赖。

## 硬规则
不写 secrets；不绕过 hooks/CI；cognition pack 版本锁定，不私自改。

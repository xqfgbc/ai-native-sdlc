# AGENTS.md — {{SERVICE}}（gateway service）

服务级（内环）SDLC。项目级规则见管理仓。

## 变更循环
`intent → spec → plan → build → test → deploy → maintain`；无接受的 plan 不写代码。

## 会话协议
每次会话结束写 `sdlc/session-log/<YYYYMMDD-HHMM>.md`：人的指令、AI 实际改动、纠正、规则缺口、未决问题。

## 采集与上传
commit 触发 `.sdlc/collect.sh`（增量 facts + AI 候选认知）→ 上传管理仓。

## Gateway 专项
- 路由 `Path=/api/<base>/**` → `lb://<service>`；改路由同步管理仓 `knowledge/context`。
- 鉴权统一入口；除 `/actuator/health/**` 外无匿名路由。
- 不引入 Eureka；发现走 k8s 原生。

## 硬规则
不写 secrets；不绕过 hooks/CI；cognition pack 版本锁定，不私自改。

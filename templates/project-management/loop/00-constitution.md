# {{PROJECT}} 项目宪法（constitution）

> 不可协商的顶层原则。02 spec / 03 plan 的门禁必须逐条核对本文件。
> 由架构师/项目负责人签署后生效；修改需重新签署。

Status: draft

## 1. 安全与合规底线
- 所有对外端点经 gateway 鉴权；除 `/actuator/health/**` 外无匿名路由。
- secrets 只来自环境 / ESO / IRSA，绝不进入源码或提交配置。
- PII 不得进入日志、错误信息或 AI 上下文。

## 2. 架构底线
- 模块分层：`api/` → `core/` → `adapters/`；`core/` 不依赖 web。
- 服务发现 k8s 原生；配置走 Spring Cloud Config；不引入 Eureka。
- 每个服务独立可用、可部署、可观测。

## 3. 工程底线
- 依赖版本由 platform/version catalog 管理，**不隐式升级**。
- 每个端点有集成测试；bug 修复先写失败测试。
- 合并前：构建/测试/静态检查全绿 + 人类 code owner 批准。

## 4. AI 行为底线
- AI 不批准自己的产出；确定性校验为最终裁决。
- 项目级认知（cognition pack）变更必须 policy owner 人工签核。

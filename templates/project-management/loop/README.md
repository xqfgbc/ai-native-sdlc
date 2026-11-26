# loop/ — 外环：项目级 SDLC

> 每阶段产物提交到版本控制；commit 链即审计轨迹；每阶段有过门禁才进入下一阶段。

## 00 constitution — 项目宪法
不可协商的顶层原则（安全/合规/架构底线），供 02/03 阶段门禁引用。
- 文件：`00-constitution.md`
- 门禁：架构师 / 项目负责人签署。

## 01 intent — 客户意图
以客户/发起人**原话**一次捕获：做不了什么、谁受影响、怎样算更好、范围外是什么。
- 目录：`01-intent/INT-<nnnn>-<slug>/intent.md`
- 门禁：客户 / PM 接受。

## 02 spec — 需求 + 设计
可测试需求 + 页面设计 + 功能/架构设计 + ADR；**先列 clarify 问题清单再定稿**。
- 目录：`02-spec/REQ-<nnnn>-<slug>/spec.md`、`02-spec/design/pages/`、`02-spec/design/architecture/`、`02-spec/design/decisions/ADR-*.md`
- 门禁：PM + 架构师签署。

## 03 plan — 项目计划 + 服务拆分
把 spec 拆成服务与有序工作项（引用 constitution）。
- 目录：`03-plan/PLAN-<nnnn>/plan.md`
- 门禁：技术负责人接受。

## 04 build — 服务创建/开发
生成服务仓、登记 `services.json`、跟踪各服务构建状态。
- 文件：`04-build/services.json`
- 门禁：每服务 PR code owner。

## 05 test — 测试管理
测试计划、需求↔测试矩阵、E2E/验收、质量门禁。
- 目录：`05-test/plan.md`、`05-test/matrix.md`、`05-test/results/`
- 门禁：QA。

## 06 deploy — 上线
发布记录、授权、回滚演练。
- 目录：`06-deploy/releases/<version>.md`
- 门禁：发布经理授权。

## 07 maintain — 维护闭环
事故/控制带击穿 → 诊断 → **写回新 intent**，重新进入外环。
- 目录：`07-maintain/incidents/INC-<nnnn>.md`
- 门禁：值班分诊。

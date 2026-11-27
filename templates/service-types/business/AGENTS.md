# AGENTS.md — {{SERVICE}}（business service）

本文件管理**服务级（内环）** SDLC。项目级规则见管理仓 `AGENTS.md`。

## 1. 变更循环（每次变更）
`intent → spec → plan → build → test → deploy → maintain`
- 无接受的 plan 不写代码；每步产物提交（intent/spec/plan → 代码+测试）。
- 门禁：intent/spec 由产品/架构确认；plan 由工程接受；合并由 code owner 批准。

## 2. 会话协议（强制）

> 会话开始先运行 `bash scripts/install-hooks.sh`（幂等，启用 `.githooks`；Claude Code 会自动执行）。
每次 AI 会话结束前，写 `sdlc/session-log/<YYYYMMDD-HHMM>.md`：
- 本次要做什么（人的指令摘要）
- AI 实际做了什么（关键改动）
- 人给的纠正 / 否决
- 发现的规则缺口（值得沉淀为约束/技能）
- 未决问题

> 采集器会读取 session-log，生成 `candidateKnowledge`（带 evidenceRef）。没有 session-log 的非平凡改动会被判 `needs_review`。
> Stop hook `session-log-guard.sh` 会在有实质提交却没写日志时阻止会话结束。

## 2b. 服务本地认知（S1）

只对本服务成立的规则不要走项目签核，放本地：

```bash
bash scripts/local-cognition.sh add --statement "…" --problem "它解决什么" \
  --origin-type incident --origin-ref INC-42 \
  --enforcement deterministic --gate-type archunit --gate-name noFoo --gate-path src/test/...
```

- 规则正文（statement）只在本仓；`collect` 只上报 `origin/problem/summary/gate` 证据，不上报正文。
- `deterministic` 必须给出真实门禁（`--gate-type` + `--gate-name`/`--gate-path`），否则会被拒绝。
- 渲染进 `CLAUDE.md`/`AGENTS.md` 的本地块，并由 SessionStart hook 注入。
- 只有需要多服务统一时才提升为项目级（S2）：人工写 proposal 并签核。

## 3. 采集与上传
- commit 触发 `.sdlc/collect.sh`：增量采集（上次 sha → HEAD）→ `sync/reports/<toSha>.json` → 上传管理仓。
- **facts 确定性提取**，AI 只产出候选认知；`review.status` 由确定性规则判定。

## 4. 硬规则
- 不写 secrets；不绕过 hooks/CI；不隐式升级依赖版本。
- 测试失败先修代码，不弱化测试。
- 认知配置用 `.sdlc/config.json` 锁定的 **cognition pack** 版本，不私自改。

## AI-first

任何操作、改进、知识都必须提供 AI 可调用入口：CLI/API + 结构化输出（`--json`）+ AGENTS/skill 说明；
网页或人工流程只能是补充。只有人类入口的功能视为未完成。

## 提交信息

`[<姓名>] #<卡号> <类型>: <概述>`；无卡号用 `#N/A`；AI 生成的代码用 `[AI-Agent]`。
例：`[AI-Agent] #AC-1020 feat: add new processor for BMI3 calculation`

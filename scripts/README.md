# scripts/ — 命令台（"刀架"）

所有可复用的确定性操作集中在这里；skills 只写"调用哪个命令"，不抄参数。

## 生成

| 命令 | 用途 |
|---|---|
| `new-project.sh <project> [target] [--allow-custom-name]` | 生成控制平面仓（`<project>-control-plane`：loop/execution/knowledge/wiki/sync + 自包含脚本） |
| `new-project.sh --print-name <project>` | 只打印推导出的控制平面仓名（无副作用） |
| `new-service-repo.sh <type> <name> <mgmt> [target] [--allow-custom-name]` | 生成服务仓并登记到管理仓；目录名按命名规则推导（见下） |
| `new-service-repo.sh --print-name <type> <name> <mgmt>` | 只打印按规则推导的仓库名（无副作用） |

命名规则（`<project>` = 管理仓名去掉 `-management`）：`business`/`frontend-vue` → `<project>-<service>-management`；
`gateway` → `<project>-<usage>-gateway`；`infra` → `<project>-<cloud>-infra`；
`config-server` → `<project>-config-server`；`configuration-data` → `<project>-<prod|devops>-configuration-data`。

## 闭环

| 命令 | 用途 |
|---|---|
| `collect.sh`（在服务仓） | commit 触发增量采集 → 报告 + hash 链 |
| `analyze-reports.sh [mgmt]` | 生成 wiki / proposals / 测试结果 / DORA |
| `validate-project.sh [mgmt]` | 校验管理仓一致性 |
| `promote-proposal.sh <mgmt> <id> <owner> [advisory\|deterministic]` | 人工签核 → pack active + guardrail 存根 |
| `sync-cognition.sh <mgmt> <svc>` | cognition pack 下发 + 版本锁定 |
| `upload-report.sh <org/repo> <report> <stage> <svc> <sha>` | 跨仓 PR 上传（P2） |
| `intake.sh` | 聚类 intake/signals → candidates |
| `intake-signal.sh <tag> <title> [body]` | 追加一条 intake 信号（Slack/Linear/邮件） |

## 验证 / 信任

| 命令 | 用途 |
|---|---|
| `app-verify.sh [build\|test\|lint\|itest\|all\|smoke]` | **统一验证 CLI**（Java/Node 自动识别） |
| `autopilot-gate.sh` | L3 autopilot 确定性门禁（信任阶梯） |
| `scan-findings.sh` | 确定性 foot-gun 扫描 → findings/inbox.md |
| `check-endpoints.sh <dir>` | 端点安全启发式检查 |
| `selftest.sh` | 框架端到端自测 |
| `validate-skills.sh` | 技能/子代理配置校验 |
| `sync-agent-adapters.sh` | `.agents/skills` → `.claude/skills` 同步 |

> 约定：新增脚本 = 可复用、幂等、失败 fail-closed；写进本表，并在对应 skill 里只引用命令名。

# Trust ladder

> 信任不是感觉，是可复现的证据；每爬一格靠一个新工具（poteto）。等级存在 `service.json` 的 `trustLevel`。

| 等级 | 名称 | 自动化什么 | 人做什么 | 门禁 |
|---|---|---|---|---|
| **L0** | manual | 无 | 自己写、自己合并 | 人 |
| **L1** | verify loop | agent 构建 + 跑 `app-verify.sh all` | 看验证输出，合并 | code owner |
| **L2** | multi-agent | writer + **独立 verifier**（优先不同模型族） | 认可 verifier 对 exact patch 的干净结论 | code owner |
| **L3** | autopilot | 验证全绿 + 独立 verifier 干净 + 可回滚时，agent 可合并 | 早上读 commit 历史，有问题就 revert 或加 guardrail | 自动化 + 可回滚性 |

## Autopilot 前置条件（全部成立才允许）

1. `service.json.trustLevel == L3`。
2. `scripts/app-verify.sh all` 在 **exact head** 上绿；CI 在 rebase 后的 head 上绿。
3. **独立 verifier**（不是作者）对 exact patch 给出干净结论。
4. 变更**可回滚**：不含单向门路径（`db/migration`、鉴权模型、资金），不含 secrets。
5. 有回滚 runbook；**生产仍走 `production-gate`**（自动化不越过生产门）。

## 升级只靠证据

- L1→L2：连续 N 次 verifier 干净运行后升。
- L2→L3：更长干净窗口 + 已验证过回滚。
- 任何事故 → **降一级**，并新增 eval + 一条 guardrail（不要只加 prompt）。

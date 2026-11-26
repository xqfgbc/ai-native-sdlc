# intake/ — 入口情报循环

> 对应 poteto 的"外循环"：把 Slack/X/邮件/工单/告警等信号**聚类**成候选意图，人只做分诊。
> 采集是 `scripts/intake.sh`（`scripts/` 由生成器复制），定时/手动由 `.github/workflows/intake.yml` 触发。

```
intake/
  signals/        原始信号（每条一个 .md，含 `Tag:` 行）
  candidates/     intake.sh 生成的聚类候选（人工提升为 loop/01-intent/INT-*/intent.md）
```

## 流程

1. 任何人/机器人把信号写成 `intake/signals/<name>.md`，第一行 `Tag: <主题>`。
2. `bash scripts/intake.sh` 按 Tag 聚类 → `intake/candidates/<date>-<tag>.md`。
3. 人工把有价值的候选提升为 `loop/01-intent/INT-<nnnn>-<slug>/intent.md`（走 Stage 1 门禁）。

## 为什么要有它

信号散落在各渠道，直接进 backlog 会变成"每个信号一个任务"；先聚类，再让 root cause 浮现。

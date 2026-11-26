# Intake channels — 把 Slack / Linear / 邮件 / 告警接进 intake

`intake/signals/` 是唯一入口；任何渠道只要能写一条信号，就能进入聚类。

## 方式一：repository_dispatch（推荐，无需部署）

在管理仓启用 `.github/workflows/intake.yml`（已内置 `repository_dispatch: [intake-signal]`）。

从任意地方调用 GitHub API：

```bash
curl -X POST \
  -H "Authorization: token $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<org>/<project>-control-plane/dispatches" \
  -d '{"event_type":"intake-signal","client_payload":{"tag":"onboarding","title":"客户反馈：注册太慢","body":"ticket #4821 ..."}}'
```

workflow 会：
1. 从 `client_payload` 取 `tag/title/body`；
2. 调 `scripts/intake-signal.sh` 写一条 `intake/signals/<ts>-<slug>.md`；
3. 调 `scripts/intake.sh` 聚类到 `intake/candidates/`；
4. 提交。

## 方式二：Slack / Linear 原生自动化

- Slack workflow / Zapier / n8n：动作选 "HTTP request"，POST 上面的 dispatch URL（把 `event_type` 和 `client_payload` 填好）。
- Linear：webhook → 一个极小的转发函数（或用 Linear Automation 的 HTTP 动作）→ 同上。

## 方式三：手动

```bash
echo "客户 A 反馈注册要填 3 页" | scripts/intake-signal.sh onboarding "客户反馈：注册太慢"
scripts/intake.sh
```

## 约定

- `Tag` 决定聚类分组（小写、kebab）；没有 Tag 归到 `uncategorized`。
- 信号只追加、不修改；聚类结果 `intake/candidates/` 也是 append；**建 intent 仍需人**（Stage 1 门禁）。
- 不要在信号里写 secrets；脱敏由 `collect.sh` 的 scrub 负责报告，不负责信号。

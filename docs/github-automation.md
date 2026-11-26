# GitHub 自动化（P2）

> **默认仍是本地生成（D2）**：`new-project.sh` / `new-service-repo.sh` 只产出目录，不建远端仓。
> 本文档描述在用户自行建好 GitHub 仓并配置权限后，如何启用自动回灌。

## 三条链路

### 1. 服务仓 → 采集（commit/push 触发）
每个服务仓模板自带 `.github/workflows/collect.yml`：
- `on: push` / `workflow_dispatch`
- 运行 `.sdlc/collect.sh`（增量、确定性 facts、候选认知、hash 链）
- 若配置了 `MANAGEMENT_REPO` + `SYNC_TOKEN`，调用 `scripts/upload-report.sh` **开 PR** 到管理仓。

### 2. 服务仓 → 管理仓（跨仓 PR）
`scripts/upload-report.sh`：
- `gh repo clone` 管理仓（浅克隆）→ 把 `sync/reports/<sha>.json` 写到 `execution/<stage>/<service>/reports/<sha>.json` → 建分支 → 推送 → `gh pr create`。
- 幂等：同一 `toSha` 已存在则采集器本地跳过；PR 端以文件名幂等。

### 3. 管理仓 → analyze（定时/手动）
`templates/project-management/.github/workflows/analyze-reports.yml`：
- `on: schedule`（cron）+ `workflow_dispatch`
- 运行 `scripts/analyze-reports.sh` → 生成 `wiki/`、`knowledge/proposals/`、刷新 `services.json` → 提交。
- **proposal → active 永远由人执行** `promote-proposal.sh`（D19），CI 不自动提升。

## 需要的配置

在**服务仓**设置：
- Variable `MANAGEMENT_REPO` = `org/<project>-management`
- Secret `SYNC_TOKEN` = GitHub App 安装令牌或 fine-grained PAT

在**管理仓**：
- 允许 `analyze-reports.yml` 提交（`permissions: contents: write`，已配置）
- CODEOWNERS 保护 `knowledge/pack.json`（已配置）

## 最小权限（C2）

`SYNC_TOKEN` 只应具备：
- 对**管理仓**：`contents: write` + `pull_requests: write`（仅用于开报告 PR）
- 对**服务仓**：`contents: read`（如需跨仓读取）

推荐用 **GitHub App**（按需签发安装令牌），而非长期 PAT。

## 报告 PR 的合并策略

- `execution/**/reports/**`：机器产出、可自动合并（或 `gh pr merge --auto`）。
- `knowledge/pack.json`：**必须人工签核**，不由 CI 修改。
- 蒸馏：analyzer 只写 `knowledge/proposals/`，人执行 `scripts/promote-proposal.sh . <id> <owner>` 才升 active。

## 本地模拟（当前已可用）

未接远端时，全部链路用本地文件模拟：
```bash
bash scripts/selftest.sh   # 生成 → 采集（本地 cp）→ analyze → promote → sync
```

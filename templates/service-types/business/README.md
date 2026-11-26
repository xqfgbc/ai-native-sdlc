# {{SERVICE}} — business service

由 AI-Native SDLC 框架从服务模板 `business` 生成。**每个服务仓独立一个 repo。**

## 结构
```
sdlc/session-log/     # 每次 AI 会话结束写入（交流/纠正/规则缺口）
.sdlc/config.json     # 服务元数据 + managementRepo + lastCollectedSha
.sdlc/collect.sh      # commit 触发采集器（由生成器从框架复制）
sync/reports/         # 采集产出
src/...               # Spring Boot 代码（api/core/adapters）
```

## 工作方式（内环）
1. 按 `AGENTS.md` 的变更循环推进（intent→spec→plan→build→test→deploy→maintain）。
2. 每次 commit 自动采集增量 → 写 `sync/reports/<toSha>.json` → 上传到管理仓。
3. `review.status=needs_review` 的报告由人抽检；候选认知进管理仓 `knowledge/proposals/`。
4. 认知配置来自 **cognition pack**（`.sdlc/config.json` 锁版本），升级走 PR。

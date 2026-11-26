# {{PROJECT}} — Project Management

> 由 AI-Native SDLC 框架从 `templates/project-management/` 生成。**这是项目的控制平面与实时 wiki**。

## 结构

```
loop/          # 外环：项目级 SDLC（00 constitution → 01 intent → … → 07 maintain）
execution/     # 内环：AI 执行事实（append-only，含 hash 链）
knowledge/     # 沉淀环：constraints / skills / lessons / context / proposals / pack.json
wiki/          # 自动生成的实时 wiki
sync/          # 契约 schema + 状态
.github/       # analyze-reports 工作流 + CODEOWNERS
```

## 工作方式

1. **外环**（人+AI）：按 `loop/README.md` 的 7 阶段推进，每阶段产物提交、过人类门禁。
2. **内环**（服务仓）：每个服务仓 commit 时自动采集 → 上传报告到 `execution/<stage>/<service>/reports/`。
3. **分析与沉淀**：定时/手动运行 analyzer → 生成 `wiki/`、`knowledge/proposals/`、更新 `loop/04-build/services.json`。
4. **认知下发**：人工签核 proposals → 发布 `knowledge/pack.json` 新版本 → 服务仓锁定升级。

## 常用命令

```bash
# 分析已上传报告（本地）
bash ../ai-native-sdlc/scripts/analyze-reports.sh .   # 或 copy 到本项目后运行
# 校验一致性
bash ../ai-native-sdlc/scripts/validate-project.sh .
```

> 路径按生成时实际位置调整。

# {{SERVICE}} — Spring Cloud Config Server (Spring Boot 4.1.3 / JDK 21)

**目的**：{{SERVICE}} 集中分发各服务配置。默认 `native` profile 读本仓 `config/`；
生产/非生产分别从 `{{PROJECT}}-prod-configuration-data`、`{{PROJECT}}-devops-configuration-data`
的 git 后端读取。配置内容不在本仓维护，只维护分发能力。

## 本地启动与调试

前置：JDK 21。本仓默认即可本地运行（`native` profile），不需要额外的 profile 参数，也不需要外部依赖。

```bash
./gradlew bootRun                                   # http://localhost:8888，读 ./config/
curl -fsS http://localhost:8888/actuator/health
curl -fsS http://localhost:8888/<application>/<profile>   # 取某服务某环境的配置
bash scripts/app-verify.sh smoke                    # 未提供 local profile，smoke 不会强加 local
```

- 换配置目录：`CONFIG_SEARCH_LOCATIONS=file:/abs/path ./gradlew bootRun`。
- 用 git 后端调试：`./gradlew bootRun --args='--spring.profiles.active=git --spring.cloud.config.server.git.uri=file:///abs/path/to/<project>-devops-configuration-data'`。
- 检查：`./gradlew test`、`checkstyleMain checkstyleTest`、`check`（itest 需 Docker）。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，其他 agent 见第 0 步。
2. **变更循环**：`intent → spec → plan → build → test → deploy → maintain`；没有接受的 plan 不写代码。
3. **职责边界**：本仓只改配置分发能力（后端、安全、刷新策略）。具体配置值写到
   `configuration-data` 仓；生产配置变更需要发布经理授权。
4. **验证与提交**：`bash scripts/app-verify.sh all`（itest 需 Docker）；消息遵循 `AGENTS.md §6`；
   pre-commit / commit-msg / pre-push 自动执行；`release*` 分支走 PR。
5. **采集与会话**：commit 后 `bash .sdlc/collect.sh`；会话结束写 `sdlc/session-log/`。
6. **部署**：镜像 → ECR → Flux；git 后端指向 prod/devops 配置数据仓；生产发布需授权。
   当前仓库尚未接入 CI/ECR，接入后以 CI 为准。

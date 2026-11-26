# config/ — 本地配置占位（native 后端）

本地开发时 config-server 的 `native` profile 从这里读配置
（`spring.cloud.config.server.native.search-locations`）。

**配置真相源不在 infra 仓**：生产配置在 `{{PROJECT}}-prod-configuration-data`，
非生产（dev/uat）配置在 `{{PROJECT}}-devops-configuration-data`（`configuration-data` 模板生成）。

命名遵循 Spring Cloud Config 约定：`application.yml`、`<service>.yml`、`<service>-<env>.yml`。

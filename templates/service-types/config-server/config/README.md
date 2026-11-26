# config/ — 本地配置目录（native 后端）

本地开发时 config-server 的 `native` profile 从这里读配置
（`spring.cloud.config.server.native.search-locations`）。

**生产/非生产配置不在这里**：用 `git` profile 分别指向配置数据仓
`{{PROJECT}}-prod-configuration-data`（生产）和 `{{PROJECT}}-devops-configuration-data`（非生产），
见 `docs/repository-topology.md`。

命名遵循 Spring Cloud Config 约定：`application.yml`、`<service>.yml`、`<service>-<env>.yml`。

# config/ — Spring Cloud Config source（集群配置真相源）

config-server 的 `git` 后端读取本目录。命名遵循 Spring Cloud Config 约定：

- `application.yml` / `application-<profile>.yml` —— 共享默认值。
- `<service>.yml` / `<service>-<env>.yml` —— 按服务、按环境（`<env>` ∈ dev/uat/prod）。

**本目录就是配置源。** 服务仓里不再有 `config-repo/`；本地开发用
`src/main/resources/application-local.yml`，需要真实配置时让 config-server 指向本目录。

示例：

- `gateway.yml` —— 网关路由（`spring.cloud.gateway.server.webflux.routes`）
- `gateway-prod.yml` —— 仅生产覆盖
- `order-service.yml`、`order-service-uat.yml` —— 按服务配置

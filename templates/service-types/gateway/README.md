# gateway — Spring Cloud Gateway service

网关服务仓（standalone）。技术栈：**Spring Boot 4.1.3 + Spring Cloud Gateway（WebFlux）/ JDK 21**，k8s 原生发现、Spring Cloud Config client。

## 构建
```bash
./gradlew assemble      # compile + bootJar (build/libs/gateway.jar)
./gradlew check         # tests + checkstyle
docker build -t gateway .
```

## 职责
- 路由：`Path=/api/<base>/**` → `lb://<service>`。
- 鉴权：统一入口 JWT；除 `/actuator/health/**` 外无匿名路由。
- 路由表变更要回灌管理仓 `knowledge/context`。

## 内环
变更循环 + 会话协议 + commit 采集。

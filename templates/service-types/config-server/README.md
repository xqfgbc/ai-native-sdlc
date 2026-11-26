# config-server — Spring Cloud Config Server

配置服务仓（standalone）。技术栈：**Spring Boot 4.1.3 + Spring Cloud Config Server / JDK 21**。

## 构建
```bash
./gradlew assemble      # build/libs/config-server.jar
./gradlew check
docker build -t config-server .
```

## 职责
- 集中管理各服务配置（本地 `config/` 走 native；生产/非生产走配置数据仓
  `<project>-prod-configuration-data` / `<project>-devops-configuration-data` 的 git 后端）。
- 配置变更要回灌管理仓 `knowledge/context`。

## 内环
变更循环 + 会话协议 + commit 采集。

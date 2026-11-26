# {{SERVICE}} — Vue 3 前端 (Vue 3 + Vite + TypeScript)

**目的**：{{SERVICE}} 是项目的 Web 前端，负责 **（待填写）页面范围、角色与关键交互**。
页面与交互以控制平面仓 `loop/02-spec/design/pages/` 为准。

## 本地启动与调试

前置：Node 20+（以 `.nvmrc`/`package.json engines` 为准，如无则用 LTS）。

```bash
npm ci
npm run dev          # http://localhost:5173（Vite 默认端口，以启动输出为准）
npm run test         # Vitest 单测
npm run test:watch   # 监听模式
npm run build        # 类型检查 + 生产构建 dist/
npm run preview      # 预览构建产物
npm run test:e2e     # Playwright（首次需安装浏览器依赖）
bash scripts/app-verify.sh smoke   # 前端当前只返回提示，不探活
```

- 后端联调：默认指向本地后端（见 `src/` 的环境配置）；跨域用 Vite proxy 或网关，不要在前端写死域名。
- 组件/页面：`src/components`、`src/views`；状态：Pinia；路由：Vue Router。

## AI 如何使用本项目

1. **开工前**：读 `AGENTS.md`；新 clone 首个会话自动运行 `scripts/install-hooks.sh`，其他 agent 见第 0 步。
2. **变更循环**：`intent → spec → plan → build → test → deploy → maintain`；没有接受的 plan 不写代码。
3. **UI 变更记录**：在报告/会话日志里写清改了哪些页面与组件、视觉与交互影响、可访问性检查结果。
4. **验证与提交**：`npm run test && npm run build`（或 `bash scripts/app-verify.sh all`）；
   消息遵循 `AGENTS.md §6`；pre-commit / commit-msg / pre-push 自动执行；`release*` 分支走 PR。
5. **采集与会话**：commit 后 `bash .sdlc/collect.sh`；会话结束写 `sdlc/session-log/`。
6. **部署**：`npm run build` 产物 + 模板 `Dockerfile`（或静态托管/CDN）；
   具体目标环境在 infra 接入后补到本仓 README 与 `{{PROJECT}}-aws-infra`。

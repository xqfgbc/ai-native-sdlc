# {{SERVICE}} — Vue 3 frontend

由服务模板 `frontend-vue` 生成。技术栈：**Vue 3 + Vite + TypeScript + Pinia + Vue Router + Vitest/Playwright**。

## 结构
```
src/                 # Vue 3 + TS
src/components/      # 通用组件
src/views/           # 页面
src/stores/          # Pinia
tests/               # Vitest 单测 + Playwright E2E
.sdlc/config.json    # 服务元数据 + managementRepo
sdlc/session-log/    # AI 会话记录
```

## 内环
同 `AGENTS.md`：变更循环 + 会话协议 + commit 采集 + cognition pack 锁定。
UI 变更报告额外记录：改了哪些页面/组件、视觉/交互影响、可访问性检查。

## 常用命令
```bash
npm ci && npm run dev
npm run test        # Vitest
npm run test:e2e    # Playwright
npm run build
```

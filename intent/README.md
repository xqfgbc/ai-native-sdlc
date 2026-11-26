# intent/ — 框架仓自身的变更意图

> 注意：这是**框架仓自身**的变更意图目录（框架也是产品，也走六阶段循环）。
> 生成出来的**管理仓**把意图放在 `loop/01-intent/INT-*/`，不要混淆。

一次变更一个目录。这里只放循环的前三个产物，不放别的：

```
intent/
  2026-11-24-claims-status/
    intent.md   <- 阶段 1（capture-intent）    status: draft -> accepted | rejected
    spec.md     <- 阶段 2（requirements-and-design）
    plan.md     <- 阶段 3a（implementation-plan）
  ...
```

## 规则

- 任何人都能提 intent；非工程人员可通过对话/PR 提交 —— 文件格式就是契约。
- 每个 intent 由 product owner 接受或拒绝；决定由合并或关闭评审记录。接受的 intent 触发阶段 2。
- `spec.md` 与 `intent.md` 放一起，记录"要什么"和"定了什么"；`plan.md` 进入审计链并门控实现。
- slug 用 kebab-case，创建后稳定 —— 它是变更 ID，用于 commit 消息：
  `intent(<slug>):`、`spec(<slug>):`、`plan(<slug>):`、`feat(<slug>):`。
- 维护发现也进这里，标 `Source: maintenance-loop`（见 `incident-to-intent` 技能）。

从 `intent/TEMPLATE.md` 开始。

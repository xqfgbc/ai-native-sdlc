# Retro — <date / trigger>

> 复盘/事故后填写；每个 finding 必须变成规则、门禁、测试或债务，不能只写结论。

## 1. 事实与时间线

- 触发：incident | gate-bypass | repeat-proposal | DORA | review
- 影响：服务 / 用户 / 时长
- 证据：commit、report、日志、proposal id

## 2. Finding → 可检查规则

| Finding | 规则（must/never） | 检查命令 / 门禁层 | Owner | 验证（正/反例） |
|---|---|---|---|---|
| | | | | |

## 3. 未解决行动 → 债务

```bash
bash scripts/debt.sh add --kind <intent|tech|ops|test|security|process> \
  --title "<action>" --owner <human> --priority P1|P2|P3 --due YYYY-MM-DD --source retro
```

## 4. 认知候选

- 需要沉淀的候选：写入 `sdlc/session-log/` 的"规则缺口"，或作为 `[learn]` 提交；
- 不直接改 `knowledge/pack.json`。

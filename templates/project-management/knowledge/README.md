# knowledge/ — 沉淀环：项目认知

> AI 只产 **candidate / proposed**；项目级条目必须 **policy owner 人工签核** 才 `active`（D19）。

## 目录

| 目录/文件 | 内容 |
|---|---|
| `constraints/` | 约束（C-xxx） |
| `skills/` | 技能（S-xxx，可复用过程知识） |
| `lessons/` | 教训（L-xxx，事故/失败） |
| `context/` | 项目/架构事实（X-xxx，自动更新） |
| `proposals/` | AI 产出的候选认知，等待人工签核 |
| `pack.json` | cognition pack（版本化，服务仓锁定消费） |

## 提升规则

| 触发 | 沉淀为 |
|---|---|
| 同一纠正/错误 ≥2 次 | constraint |
| 同类流程 ≥3 次 | skill |
| 事故/失败/绕过门禁 | lesson（+eval） |
| 架构事实变化 | context（自动更新） |
| 政策/安全硬规则 | 确定性 gate（hook/CI） |

## 条目属性

`id / type / scope(project|service|process) / owner / version / provenance / status(proposed→active→retired) / enforcement(advisory|deterministic)`

## 生效边界（D19）

- **服务内约束**：明确 → 自动；歧义 → 人工。
- **项目级 cognition pack**：AI 只写 `proposals/`；policy owner 人工签 PR → 更新 `pack.json` 并升 `active`。

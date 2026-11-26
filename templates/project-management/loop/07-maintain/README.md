# 07-maintain — 维护闭环

- `incidents/INC-<nnnn>.md`：事故记录（现象、诊断、恢复、教训、新增 eval）。
- **闭环**：事故 → 新 `01-intent`（重新进入外环）；每起事故新增一条 eval 用例。
- 控制带：`config/bands.yaml`（1σ 记录 / 2σ 只读诊断 / 3σ 提议或预批准 runbook）。
- 度量：breach→intent 时长、MTTR、重复事故类（每类修复追加 eval）。
